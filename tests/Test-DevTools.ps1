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
    'dev.ps1'
    'dev.cmd'
    'config.example.json'
    'README.md'
    'CHANGELOG.md'
    'CONTRIBUTING.md'
    'LICENSE'
)

foreach ($file in $requiredFiles) {
    Test-RequiredPath -Path $file -Label "Required file: $file" | Out-Null
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
    'commands/status.ps1'
    'commands/backup.ps1'
    'commands/open.ps1'
    'commands/help.ps1'
    'commands/quick.ps1'
    'commands/recent.ps1'
    'commands/info.ps1'
    'commands/test.ps1'
    'commands/self.ps1'
)

foreach ($commandFile in $commandFiles) {
    Test-RequiredPath -Path $commandFile -Label "Command file: $commandFile" | Out-Null
}

$libFiles = @(
    'lib/recent.ps1'
    'lib/project-info.ps1'
    'lib/test.ps1'
    'lib/self.ps1'
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

    if (-not $failed) {
        $configValid = $true
        Write-TestPass 'config.example.json is valid JSON with required keys'
    }
}
catch {
    Write-TestFailure "config.example.json is not valid JSON: $($_.Exception.Message)"
}

# README content checks
Test-ReadmeContains -Text 'DevTools' -Label 'DevTools' | Out-Null
Test-ReadmeContains -Text 'Installation' -Label 'Installation' | Out-Null
Test-ReadmeContains -Text 'Quick Start' -Label 'Quick Start' | Out-Null
Test-ReadmeContains -Text 'Commands' -Label 'Commands' | Out-Null
Test-ReadmeContains -Text 'Roadmap' -Label 'Roadmap' | Out-Null

# Verify main commands are loadable (syntax-only via AST on command scripts)
$mainCommands = @('home', 'menu', 'configure', 'settings', 'doctor', 'clone', 'update', 'status', 'backup', 'open', 'help', 'quick', 'recent', 'info', 'test', 'self')

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
