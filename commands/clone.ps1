ShowCommandScreen -Heading 'Clone Repositories' -Description @(
    "Checking GitHub for repositories you don't have locally."
)

if (-not (Test-RequireGit)) { exit 1 }
if (-not (Test-RequireGh)) { exit 1 }

if (-not (Test-GhAuthenticated)) {
    ShowWarning 'You are not signed in to GitHub yet.'
    ShowInfo 'Next step: run Doctor and sign in to GitHub.'
    exit 1
}

Ensure-Directory -Path $Config.workspacePath
Set-Location $Config.workspacePath

$downloaded = 0
$skipped = 0
$issues = 0

foreach ($owner in $Config.githubOwners) {
    ShowInfo "Checking $owner on GitHub..."

    try {
        $repos = Get-GithubReposForOwner -Owner $owner
    }
    catch {
        ShowWarning $_.Exception.Message
        $issues++
        continue
    }

    foreach ($nameWithOwner in $repos) {
        $repoName = ($nameWithOwner -split '/')[1]
        $target = Join-Path $Config.workspacePath $repoName

        if (Test-Path $target) {
            ShowInfo "Already local: $nameWithOwner"
            $skipped++
            continue
        }

        ShowInfo "Downloading: $nameWithOwner"
        $exitCode = Invoke-QuietCommand -FilePath 'gh' -ArgumentList @('repo', 'clone', $nameWithOwner, $target)

        if ($exitCode -eq 0) {
            ShowSuccess "Downloaded: $nameWithOwner"
            $downloaded++
        }
        else {
            ShowWarning "Could not download: $nameWithOwner"
            $issues++
        }
    }
}

Write-Host ''
ShowScreenTitle -Title 'Finished.'
ShowSummary -Lines @(
    "Downloaded: $downloaded"
    "Skipped: $skipped"
    "Issues: $issues"
)
