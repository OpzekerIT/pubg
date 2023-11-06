. .\..\includes\ps1\lockfile.ps1

new-lock

if ($PSScriptRoot.length -eq 0) {
    $scriptroot = Get-Location
}
else {
    $scriptroot = $PSScriptRoot
}

function Get-Change {
    param (
        [double]$OldWinRatio,
        [double]$NewWinRatio
    )

    $change = ($OldWinRatio -eq 0) ? (($NewWinRatio -eq 0) ? 0 : $NewWinRatio) : ($NewWinRatio - $OldWinRatio)
    
    return [math]::Round($change, 2)
}

function get-killstats {
    param (
        $player_name,
        $telemetry,
        $matchType,
        $gameMode
    )
    $attacks = @()
    foreach ($action in $telemetry) {

        $attacks += $action
        
    }
    $kills = $attacks | where-object { $_.killer.name -eq $player_name }
    return @{
        playername = $player_name
        humankills = ($kills | where-object { $_.victim.accountId -notlike 'ai.*' }).count
        kills      = $kills.count
        deaths     = ($attacks | where-object { $_.victim.name -eq $player_name }).count
        gameMode   = $gameMode
        matchType  = $matchType
        dbno       = ($attacks | where-object { $_.dBNOMaker.name -eq $player_name }).count
        

    }
}
# Get the latest file in the directory by last modification time
try {
    $latestFile = Get-ChildItem -Path "$scriptroot/../data/archive/" -File -ErrorAction Stop | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Output "Found file $($latestFile.FullName)"

}
catch { 
    $latestFile = @()
    
}

# Display the result
if ($latestFile.FullName) {
    write-host "getting info from $($latestFile.FullName)" 
    $oldstats = get-content $latestFile.FullName  | ConvertFrom-Json
}
else {
    write-output 'setting old stats var empty'
    $oldstats = @()
}


$all_player_matches = get-content  "$scriptroot/../data/player_matches.json" | convertfrom-json -Depth 100
$killstats = @()
$i = 0

foreach ($player in $all_player_matches) {
    if ($player.psobject.properties.name -eq 'new_win_matches') {
        continue
    }
    $player_name = $player.playername
    $i++
    $j = 0
    write-output "$($all_player_matches.count) / $i"
    foreach ($match in $player.player_matches) {
        $j++
        write-output "$($player.player_matches.count)/ $j"
       
        if (!(Test-Path -path "$scriptroot/../data/killstats/$($match.id)_$player_name.json" )) {
            $telemetryfile = "$scriptroot/../data/telemetry_cache/$($match.telemetry_url.split("/")[-1])"
            if (!(test-path -Path $telemetryfile)) {
                write-output "Saving $telemetryfile"
                $telemetry_content = (Invoke-WebRequest -Uri $match.telemetry_url).content
                $telemetry_content | out-file $telemetryfile
                $telemetry = $telemetry_content | ConvertFrom-Json
            }
            else {
                write-output "Getting from cache $telemetryfile"
                $telemetry = get-content $telemetryfile  | convertfrom-json
            }
       
            write-output "Analyzing for player $player_name telemetry: $($match.telemetry_url)"
            $killstat = get-killstats -player_name $player_name -telemetry ($telemetry | where-object { $_._T -eq 'LOGPLAYERKILLV2' }) -gameMode $match.gameMode -matchType $match.matchType
        
        
            $savekillstats = @{
                matchid = $match.id
                created = $match.createdAt
                stats   = $killstat
                winplace = (($all_player_matches | where-object { $_.playername -eq $player_name } ).player_matches | where-object {$_.id -eq $match.id}).stats.winplace
            }
            $savekillstats | ConvertTo-Json | out-file "$scriptroot/../data/killstats/$($match.id)_$player_name.json"
            $killstats += $killstat
        } else{
            write-output "match $($match.id) already in cache"
            $killstats += (get-content "$scriptroot/../data/killstats/$($match.id)_$player_name.json" | ConvertFrom-Json).stats
        }

    }
}

