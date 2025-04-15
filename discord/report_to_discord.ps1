# --- Script Setup ---
# Note: Transcript path seems incorrect, should likely be specific to this script.
# Consider changing to '/var/log/dtch/report_to_discord.log' or similar.
Start-Transcript -Path '/var/log/dtch/report_to_discord.log' -Append
Write-Output "Starting report_to_discord script at $(Get-Date)"
Write-Output "Running from: $(Get-Location)"

# Determine script root directory reliably
if ($PSScriptRoot) {
    $scriptRoot = $PSScriptRoot
} else {
    $scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Write-Warning "PSScriptRoot not defined, using calculated path: $scriptRoot"
}
Write-Output "Script root identified as: $scriptRoot"

# Define paths using Join-Path
$includesPath = Join-Path -Path $scriptRoot -ChildPath "..\includes\ps1"
$discordConfigPath = Join-Path -Path $scriptRoot -ChildPath "config.php" # Config is in the same dir
$dataPath = Join-Path -Path $scriptRoot -ChildPath "..\data"
$lastStatsJsonPath = Join-Path -Path $dataPath -ChildPath "player_last_stats.json"

# --- Locking ---
$lockFilePath = Join-Path -Path $includesPath -ChildPath "lockfile.ps1"
if (-not (Test-Path -Path $lockFilePath -PathType Leaf)) {
    Write-Error "Lockfile script not found at '$lockFilePath'. Cannot proceed."
    Stop-Transcript
    exit 1
}
. $lockFilePath
New-Lock -by "report_to_discord" -ErrorAction Stop # Stop if locking fails

