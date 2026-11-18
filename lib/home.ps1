function Get-DevRepoMenuOptions {
    param([ValidateSet('home', 'menu', 'quick')][string]$Screen)

    $items = switch ($Screen) {
        'home' {
            '1|Open a project|open'
            '2|Update my projects|sync'
            '3|Download new projects|clone'
            '4|Check project health|status'
            '5|Fix repository issues|repos'
            '6|Recently opened|recent'
            'D|Check my setup|doctor'
            'M|All actions|menu'
            'S|Settings|settings'
            'H|Help|help'
            'Q|Quit|quit'
        }
        'menu' {
            '1|Home|home'
            '2|Quick actions|quick'
            '3|Recently opened|recent'
            '4|Project details|info'
            '5|Check my setup|doctor'
            '6|Set up my workspace|configure'
            '7|Settings|settings'
            '8|Download new projects|clone'
            '9|Update my projects|sync'
            '10|Check project health|status'
            '11|Fix repository issues|repos'
            '12|Back up changes to GitHub|backup'
            '13|Open a project|open'
            '14|Manage deployments|deploy'
            '15|Help|help'
            '16|Quit|quit'
            '0|Back|back'
        }
        'quick' {
            '1|Recently opened|recent'
            '2|Open a project|open'
            '3|Check project health|status'
            '4|Update my projects|sync'
            '5|Download new projects|clone'
            '6|Fix repository issues|repos'
            '7|All actions|menu'
            '8|Quit|quit'
            '0|Back|back'
        }
    }

    foreach ($item in $items) {
        $key, $label, $action = $item.Split('|')
        [pscustomobject]@{ Key = $key; Label = $label; Action = $action }
    }
}

function Get-DevRepoHomeSnapshot {
    $checks = @(Get-DevToolsRequiredChecks)
    $projects = @()
    $health = $null
    $workspaceReady = $checks.Where({ $_.Id -eq 'workspace' }).Passed
    $gitReady = $checks.Where({ $_.Id -eq 'git' }).Passed

    if ($workspaceReady) {
        $projects = @(Get-WorkspaceProjects -WorkspacePath $Config.workspacePath)
        if ($gitReady) {
            if ($projects.Where({ $_.IsGit }).Count -gt 0) {
                ShowInfo 'Checking local project health...'
            }
            $states = @(Get-WorkspaceRepositoryStates -WorkspacePath $Config.workspacePath)
            $health = Get-RepositoryStateSummary -States $states
        }
    }

    [pscustomobject]@{
        GitReady = $gitReady
        GitHubConnected = $checks.Where({ $_.Id -eq 'gh-auth' }).Passed
        EditorAvailable = $checks.Where({ $_.Id -eq 'editor' }).Passed
        WorkspaceReady = $workspaceReady
        ProjectCount = $projects.Count
        Health = $health
    }
}

function Show-DevRepoHome {
    param([Parameter(Mandatory = $true)]$Snapshot)

    Write-Host 'DEVREPO' -ForegroundColor Cyan
    Write-Host (Get-ProductSubtitle)
    Write-Host 'by Novenworks'
    Write-Host ''
    Write-Host "Workspace: $($Config.workspacePath)"

    ShowSection -Label 'System'
    ShowInfo $(if ($Snapshot.GitReady) { 'Git ready' } else { 'Git needs setup' })
    ShowInfo $(if ($Snapshot.GitHubConnected) { 'GitHub connected' } else { 'GitHub needs sign-in' })
    ShowInfo $(if ($Snapshot.EditorAvailable) { 'Editor available' } else { 'Editor needs setup' })
    if (-not ($Snapshot.GitReady -and $Snapshot.GitHubConnected -and $Snapshot.EditorAvailable)) {
        ShowInfo 'Choose D to check setup and see how to fix it.'
    }

    ShowSection -Label 'Projects'
    if (-not $Snapshot.WorkspaceReady) {
        ShowInfo 'Workspace folder is missing. Open Settings to choose a folder.'
    }
    else {
        ShowInfo "$($Snapshot.ProjectCount) project folders"
        if ($null -ne $Snapshot.Health) {
            ShowInfo ("{0} Git projects healthy, {1} need attention (local snapshot)" -f $Snapshot.Health.Healthy, $Snapshot.Health.NeedsAttention)
        }
        else {
            ShowInfo 'Git is required to check project health.'
        }
    }

    ShowSection -Label 'Quick actions'
}

function Invoke-DevRepoNavigation {
    param([ValidateSet('home', 'menu', 'quick')][string]$StartScreen = 'home')

    $screen = $StartScreen
    $history = [System.Collections.Generic.Stack[string]]::new()
    $snapshot = $null
    while ($true) {
        Clear-Host
        if ($screen -eq 'home') {
            if ($null -eq $snapshot) { $snapshot = Get-DevRepoHomeSnapshot }
            Show-DevRepoHome -Snapshot $snapshot
        }
        else {
            $heading = if ($screen -eq 'menu') { 'All actions' } else { 'Quick actions' }
            ShowCommandScreen -Heading $heading -Description @('Choose an action for this workspace.')
        }

        $options = @(Get-DevRepoMenuOptions -Screen $screen)
        $shortcuts = if ($screen -eq 'home') { @{ O = 'recent' } } else { @{} }
        $choice = Read-DevRepoMenuChoice -Options $options -Shortcuts $shortcuts
        $action = $shortcuts[$choice]
        if (-not $action) {
            $action = ($options | Where-Object { $_.Key -eq $choice } | Select-Object -First 1).Action
        }
        if ($choice -eq 'Back' -or $action -eq 'back') {
            if ($history.Count -eq 0) { return }
            $screen = $history.Pop()
            continue
        }
        if ($action -eq 'quit') { return }
        if ($action -in @('home', 'menu', 'quick')) {
            if ($history.Count -gt 0 -and $history.Peek() -eq $action) {
                $screen = $history.Pop()
            }
            else {
                $history.Push($screen)
                $screen = $action
            }
            continue
        }

        switch ($action) {
            'open' { Invoke-OpenProjectFlow; Wait-ForKey }
            'recent' { Invoke-RecentProjectsFlow; Wait-ForKey }
            'info' { Invoke-ProjectInfoFlow; Wait-ForKey }
            'sync' { Invoke-RepositorySyncFlow | Out-Null; Wait-ForKey }
            'clone' { & (Join-Path $DevToolsRoot 'commands/clone.ps1'); Wait-ForKey }
            'status' { Invoke-RepositoryHealthFlow }
            'repos' { Invoke-RepositoryMaintenanceMenu }
            'backup' { & (Join-Path $DevToolsRoot 'commands/backup.ps1'); Wait-ForKey }
            'doctor' { . (Join-Path $DevToolsRoot 'commands/doctor.ps1'); Wait-ForKey }
            'configure' { . (Join-Path $DevToolsRoot 'commands/configure.ps1') }
            'settings' { . (Join-Path $DevToolsRoot 'commands/settings.ps1') }
            'help' { . (Join-Path $DevToolsRoot 'commands/help.ps1'); Wait-ForKey }
            'deploy' { Invoke-DeploymentManagerMenu -ConfigObject $Config | Out-Null }
            default { ShowWarning 'Choose a shortcut from the list.'; Wait-ForKey }
        }

        if ($action -in @('sync', 'clone', 'status', 'repos', 'backup', 'doctor', 'configure', 'settings')) {
            $snapshot = $null
        }
    }
}
