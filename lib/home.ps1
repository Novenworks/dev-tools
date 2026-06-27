function Get-StatusIndicator {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OverallStatus
    )

    switch ($OverallStatus) {
        'Ready to Build' { return [char]0x1F7E2 }
        'Almost Ready' { return [char]0x1F7E1 }
        default { return [char]0x1F7E0 }
    }
}

function Get-HomeChecklistIcon {
    param(
        [Parameter(Mandatory = $true)][bool]$Passed,
        [Parameter(Mandatory = $true)][bool]$Optional
    )

    if ($Passed) {
        return [char]0x2713
    }

    if ($Optional) {
        return [char]0x25CB
    }

    return [char]0x2717
}

function Show-HomeChecklist {
    param(
        [Parameter(Mandatory = $true)]$Status
    )

    $homeOptionalIds = @('node', 'cursor', 'claude-desktop', 'claude-code')
    $optionalChecks = @($Status.OptionalChecks | Where-Object { $_.Id -in $homeOptionalIds })

    Write-Host 'Required' -ForegroundColor DarkGray
    Write-Host ''

    foreach ($check in $Status.RequiredChecks) {
        $icon = Get-HomeChecklistIcon -Passed $check.Passed -Optional $false
        $color = if ($check.Passed) { 'Green' } else { 'Yellow' }
        Write-Host "  $icon $($check.Label)" -ForegroundColor $color
    }

    Write-Host ''
    Write-Host 'Optional' -ForegroundColor DarkGray
    Write-Host ''

    foreach ($check in $optionalChecks) {
        $icon = Get-HomeChecklistIcon -Passed $check.Passed -Optional $true
        $color = if ($check.Passed) { 'Green' } else { 'DarkGray' }
        Write-Host "  $icon $($check.Label)" -ForegroundColor $color
    }

    Write-Host ''
}

function Show-HomeStatusFocal {
    param(
        [Parameter(Mandatory = $true)]$Status,
        [Parameter(Mandatory = $true)][array]$AttentionItems
    )

    $indicator = Get-StatusIndicator -OverallStatus $Status.OverallStatus
    $statusColor = switch ($Status.OverallStatus) {
        'Ready to Build' { 'Green' }
        'Almost Ready' { 'Yellow' }
        default { 'Yellow' }
    }

    Write-Host "$indicator $($Status.OverallStatus)" -ForegroundColor $statusColor
    Write-Host ''

    if ($Status.RequiredAttention -eq 0) {
        return
    }

    if ($AttentionItems.Count -eq 1) {
        ShowInfo "$($AttentionItems.Count) item needs attention."
        Write-Host ''
        Write-Host $AttentionItems[0].Label -ForegroundColor Cyan
        Write-Host "  $($AttentionItems[0].StatusText)" -ForegroundColor DarkGray
        Write-Host ''
        return
    }

    ShowInfo 'Multiple setup items need attention.'
    ShowInfo 'Run Doctor for details.'
    Write-Host ''
}

function Show-HomeSummary {
    param(
        [Parameter(Mandatory = $true)]$Status
    )

    ShowSummary -Title 'Summary' -Lines @(
        "Ready: $($Status.RequiredReady)"
        "Needs Attention: $($Status.RequiredAttention)"
        "Optional Installed: $($Status.OptionalInstalled)"
        "Optional Missing: $($Status.OptionalMissing)"
    )
}