# --- Main Logic in Try/Finally for Lock Removal ---
try {
    # --- Helper Function ---
    # Checks if K/D values are valid numbers (not NaN or Infinity)
    function Test-IsValidKdEntry {
        param($entry)
        
        # Check if properties exist and are numeric before comparison
        $kdHValid = $entry.PSObject.Properties.Name -contains 'KD_H' -and $entry.KD_H -is [double] -and -not [double]::IsNaN($entry.KD_H) -and -not [double]::IsInfinity($entry.KD_H)
        $kdAllValid = $entry.PSObject.Properties.Name -contains 'KD_ALL' -and $entry.KD_ALL -is [double] -and -not [double]::IsNaN($entry.KD_ALL) -and -not [double]::IsInfinity($entry.KD_ALL)
        
        return $kdHValid -and $kdAllValid
    }

    # --- Configuration Loading ---
    $webhookUrl = $null
    if (Test-Path -Path $discordConfigPath -PathType Leaf) {
        try {
            $fileContent = Get-Content -Path $discordConfigPath -Raw -ErrorAction Stop
            # Corrected regex for webhookurl
            if ($fileContent -match '^\s*\$webhookurl\s*=\s*''([^'']+)''') {
                $webhookUrl = $matches[1]
                Write-Output "Discord webhook URL loaded successfully."
            } else {
                Write-Warning "Webhook URL pattern not found in '$discordConfigPath'."
            }
        } catch {
            Write-Warning "Failed to read '$discordConfigPath'. Error: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "Discord config file not found at '$discordConfigPath'."
    }

    if (-not $webhookUrl) {
        Write-Error "Discord webhook URL could not be loaded. Cannot send report."
        throw "Missing Webhook URL" # Throw to trigger finally block
    }

    # --- Load Stats Data ---
    $statsData = $null
    if (Test-Path -Path $lastStatsJsonPath -PathType Leaf) {
        try {
            $statsData = Get-Content -Path $lastStatsJsonPath | ConvertFrom-Json -ErrorAction Stop
            if ($null -eq $statsData) {
                 Write-Error "Failed to parse stats data from '$lastStatsJsonPath'. Cannot generate report."
                 throw "Invalid Stats Data"
            }
             Write-Output "Successfully loaded player stats data."
        } catch {
            Write-Error "Error reading '$lastStatsJsonPath': $($_.Exception.Message). Cannot generate report."
            throw $_
        }
    } else {
        Write-Error "Player stats file not found at '$lastStatsJsonPath'. Cannot generate report."
        throw "Missing Stats File"
    }

    # --- Process Stats ---
    Write-Output "Processing stats..."
    # Safely access the 'all' category and filter valid entries
    $filteredAllStats = @()
    if ($statsData.PSObject.Properties.Name -contains 'all' -and $statsData.all -is [array]) {
        $filteredAllStats = $statsData.all | Where-Object { Test-IsValidKdEntry $_ }
        Write-Output "Found $($filteredAllStats.Count) valid entries in 'all' category."
    } else {
        Write-Warning "Stats data does not contain a valid 'all' array. Report might be incomplete."
    }

    # --- Find Top Players (Handle Empty/Null Cases) ---
    # Helper to safely get top player stat
    function Get-TopStat {
        param(
            [array]$Data,
            [string]$Property,
            [string]$DefaultName = "N/A",
            [string]$DefaultStat = "N/A"
        )
        $sorted = $Data | Sort-Object $Property -Descending -ErrorAction SilentlyContinue
        if ($sorted -and $sorted.Count -gt 0) {
            # Ensure the property exists on the top object before accessing
            $topEntry = $sorted[0]
            $playerName = if ($topEntry.PSObject.Properties.Name -contains 'playername') { $topEntry.playername } else { $DefaultName }
            $statValue = if ($topEntry.PSObject.Properties.Name -contains $Property) { $topEntry.$Property } else { $DefaultStat }
            # Format numeric stats if needed (e.g., K/D)
            if ($Property -like "KD*" -and $statValue -is [double]) { $statValue = "{0:N2}" -f $statValue }
            
            return @{ 'name' = $playerName; 'stat' = $statValue }
        } else {
            return @{ 'name' = $DefaultName; 'stat' = $DefaultStat }
        }
    }

    $mostKills = Get-TopStat -Data $filteredAllStats -Property 'kills'
    $mostDeaths = Get-TopStat -Data $filteredAllStats -Property 'deaths'
    $mostHumanKills = Get-TopStat -Data $filteredAllStats -Property 'humankills'
    $mostKdH = Get-TopStat -Data $filteredAllStats -Property 'KD_H'
    $mostKdAll = Get-TopStat -Data $filteredAllStats -Property 'KD_ALL'
    $mostMatches = Get-TopStat -Data $filteredAllStats -Property 'matches'

    Write-Output "Determined top players for report."

    # --- Format Discord Message ---
    # Using PowerShell multi-line string with variable substitution
    $reportContent = @"
:rocket: Het maandelijks raportje :rocket:

Hey toppers!

Laten we eens duiken in de cijfers van onze supergamers van de afgelopen maand:

:dart: Meeste Kills:
Hats off voor **$($mostKills.name)**! Met **$($mostKills.stat)** kills is hij/zij onze scherpschutter van de maand!

:skull_crossbones: Meeste Deaths:
Oei, oei, oei... **$($mostDeaths.name)** is helaas het vaakst naar het hiernamaals gestuurd met **$($mostDeaths.stat)** deaths. Kop op, volgende keer beter!

:robot: Meeste Humankills:
Watch out! We hebben een Terminator onder ons. Hoedje af voor **$($mostHumanKills.name)** met **$($mostHumanKills.stat)** humankills!

:bar_chart: Beste KD Ratio (Alle vijanden):
De onevenaarbare **$($mostKdAll.name)** heeft een KD van **$($mostKdAll.stat)** ! Niet slecht, toch? 😉

:adult: Beste KD Ratio (Alleen menselijke spelers):
Opgelet, gamers! **$($mostKdH.name)** heeft een KD van **$($mostKdH.stat)** tegen andere spelers! Wie daagt hem/haar uit?

:video_game: Meeste Matches:
Onze meest toegewijde gamer, **$($mostMatches.name)**, heeft maar liefst **$($mostMatches.stat)** matches gespeeld. Ga zo door!

Da's het voor nu, gamers! Blijf schieten, blijf lachen en tot het volgende rapportje!

High fives en knuffels (virtueel, natuurlijk),
Het Gaming Team

Meer stats zijn hier te vinden : https://lanta.eu/DTCH
"@

    Write-Output "Formatted Discord message content."
    # Write-Verbose $reportContent # Uncomment to see the full message in verbose logs

    # --- Send to Discord ---
    $payload = @{
        content = $reportContent
        # username = "Stats Bot" # Optional: Override bot name
        # avatar_url = "" # Optional: Override bot avatar
    } | ConvertTo-Json -Depth 3 # Depth 3 should be sufficient

    Write-Output "Sending report to Discord webhook..."
    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType 'application/json' -ErrorAction Stop
        Write-Output "Report successfully sent to Discord."
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Failed to send report to Discord. Error: $errorMessage"
        # Consider logging the failed payload or response details if available
        # Write-Warning "Payload: $payload"
    }

} # End Main Try Block
finally {
    # --- Cleanup ---
    Write-Output "Script finished at $(Get-Date)."
    Remove-Lock # Ensure lock is always removed
    Stop-Transcript
}