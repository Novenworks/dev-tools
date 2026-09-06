# Repository intelligence - pure state classification.
#
# Every function here is pure: facts in, classification out. No Git calls, no UI.
# This is what makes repository health testable without touching real repositories.

function Get-RepositoryHealthCatalog {
    <#
    .SYNOPSIS
        The single catalog of repository health states.
    .DESCRIPTION
        Order matters. Classification walks these rules top down and returns the
        first match, so the most actionable condition always wins. A repository
        with unresolved conflicts is never reported as merely "Modified".
    #>

    return @(
        [pscustomobject]@{
            Code = 'InvalidRepository'; Label = 'Not a repository'; Severity = 'Problem'; Group = 'Other'
            Explanation = 'DevTools could not read this folder as a Git repository.'
            LocalWork = 'Your files are untouched.'
            Action = 'Open the folder and check whether it was moved, renamed, or never cloned.'
        }
        [pscustomobject]@{
            Code = 'Conflicts'; Label = 'Conflicts'; Severity = 'Problem'; Group = 'Conflicts'
            Explanation = 'This repository has unresolved merge conflicts.'
            LocalWork = 'Nothing was lost. Your conflicted files are still on disk.'
            Action = 'Resolve the existing merge conflicts before syncing.'
        }
        [pscustomobject]@{
            Code = 'MergeInProgress'; Label = 'Merge in progress'; Severity = 'Problem'; Group = 'Operation'
            Explanation = 'A merge was started here and has not been finished.'
            LocalWork = 'Your work is safe. DevTools did not touch this repository.'
            Action = 'Finish the merge with a commit, or cancel it, before syncing.'
        }
        [pscustomobject]@{
            Code = 'RebaseInProgress'; Label = 'Rebase in progress'; Severity = 'Problem'; Group = 'Operation'
            Explanation = 'A rebase was started here and has not been finished.'
            LocalWork = 'Your work is safe. DevTools did not touch this repository.'
            Action = 'Continue or abort the rebase before syncing.'
        }
        [pscustomobject]@{
            Code = 'OperationInProgress'; Label = 'Operation in progress'; Severity = 'Problem'; Group = 'Operation'
            Explanation = 'A cherry-pick, revert, or bisect is still running in this repository.'
            LocalWork = 'Your work is safe. DevTools did not touch this repository.'
            Action = 'Finish or cancel the in-progress Git operation before syncing.'
        }
        [pscustomobject]@{
            Code = 'DetachedHead'; Label = 'Detached HEAD'; Severity = 'Attention'; Group = 'Detached'
            Explanation = 'This repository is not currently on a branch.'
            LocalWork = 'Your work is safe, but new commits here are easy to lose.'
            Action = 'Review before switching branches, then check out a branch.'
        }
        [pscustomobject]@{
            Code = 'AuthenticationFailed'; Label = 'Sign-in required'; Severity = 'Problem'; Group = 'Remote'
            Explanation = 'GitHub refused the connection because DevTools is not signed in for this repository.'
            LocalWork = 'Your work is safe. Nothing was changed.'
            Action = 'Sign in again, then sync. Run Doctor if GitHub CLI needs attention.'
        }
        [pscustomobject]@{
            Code = 'RemoteUnavailable'; Label = 'Remote unavailable'; Severity = 'Attention'; Group = 'Remote'
            Explanation = 'DevTools could not reach the remote server.'
            LocalWork = 'Your work is safe. Nothing was changed.'
            Action = 'Check your network connection, then sync again.'
        }
        [pscustomobject]@{
            Code = 'FetchFailed'; Label = 'Refresh failed'; Severity = 'Attention'; Group = 'Remote'
            Explanation = 'DevTools could not refresh the remote state for this repository.'
            LocalWork = 'Your work is safe. Nothing was changed.'
            Action = 'Show details for the Git error, then sync again.'
        }
        [pscustomobject]@{
            Code = 'UpstreamGone'; Label = 'Upstream gone'; Severity = 'Attention'; Group = 'Upstream'
            Explanation = 'The branch is tracking a remote branch that no longer exists.'
            LocalWork = 'Your commits are safe on the local branch.'
            Action = 'Use Repair upstream to review, then switch to the default branch.'
        }
        [pscustomobject]@{
            Code = 'MissingUpstream'; Label = 'Missing upstream'; Severity = 'Attention'; Group = 'Upstream'
            Explanation = 'This branch is not tracking any remote branch, so DevTools cannot tell whether it is current.'
            LocalWork = 'Your work is safe and stays local.'
            Action = 'Push the branch to set an upstream, or switch to the default branch.'
        }
        [pscustomobject]@{
            Code = 'Diverged'; Label = 'Diverged'; Severity = 'Problem'; Group = 'Diverged'
            Explanation = 'Local and remote branches both contain unique commits.'
            LocalWork = 'Your commits are safe. DevTools will not merge or rebase for you.'
            Action = 'Review manually before merging or rebasing.'
        }
        [pscustomobject]@{
            Code = 'LocalChanges'; Label = 'Local changes'; Severity = 'Attention'; Group = 'Dirty'
            Explanation = 'This repository has uncommitted changes in the working tree.'
            LocalWork = 'Your changes are safe. DevTools never stashes or discards them.'
            Action = 'Review or commit your local changes before syncing.'
        }
        [pscustomobject]@{
            Code = 'RemoteMissing'; Label = 'No remote'; Severity = 'Attention'; Group = 'Remote'
            Explanation = 'This repository has no remote configured, so there is nothing to sync with.'
            LocalWork = 'Your work is safe and stays local.'
            Action = 'Add a remote if this project should live on GitHub.'
        }
        [pscustomobject]@{
            Code = 'Ahead'; Label = 'Ahead'; Severity = 'Attention'; Group = 'Ahead'
            Explanation = 'This repository contains local commits that are not on GitHub.'
            LocalWork = 'Your commits are safe locally, but they are not backed up yet.'
            Action = 'Review and push when ready.'
        }
        [pscustomobject]@{
            Code = 'Behind'; Label = 'Behind'; Severity = 'Attention'; Group = 'Behind'
            Explanation = 'GitHub has commits that are not in your local copy.'
            LocalWork = 'Your work is safe.'
            Action = 'Sync to fast-forward this repository.'
        }
        [pscustomobject]@{
            Code = 'Current'; Label = 'Current'; Severity = 'Healthy'; Group = 'Healthy'
            Explanation = 'This repository matches GitHub and has no local changes.'
            LocalWork = 'Nothing to do.'
            Action = 'No action needed.'
        }
    )
}

