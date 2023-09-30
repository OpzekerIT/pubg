. .\..\includes\ps1\lockfile.ps1

new-lock
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
}else {
    Write-Output "API Key not found"
}

if ($fileContent -match "\`$clanid\s*=\s*\'([^\']+)\'") {
    $clanid = $matches[1]
} else {
    Write-Output "No clanid found in $configPath"
}
$headers = @{
    'accept'        = 'application/vnd.api+json'
    'Authorization' = "$apiKey"
}
try {
    $claninfo = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/clans/$clanid" -Method GET -Headers $headers
} catch {
    write-output "sleeping for 61 sec"
    start-sleep -Seconds 61
    $claninfo = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/clans/$clanid" -Method GET -Headers $headers
}
# Get current date and time
$currentDateTime = Get-Date

# Get current timezone
$currentTimezone = (Get-TimeZone).Id

# Format and parse the information into a string
$formattedString = "$currentDateTime - Time Zone: $currentTimezone"
# Output the formatted string


[PSCustomObject]$clandata = $claninfo.data.attributes
$clandata | Add-Member -Name "updated" -MemberType NoteProperty -Value $formattedString
$clandata | convertto-json -Depth 100 | out-file "$scriptroot/../data/claninfo.json"

$clandata | convertto-json -Depth 100
remove-lock