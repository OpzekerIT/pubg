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
                New-Item -ItemType File -Path $lockFile | Out-Null
                $lock = $false
            }
            catch {
                $lock = $true
            }
        }
        if ($i -ge $timeout) {
            Write-Output "Timed out"
            exit
        }
        $i++
    }
    if ($by) {
        $by | Out-File -FilePath $lockFile -Append
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