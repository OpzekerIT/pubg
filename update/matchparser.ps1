Start-Transcript -Path '/var/log/dtch/matchparser.log' -Append
Write-Output 'Running from'
(Get-Location).path

if ($PSScriptRoot.length -eq 0) {
    $scriptroot = Get-Location
}
else {
    $scriptroot = $PSScriptRoot
}

. $scriptroot\..\includes\ps1\lockfile.ps1
new-lock -by "matchparser"
##SETTINGS
$monthsback = -3 # how many months back to look for matches
##END OF SETTINGS
function Get-Change {
    param (
        [double]$OldWinRatio,
        [double]$NewWinRatio
    )

    $change = ($OldWinRatio -eq 0) ? (($NewWinRatio -eq 0) ? 0 : $NewWinRatio) : ($NewWinRatio - $OldWinRatio)
    
    return [math]::Round($change, 2)
}

function Get-winratio {
    param (
        [int]$player_wins,
        [int]$player_matches
    )
    if ($player_wins -eq 0 -or $player_matches -eq 0) {
        $winratio = 0
    }
    else {
        $winratio = ($player_wins / $player_matches) * 100
    }
    return $winratio
}
function get-killstats {
    param (
        $player_name,
        $telemetry,
        $matchType,
        $gameMode
    )
    $LOGPLAYERKILLV2 = $telemetry | where-object { $_._T -eq 'LOGPLAYERKILLV2' }
    $kills = $LOGPLAYERKILLV2 | where-object { $_.killer.name -eq $player_name }
    $deaths = $LOGPLAYERKILLV2 | where-object { $_.victim.name -eq $player_name -and $_.finisher.name.count -ge 1 }
    $HumanDmg = $([math]::Round(($telemetry | Where-Object { $_._T -eq 'LOGPLAYERTAKEDAMAGE' -and $_.attacker.name -eq $player_name -and $_.victim.accountId -notlike "ai.*" -and $_.victim.teamId -ne $_.attacker.teamId } | Measure-Object -Property damage -Sum).Sum))
    return @{
        playername = $player_name
        humankills = ($kills | where-object { $_.victim.accountId -notlike 'ai.*' }).count
        kills      = $kills.count
        deaths     = ($deaths).count
        gameMode   = $gameMode
        matchType  = $matchType
        dbno       = ($kills | where-object { $_.dBNOMaker.name -eq $player_name }).count
        HumanDmg   = $HumanDmg


    }
}

try {
    $filesarray = @()
    $files = Get-ChildItem -Path "$scriptroot/../data/archive/" -File -ErrorAction Stop
    foreach ($file in $files) {
        $dateinfile = $file.Name.split('_')[0]
        $format = 'yyyy-MM-ddTHH-mm-ss\Z'
        $culture = [Globalization.CultureInfo]::InvariantCulture
        $dateTime = [datetime]::ParseExact($dateinfile, $format, $culture)
        $filesarray += [PSCustomObject]@{name = $file.Name; date = $dateTime }   
    }

    try { $latestFile = ($filesarray | where-object { ($_.date -gt (get-date).AddDays(-2)) -and ($_.date -lt (get-date).AddDays(-1)) } | Sort-Object date)[0] }
    catch { $latestFile = ($filesarray | sort-object date )[-1] }
    $latestFile = Get-Item -Path "$scriptroot/../data/archive/$($latestFile.name)"
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

try { 
    $all_player_matches = get-content  "$scriptroot/../data/player_matches.json" | convertfrom-json -Depth 100 
}
catch {   
    Write-Output 'Unable to read file exitin'
    exit
}



foreach ($player in $all_player_matches) {
    if ($player.psobject.properties.name -eq 'new_win_matches') {
        continue
    }
    $player_name = $player.playername

    foreach ($match in $player.player_matches) {
        write-output "Analyzing match $($match.id) for player $player_name"
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
            $killstat = get-killstats -player_name $player_name -telemetry ($telemetry | where-object { ($_._T -eq 'LOGPLAYERTAKEDAMAGE') -or ($_._T -eq 'LOGPLAYERKILLV2') }) -gameMode $match.gameMode -matchType $match.matchType
        
        
            $savekillstats = @{
                matchid   = $match.id
                created   = $match.createdAt
                stats     = $killstat
                deathType = $match.stats.deathType
                winplace  = (($all_player_matches | where-object { $_.playername -eq $player_name } ).player_matches | where-object { $_.id -eq $match.id }).stats.winplace
            }
            Write-Output "Writing to file $scriptroot/../data/killstats/$($match.id)_$player_name.json"
            $savekillstats | ConvertTo-Json | out-file "$scriptroot/../data/killstats/$($match.id)_$player_name.json"
            
           
        }
        else {
            Write-Output "$($match.id) already in cache"
        }
    }
}

