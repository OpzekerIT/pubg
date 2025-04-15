# --- Script Setup ---
Start-Transcript -Path '/var/log/dtch/matchparser.log' -Append
Write-Output "Starting matchparser script at $(Get-Date)"
Write-Output "Running from: $(Get-Location)"

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
$dataPath = Join-Path -Path $scriptRoot -ChildPath "..\data"
$killStatsPath = Join-Path -Path $dataPath -ChildPath "killstats"
$archivePath = Join-Path -Path $killStatsPath -ChildPath "archive" # Archive within killstats
$telemetryCachePath = Join-Path -Path $dataPath -ChildPath "telemetry_cache"
$playerMatchesJsonPath = Join-Path -Path $dataPath -ChildPath "player_matches.json"
$lastStatsJsonPath = Join-Path -Path $dataPath -ChildPath "player_last_stats.json"
$archiveDir = Join-Path -Path $dataPath -ChildPath "archive" # Separate archive for player_last_stats

# Ensure required directories exist
@( $dataPath, $killStatsPath, $archivePath, $telemetryCachePath, $archiveDir ) | ForEach-Object {
    if (-not (Test-Path -Path $_ -PathType Container)) {
        Write-Warning "Directory not found at '$_'. Attempting to create."
        try {
            New-Item -Path $_ -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Output "Successfully created directory: $_"
        } catch {
            Write-Error "Failed to create directory '$_'. Please check permissions. Error: $($_.Exception.Message)"
            Stop-Transcript
            exit 1
        }
    }
}

# --- Locking ---
$lockFilePath = Join-Path -Path $includesPath -ChildPath "lockfile.ps1"
if (-not (Test-Path -Path $lockFilePath -PathType Leaf)) {
    Write-Error "Lockfile script not found at '$lockFilePath'. Cannot proceed."
    Stop-Transcript
    exit 1
}
. $lockFilePath
New-Lock -by "matchparser" -ErrorAction Stop # Stop if locking fails

