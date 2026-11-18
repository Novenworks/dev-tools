#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path ([IO.Path]::GetTempPath()) ("devrepo cli " + [guid]::NewGuid())
$engine = (Get-Process -Id $PID).Path
$githubEnvironment = @{}
$githubVariables = @('GH_CONFIG_DIR', 'GH_TOKEN', 'GITHUB_TOKEN', 'GH_ENTERPRISE_TOKEN', 'GITHUB_ENTERPRISE_TOKEN')
foreach ($name in $githubVariables) {
    $githubEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

function Assert-Output {
    param($Output, [string]$Expected)
    if ((@($Output) -join "`n") -notmatch [regex]::Escape($Expected)) {
        throw "Expected '$Expected' in: $Output"
    }
}

try {
    New-Item -ItemType Directory -Path $fixture | Out-Null
    foreach ($name in $githubVariables) { [Environment]::SetEnvironmentVariable($name, $null, 'Process') }
    $env:GH_CONFIG_DIR = (New-Item -ItemType Directory -Path (Join-Path $fixture 'gh')).FullName

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

    $output = & $engine -NoProfile -ExecutionPolicy Bypass -File $core doctor --json
    if ($LASTEXITCODE -ne 0 -or @($output).Count -ne 1) { throw 'Doctor did not emit a single JSON result.' }
    $doctor = $output | ConvertFrom-Json
    if ($doctor.command -ne 'doctor' -or -not $doctor.success -or @($doctor.data.required).Count -eq 0) {
        throw 'Doctor JSON does not contain setup checks.'
    }

    $output = & $engine -NoProfile -ExecutionPolicy Bypass -File $core projects list --json
    $list = $output | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $list.schemaVersion -ne 1 -or $list.data.count -ne 2 -or @($list.data.projects).Count -ne 2) {
        throw 'Project listing contract is invalid.'
    }

    $output = & $engine -NoProfile -ExecutionPolicy Bypass -File $core repos status --json
    $health = $output | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $health.command -ne 'status' -or $health.data.refreshed -or $health.data.summary.Total -ne 1) {
        throw 'Repository status contract is invalid.'
    }

    $output = & $engine -NoProfile -ExecutionPolicy Bypass -File $core status --no-interactive 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Text status failed.' }
    Assert-Output $output '1 Git projects'

    $repoPath = Join-Path $workspace 'Repository'
    & git -C $repoPath remote add origin 'file:///missing-devrepo-fixture'
    if ($LASTEXITCODE -ne 0) { throw 'Could not set up a remote for the dry-run fixture.' }
    $headPath = Join-Path $repoPath '.git/HEAD'
    $head = (Get-FileHash -LiteralPath $headPath).Hash

    $output = & $engine -NoProfile -ExecutionPolicy Bypass -File $core update --dry-run --json
    $preview = $output | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $preview.command -ne 'sync' -or -not $preview.data.dryRun -or $preview.data.refreshed) {
        throw 'Update alias did not return a local dry-run preview.'
    }
    if (@($preview.data.repositories).Count -ne 1 -or $preview.data.repositories[0].plannedAction -ne 'skip') {
        throw 'Dry run should skip a repository without an upstream.'
    }
    if ((Get-FileHash -LiteralPath $headPath).Hash -ne $head -or (Test-Path -LiteralPath (Join-Path $repoPath '.git/FETCH_HEAD'))) {
        throw 'Dry run mutated the Git fixture.'
    }
    if ($output -match 'missing-devrepo-fixture') { throw 'Dry run emitted the remote URL.' }

    $output = & $engine -NoProfile -ExecutionPolicy Bypass -File $core sync --json
    $rejected = $output | ConvertFrom-Json
    if ($LASTEXITCODE -ne 7 -or $rejected.success -or $rejected.errors[0].code -ne 'unsafe_operation') {
        throw 'Noninteractive sync must reject mutations.'
    }

    $output = & $engine -NoProfile -ExecutionPolicy Bypass -File $core status --json --invalid
    $rejected = $output | ConvertFrom-Json
    if ($LASTEXITCODE -ne 2 -or $rejected.success -or $rejected.errors[0].code -ne 'invalid_arguments') {
        throw 'Structured status must reject unknown options.'
    }

    Write-Host 'PASS: DevRepo launchers, Home counts, typed navigation, sync cancellation and automation contracts'
}
finally {
    foreach ($name in $githubVariables) {
        [Environment]::SetEnvironmentVariable($name, $githubEnvironment[$name], 'Process')
    }
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
