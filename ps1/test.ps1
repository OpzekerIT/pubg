
$playername = 'Lanta01'
$headers = @{
    'accept'        = 'application/vnd.api+json'
    'Authorization' = 'YOURAPIKEY'
}
$playerinfo = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/players?filter[playerNames]=$playername" -Method GET -Headers $headers
$playedid = $playerinfo.data.id
$seasons = Invoke-RestMethod -Uri 'https://api.pubg.com/shards/steam/seasons' -Method GET -Headers $headers

$season = ($seasons.data | Where-Object { $_.attributes.isCurrentSeason -eq $true }).id

$match_array = @()


$seasonstats = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/players/$playedid/seasons/$season`?filter[gamepad]=false" -Method GET -Headers $headers
$pubgmatches = $seasonstats.data.relationships.matchesSquad.data.id

foreach ($match in $pubgmatches) {
    Write-Output "checking $Match"
    $match_array += Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/matches/$Match" -Method GET -Headers $headers

}
