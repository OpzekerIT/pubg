
if($PSScriptRoot.length -eq 0){
    $scriptroot = Get-Location
}else{
    $scriptroot = $PSScriptRoot
}

function get-killstats {
    param (
        $player_name,
        $telemetry
    )
    $attacks = @()
    foreach ($action in $telemetry) {

        if ($action.PSObject.Properties.name.contains('killer')) {
            #write-output "Analyzing dBNOid $($action.dBNOId)" 
            $attacks += $action
        }
    
    }
    $kills = $attacks | where-object { $_.killer.name -eq $player_name }
    return @{
        playername = $player_name
        humankills = ($kills | where-object { $_.victim.accountId -notlike 'ai.*' }).count
        kills      = $kills.count
        deaths     = ($attacks | where-object { $_.victim.name -eq $player_name }).count

    }
}

$all_player_matches = get-content  "$scriptroot/../data/player_matches.json" | convertfrom-json -Depth 100
$killstats = @()
foreach ($player in $all_player_matches) {
    $player_name = $player.playername
    
    foreach ($match in $player.player_matches) {

       
        
        $telemetryfile = "$scriptroot/../data/telemetry_cache/$($match.telemetry_url.split("/")[-1])"
        if (!(test-path -Path $telemetryfile)) {
            write-output "Saving $telemetryfile"
            $telemetry_content = (Invoke-WebRequest -Uri $match.telemetry_url).content
            $telemetry_content | out-file $telemetryfile
            $telemetry = $telemetry_content | ConvertFrom-Json
        }else{
            write-output "Getting from cache $telemetryfile"
            $telemetry = get-content $telemetryfile  | convertfrom-json
        }
       
        write-output "Analyzing for player $player_name telemetry: $($match.telemetry_url)"
        $killstats += get-killstats -player_name $player_name -telemetry $telemetry
    }       

}


$playerstats = @()
foreach ($player in $all_player_matches.playername) {

    $deaths = (($killstats | where-object { $_.playername -eq $player }).deaths | Measure-Object -sum).sum
    $kills = (($killstats | where-object { $_.playername -eq $player }).kills | Measure-Object -sum).sum
    $humankills = (($killstats | where-object { $_.playername -eq $player }).humankills | Measure-Object -sum).sum

    $playerstats += [PSCustomObject]@{ 
        playername = $player
        deaths     = $deaths
        kills      = $kills
        humankills = $humankills
        matches    = ($killstats | where-object { $_.playername -eq $player }).count
        KD_H       = $humankills / $deaths
        KD_ALL     = $kills / $deaths

        
    }

}

$currentDateTime = Get-Date

# Get current timezone
$currentTimezone = (Get-TimeZone).Id

# Format and parse the information into a string
$formattedString = "$currentDateTime - Time Zone: $currentTimezone"

# Output the formatted string
$playerstats += [PSCustomObject]@{
    updated = $formattedString
 }



($playerstats | convertto-json) | out-file "$scriptroot/../data/player_last_stats.json"


