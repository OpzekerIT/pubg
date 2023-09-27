if ($PSScriptRoot.length -eq 0) {
    $scriptroot = Get-Location
}
else {
    $scriptroot = $PSScriptRoot
}


$fileContent = Get-Content -Path "$scriptroot/../discord/config.php" -Raw

# Use regex to match the apiKey value
if ($fileContent -match "\`$webhookurl\s*=\s*\'([^\']+)\'") {
    $webhookurl = $matches[1]
}
else {
    Write-Output "API Key not found"
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

$player_matches = get-content "$scriptroot/../data/player_matches.json" | convertfrom-json -Depth 100
$new_win_matches = $player_matches.new_win_matches
$win_stats = @()

foreach ($winid in $new_win_matches) {

    

    
    if ($null -eq $winid) { continue }
    $winmatches = $player_matches.player_matches | Where-Object { $_.id -eq $winid }
    $telemetry = (invoke-webrequest @($winmatches.telemetry_url)[0]).content | convertfrom-json
    $players = $winmatches.stats.name 

    send-discord -content ":chicken: :chicken: CHICKEN CHICKEN WINNER DINNER!! :chicken: :chicken:"
    send-discord -content "Gefeliciteerd $($players -join ' ')"
    send-discord -content "match Type $($winmatches[0].matchType)"
    send-discord -content "map $($winmatches[0].mapName)"

    foreach ($player in $players) {

        $win_stats += [PSCustomObject]@{ 
            playername   = $player
            dmg_h   = (($telemetry | where-object { $_._T -eq 'LOGPLAYERTAKEDAMAGE' } | where-object { $_.attacker.name -eq $player } | where-object { $_.victim.accountId -notlike "ai.*" } ).damage | Measure-Object -Sum).Sum
            dmg     = ($winmatches.stats | Where-Object { $_.name -eq $player }).damageDealt
            k_h  = (($telemetry | where-object { $_._T -eq 'LOGPLAYERKILLV2' } | where-object { $_.killer.name -eq $player } | where-object { $_.victim.accountId -notlike "ai.*" } )).count
            k_a    = ($winmatches.stats | Where-Object { $_.name -eq $player }).kills
            k_t    = ($winmatches.stats | Where-Object { $_.name -eq $player }).teamKills
            t_serv = ($winmatches.stats | Where-Object { $_.name -eq $player }).timeSurvived
        }
    }
}

$content_winstats =  '```' + ($win_stats | Format-Table | out-string) + '```'
send-discord -content $content_winstats

$legenda = "

Legenda: 

dmg_h = Damege tegen echte spelers
dmg = Alle dmg zowel echte spelers als ai
k_h = Echte spelers die ge gekilled hebt
K_a = alle spelers kills
t_serv = time survived in secondes
"

send-discord -content $legenda

foreach ($item in $player_matches) {
    if ($item.PSObject.Properties.Name -contains "new_win_matches") {
        $item.new_win_matches = $null
    }
}

# Convert back to JSON (optional)
$newJson = $player_matches | ConvertTo-Json -Depth 100

# Display the updated JSON
$newJson | out-file "$scriptroot/../data/player_matches.json"