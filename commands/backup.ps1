ShowCommandScreen -Heading 'Backup Changes' -Description @(
    'DevTools found repositories with uncommitted changes.'
)

if (-not (Test-RequireGit)) { exit 1 }

$changedRepos = @(Get-ChangedWorkspaceRepos -WorkspacePath $Config.workspacePath)

if ($changedRepos.Count -eq 0) {
    ShowSuccess 'Everything looks good. No backup needed right now.'
    exit 0
}

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
    exit 0
}

Write-Host ''

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$message = "$($Config.autoBackupMessage) $timestamp"

$backedUp = 0
$issues = 0

foreach ($repo in $changedRepos) {
    ShowInfo "Saving $($repo.Name)..."

    Push-Location $repo.FullName
    try {
        $addExit = Invoke-QuietCommand -FilePath 'git' -ArgumentList @('add', '.')
        if ($addExit -ne 0) {
            ShowWarning "Could not prepare $($repo.Name)"
            $issues++
            continue
        }

        $commitExit = Invoke-QuietCommand -FilePath 'git' -ArgumentList @('commit', '-m', $message)
        if ($commitExit -ne 0) {
            ShowWarning "Could not save $($repo.Name)"
            $issues++
            continue
        }

        $pushExit = Invoke-QuietCommand -FilePath 'git' -ArgumentList @('push')
        if ($pushExit -eq 0) {
            ShowSuccess "Saved: $($repo.Name)"
            $backedUp++
        }
        else {
            ShowWarning "Could not upload $($repo.Name)"
            $issues++
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host ''
if ($issues -eq 0) {
    ShowSuccess 'Backup complete.'
    ShowInfo 'Everything has been safely committed and pushed.'
}
else {
    ShowWarning 'Backup finished with some issues.'
    ShowInfo "Saved: $backedUp | Issues: $issues"
}