$killstats = @()
$matchfiles = Get-ChildItem "$scriptroot/../data/killstats/" -File -Filter *.json

$killstats_clan_matches_gt_1 = @()
$killstats_clan_matches_gt_2 = @()
$killstats_clan_matches_gt_3 = @()
$guids = $matchfiles.Name | ForEach-Object { $_.Split("_")[0] }
$groupedGuids_clan_matches_gt_1 = $guids | Group-Object | Where-Object { $_.Count -gt 1 }
$groupedGuids_clan_matches_gt_2 = $guids | Group-Object | Where-Object { $_.Count -gt 2 }
$groupedGuids_clan_matches_gt_3 = $guids | Group-Object | Where-Object { $_.Count -gt 3 }

$last_month = (get-date).AddMonths($monthsback)
foreach ($file in $matchfiles) {
    $json = get-content $file | ConvertFrom-Json
    if ($json.created -gt $last_month) {
        $killstats += $json
        if ($groupedGuids_clan_matches_gt_1.Name -contains $json.matchid) {
            $killstats_clan_matches_gt_1 += $json
        }
        if ($groupedGuids_clan_matches_gt_2.Name -contains $json.matchid) {
            $killstats_clan_matches_gt_2 += $json
        }
        if ($groupedGuids_clan_matches_gt_3.Name -contains $json.matchid) {
            $killstats_clan_matches_gt_3 += $json
        }
    }
    else {
        write-output "Archiving $($file.name)"
        Move-Item -Path $file.FullName -Destination "$scriptroot/../data/killstats/archive/." -Force -Verbose
    }
}

function Get-MatchStatsPlayer {
    param (
        [switch] $GameMode,
        [switch] $MatchType,
        [string] $typemodevalue,
        [array] $playernames,
        [string] $friendlyname,
        [array] $killstats,
        [string] $sortstat
        
    )
    $MatchStatsPlayer = @()
    foreach ($player in $playernames) {
        if ($null -eq $player) {
            continue
        }
        if ($GameMode) {
            $filterProperty = 'gameMode'
        }
        if ($MatchType) {
            $filterProperty = 'matchType'
        }
        $alives = (($killstats | where-object { $_.stats.playername -eq $player -and $_.stats.$filterProperty -like $typemodevalue }).deathType | where-object { $_ -eq 'alive' }).count
        $deaths = (($killstats | where-object { $_.stats.playername -eq $player -and $_.stats.$filterProperty -like $typemodevalue }).deathType | where-object { $_ -ne 'alive' }).count
        $kills = (($killstats.stats | where-object { $_.playername -eq $player -and $_.$filterProperty -like $typemodevalue }).kills | Measure-Object -sum).sum
        $dbno = (($killstats.stats | where-object { $_.playername -eq $player -and $_.$filterProperty -like $typemodevalue }).dbno | Measure-Object -sum).sum
        $humankills = (($killstats.stats | where-object { $_.playername -eq $player -and $_.$filterProperty -like $typemodevalue }).humankills | Measure-Object -sum).sum
        $player_matches = ($killstats.stats | where-object { $_.playername -eq $player -and $_.$filterProperty -like $typemodevalue }).count
        $player_wins = ($killstats | where-object { $_.stats.playername -eq $player -and $_.winplace -eq 1 -and $_.stats.$filterProperty -like $typemodevalue }).count
        $winratio_old = (($oldstats.$friendlyname | Where-Object { $_.playername -eq $player }).winratio)
        $winratio = Get-winratio -player_wins $player_wins -player_matches $player_matches
        $change = get-change -OldWinRatio $winratio_old -NewWinRatio $winratio
        $avarage_human_damage = [math]::Round((($killstats.stats | where-object { $_.playername -eq $player -and $_.$filterProperty -like $typemodevalue } | Measure-Object -Property HumanDmg -Sum).Sum / $player_matches), 2)
        
        write-host $filterProperty
        write-host $typemodevalue
        write-host "Calculating for player $player"
        write-host "new winratio $winratio"
        write-host "Old winratio $winratio_old"
        write-host $change
    
        $MatchStatsPlayer += [PSCustomObject]@{ 
            alives     = $alives
            playername = $player
            deaths     = $deaths
            kills      = $kills
            humankills = $humankills
            matches    = $player_matches
            KD_H       = $humankills / ($deaths + $alives) # KD_Human calculated per match (kills / (deaths + alives))
            KD_ALL     = $kills / ($deaths + $alives) # KD_ALL calculated per match (kills / (deaths + alives))
            winratio   = $winratio
            wins       = $player_wins
            dbno       = $dbno
            change     = $change
            ahd        = $avarage_human_damage

        }
    }
    $MatchStatsPlayer_sorted = $MatchStatsPlayer | ForEach-Object {
        $_ | Add-Member -NotePropertyName RandomKey -NotePropertyValue (Get-Random) -PassThru
    } | Sort-Object -Property $sortstat -Descending | Select-Object -Property * -ExcludeProperty RandomKey #randomize the order

    return $MatchStatsPlayer_sorted
}




