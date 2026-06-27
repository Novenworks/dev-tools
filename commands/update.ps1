ShowCommandScreen -Heading 'Update Repositories' -Description @(
    'Checking each repository for new changes.'
)

if (-not (Test-RequireGit)) { exit 1 }

if (-not (Test-Path $Config.workspacePath)) {
    ShowWarning 'Your workspace folder is not set up yet.'
    ShowInfo 'Next step: run Configure first.'
    exit 1
}

$repos = Get-WorkspaceGitRepos -WorkspacePath $Config.workspacePath
$updated = 0
$current = 0
$issues = 0

if ($repos.Count -eq 0) {
    ShowInfo 'No repositories found yet.'
    ShowInfo 'Next step: run Clone missing repositories.'
    exit 0
}

foreach ($repo in $repos) {
    ShowInfo "Checking $($repo.Name)..."

    $result = Invoke-GitPullWithOutput -RepoPath $repo.FullName

    if ($result.ExitCode -eq 0) {
        if (Test-GitPullAlreadyCurrent -Output $result.Output) {
            ShowInfo "Already current: $($repo.Name)"
            $current++
        }
        else {
            ShowSuccess "Updated: $($repo.Name)"
            $updated++
        }
    }
    else {
        ShowWarning "Could not update: $($repo.Name)"
        $issues++
    }
}

ShowSummary -Title 'Summary' -Lines @(
    "Updated: $updated"
    "Already Current: $current"
    "Issues: $issues"
)