$playerstats_all = @()
foreach ($player in $all_player_matches.playername) {
    if ($null -eq $player) {
        continue
    }
    $deaths = (($killstats | where-object { $_.playername -eq $player }).deaths | Measure-Object -sum).sum
    $kills = (($killstats | where-object { $_.playername -eq $player }).kills | Measure-Object -sum).sum
    $dbno = (($killstats | where-object { $_.playername -eq $player }).dbno | Measure-Object -sum).sum
    $humankills = (($killstats | where-object { $_.playername -eq $player }).humankills | Measure-Object -sum).sum
    $player_matches = ($all_player_matches | where-object { $_.playername -eq $player }).player_matches.count
    $player_wins = ($all_player_matches | where-object { $_.playername -eq $player } | ForEach-Object { $_.player_matches } | where-object { $_.stats.winPlace -eq 1 }).count
    $winratio = ($player_wins / $player_matches) * 100
    $winratio_old = (($oldstats.all | Where-Object { $_.playername -eq $player }).winratio)
    $change = get-change -OldWinRatio $winratio_old -NewWinRatio $winratio
    write-output 'all'
    write-output "Calculating for player $player"
    write-output "new winratio $winratio"
    write-output "Old winratio $winratio_old"
    write-output $change


    $playerstats_all += [PSCustomObject]@{ 
        playername = $player
        deaths     = $deaths
        kills      = $kills
        humankills = $humankills
        matches    = ($all_player_matches | where-object { $_.playername -eq $player }).player_matches.count
        KD_H       = $humankills / $deaths
        KD_ALL     = $kills / $deaths
        winratio   = $winratio
        wins       = $player_wins
        dbno       = $dbno
        change     = $change

    }
}
$playerstats_all = $playerstats_all | Sort-Object winratio -Descending

##IBR

$playerstats_event_ibr = @()
foreach ($player in $all_player_matches.playername) {
    if ($null -eq $player) {
        continue
    }
    $deaths = (($killstats | where-object { $_.playername -eq $player -and $_.gameMode -eq 'ibr' -and $_.matchType -eq 'event' }).deaths | Measure-Object -sum).sum
    $kills = (($killstats | where-object { $_.playername -eq $player -and $_.gameMode -eq 'ibr' -and $_.matchType -eq 'event' }).kills | Measure-Object -sum).sum
    $dbno = (($killstats | where-object { $_.playername -eq $player -and $_.gameMode -eq 'ibr' -and $_.matchType -eq 'event' }).dbno | Measure-Object -sum).sum
    $humankills = (($killstats | where-object { $_.playername -eq $player -and $_.gameMode -eq 'ibr' -and $_.matchType -eq 'event' }).humankills | Measure-Object -sum).sum
    $player_matches = ((($all_player_matches | where-object { $_.playername -eq $player }).player_matches | Where-Object { $_.matchType -eq 'event' -and $_.gameMode -eq 'ibr' }).count)
    $player_wins = ($all_player_matches | where-object { $_.playername -eq $player } | ForEach-Object { $_.player_matches } | where-object { $_.stats.winPlace -eq 1 } | Where-Object { $_.matchType -eq 'event' -and $_.gameMode -eq 'ibr' }).count
    $winratio = ($player_wins / $player_matches) * 100
    $winratio_old = (($oldstats.Intense | Where-Object { $_.playername -eq $player }).winratio)
    $change = get-change -OldWinRatio $winratio_old -NewWinRatio $winratio

    write-output 'event'
    write-output "Calculating for player $player"
    write-output "new winratio $winratio"
    write-output "Old winratio $winratio_old"
    write-output $change

    $playerstats_event_ibr += [PSCustomObject]@{ 
        playername = $player
        deaths     = $deaths
        kills      = $kills
        humankills = $humankills
        matches    = ((($all_player_matches | where-object { $_.playername -eq $player }).player_matches | Where-Object { $_.matchType -eq 'event' -and $_.gameMode -eq 'ibr' }).count)
        KD_H       = $humankills / $deaths
        KD_ALL     = $kills / $deaths
        winratio   = ($player_wins / $player_matches) * 100
        wins       = $player_wins
        dbno       = $dbno
        change     = $change
    }
}
$playerstats_event_ibr = $playerstats_event_ibr | Sort-Object winratio -Descending

