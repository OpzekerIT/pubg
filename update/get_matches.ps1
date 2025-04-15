# --- Script Setup ---
Start-Transcript -Path '/var/log/dtch/get_matches.log' -Append
Write-Output "Starting get_matches script at $(Get-Date)"
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
$configPath = Join-Path -Path $scriptRoot -ChildPath "..\config"
$dataPath = Join-Path -Path $scriptRoot -ChildPath "..\data"
$matchesPath = Join-Path -Path $dataPath -ChildPath "matches"
$matchesArchivePath = Join-Path -Path $matchesPath -ChildPath "archive"
$playerDataJsonPath = Join-Path -Path $dataPath -ChildPath "player_data.json"
$playerMatchesJsonPath = Join-Path -Path $dataPath -ChildPath "player_matches.json"
$cachedMatchesJsonPath = Join-Path -Path $dataPath -ChildPath "cached_matches.json"

# Ensure required directories exist
@( $dataPath, $matchesPath, $matchesArchivePath ) | ForEach-Object {
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
New-Lock -by "get_matches" -ErrorAction Stop # Stop if locking fails

# --- Main Logic in Try/Finally for Lock Removal ---
try {
    # --- Configuration Loading ---
    $apiKey = $null
    $clanMembers = @() # Renamed from $players for clarity

    # Load API Key from config.php
    $phpConfigPath = Join-Path -Path $configPath -ChildPath "config.php"
    if (Test-Path -Path $phpConfigPath -PathType Leaf) {
        try {
            $fileContent = Get-Content -Path $phpConfigPath -Raw -ErrorAction Stop
            # Corrected regex for apiKey
            if ($fileContent -match '^\s*\$apiKey\s*=\s*''([^'']+)''') {
                $apiKey = $matches[1]
                Write-Output "API Key loaded successfully."
            } else {
                Write-Warning "API Key pattern not found in '$phpConfigPath'."
            }
        } catch {
            Write-Warning "Failed to read '$phpConfigPath'. Error: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "Config file not found at '$phpConfigPath'."
    }

    if (-not $apiKey) {
        Write-Error "API Key could not be loaded. Cannot proceed without API Key."
        throw "Missing API Key" # Throw to trigger finally block
    }

    # Load Clan Members from clanmembers.json
    $clanMembersJsonPath = Join-Path -Path $configPath -ChildPath "clanmembers.json"
    if (Test-Path -Path $clanMembersJsonPath -PathType Leaf) {
        try {
            $clanMembersData = Get-Content -Path $clanMembersJsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
            if ($clanMembersData -is [PSCustomObject] -and $clanMembersData.PSObject.Properties.Name -contains 'clanMembers' -and $clanMembersData.clanMembers -is [array]) {
                 $clanMembers = $clanMembersData.clanMembers
                 Write-Output "Clan members loaded successfully. Count: $($clanMembers.Count)"
            } else {
                 Write-Warning "Invalid structure in '$clanMembersJsonPath'. Expected an object with a 'clanMembers' array."
            }
        } catch {
            Write-Warning "Failed to read or parse '$clanMembersJsonPath'. Error: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "Clan members file not found at '$clanMembersJsonPath'."
    }

    if ($clanMembers.Count -eq 0) {
        Write-Warning "No clan members loaded. Proceeding, but cached matches might be incomplete."
        # Decide if this is a fatal error or not
    }

    # --- Helper Function for API Calls (Copied from update_clan_members.ps1) ---
    function Invoke-PubgApi {
        param(
            [Parameter(Mandatory=$true)]
            [string]$Uri,
            [Parameter(Mandatory=$true)]
            [hashtable]$Headers,
            [int]$RetryCount = 1,
            [int]$RetryDelaySeconds = 61
        )
        for ($attempt = 1; $attempt -le ($RetryCount + 1); $attempt++) {
            try {
                Write-Verbose "Attempting API call (Attempt $($attempt)): $Uri"
                $response = Invoke-RestMethod -Uri $Uri -Method GET -Headers $Headers -ErrorAction Stop
                if ($null -ne $response) { Write-Verbose "API call successful."; return $response }
                else { Write-Warning "API call to $Uri returned null or empty response."; return $null }
            } catch {
                $statusCode = $_.Exception.Response.StatusCode.value__
                $errorMessage = $_.Exception.Message
                Write-Warning "API call failed (Attempt $($attempt)). Status: $statusCode. Error: $errorMessage"
                if ($attempt -le $RetryCount -and $statusCode -eq 429) {
                    Write-Warning "Rate limit hit. Sleeping for $RetryDelaySeconds seconds before retry..."
                    Start-Sleep -Seconds $RetryDelaySeconds
                } elseif ($attempt -gt $RetryCount) { Write-Error "API call failed after $($attempt) attempts. URI: $Uri. Last Error: $errorMessage"; return $null }
                else { Write-Error "Non-retryable API error. URI: $Uri. Error: $errorMessage"; return $null }
            }
        }
        return $null
    }

    # --- Load Player Data (IDs and Match Lists) ---
    $playerData = $null
    if (Test-Path -Path $playerDataJsonPath -PathType Leaf) {
        try {
            # Assuming player_data.json contains an object with a 'data' array property
            $playerDataWrapper = Get-Content -Path $playerDataJsonPath | ConvertFrom-Json -Depth 100 -ErrorAction Stop
            if ($null -ne $playerDataWrapper -and $playerDataWrapper.PSObject.Properties.Name -contains 'data' -and $playerDataWrapper.data -is [array]) {
                 $playerData = $playerDataWrapper.data
                 Write-Output "Successfully loaded player data. Count: $($playerData.Count)"
            } else {
                 Write-Error "Invalid structure in '$playerDataJsonPath'. Expected object with 'data' array. Cannot proceed."
                 throw "Invalid player data structure."
            }
        } catch {
            Write-Error "Error reading '$playerDataJsonPath': $($_.Exception.Message). Cannot proceed."
            throw $_
        }
    } else {
        Write-Error "Player data file not found at '$playerDataJsonPath'. Run update_clan_members.ps1 first. Cannot proceed."
        throw "Missing player data file."
    }

    # --- Fetch and Process Matches for Each Player ---
    Write-Output "Fetching and processing matches for $($playerData.Count) players..."
    $allPlayerMatchDetails = @() # Store processed match details for all players
    $apiHeaders = @{
        'accept'        = 'application/vnd.api+json'
        'Authorization' = "Bearer $apiKey"
    }
    $matchesFetched = 0
    $matchesCached = 0

    foreach ($player in $playerData) {
        # Validate player structure
        if ($null -eq $player.attributes -or $null -eq $player.attributes.name -or $null -eq $player.relationships.matches.data) {
            Write-Warning "Skipping player due to missing attributes, name, or match data: $($player | Out-String)"
            continue
        }
        $playerName = $player.attributes.name
        $playerMatchIds = $player.relationships.matches.data.id
        Write-Output "Processing player: $playerName ($($playerMatchIds.Count) recent matches)"

        $currentPlayerMatches = @()
        foreach ($matchId in $playerMatchIds) {
            if (-not $matchId) { Write-Warning "Skipping null/empty match ID for player $playerName."; continue }
            
            Write-Verbose "Getting match details for $playerName, Match ID: $matchId"
            $matchJsonPath = Join-Path -Path $matchesPath -ChildPath "$matchId.json"
            $matchStats = $null

            # Check cache first
            if (Test-Path -Path $matchJsonPath -PathType Leaf) {
                Write-Verbose "Getting $matchId from cache."
                try {
                    $matchStats = Get-Content -Path $matchJsonPath | ConvertFrom-Json -Depth 100 -ErrorAction Stop
                    if ($null -eq $matchStats) { Write-Warning "Failed to parse cached match file: $matchJsonPath" }
                    else { $matchesCached++ }
                } catch {
                    Write-Warning "Error reading cached match file '$matchJsonPath': $($_.Exception.Message)"
                }
            }

            # Fetch from API if not cached or cache failed
            if ($null -eq $matchStats) {
                $apiUrl = "https://api.pubg.com/shards/steam/matches/$matchId"
                Write-Output "Fetching match $matchId from API..."
                $matchStats = Invoke-PubgApi -Uri $apiUrl -Headers $apiHeaders
                
                if ($null -ne $matchStats) {
                    $matchesFetched++
                    # Sort included participants by winPlace before saving (optional, but done in original)
                    try {
                        if ($null -ne $matchStats.included -and $matchStats.included -is [array]) {
                            $matchStats.included = $matchStats.included | Sort-Object -Property { $_.attributes.stats.winPlace } -ErrorAction SilentlyContinue
                        }
                    } catch { Write-Warning "Could not sort 'included' array for match $matchId." }
                    
                    # Save to cache
                    try {
                        $matchStats | ConvertTo-Json -Depth 100 | Out-File -FilePath $matchJsonPath -Encoding UTF8 -ErrorAction Stop
                        Write-Verbose "Saved match $matchId to cache."
                    } catch {
                        Write-Warning "Failed to save match $matchId to cache '$matchJsonPath'. Error: $($_.Exception.Message)"
                    }
                } else {
                    Write-Warning "Failed to fetch match $matchId from API for player $playerName."
                    continue # Skip this match if API fetch failed
                }
            }

            # Process the retrieved/cached match stats
            if ($null -ne $matchStats -and $null -ne $matchStats.data -and $null -ne $matchStats.included) {
                 # Find the specific player's stats within the 'included' array
                 $playerSpecificStats = $null
                 if ($matchStats.included -is [array]) {
                     $playerSpecificStats = $matchStats.included |
                                            Where-Object { $_.type -eq 'participant' -and ($_.attributes.stats.name -eq $playerName) } |
                                            Select-Object -First 1 -ExpandProperty attributes | Select-Object -ExpandProperty stats
                 }

                 # Find telemetry URL
                 $telemetryUrl = $null
                 if ($matchStats.included -is [array]) {
                      $telemetryAsset = $matchStats.included | Where-Object { $_.type -eq 'asset' -and $_.attributes.name -eq 'telemetry' } | Select-Object -First 1
                      if ($telemetryAsset) { $telemetryUrl = $telemetryAsset.attributes.URL }
                 }

                 if ($null -ne $playerSpecificStats) {
                     $currentPlayerMatches += [PSCustomObject]@{
                         stats         = $playerSpecificStats # Just the stats object for this player
                         matchType     = $matchStats.data.attributes.matchType
                         gameMode      = $matchStats.data.attributes.gameMode
                         createdAt     = $matchStats.data.attributes.createdAt
                         mapName       = $matchStats.data.attributes.mapName
                         telemetry_url = $telemetryUrl
                         id            = $matchStats.data.id
                     }
                 } else {
                     Write-Warning "Could not find stats for player $playerName within match $matchId data."
                 }
            } else {
                 Write-Warning "Match data structure for $matchId is invalid or incomplete after retrieval/caching."
            }
        } # End foreach matchId

        # Add the processed matches for the current player to the main list
        $allPlayerMatchDetails += [PSCustomObject]@{
            playername     = $playerName
            player_matches = $currentPlayerMatches # Array of processed match objects for this player
        }
        Write-Output "Finished processing matches for $playerName. Found $($currentPlayerMatches.Count) valid entries."
    } # End foreach player
    Write-Output "Finished fetching/processing all matches. API Fetches: $matchesFetched, Cache Hits: $matchesCached."

    # --- Compare with Old Data & Identify New Wins/Losses ---
    Write-Output "Comparing current matches with old data..."
    $oldPlayerMatchData = $null
    $newWinMatchesList = @()
    $newLossMatchesList = @()

    if (Test-Path -Path $playerMatchesJsonPath -PathType Leaf) {
        try {
            $oldPlayerMatchData = Get-Content -Path $playerMatchesJsonPath | ConvertFrom-Json -Depth 100 -ErrorAction Stop
            if ($null -eq $oldPlayerMatchData) {
                 Write-Warning "Failed to parse old player matches file: $playerMatchesJsonPath. Cannot compare for new wins/losses."
            } else {
                 Write-Output "Successfully loaded old player matches data for comparison."
                 
                 # Extract all current match IDs and old match IDs safely
                 $currentMatchIds = ($allPlayerMatchDetails.player_matches.id | Select-Object -Unique)
                 $oldMatchIds = $null
                 if ($oldPlayerMatchData -is [array]) {
                     $oldMatchIds = ($oldPlayerMatchData.player_matches.id | Select-Object -Unique)
                 } else {
                     Write-Warning "Old player matches data is not in the expected array format."
                 }

                 if ($null -ne $oldMatchIds) {
                     # Compare IDs to find newly added matches
                     $newMatchIds = (Compare-Object -ReferenceObject $oldMatchIds -DifferenceObject $currentMatchIds | Where-Object { $_.SideIndicator -eq '=>' }).InputObject | Select-Object -Unique
                     Write-Output "Found $($newMatchIds.Count) new match IDs."

                     # Identify new wins and losses among the new matches
                     $newMatchesDetails = $allPlayerMatchDetails.player_matches | Where-Object { $newMatchIds -contains $_.id }
                     $newWinMatchesList = ($newMatchesDetails | Where-Object { $_.stats.winPlace -eq 1 }).id | Select-Object -Unique
                     $newLossMatchesList = ($newMatchesDetails | Where-Object { $_.stats.winPlace -ne 1 }).id | Select-Object -Unique
                     
                     Write-Output "Identified $($newWinMatchesList.Count) new wins and $($newLossMatchesList.Count) new losses."

                     # Combine with potentially existing lists from old data (if format was correct)
                     $oldWinMatches = $oldPlayerMatchData | Where-Object { $_.PSObject.Properties.Name -eq 'new_win_matches' } | Select-Object -ExpandProperty new_win_matches
                     $oldLossMatches = $oldPlayerMatchData | Where-Object { $_.PSObject.Properties.Name -eq 'new_loss_matches' } | Select-Object -ExpandProperty new_loss_matches
                     
                     if ($oldWinMatches -is [array]) { $newWinMatchesList = ($oldWinMatches + $newWinMatchesList) | Select-Object -Unique }
                     if ($oldLossMatches -is [array]) { $newLossMatchesList = ($oldLossMatches + $newLossMatchesList) | Select-Object -Unique }
                 }
            }
        } catch {
            Write-Warning "Error reading or processing old player matches file '$playerMatchesJsonPath': $($_.Exception.Message)"
        }
    } else {
        Write-Output "Old player matches file not found. Cannot compare for new wins/losses."
        # If no old file, all current wins/losses are "new" for the first run
        $newWinMatchesList = ($allPlayerMatchDetails.player_matches | Where-Object { $_.stats.winPlace -eq 1 }).id | Select-Object -Unique
        $newLossMatchesList = ($allPlayerMatchDetails.player_matches | Where-Object { $_.stats.winPlace -ne 1 }).id | Select-Object -Unique
        Write-Output "Treating all current wins ($($newWinMatchesList.Count)) and losses ($($newLossMatchesList.Count)) as new."
    }

    # Add the lists of new wins/losses to the data structure
    $allPlayerMatchDetails += [PSCustomObject]@{ new_win_matches = $newWinMatchesList }
    $allPlayerMatchDetails += [PSCustomObject]@{ new_loss_matches = $newLossMatchesList }

    # Add update timestamp
    $currentDateTime = Get-Date
    $currentTimezone = (Get-TimeZone).Id
    $formattedString = "$currentDateTime - Time Zone: $currentTimezone"
    $allPlayerMatchDetails += [PSCustomObject]@{ updated = $formattedString }
    Write-Output "Added update timestamp and new win/loss lists."

    # --- Save Updated Player Matches Data ---
    try {
        $allPlayerMatchDetails | ConvertTo-Json -Depth 100 | Out-File -FilePath $playerMatchesJsonPath -Encoding UTF8 -ErrorAction Stop
        Write-Output "Updated player matches data saved to '$playerMatchesJsonPath'"
    } catch {
        Write-Error "Failed to save updated player matches data to '$playerMatchesJsonPath'. Error: $($_.Exception.Message)"
    }

    # --- Clean Old Match Files & Create Cached Summary ---
    Write-Output "Cleaning old match files and creating cached summary..."
    $cachedMatches = @()
    $archivedMatchFiles = 0
    $processedMatchFiles = 0
    $monthsToKeepMatches = -3 # How long to keep individual match files

    try {
        $matchFiles = Get-ChildItem -Path $matchesPath -Filter *.json -File -ErrorAction SilentlyContinue
        if ($matchFiles) {
            $archiveThreshold = (Get-Date).AddMonths($monthsToKeepMatches)
            Write-Output "Archiving match files older than: $archiveThreshold"

            foreach ($file in $matchFiles) {
                $processedMatchFiles++
                try {
                    $fileContent = Get-Content -Path $file.FullName | ConvertFrom-Json -Depth 100 -ErrorAction Stop
                    # Validate essential structure
                    if ($null -eq $fileContent -or $null -eq $fileContent.data.attributes.createdAt -or $null -eq $fileContent.included) {
                        Write-Warning "Skipping invalid match file: $($file.Name)"
                        continue
                    }
                    
                    $matchFileDate = $null
                    try { $matchFileDate = [datetime]$fileContent.data.attributes.createdAt } catch { Write-Warning "Could not parse date in match file $($file.Name)" }

                    # Archive old files
                    if ($null -ne $matchFileDate -and $matchFileDate -lt $archiveThreshold) {
                        Write-Verbose "Archiving match file: $($file.Name)"
                        Move-Item -Path $file.FullName -Destination $matchesArchivePath -Force -ErrorAction SilentlyContinue
                        if ($?) { $archivedMatchFiles++ }
                        else { Write-Warning "Failed to archive match file: $($file.Name)" }
                    } else {
                        # Process file for cached summary if it's recent enough
                        $matchAttributes = $fileContent.data.attributes
                        $matchId = $fileContent.data.id
                        
                        # Find stats for clan members within this match
                        $clanMemberStatsInMatch = @()
                        if ($fileContent.included -is [array]) {
                             $clanMemberStatsInMatch = $fileContent.included |
                                                       Where-Object { $_.type -eq 'participant' -and $clanMembers -contains $_.attributes.stats.name } |
                                                       Select-Object -ExpandProperty attributes | Select-Object -ExpandProperty stats
                        }

                        if ($clanMemberStatsInMatch.Count -gt 0) {
                            $cachedMatches += [PSCustomObject]@{
                                matchType = $matchAttributes.matchType
                                gameMode  = $matchAttributes.gameMode
                                createdAt = $matchAttributes.createdAt
                                mapName   = $matchAttributes.mapName
                                id        = $matchId
                                stats     = @($clanMemberStatsInMatch) # Ensure stats is always an array
                            }
                        }
                    }
                } catch {
                    Write-Warning "Error processing match file '$($file.Name)': $($_.Exception.Message)"
                }
            } # End foreach file
            Write-Output "Processed $processedMatchFiles match files. Archived: $archivedMatchFiles."

            # Save the cached summary object
            if ($cachedMatches.Count -gt 0) {
                 try {
                     $cachedMatches | Sort-Object createdAt -Descending | ConvertTo-Json -Depth 100 | Out-File -FilePath $cachedMatchesJsonPath -Encoding UTF8 -ErrorAction Stop
                     Write-Output "Cached matches summary saved to '$cachedMatchesJsonPath'. Count: $($cachedMatches.Count)"
                 } catch {
                     Write-Error "Failed to save cached matches summary to '$cachedMatchesJsonPath'. Error: $($_.Exception.Message)"
                 }
            } else {
                 Write-Output "No recent matches found containing clan members for cached summary."
                 # Optionally clear or save an empty array to the cache file
                 # @() | ConvertTo-Json | Out-File -FilePath $cachedMatchesJsonPath -Encoding UTF8
            }

        } else {
            Write-Output "No match files found in '$matchesPath' to process or clean."
        }
    } catch {
        Write-Warning "Error during match file cleaning/caching process: $($_.Exception.Message)"
    }

} # End Main Try Block
finally {
    # --- Cleanup ---
    Write-Output "Script finished at $(Get-Date)."
    Remove-Lock # Ensure lock is always removed
    Stop-Transcript
}