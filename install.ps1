# Dev Tools CLI install script for Windows

$ErrorActionPreference = 'Stop'
$InstallRoot = $PSScriptRoot

Write-Host 'Installing Dev Tools CLI...' -ForegroundColor Cyan
Write-Host ''

$configPath = Join-Path $InstallRoot 'config.json'
$examplePath = Join-Path $InstallRoot 'config.example.json'

if (-not (Test-Path $configPath)) {
    Copy-Item -Path $examplePath -Destination $configPath
    Write-Host 'Created config.json from config.example.json.' -ForegroundColor Yellow
    Write-Host 'Run dev to launch the guided setup wizard.' -ForegroundColor Yellow
    Write-Host ''
}

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

if ($userPath -notlike "*$InstallRoot*") {
    $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) {
        $InstallRoot
    }
    else {
        "$userPath;$InstallRoot"
    }

    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Host "Added $InstallRoot to your user PATH." -ForegroundColor Green
}
else {
    Write-Host 'Dev Tools CLI is already on your user PATH.' -ForegroundColor Green
}

Write-Host ''
Write-Host 'Install complete.' -ForegroundColor Green
Write-Host ''
Write-Host 'Next steps:'
Write-Host '  1. Close and reopen PowerShell or Command Prompt'
Write-Host '  2. Run: dev'
Write-Host '  3. Complete the Configure wizard'
Write-Host '  4. Run: dev clone'
Write-Host ''
