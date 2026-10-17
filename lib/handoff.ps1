# Cross-machine inspection and explicit sync entry points.
# Reuses repository facts/classification; never treats Git as a file backup service.

function Get-WorkspaceHandoffReport {
    param([Parameter(Mandatory = $true)][string]$WorkspacePath)

    if (-not (Test-Path -LiteralPath $WorkspacePath -PathType Container)) {
        throw "Workspace does not exist: $WorkspacePath. Run dev configure to select this computer's workspace."
    }
    $rows = @()
    # Match existing one-folder-per-project discovery. Do not follow junctions.
    foreach ($project in @(Get-ChildItem -LiteralPath $WorkspacePath -Directory -Force -ErrorAction Stop |
            Where-Object { $_.Name -ne '.git' } | Sort-Object Name)) {
        $reasons = @()
        $state = $null
        $ignoredCount = 0
        $unpublished = 0
        $plan = 'Skip'
        if ($project.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $reasons += 'Linked folder: inspect its target separately.'
        }
        elseif (-not (Test-Path -LiteralPath (Join-Path $project.FullName '.git'))) {
            $reasons += 'Not a Git repository. Copy or back up local files separately; Git cannot transfer this folder.'
        }
        else {
            $facts = Get-RepositoryFacts -RepoPath $project.FullName -Name $project.Name
            $state = Get-RepositoryState -Facts $facts
            # --directory collapses ignored build/dependency trees instead of walking every file.
            $ignored = Invoke-DevToolsGit -RepoPath $project.FullName -GitArgs @('ls-files', '--others', '--ignored', '--exclude-standard', '--directory')
            $localCommits = Invoke-DevToolsGit -RepoPath $project.FullName -GitArgs @('rev-list', '--count', '--branches', '--not', '--remotes')
            if ($ignored.Success) { $ignoredCount = @($ignored.Lines).Count }
            else { $reasons += 'Could not inspect ignored files.' }
            if ($localCommits.Success -and $localCommits.Output -match '^\d+$') { $unpublished = [int]$localCommits.Output }
            else { $reasons += 'Could not inspect unpublished commits across local branches.' }
            $stash = Invoke-DevToolsGit -RepoPath $project.FullName -GitArgs @('stash', 'list', '--format=%gd')
            if (-not $stash.Success) { $reasons += 'Could not inspect local stashes.' }
            elseif (@($stash.Lines).Count -gt 0) { $reasons += 'Local stashes exist. Git push/pull does not transfer stashes; review separately.' }
            if ($state.HealthCode -notin @('Current', 'Behind')) { $reasons += "$($state.HealthLabel): $($state.RecommendedAction)" }
            if ($unpublished -gt 0) { $reasons += "$unpublished commit(s) across local branches absent from cached remote refs. Review and push explicitly when ready." }
            if ($ignoredCount -gt 0) { $reasons += "$ignoredCount ignored file/directory entry(s): review separately; Git does not transfer these." }
            if ($facts.HasRemote -and $facts.RemoteUrl -notmatch '^(https?://|ssh://|git://|[^/\\:]+@[^:]+:)') {
                $reasons += 'Remote is a local path or unrecognized transport; verify accessibility from the other computer.'
            }
            if ($state.CanFastForward -and $ignored.Success -and $ignoredCount -eq 0) { $plan = 'Would fast-forward after refresh and recheck' }
            elseif ($state.HealthCode -eq 'Current') { $plan = 'No update (cached)' }
        }
        $rows += [pscustomobject]@{
            Name = $project.Name; Path = $project.FullName; State = $state
            Readiness = $(if ($reasons.Count -eq 0) { 'Ready (cached)' } else { 'Needs attention' })
            Reasons = @($reasons); IgnoredEntries = $ignoredCount
            UnpublishedCommits = $unpublished; SyncPlan = $plan
        }
    }
    return [pscustomobject]@{
        Workspace = $WorkspacePath; InspectedAt = [DateTime]::UtcNow.ToString('o')
        RemoteKnowledge = 'Cached remote refs only; no network verification.'
        Projects = @($rows)
    }
}

function Show-WorkspaceHandoffReport {
    param([Parameter(Mandatory = $true)]$Report)
    Write-Host "Workspace: $($Report.Workspace)"
    Write-Host $Report.RemoteKnowledge
    Write-Host 'Ready means this branch has no known local work to transfer. Check the destination with Doctor before pulling.'
    Write-Host 'Ignored files, stashes, nested projects, files outside these project folders, and the other computer are not synchronized.'
    if (@($Report.Projects).Count -eq 0) { Write-Host 'No project folders found.' }
    foreach ($row in $Report.Projects) {
        Write-Host "[$($row.Readiness)] $($row.Name)"
        if ($row.State) {
            $s = $row.State
            Write-Host "  Branch: $($s.BranchDisplay); health: $($s.HealthLabel); changed: $($s.ModifiedFilesCount); untracked: $($s.UntrackedFilesCount); ahead: $($s.Ahead); behind: $($s.Behind)"
        }
        Write-Host "  Sync: $($row.SyncPlan)"
        foreach ($reason in $row.Reasons) { Write-Host "  $reason" }
    }
}

function Invoke-WorkspaceHandoffCommand {
    param(
        [ValidateSet('Doctor', 'Readiness', 'Sync')][string]$Mode,
        [AllowEmptyCollection()][string[]]$Arguments = @()
    )
    $options = @($Arguments | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.ToLowerInvariant() })
    $allowed = if ($Mode -eq 'Sync') { @('--dry-run', '--refresh', '--apply') } else { @() }
    foreach ($option in $options) {
        if ($option -notin $allowed) { throw "Unknown option '$option' for $Mode." }
    }
    if ('--dry-run' -in $options -and ('--apply' -in $options -or '--refresh' -in $options)) {
        throw '--dry-run cannot be combined with --apply or --refresh. Dry runs never fetch or update files.'
    }
    if (-not (Test-RequireGit)) { return }
    if ($Mode -eq 'Doctor') {
        Write-Host 'Doctor: read-only workspace health (no setup, sign-in, fetch, or fixes).'
        Write-Host 'GitHub CLI, cloud services, and AI are not needed for this inspection.'
    }
    $report = Get-WorkspaceHandoffReport -WorkspacePath $Config.workspacePath
    Show-WorkspaceHandoffReport -Report $report
    if ($Mode -ne 'Sync') { return }
    if ('--apply' -notin $options -and '--refresh' -notin $options) {
        Write-Host 'Preview only. No fetch, commit, push, pull, or file changes.'
        Write-Host 'Next: dev sync --refresh (fetch only), or dev sync --apply (fetch, recheck, fast-forward only).'
        return
    }
    # These two explicit options permit network access and remote-ref changes.
    # Each project is inspected again after fetching; the preview is never a mutation plan to replay blindly.
    foreach ($row in $report.Projects) {
        if (-not $row.State -or -not $row.State.IsGitRepository) { continue }
        $facts = Get-RepositoryFacts -RepoPath $row.Path -Name $row.Name -Refresh
        $state = Get-RepositoryState -Facts $facts
        if ('--apply' -notin $options) {
            Write-Host "Refreshed: $($row.Name) - $($state.HealthLabel) (no working-tree update)"
            continue
        }
        $result = Invoke-RepositorySyncForState -State $state
        Write-Host "$($result.Outcome): $($row.Name) $($result.Reason)"
    }
}
