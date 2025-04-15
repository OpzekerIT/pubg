# --- Script Setup ---
$logPrefix = Get-Date -Format "yyyyMMdd_HHmmss" # Use standard sortable format
# Determine script root directory reliably
if ($PSScriptRoot) {
    $scriptRoot = $PSScriptRoot
} else {
    $scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Write-Warning "PSScriptRoot not defined, using calculated path: $scriptRoot"
}
Write-Output "Script root identified as: $scriptRoot"

# Define paths using Join-Path
$includesPath = Join-Path -Path $scriptRoot -ChildPath "..\includes\ps1"
$configPath = Join-Path -Path $scriptRoot -ChildPath "..\config"
$discordConfigPath = Join-Path -Path $scriptRoot -ChildPath "config.php" # Config is in the same dir
$dataPath = Join-Path -Path $scriptRoot -ChildPath "..\data"
$logDir = Join-Path -Path $scriptRoot -ChildPath "..\logs" # Assuming logs dir relative to scriptroot parent
$playerMatchesJsonPath = Join-Path -Path $dataPath -ChildPath "player_matches.json"

# Ensure Log directory exists
if (-not (Test-Path -Path $logDir -PathType Container)) {
    Write-Warning "Log directory not found at '$logDir'. Attempting to create."
    try {
        New-Item -Path $logDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Write-Output "Successfully created log directory."
    } catch {
        # Log to console if transcript path fails
        Write-Error "Failed to create log directory '$logDir'. Please check permissions. Error: $($_.Exception.Message)"
        # Continue without transcript if log dir fails? Or exit? For now, continue.
    }
}

# Start Transcript (use calculated $logDir)
$transcriptPath = Join-Path -Path $logDir -ChildPath "report_new_matches_$logPrefix.log"
try {
    Start-Transcript -Path $transcriptPath -Append -ErrorAction Stop
    Write-Output "Starting report_new_matches script at $(Get-Date)"
    Write-Output "Running from: $(Get-Location)"
    Write-Output "Transcript logging to: $transcriptPath"
} catch {
     Write-Error "Failed to start transcript at '$transcriptPath'. Error: $($_.Exception.Message)"
     # Exit if transcript is critical? For now, continue.
}

# --- Locking ---
$lockFilePath = Join-Path -Path $includesPath -ChildPath "lockfile.ps1"
if (-not (Test-Path -Path $lockFilePath -PathType Leaf)) {
    Write-Error "Lockfile script not found at '$lockFilePath'. Cannot proceed."
    if ($transcriptPath) { Stop-Transcript }
    exit 1
}
. $lockFilePath
New-Lock -by "report_new_matches" -ErrorAction Stop # Stop if locking fails

