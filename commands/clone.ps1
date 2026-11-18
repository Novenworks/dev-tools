ShowCommandScreen -Heading 'Download new projects' -Description @(
    'Find projects on your GitHub accounts that are missing from this workspace.'
    'New folders are created here. Existing folders are skipped.'
    'Review the number of downloads before starting.'
)

if (-not (Test-RequireGit)) { exit 1 }
if (-not (Test-RequireGh)) { exit 1 }
if (-not (Test-GhAuthenticated)) {
    ShowWarning 'Sign in to GitHub before downloading projects.'
    ShowInfo 'Next step: run devrepo doctor and choose the sign-in option.'
    exit 1
}

$planned = [System.Collections.Generic.List[object]]::new()
$existing = 0
$ownerFailures = 0

foreach ($owner in $Config.githubOwners) {
    ShowInfo "Checking $owner on GitHub..."
    try {
        $repos = Get-GithubReposForOwner -Owner $owner
    }
    catch {
        ShowWarning $_.Exception.Message
        $ownerFailures++
        continue
    }

    foreach ($nameWithOwner in $repos) {
        $repoName = ($nameWithOwner -split '/')[1]
        $target = Join-Path $Config.workspacePath $repoName
        if (Test-Path -LiteralPath $target) {
            $existing++
            continue
        }
        $planned.Add([pscustomobject]@{ Name = $nameWithOwner; Path = $target })
    }
}

Write-Host ''
ShowInfo ("Found {0} download candidates. {1} already have local folders." -f $planned.Count, $existing)
if ($ownerFailures -gt 0) {
    ShowWarning "$ownerFailures GitHub accounts could not be checked."
}
if ($planned.Count -eq 0) {
    ShowInfo 'Next: open a local project or check your GitHub setup.'
    if ($ownerFailures -gt 0) { exit 1 }
    return
}

if (-not (Confirm-DevRepoAction -Label "Download projects to $($Config.workspacePath)")) {
    ShowInfo 'Download canceled. No project folders were created.'
    return
}

Ensure-Directory -Path $Config.workspacePath
$downloaded = 0
$failed = 0

foreach ($item in $planned) {
    if (Test-Path -LiteralPath $item.Path) {
        ShowInfo "Existing folder, skipped: $($item.Name)"
        $existing++
        continue
    }

    ShowInfo "Downloading: $($item.Name)"
    $exitCode = Invoke-QuietCommand -FilePath 'gh' -ArgumentList @('repo', 'clone', $item.Name, $item.Path)
    if ($exitCode -eq 0 -and (Test-ProjectIsGitRepo -Path $item.Path)) {
        ShowSuccess "Downloaded: $($item.Name)"
        $downloaded++
    }
    else {
        ShowWarning "Could not verify download: $($item.Name)"
        $failed++
    }
}

ShowSummary -Title 'Download results' -Lines @(
    "Downloaded: $downloaded"
    "Existing folders skipped: $existing"
    "Downloads needing attention: $failed"
    "GitHub accounts that could not be checked: $ownerFailures"
    'Next: open a project or check your GitHub setup.'
)
if ($failed -gt 0 -or $ownerFailures -gt 0) { exit 1 }
