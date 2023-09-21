
# Read the content of the file as a single string
$fileContent = Get-Content -Path "../config/config.php" -Raw

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
$claninfo = Invoke-RestMethod -Uri "https://api.pubg.com/shards/steam/clans/$clanid" -Method GET -Headers $headers
$claninfo.data.attributes | convertto-json -Depth 100 | out-file '../data/claninfo.json'