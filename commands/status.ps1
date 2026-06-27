ShowCommandScreen -Heading 'Repository Status' -Description @(
    'Current status of your local repositories.'
)

if (-not (Test-RequireGit)) { exit 1 }

if (-not (Test-Path $Config.workspacePath)) {
    ShowWarning 'Your workspace folder is not set up yet.'
    ShowInfo 'Next step: run Configure or choose option 1 from Home Dashboard.'
    exit 1
}

$repos = Get-WorkspaceGitRepos -WorkspacePath $Config.workspacePath

if ($repos.Count -eq 0) {
    ShowInfo 'No repositories found yet.'
    ShowInfo 'Next step: run Clone missing repositories after signing in to GitHub.'
    exit 0
}

$rows = @()
$cleanCount = 0
$modifiedCount = 0
$aheadCount = 0
$behindCount = 0
$conflictCount = 0

foreach ($repo in $repos) {
    $details = Get-RepoStatusDetails -RepoPath $repo.FullName
    $rows += $details

    if ($details.IsClean) { $cleanCount++ }
    if ($details.IsModified) { $modifiedCount++ }
    if ($details.Ahead -gt 0) { $aheadCount++ }
    if ($details.Behind -gt 0) { $behindCount++ }
    if ($details.HasConflicts) { $conflictCount++ }
}

ShowRepositoryStatusTable -Rows $rows

ShowSummary -Title 'Summary' -Lines @(
    "Clean: $cleanCount"
    "Modified: $modifiedCount"
    "Ahead: $aheadCount"
    "Behind: $behindCount"
    "Conflicts: $conflictCount"
)

Write-Host ''
if ($modifiedCount -eq 0 -and $aheadCount -eq 0 -and $behindCount -eq 0 -and $conflictCount -eq 0) {
    ShowSuccess 'Everything looks good.'
}
else {
    ShowWarning 'Some repositories need attention.'
    ShowInfo 'Next step: review changed repos, then run Update or Backup if needed.'
}