function Get-RepositoryHealthDefinition {
    param([Parameter(Mandatory = $true)][string]$Code)

    $match = Get-RepositoryHealthCatalog | Where-Object { $_.Code -eq $Code } | Select-Object -First 1

    if ($match) { return $match }

    return [pscustomobject]@{
        Code = 'OtherGitError'; Label = 'Git error'; Severity = 'Problem'; Group = 'Other'
        Explanation = 'Git reported an error DevTools does not recognize.'
        LocalWork = 'Your work is safe. Nothing was changed.'
        Action = 'Show details for the Git error, or export a diagnostic report.'
    }
}

function Get-RepositoryHealthCode {
    <#
    .SYNOPSIS
        Classifies repository facts into a single health code. Pure function.
    #>
    param([Parameter(Mandatory = $true)]$Facts)

    if (-not $Facts.IsGitRepository) { return 'InvalidRepository' }
    if ($Facts.HasConflicts) { return 'Conflicts' }
    if ($Facts.MergeInProgress) { return 'MergeInProgress' }
    if ($Facts.RebaseInProgress) { return 'RebaseInProgress' }
    if ($Facts.CherryPickInProgress -or $Facts.RevertInProgress -or $Facts.BisectInProgress) { return 'OperationInProgress' }
    if ($Facts.IsDetachedHead) { return 'DetachedHead' }

    if ($Facts.FetchAttempted -and -not $Facts.FetchSucceeded) {
        switch ($Facts.FetchErrorCategory) {
            'Authentication' { return 'AuthenticationFailed' }
            'Network' { return 'RemoteUnavailable' }
            'RemoteMissing' { return 'RemoteUnavailable' }
            default { return 'FetchFailed' }
        }
    }

    if ($Facts.Ahead -gt 0 -and $Facts.Behind -gt 0) { return 'Diverged' }

    # Uncommitted work is more actionable than a missing remote or upstream, and
    # it blocks every repair path anyway, so it is reported first.
    if ($Facts.IsDirty) { return 'LocalChanges' }

    if ($Facts.HasRemote -and $Facts.UpstreamConfigured -and -not $Facts.UpstreamExists) { return 'UpstreamGone' }
    if ($Facts.HasRemote -and -not $Facts.UpstreamConfigured) { return 'MissingUpstream' }
    if (-not $Facts.HasRemote) { return 'RemoteMissing' }

    if ($Facts.Ahead -gt 0) { return 'Ahead' }
    if ($Facts.Behind -gt 0) { return 'Behind' }

    return 'Current'
}

