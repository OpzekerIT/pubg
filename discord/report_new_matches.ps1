. .\..\includes\ps1\lockfile.ps1 
  
new-lock

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
    "Baltic_Main"     = "Erangel"
    "Chimera_Main"    = "Paramo"
    "Desert_Main"     = "Miramar"
    "DihorOtok_Main"  = "Vikendi"
    "Erangel_Main"    = "Erangel"
    "Heaven_Main"     = "Haven"
    "Kiki_Main"       = "Deston"
    "Range_Main"      = "Camp Jackal"
    "Savage_Main"     = "Sanhok"
    "Summerland_Main" = "Karakin"
    "Tiger_Main"      = "Taego"
}

$player_matches = get-content "$scriptroot/../data/player_matches.json" | convertfrom-json -Depth 100
$new_win_matches = $player_matches.new_win_matches


foreach ($winid in $new_win_matches) {

    $win_stats = @()
    $victims = @()
    if ($null -eq $winid) { continue }
    $winmatches = $player_matches.player_matches | Where-Object { $_.id -eq $winid }
    $telemetry = (invoke-webrequest @($winmatches.telemetry_url)[0]).content | convertfrom-json | where-object { ($_._T -eq 'LOGPLAYERTAKEDAMAGE') -or ($_._T -eq 'LOGPLAYERKILLV2') }
    $winners = ($winmatches | where-object {$_.stats.winPlace -eq 1}).stats.name
    $match_stats = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/matches/$winid" -Method GET -Headers $headers
    if($winmatches[0].matchType -eq 'custom'){
        $players_to_report = $match_stats.included.attributes.stats
    }else{
        $players_to_report = ($match_stats.included.attributes.stats | where-object { $_.winplace -eq 1 })
    }
    

    send-discord -content ":chicken: :chicken: **WINNER WINNER CHICKEN DINNER!!** :chicken: :chicken:"
    send-discord -content ":partying_face::partying_face::partying_face: Gefeliciteerd   $($winners -join ', ') :partying_face::partying_face::partying_face:"
    $match_settings = @"
``````
match mode      $($winmatches[0].gameMode)
match type      $($winmatches[0].matchType)
map             $($map_map[$winmatches[0].mapName])
id              $($winmatches[0].id)
``````
"@
    send-discord -content $match_settings
    foreach ($player in $players_to_report.name) {
        if($null -eq $player){continue}
        write-output "creating table for player $player"
        $win_stats += [PSCustomObject]@{ 
            Name   = $player
            'Human dmg'  = "$([math]::Round(($telemetry | Where-Object { $_._T -eq 'LOGPLAYERTAKEDAMAGE' -and $_.attacker.name -eq $player -and $_.victim.accountId -notlike "ai.*" -and $_.victim.teamId -ne $_.attacker.teamId } | Measure-Object -Property damage -Sum).Sum))"
            'Human Kills'    = "$(($telemetry | Where-Object { $_._T -eq 'LOGPLAYERKILLV2' -and $_.killer.name -eq $player -and $_.victim.accountId -notlike "ai.*" }).count)"
            'Dmg'    = "$([math]::Round(($players_to_report | Where-Object { $_.name -eq $player }).damageDealt))"
            'Kills'   = "$(($players_to_report | Where-Object { $_.name -eq $player }).kills)"
            'alive' = "$([math]::Round((($players_to_report | Where-Object { $_.name -eq $player }).timeSurvived /60 )))"
        }
        $teamdmg = $telemetry | Where-Object {
            $_._T -eq 'LOGPLAYERTAKEDAMAGE' -and 
            $_.victim.teamId -eq $_.attacker.teamId -and
            $_.victim.accountId -notlike "ai.*" -and 
            $_.victim.name -ne $_.attacker.name -and
            $_.attacker.name -eq $player
        }
        
        if ($teamdmg.count -ge 1) {
            foreach ($victim in ($teamdmg.victim.name | Select-Object -Unique)) {
                $victims += [PSCustomObject]@{
                    attacker = $player
                    victim   = $victim
                    Damage   = "$([math]::Round((($teamdmg | Where-Object { $_.victim.name -eq $victim }).damage | Measure-Object -Sum).Sum))"
                }
            }
    
        }

    }


    $content_winstats = '```' + ($win_stats | Format-Table | out-string) + '```'
    send-discord -content $content_winstats

    if($victims.count -ge 1){
        send-discord -content ":skull::skull: Helaas hebben we deze keer ook team killers :skull::skull: "
    $content_victims =  '```' + ($victims | Format-Table | out-string) + '```'
        send-discord -content $content_victims
    }

    
    $legenda = '
```
dmg_h   = Schade aangericht aan echte spelers
dmg     = Totale schade (aan zowel echte spelers als AI)
k_h     = Aantal echte spelers die je hebt geelimineerd
K_a     = Totale aantal eliminaties (inclusief AI)
t_serv  = Overleefde tijd (in minuten)
k_t     = Team eliminaties
```
        '
    
    #send-discord -content $legenda
    
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

remove-lock