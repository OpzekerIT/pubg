$logprefix = Get-Date -Format "ddMMyyyy_HHmmss"
if ($PSScriptRoot.length -eq 0) {
    $scriptroot = Get-Location
}
else {
    $scriptroot = $PSScriptRoot
}
$RelativeLogdir = Join-Path -Path $scriptroot -ChildPath "..\logs"
$logDir = (Resolve-Path -Path $RelativeLogdir).Path

Start-Transcript -Path "$logDir/report_new_matches_$logprefix.log" -Append
. $scriptroot\..\includes\ps1\lockfile.ps1
new-lock -by "report_new_matches"
write-output "Scriptroot: $scriptroot"
write-output "Scriptname: $($MyInvocation.MyCommand)"
write-output "Script: $($MyInvocation.MyCommand.Path)"
write-output "PSScriptroot: $PSScriptRoot"
write-output "Logdir: $logDir"

$fileContent = Get-Content -Path "$scriptroot/../config/config.php" -Raw

# Use regex to match the apiKey value
if ($fileContent -match "\`$apiKey\s*=\s*\'([^\']+)\'") {
    $apiKey = $matches[1]
}
else {
    write-output "API Key not found"
}

$headers = @{
    'accept'        = 'application/vnd.api+json'
    'Authorization' = "$apiKey"
}


$fileContent = Get-Content -Path "$scriptroot/../discord/config.php" -Raw

# Use regex to match the apiKey value
if ($fileContent -match "\`$webhookurl\s*=\s*'([^']+)'") {
    $webhookurl = $matches[1]
}
else {
    write-output "No web url found"
}