function Test-RepositoryCanFastForward {
    <#
    .SYNOPSIS
        The safe-update policy. Pure function.
    .DESCRIPTION
        DevTools only updates a repository automatically when every one of these
        is true. Anything else is skipped and explained.
    #>
    param([Parameter(Mandatory = $true)]$Facts)

    if (-not $Facts.IsGitRepository) { return $false }
    if (-not $Facts.HasRemote) { return $false }
    if ($Facts.FetchAttempted -and -not $Facts.FetchSucceeded) { return $false }
    if ($Facts.IsDetachedHead) { return $false }
    if ($Facts.MergeInProgress -or $Facts.RebaseInProgress) { return $false }
    if ($Facts.CherryPickInProgress -or $Facts.RevertInProgress -or $Facts.BisectInProgress) { return $false }
    if ($Facts.HasConflicts) { return $false }
    if ($Facts.IsDirty) { return $false }
    if (-not $Facts.UpstreamConfigured) { return $false }
    if (-not $Facts.UpstreamExists) { return $false }
    if ($Facts.Ahead -gt 0) { return $false }
    if ($Facts.Behind -le 0) { return $false }

    return $true
}

function Get-RepositoryStateDetail {
    <#
    .SYNOPSIS
        Adds repository-specific wording to the generic catalog copy. Pure function.
    #>
    param(
        [Parameter(Mandatory = $true)]$Facts,
        [Parameter(Mandatory = $true)][string]$Code
    )

    switch ($Code) {
        'UpstreamGone' {
            if (-not [string]::IsNullOrWhiteSpace($Facts.Upstream)) {
                return "$($Facts.Upstream) no longer exists"
            }
            return 'the tracked remote branch no longer exists'
        }
        'MissingUpstream' {
            if (-not [string]::IsNullOrWhiteSpace($Facts.CurrentBranch)) {
                return "$($Facts.CurrentBranch) is not tracking a remote branch"
            }
            return 'no upstream branch is configured'
        }
        'LocalChanges' {
            $parts = @()
            if ($Facts.ModifiedFilesCount -gt 0) { $parts += "$($Facts.ModifiedFilesCount) changed" }
            if ($Facts.UntrackedFilesCount -gt 0) { $parts += "$($Facts.UntrackedFilesCount) untracked" }
            if ($parts.Count -eq 0) { return 'local changes' }
            return ($parts -join ', ') + ' file(s)'
        }
        'Ahead' { return "$($Facts.Ahead) commit(s) not on GitHub" }
        'Behind' { return "$($Facts.Behind) commit(s) available" }
        'Diverged' { return "$($Facts.Ahead) local, $($Facts.Behind) remote commit(s)" }
        'Conflicts' { return "$($Facts.ConflictFilesCount) conflicted file(s)" }
        'DetachedHead' {
            if (-not [string]::IsNullOrWhiteSpace($Facts.Head)) {
                $short = $Facts.Head
                if ($short.Length -gt 7) { $short = $short.Substring(0, 7) }
                return "HEAD is at $short"
            }
            return 'not on a branch'
        }
        default { return '' }
    }
}

function Get-RepositoryState {
    <#
    .SYNOPSIS
        Builds the authoritative repository state object used across DevTools.
    .DESCRIPTION
        Pure function over facts. Repository Health, Sync, Project Info, repair,
        and diagnostic reports all consume this same object.
    #>
    param([Parameter(Mandatory = $true)]$Facts)

    $code = Get-RepositoryHealthCode -Facts $Facts
    $definition = Get-RepositoryHealthDefinition -Code $code
    $detail = Get-RepositoryStateDetail -Facts $Facts -Code $code

    $branchDisplay = $Facts.CurrentBranch
    if ($Facts.IsDetachedHead) { $branchDisplay = '(detached)' }
    if ([string]::IsNullOrWhiteSpace($branchDisplay)) { $branchDisplay = '(unknown)' }

    return [pscustomobject]@{
        Name                 = $Facts.Name
        Path                 = $Facts.Path
        IsGitRepository      = $Facts.IsGitRepository
        CurrentBranch        = $Facts.CurrentBranch
        BranchDisplay        = $branchDisplay
        IsDetachedHead       = $Facts.IsDetachedHead
        DefaultBranch        = $Facts.DefaultBranch
        RemoteName           = $Facts.RemoteName
        RemoteUrl            = $Facts.RemoteUrl
        Upstream             = $Facts.Upstream
        UpstreamConfigured   = $Facts.UpstreamConfigured
        UpstreamExists       = $Facts.UpstreamExists
        RemoteBranchExists   = $Facts.RemoteBranchExists
        IsDirty              = $Facts.IsDirty
        ModifiedFilesCount   = $Facts.ModifiedFilesCount
        UntrackedFilesCount  = $Facts.UntrackedFilesCount
        HasConflicts         = $Facts.HasConflicts
        ConflictFilesCount   = $Facts.ConflictFilesCount
        MergeInProgress      = $Facts.MergeInProgress
        RebaseInProgress     = $Facts.RebaseInProgress
        CherryPickInProgress = $Facts.CherryPickInProgress
        RevertInProgress     = $Facts.RevertInProgress
        Ahead                = $Facts.Ahead
        Behind               = $Facts.Behind
        IsDiverged           = $Facts.IsDiverged
        FetchAttempted       = $Facts.FetchAttempted
        FetchSucceeded       = $Facts.FetchSucceeded
        FetchError           = $Facts.FetchError
        RemoteAvailable      = $Facts.RemoteAvailable
        GitError             = $Facts.GitError
        HealthCode           = $code
        HealthLabel          = $definition.Label
        HealthSeverity       = $definition.Severity
        HealthGroup          = $definition.Group
        IsHealthy            = ($definition.Severity -eq 'Healthy')
        NeedsAttention       = ($definition.Severity -ne 'Healthy')
        Explanation          = $definition.Explanation
        LocalWorkNote        = $definition.LocalWork
        RecommendedAction    = $definition.Action
        Detail               = $detail
        CanFastForward       = (Test-RepositoryCanFastForward -Facts $Facts)
        DisplayStatus        = $definition.Label
    }
}

