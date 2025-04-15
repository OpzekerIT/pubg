# --- Script Setup ---
# Using Unicode BOM (Byte Order Mark) can sometimes cause issues, ensure file is saved as UTF-8 without BOM if problems arise.
Start-Transcript -Path '/var/log/dtch/update_clan.log' -Append
Write-Output "Starting update_clan script at $(Get-Date)"
Write-Output "Running from: $(Get-Location)"

# Determine script root directory reliably
if ($PSScriptRoot) {
    $scriptRoot = $PSScriptRoot
} else {
    # Fallback for environments where $PSScriptRoot is not defined (e.g., ISE)
    $scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Write-Warning "PSScriptRoot not defined, using calculated path: $scriptRoot"
}
Write-Output "Script root identified as: $scriptRoot"

# Define paths using Join-Path for robustness
$includesPath = Join-Path -Path $scriptRoot -ChildPath "..\includes\ps1"
$configPath = Join-Path -Path $scriptRoot -ChildPath "..\config"
$dataPath = Join-Path -Path $scriptRoot -ChildPath "..\data"

# Ensure data directory exists (copied from update_clan_members.ps1 for consistency)
if (-not (Test-Path -Path $dataPath -PathType Container)) {
    Write-Warning "Data directory not found at '$dataPath'. Attempting to create."
    try {
        New-Item -Path $dataPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Write-Output "Successfully created data directory."
    } catch {
        Write-Error "Failed to create data directory '$dataPath'. Please check permissions. Error: $($_.Exception.Message)"
        Stop-Transcript
        exit 1
    }
}

# --- Locking ---
$lockFilePath = Join-Path -Path $includesPath -ChildPath "lockfile.ps1"
if (-not (Test-Path -Path $lockFilePath -PathType Leaf)) {
    Write-Error "Lockfile script not found at '$lockFilePath'. Cannot proceed."
    Stop-Transcript
    exit 1
}
. $lockFilePath
New-Lock -by "update_clan" -ErrorAction Stop # Stop if locking fails

# --- Configuration Loading ---
$apiKey = $null
$clanId = $null

# Load API Key and Clan ID from config.php
$phpConfigPath = Join-Path -Path $configPath -ChildPath "config.php"
if (Test-Path -Path $phpConfigPath -PathType Leaf) {
    try {
        $fileContent = Get-Content -Path $phpConfigPath -Raw -ErrorAction Stop
        
        # Corrected regex for apiKey
        if ($fileContent -match '^\s*\$apiKey\s*=\s*''([^'']+)''') {
            $apiKey = $matches[1]
            Write-Output "API Key loaded successfully."
        } else {
            Write-Warning "API Key pattern not found in '$phpConfigPath'."
        }
        
        # Corrected regex for clanid
        if ($fileContent -match '^\s*\$clanid\s*=\s*''([^'']+)''') {
            $clanId = $matches[1]
            Write-Output "Clan ID loaded successfully."
        } else {
            Write-Warning "Clan ID pattern not found in '$phpConfigPath'."
        }
    } catch {
        Write-Warning "Failed to read '$phpConfigPath'. Error: $($_.Exception.Message)"
    }
} else {
    Write-Warning "Config file not found at '$phpConfigPath'."
}

# Validate required config
if (-not $apiKey) {
    Write-Error "API Key could not be loaded. Cannot proceed."
    Remove-Lock
    Stop-Transcript
    exit 1
}
if (-not $clanId) {
    Write-Error "Clan ID could not be loaded. Cannot proceed."
    Remove-Lock
    Stop-Transcript
    exit 1
}

# --- Helper Function for API Calls (Copied from update_clan_members.ps1 for self-containment) ---
function Invoke-PubgApi {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        [Parameter(Mandatory=$true)]
        [hashtable]$Headers,
        [int]$RetryCount = 1,
        [int]$RetryDelaySeconds = 61
    )
    
    for ($attempt = 1; $attempt -le ($RetryCount + 1); $attempt++) {
        try {
            Write-Verbose "Attempting API call (Attempt $($attempt)): $Uri"
            $response = Invoke-RestMethod -Uri $Uri -Method GET -Headers $Headers -ErrorAction Stop
            if ($null -ne $response) {
                Write-Verbose "API call successful."
                return $response
            } else {
                 Write-Warning "API call to $Uri returned null or empty response."
                 return $null
            }
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorMessage = $_.Exception.Message
            Write-Warning "API call failed (Attempt $($attempt)). Status: $statusCode. Error: $errorMessage"
            
            if ($attempt -le $RetryCount -and $statusCode -eq 429) {
                Write-Warning "Rate limit hit. Sleeping for $RetryDelaySeconds seconds before retry..."
                Start-Sleep -Seconds $RetryDelaySeconds
            } elseif ($attempt -gt $RetryCount) {
                Write-Error "API call failed after $($attempt) attempts. URI: $Uri. Last Error: $errorMessage"
                return $null
            } else {
                 Write-Error "Non-retryable API error. URI: $Uri. Error: $errorMessage"
                 return $null
            }
        }
    }
    return $null
}

# --- Get Clan Information ---
Write-Output "Fetching clan information for ID: $clanId"
$headers = @{
    'accept'        = 'application/vnd.api+json'
    'Authorization' = "Bearer $apiKey" # Standard practice
}
$apiUrl = "https://api.pubg.com/shards/steam/clans/$clanId"

$clanInfoResponse = Invoke-PubgApi -Uri $apiUrl -Headers $headers

# --- Process and Save Clan Data ---
if ($null -ne $clanInfoResponse -and $null -ne $clanInfoResponse.data.attributes) {
    Write-Output "Successfully retrieved clan information."
    
    # Create PS Custom Object from attributes
    $clanData = [PSCustomObject]$clanInfoResponse.data.attributes
    
    # Add update timestamp
    $currentDateTime = Get-Date
    $currentTimezone = (Get-TimeZone).Id
    $formattedString = "$currentDateTime - Time Zone: $currentTimezone"
    $clanData | Add-Member -Name "updated" -MemberType NoteProperty -Value $formattedString
    Write-Output "Added update timestamp: $formattedString"

    # Save clan data to JSON file
    $clanInfoJsonPath = Join-Path -Path $dataPath -ChildPath "claninfo.json"
    try {
        $clanData | ConvertTo-Json -Depth 100 | Out-File -FilePath $clanInfoJsonPath -Encoding UTF8 -ErrorAction Stop
        Write-Output "Clan info saved to '$clanInfoJsonPath'"
        
        # Output JSON to transcript for verification (optional)
        # Write-Output "Saved Data:"
        # $clanData | ConvertTo-Json -Depth 100 | Write-Output
        
    } catch {
        Write-Error "Failed to save clan info to '$clanInfoJsonPath'. Error: $($_.Exception.Message)"
    }
} else {
    Write-Error "Failed to retrieve valid clan information from API for ID: $clanId"
    # Consider if script should exit or continue
}

# --- Cleanup ---
Write-Output "Script finished at $(Get-Date)."
Remove-Lock
Stop-Transcript