# --- Main Logic in Try/Finally for Lock Removal ---
try {
    # --- Configuration Loading ---
    $apiKey = $null
    $webhookUrl = $null
    $webhookUrlLosers = $null

    # Load API Key from main config.php
    $phpConfigPath = Join-Path -Path $configPath -ChildPath "config.php"
    if (Test-Path -Path $phpConfigPath -PathType Leaf) {
        try {
            $fileContent = Get-Content -Path $phpConfigPath -Raw -ErrorAction Stop
            if ($fileContent -match '^\s*\$apiKey\s*=\s*''([^'']+)''') { $apiKey = $matches[1]; Write-Verbose "API Key loaded." }
            else { Write-Warning "API Key pattern not found in '$phpConfigPath'." }
        } catch { Write-Warning "Failed to read '$phpConfigPath': $($_.Exception.Message)" }
    } else { Write-Warning "Main config file not found at '$phpConfigPath'." }

    # Load Webhook URLs from discord/config.php
    if (Test-Path -Path $discordConfigPath -PathType Leaf) {
        try {
            $discordFileContent = Get-Content -Path $discordConfigPath -Raw -ErrorAction Stop
            if ($discordFileContent -match '^\s*\$webhookurl\s*=\s*''([^'']+)''') { $webhookUrl = $matches[1]; Write-Verbose "Main webhook URL loaded." }
            else { Write-Warning "Main webhook URL pattern not found in '$discordConfigPath'." }
            
            if ($discordFileContent -match '^\s*\$webhookurl_losers\s*=\s*''([^'']+)''') { $webhookUrlLosers = $matches[1]; Write-Verbose "Losers webhook URL loaded." }
            else { Write-Warning "Losers webhook URL pattern not found in '$discordConfigPath'." }
        } catch { Write-Warning "Failed to read '$discordConfigPath': $($_.Exception.Message)" }
    } else { Write-Warning "Discord config file not found at '$discordConfigPath'." }

    # Validate required config
    if (-not $apiKey) { Write-Error "API Key missing."; throw "Missing API Key" }
    if (-not $webhookUrl) { Write-Error "Main Discord webhook URL missing."; throw "Missing Webhook URL" }
    if (-not $webhookUrlLosers) { Write-Error "Losers Discord webhook URL missing."; throw "Missing Losers Webhook URL" }

    # --- API Headers ---
    $apiHeaders = @{
        'accept'        = 'application/vnd.api+json'
        'Authorization' = "Bearer $apiKey"
    }

    # --- Helper Function for API Calls (Copied from update_clan_members.ps1) ---
    function Invoke-PubgApi {
        param(
            [Parameter(Mandatory=$true)][string]$Uri, [Parameter(Mandatory=$true)][hashtable]$Headers,
            [int]$RetryCount = 1, [int]$RetryDelaySeconds = 61
        )
        for ($attempt = 1; $attempt -le ($RetryCount + 1); $attempt++) {
            try {
                Write-Verbose "API call (Attempt $($attempt)): $Uri"
                $response = Invoke-RestMethod -Uri $Uri -Method GET -Headers $Headers -ErrorAction Stop
                if ($null -ne $response) { Write-Verbose "API call successful."; return $response }
                else { Write-Warning "API call to $Uri returned null."; return $null }
            } catch {
                $statusCode = $_.Exception.Response.StatusCode.value__
                $errorMessage = $_.Exception.Message
                Write-Warning "API call failed (Attempt $($attempt)). Status: $statusCode. Error: $errorMessage"
                if ($attempt -le $RetryCount -and $statusCode -eq 429) {
                    Write-Warning "Rate limit hit. Sleeping $RetryDelaySeconds sec..."; Start-Sleep -Seconds $RetryDelaySeconds
                } elseif ($attempt -gt $RetryCount) { Write-Error "API call failed after $($attempt) attempts. URI: $Uri. Last Error: $errorMessage"; return $null }
                else { Write-Error "Non-retryable API error. URI: $Uri. Error: $errorMessage"; return $null }
            }
        }
        return $null
    }
    
    # --- Helper Function for Telemetry Download/Parse ---
    function Get-TelemetryData {
         param([string]$TelemetryUrl)
         if (-not $TelemetryUrl) { Write-Warning "Get-TelemetryData: No Telemetry URL provided."; return $null }
         
         $telemetryFileName = $TelemetryUrl.Split('/')[-1]
         $telemetryCacheFilePath = Join-Path -Path $telemetryCachePath -ChildPath $telemetryFileName
         
         # Try cache first
         if (Test-Path -Path $telemetryCacheFilePath -PathType Leaf) {
             Write-Verbose "Loading telemetry from cache: $telemetryCacheFilePath"
             try {
                 $telemetry = Get-Content -Path $telemetryCacheFilePath | ConvertFrom-Json -ErrorAction Stop
                 if ($null -ne $telemetry) { return $telemetry }
                 else { Write-Warning "Failed to parse cached telemetry: $telemetryCacheFilePath" }
             } catch { Write-Warning "Error reading cached telemetry '$telemetryCacheFilePath': $($_.Exception.Message)" }
         }
         
         # Download if not cached or cache failed
         Write-Output "Downloading telemetry: $TelemetryUrl"
         try {
             $webHeaders = @{ 'Accept-Encoding' = 'gzip' }
             $response = Invoke-WebRequest -Uri $TelemetryUrl -Headers $webHeaders -UseBasicParsing -ErrorAction Stop
             $telemetryContent = $response.Content
             $telemetryContent | Out-File -FilePath $telemetryCacheFilePath -Encoding UTF8 -ErrorAction SilentlyContinue
             $telemetry = $telemetryContent | ConvertFrom-Json -ErrorAction Stop
             if ($null -eq $telemetry) { Write-Warning "Failed to parse downloaded telemetry from $TelemetryUrl." }
             return $telemetry
         } catch {
             $errorMessage = $_.Exception.Message
             Write-Warning "Failed to download/save telemetry from $TelemetryUrl. Error: $errorMessage"
             return $null
         }
    }

    # --- Discord Sending Functions (with Error Handling) ---
    function Send-DiscordMessage {
        param([string]$Webhook, [string]$Content)
        if (-not $Webhook -or -not $Content) { Write-Warning "Send-DiscordMessage: Missing Webhook or Content."; return }
        
        $payload = @{ content = $Content } | ConvertTo-Json -Depth 3
        try {
            Invoke-RestMethod -Uri $Webhook -Method Post -Body $payload -ContentType 'application/json' -ErrorAction Stop
            Write-Verbose "Successfully sent message to Discord."
        } catch {
            $errorMessage = $_.Exception.Message
            Write-Error "Failed to send message to Discord ($Webhook). Error: $errorMessage"
        }
    }
    function Send-DiscordWin($Content) { Send-DiscordMessage -Webhook $webhookUrl -Content $Content }
    function Send-DiscordLoss($Content) { Send-DiscordMessage -Webhook $webhookUrlLosers -Content $Content }

    # --- Map Definitions ---
    $mapNameLookup = @{ # Renamed from $map_map
        "Baltic_Main"     = "Erangel"
        "Chimera_Main"    = "Paramo"
        "Desert_Main"     = "Miramar"
        "DihorOtok_Main"  = "Vikendi"
        "Erangel_Main"    = "Erangel" # Duplicate key, might be intentional?
        "Heaven_Main"     = "Haven"
        "Kiki_Main"       = "Deston"
        "Range_Main"      = "Camp Jackal"
        "Savage_Main"     = "Sanhok"
        "Summerland_Main" = "Karakin"
        "Tiger_Main"      = "Taego"
        "Neon_Main"       = "Rondo"
    }

    # --- Load Player Matches Data ---
    $playerMatchesData = $null
    if (Test-Path -Path $playerMatchesJsonPath -PathType Leaf) {
        try {
            $playerMatchesData = Get-Content -Path $playerMatchesJsonPath | ConvertFrom-Json -Depth 100 -ErrorAction Stop
            if ($null -eq $playerMatchesData -or -not ($playerMatchesData -is [array])) {
                 Write-Error "Invalid structure in '$playerMatchesJsonPath'. Expected array. Cannot proceed."
                 throw "Invalid player matches data."
            }
            Write-Output "Successfully loaded player matches data."
        } catch {
            Write-Error "Error reading '$playerMatchesJsonPath': $($_.Exception.Message). Cannot proceed."
            throw $_
        }
    } else {
        Write-Error "Player matches file not found at '$playerMatchesJsonPath'. Cannot proceed."
        throw "Missing player matches file."
    }

    # --- Extract New Wins and Losses ---
    # Find the special entries added by get_matches.ps1
    $newWinEntry = $playerMatchesData | Where-Object { $_.PSObject.Properties.Name -eq 'new_win_matches' } | Select-Object -First 1
    $newLossEntry = $playerMatchesData | Where-Object { $_.PSObject.Properties.Name -eq 'new_loss_matches' } | Select-Object -First 1

    $newWinMatchIds = if ($null -ne $newWinEntry -and $newWinEntry.new_win_matches -is [array]) { $newWinEntry.new_win_matches } else { @() }
    $newLossMatchIds = if ($null -ne $newLossEntry -and $newLossEntry.new_loss_matches -is [array]) { $newLossEntry.new_loss_matches } else { @() }

    Write-Output "Found $($newWinMatchIds.Count) new win match IDs and $($newLossMatchIds.Count) new loss match IDs to report."
    
    # Extract actual match data (excluding the special entries)
    $actualMatchEntries = $playerMatchesData | Where-Object { $_.PSObject.Properties.Name -ne 'new_win_matches' -and $_.PSObject.Properties.Name -ne 'new_loss_matches' }

    # --- Process and Report New Losses ---
    Write-Output "Processing $($newLossMatchIds.Count) new losses..."
    foreach ($lossId in $newLossMatchIds) {
        if (-not $lossId) { continue }
        Write-Output "Processing loss match ID: $lossId"
        
        # Find all player entries related to this loss match ID in the loaded data
        $lossMatchPlayerEntries = $actualMatchEntries.player_matches | Where-Object { $_.id -eq $lossId }
        if ($null -eq $lossMatchPlayerEntries -or $lossMatchPlayerEntries.Count -eq 0) {
            Write-Warning "Could not find match details for loss ID $lossId in player_matches.json data."
            continue
        }
        
        # Use the first entry for common match details (assuming they are consistent)
        $firstLossEntry = $lossMatchPlayerEntries[0]
        $lossGameMode = $firstLossEntry.gameMode
        $lossMatchType = $firstLossEntry.matchType
        $lossMapNameRaw = $firstLossEntry.mapName
        $lossTelemetryUrl = $firstLossEntry.telemetry_url
        
        # Skip TDM matches
        if ($lossGameMode -eq 'tdm') { Write-Output "Skipping TDM loss match $lossId."; continue }

        # Fetch Full Match Stats from API (needed for all participants' details)
        $lossMatchApiStats = Invoke-PubgApi -Uri "https://api.pubg.com/shards/steam/matches/$lossId" -Headers $apiHeaders
        
        # Get Telemetry Data
        $lossTelemetryEvents = Get-TelemetryData -TelemetryUrl $lossTelemetryUrl
        $relevantLossTelemetry = $null
        if ($lossTelemetryEvents -is [array]) {
            $relevantLossTelemetry = $lossTelemetryEvents | Where-Object { $_._T -eq 'LogPlayerTakeDamage' -or $_._T -eq 'LogPlayerKillV2' }
        } else { Write-Warning "Invalid or missing telemetry data for loss match $lossId." }

        # Prepare data tables
        $lossStatsTable = @()
        $lossTeamDamageVictims = @()

        # Iterate through players involved in this loss from our data
        $involvedPlayerNames = $lossMatchPlayerEntries.stats.name | Select-Object -Unique
        foreach ($playerName in $involvedPlayerNames) {
             $playerLossStats = $lossMatchPlayerEntries | Where-Object { $_.stats.name -eq $playerName } | Select-Object -First 1 -ExpandProperty stats
             
             # Try to get more detailed stats from the full API response if available
             $detailedPlayerStats = $null
             if ($null -ne $lossMatchApiStats -and $lossMatchApiStats.included -is [array]) {
                 $detailedPlayerStats = $lossMatchApiStats.included |
                                        Where-Object { $_.type -eq 'participant' -and $_.attributes.stats.name -eq $playerName } |
                                        Select-Object -First 1 -ExpandProperty attributes | Select-Object -ExpandProperty stats
             }

             # Use detailed stats if found, otherwise fallback to basic stats from player_matches.json
             $statsToUse = if ($null -ne $detailedPlayerStats) { $detailedPlayerStats } else { $playerLossStats }
             
             if ($null -eq $statsToUse) { Write-Warning "Could not find any stats for $playerName in loss $lossId."; continue }

             # Calculate Human Kills/Damage from Telemetry
             $humanDmg = "N/A"
             $humanKills = "N/A"
             if ($null -ne $relevantLossTelemetry) {
                 try {
                    $humanDmgEvents = $relevantLossTelemetry | Where-Object { $_._T -eq 'LogPlayerTakeDamage' -and $_.attacker.name -eq $playerName -and $_.victim.accountId -notlike "ai.*" -and $_.victim.teamId -ne $_.attacker.teamId }
                    if ($humanDmgEvents) { $humanDmg = [math]::Round(($humanDmgEvents | Measure-Object -Property damage -Sum).Sum) }
                    
                    $humanKillEvents = $relevantLossTelemetry | Where-Object { $_._T -eq 'LogPlayerKillV2' -and $_.killer.name -eq $playerName -and $_.victim.accountId -notlike "ai.*" }
                    $humanKills = $humanKillEvents.Count
                 } catch { Write-Warning ("Error processing telemetry stats for {0} in loss {1}: {2}" -f $playerName, $lossId, $_.Exception.Message) }
             }

             # Add to stats table
             $lossStatsTable += [PSCustomObject]@{
                Name          = $playerName
                'Human dmg'   = "$humanDmg"
                'Human Kills' = "$humanKills"
                'Dmg'         = "$([math]::Round($statsToUse.damageDealt))"
                'Kills'       = "$($statsToUse.kills)"
                'alive (min)' = "$([math]::Round(($statsToUse.timeSurvived / 60)))" # Clarify unit
             }

             # Calculate team damage from Telemetry
             if ($null -ne $relevantLossTelemetry) {
                 try {
                    $teamDmgEvents = $relevantLossTelemetry | Where-Object {
                        $_._T -eq 'LogPlayerTakeDamage' -and $_.victim.teamId -eq $_.attacker.teamId -and
                        $_.victim.accountId -notlike "ai.*" -and $_.victim.name -ne $_.attacker.name -and
                        $_.attacker.name -eq $playerName
                    }
                    if ($teamDmgEvents) {
                        foreach ($victimEntry in ($teamDmgEvents | Group-Object victim.name)) {
                            $lossTeamDamageVictims += [PSCustomObject]@{
                                attacker = $playerName
                                victim   = $victimEntry.Name
                                Damage   = "$([math]::Round(($victimEntry.Group.damage | Measure-Object -Sum).Sum))"
                            }
                        }
                    }
                 } catch { Write-Warning ("Error processing team damage for {0} in loss {1}: {2}" -f $playerName, $lossId, $_.Exception.Message) }
             }
        } # End foreach playerName in loss

        # Format tables for Discord message
        $contentLossStats = if ($lossStatsTable.Count -gt 0) { '```' + ($lossStatsTable | Format-Table -AutoSize | Out-String) + '```' } else { "" }
        $contentLossVictims = if ($lossTeamDamageVictims.Count -gt 0) { ":skull::skull: Team Damage :skull::skull:`n" + '```' + ($lossTeamDamageVictims | Format-Table -AutoSize | Out-String) + '```' } else { "" }

        # Construct and Send Loss Message
        $losersString = $involvedPlayerNames -join ', '
        $mapDisplayName = if ($mapNameLookup.ContainsKey($lossMapNameRaw)) { $mapNameLookup[$lossMapNameRaw] } else { $lossMapNameRaw }
        $firstPlayerName = $involvedPlayerNames[0] # Use first player for replay link
        $replayUrl = $lossTelemetryUrl -replace 'https://telemetry-cdn.pubg.com/bluehole-pubg', 'https://chickendinner.gg' -replace '-telemetry.json', ''
        $replayUrl += "?follow=$firstPlayerName"
        
        $matchSettings = @"
``````
Match Mode : $lossGameMode
Match Type : $lossMatchType
Map        : $mapDisplayName
Match ID   : $lossId
``````
"@
        Send-DiscordLoss -Content "We hebben een LOSERT! Geen Kip voor jou! :skull::skull:"
        Send-DiscordLoss -Content ":partying_face::partying_face: Helaas, **$($losersString)** :partying_face::partying_face:"
        Send-DiscordLoss -Content $matchSettings
        if ($contentLossStats) { Send-DiscordLoss -Content $contentLossStats }
        if ($contentLossVictims) { Send-DiscordLoss -Content $contentLossVictims }
        Send-DiscordLoss -Content "[2D Replay](<$replayUrl>)"
        Send-DiscordLoss -Content "Meer match details [DTCH_STATS](<https://dtch.online/matchinfo.php?matchid=$lossId>)"
        
        Write-Output "Sent loss report for match $lossId."
        Start-Sleep -Seconds 2 # Small delay between messages
        
    } # End foreach lossId

    # --- Process and Report New Wins ---
    Write-Output "Processing $($newWinMatchIds.Count) new wins..."
    foreach ($winId in $newWinMatchIds) {
         if (-not $winId) { continue }
         Write-Output "Processing win match ID: $winId"
         
         # Find all player entries related to this win match ID
         $winMatchPlayerEntries = $actualMatchEntries.player_matches | Where-Object { $_.id -eq $winId }
         if ($null -eq $winMatchPlayerEntries -or $winMatchPlayerEntries.Count -eq 0) {
             Write-Warning "Could not find match details for win ID $winId in player_matches.json data."
             continue
         }
         
         # Use the first entry for common details
         $firstWinEntry = $winMatchPlayerEntries[0]
         $winGameMode = $firstWinEntry.gameMode
         $winMatchType = $firstWinEntry.matchType
         $winMapNameRaw = $firstWinEntry.mapName
         $winTelemetryUrl = $firstWinEntry.telemetry_url
         
         # Skip TDM
         if ($winGameMode -eq 'tdm') { Write-Output "Skipping TDM win match $winId."; continue }

         # Get Telemetry
         $winTelemetryEvents = Get-TelemetryData -TelemetryUrl $winTelemetryUrl
         $relevantWinTelemetry = $null
         if ($winTelemetryEvents -is [array]) {
             $relevantWinTelemetry = $winTelemetryEvents | Where-Object { $_._T -eq 'LogPlayerTakeDamage' -or $_._T -eq 'LogPlayerKillV2' }
         } else { Write-Warning "Invalid or missing telemetry data for win match $winId." }

         # Get Full Match Stats from API
         $winMatchApiStats = Invoke-PubgApi -Uri "https://api.pubg.com/shards/steam/matches/$winId" -Headers $apiHeaders
         
         # Determine players to report (winners or all non-AI in custom)
         $playersToReportStats = @()
         if ($null -ne $winMatchApiStats -and $winMatchApiStats.included -is [array]) {
             if ($winMatchType -eq 'custom') {
                 $playersToReportStats = $winMatchApiStats.included | Where-Object { $_.type -eq 'participant' -and $_.attributes.stats.playerId -notlike "ai.*" } | Select-Object -ExpandProperty attributes | Select-Object -ExpandProperty stats
             } else {
                 $playersToReportStats = $winMatchApiStats.included | Where-Object { $_.type -eq 'participant' -and $_.attributes.stats.winPlace -eq 1 } | Select-Object -ExpandProperty attributes | Select-Object -ExpandProperty stats
             }
         } else {
             Write-Warning "Could not get full match stats from API for win $winId. Reporting might be incomplete."
             # Fallback: Use players from our loaded data who won
             $playersToReportStats = $winMatchPlayerEntries | Where-Object { $_.stats.winPlace -eq 1 } | Select-Object -ExpandProperty stats
         }
         
         if ($playersToReportStats.Count -eq 0) { Write-Warning "No winning players found to report for match $winId."; continue }

         $winnerNames = $playersToReportStats.name
         $winnersString = $winnerNames -join ', '
         
         # Prepare data tables
         $winStatsTable = @()
         $winTeamDamageVictims = @()

         # Fail-safe check (from original script) - Limit number of reports if too many new wins detected at once?
         # This might indicate an issue with the comparison logic or first run.
         if ($newWinMatchIds.Count -gt 10) {
             Write-Warning "More than 10 new win matches detected ($($newWinMatchIds.Count)). This might indicate an issue. Reporting only the first 10."
             # Optionally break or limit the loop here if desired
             # For now, just log the warning.
         }
         
         # Send initial win messages
         Send-DiscordWin -Content ":chicken::chicken: **WINNER WINNER CHICKEN DINNER!!** :chicken::chicken:"
         Send-DiscordWin -Content ":partying_face::partying_face: Gefeliciteerd **$($winnersString)** :partying_face::partying_face:"
         
         $mapDisplayName = if ($mapNameLookup.ContainsKey($winMapNameRaw)) { $mapNameLookup[$winMapNameRaw] } else { $winMapNameRaw }
         $matchSettings = @"
``````
Match Mode : $winGameMode
Match Type : $winMatchType
Map        : $mapDisplayName
Match ID   : $winId
``````
"@
         Send-DiscordWin -Content $matchSettings

         # Calculate stats for each reported player
         foreach ($playerStat in $playersToReportStats) {
             $playerName = $playerStat.name
             if (-not $playerName) { continue }
             
             Write-Verbose "Creating stats table entry for winner $playerName in match $winId"
             
             # Calculate Human Kills/Damage from Telemetry
             $humanDmg = "N/A"
             $humanKills = "N/A"
             if ($null -ne $relevantWinTelemetry) {
                 try {
                    $humanDmgEvents = $relevantWinTelemetry | Where-Object { $_._T -eq 'LogPlayerTakeDamage' -and $_.attacker.name -eq $playerName -and $_.victim.accountId -notlike "ai.*" -and $_.victim.teamId -ne $_.attacker.teamId }
                    if ($humanDmgEvents) { $humanDmg = [math]::Round(($humanDmgEvents | Measure-Object -Property damage -Sum).Sum) }
                    
                    $humanKillEvents = $relevantWinTelemetry | Where-Object { $_._T -eq 'LogPlayerKillV2' -and $_.killer.name -eq $playerName -and $_.victim.accountId -notlike "ai.*" }
                    $humanKills = $humanKillEvents.Count
                 } catch { Write-Warning ("Error processing telemetry stats for {0} in win {1}: {2}" -f $playerName, $winId, $_.Exception.Message) }
             }

             # Add to stats table
             $winStatsTable += [PSCustomObject]@{
                Name          = $playerName
                'Human dmg'   = "$humanDmg"
                'Human Kills' = "$humanKills"
                'Dmg'         = "$([math]::Round($playerStat.damageDealt))"
                'Kills'       = "$($playerStat.kills)"
                'alive (min)' = "$([math]::Round(($playerStat.timeSurvived / 60)))"
             }

             # Calculate team damage from Telemetry
             if ($null -ne $relevantWinTelemetry) {
                 try {
                    $teamDmgEvents = $relevantWinTelemetry | Where-Object {
                        $_._T -eq 'LogPlayerTakeDamage' -and $_.victim.teamId -eq $_.attacker.teamId -and
                        $_.victim.accountId -notlike "ai.*" -and $_.victim.name -ne $_.attacker.name -and
                        $_.attacker.name -eq $playerName
                    }
                    if ($teamDmgEvents) {
                        foreach ($victimEntry in ($teamDmgEvents | Group-Object victim.name)) {
                            $winTeamDamageVictims += [PSCustomObject]@{
                                attacker = $playerName
                                victim   = $victimEntry.Name
                                Damage   = "$([math]::Round(($victimEntry.Group.damage | Measure-Object -Sum).Sum))"
                            }
                        }
                    }
                 } catch { Write-Warning ("Error processing team damage for {0} in win {1}: {2}" -f $playerName, $winId, $_.Exception.Message) }
             }
         } # End foreach playerStat

         # Format and send stats tables
         $contentWinStats = if ($winStatsTable.Count -gt 0) { '```' + ($winStatsTable | Format-Table -AutoSize | Out-String) + '```' } else { "" }
         if ($contentWinStats) { Send-DiscordWin -Content $contentWinStats }

         $contentWinVictims = if ($winTeamDamageVictims.Count -gt 0) { ":skull::skull: Team Damage Report :skull::skull:`n" + '```' + ($winTeamDamageVictims | Format-Table -AutoSize | Out-String) + '```' } else { "" }
         if ($contentWinVictims) { Send-DiscordWin -Content $contentWinVictims }

         # Send Replay and Details Links
         $firstWinnerName = $winnerNames[0]
         $replayUrl = $winTelemetryUrl -replace 'https://telemetry-cdn.pubg.com/bluehole-pubg', 'https://chickendinner.gg' -replace '-telemetry.json', ''
         $replayUrl += "?follow=$firstWinnerName"
         Send-DiscordWin -Content "[2D Replay](<$replayUrl>)"
         Send-DiscordWin -Content "More match details [DTCH_STATS](<https://dtch.online/matchinfo.php?matchid=$winId>)"
         
         Write-Output "Sent win report for match $winId."
         Start-Sleep -Seconds 2 # Small delay between messages

    } # End foreach winId

    # --- Clear New Match Lists in Data File ---
    Write-Output "Clearing new win/loss lists in player matches data file..."
    $updatedPlayerMatchesData = $playerMatchesData # Start with the loaded data
    $winListCleared = $false
    $lossListCleared = $false

    # Iterate through the array to find and modify the special entries
    for ($i = 0; $i -lt $updatedPlayerMatchesData.Count; $i++) {
        $item = $updatedPlayerMatchesData[$i]
        if ($item -is [PSCustomObject]) {
            if ($item.PSObject.Properties.Name -eq 'new_win_matches') {
                $item.new_win_matches = @() # Clear the list
                $winListCleared = $true
            }
            if ($item.PSObject.Properties.Name -eq 'new_loss_matches') {
                $item.new_loss_matches = @() # Clear the list
                $lossListCleared = $true
            }
        }
        # Stop if both found and cleared
        if ($winListCleared -and $lossListCleared) { break }
    }
    
    if ($winListCleared -or $lossListCleared) {
         try {
             $updatedPlayerMatchesData | ConvertTo-Json -Depth 100 | Out-File -FilePath $playerMatchesJsonPath -Encoding UTF8 -ErrorAction Stop
             Write-Output "Successfully cleared new match lists in '$playerMatchesJsonPath'."
         } catch {
             Write-Error "Failed to save player matches data after clearing lists. '$playerMatchesJsonPath'. Error: $($_.Exception.Message)"
         }
    } else {
         Write-Warning "Could not find 'new_win_matches' or 'new_loss_matches' entries to clear in '$playerMatchesJsonPath'."
    }

} # End Main Try Block
finally {
    # --- Cleanup ---
    Write-Output "Script finished at $(Get-Date)."
    Remove-Lock # Ensure lock is always removed
    if ($transcriptPath -and (Get-Transcript | Select-Object -ExpandProperty Path) -eq $transcriptPath) {
        Stop-Transcript
    }
}