function Get-RepositoryStateSummary {
    <#
    .SYNOPSIS
        Counts repository states by group for health and sync summaries. Pure function.
    #>
    param([AllowEmptyCollection()][array]$States = @())

    $summary = [ordered]@{
        Total          = 0
        Healthy        = 0
        NeedsAttention = 0
        Dirty          = 0
        Behind         = 0
        Ahead          = 0
        Diverged       = 0
        Upstream       = 0
        Detached       = 0
        Conflicts      = 0
        Operation      = 0
        Remote         = 0
        Other          = 0
    }

    foreach ($state in @($States)) {
        $summary.Total++

        if ($state.IsHealthy) {
            $summary.Healthy++
            continue
        }

        $summary.NeedsAttention++

        switch ($state.HealthGroup) {
            'Dirty' { $summary.Dirty++ }
            'Behind' { $summary.Behind++ }
            'Ahead' { $summary.Ahead++ }
            'Diverged' { $summary.Diverged++ }
            'Upstream' { $summary.Upstream++ }
            'Detached' { $summary.Detached++ }
            'Conflicts' { $summary.Conflicts++ }
            'Operation' { $summary.Operation++ }
            'Remote' { $summary.Remote++ }
            default { $summary.Other++ }
        }
    }

    return $summary
}

function Get-RepositoryFilterDefinitions {
    <#
    .SYNOPSIS
        Filters offered by the Repository Health screen. Pure data.
    #>

    return @(
        [pscustomobject]@{ Key = '1'; Label = 'All repositories'; Filter = 'All' }
        [pscustomobject]@{ Key = '2'; Label = 'Repositories needing attention'; Filter = 'Attention' }
        [pscustomobject]@{ Key = '3'; Label = 'Modified repositories'; Filter = 'Dirty' }
        [pscustomobject]@{ Key = '4'; Label = 'Behind repositories'; Filter = 'Behind' }
        [pscustomobject]@{ Key = '5'; Label = 'Ahead repositories'; Filter = 'Ahead' }
        [pscustomobject]@{ Key = '6'; Label = 'Diverged repositories'; Filter = 'Diverged' }
        [pscustomobject]@{ Key = '7'; Label = 'Broken upstreams'; Filter = 'Upstream' }
        [pscustomobject]@{ Key = '8'; Label = 'Conflicts / operations in progress'; Filter = 'Blocked' }
    )
}

function Select-RepositoryStatesByFilter {
    <#
    .SYNOPSIS
        Applies a health filter to a set of repository states. Pure function.
    #>
    param(
        [AllowEmptyCollection()][array]$States = @(),
        [string]$Filter = 'All'
    )

    switch ($Filter) {
        'All' { return @($States) }
        'Attention' { return @($States | Where-Object { $_.NeedsAttention }) }
        'Dirty' { return @($States | Where-Object { $_.HealthGroup -eq 'Dirty' }) }
        'Behind' { return @($States | Where-Object { $_.HealthGroup -eq 'Behind' }) }
        'Ahead' { return @($States | Where-Object { $_.HealthGroup -eq 'Ahead' }) }
        'Diverged' { return @($States | Where-Object { $_.HealthGroup -eq 'Diverged' }) }
        'Upstream' { return @($States | Where-Object { $_.HealthGroup -eq 'Upstream' }) }
        'Blocked' { return @($States | Where-Object { $_.HealthGroup -eq 'Conflicts' -or $_.HealthGroup -eq 'Operation' }) }
        'Remote' { return @($States | Where-Object { $_.HealthGroup -eq 'Remote' }) }
        default { return @($States) }
    }
}
