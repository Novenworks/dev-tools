#Requires -Version 5.1

<#
.SYNOPSIS
    Validates DevTools project structure, configuration, and PowerShell syntax.
.DESCRIPTION
    Safe local and CI validation. Does not clone, pull, commit, push, or require GitHub auth.
#>

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$failed = $false
$parseCount = 0
$requiredFileCount = 0
$configValid = $false

function Write-TestFailure {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "FAIL: $Message" -ForegroundColor Red
    $script:failed = $true
}

function Write-TestPass {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "PASS: $Message" -ForegroundColor Green
}

function Test-RequiredPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $ProjectRoot $Path }

    if (Test-Path -LiteralPath $fullPath) {
        Write-TestPass $Label
        $script:requiredFileCount++
        return $true
    }

    Write-TestFailure "$Label (missing: $Path)"
    return $false
}

function Test-ReadmeContains {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $readmePath = Join-Path $ProjectRoot 'README.md'
    $content = Get-Content -LiteralPath $readmePath -Raw

    if ($content -match [regex]::Escape($Text)) {
        Write-TestPass "README contains: $Label"
        return $true
    }

    Write-TestFailure "README missing section or text: $Label"
    return $false
}

Write-Host ''
Write-Host 'DevTools Test Runner' -ForegroundColor Cyan
Write-Host "Project root: $ProjectRoot"
Write-Host ''

# Required files
$requiredFiles = @(
    'dev-core.ps1'
    'dev.cmd'
    'install.ps1'
    'config.example.json'
    'README.md'
    'CHANGELOG.md'
    'CONTRIBUTING.md'
    'LICENSE'
)

foreach ($file in $requiredFiles) {
    Test-RequiredPath -Path $file -Label "Required file: $file" | Out-Null
}

$versionPath = Join-Path $ProjectRoot 'VERSION'
if (Test-Path -LiteralPath $versionPath) {
    $versionValue = (Get-Content -LiteralPath $versionPath -Raw).Trim()

    if ($versionValue -eq '0.5.0') {
        Write-TestPass 'VERSION is 0.5.0'
    }
    else {
        Write-TestFailure "VERSION expected 0.5.0 but found: $versionValue"
    }
}
else {
    Write-TestFailure 'VERSION file missing'
}

$legacyDevPs1Path = Join-Path $ProjectRoot 'dev.ps1'
if (Test-Path -LiteralPath $legacyDevPs1Path) {
    Write-TestFailure 'Root dev.ps1 must not exist (use dev-core.ps1 to avoid PATH conflicts)'
}
else {
    Write-TestPass 'Root dev.ps1 is absent'
}

$devCmdPath = Join-Path $ProjectRoot 'dev.cmd'
if (Test-Path -LiteralPath $devCmdPath) {
    $devCmdContent = Get-Content -LiteralPath $devCmdPath -Raw

    if ($devCmdContent -match 'dev-core\.ps1') {
        Write-TestPass 'dev.cmd references dev-core.ps1'
    }
    else {
        Write-TestFailure 'dev.cmd must reference dev-core.ps1'
    }

    if ($devCmdContent -match 'ExecutionPolicy Bypass') {
        Write-TestPass 'dev.cmd includes ExecutionPolicy Bypass'
    }
    else {
        Write-TestFailure 'dev.cmd must include ExecutionPolicy Bypass'
    }
}
else {
    Write-TestFailure 'dev.cmd missing for launcher validation'
}

# Required folders
$requiredFolders = @(
    'commands'
    'lib'
    '.github'
)

foreach ($folder in $requiredFolders) {
    Test-RequiredPath -Path $folder -Label "Required folder: $folder" | Out-Null
}

# Optional testing docs
$testingDocs = @(
    'docs/testing/README.md'
    'docs/testing/smoke-test.md'
)

foreach ($doc in $testingDocs) {
    Test-RequiredPath -Path $doc -Label "Testing doc: $doc" | Out-Null
}

# Command files
$commandFiles = @(
    'commands/home.ps1'
    'commands/menu.ps1'
    'commands/doctor.ps1'
    'commands/configure.ps1'
    'commands/settings.ps1'
    'commands/clone.ps1'
    'commands/update.ps1'
    'commands/sync.ps1'
    'commands/status.ps1'
    'commands/repos.ps1'
    'commands/backup.ps1'
    'commands/open.ps1'
    'commands/help.ps1'
    'commands/quick.ps1'
    'commands/recent.ps1'
    'commands/info.ps1'
    'commands/test.ps1'
    'commands/self.ps1'
    'commands/deploy.ps1'
)

foreach ($commandFile in $commandFiles) {
    Test-RequiredPath -Path $commandFile -Label "Command file: $commandFile" | Out-Null
}

