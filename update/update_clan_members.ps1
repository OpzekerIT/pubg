# --- Script Setup ---
# Using Unicode BOM (Byte Order Mark) can sometimes cause issues, ensure file is saved as UTF-8 without BOM if problems arise.
Start-Transcript -Path '/var/log/dtch/update_clan_members.log' -Append
Write-Output "Starting update_clan_members script at $(Get-Date)"
Write-Output "Running from: $(Get-Location)"

# Determine script root directory reliably
if ($PSScriptRoot) {
    $scriptRoot = $PSScriptRoot
} else {
    # Fallback for environments where $PSScriptRoot is not defined (e.g., ISE)
    $scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Write-Warning "PSScriptRoot not defined, using calculated path: $scriptRoot"
}
Write-Output "Script root identified as: $scriptRoot"

# Define paths using Join-Path for robustness
$includesPath = Join-Path -Path $scriptRoot -ChildPath "..\includes\ps1"
$configPath = Join-Path -Path $scriptRoot -ChildPath "..\config"
$dataPath = Join-Path -Path $scriptRoot -ChildPath "..\data"

# Ensure data directory exists
if (-not (Test-Path -Path $dataPath -PathType Container)) {
    Write-Warning "Data directory not found at '$dataPath'. Attempting to create."
    try {
        New-Item -Path $dataPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Write-Output "Successfully created data directory."
    } catch {
        Write-Error "Failed to create data directory '$dataPath'. Please check permissions. Error: $($_.Exception.Message)"
        Stop-Transcript
        exit 1
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
New-Lock -by "update_clan_members" -ErrorAction Stop # Stop if locking fails

# --- Configuration Loading ---
$apiKey = $null
$clanMembersArray = @()

# Load API Key from config.php
$phpConfigPath = Join-Path -Path $configPath -ChildPath "config.php"
if (Test-Path -Path $phpConfigPath -PathType Leaf) {
    try {
        $fileContent = Get-Content -Path $phpConfigPath -Raw -ErrorAction Stop
        # Corrected regex: Match literal '$apiKey', whitespace, '=', whitespace, single quote, capture content, single quote.
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
    Remove-Lock
    Stop-Transcript
    exit 1
}

# Load Clan Members from clanmembers.json
$clanMembersJsonPath = Join-Path -Path $configPath -ChildPath "clanmembers.json"
if (Test-Path -Path $clanMembersJsonPath -PathType Leaf) {
    try {
        $clanMembersData = Get-Content -Path $clanMembersJsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
        if ($clanMembersData -is [PSCustomObject] -and $clanMembersData.PSObject.Properties.Name -contains 'clanMembers' -and $clanMembersData.clanMembers -is [array]) {
             $clanMembersArray = $clanMembersData.clanMembers
             Write-Output "Clan members loaded successfully. Count: $($clanMembersArray.Count)"
        } else {
             Write-Warning "Invalid structure in '$clanMembersJsonPath'. Expected an object with a 'clanMembers' array."
        }
    } catch {
        Write-Warning "Failed to read or parse '$clanMembersJsonPath'. Error: $($_.Exception.Message)"
    }
} else {
    Write-Warning "Clan members file not found at '$clanMembersJsonPath'."
}

if ($clanMembersArray.Count -eq 0) {
    Write-Error "No clan members loaded. Cannot proceed."
    Remove-Lock
    Stop-Transcript
    exit 1
}

# --- Helper Function for API Calls ---
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
            # Basic validation: Check if response is not null
            if ($null -ne $response) {
                Write-Verbose "API call successful."
                return $response
            } else {
                 Write-Warning "API call to $Uri returned null or empty response."
                 # Decide if null response is an error or expected empty result
                 return $null # Or handle as error if appropriate
            }
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorMessage = $_.Exception.Message
            Write-Warning "API call failed (Attempt $($attempt)). Status: $statusCode. Error: $errorMessage"
            
            # Check for rate limit (429) or other retryable errors if needed
            if ($attempt -le $RetryCount -and $statusCode -eq 429) {
                Write-Warning "Rate limit hit. Sleeping for $RetryDelaySeconds seconds before retry..."
                Start-Sleep -Seconds $RetryDelaySeconds
            } elseif ($attempt -gt $RetryCount) {
                Write-Error "API call failed after $($attempt) attempts. URI: $Uri. Last Error: $errorMessage"
                # Re-throw the exception or return null/specific error object
                # throw $_ # Re-throw the last exception to halt script if critical
                return $null # Return null to allow script to potentially continue or handle missing data
            } else {
                 # Handle other non-retryable errors immediately
                 Write-Error "Non-retryable API error. URI: $Uri. Error: $errorMessage"
                 return $null
            }
        }
    }
    # Should not be reached if logic is correct, but return null just in case
    return $null
}


