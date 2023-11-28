Start-Transcript -Path '/var/log/dtch/update_clan_members.log' -Append
Write-Output 'Running from'
(Get-Location).path

if ($PSScriptRoot.length -eq 0) {
    $scriptroot = Get-Location
}
else {
    $scriptroot = $PSScriptRoot
}

. $scriptroot\..\includes\ps1\lockfile.ps1
new-lock -by "update_clan_members"

# Read the content of the file as a single string
$fileContent = Get-Content -Path "$scriptroot/../config/config.php" -Raw

# Use regex to match the apiKey value
if ($fileContent -match "\`$apiKey\s*=\s*\'([^\']+)\'") {
    $apiKey = $matches[1]
}
else {
    Write-Output "API Key not found"
}


$clanMembersArray = (Get-Content "$scriptroot/../config/clanmembers.json" | ConvertFrom-Json).clanMembers

$clanmemberchunks = @()
$chunk = @()
$chunksize = 10
$i = 0

foreach ($member in $clanMembersArray) {
    $chunk += $member
    if ($chunk.Count -eq $chunksize) {
        $clanmemberchunks += @{ "Chunk$i" = $chunk }
        $chunk = @()
        $i++
    }
}

# Add any remaining members to the last chunk
if ($chunk.Count -gt 0) {
    $clanmemberchunks += @{ "Chunk$i" = $chunk }
}
$clanMembers = $clanMembersArray -join ','

$headers = @{
    'accept'        = 'application/vnd.api+json'
    'Authorization' = "$apiKey"
}


$playerinfo = @()
foreach ($key in $clanmemberchunks.keys) {

    $clanMembers = $clanmemberchunks.$key -join ','
    $clanMembers
    try {
        $playerinfo += Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/players?filter[playerNames]=$clanMembers" -Method GET -Headers $headers 
    }
    catch {
        write-output 'Sleeping for 61 seconds'
        start-sleep -Seconds 61
        $playerinfo += Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/players?filter[playerNames]=$clanMembers" -Method GET -Headers $headers
    }

}
$playerinfo.data | convertto-json -depth 100 | Out-File "$scriptroot/../data/player_data.json"
$playerList = @()
$playerinfo.data | ForEach-Object {
    $playerObject = [PSCustomObject]@{
        PlayerName = $_.attributes.name
        PlayerID   = $_.id
    }
    $playerList += $playerObject
}

# Display the list
$playerList



$playerChunks = @{}
$chunk = @()
$chunksize = 10
$i = 0

foreach ($player in $playerList) {
    $chunkName = "Chunk$i"
    $chunk += $player
    if ($chunk.Count -eq $chunksize) {
        $playerChunks[$chunkName] = $chunk
        $chunk = @()
        $i++
    }
}

# Add any remaining players to the last chunk
if ($chunk.Count -gt 0) {
    $playerChunks["Chunk$i"] = $chunk
}

$playeridstringarray = @()
foreach ($key in $playerChunks.keys) {

    $playeridstringarray += $playerChunks.$key.PlayerID -join ','
}

$playermodes = @(
    "solo",
    "duo",
    "squad",
    "solo-fpp",
    "duo-fpp",
    "squad-fpp"
)
# Initialize the master hashtable
$lifetimestats = @{}
foreach ($playeridstring in $playeridstringarray) {
    foreach ($playmode in $playermodes) {
        # Fetch stats for the current playmode
    
        write-output "Getting data for players $playeridstring gameode $playmode"
 
        try {
            $stats = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/seasons/lifetime/gameMode/$playmode/players?filter[playerIds]=$playeridstring" -Method GET -Headers $headers
        }
        catch {
            write-output 'sleeping for 61 seconds'
            start-sleep -Seconds 61
            $stats = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/seasons/lifetime/gameMode/$playmode/players?filter[playerIds]=$playeridstring" -Method GET -Headers $headers
        }
   
 
        # Check if the playmode doesn't exist in the hashtable, then add it
        if (-not $lifetimestats.ContainsKey($playmode)) {
            $lifetimestats[$playmode] = @{}
        }

        foreach ($stat in $stats.data.relationships.player.data.id) {
        
            # Fetch the player name for the current stat (account ID) from the dictionary
            $playerName = $playerList | Where-Object { $_.PlayerID -eq $stat } | Select-Object -ExpandProperty PlayerName
            write-output "Getting data for $playerName with gamemode $playmode"
            # Fetch the specific stat data for the current stat
            $specificStat = ($stats.data | where-object { $_.relationships.player.data.id -eq $stat }).attributes.gamemodestats.$playmode

            # Create a new hashtable entry for the player and insert the specific stat data
            if (-not $lifetimestats[$playmode].ContainsKey($playerName)) {
                $lifetimestats[$playmode][$playerName] = @{}
            }
            $lifetimestats[$playmode][$playerName][$stat] = $specificStat
        }
    }

}

# Get current date and time
$currentDateTime = Get-Date

# Get current timezone
$currentTimezone = (Get-TimeZone).Id

# Format and parse the information into a string
$formattedString = "$currentDateTime - Time Zone: $currentTimezone"
$lifetimestats['updated'] = $formattedString
# Output the formatted string


$lifetimestats | convertto-json -Depth 100 | out-file "$scriptroot/../data/player_lifetime_data.json"


$seasons = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/seasons" -Method GET -Headers $headers
$current_season = $seasons.data | Where-Object {$_.attributes.isCurrentSeason -eq $true}

$i = 0
$seasonstats = @()
while($playerinfo.data.Count -gt $i) {
    write-host $clanMembersArray[$i]
   
    try{
        $rankedstat = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/players/$($playerinfo.data[$i].id)/seasons/$($current_season.id)/ranked" -Method GET -Headers $headers
    }catch{
        write-output 'sleeping for 61 seconds'
        start-sleep -Seconds 61
        $rankedstat = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/players/$($playerinfo.data[$i].id)/seasons/$($current_season.id)/ranked" -Method GET -Headers $headers
    }

    $seasonstats += [PSCustomObject]@{
        stat = $rankedstat
        name = $playerinfo.data[$i].attributes.name 
    }

    $i++

}
$seasonstats | Sort-Object -Property {$_.stat.data.attributes.rankedGameModeStats.'squad-fpp'.currentRankPoint} -Descending | convertto-json -Depth 100| Out-File "$scriptroot/../data/player_season_data.json"

remove-lock
Stop-Transcript