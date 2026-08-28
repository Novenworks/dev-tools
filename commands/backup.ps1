# dev backup — safe backup workflow, with an optional secondary remote.
#
# Backup never commits or pushes without confirmation. "setup" and "status"
# are read-only/local-only (no push); only the default flow pushes.

$backupArgs = @($script:DevToolsCommandArgs)
$backupSubCommand = ''

foreach ($argument in $backupArgs) {
    if ([string]::IsNullOrWhiteSpace($argument)) { continue }
    $backupSubCommand = ([string]$argument).ToLower()
    break
}

switch ($backupSubCommand) {
    'setup' {
        ShowCommandScreen -Heading 'Backup Setup' -Description @(
            'Configure an optional secondary remote (GitLab or Bitbucket).'
        )
        $exitCode = Invoke-BackupSetupCommand -ConfigObject $Config -WorkspacePath $Config.workspacePath
        Wait-ForKey
        exit $exitCode
    }
    'status' {
        ShowCommandScreen -Heading 'Backup Status' -Description @(
            'Which repositories have a secondary backup remote configured.'
        )
        $exitCode = Invoke-BackupStatusCommand -ConfigObject $Config -WorkspacePath $Config.workspacePath
        Wait-ForKey
        exit $exitCode
    }
    '' {
        # falls through to the default backup-and-push flow below
    }
    default {
        ShowError "Unknown backup command: $backupSubCommand"
        ShowInfo 'Valid: dev backup, dev backup setup, dev backup status'
        Wait-ForKey
        exit 1
    }
}

ShowCommandScreen -Heading 'Backup Changes' -Description @(
    'DevTools found repositories with uncommitted changes.'
)

if (-not (Test-RequireGit)) {
    Wait-ForKey
    exit 1
}

$changedRepos = @(Get-ChangedWorkspaceRepos -WorkspacePath $Config.workspacePath)

if ($changedRepos.Count -eq 0) {
    ShowSuccess 'Everything looks good. No backup needed right now.'
    Wait-ForKey
    exit 0
}

$backupConfig = Get-BackupConfig -ConfigObject $Config
$secondaryLabel = if ($backupConfig.Provider) { Get-BackupProviderDisplayName -Provider $backupConfig.Provider } else { 'Backup' }

ShowSection -Label 'Repositories'
foreach ($repo in $changedRepos) {
    Write-Host "  $($repo.Name)" -ForegroundColor Yellow
}

Write-Host ''
Write-Host '[Y] Yes' -ForegroundColor Green
Write-Host '[N] Cancel' -ForegroundColor DarkGray
Write-Host ''
$confirm = Read-Host 'Create backup commits and push them now?'

if ($confirm -notmatch '^[Yy]$') {
    ShowInfo 'Backup cancelled. Your changes are still on your computer.'
    Wait-ForKey
    exit 0
}

Write-Host ''

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$message = "$($Config.autoBackupMessage) $timestamp"

$rows = @()
$primaryOk = 0
$primaryTotal = 0
$secondaryOk = 0
$secondaryTotal = 0

foreach ($repo in $changedRepos) {
    ShowInfo "Saving $($repo.Name)..."

    Push-Location $repo.FullName
    try {
        $null = git add . 2>&1 | Out-String
        $addExit = $LASTEXITCODE
        if ($addExit -ne 0) {
            ShowWarning "Could not prepare $($repo.Name)"
            $rows += [pscustomobject]@{ Name = $repo.Name; PrimaryOk = $false; HasSecondary = $false; SecondaryOk = $false }
            continue
        }

        $null = git commit -m $message 2>&1 | Out-String
        $commitExit = $LASTEXITCODE
        if ($commitExit -ne 0) {
            ShowWarning "Could not save $($repo.Name)"
            $rows += [pscustomobject]@{ Name = $repo.Name; PrimaryOk = $false; HasSecondary = $false; SecondaryOk = $false }
            continue
        }

        $branch = Get-RepoBranch -RepoPath $repo.FullName

        $primaryTotal++
        $primaryResult = Invoke-GitPushToRemote -RepoPath $repo.FullName -RemoteName 'origin' -Branch $branch
        $primaryRowOk = $primaryResult.Success

        if ($primaryRowOk) {
            $primaryOk++
        }

        $hasSecondary = Test-GitRemoteExists -RepoPath $repo.FullName -RemoteName $backupConfig.RemoteName
        $secondaryRowOk = $false

        if ($hasSecondary) {
            $secondaryTotal++
            # Attempted independently of the primary result: the local commit
            # already exists, so a failed GitHub push should not cost the user
            # their secondary copy too.
            $secondaryResult = Invoke-GitBackupPush -RepoPath $repo.FullName -RemoteName $backupConfig.RemoteName
            $secondaryRowOk = $secondaryResult.Success

            if ($secondaryRowOk) {
                $secondaryOk++
            }
        }

        if ($primaryRowOk) {
            ShowSuccess "Saved: $($repo.Name)"
        }
        else {
            ShowWarning "Could not upload $($repo.Name) to GitHub"
        }

        $rows += [pscustomobject]@{
            Name         = $repo.Name
            PrimaryOk    = $primaryRowOk
            HasSecondary = $hasSecondary
            SecondaryOk  = $secondaryRowOk
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host ''
ShowSection -Label 'Summary'

foreach ($row in $rows) {
    Write-Host "$($row.Name)" -ForegroundColor Cyan
    $primaryIcon = if ($row.PrimaryOk) { Get-UiIcon -Name 'pass' } else { Get-UiIcon -Name 'fail' }
    $primaryColor = if ($row.PrimaryOk) { 'Green' } else { 'Yellow' }
    Write-Host "  $primaryIcon GitHub" -ForegroundColor $primaryColor

    if ($row.HasSecondary) {
        $secondaryIcon = if ($row.SecondaryOk) { Get-UiIcon -Name 'pass' } else { Get-UiIcon -Name 'warn' }
        $secondaryColor = if ($row.SecondaryOk) { 'Green' } else { 'Yellow' }
        $secondarySuffix = if ($row.SecondaryOk) { '' } else { ' failed' }
        Write-Host "  $secondaryIcon $secondaryLabel$secondarySuffix" -ForegroundColor $secondaryColor
    }

    Write-Host ''
}

ShowInfo "Primary: $primaryOk/$primaryTotal"
if ($secondaryTotal -gt 0) {
    ShowInfo "Secondary: $secondaryOk/$secondaryTotal"
}

if ($primaryOk -eq $primaryTotal -and $secondaryOk -eq $secondaryTotal) {
    ShowSuccess 'Backup complete.'
}
else {
    ShowWarning 'Backup finished with some issues.'
}

Wait-ForKey
