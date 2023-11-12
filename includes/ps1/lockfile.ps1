function new-lock {
    Write-Output 'Setting lock'
    if ($env:temp) {
        $lockFile = Join-Path -Path $env:temp -ChildPath 'lockfile_pubg.lock'
    }
    else {
        $lockFile = "/tmp/lockfile_pubg.lock"
    }
    if (Test-Path -Path $lockFile) {
        Write-Host "Job is already running."
        Exit
    }
    New-Item -ItemType File -Path $lockFile | Out-Null
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