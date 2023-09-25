
if ($PSScriptRoot.length -eq 0) {
    $scriptroot = Get-Location
}
else {
    $scriptroot = $PSScriptRoot
}
# Read the content of the file as a single string
$fileContent = Get-Content -Path "$scriptroot/../config/config.php" -Raw

# Use regex to match the apiKey value
if ($fileContent -match "\`$apiKey\s*=\s*\'([^\']+)\'") {
    $apiKey = $matches[1]
}
else {
    Write-Output "API Key not found"
}

if ($fileContent -match "\`$clanmembers\s*=\s*array\(([^)]+)\)") {
    # Remove quotes and split by comma to get individual members
    $clanMembers = ($matches[1] -replace '"|\'', '' -split ","').replace(" ", "")
    $clanMembersArray = $clanMembers.split(",").trim()
    Write-Output "Clan Members: $($clanMembersArray -join ', ')"
}
else {
    Write-Output "Clan members not found"
}
if ($clanMembersArray.count -ge 10 ) {
    write-output "Currently not able to process more then 10 players"
    exit
}

$headers = @{
    'accept'        = 'application/vnd.api+json'
    'Authorization' = "$apiKey"
}

$player_data = get-content  "$scriptroot/../data/player_data.json" | convertfrom-json -Depth 100

$player_matches = @()
foreach ($player in $player_data) {
    $lastMatches = $player.relationships.matches.data.id #| Select-Object -First 10
    $playermatches = @()
    foreach ($match in $lastMatches) {
        Write-Host "Getting match for $($player.attributes.name) match: $match "
        $stats = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/matches/$match" -Method GET -Headers $headers
        $playermatches += [PSCustomObject]@{ 
            stats = $stats.included.ATTRIBUTES.stats  | where-object {$_.name -eq $player.attributes.name}
            matchType = $stats.data.attributes.matchtype
            gameMode = $stats.data.attributes.gameMode
            createdAt = $stats.data.attributes.createdAt
            mapName = $stats.data.attributes.mapName
            winPlace = $stats.data.attributes.winPlace
            telemetry_url = ($stats.included.attributes | Where-Object {$_.name -eq 'telemetry'}).URL
        }

    }

    $obj = [PSCustomObject]@{
        playername     = $player.attributes.name
        player_matches = $playermatches

    }

    $player_matches += $obj

}

$currentDateTime = Get-Date

# Get current timezone
$currentTimezone = (Get-TimeZone).Id

# Format and parse the information into a string
$formattedString = "$currentDateTime - Time Zone: $currentTimezone"
# Output the formatted string



$player_matches| Add-Member -Name "updated" -MemberType NoteProperty -Value $formattedString

$player_matches | convertto-json -Depth 100 | out-file "$scriptroot/../data/player_matches.json"