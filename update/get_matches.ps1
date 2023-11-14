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
$player_data = get-content  "$scriptroot/../data/player_data.json" | convertfrom-json -Depth 100


foreach ($player in $player_data) {
    $lastMatches = $player.relationships.matches.data.id #| Select-Object -First 10
    $playermatches = @()
    foreach ($match in $lastMatches) {
        Write-Host "Getting match for $($player.attributes.name) match: $match "
        if(Test-Path "$scriptroot/../data/matches/$match.json"){
            write-output "Getting $match from cache"
            $stats = get-content "$scriptroot/../data/matches/$match.json" | convertfrom-json
        }else{
            $stats = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/matches/$match" -Method GET -Headers $headers
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
    $old_player_data = get-content "$scriptroot/../data/player_matches.json" | convertfrom-json -Depth 100
    $new_ids = ($player_matches.player_matches | where-object {$_.stats.winplace -eq 1}).id
    $old_ids = ($old_player_data.player_matches | where-object {$_.stats.winplace -eq 1}).id 
    $new_win_matches = ((Compare-Object -ReferenceObject $old_ids -DifferenceObject $new_ids) | Where-Object { $_.SideIndicator -eq '=>' }).InputObject | Select-Object -Unique
    $new_win_matches = $old_player_data.new_win_matches + $new_win_matches | Select-Object -Unique
    $player_matches += [PSCustomObject]@{ 
        new_win_matches = $new_win_matches
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

remove-lock