function new-lock {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $by
    )

    Write-Output 'Setting lock'
    $timeout = 15
    $i = 0
    while ($true) {
        if ($env:temp) {
            $lockFile = Join-Path -Path $env:temp -ChildPath 'lockfile_pubg.lock'
        }
        else {
            $lockFile = "/tmp/lockfile_pubg.lock"
        }

        if (Test-Path -Path $lockFile) {
            Write-Host "Job is already running. Lock file found at $lockFile. Sleeping 15 seconds."
            Start-Sleep -Seconds 15
        }
        else {
            try {
                $content = if ($by) { $by } else { "" }
                New-Item -ItemType File -Path $lockFile -Value $content -Force
                Write-Host "Lock file created at $lockFile."
                break
            }
            catch {
                Write-Output "Unable to create lockfile, error: $_. Resuming lock loop."
            }
        }
        if ($i -ge $timeout) {
            Write-Output "Timed out after $timeout attempts."
            exit
        }
        $i++
    }
}

function remove-lock {
    Write-Output 'Removing lock'
    if ($env:temp) {
        $lockFile = Join-Path -Path $env:temp -ChildPath 'lockfile_pubg.lock'
    }
    else {
        $lockFile = "/tmp/lockfile_pubg.lock"
    }
    Remove-Item -Path $lockFile
}