# Use regex to match the losers webhook url
if ($fileContent -match "\`$webhookurl_losers\s*=\s*'([^']+)'") {
    $webhookurl_losers = $matches[1]
}
else {
    write-output "No losers web url found"
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

function send-discord-losers {
    param (
        $content
    )
    $payload = [PSCustomObject]@{
        content = $content
    }
    if ($payload.content -eq "") {
        $payload = [PSCustomObject]@{
            content = "Nothing to report"
        }
    }
    Invoke-RestMethod -Uri $webhookurl_losers -Method Post -Body ($payload | ConvertTo-Json) -ContentType 'Application/Json'

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
    "Neon_Main"       = "Rondo"
}

try { 
    $player_matches = get-content "$scriptroot/../data/player_matches.json" | convertfrom-json -Depth 100 
}
catch {
    write-output 'Unable to read file exitin' 
}
write-output $player_matches
write-output $new_win_matches
$new_win_matches = $player_matches[-2].new_win_matches

# Gebruik nu de lijst van nieuwe verloren matches uit het JSON-bestand
$new_loss_matches = $player_matches[-1].new_loss_matches

# Post verloren matches naar #losers kanaal
# foreach ($lossid in $new_loss_matches) {
#     $lossmatch = $player_matches.player_matches | Where-Object { $_.id -eq $lossid }
#     if ($null -eq $lossmatch) { continue }
#     if ($lossmatch[0].gameMode -eq 'tdm') { continue }

#     # Fetch detailed match stats and telemetry for the loss
#     $loss_match_stats = $null
#     $loss_telemetry = $null
#     try {
#         $loss_match_stats = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/matches/$lossid" -Method GET -Headers $headers
#         $loss_telemetry = (invoke-webrequest @($lossmatch.telemetry_url)[0]).content | convertfrom-json | where-object { ($_._T -eq 'LOGPLAYERTAKEDAMAGE') -or ($_._T -eq 'LOGPLAYERKILLV2') }
#     } catch {
#         $errorMessage = $_.Exception.Message
#         Write-Warning ("Failed to fetch API/telemetry data for loss match {0}: {1}" -f $lossid, $errorMessage)
#     }

#     $loss_stats_table = @()
#     $loss_victims = @() # For team damage

#     # Iterate through players found in the locally stored match data for this loss
#     foreach ($player_stat in $lossmatch[0].stats) {
#         $player_name = $player_stat.name
#         # Find the corresponding detailed stats from the API response
#         $detailed_player_stats = $null
#         if ($null -ne $loss_match_stats) {
#              $detailed_player_stats = $loss_match_stats.included | Where-Object {$_.type -eq 'participant'} | ForEach-Object {$_.attributes.stats} | Where-Object { $_.name -eq $player_name }
#         }

#         if ($null -eq $detailed_player_stats) {
#             Write-Warning "Could not find detailed stats for player $player_name in loss match $lossid. Using basic stats."
#             # Fallback to basic stats if detailed stats are missing
#              $loss_stats_table += [PSCustomObject]@{
#                 Name          = $player_name
#                 'Human dmg'   = "N/A"
#                 'Human Kills' = "N/A"
#                 'Dmg'         = "$([math]::Round($player_stat.damageDealt))" # Use basic stat
#                 'Kills'       = "$($player_stat.kills)" # Use basic stat
#                 'alive'       = "$([math]::Round(($player_stat.timeSurvived / 60)))" # Use basic stat
#             }
#             continue # Skip telemetry processing if detailed stats failed
#         }

#         # Calculate stats (similar to win stats calculation)
#         $human_dmg = "N/A"
#         $human_kills = "N/A"
#         if ($null -ne $loss_telemetry) {
#              try {
#                 $human_dmg = [math]::Round(($loss_telemetry | Where-Object { $_._T -eq 'LOGPLAYERTAKEDAMAGE' -and $_.attacker.name -eq $player_name -and $_.victim.accountId -notlike "ai.*" -and $_.victim.teamId -ne $_.attacker.teamId } | Measure-Object -Property damage -Sum).Sum)
#                 $human_kills = ($loss_telemetry | Where-Object { $_._T -eq 'LOGPLAYERKILLV2' -and $_.killer.name -eq $player_name -and $_.victim.accountId -notlike "ai.*" }).count
#              } catch {
#                  $errorMessage = $_.Exception.Message
#                  Write-Warning ("Error processing telemetry stats for {0} in loss {1}: {2}" -f $player_name, $lossid, $errorMessage)
#              }
#         }

#         $loss_stats_table += [PSCustomObject]@{
#             Name          = $player_name
#             'Human dmg'   = "$human_dmg"
#             'Human Kills' = "$human_kills"
#             'Dmg'         = "$([math]::Round($detailed_player_stats.damageDealt))"
#             'Kills'       = "$($detailed_player_stats.kills)"
#             'alive'       = "$([math]::Round(($detailed_player_stats.timeSurvived / 60)))"
#         }

#         # Calculate team damage
#          if ($null -ne $loss_telemetry) {
#              try {
#                 $teamdmg = $loss_telemetry | Where-Object {
#                     $_._T -eq 'LOGPLAYERTAKEDAMAGE' -and
#                     $_.victim.teamId -eq $_.attacker.teamId -and
#                     $_.victim.accountId -notlike "ai.*" -and
#                     $_.victim.name -ne $_.attacker.name -and
#                     $_.attacker.name -eq $player_name
#                 }
#                 if ($teamdmg.count -ge 1) {
#                     foreach ($victim_name in ($teamdmg.victim.name | Select-Object -Unique)) {
#                         $loss_victims += [PSCustomObject]@{
#                             attacker = $player_name
#                             victim   = $victim_name
#                             Damage   = "$([math]::Round((($teamdmg | Where-Object { $_.victim.name -eq $victim_name }).damage | Measure-Object -Sum).Sum))"
#                         }
#                     }
#                 }
#              } catch {
#                  $errorMessage = $_.Exception.Message
#                  Write-Warning ("Error processing team damage for {0} in loss {1}: {2}" -f $player_name, $lossid, $errorMessage)
#              }
#         }
#     }

#     # Format the stats table
#     $content_lossstats = ""
#     if ($loss_stats_table.Count -gt 0) {
#         $content_lossstats = '```' + ($loss_stats_table | Format-Table -AutoSize | Out-String) + '```'
#     }

#     # Format team damage table
#     $content_loss_victims = ""
#     if ($loss_victims.Count -gt 0) {
#         $content_loss_victims = ":skull::skull: Team Damage :skull::skull:`n" + '```' + ($loss_victims | Format-Table -AutoSize | Out-String) + '```'
#     }

#     # Original message construction variables
#     $losers = $lossmatch[0].stats.name -join ', ' # Join names for display
#     $map = $map_map[$lossmatch[0].mapName]
#     $place = ($lossmatch[0].stats | Select-Object -First 1).winPlace # Get placement from the first player stat
#     $first_player_name = ($lossmatch[0].stats | Select-Object -First 1).name
#     $replay_url = $lossmatch[0].telemetry_url -replace 'https://telemetry-cdn.pubg.com/bluehole-pubg', 'https://chickendinner.gg'
#     $replay_url = $replay_url -replace '-telemetry.json', ''
#     $replay_url = $replay_url + "?follow=$first_player_name" # Follow the first player
#     $match_settings = @"
# ``````
# match mode      $($lossmatch[0].gameMode)
# match type      $($lossmatch[0].matchType)
# map             $($map_map[$lossmatch[0].mapName])
# id              $($lossmatch[0].id)
# ``````
# "@
#     send-discord-losers -content "We hebben een LOSERT! Geen Kip voor jou! :skull::skull:"
#     send-discord-losers -content ":partying_face::partying_face::partying_face: Helaas, $($losers) :partying_face::partying_face::partying_face:"
#     send-discord-losers -content $match_settings
#     send-discord-losers -content $content_lossstats
#     send-discord-losers -content $content_loss_victims
#     send-discord-losers -content "[2D replay](<$replay_url>)"
#     send-discord-losers -content "Meer match details [DTCH_STATS](<https://dtch.online/matchinfo.php?matchid=$($lossmatch[0].id)>)" 
# }


foreach ($winid in $new_win_matches) {

    $win_stats = @()
    $victims = @()
    if ($null -eq $winid) { continue }
    $winmatches = $player_matches.player_matches | Where-Object { $_.id -eq $winid }
    $telemetry = (invoke-webrequest @($winmatches.telemetry_url)[0]).content | convertfrom-json | where-object { ($_._T -eq 'LOGPLAYERTAKEDAMAGE') -or ($_._T -eq 'LOGPLAYERKILLV2') }
    $winners = @(($winmatches | where-object { $_.stats.winPlace -eq 1 }).stats.name)
    #    $2D_replay_url = @($winmatches.telemetry_url)[0] -replace 'https://telemetry-cdn.pubg.com/bluehole-pubg', 'https://chickendinner.gg'
    #    $2D_replay_url = $2D_replay_url -replace '-telemetry.json', ''
    #    $2D_replay_url = $2D_replay_url + "?follow=$($winners[0])"
    $2D_replay_url = 'https://chickendinner.gg/' + $winid
    $match_stats = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/matches/$winid" -Method GET -Headers $headers
    if ($winmatches[0].gameMode -eq 'tdm' ) {
        continue
    }
    if (
        ($winmatches[0].matchtype -eq 'event' -and $winmatches[0].gameMode -ne 'ibr') -or
        ($winmatches[0].gameMode -eq 'tdm')
    ) {
        Write-Output 'Skipping because of event or tdm'
        continue
    } #skip tdm matches
    if ($winmatches[0].matchType -eq 'custom') {
        $players_to_report = $match_stats.included.attributes.stats | where-object { $_.playerId -notlike "ai.*" }
    }
    else {
        $players_to_report = $match_stats.included.attributes.stats | where-object { $_.winplace -eq 1 }
    }
    $2D_replay_url = 'https://chickendinner.gg/' + $winid + "/" + $players_to_report[0].name
    if ($new_win_matches.count -le 10) {
        #fail safe
        $winnerswithurl = @()
        foreach ($winner in $winners) {
            $winnerswithurl += "[$winner](<https://dtch.online/latestmatches.php?selected_player=$($winner)>)"
        }
        send-discord -content ":chicken: :chicken: **WINNER WINNER CHICKEN DINNER!!** :chicken: :chicken:"
        send-discord -content ":partying_face::partying_face::partying_face: Gefeliciteerd   $($winnerswithurl -join ', ') :partying_face::partying_face::partying_face:"
        $match_settings = @"
``````
match mode      $($winmatches[0].gameMode)
match type      $($winmatches[0].matchType)
map             $($map_map[$winmatches[0].mapName])
id              $($winmatches[0].id)
``````
"@
        send-discord -content $match_settings
    }
    else {
        write-output "Something went wrong (more then 10 matches to report)"
    }
    foreach ($player in $players_to_report.name) {
        if ($null -eq $player) { continue }
        write-output "creating table for player $player"
        $win_stats += [PSCustomObject]@{ 
            Name          = $player
            'Human dmg'   = "$([math]::Round(($telemetry | Where-Object { $_._T -eq 'LOGPLAYERTAKEDAMAGE' -and $_.attacker.name -eq $player -and $_.victim.accountId -notlike "ai.*" -and $_.victim.teamId -ne $_.attacker.teamId } | Measure-Object -Property damage -Sum).Sum))"
            'Human Kills' = "$(($telemetry | Where-Object { $_._T -eq 'LOGPLAYERKILLV2' -and $_.killer.name -eq $player -and $_.victim.accountId -notlike "ai.*" }).count)"
            'Dmg'         = "$([math]::Round(($players_to_report | Where-Object { $_.name -eq $player }).damageDealt))"
            'Kills'       = "$(($players_to_report | Where-Object { $_.name -eq $player }).kills)"
            'alive'       = "$([math]::Round((($players_to_report | Where-Object { $_.name -eq $player }).timeSurvived /60 )))"
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
    write-output "New win matches:"
    $new_win_matches
    if ($new_win_matches.count -le 10) {
        $content_winstats = '```' + ($win_stats | Format-Table | out-string) + '```'
        send-discord -content $content_winstats

        if ($victims.count -ge 1) {
            send-discord -content ":skull::skull: Helaas hebben we deze keer ook team killers :skull::skull: "
            $content_victims = '```' + ($victims | Format-Table | out-string) + '```'
            send-discord -content $content_victims
        }

        send-discord -content "[2D replay](<$2D_replay_url>)"
        send-discord -content "More match details [DTCH_STATS](<https://dtch.online/matchinfo.php?matchid=$($winmatches[0].id)>)"
    }
    else {
        write-output "Something went wrong (more then 10 matches to report)"
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
    if ($item.PSObject.Properties.Name -contains "new_loss_matches") {
        $item.new_loss_matches = $null
    }
}

# Convert back to JSON (optional)
$newJson = $player_matches | ConvertTo-Json -Depth 100

# Display the updated JSON
$newJson | out-file "$scriptroot/../data/player_matches.json"

remove-lock
Stop-Transcript

