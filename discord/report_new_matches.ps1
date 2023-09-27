
if ($PSScriptRoot.length -eq 0) {
    $scriptroot = Get-Location
}
else {
    $scriptroot = $PSScriptRoot
}



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


$fileContent = Get-Content -Path "$scriptroot/../discord/config.php" -Raw

# Use regex to match the apiKey value
if ($fileContent -match "\`$webhookurl\s*=\s*\'([^\']+)\'") {
    $webhookurl = $matches[1]
}
else {
    Write-Output "No web url found"
}

function send-discord {
    param (
        $content
    )
    $payload = [PSCustomObject]@{

        content = $content
    
    }
    
    Invoke-RestMethod -Uri $webhookurl -Method Post -Body ($payload | ConvertTo-Json) -ContentType 'Application/Json'
}

$map_map = @{
    "Baltic_Main" = "Erangel"
    "Chimera_Main" = "Paramo"
    "Desert_Main" = "Miramar"
    "DihorOtok_Main" = "Vikendi"
    "Erangel_Main" = "Erangel"
    "Heaven_Main" = "Haven"
    "Kiki_Main" = "Deston"
    "Range_Main" = "Camp Jackal"
    "Savage_Main" = "Sanhok"
    "Summerland_Main" = "Karakin"
    "Tiger_Main" = "Taego"
}

$player_matches = get-content "$scriptroot/../data/player_matches.json" | convertfrom-json -Depth 100
$new_win_matches = $player_matches.new_win_matches
$win_stats = @()

foreach ($winid in $new_win_matches) {
   
    if ($null -eq $winid) { continue }
    $winmatches = $player_matches.player_matches | Where-Object { $_.id -eq $winid }
    $telemetry = (invoke-webrequest @($winmatches.telemetry_url)[0]).content | convertfrom-json
    $players = $winmatches.stats.name 
    $match_stats = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/matches/$winid" -Method GET -Headers $headers
    $all_winners_of_match = ($match_stats.included.attributes.stats | where-object { $_.winplace -eq 1 })
    send-discord -content ":chicken: :chicken: **CHICKEN CHICKEN WINNER DINNER!!** :chicken: :chicken:"
    send-discord -content "Gefeliciteerd $($players -join ' ')"
    send-discord -content "match mode $($winmatches[0].gameMode)"
    send-discord -content "match type $($winmatches[0].matchType)"
    send-discord -content "map $($map_map[$winmatches[0].mapName])"

    foreach ($player in $all_winners_of_match.name) {
        write-output "creating tble for player $player"
        $win_stats += [PSCustomObject]@{ 
            playername = $player
            dmg_h      = [math]::Round((($telemetry | where-object { $_._T -eq 'LOGPLAYERTAKEDAMAGE' } | where-object { $_.attacker.name -eq $player } | where-object { $_.victim.accountId -notlike "ai.*" } | where-object {$_.victim.teamId -ne $_.attacker.teamId } ).damage | Measure-Object -Sum).Sum, 2)
            k_h        = (($telemetry | where-object { $_._T -eq 'LOGPLAYERKILLV2' } | where-object { $_.killer.name -eq $player } | where-object { $_.victim.accountId -notlike "ai.*" } )).count
            dmg        = ($all_winners_of_match | Where-Object { $_.name -eq $player }).damageDealt
            k_a        = ($all_winners_of_match | Where-Object { $_.name -eq $player }).kills
            k_t        = ($all_winners_of_match | Where-Object { $_.name -eq $player }).teamKills
            t_serv     = ($all_winners_of_match | Where-Object { $_.name -eq $player }).timeSurvived
        }
       
    }
    
    $content_winstats = '```' + ($win_stats | Format-Table | out-string) + '```'
    send-discord -content $content_winstats
    
    $legenda = '
```
dmg_h   = Schade aangericht aan echte spelers
dmg     = Totale schade (aan zowel echte spelers als AI)
k_h     = Aantal echte spelers die je hebt geelimineerd
K_a     = Totale aantal eliminaties (inclusief AI)
t_serv  = Overleefde tijd (in seconden)
k_t     = Team eliminaties
```
        '
    
    send-discord -content $legenda
    
}



foreach ($item in $player_matches) {
    if ($item.PSObject.Properties.Name -contains "new_win_matches") {
        $item.new_win_matches = $null
    }
}

# Convert back to JSON (optional)
$newJson = $player_matches | ConvertTo-Json -Depth 100

# Display the updated JSON
$newJson | out-file "$scriptroot/../data/player_matches.json"