$libFiles = @(
    'lib/repo-git.ps1'
    'lib/repo-state.ps1'
    'lib/repo-sync.ps1'
    'lib/repo-repair.ps1'
    'lib/repo-report.ps1'
    'lib/repo-ui.ps1'
    'lib/recent.ps1'
    'lib/project-info.ps1'
    'lib/test.ps1'
    'lib/self.ps1'
    'lib/deploy.ps1'
    'lib/deploy-config.ps1'
    'lib/deploy-github.ps1'
    'lib/deploy-vercel.ps1'
    'lib/deploy-model.ps1'
    'lib/deploy-report.ps1'
)

foreach ($libFile in $libFiles) {
    Test-RequiredPath -Path $libFile -Label "Library file: $libFile" | Out-Null
}

# Parse all PowerShell files
$ps1Files = Get-ChildItem -Path $ProjectRoot -Recurse -Filter '*.ps1' -File |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }

foreach ($file in $ps1Files) {
    $tokens = $null
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)

    if ($errors -and $errors.Count -gt 0) {
        Write-TestFailure "Parse error in $($file.FullName): $($errors[0].Message)"
    }
    else {
        $parseCount++
    }
}

Write-TestPass "Parsed $parseCount PowerShell file(s)"

# Validate config.example.json
$configPath = Join-Path $ProjectRoot 'config.example.json'

try {
    $configJson = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    $requiredConfigKeys = @(
        'workspacePath'
        'githubOwners'
        'defaultEditor'
        'autoBackupMessage'
        'autoUpdate'
    )

    foreach ($key in $requiredConfigKeys) {
        if (-not ($configJson.PSObject.Properties.Name -contains $key)) {
            Write-TestFailure "config.example.json missing key: $key"
        }
    }

    if ($configJson.PSObject.Properties.Name -contains 'deployments') {
        Write-TestPass 'config.example.json includes the deployments section'

        if ($configJson.deployments.repositoryFilters) {
            Write-TestPass 'config.example.json includes deployment repository filters'
        }
        else {
            Write-TestFailure 'config.example.json deployments section missing repositoryFilters'
        }
    }
    else {
        Write-TestFailure 'config.example.json missing key: deployments'
    }

    if (-not $failed) {
        $configValid = $true
        Write-TestPass 'config.example.json is valid JSON with required keys'
    }
}
catch {
    Write-TestFailure "config.example.json is not valid JSON: $($_.Exception.Message)"
}

# No committed file may contain a Vercel token.
$trackedTextFiles = Get-ChildItem -Path $ProjectRoot -Recurse -File -Include '*.ps1', '*.json', '*.md', '*.cmd', '*.yml' |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.Name -ne 'config.json' }

$secretFindings = @()
foreach ($trackedFile in $trackedTextFiles) {
    $trackedContent = Get-Content -LiteralPath $trackedFile.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $trackedContent) { continue }

    if ($trackedContent -match '(?i)vercel[_-]?token\s*[:=]\s*[''"][A-Za-z0-9_\-]{16,}[''"]') {
        $secretFindings += $trackedFile.FullName
    }
}

if ($secretFindings.Count -eq 0) {
    Write-TestPass 'No Vercel token literals are committed'
}
else {
    Write-TestFailure "Possible committed Vercel token in: $($secretFindings -join ', ')"
}

$gitignoreePath = Join-Path $ProjectRoot '.gitignore'
if (Test-Path -LiteralPath $gitignoreePath) {
    $gitignoreContent = Get-Content -LiteralPath $gitignoreePath -Raw

    if ($gitignoreContent -match 'reports/') {
        Write-TestPass '.gitignore excludes generated deployment reports'
    }
    else {
        Write-TestFailure '.gitignore must exclude reports/'
    }
}

# README content checks
Test-ReadmeContains -Text 'DevTools' -Label 'DevTools' | Out-Null
Test-ReadmeContains -Text 'Installation' -Label 'Installation' | Out-Null
Test-ReadmeContains -Text 'Quick Start' -Label 'Quick Start' | Out-Null
Test-ReadmeContains -Text 'Commands' -Label 'Commands' | Out-Null
Test-ReadmeContains -Text 'Roadmap' -Label 'Roadmap' | Out-Null
Test-ReadmeContains -Text 'install.ps1' -Label 'install.ps1' | Out-Null
Test-ReadmeContains -Text 'ExecutionPolicy Bypass' -Label 'ExecutionPolicy Bypass install' | Out-Null
Test-ReadmeContains -Text 'v0.5.0' -Label 'v0.5.0' | Out-Null

$readmePath = Join-Path $ProjectRoot 'README.md'
$readmeContent = Get-Content -LiteralPath $readmePath -Raw

if ($readmeContent -match 'powershell -ExecutionPolicy Bypass -File "\.\\dev\.ps1"') {
    Write-TestFailure 'README must not recommend dev.ps1 as the primary entrypoint'
}
else {
    Write-TestPass 'README does not recommend dev.ps1 as primary entrypoint'
}

