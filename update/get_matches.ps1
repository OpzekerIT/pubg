Start-Transcript -Path '/var/log/dtch/get_matches.log' -Append

if ($PSScriptRoot.length -eq 0) {
    $scriptroot = Get-Location
}
else {
    $scriptroot = $PSScriptRoot
}

. $scriptroot\..\includes\ps1\lockfile.ps1
new-lock -by "get_matches"

# Read the content of the file as a single string
$fileContent = Get-Content -Path "$scriptroot/../config/config.php" -Raw
$players = (Get-Content -Path "$scriptroot/../config/clanmembers.json" | ConvertFrom-Json).clanmembers
# Use regex to match the apiKey value
if ($fileContent -match "\`$apiKey\s*=\s*\'([^\']+)\'") {
    $apiKey = $matches[1]
}
else {
    Write-Output "API Key not found"
}

$headers = @{
    'accept'        = 'application/vnd.api+json'
    'Authorization' = "$apiKey"
}
$player_matches = @()
try { 
    $player_data = get-content  "$scriptroot/../data/player_data.json" | convertfrom-json -Depth 100 
}
catch {
    Write-Output 'Unable to read file exitin'
    exit
}
foreach ($player in $player_data) {
    $lastMatches = $player.relationships.matches.data.id #| Select-Object -First 10
    $playermatches = @()
    foreach ($match in $lastMatches) {
        Write-Host "Getting match for $($player.attributes.name) match: $match "
        if (Test-Path "$scriptroot/../data/matches/$match.json") {
            write-output "Getting $match from cache"
            $stats = get-content "$scriptroot/../data/matches/$match.json" | convertfrom-json
        }
        else {
            $stats = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/matches/$match" -Method GET -Headers $headers
            $sortedStats = $stats.included | Sort-Object { $_.attributes.stats.winplace } 
            $stats.included = $sortedStats
            $stats | ConvertTo-Json -Depth 100 | Out-File "$scriptroot/../data/matches/$match.json"
        }
        
        $playermatches += [PSCustomObject]@{ 
            stats         = $stats.included.ATTRIBUTES.stats  | where-object { $_.name -eq $player.attributes.name }
            matchType     = $stats.data.attributes.matchtype
            gameMode      = $stats.data.attributes.gameMode
            createdAt     = $stats.data.attributes.createdAt
            mapName       = $stats.data.attributes.mapName
            telemetry_url = ($stats.included.attributes | Where-Object { $_.name -eq 'telemetry' }).URL
            id            = $stats.data.id
        }

    }

    $obj = [PSCustomObject]@{
        playername     = $player.attributes.name
        player_matches = $playermatches

    }

    $player_matches += $obj

}

if (test-path "$scriptroot/../data/player_matches.json") {
    try {
        $old_player_data = get-content "$scriptroot/../data/player_matches.json" | convertfrom-json -Depth 100
    }
    catch {
        Write-Output 'Unable to read file exitin'
        exit
    }
    $new_ids = ($player_matches.player_matches | where-object { $_.stats.winplace -eq 1 }).id
    $old_ids = ($old_player_data.player_matches | where-object { $_.stats.winplace -eq 1 }).id 
    $new_win_matches = ((Compare-Object -ReferenceObject $old_ids -DifferenceObject $new_ids) | Where-Object { $_.SideIndicator -eq '=>' }).InputObject | Select-Object -Unique
    $new_win_matches = $old_player_data.new_win_matches + $new_win_matches | Select-Object -Unique
    $player_matches += [PSCustomObject]@{ 
        new_win_matches = $new_win_matches
    }

    # Nieuwe verloren matches bepalen
    $new_loss_ids = ($player_matches.player_matches | Where-Object { $_.stats.winplace -ne 1 }).id
    $old_loss_ids = ($old_player_data.player_matches | Where-Object { $_.stats.winplace -ne 1 }).id
    $new_loss_matches = ((Compare-Object -ReferenceObject $old_loss_ids -DifferenceObject $new_loss_ids) | Where-Object { $_.SideIndicator -eq '=>' }).InputObject | Select-Object -Unique
    $new_loss_matches = $old_player_data.new_loss_matches + $new_loss_matches | Select-Object -Unique
    $player_matches += [PSCustomObject]@{
        new_loss_matches = $new_loss_matches
    }

}

$currentDateTime = Get-Date

# Get current timezone
$currentTimezone = (Get-TimeZone).Id

# Format and parse the information into a string
$formattedString = "$currentDateTime - Time Zone: $currentTimezone"
# Output the formatted string
$playermatches += [PSCustomObject]@{ 
    updated = $formattedString
}

$player_matches | convertto-json -Depth 100 | out-file "$scriptroot/../data/player_matches.json"

write-output 'Cleaning matches'

$matchfiles = Get-ChildItem "$scriptroot/../data/matches" -Filter *.json
$player_matches_object = @()
foreach ($file in $matchfiles) {
    $filecontent = get-content $file | convertfrom-json
    $matchfiledate = $filecontent.data.attributes.createdAt
    if ($matchfiledate -lt (get-date).AddMonths(-3)) {
        write-output "archiving $matchfiledate"
        Move-Item -Path $file -Destination "$scriptroot/../data/matches/archive"
    }
    else {
        $result = ($filecontent.included | where-object { $_.type -eq 'participant' } | Where-Object { $players -contains $_.attributes.stats.name })
        $filecontent.data.id
        $result.count
        $player_matches_cached = ($filecontent.included | where-object { $_.type -eq 'participant' } | Where-Object { $players -contains $_.attributes.stats.name }).attributes.stats
        if ($null -ne $player_matches_cached) {
            $player_matches_object += [PSCustomObject]@{
                matchType = $filecontent.data.attributes.matchType
                gameMode  = $filecontent.data.attributes.gameMode
                createdAt = $filecontent.data.attributes.createdAt
                mapName   = $filecontent.data.attributes.mapName
                id        = $filecontent.data.id
                stats     = @($player_matches_cached)
            }
        }
        write-output "NEW $matchfiledate"
    }
}
$player_matches_object | Sort-Object createdAt -Descending | convertto-json -Depth 100 | out-file "$scriptroot/../data/cached_matches.json"

remove-lock
Stop-Transcript