# Repository intelligence - workspace collection and the safe synchronization engine.
#
# Safety contract for everything in this file:
#   no stash, no reset, no clean, no force, no commit, no push,
#   no merge commits, no rebase, no branch switching, no branch deletion.
# The only mutation is an explicit fast-forward of a clean, behind-only branch.

function Get-WorkspaceRepositoryStates {
    <#
    .SYNOPSIS
        Inspects every repository in the workspace and returns repository states.
    .PARAMETER Refresh
        Fetches and prunes each repository first so remote state is accurate.
        Required for sync; optional for a fast local health read.
    .PARAMETER OnProgress
        Optional scriptblock called as (index, total, name) so long runs never
        look frozen at workspace scale.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$WorkspacePath,
        [switch]$Refresh,
        [scriptblock]$OnProgress
    )

    $repos = @(Get-WorkspaceGitRepos -WorkspacePath $WorkspacePath)
    $states = @()
    $index = 0

    foreach ($repo in $repos) {
        $index++

        if ($OnProgress) {
            & $OnProgress $index $repos.Count $repo.Name
        }

        # A single failing repository must never terminate the batch.
        try {
            $facts = Get-RepositoryFacts -RepoPath $repo.FullName -Name $repo.Name -Refresh:$Refresh
            $states += Get-RepositoryState -Facts $facts
        }
        catch {
            $fallback = New-RepositoryFacts -Name $repo.Name -Path $repo.FullName
            $fallback.GitError = $_.Exception.Message
            $states += Get-RepositoryState -Facts $fallback
        }
    }

    return @($states)
}

function Get-RepositorySkipReason {
    <#
    .SYNOPSIS
        Turns a repository state into a short, actionable skip reason. Pure function.
    .DESCRIPTION
        DevTools never reports "Could not update" when it knows the real reason.
    #>
    param([Parameter(Mandatory = $true)]$State)

    switch ($State.HealthCode) {
        'LocalChanges' { return 'local changes' }
        'Ahead' { return 'local commits not pushed yet' }
        'Diverged' { return 'local and remote have diverged' }
        'UpstreamGone' {
            if (-not [string]::IsNullOrWhiteSpace($State.Upstream)) {
                return "$($State.Upstream) no longer exists"
            }
            return 'upstream no longer exists'
        }
        'MissingUpstream' { return 'no upstream branch is set' }
        'DetachedHead' { return 'not on a branch' }
        'Conflicts' { return 'unresolved conflicts' }
        'MergeInProgress' { return 'merge in progress' }
        'RebaseInProgress' { return 'rebase in progress' }
        'OperationInProgress' { return 'Git operation in progress' }
        'RemoteMissing' { return 'no remote configured' }
        'AuthenticationFailed' { return 'sign-in required' }
        'RemoteUnavailable' { return 'could not contact remote' }
        'FetchFailed' { return 'could not refresh remote state' }
        'InvalidRepository' { return 'not a Git repository' }
        default { return $State.HealthLabel.ToLower() }
    }
}

function New-RepositorySyncResult {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][ValidateSet('Updated', 'Current', 'Skipped', 'Failed')][string]$Outcome,
        [string]$Reason = '',
        [int]$CommitsPulled = 0,
        [string]$GitError = ''
    )

    return [pscustomobject]@{
        Name              = $State.Name
        Path              = $State.Path
        Branch            = $State.BranchDisplay
        State             = $State
        Outcome           = $Outcome
        Reason            = $Reason
        CommitsPulled     = $CommitsPulled
        GitError          = $GitError
        RecommendedAction = $State.RecommendedAction
    }
}

function Invoke-RepositoryFastForward {
    <#
    .SYNOPSIS
        Fast-forwards a repository to its upstream. Never creates a merge commit.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][string]$Upstream
    )

    return Invoke-DevToolsGit -RepoPath $RepoPath -GitArgs @('merge', '--ff-only', "refs/remotes/$Upstream")
}