# --- Get Player Information ---
Write-Output "Fetching player information..."
$headers = @{
    'accept'        = 'application/vnd.api+json'
    'Authorization' = "Bearer $apiKey" # Standard practice to include "Bearer"
}

# Chunk clan members for API query (max 10 per request)
$clanMemberChunks = @()
$chunkSize = 10
for ($i = 0; $i -lt $clanMembersArray.Count; $i += $chunkSize) {
    $endIndex = [System.Math]::Min($i + $chunkSize - 1, $clanMembersArray.Count - 1)
    $clanMemberChunks += ,($clanMembersArray[$i..$endIndex]) # Use comma to ensure it's always an array of arrays
}
Write-Output "Split clan members into $($clanMemberChunks.Count) chunks."

$allPlayerInfoData = @()
foreach ($chunk in $clanMemberChunks) {
    $playerNamesParam = $chunk -join ','
    $apiUrl = "https://api.pubg.com/shards/steam/players?filter[playerNames]=$playerNamesParam"
    Write-Output "Querying for players: $playerNamesParam"
    
    $playerInfoResponse = Invoke-PubgApi -Uri $apiUrl -Headers $headers
    
    if ($null -ne $playerInfoResponse -and $playerInfoResponse.data -is [array]) {
        $allPlayerInfoData += $playerInfoResponse.data
        Write-Output "Received data for $($playerInfoResponse.data.Count) players in this chunk."
    } else {
        Write-Warning "No valid player data received for chunk: $playerNamesParam"
        # Consider if script should stop or continue if a chunk fails
    }
}

# Process player info if data was retrieved
$playerList = @()
if ($allPlayerInfoData.Count -gt 0) {
    # Save raw player data
    $playerDataJsonPath = Join-Path -Path $dataPath -ChildPath "player_data.json"
    try {
        @{ data = $allPlayerInfoData } | ConvertTo-Json -Depth 100 | Out-File -FilePath $playerDataJsonPath -Encoding UTF8 -ErrorAction Stop
        Write-Output "Player data saved to '$playerDataJsonPath'"
    } catch {
        Write-Warning "Failed to save player data to '$playerDataJsonPath'. Error: $($_.Exception.Message)"
    }

    # Create simplified player list (Name/ID mapping)
    $playerList = $allPlayerInfoData | ForEach-Object {
        if ($_.attributes -ne $null -and $_.id -ne $null) {
            [PSCustomObject]@{
                PlayerName = $_.attributes.name
                PlayerID   = $_.id
            }
        } else {
            Write-Warning "Skipping player entry due to missing attributes or ID: $($_.PSObject.Properties | Out-String)"
        }
    }
    Write-Output "Processed $($playerList.Count) players into PlayerList."
    # $playerList | Format-Table # Optional: Display the list
} else {
    Write-Error "No player information retrieved from API. Cannot proceed with stats fetching."
    Remove-Lock
    Stop-Transcript
    exit 1
}

# --- Get Lifetime Stats ---
Write-Output "Fetching lifetime stats..."
$playerModes = @("solo", "duo", "squad", "solo-fpp", "duo-fpp", "squad-fpp")
$lifetimeStats = @{} # Use hashtable for structured storage: $lifetimeStats[mode][playerName][accountId] = stats

# Chunk player IDs for API query (max 10 per request)
$playerIdChunks = @()
for ($i = 0; $i -lt $playerList.Count; $i += $chunkSize) {
    $endIndex = [System.Math]::Min($i + $chunkSize - 1, $playerList.Count - 1)
    $playerIdChunks += ,($playerList[$i..$endIndex].PlayerID)
}
Write-Output "Split player IDs into $($playerIdChunks.Count) chunks."