##airoyale
$playerstats_airoyale = @()
foreach ($player in $all_player_matches.playername) {
    if ($null -eq $player) {
        continue
    }
    $deaths = (($killstats | where-object { $_.playername -eq $player -and $_.matchType -eq 'airoyale' }).deaths | Measure-Object -sum).sum
    $kills = (($killstats | where-object { $_.playername -eq $player -and $_.matchType -eq 'airoyale' }).kills | Measure-Object -sum).sum
    $dbno = (($killstats | where-object { $_.playername -eq $player -and $_.matchType -eq 'airoyale' }).dbno | Measure-Object -sum).sum
    $humankills = (($killstats | where-object { $_.playername -eq $player -and $_.matchType -eq 'airoyale' }).humankills | Measure-Object -sum).sum
    $player_matches = ((($all_player_matches | where-object { $_.playername -eq $player }).player_matches | Where-Object { $_.matchType -eq 'airoyale' }).count)
    $player_wins = ($all_player_matches | where-object { $_.playername -eq $player } | ForEach-Object { $_.player_matches } | where-object { $_.stats.winPlace -eq 1 } | Where-Object { $_.matchType -eq 'airoyale' }).count
    $winratio = ($player_wins / $player_matches) * 100
    $winratio_old = (($oldstats.Casual | Where-Object { $_.playername -eq $player }).winratio)
    $change = get-change -OldWinRatio $winratio_old -NewWinRatio $winratio

    write-output 'airoyale'
    write-output "Calculating for player $player"
    write-output "new winratio $winratio"
    write-output "Old winratio $winratio_old"
    write-output $change


    $playerstats_airoyale += [PSCustomObject]@{ 
        playername = $player
        deaths     = $deaths
        kills      = $kills
        humankills = $humankills
        matches    = ((($all_player_matches | where-object { $_.playername -eq $player }).player_matches | Where-Object { $_.matchType -eq 'airoyale' }).count)
        KD_H       = $humankills / $deaths
        KD_ALL     = $kills / $deaths
        winratio   = ($player_wins / $player_matches) * 100
        wins       = $player_wins
        dbno       = $dbno
        change     = $change
    }
}
$playerstats_airoyale = $playerstats_airoyale | Sort-Object winratio -Descending

$playerstats_official = @()
foreach ($player in $all_player_matches.playername) {
    if ($null -eq $player) {
        continue
    }
    $deaths = (($killstats | where-object { $_.playername -eq $player -and $_.matchType -eq 'official' }).deaths | Measure-Object -sum).sum
    $kills = (($killstats | where-object { $_.playername -eq $player -and $_.matchType -eq 'official' }).kills | Measure-Object -sum).sum
    $dbno = (($killstats | where-object { $_.playername -eq $player -and $_.matchType -eq 'official' }).dbno | Measure-Object -sum).sum
    $humankills = (($killstats | where-object { $_.playername -eq $player -and $_.matchType -eq 'official' }).humankills | Measure-Object -sum).sum
    $player_matches = ((($all_player_matches | where-object { $_.playername -eq $player }).player_matches | Where-Object { $_.matchType -eq 'official' }).count)
    $player_wins = ($all_player_matches | where-object { $_.playername -eq $player } | ForEach-Object { $_.player_matches } | where-object { $_.stats.winPlace -eq 1 } | Where-Object { $_.matchType -eq 'official' }).count
    $winratio = ($player_wins / $player_matches) * 100
    $winratio_old = (($oldstats.official | Where-Object { $_.playername -eq $player }).winratio)
    $change = get-change -OldWinRatio $winratio_old -NewWinRatio $winratio
    write-output 'official'
    write-output "Calculating for player $player"
    write-output "new winratio $winratio"
    write-output "Old winratio $winratio_old"
    write-output $change

    $playerstats_official += [PSCustomObject]@{ 
        playername = $player
        deaths     = $deaths
        kills      = $kills
        humankills = $humankills
        matches    = ((($all_player_matches | where-object { $_.playername -eq $player }).player_matches | Where-Object { $_.matchType -eq 'official' }).count)
        KD_H       = $humankills / $deaths
        KD_ALL     = $kills / $deaths
        winratio   = ($player_wins / $player_matches) * 100
        wins       = $player_wins
        dbno       = $dbno
        change     = $change
    }
}
$playerstats_official = $playerstats_official | Sort-Object winratio -Descending

