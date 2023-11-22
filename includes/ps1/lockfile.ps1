function new-lock {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $by
    )
    Write-Output 'Setting lock'
    $lock = $true
    $timeout = 15
    $i = 0
    while ($lock) {
        if ($env:temp) {
            $lockFile = Join-Path -Path $env:temp -ChildPath 'lockfile_pubg.lock'
        }
        else {
            $lockFile = "/tmp/lockfile_pubg.lock"
        }
        if (Test-Path -Path $lockFile) {
            Write-Host "Job is already running. Sleeping 10 seconds"
            Start-Sleep -Seconds 10
        }
        else {
            try {
                $content = if ($by) { $by } else { "" }
                New-Item -ItemType File -Path $lockFile -Value $content
                $lock = $false
            }
            catch {
                Write-Output "Unable to create lockfile , resuming lock loop"
                $lock = $true
            }
        }
        if ($i -ge $timeout) {
            Write-Output "Timed out"
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