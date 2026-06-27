function Get-HomeAttentionItems {
    $status = Get-DevToolsSystemStatus
    $priority = @('gh-auth', 'gh', 'git', 'workspace', 'configuration', 'editor')

    $items = @()
    foreach ($id in $priority) {
        $check = $status.RequiredChecks | Where-Object { $_.Id -eq $id -and -not $_.Passed }
        if ($check) {
            $items += $check
        }
    }

    return $items
}

function Get-ConfigurationCheckState {
    $configExists = Test-DevToolsConfigFileExists
    $configValid = $false

    if ($configExists) {
        try {
            $null = Get-DevToolsConfig
            $configValid = $true
        }
        catch {
            $configValid = $false
        }
    }

    $ownersConfigured = $false
    if ($Config -and $Config.githubOwners -and @($Config.githubOwners).Count -gt 0) {
        $ownersConfigured = @($Config.githubOwners | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0
    }

    $passed = $configExists -and $configValid -and $ownersConfigured
    $detail = if ($passed) { 'Configured' } else { 'Needs setup' }

    return [pscustomobject]@{
        Passed = $passed
        Detail = $detail
    }
}

function New-DoctorCheck {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][bool]$Passed,
        [string]$Version,
        [string]$StatusText,
        [string]$SuggestedAction,
        [string]$WhyItMatters,
        [switch]$Optional,
        [switch]$CanFixInteractively,
        [string]$FixCommand
    )

    return [pscustomobject]@{
        Id                  = $Id
        Label               = $Label
        Passed              = $Passed
        Version             = $Version
        StatusText          = $StatusText
        SuggestedAction     = $SuggestedAction
        WhyItMatters        = $WhyItMatters
        Optional            = [bool]$Optional
        CanFixInteractively = [bool]$CanFixInteractively
        FixCommand          = $FixCommand
    }
}

function Get-DevToolsRequiredChecks {
    $catalog = Get-DoctorCheckCatalog
    $configuration = Get-ConfigurationCheckState
    $workspaceExists = $false

    if ($Config -and $Config.workspacePath) {
        $workspaceExists = Test-Path $Config.workspacePath
    }

    $gitVersion = Get-ToolVersionNumber -Command 'git'
    $ghVersion = Get-ToolVersionNumber -Command 'gh'
    $ghAuthenticated = $false

    if (Test-CommandExists 'gh') {
        $ghAuthenticated = Test-GhAuthenticated
    }

    $editorSelected = $Config -and -not [string]::IsNullOrWhiteSpace($Config.defaultEditor)

    return @(
        (New-DoctorCheck -Id 'git' -Label 'Git' -Passed ([bool]$gitVersion) -Version $gitVersion `
            -StatusText $(if ($gitVersion) { 'Installed' } else { 'Not Installed' }) `
            -WhyItMatters $catalog.git.WhyItMatters `
            -SuggestedAction $(if ($gitVersion) { $catalog.git.InstalledAction } else { $catalog.git.MissingAction })),
        (New-DoctorCheck -Id 'gh' -Label 'GitHub CLI' -Passed ([bool]$ghVersion) -Version $ghVersion `
            -StatusText $(if ($ghVersion) { 'Installed' } else { 'Not Installed' }) `
            -WhyItMatters $catalog.gh.WhyItMatters `
            -SuggestedAction $(if ($ghVersion) { $catalog.gh.InstalledAction } else { $catalog.gh.MissingAction }) `
            -CanFixInteractively:(-not $ghVersion) `
            -FixCommand 'winget install GitHub.cli -e --accept-source-agreements --accept-package-agreements'),
        (New-DoctorCheck -Id 'gh-auth' -Label 'GitHub Login' -Passed $ghAuthenticated `
            -StatusText $(if ($ghAuthenticated) { 'Signed in' } else { 'Not signed in' }) `
            -WhyItMatters $catalog.'gh-auth'.WhyItMatters `
            -SuggestedAction $(if ($ghAuthenticated) { $catalog.'gh-auth'.InstalledAction } else { $catalog.'gh-auth'.MissingAction }) `
            -CanFixInteractively:((Test-CommandExists 'gh') -and -not $ghAuthenticated) `
            -FixCommand 'gh auth login'),
        (New-DoctorCheck -Id 'workspace' -Label 'Workspace' -Passed $workspaceExists `
            -StatusText $(if ($workspaceExists) { 'Ready' } else { 'Not set up' }) `
            -WhyItMatters $catalog.workspace.WhyItMatters `
            -SuggestedAction $(if ($workspaceExists) { $catalog.workspace.InstalledAction } else { $catalog.workspace.MissingAction })),
        (New-DoctorCheck -Id 'configuration' -Label 'Configuration' -Passed $configuration.Passed `
            -StatusText $configuration.Detail `
            -WhyItMatters $catalog.configuration.WhyItMatters `
            -SuggestedAction $(if ($configuration.Passed) { $catalog.configuration.InstalledAction } else { $catalog.configuration.MissingAction })),
        (New-DoctorCheck -Id 'editor' -Label 'Default Editor' -Passed $editorSelected `
            -StatusText $(if ($editorSelected) { (Get-EditorDisplayName -Editor $Config.defaultEditor) } else { 'Not selected' }) `
            -WhyItMatters $catalog.editor.WhyItMatters `
            -SuggestedAction $(if ($editorSelected) { $catalog.editor.InstalledAction } else { $catalog.editor.MissingAction }))
    )
}