$installationDocPath = Join-Path $ProjectRoot 'docs\installation.md'
if (Test-Path -LiteralPath $installationDocPath) {
    $installationDocContent = Get-Content -LiteralPath $installationDocPath -Raw

    if ($installationDocContent -match 'install\.ps1') {
        Write-TestPass 'installation.md mentions install.ps1'
    }
    else {
        Write-TestFailure 'installation.md must mention install.ps1'
    }

    if ($installationDocContent -match 'ExecutionPolicy Bypass') {
        Write-TestPass 'installation.md mentions ExecutionPolicy Bypass install'
    }
    else {
        Write-TestFailure 'installation.md must mention ExecutionPolicy Bypass install'
    }
}

# Verify main commands are loadable (syntax-only via AST on command scripts)
$mainCommands = @('home', 'menu', 'configure', 'settings', 'doctor', 'clone', 'update', 'sync', 'status', 'repos', 'backup', 'open', 'help', 'quick', 'recent', 'info', 'test', 'self', 'deploy')

foreach ($commandName in $mainCommands) {
    $commandPath = Join-Path $ProjectRoot "commands\$commandName.ps1"
    if (-not (Test-Path -LiteralPath $commandPath)) {
        Write-TestFailure "Main command missing: $commandName"
        continue
    }

    $tokens = $null
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($commandPath, [ref]$tokens, [ref]$errors)

    if ($errors -and $errors.Count -gt 0) {
        Write-TestFailure "Command parse error ($commandName): $($errors[0].Message)"
    }
}

# Home status focal accepts empty attention items when all checks pass
try {
    $DevToolsRoot = $ProjectRoot
    . (Join-Path $ProjectRoot 'lib\utils.ps1')
    . (Join-Path $ProjectRoot 'lib\copy.ps1')
    . (Join-Path $ProjectRoot 'lib\ui.ps1')
    . (Join-Path $ProjectRoot 'lib\home.ps1')

    $readyStatus = [pscustomobject]@{
        OverallStatus     = 'Ready to Build'
        RequiredAttention = 0
    }

    Show-HomeStatusFocal -Status $readyStatus -AttentionItems @() | Out-Null
    Write-TestPass 'Show-HomeStatusFocal accepts empty AttentionItems'
}
catch {
    Write-TestFailure "Show-HomeStatusFocal empty AttentionItems: $($_.Exception.Message)"
}

# Repository intelligence tests run in a child process because they create
# throwaway Git fixtures in a temporary folder.
$repoTestScript = Join-Path $ProjectRoot 'tests\Test-Repos.ps1'

$childRunner = 'powershell.exe'
$pwshForChildren = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwshForChildren) { $childRunner = $pwshForChildren.Source }

if (Test-Path -LiteralPath $repoTestScript) {
    Write-Host ''
    & $childRunner -NoProfile -ExecutionPolicy Bypass -File $repoTestScript
    $repoExitCode = $LASTEXITCODE

    if ($repoExitCode -eq 0) {
        Write-TestPass 'Repository intelligence tests passed'
    }
    else {
        Write-TestFailure "Repository intelligence tests failed (exit code $repoExitCode)"
    }
}
else {
    Write-TestFailure 'Repository intelligence tests missing: tests/Test-Repos.ps1'
}

# Deployment Manager tests run in a child process so their service mocks stay isolated.
$deployTestScript = Join-Path $ProjectRoot 'tests\Test-Deploy.ps1'

if (Test-Path -LiteralPath $deployTestScript) {
    $deployRunner = $childRunner

    Write-Host ''
    & $deployRunner -NoProfile -ExecutionPolicy Bypass -File $deployTestScript
    $deployExitCode = $LASTEXITCODE

    if ($deployExitCode -eq 0) {
        Write-TestPass 'Deployment Manager tests passed'
    }
    else {
        Write-TestFailure "Deployment Manager tests failed (exit code $deployExitCode)"
    }
}
else {
    Write-TestFailure 'Deployment Manager tests missing: tests/Test-Deploy.ps1'
}

# Optional development tools (does not affect pass/fail)
. (Join-Path $ProjectRoot 'lib\utils.ps1')
. (Join-Path $ProjectRoot 'lib\test.ps1')

# Summary
Write-Host ''
Write-Host 'DevTools Test Summary' -ForegroundColor Cyan
Write-Host "PowerShell files parsed: $parseCount"
Write-Host "Required files checked: $requiredFileCount"
Write-Host "Config valid: $(if ($configValid) { 'Yes' } else { 'No' })"

if ($failed) {
    Write-Host 'Result: FAIL' -ForegroundColor Red
}
else {
    Write-Host 'Result: PASS' -ForegroundColor Green
}

Show-DevelopmentEnvironmentSummary
Invoke-OptionalPSScriptAnalyzerLint -ProjectRoot $ProjectRoot

if ($failed) {
    exit 1
}

exit 0