foreach ($idChunk in $playerIdChunks) {
    $playerIdsParam = $idChunk -join ','
    foreach ($playMode in $playerModes) {
        Write-Output "Getting lifetime stats for mode '$playMode', players: $playerIdsParam"
        $apiUrl = "https://api.pubg.com/shards/steam/seasons/lifetime/gameMode/$playMode/players?filter[playerIds]=$playerIdsParam"
        
        $statsResponse = Invoke-PubgApi -Uri $apiUrl -Headers $headers
        
        if ($null -ne $statsResponse -and $statsResponse.data -is [array]) {
            Write-Verbose "Received $($statsResponse.data.Count) stat entries for mode '$playMode'."
            # Initialize mode in hashtable if it doesn't exist
            if (-not $lifetimeStats.ContainsKey($playMode)) {
                $lifetimeStats[$playMode] = @{}
            }

            # Process each stat entry in the response
            foreach ($statEntry in $statsResponse.data) {
                 # Validate structure before accessing nested properties
                 if ($null -ne $statEntry.relationships.player.data.id -and $null -ne $statEntry.attributes.gameModeStats.$playMode) {
                    $accountId = $statEntry.relationships.player.data.id
                    $specificStat = $statEntry.attributes.gameModeStats.$playMode
                    
                    # Find player name from our $playerList
                    $playerName = ($playerList | Where-Object { $_.PlayerID -eq $accountId } | Select-Object -First 1).PlayerName
                    
                    if ($playerName) {
                         # Initialize player in hashtable if it doesn't exist
                        if (-not $lifetimeStats[$playMode].ContainsKey($playerName)) {
                            $lifetimeStats[$playMode][$playerName] = @{}
                        }
                        # Store the stats under the account ID for that player/mode
                        $lifetimeStats[$playMode][$playerName][$accountId] = $specificStat
                        Write-Verbose "Stored stats for $playerName ($accountId) in mode $playMode."
                    } else {
                        Write-Warning "Could not find player name for account ID '$accountId' in PlayerList."
                    }
                 } else {
                     Write-Warning "Skipping stat entry due to missing data/relationships/gameModeStats: $($statEntry | Out-String)"
                 }
            }
        } else {
            Write-Warning "No valid lifetime stats data received for mode '$playMode', players: $playerIdsParam"
        }
    }
}

# Add update timestamp and save lifetime stats
$currentDateTime = Get-Date
$currentTimezone = (Get-TimeZone).Id
$formattedString = "$currentDateTime - Time Zone: $currentTimezone"
$lifetimeStats['updated'] = $formattedString
Write-Output "Added update timestamp: $formattedString"

$lifetimeStatsJsonPath = Join-Path -Path $dataPath -ChildPath "player_lifetime_data.json"
try {
    $lifetimeStats | ConvertTo-Json -Depth 100 | Out-File -FilePath $lifetimeStatsJsonPath -Encoding UTF8 -ErrorAction Stop
    Write-Output "Lifetime stats saved to '$lifetimeStatsJsonPath'"
} catch {
    Write-Warning "Failed to save lifetime stats to '$lifetimeStatsJsonPath'. Error: $($_.Exception.Message)"
}

# --- Get Current Season Ranked Stats ---
Write-Output "Fetching current season information..."
$currentSeason = $null
$seasonsResponse = Invoke-PubgApi -Uri "https://api.pubg.com/shards/steam/seasons" -Headers $headers

if ($null -ne $seasonsResponse -and $seasonsResponse.data -is [array]) {
    $currentSeason = $seasonsResponse.data | Where-Object { $_.attributes.isCurrentSeason -eq $true } | Select-Object -First 1
}

if (-not $currentSeason) {
    Write-Warning "Could not determine the current season from API. Skipping ranked stats update."
} else {
    Write-Output "Current season identified: $($currentSeason.id)"
    $seasonStats = @()
    
    # Iterate through the validated $playerList
    foreach ($player in $playerList) {
        Write-Output "Getting ranked stats for player: $($player.PlayerName) ($($player.PlayerID))"
        $apiUrl = "https://api.pubg.com/shards/steam/players/$($player.PlayerID)/seasons/$($currentSeason.id)/ranked"
        
        $rankedStatResponse = Invoke-PubgApi -Uri $apiUrl -Headers $headers
        
        # Even if API call returns null (e.g., player has no ranked stats), store an entry
        $seasonStats += [PSCustomObject]@{
            stat = $rankedStatResponse # Store the whole response (or null)
            name = $player.PlayerName
        }
        Write-Verbose "Stored ranked stat entry for $($player.PlayerName)."
    }

    # Save season stats (sorting might fail if 'stat' or nested properties are null)
    $seasonStatsJsonPath = Join-Path -Path $dataPath -ChildPath "player_season_data.json"
    try {
        # Sort carefully, handling potential nulls
        $sortedSeasonStats = $seasonStats | Sort-Object -Property { if ($null -ne $_.stat.data.attributes.rankedGameModeStats.'squad-fpp'.currentRankPoint) { $_.stat.data.attributes.rankedGameModeStats.'squad-fpp'.currentRankPoint } else { 0 } } -Descending
        
        $sortedSeasonStats | ConvertTo-Json -Depth 100 | Out-File -FilePath $seasonStatsJsonPath -Encoding UTF8 -ErrorAction Stop
        Write-Output "Season stats saved to '$seasonStatsJsonPath'"
    } catch {
        Write-Warning "Failed to save season stats to '$seasonStatsJsonPath'. Sorting or file write failed. Error: $($_.Exception.Message)"
    }
}

# --- Cleanup ---
Write-Output "Script finished at $(Get-Date)."
Remove-Lock
Stop-Transcript