# --- Main Logic in Try/Finally for Lock Removal ---
try {
    # --- Settings ---
    $monthsBack = -3 # How many months back to look for matches for aggregation
    Write-Output "Using monthsBack setting: $monthsBack"

    # --- Helper Functions ---
    function Get-Change {
        param (
            [double]$OldWinRatio,
            [double]$NewWinRatio
        )
        # Ensure inputs are treated as numbers, default to 0 if null/invalid
        $old = if ($OldWinRatio -is [double]) { $OldWinRatio } else { 0.0 }
        $new = if ($NewWinRatio -is [double]) { $NewWinRatio } else { 0.0 }

        # Calculate change: If old is 0, change is simply the new ratio. Otherwise, it's the difference.
        $change = ($old -eq 0) ? $new : ($new - $old)
        return [math]::Round($change, 2)
    }

    function Get-WinRatio {
        param (
            [int]$playerWins,
            [int]$playerMatches
        )
        if ($playerMatches -gt 0) {
            # Calculate win ratio percentage
            return [math]::Round(($playerWins / $playerMatches) * 100, 2) # Round percentage
        } else {
            return 0.0 # Return 0.0 for consistency if no matches played
        }
    }

    function Get-KillStatsFromTelemetry {
        param (
            [string]$playerName,
            [array]$telemetryEvents, # Expecting pre-filtered events
            [string]$matchType,
            [string]$gameMode
        )
        
        # Validate input
        if (-not $playerName -or $null -eq $telemetryEvents) {
            Write-Warning "Get-KillStatsFromTelemetry: Invalid input (PlayerName or TelemetryEvents)."
            return $null
        }

        # Filter relevant events once
        $killEvents = $telemetryEvents | Where-Object { $_._T -eq 'LogPlayerKillV2' }
        $damageEvents = $telemetryEvents | Where-Object { $_._T -eq 'LogPlayerTakeDamage' }

        # Calculate Kills
        $playerKills = $killEvents | Where-Object { $null -ne $_.killer -and $_.killer.name -eq $playerName }
        $totalKillsCount = $playerKills.Count
        $humanKillsCount = ($playerKills | Where-Object { $null -ne $_.victim -and $_.victim.accountId -notlike 'ai.*' }).Count
        $dbnoCount = ($playerKills | Where-Object { $null -ne $_.dBNOId }).Count # Check if DBNO event exists

        # Calculate Deaths (where player is victim and finished by someone)
        # Note: Finisher check might be complex depending on data structure, adjust if needed
        $playerDeaths = $killEvents | Where-Object { $null -ne $_.victim -and $_.victim.name -eq $playerName -and $null -ne $_.finisher }
        $deathsCount = $playerDeaths.Count

        # Calculate Human Damage Dealt
        $humanDamageDealt = 0
        try {
             $humanDamageEvents = $damageEvents | Where-Object {
                $null -ne $_.attacker -and $_.attacker.name -eq $playerName -and
                $null -ne $_.victim -and $_.victim.accountId -notlike "ai.*" -and
                $_.victim.teamId -ne $_.attacker.teamId
             }
             if ($humanDamageEvents) {
                 $humanDamageDealt = ($humanDamageEvents | Measure-Object -Property damage -Sum).Sum
             }
        } catch {
             $errorMessage = $_.Exception.Message
             Write-Warning ("Error calculating HumanDmg for {0}: {1}" -f $playerName, $errorMessage)
        }
       
        return @{
            playername = $playerName
            humankills = $humanKillsCount
            kills      = $totalKillsCount
            deaths     = $deathsCount # Note: This counts finishes, might differ from match end death reason
            gameMode   = $gameMode
            matchType  = $matchType
            dbno       = $dbnoCount
            HumanDmg   = [math]::Round($humanDamageDealt) # Round final value
        }
    }

    # --- Load Old Stats Archive ---
    $oldStats = $null
    $latestArchivePath = $null
    try {
        $archiveFiles = Get-ChildItem -Path $archiveDir -Filter "*_player_last_stats.json" -File -ErrorAction SilentlyContinue
        if ($archiveFiles) {
            # Find the most recent archive file based on filename date
            $latestArchiveFile = $archiveFiles | Sort-Object -Property Name -Descending | Select-Object -First 1
            $latestArchivePath = $latestArchiveFile.FullName
            Write-Output "Attempting to load old stats from: $latestArchivePath"
            $oldStats = Get-Content -Path $latestArchivePath | ConvertFrom-Json -ErrorAction Stop
            if ($null -eq $oldStats) {
                 Write-Warning "Failed to parse old stats file: $latestArchivePath"
            } else {
                 Write-Output "Successfully loaded old stats."
            }
        } else {
            Write-Output "No old stats archive files found in '$archiveDir'."
        }
    } catch {
        Write-Warning "Error accessing or processing archive directory '$archiveDir': $($_.Exception.Message)"
        $oldStats = $null # Ensure it's null on error
    }
    # Use an empty hashtable if old stats couldn't be loaded, to prevent errors later
    if ($null -eq $oldStats) {
        Write-Output "Initializing old stats as empty."
        $oldStats = @{}
    }


    # --- Load Current Player Matches ---
    $allPlayerMatches = $null
    if (Test-Path -Path $playerMatchesJsonPath -PathType Leaf) {
        try {
            $allPlayerMatches = Get-Content -Path $playerMatchesJsonPath | ConvertFrom-Json -Depth 100 -ErrorAction Stop
            if ($null -eq $allPlayerMatches -or -not ($allPlayerMatches -is [array])) {
                 Write-Error "Failed to parse or invalid structure in '$playerMatchesJsonPath'. Cannot proceed."
                 throw "Invalid player matches data." # Throw to trigger finally block
            }
            Write-Output "Successfully loaded player matches data. Entry count: $($allPlayerMatches.Count)"
        } catch {
            Write-Error "Error reading '$playerMatchesJsonPath': $($_.Exception.Message). Cannot proceed."
            throw $_ # Re-throw to trigger finally block
        }
    } else {
        Write-Error "Player matches file not found at '$playerMatchesJsonPath'. Cannot proceed."
        throw "Missing player matches file." # Throw to trigger finally block
    }

    # --- Process Matches & Generate Kill Stats ---
    Write-Output "Starting match processing and kill stat generation..."
    $processedMatchCount = 0
    $telemetryDownloads = 0
    $telemetryCacheHits = 0
    $killStatFilesWritten = 0

    # Extract player list (excluding special entries like 'new_win_matches')
    $playersToProcess = $allPlayerMatches | Where-Object { $_.PSObject.Properties.Name -ne 'new_win_matches' -and $_.PSObject.Properties.Name -ne 'new_loss_matches' -and $null -ne $_.playername }

    foreach ($playerEntry in $playersToProcess) {
        $playerName = $playerEntry.playername
        if (-not $playerName) {
             Write-Warning "Skipping player entry with missing name."
             continue
        }
        
        if ($null -eq $playerEntry.player_matches -or -not ($playerEntry.player_matches -is [array])) {
            Write-Warning "Skipping player $playerName due to missing or invalid 'player_matches' array."
            continue
        }

        foreach ($match in $playerEntry.player_matches) {
            # Validate essential match data
            $matchId = $match.id
            $telemetryUrl = $match.telemetry_url
            $matchCreatedAt = $match.createdAt
            $matchGameMode = $match.gameMode
            $matchType = $match.matchType
            $matchStats = $match.stats # Player-specific stats within this match entry

            if (-not $matchId -or -not $telemetryUrl -or -not $matchCreatedAt -or -not $matchStats) {
                Write-Warning "Skipping match for player $playerName due to missing ID, Telemetry URL, Creation Date, or Stats."
                continue
            }
            
            Write-Verbose "Analyzing match $matchId for player $playerName"
            $processedMatchCount++
            $killStatFilePath = Join-Path -Path $killStatsPath -ChildPath "${matchId}_${playerName}.json"

            if (Test-Path -Path $killStatFilePath -PathType Leaf) {
                Write-Verbose "Kill stats file already exists: $killStatFilePath"
                continue # Skip if already processed
            }

            # Get Telemetry Data (Download or Cache)
            $telemetry = $null
            $telemetryFileName = $telemetryUrl.Split('/')[-1]
            $telemetryCacheFilePath = Join-Path -Path $telemetryCachePath -ChildPath $telemetryFileName
            
            if (Test-Path -Path $telemetryCacheFilePath -PathType Leaf) {
                Write-Verbose "Loading telemetry from cache: $telemetryCacheFilePath"
                try {
                    $telemetry = Get-Content -Path $telemetryCacheFilePath | ConvertFrom-Json -ErrorAction Stop
                    if ($null -eq $telemetry) { Write-Warning "Failed to parse cached telemetry: $telemetryCacheFilePath" }
                    else { $telemetryCacheHits++ }
                } catch {
                    Write-Warning "Error reading cached telemetry '$telemetryCacheFilePath': $($_.Exception.Message)"
                }
            }
            
            if ($null -eq $telemetry) {
                 # Download telemetry if not cached or cache read failed
                Write-Output ("Downloading telemetry for match {0}: {1}" -f $matchId, $telemetryUrl)
                try {
                    # Add User-Agent
                    $headers = @{ 'Accept-Encoding' = 'gzip' } # Request compression
                    $response = Invoke-WebRequest -Uri $telemetryUrl -Headers $headers -UseBasicParsing -ErrorAction Stop
                    $telemetryContent = $response.Content # Content is automatically decompressed
                    
                    # Save to cache
                    $telemetryContent | Out-File -FilePath $telemetryCacheFilePath -Encoding UTF8 -ErrorAction SilentlyContinue
                    $telemetryDownloads++

                    # Parse downloaded content
                    $telemetry = $telemetryContent | ConvertFrom-Json -ErrorAction Stop
                    if ($null -eq $telemetry) { Write-Warning "Failed to parse downloaded telemetry for match $matchId." }

                } catch {
                    $errorMessage = $_.Exception.Message # Assign to variable first
                    Write-Warning "Failed to download or save telemetry for match $matchId. URL: $telemetryUrl. Error: $errorMessage" # Use variable in string
                    # Continue to next match if telemetry fails
                    continue
                }
            }

            # Process Telemetry if successfully loaded/downloaded
            if ($null -ne $telemetry -and ($telemetry -is [array])) {
                 Write-Verbose "Analyzing telemetry for player $playerName in match $matchId"
                 # Filter relevant telemetry events once
                 $relevantTelemetry = $telemetry | Where-Object { $_._T -eq 'LogPlayerTakeDamage' -or $_._T -eq 'LogPlayerKillV2' }
                 
                 $killStatResult = Get-KillStatsFromTelemetry -playerName $playerName -telemetryEvents $relevantTelemetry -gameMode $matchGameMode -matchType $matchType
                 
                 if ($null -ne $killStatResult) {
                    # Find player's win place and death type from the original match data
                    $playerMatchStats = $allPlayerMatches |
                                        Select-Object -ExpandProperty player_matches |
                                        Where-Object { $_.id -eq $matchId } |
                                        Select-Object -ExpandProperty stats |
                                        Where-Object { $_.name -eq $playerName } |
                                        Select-Object -First 1

                    $deathType = $playerMatchStats.deathType ?? "unknown"
                    $winPlace = $playerMatchStats.winPlace ?? 0

                    $saveKillStats = @{
                        matchid   = $matchId
                        created   = $matchCreatedAt # Use original timestamp
                        stats     = $killStatResult
                        deathType = $deathType
                        winplace  = $winPlace
                    }
                    
                    # Save the individual kill stat file
                    try {
                        $saveKillStats | ConvertTo-Json -Depth 5 | Out-File -FilePath $killStatFilePath -Encoding UTF8 -ErrorAction Stop
                        Write-Output "Written kill stats file: $killStatFilePath"
                        $killStatFilesWritten++
                    } catch {
                        Write-Warning "Failed to write kill stats file '$killStatFilePath'. Error: $($_.Exception.Message)"
                    }
                 } else {
                     Write-Warning "Get-KillStatsFromTelemetry returned null for $playerName in match $matchId."
                 }
            } else {
                 Write-Warning "Telemetry data for match $matchId is null or not an array after loading/downloading."
            }
        } # End foreach match
    } # End foreach playerEntry
    Write-Output "Finished match processing. Processed: $processedMatchCount matches. Telemetry Downloads: $telemetryDownloads, Cache Hits: $telemetryCacheHits. Kill Stats Files Written: $killStatFilesWritten."

    # --- Aggregate Kill Stats & Archive Old Files ---
    Write-Output "Aggregating kill stats and archiving old files..."
    $currentKillStats = @()
    $killStatsClanMatchesGt1 = @() # Renamed for clarity
    # $killStatsClanMatchesGt2 = @() # Not used later, commented out
    # $killStatsClanMatchesGt3 = @() # Not used later, commented out
    $archivedKillStatFiles = 0
    $processedKillStatFiles = 0

    try {
        $matchFiles = Get-ChildItem -Path $killStatsPath -File -Filter *.json -ErrorAction SilentlyContinue
        if ($null -eq $matchFiles) {
             Write-Warning "No kill stat files found in '$killStatsPath'."
        } else {
            # Determine date threshold for archiving
            $archiveThresholdDate = (Get-Date).AddMonths($monthsBack)
            Write-Output "Archiving kill stat files older than: $archiveThresholdDate"

            # Group files by match ID to count clan participation
            $groupedFiles = $matchFiles | Group-Object -Property { $_.Name.Split('_')[0] }
            $matchIdsWithClanGt1 = ($groupedFiles | Where-Object { $_.Count -gt 1 }).Name

            foreach ($file in $matchFiles) {
                $processedKillStatFiles++
                try {
                    $json = Get-Content -Path $file.FullName | ConvertFrom-Json -ErrorAction Stop
                    if ($null -eq $json -or $null -eq $json.created -or $null -eq $json.matchid) {
                        Write-Warning "Skipping invalid or incomplete kill stat file: $($file.Name)"
                        continue
                    }

                    # Attempt to parse the date string
                    $fileDate = $null
                    try { $fileDate = [datetime]$json.created } catch { Write-Warning "Could not parse date '$($json.created)' in file $($file.Name)" }

                    if ($null -ne $fileDate -and $fileDate -ge $archiveThresholdDate) {
                        # Keep stats if within date range
                        $currentKillStats += $json
                        # Add to clan participation list if applicable
                        if ($matchIdsWithClanGt1 -contains $json.matchid) {
                            $killStatsClanMatchesGt1 += $json
                        }
                    } else {
                        # Archive old file
                        Write-Verbose "Archiving $($file.Name)"
                        Move-Item -Path $file.FullName -Destination $archivePath -Force -ErrorAction SilentlyContinue # Continue if move fails
                        if ($?) { $archivedKillStatFiles++ }
                        else { Write-Warning "Failed to archive file: $($file.Name)" }
                    }
                } catch {
                    Write-Warning "Error processing kill stat file '$($file.Name)': $($_.Exception.Message)"
                }
            } # End foreach file
            Write-Output "Processed $processedKillStatFiles kill stat files. Archived: $archivedKillStatFiles. Kept: $($currentKillStats.Count)."
        }
    } catch {
        Write-Warning "Error reading kill stats directory '$killStatsPath': $($_.Exception.Message)"
    }


    # --- Calculate Player Stats per Category ---
    Write-Output "Calculating aggregated player stats per category..."
    
    # Define function locally for clarity, even if slightly redundant
    function Get-AggregatedMatchStatsPlayer {
        param (
            [Parameter(Mandatory=$true)]
            [switch]$FilterByGameMode, # Use specific parameter names
            [Parameter(Mandatory=$true)]
            [switch]$FilterByMatchType,
            [Parameter(Mandatory=$true)]
            [string]$FilterValue, # Value for gameMode or matchType
            [Parameter(Mandatory=$true)]
            [array]$PlayerNames,
            [Parameter(Mandatory=$true)]
            [string]$CategoryFriendlyName, # Key for looking up old stats
            [Parameter(Mandatory=$true)]
            [array]$KillStatsToAggregate, # The array of kill stat objects
            [Parameter(Mandatory=$true)]
            [string]$SortStat,
            [Parameter(Mandatory=$true)]
            [hashtable]$OldStatsData # Pass old stats explicitly
        )
        
        $aggregatedStatsList = @()
        
        # Determine the property to filter on based on parameters
        $filterProperty = $null
        if ($FilterByGameMode) { $filterProperty = 'gameMode' }
        elseif ($FilterByMatchType) { $filterProperty = 'matchType' }
        else { Write-Error "Get-AggregatedMatchStatsPlayer: Must specify -FilterByGameMode or -FilterByMatchType."; return $null }

        foreach ($player in $PlayerNames) {
            if (-not $player) { continue } # Skip null/empty player names

            # Filter kill stats for the current player and category
            $playerKillStats = $KillStatsToAggregate | Where-Object {
                $_.stats -ne $null -and
                $_.stats.playername -eq $player -and
                $_.stats.$filterProperty -like $FilterValue # Use -like for wildcard support if needed (e.g., '*')
            }
            
            $playerMatchCount = $playerKillStats.Count
            if ($playerMatchCount -eq 0) { continue } # Skip player if no stats in this category

            # Aggregate stats using Measure-Object where possible
            $totalWins = ($playerKillStats | Where-Object { $_.winplace -eq 1 }).Count
            $totalDeaths = ($playerKillStats | Where-Object { $_.deathType -ne 'alive' }).Count # Assuming 'alive' means survived
            $totalKills = ($playerKillStats.stats.kills | Measure-Object -Sum -ErrorAction SilentlyContinue).Sum
            $totalHumanKills = ($playerKillStats.stats.humankills | Measure-Object -Sum -ErrorAction SilentlyContinue).Sum
            $totalDbno = ($playerKillStats.stats.dbno | Measure-Object -Sum -ErrorAction SilentlyContinue).Sum
            $totalHumanDmg = ($playerKillStats.stats.HumanDmg | Measure-Object -Sum -ErrorAction SilentlyContinue).Sum

            # Calculate Ratios (Handle division by zero)
            $kdHuman = if ($totalDeaths -gt 0) { [math]::Round($totalHumanKills / $totalDeaths, 2) } else { $totalHumanKills } # Or "Infinity" string
            $kdAll = if ($totalDeaths -gt 0) { [math]::Round($totalKills / $totalDeaths, 2) } else { $totalKills } # Or "Infinity" string
            $avgHumanDmg = if ($playerMatchCount -gt 0) { [math]::Round($totalHumanDmg / $playerMatchCount, 2) } else { 0.0 }
            
            # Calculate Win Ratio and Change
            $currentWinRatio = Get-WinRatio -playerWins $totalWins -playerMatches $playerMatchCount
            $oldWinRatio = $null
            # Safely access old stats
            if ($OldStatsData.ContainsKey($CategoryFriendlyName)) {
                 $oldCategoryStats = $OldStatsData[$CategoryFriendlyName]
                 $playerOldStat = $oldCategoryStats | Where-Object { $_.playername -eq $player } | Select-Object -First 1
                 if ($playerOldStat -and $playerOldStat.PSObject.Properties.Name -contains 'winratio') {
                     # Attempt conversion, default to 0.0 if fails
                     try { $oldWinRatio = [double]$playerOldStat.winratio } catch { $oldWinRatio = 0.0 }
                 }
            }
            $winRatioChange = Get-Change -OldWinRatio $oldWinRatio -NewWinRatio $currentWinRatio

            Write-Verbose "Stats for $player [$CategoryFriendlyName]: Matches=$playerMatchCount, Wins=$totalWins, Deaths=$totalDeaths, Kills=$totalKills, HKills=$totalHumanKills, AHD=$avgHumanDmg, Win%=$currentWinRatio, Change=$winRatioChange"

            $aggregatedStatsList += [PSCustomObject]@{
                playername = $player
                deaths     = $totalDeaths
                kills      = $totalKills
                humankills = $totalHumanKills
                matches    = $playerMatchCount
                KD_H       = $kdHuman
                KD_ALL     = $kdAll
                winratio   = $currentWinRatio
                wins       = $totalWins
                dbno       = $totalDbno
                change     = $winRatioChange # Store the calculated change
                ahd        = $avgHumanDmg
            }
        } # End foreach player

        # Sort the results
        if ($aggregatedStatsList.Count -gt 0 -and $SortStat) {
             try {
                 # Add random key for stable sort behavior if primary sort keys are equal
                 $aggregatedStatsList = $aggregatedStatsList | ForEach-Object {
                     $_ | Add-Member -NotePropertyName RandomKey -NotePropertyValue (Get-Random) -PassThru
                 } | Sort-Object -Property $SortStat, RandomKey -Descending | Select-Object -Property * -ExcludeProperty RandomKey
             } catch {
                  Write-Warning "Failed to sort aggregated stats by '$SortStat'. Error: $($_.Exception.Message)"
             }
        }
        
        return $aggregatedStatsList
    } # End function Get-AggregatedMatchStatsPlayer

    # Get list of unique player names from the loaded match data
    $uniquePlayerNames = ($playersToProcess.playername | Select-Object -Unique)

    # Calculate stats for each category
    $playerStatsEventIbr = Get-AggregatedMatchStatsPlayer -FilterByGameMode -FilterValue 'ibr' -PlayerNames $uniquePlayerNames -CategoryFriendlyName 'Intense' -KillStatsToAggregate $currentKillStats -SortStat 'ahd' -OldStatsData $oldStats
    $playerStatsAiRoyale = Get-AggregatedMatchStatsPlayer -FilterByMatchType -FilterValue 'airoyale' -PlayerNames $uniquePlayerNames -CategoryFriendlyName 'Casual' -KillStatsToAggregate $currentKillStats -SortStat 'ahd' -OldStatsData $oldStats
    $playerStatsOfficial = Get-AggregatedMatchStatsPlayer -FilterByMatchType -FilterValue 'official' -PlayerNames $uniquePlayerNames -CategoryFriendlyName 'official' -KillStatsToAggregate $currentKillStats -SortStat 'ahd' -OldStatsData $oldStats
    $playerStatsCustom = Get-AggregatedMatchStatsPlayer -FilterByMatchType -FilterValue 'custom' -PlayerNames $uniquePlayerNames -CategoryFriendlyName 'custom' -KillStatsToAggregate $currentKillStats -SortStat 'ahd' -OldStatsData $oldStats
    $playerStatsAll = Get-AggregatedMatchStatsPlayer -FilterByMatchType -FilterValue '*' -PlayerNames $uniquePlayerNames -CategoryFriendlyName 'all' -KillStatsToAggregate $currentKillStats -SortStat 'ahd' -OldStatsData $oldStats
    $playerStatsRanked = Get-AggregatedMatchStatsPlayer -FilterByMatchType -FilterValue 'competitive' -PlayerNames $uniquePlayerNames -CategoryFriendlyName 'Ranked' -KillStatsToAggregate $currentKillStats -SortStat 'ahd' -OldStatsData $oldStats
    $playerStatsAiRoyaleClanGt1 = Get-AggregatedMatchStatsPlayer -FilterByMatchType -FilterValue 'airoyale' -PlayerNames $uniquePlayerNames -CategoryFriendlyName 'Casual' -KillStatsToAggregate $killStatsClanMatchesGt1 -SortStat 'ahd' -OldStatsData $oldStats # Use filtered killstats

    # Apply specific sorting if needed (e.g., custom by winratio)
    if ($playerStatsCustom) {
        $playerStatsCustom = $playerStatsCustom | Sort-Object winratio -Descending
    }

    # --- Save Aggregated Stats ---
    Write-Output "Saving aggregated player stats..."
    $currentDateTime = Get-Date
    $currentTimezone = (Get-TimeZone).Id
    $formattedString = "$currentDateTime - Time Zone: $currentTimezone"

    $playerStatsOutput = [PSCustomObject]@{
        all         = $playerStatsAll
        clan_casual = $playerStatsAiRoyaleClanGt1
        Intense     = $playerStatsEventIbr
        Casual      = $playerStatsAiRoyale
        official    = $playerStatsOfficial
        custom      = $playerStatsCustom
        updated     = $formattedString
        Ranked      = $playerStatsRanked
    }

    # Save to current stats file
    try {
        $playerStatsOutput | ConvertTo-Json -Depth 10 | Out-File -FilePath $lastStatsJsonPath -Encoding UTF8 -ErrorAction Stop
        Write-Output "Aggregated stats saved to '$lastStatsJsonPath'"
    } catch {
        Write-Warning "Failed to save aggregated stats to '$lastStatsJsonPath'. Error: $($_.Exception.Message)"
    }

    # Save to archive file
    $archiveFileNameDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH-mm-ssZ") -replace ":", "-"
    $archiveFilePath = Join-Path -Path $archiveDir -ChildPath "${archiveFileNameDate}_player_last_stats.json"
    try {
        Write-Output "Archiving aggregated stats to: $archiveFilePath"
        $playerStatsOutput | ConvertTo-Json -Depth 10 | Out-File -FilePath $archiveFilePath -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Warning "Failed to archive aggregated stats to '$archiveFilePath'. Error: $($_.Exception.Message)"
    }

    # --- Clean Telemetry Cache ---
    Write-Output "Cleaning telemetry cache..."
    try {
        # Get telemetry URLs from the *currently loaded* player matches data
        $activeTelemetryUrls = ($allPlayerMatches | Select-Object -ExpandProperty player_matches).telemetry_url | Select-Object -Unique
        $filesToKeep = $activeTelemetryUrls | ForEach-Object { if ($_) { $_.Split('/')[-1] } } # Get just the filenames

        $cachedFiles = Get-ChildItem -Path $telemetryCachePath -File -ErrorAction SilentlyContinue

        if ($cachedFiles) {
            $filesToRemove = Compare-Object -ReferenceObject $filesToKeep -DifferenceObject $cachedFiles.Name -PassThru | Where-Object { $_ -ne $null }
            
            $removedCount = 0
            foreach ($fileToRemoveName in $filesToRemove) {
                $fileToRemovePath = Join-Path -Path $telemetryCachePath -ChildPath $fileToRemoveName
                Write-Verbose "Removing cached telemetry file: $fileToRemovePath"
                Remove-Item -Path $fileToRemovePath -Force -ErrorAction SilentlyContinue
                if ($?) { $removedCount++ }
                else { Write-Warning "Failed to remove cache file: $fileToRemovePath" }
            }
            Write-Output "Telemetry cache cleanup complete. Removed $removedCount files."
        } else {
            Write-Output "Telemetry cache directory is empty or inaccessible."
        }
    } catch {
        Write-Warning "Error during telemetry cache cleanup: $($_.Exception.Message)"
    }

    Write-Output "Match parsing and aggregation complete."

} # End Main Try Block
finally {
    # --- Cleanup ---
    Write-Output "Script finished at $(Get-Date)."
    Remove-Lock # Ensure lock is always removed
    Stop-Transcript
}