function Invoke-RepositorySyncForState {
    <#
    .SYNOPSIS
        Applies the safe update policy to one already-refreshed repository state.
    #>
    param([Parameter(Mandatory = $true)]$State)

    if ($State.HealthCode -eq 'Current') {
        return New-RepositorySyncResult -State $State -Outcome 'Current'
    }

    if (-not $State.CanFastForward) {
        return New-RepositorySyncResult -State $State -Outcome 'Skipped' `
            -Reason (Get-RepositorySkipReason -State $State) `
            -GitError $State.FetchError
    }

    $behindBefore = $State.Behind
    $merge = Invoke-RepositoryFastForward -RepoPath $State.Path -Upstream $State.Upstream

    if (-not $merge.Success) {
        return New-RepositorySyncResult -State $State -Outcome 'Failed' `
            -Reason 'the fast-forward could not be completed' `
            -GitError $merge.Output
    }

    $updatedState = $State

    try {
        $facts = Get-RepositoryFacts -RepoPath $State.Path -Name $State.Name
        $facts.FetchAttempted = $State.FetchAttempted
        $facts.FetchSucceeded = $State.FetchSucceeded
        $facts.RemoteAvailable = $State.RemoteAvailable
        $updatedState = Get-RepositoryState -Facts $facts
    }
    catch {
        # Keep the pre-merge state if re-inspection fails; the merge already succeeded.
    }

    return New-RepositorySyncResult -State $updatedState -Outcome 'Updated' -CommitsPulled $behindBefore
}

function Invoke-RepositorySync {
    <#
    .SYNOPSIS
        Fetches, classifies, and safely fast-forwards every repository in a workspace.
    .DESCRIPTION
        FETCH -> INSPECT -> CLASSIFY -> SAFELY UPDATE -> REPORT.
        Unsafe repositories are skipped and explained, never modified.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$WorkspacePath,
        [scriptblock]$OnProgress,
        [scriptblock]$OnResult
    )

    $repos = @(Get-WorkspaceGitRepos -WorkspacePath $WorkspacePath)
    $results = @()
    $index = 0

    foreach ($repo in $repos) {
        $index++

        if ($OnProgress) {
            & $OnProgress $index $repos.Count $repo.Name
        }

        try {
            $facts = Get-RepositoryFacts -RepoPath $repo.FullName -Name $repo.Name -Refresh
            $state = Get-RepositoryState -Facts $facts
            $result = Invoke-RepositorySyncForState -State $state
        }
        catch {
            $fallback = New-RepositoryFacts -Name $repo.Name -Path $repo.FullName
            $fallback.GitError = $_.Exception.Message
            $fallbackState = Get-RepositoryState -Facts $fallback
            $result = New-RepositorySyncResult -State $fallbackState -Outcome 'Failed' `
                -Reason 'DevTools could not inspect this repository' `
                -GitError $_.Exception.Message
        }

        $results += $result

        if ($OnResult) {
            & $OnResult $result
        }
    }

    return @($results)
}

function Get-RepositorySyncSummary {
    <#
    .SYNOPSIS
        Categorized counts for the sync summary screen. Pure function.
    #>
    param([AllowEmptyCollection()][array]$Results = @())

    $states = @($Results | ForEach-Object { $_.State })
    $summary = Get-RepositoryStateSummary -States $states

    $updated = @($Results | Where-Object { $_.Outcome -eq 'Updated' }).Count
    $current = @($Results | Where-Object { $_.Outcome -eq 'Current' }).Count
    $failed = @($Results | Where-Object { $_.Outcome -eq 'Failed' }).Count

    return [ordered]@{
        Total          = @($Results).Count
        Updated        = $updated
        Current        = $current
        Dirty          = $summary.Dirty
        Ahead          = $summary.Ahead
        Diverged       = $summary.Diverged
        Upstream       = $summary.Upstream
        Detached       = $summary.Detached
        Conflicts      = $summary.Conflicts
        Operation      = $summary.Operation
        Remote         = $summary.Remote
        Other          = $summary.Other + $failed
        NeedsAttention = @($Results | Where-Object { $_.Outcome -eq 'Skipped' -or $_.Outcome -eq 'Failed' }).Count
    }
}

function Get-RepositorySyncAttentionResults {
    param([AllowEmptyCollection()][array]$Results = @())

    return @($Results | Where-Object { $_.Outcome -eq 'Skipped' -or $_.Outcome -eq 'Failed' })
}
