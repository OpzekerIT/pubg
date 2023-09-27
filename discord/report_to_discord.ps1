

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

$stats = get-content "$scriptroot/../data/player_last_stats.json" | convertfrom-json

foreach ($player in $stats) {
    if ($player.KD_H -eq "Infinity") {
        $player.KD_H = 0
    }

    if ($player.KD_ALL -eq "Infinity") {
        $player.KD_ALL = 0
    }
}

$most_kills = @{
    'name' = (($stats | Sort-Object kills -Descending)[0].playername)
    'stat' = (($stats | Sort-Object kills -Descending)[0].kills)
}
$most_deaths = @{
    'name' = (($stats | Sort-Object deaths -Descending)[0].playername)
    'stat' = (($stats | Sort-Object deaths -Descending)[0].deaths)
}
$most_humankills = @{
    'name' = (($stats | Sort-Object humankills -Descending)[0].playername)
    'stat' = (($stats | Sort-Object humankills -Descending)[0].humankills)
}
$most_KD_H = @{
    'name' = (($stats | Sort-Object KD_H -Descending)[0].playername)
    'stat' = (($stats | Sort-Object KD_H -Descending)[0].KD_H)
}
$most_KD_ALL = @{
    'name' = (($stats | Sort-Object KD_ALL -Descending)[0].playername)
    'stat' = (($stats | Sort-Object KD_ALL -Descending)[0].KD_ALL)
}
$most_matches = @{
    'name' = (($stats | Sort-Object matches -Descending)[0].playername)
    'stat' = (($stats | Sort-Object matches -Descending)[0].matches)
}

$content = "
:rocket: Het 2 wekelijkse raportje :rocket:

Hey toppers!

Laten we eens duiken in de cijfers van onze supergamers van de afgelopen twee weken:

:dart: Meeste Kills:
Hats off voor **$($most_kills['name'])**! Met **$($most_kills['stat'])** kills is hij/zij onze scherpschutter van de week!

:skull_crossbones: Meeste Deaths:
Oei, oei, oei... **$($most_deaths['name'])** is helaas het vaakst naar het hiernamaals gestuurd met **$($most_deaths['stat'])** deaths. Kop op, volgende keer beter!

:robot: Meeste Humankills:
Watch out! We hebben een Terminator onder ons. Hoedje af voor **$($most_humankills['name'])** met **$($most_humankills['stat'])** humankills!

:bar_chart: Beste KD Ratio (Alle vijanden):
De onevenaarbare **$($most_KD_ALL['name'])** heeft een KD van **$($most_KD_ALL['stat'])** ! Niet slecht, toch? 😉

:adult: Beste KD Ratio (Alleen menselijke spelers):
Opgelet, gamers! **$($most_KD_H['name'])** heeft een KD van **$($most_KD_H['stat'])** tegen andere spelers! Wie daagt hem/haar uit?

:video_game: Meeste Matches:
Onze meest toegewijde gamer, **$($most_matches['name'])**, heeft maar liefst **$($most_matches['stat'])** matches gespeeld. Ga zo door!

Da's het voor nu, gamers! Blijf schieten, blijf lachen en tot het volgende rapportje!

High fives en knuffels (virtueel, natuurlijk),
Het Gaming Team

Meer stats zijn hier te vinden : https://lanta.eu/DTCH
"

$content



$payload = [PSCustomObject]@{

    content = $content

}

Invoke-RestMethod -Uri $webhookurl -Method Post -Body ($payload | ConvertTo-Json) -ContentType 'Application/Json'