##CUSTOM GAMES

$playerstats_custom = @()
foreach ($player in $all_player_matches.playername) {
    if ($null -eq $player) {
        continue
    }
    $deaths = (($killstats | where-object { $_.playername -eq $player -and $_.matchType -eq 'custom' }).deaths | Measure-Object -sum).sum
    $kills = (($killstats | where-object { $_.playername -eq $player -and $_.matchType -eq 'custom' }).kills | Measure-Object -sum).sum
    $dbno = (($killstats | where-object { $_.playername -eq $player -and $_.matchType -eq 'custom' }).dbno | Measure-Object -sum).sum
    $humankills = (($killstats | where-object { $_.playername -eq $player -and $_.matchType -eq 'custom' }).humankills | Measure-Object -sum).sum
    $player_matches = ((($all_player_matches | where-object { $_.playername -eq $player }).player_matches | Where-Object { $_.matchType -eq 'custom' }).count)
    $player_wins = ($all_player_matches | where-object { $_.playername -eq $player } | ForEach-Object { $_.player_matches } | where-object { $_.stats.winPlace -eq 1 } | Where-Object { $_.matchType -eq 'custom' }).count
    $winratio = ($player_wins / $player_matches) * 100
    $winratio_old = (($oldstats.custom | Where-Object { $_.playername -eq $player }).winratio)
    $change = get-change -OldWinRatio $winratio_old -NewWinRatio $winratio
    write-output 'custom'
    write-output "Calculating for player $player"
    write-output "new winratio $winratio"
    write-output "Old winratio $winratio_old"
    write-output $change

    $playerstats_custom += [PSCustomObject]@{ 
        playername = $player
        deaths     = $deaths
        kills      = $kills
        humankills = $humankills
        matches    = ((($all_player_matches | where-object { $_.playername -eq $player }).player_matches | Where-Object { $_.matchType -eq 'custom' }).count)
        KD_H       = $humankills / $deaths
        KD_ALL     = $kills / $deaths
        winratio   = ($player_wins / $player_matches) * 100
        wins       = $player_wins
        dbno       = $dbno
        change     = $change
    }
}
$playerstats_custom = $playerstats_custom | Sort-Object winratio -Descending

$currentDateTime = Get-Date

# Get current timezone
$currentTimezone = (Get-TimeZone).Id

# Format and parse the information into a string
$formattedString = "$currentDateTime - Time Zone: $currentTimezone"

# Output the formatted string

$playerstats = [PSCustomObject]@{
    all      = $playerstats_all
    Intense  = $playerstats_event_ibr
    Casual   = $playerstats_airoyale
    official = $playerstats_official
    custom   = $playerstats_custom
    updated  = $formattedString
}

write-output "Writing file"
($playerstats | convertto-json) | out-file "$scriptroot/../data/player_last_stats.json"


$date = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$filenameDate = ($date -replace ":", "-")
($playerstats | convertto-json) | out-file "$scriptroot/../data/archive/$($filenameDate)_player_last_stats.json"

write-output "Cleaning cache"

$files_keep = (($all_player_matches).player_matches.telemetry_url | Select-Object -Unique) | ForEach-Object { $_.split("/")[-1] }
$files_cache = (get-childitem "$scriptroot/../data/telemetry_cache/").name


$difference = (Compare-Object -ReferenceObject $files_keep -DifferenceObject $files_cache | Where-Object { $_.SideIndicator -eq "=>" }).InputObject

foreach ($file in $difference) {
    write-output "removing $scriptroot/../data/telemetry_cache/$file"
    Remove-Item -Path "$scriptroot/../data/telemetry_cache/$file"
}
write-output "Operation complete"
remove-lock