function Get-DevToolsOptionalChecks {
    $catalog = Get-DoctorCheckCatalog
    $nodeVersion = Get-ToolVersionNumber -Command 'node'
    $npmVersion = Get-ToolVersionNumber -Command 'npm'
    $nodeInstalled = [bool]$nodeVersion

    $npmPassed = [bool]$npmVersion
    $npmStatus = if ($npmVersion) { 'Installed' } else { 'Not Installed' }
    $npmAction = if ($npmVersion) { $catalog.npm.InstalledAction } else { $catalog.npm.MissingAction }

    if (-not $nodeInstalled) {
        $npmPassed = $true
        $npmStatus = 'Installs with Node.js'
        $npmAction = $catalog.npm.MissingAction
    }
    elseif (-not $npmPassed) {
        $npmAction = 'Try reinstalling Node.js LTS.'
    }

    return @(
        (New-DoctorCheck -Id 'node' -Label 'Node.js' -Passed $nodeInstalled -Optional -Version $nodeVersion `
            -StatusText $(if ($nodeVersion) { 'Installed' } else { 'Not Installed' }) `
            -WhyItMatters $catalog.node.WhyItMatters `
            -SuggestedAction $(if ($nodeVersion) { $catalog.node.InstalledAction } else { $catalog.node.MissingAction }) `
            -CanFixInteractively:(-not $nodeInstalled) `
            -FixCommand 'winget install OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements'),
        (New-DoctorCheck -Id 'npm' -Label 'npm' -Passed $npmPassed -Optional `
            -StatusText $npmStatus `
            -WhyItMatters $catalog.npm.WhyItMatters `
            -SuggestedAction $npmAction),
        (New-DoctorCheck -Id 'cursor' -Label 'Cursor' -Passed (Test-CommandExists 'cursor') -Optional `
            -StatusText $(if (Test-CommandExists 'cursor') { 'Installed' } else { 'Optional' }) `
            -WhyItMatters $catalog.cursor.WhyItMatters `
            -SuggestedAction $(if (Test-CommandExists 'cursor') { $catalog.cursor.InstalledAction } else { $catalog.cursor.MissingAction })),
        (New-DoctorCheck -Id 'claude-desktop' -Label 'Claude Desktop' -Passed (Test-ClaudeDesktopInstalled) -Optional `
            -StatusText $(if (Test-ClaudeDesktopInstalled) { 'Installed' } else { 'Optional' }) `
            -WhyItMatters $catalog.'claude-desktop'.WhyItMatters `
            -SuggestedAction $(if (Test-ClaudeDesktopInstalled) { $catalog.'claude-desktop'.InstalledAction } else { $catalog.'claude-desktop'.MissingAction })),
        (New-DoctorCheck -Id 'claude-code' -Label 'Claude Code' -Passed (Test-CommandExists 'claude') -Optional `
            -StatusText $(if (Test-CommandExists 'claude') { 'Available' } else { 'Optional' }) `
            -WhyItMatters $catalog.'claude-code'.WhyItMatters `
            -SuggestedAction $(if (Test-CommandExists 'claude') { $catalog.'claude-code'.InstalledAction } else { $catalog.'claude-code'.MissingAction }))
    )
}

function Get-DevToolsSystemStatus {
    $required = @(Get-DevToolsRequiredChecks)
    $optional = @(Get-DevToolsOptionalChecks)

    $requiredReady = @($required | Where-Object { $_.Passed }).Count
    $requiredAttention = @($required | Where-Object { -not $_.Passed }).Count
    $optionalInstalled = @($optional | Where-Object { $_.Passed }).Count
    $optionalMissing = @($optional | Where-Object { -not $_.Passed }).Count

    return [pscustomobject]@{
        RequiredReady     = $requiredReady
        RequiredAttention = $requiredAttention
        OptionalInstalled = $optionalInstalled
        OptionalMissing   = $optionalMissing
        OverallStatus     = (Get-OverallStatusLabel -NeedsAttention $requiredAttention)
        RequiredChecks    = $required
        OptionalChecks    = $optional
    }
}

function Get-DevToolsHealthChecks {
    $status = Get-DevToolsSystemStatus
    return @($status.RequiredChecks + $status.OptionalChecks)
}

function Invoke-DoctorInteractiveFixes {
    $maxPasses = 3

    for ($pass = 0; $pass -lt $maxPasses; $pass++) {
        $status = Get-DevToolsSystemStatus
        $acted = $false

        foreach ($check in $status.RequiredChecks) {
            if ($check.Id -eq 'gh' -and $check.CanFixInteractively) {
                Write-Host ''
                ShowInfo $check.WhyItMatters

                if (ShowInstallPrompt -Prompt 'Install GitHub CLI now?') {
                    Invoke-Expression $check.FixCommand
                    ShowInfo 'Checking GitHub CLI again...'
                    $acted = $true
                }
            }

            if ($check.Id -eq 'gh-auth' -and $check.CanFixInteractively) {
                Write-Host ''
                ShowWarning 'GitHub CLI is installed, but you are not signed in.'
                ShowInfo $check.WhyItMatters

                if (ShowYesNoPrompt -Prompt 'Log in now?' -YesLabel '[Y] Yes' -NoLabel '[N] Later') {
                    gh auth login

                    if (Test-GhAuthenticated) {
                        ShowSuccess "$(Get-DevToolsDisplaySymbol -Name 'success-mark') GitHub login successful."
                    }
                    else {
                        ShowInfo 'Sign-in may still be in progress. Run Doctor again if needed.'
                    }

                    $acted = $true
                }
            }
        }

        foreach ($check in $status.OptionalChecks) {
            if ($check.Id -eq 'node' -and $check.CanFixInteractively) {
                Write-Host ''
                ShowInfo 'Node.js powers many modern JavaScript projects.'

                if (ShowInstallPrompt -Prompt 'Install Node.js LTS now?') {
                    Invoke-Expression $check.FixCommand
                    ShowInfo 'Checking Node.js again...'

                    if (Get-ToolVersionNumber -Command 'node') {
                        ShowSuccess '* Node.js is now installed.'
                    }
                    else {
                        ShowInfo 'You may need to restart PowerShell before Node.js is detected.'
                        ShowInfo 'Re-run Doctor after restarting your terminal.'
                    }

                    $acted = $true
                }
            }
        }

        if (-not $acted) {
            break
        }
    }
}

function Show-HomeSystemStatus {
    # Deprecated: use Show-HomeScreen in lib/home.ps1
    return (Get-DevToolsSystemStatus)
}

function Show-DoctorCheckResults {
    param([switch]$Interactive)

    if ($Interactive) {
        Invoke-DoctorInteractiveFixes
    }

    $status = Get-DevToolsSystemStatus

    Write-Host 'Required' -ForegroundColor Cyan
    Write-Host ''

    foreach ($check in $status.RequiredChecks) {
        ShowDoctorCheckCard -Check $check
    }

    Write-Host 'Optional' -ForegroundColor Cyan
    Write-Host ''

    foreach ($check in $status.OptionalChecks) {
        ShowDoctorCheckCard -Check $check
    }

    ShowDoctorSystemStatus -Status $status
}
