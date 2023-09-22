
if($PSScriptRoot.length -eq 0){
    $scriptroot = Get-Location
}else{
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
$playerinfo = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/players?filter[playerNames]=$clanMembers" -Method GET -Headers $headers
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


$playeridstring = ""
foreach ($playerid in $playerinfo.data.id){
    $playeridstring += "$playerid,"
}
$playeridstring = $playeridstring.Substring(0, $playeridstring.Length - 1)


$playermodes = @(
    "solo",
    "duo",
    "squad"
    #"solo-fpp",
    #"duo-fpp",
    #"squad-fpp"
)
# Initialize the master hashtable
$lifetimestats = @{}
$webrequestlimiter = 0
foreach ($playmode in $playermodes) {
    # Fetch stats for the current playmode
    if($webrequestlimiter -le 8){
        write-output "Getting data for players $playeridstring gameode $playmode"
    $stats = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/seasons/lifetime/gameMode/$playmode/players?filter[playerIds]=$playeridstring" -Method GET -Headers $headers
    $webrequestlimiter++
}else{
    write-ouput "sleeping for 60 seconds"
    $webrequestlimiter = 0
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
        $specificStat = ($stats.data | where-object {$_.relationships.player.data.id -eq $stat}).attributes.gamemodestats.$playmode

        # Create a new hashtable entry for the player and insert the specific stat data
        if (-not $lifetimestats[$playmode].ContainsKey($playerName)) {
            $lifetimestats[$playmode][$playerName] = @{}
        }
        $lifetimestats[$playmode][$playerName][$stat] = $specificStat
    }
}



# Get current date and time
$currentDateTime = Get-Date

# Get current timezone
$currentTimezone = (Get-TimeZone).Id

# Format and parse the information into a string
$formattedString = "$currentDateTime - Time Zone: $currentTimezone"
$lifetimestats['updated']= $formattedString
# Output the formatted string


$lifetimestats | convertto-json -Depth 100 | out-file "$scriptroot/../data/player_lifetime_data.json"