$playerstats_event_ibr = Get-MatchStatsPlayer -GameMode -typemodevalue 'ibr' -playernames $all_player_matches.playername -friendlyname 'Intense' -killstats $killstats -sortstat 'randomkey' 
$playerstats_airoyale = Get-MatchStatsPlayer -MatchType -typemodevalue 'airoyale' -playernames $all_player_matches.playername -friendlyname 'Casual' -killstats $killstats -sortstat 'randomkey' 
$playerstats_official = Get-MatchStatsPlayer -MatchType -typemodevalue 'official' -playernames $all_player_matches.playername -friendlyname 'official' -killstats $killstats -sortstat 'randomkey' 
$playerstats_custom = Get-MatchStatsPlayer -MatchType -typemodevalue 'custom' -playernames $all_player_matches.playername -friendlyname 'custom' -killstats $killstats -sortstat 'randomkey' 
$playerstats_all = Get-MatchStatsPlayer -MatchType -typemodevalue '*' -playernames $all_player_matches.playername -friendlyname 'all' -killstats $killstats -sortstat 'randomkey' 
$playerstats_ranked = Get-MatchStatsPlayer -MatchType -typemodevalue 'competitive' -playernames $all_player_matches.playername -friendlyname 'Ranked' -killstats $killstats -sortstat 'randomkey' 

$playerstats_airoyale_clan_gt_1 = Get-MatchStatsPlayer -MatchType -typemodevalue 'airoyale' -playernames $all_player_matches.playername -friendlyname 'Casual' -killstats $killstats_clan_matches_gt_1 -sortstat 'winratio' 

$playerstats_custom = $playerstats_custom | Sort-Object winratio -Descending

$currentDateTime = Get-Date

# Get current timezone
$currentTimezone = (Get-TimeZone).Id

# Format and parse the information into a string
$formattedString = "$currentDateTime - Time Zone: $currentTimezone"

# Output the formatted string

$playerstats = [PSCustomObject]@{
    all         = $playerstats_all
    clan_casual = $playerstats_airoyale_clan_gt_1
    Intense     = $playerstats_event_ibr
    Casual      = $playerstats_airoyale
    official    = $playerstats_official
    custom      = $playerstats_custom
    updated     = $formattedString
    Ranked      = $playerstats_ranked

}

write-output "Writing file"
($playerstats | convertto-json) | out-file "$scriptroot/../data/player_last_stats.json"


$date = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$filenameDate = ($date -replace ":", "-")
write-output "writing to file : $scriptroot/../data/archive/$($filenameDate)_player_last_stats.json"
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
Stop-Transcript