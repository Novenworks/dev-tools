function Write-OptionalDevelopmentToolDivider {
    Write-Host '----------------------------------------' -ForegroundColor DarkGray
}

function Get-OptionalToolResultMark {
    if (Get-Command Get-DevToolsDisplaySymbol -ErrorAction SilentlyContinue) {
        return Get-DevToolsDisplaySymbol -Name 'success-mark'
    }

    return '*'
}

function Show-OptionalDevelopmentToolReport {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Installed,
        [Parameter(Mandatory = $true)][string[]]$About,
        [string[]]$Recommended = @('Install it to enable additional checks during automated tests.'),
        [string[]]$InstallCommands = @(),
        [string]$ContinueMessage = 'Continuing without additional checks...',
        [string]$RunningMessage = '',
        [scriptblock]$InvokeWhenInstalled
    )

    Write-Host ''
    Write-OptionalDevelopmentToolDivider
    Write-Host ''
    Write-Host $Name -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Status' -ForegroundColor Cyan
    Write-Host ('  {0}' -f $(if ($Installed) { 'Installed' } else { 'Not installed' })) -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'About' -ForegroundColor Cyan
    Write-Host ''

    foreach ($line in $About) {
        Write-Host "  $line" -ForegroundColor DarkGray
    }

    Write-Host ''

    if (-not $Installed) {
        Write-Host 'Recommended' -ForegroundColor Cyan
        Write-Host ''

        foreach ($line in $Recommended) {
            Write-Host "  $line" -ForegroundColor DarkGray
        }

        Write-Host ''

        if ($InstallCommands.Count -gt 0) {
            Write-Host 'Run:' -ForegroundColor Cyan
            Write-Host ''

            foreach ($command in $InstallCommands) {
                Write-Host "  $command" -ForegroundColor DarkGray
            }

            Write-Host ''
        }

        Write-Host $ContinueMessage -ForegroundColor DarkGray
        Write-Host ''
        Write-OptionalDevelopmentToolDivider
        Write-Host ''
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($RunningMessage)) {
        Write-Host $RunningMessage -ForegroundColor DarkGray
        Write-Host ''
    }

    if ($InvokeWhenInstalled) {
        & $InvokeWhenInstalled
    }

    Write-Host ''
    Write-OptionalDevelopmentToolDivider
    Write-Host ''
}

function Invoke-OptionalPSScriptAnalyzerLint {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot
    )

    $installed = [bool](Get-Module -ListAvailable -Name PSScriptAnalyzer)

    Show-OptionalDevelopmentToolReport `
        -Name 'PSScriptAnalyzer' `
        -Installed $installed `
        -About @(
            'PSScriptAnalyzer provides additional PowerShell code quality checks.'
            'DevTools can run without it.'
        ) `
        -Recommended @(
            'Install it to enable linting during automated tests.'
        ) `
        -InstallCommands @(
            'Install-Module PSScriptAnalyzer -Scope CurrentUser'
        ) `
        -ContinueMessage 'Continuing without linting...' `
        -RunningMessage 'Running PowerShell lint checks...' `
        -InvokeWhenInstalled {
            Import-Module PSScriptAnalyzer -ErrorAction SilentlyContinue

            if (-not (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue)) {
                Write-Host '  PSScriptAnalyzer is listed but could not be loaded.' -ForegroundColor DarkGray
                return
            }

            $analyzerResults = @(
                Invoke-ScriptAnalyzer -Path $ProjectRoot -Recurse -Severity Error, Warning -ErrorAction SilentlyContinue
            )

            if ($analyzerResults.Count -eq 0) {
                $mark = Get-OptionalToolResultMark
                Write-Host "$mark No issues found." -ForegroundColor Green
                return
            }

            foreach ($result in $analyzerResults) {
                Write-Host "LINT: $($result.ScriptName):$($result.Line) $($result.Message)" -ForegroundColor Yellow
            }

            $warningCount = @($analyzerResults | Where-Object { $_.Severity -eq 'Warning' }).Count
            $errorCount = @($analyzerResults | Where-Object { $_.Severity -eq 'Error' }).Count
            $mark = Get-OptionalToolResultMark

            Write-Host ''
            Write-Host "$mark Lint completed." -ForegroundColor Green

            if ($warningCount -gt 0) {
                Write-Host "  $warningCount warning(s) found." -ForegroundColor DarkGray
            }

            if ($errorCount -gt 0) {
                Write-Host "  $errorCount error(s) found." -ForegroundColor DarkGray
            }
        }
}

function Invoke-DevToolsTestSuite {
    Write-Host ''
    Write-Host 'DevTools Test Runner' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Locating installation...' -ForegroundColor DarkGray

    $root = Get-DevToolsRoot
    $testScript = if ($root) { Join-Path $root 'tests\Test-DevTools.ps1' } else { $null }

    if (-not $testScript -or -not (Test-Path -LiteralPath $testScript)) {
        Write-Host ''
        ShowError 'Unable to locate:'
        ShowInfo 'tests\Test-DevTools.ps1'
        ShowInfo 'Your DevTools installation may be incomplete.'
        Write-Host ''
        return 1
    }

    $foundMark = Get-DevToolsDisplaySymbol -Name 'success-mark'
    Write-Host ''
    Write-Host "$foundMark Installation found" -ForegroundColor Green
    Write-Host ''
    Write-Host 'Running automated validation...' -ForegroundColor DarkGray
    Write-Host ''

    $runner = 'powershell.exe'
    $runnerArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $testScript)

    if (Test-CommandExists 'pwsh') {
        $runner = (Get-Command pwsh).Source
    }

    $testOutput = @(& $runner @runnerArgs 2>&1)
    foreach ($line in $testOutput) {
        Write-Host $line
    }

    $exitCode = $LASTEXITCODE

    if ($null -eq $exitCode -or $exitCode -eq '') {
        $exitCode = 0
    }

    Write-Host ''

    if ($exitCode -eq 0) {
        ShowSuccess "$(Get-DevToolsDisplaySymbol -Name 'success-mark') All automated tests passed."
    }
    else {
        ShowWarning "$(Get-DevToolsDisplaySymbol -Name 'check-fail') One or more tests failed."
        ShowInfo 'Review the output above for details.'
    }

    Write-Host ''
    return [int]$exitCode
}
