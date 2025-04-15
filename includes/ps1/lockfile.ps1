# Functions for creating and removing a simple lock file to prevent concurrent script execution.

function New-Lock {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$by # Optional identifier for who/what created the lock
    )

    Write-Verbose "Attempting to acquire lock..."
    $timeoutSeconds = 15 * 15 # Increased timeout to ~4 minutes (15 attempts * 15 seconds)
    $sleepSeconds = 15
    $startTime = Get-Date

    # Determine lock file path based on OS
    if ($IsWindows) {
        $lockFilePath = Join-Path -Path $env:TEMP -ChildPath 'pubg_stats.lock'
    } elseif ($IsLinux -or $IsMacOS) {
        $lockFilePath = '/tmp/pubg_stats.lock'
    } else {
        Write-Error "Unsupported operating system for lock file path determination."
        throw "Unsupported OS for locking." # Throw to ensure script stops
    }
    Write-Verbose "Using lock file path: $lockFilePath"

    while ($true) {
        if (Test-Path -Path $lockFilePath -PathType Leaf) {
            $lockContent = Get-Content -Path $lockFilePath -Raw -ErrorAction SilentlyContinue
            Write-Warning ("Lock file '$lockFilePath' already exists (Content: '$lockContent'). Waiting $sleepSeconds seconds...")
            Start-Sleep -Seconds $sleepSeconds
        } else {
            try {
                # Attempt to create the lock file
                $lockCreatorInfo = if ($by) { "Locked by '$by' at $(Get-Date)" } else { "Locked at $(Get-Date)" }
                New-Item -ItemType File -Path $lockFilePath -Value $lockCreatorInfo -Force -ErrorAction Stop | Out-Null
                Write-Output "Lock file created successfully at '$lockFilePath'."
                return # Exit the loop and function on success
            } catch {
                # This catch might occur if another process creates the file between Test-Path and New-Item (race condition)
                $errorMessage = $_.Exception.Message
                Write-Warning "Failed to create lock file (possible race condition?): $errorMessage. Retrying..."
                Start-Sleep -Seconds 1 # Short sleep before retry on creation failure
            }
        }

        # Check for timeout
        if (((Get-Date) - $startTime).TotalSeconds -ge $timeoutSeconds) {
            Write-Error "Timed out after $timeoutSeconds seconds waiting for lock file '$lockFilePath'."
            throw "Lock acquisition timed out." # Throw to ensure script stops
        }
    }
}

function Remove-Lock {
    Write-Verbose "Attempting to remove lock..."

    # Determine lock file path (consistent with New-Lock)
    if ($IsWindows) {
        $lockFilePath = Join-Path -Path $env:TEMP -ChildPath 'pubg_stats.lock'
    } elseif ($IsLinux -or $IsMacOS) {
        $lockFilePath = '/tmp/pubg_stats.lock'
    } else {
        Write-Warning "Unsupported operating system for lock file path determination. Cannot remove lock."
        return
    }
     Write-Verbose "Target lock file path: $lockFilePath"

    if (Test-Path -Path $lockFilePath -PathType Leaf) {
        try {
            Remove-Item -Path $lockFilePath -Force -ErrorAction Stop
            Write-Output "Lock file '$lockFilePath' removed successfully."
        } catch {
             $errorMessage = $_.Exception.Message
             Write-Error "Failed to remove lock file '$lockFilePath'. Manual removal might be required. Error: $errorMessage"
             # Consider if this should be a fatal error depending on script requirements
        }
    } else {
        Write-Warning "Lock file '$lockFilePath' not found. Assuming already removed."
    }
}