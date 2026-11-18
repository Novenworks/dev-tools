#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path ([IO.Path]::GetTempPath()) ("devrepo cli " + [guid]::NewGuid())
$engine = (Get-Process -Id $PID).Path

function Assert-Output {
    param($Output, [string]$Expected)
    if ((@($Output) -join "`n") -notmatch [regex]::Escape($Expected)) {
        throw "Expected '$Expected' in: $Output"
    }
}

try {
    New-Item -ItemType Directory -Path $fixture | Out-Null
    foreach ($path in @('dev-core.ps1', 'devrepo.cmd', 'dev.cmd', 'lib', 'commands', 'config.example.json', 'VERSION')) {
        Copy-Item -LiteralPath (Join-Path $root $path) -Destination $fixture -Recurse
    }

    $core = Join-Path $fixture 'dev-core.ps1'
    $output = & $engine -NoProfile -ExecutionPolicy Bypass -File $core --help
    if ($LASTEXITCODE -ne 0) { throw 'Help failed.' }
    Assert-Output $output 'DevRepo by Novenworks'
    if (Test-Path -LiteralPath (Join-Path $fixture 'config.json')) { throw 'Help created a configuration file.' }

    $output = & $engine -NoProfile -ExecutionPolicy Bypass -File $core '../lib/utils'
    if ($LASTEXITCODE -eq 0) { throw 'Unknown command returned success.' }
    Assert-Output $output 'Unknown command:'

    if ($env:OS -eq 'Windows_NT') {
        foreach ($name in @('devrepo.cmd', 'dev.cmd')) {
            $output = & (Join-Path $fixture $name) help
            if ($LASTEXITCODE -ne 0) { throw "$name failed." }
            Assert-Output $output 'DevRepo by Novenworks'
        }
    }

    $workspace = Join-Path $fixture 'Workspace'
    $null = New-Item -ItemType Directory -Path (Join-Path $workspace 'Local folder') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $workspace 'Repository')
    & git -C (Join-Path $workspace 'Repository') init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Could not create Git fixture.' }
    $config = @{ workspacePath = $workspace; githubOwners = @('example'); defaultEditor = 'git'; autoBackupMessage = 'Backup' }
    $config | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $fixture 'config.json')

    $output = @('M','2','Back','Back','Q') | & $engine -NoProfile -ExecutionPolicy Bypass -File $core home
    if ($LASTEXITCODE -ne 0) { throw 'Home failed.' }
    Assert-Output $output '2 project folders'
    Assert-Output $output '0 Git projects healthy, 1 need attention'
    Assert-Output $output 'All actions'
    Assert-Output $output 'Quick actions'

    foreach ($command in @('sync', 'update')) {
        $output = @('N','') | & $engine -NoProfile -ExecutionPolicy Bypass -File $core $command
        if ($LASTEXITCODE -ne 0) { throw "$command cancellation failed." }
        Assert-Output $output 'Update canceled before checking remotes.'
    }

    Write-Host 'PASS: DevRepo launchers, Home counts, typed navigation and sync cancellation'
}
finally {
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