function Get-HomeActionDefinitions {
    param(
        [Parameter(Mandatory = $true)]$Status
    )

    $attentionItems = @(Get-HomeAttentionItems)

    if ($Status.RequiredAttention -eq 0) {
        $actions = @(
            [pscustomobject]@{ Key = '1'; Label = 'Main Menu'; Action = 'menu' }
            [pscustomobject]@{ Key = '2'; Label = 'Quick Actions'; Action = 'quick' }
        )

        if (@(Get-RecentProjects).Count -gt 0) {
            $actions += [pscustomobject]@{ Key = '3'; Label = 'Open Recent'; Action = 'recent' }
            $actions += [pscustomobject]@{ Key = '4'; Label = 'Doctor'; Action = 'doctor' }
            $actions += [pscustomobject]@{ Key = '5'; Label = 'Settings'; Action = 'settings' }
            $actions += [pscustomobject]@{ Key = '6'; Label = 'Exit'; Action = 'exit' }
        }
        else {
            $actions += [pscustomobject]@{ Key = '3'; Label = 'Doctor'; Action = 'doctor' }
            $actions += [pscustomobject]@{ Key = '4'; Label = 'Settings'; Action = 'settings' }
            $actions += [pscustomobject]@{ Key = '5'; Label = 'Exit'; Action = 'exit' }
        }

        return $actions
    }

    if ($attentionItems.Count -eq 1) {
        $item = $attentionItems[0]
        $fixLabel = if ($item.Id -eq 'gh-auth') {
            'Sign into GitHub'
        }
        else {
            "Fix $($item.Label)"
        }

        return @(
            [pscustomobject]@{ Key = '1'; Label = $fixLabel; Action = 'fix-primary'; CheckId = $item.Id }
            [pscustomobject]@{ Key = '2'; Label = 'Continue to Main Menu'; Action = 'menu' }
            [pscustomobject]@{ Key = '3'; Label = 'Run Doctor'; Action = 'doctor' }
            [pscustomobject]@{ Key = '4'; Label = 'Exit'; Action = 'exit' }
        )
    }

    return @(
        [pscustomobject]@{ Key = '1'; Label = 'Configure'; Action = 'configure' }
        [pscustomobject]@{ Key = '2'; Label = 'Run Doctor'; Action = 'doctor' }
        [pscustomobject]@{ Key = '3'; Label = 'Main Menu'; Action = 'menu' }
        [pscustomobject]@{ Key = '4'; Label = 'Exit'; Action = 'exit' }
    )
}

function Show-HomeScreen {
    $status = Get-DevToolsSystemStatus
    $attentionItems = @(Get-HomeAttentionItems)

    ShowHomeLanding -Clear

    Write-Host 'System Status' -ForegroundColor Cyan
    Write-Host ''

    Show-HomeStatusFocal -Status $status -AttentionItems $attentionItems
    Show-HomeChecklist -Status $status
    Show-HomeRecentProjects

    $actions = @(Get-HomeActionDefinitions -Status $status)
    ShowHomeActions -Actions $actions

    Show-HomeSummary -Status $status

    Write-Host ''
    Write-Host 'Tip' -ForegroundColor Cyan
    ShowInfo 'Run Doctor anytime for a complete system check.'
    Write-Host ''

    return [pscustomobject]@{
        Status         = $status
        Actions        = $actions
        AttentionItems = $attentionItems
    }
}

function Invoke-HomeGitHubSignIn {
    Write-Host ''
    Write-Host 'GitHub Login' -ForegroundColor Cyan
    Write-Host '  Not signed in.' -ForegroundColor DarkGray
    Write-Host ''
    ShowInfo 'DevTools uses your GitHub account to clone and update repositories.'
    Write-Host ''
    Write-Host '  1  Sign in now'
    Write-Host '  2  Later'
    Write-Host ''

    $choice = Read-Host 'Choose an option'

    if ($choice -ne '1') {
        return $false
    }

    if (-not (Test-CommandExists 'gh')) {
        ShowInfo 'GitHub CLI is required before you can sign in.'
        ShowInfo 'Run Doctor to install GitHub CLI first.'
        Wait-ForKey -Message 'Press Enter to continue'
        return $false
    }

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        gh auth login
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }

    if (Test-GhAuthenticated) {
        $checkMark = [char]0x2713
        ShowSuccess "$checkMark GitHub login successful."
        Wait-ForKey -Message 'Press Enter to continue'
        return $true
    }

    ShowInfo 'Sign-in may still be in progress. Run Doctor again if needed.'
    Wait-ForKey -Message 'Press Enter to continue'
    return $false
}

function Invoke-HomePrimaryFix {
    param(
        [Parameter(Mandatory = $true)][string]$CheckId
    )

    switch ($CheckId) {
        'gh-auth' {
            Invoke-HomeGitHubSignIn | Out-Null
        }
        'configuration' {
            . (Join-Path $DevToolsRoot 'commands\configure.ps1')
            $script:Config = Set-ScriptConfig
        }
        'workspace' {
            . (Join-Path $DevToolsRoot 'commands\configure.ps1')
            $script:Config = Set-ScriptConfig
        }
        'editor' {
            . (Join-Path $DevToolsRoot 'commands\settings.ps1')
        }
        default {
            . (Join-Path $DevToolsRoot 'commands\doctor.ps1')
            Wait-ForKey -Message 'Press Enter to return to Home'
        }
    }
}
