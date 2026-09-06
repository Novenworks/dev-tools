# Repository intelligence — guided upstream repair and safe merged-branch cleanup.
#
# Safety contract: DevTools never force-deletes a branch, never deletes an
# unmerged branch, and never switches branches when local work could be lost.

# ---------------------------------------------------------------------------
# Upstream repair
# ---------------------------------------------------------------------------

function Get-RepositoryUnmergedCommitCount {
    <#
    .SYNOPSIS
        Counts commits on the current branch that are not reachable from a base ref.
    .DESCRIPTION
        Returns -1 when the answer cannot be determined, which the safety rules
        treat as "not provably safe".
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][string]$BaseRef
    )

    $result = Invoke-DevToolsGit -RepoPath $RepoPath -GitArgs @('rev-list', '--count', "$BaseRef..HEAD")

    if (-not $result.Success -or [string]::IsNullOrWhiteSpace($result.Output)) {
        return -1
    }

    $value = 0
    if ([int]::TryParse($result.Output.Trim(), [ref]$value)) {
        return $value
    }

    return -1
}

function Get-RepositoryComparisonRef {
    <#
    .SYNOPSIS
        Picks the best available ref for the default branch. Pure function.
    #>
    param(
        [Parameter(Mandatory = $true)]$State,
        [bool]$RemoteDefaultExists = $false,
        [bool]$LocalDefaultExists = $false
    )

    if ([string]::IsNullOrWhiteSpace($State.DefaultBranch)) {
        return ''
    }

    if ($RemoteDefaultExists -and -not [string]::IsNullOrWhiteSpace($State.RemoteName)) {
        return "refs/remotes/$($State.RemoteName)/$($State.DefaultBranch)"
    }

    if ($LocalDefaultExists) {
        return "refs/heads/$($State.DefaultBranch)"
    }

    return ''
}

function Get-UpstreamRepairSafety {
    <#
    .SYNOPSIS
        Decides whether switching to the default branch is safe. Pure function.
    .DESCRIPTION
        UnmergedCommits of -1 means "unknown", which is treated as unsafe.
    #>
    param(
        [Parameter(Mandatory = $true)]$State,
        [int]$UnmergedCommits = -1,
        [string]$ComparisonRef = ''
    )

    $blockers = @()

    if ($State.HealthCode -ne 'UpstreamGone' -and $State.HealthCode -ne 'MissingUpstream') {
        $blockers += 'This repository does not have a broken upstream to repair.'
    }

    if ($State.IsDetachedHead) {
        $blockers += 'This repository is not on a branch.'
    }

    if ($State.HasConflicts) {
        $blockers += 'Unresolved conflicts must be resolved first.'
    }

    if ($State.MergeInProgress -or $State.RebaseInProgress -or $State.CherryPickInProgress -or $State.RevertInProgress) {
        $blockers += 'A Git operation is still in progress.'
    }

    if ($State.IsDirty) {
        $blockers += 'The working tree has uncommitted changes. Commit or review them first.'
    }

    if ([string]::IsNullOrWhiteSpace($State.DefaultBranch)) {
        $blockers += 'DevTools could not determine the default branch.'
    }

    if ([string]::IsNullOrWhiteSpace($ComparisonRef)) {
        $blockers += 'DevTools could not find the default branch to compare against.'
    }

    if ($State.CurrentBranch -eq $State.DefaultBranch) {
        $blockers += 'This repository is already on the default branch.'
    }

    if ($UnmergedCommits -lt 0) {
        $blockers += 'DevTools could not confirm whether this branch has unmerged commits.'
    }
    elseif ($UnmergedCommits -gt 0) {
        $blockers += "This branch has $UnmergedCommits commit(s) that are not in $($State.DefaultBranch). Review them manually before switching."
    }

    return [pscustomobject]@{
        IsSafe          = ($blockers.Count -eq 0)
        Blockers        = @($blockers)
        UnmergedCommits = $UnmergedCommits
        ComparisonRef   = $ComparisonRef
    }
}

function Get-UpstreamRepairPlan {
    <#
    .SYNOPSIS
        Builds the guided repair plan for a repository with a broken upstream.
    #>
    param([Parameter(Mandatory = $true)]$State)

    $remoteDefaultExists = $false
    $localDefaultExists = $false

    if (-not [string]::IsNullOrWhiteSpace($State.DefaultBranch)) {
        if (-not [string]::IsNullOrWhiteSpace($State.RemoteName)) {
            $remoteDefaultExists = Test-RepositoryRefExists -RepoPath $State.Path -Ref "refs/remotes/$($State.RemoteName)/$($State.DefaultBranch)"
        }
        $localDefaultExists = Test-RepositoryRefExists -RepoPath $State.Path -Ref "refs/heads/$($State.DefaultBranch)"
    }

    $comparisonRef = Get-RepositoryComparisonRef -State $State -RemoteDefaultExists $remoteDefaultExists -LocalDefaultExists $localDefaultExists

    $unmerged = -1
    if (-not [string]::IsNullOrWhiteSpace($comparisonRef)) {
        $unmerged = Get-RepositoryUnmergedCommitCount -RepoPath $State.Path -BaseRef $comparisonRef
    }

    $safety = Get-UpstreamRepairSafety -State $State -UnmergedCommits $unmerged -ComparisonRef $comparisonRef

    $steps = @()
    if ($safety.IsSafe) {
        $steps += "Switch to $($State.DefaultBranch)."
        if ($remoteDefaultExists) {
            $steps += "Make sure $($State.DefaultBranch) tracks $($State.RemoteName)/$($State.DefaultBranch)."
            $steps += "Refresh and fast-forward $($State.DefaultBranch)."
        }
        $steps += "Leave $($State.CurrentBranch) in place. DevTools does not delete branches during repair."
    }

    return [pscustomobject]@{
        Name                = $State.Name
        Path                = $State.Path
        CurrentBranch       = $State.CurrentBranch
        Upstream            = $State.Upstream
        DefaultBranch       = $State.DefaultBranch
        RemoteName          = $State.RemoteName
        RemoteDefaultExists = $remoteDefaultExists
        LocalDefaultExists  = $localDefaultExists
        ComparisonRef       = $comparisonRef
        UnmergedCommits     = $unmerged
        CanRepair           = $safety.IsSafe
        Blockers            = @($safety.Blockers)
        Steps               = @($steps)
    }
}

function Invoke-UpstreamRepair {
    <#
    .SYNOPSIS
        Performs the safe part of upstream repair after the plan says it is safe.
    .DESCRIPTION
        Switches to the default branch, restores tracking when a remote branch
        exists, and fast-forwards. It never deletes the old branch, never
        discards changes, and re-verifies safety before mutating anything.
    #>
    param([Parameter(Mandatory = $true)]$Plan)

    $steps = @()

    if (-not $Plan.CanRepair) {
        return [pscustomobject]@{
            Success = $false
            Steps   = @()
            Error   = 'This repository is not safe to repair automatically.'
        }
    }

    # Re-verify against live facts so nothing changed since the plan was built.
    $facts = Get-RepositoryFacts -RepoPath $Plan.Path -Name $Plan.Name
    $state = Get-RepositoryState -Facts $facts

    if ($state.IsDirty -or $state.HasConflicts -or $state.IsDetachedHead) {
        return [pscustomobject]@{
            Success = $false
            Steps   = @()
            Error   = 'The repository changed since the plan was created. Repair was cancelled.'
        }
    }

    $checkout = Invoke-DevToolsGit -RepoPath $Plan.Path -GitArgs @('checkout', $Plan.DefaultBranch)

    if (-not $checkout.Success) {
        return [pscustomobject]@{
            Success = $false
            Steps   = @($steps)
            Error   = $checkout.Output
        }
    }

    $steps += "Switched to $($Plan.DefaultBranch)."

    if ($Plan.RemoteDefaultExists) {
        $upstreamRef = "$($Plan.RemoteName)/$($Plan.DefaultBranch)"
        $setUpstream = Invoke-DevToolsGit -RepoPath $Plan.Path -GitArgs @('branch', "--set-upstream-to=$upstreamRef", $Plan.DefaultBranch)

        if ($setUpstream.Success) {
            $steps += "$($Plan.DefaultBranch) now tracks $upstreamRef."
        }

        $fetch = Invoke-RepositoryFetch -RepoPath $Plan.Path -RemoteName $Plan.RemoteName

        if ($fetch.Success) {
            $steps += 'Refreshed remote state.'

            $afterFacts = Get-RepositoryFacts -RepoPath $Plan.Path -Name $Plan.Name
            $afterState = Get-RepositoryState -Facts $afterFacts

            if ($afterState.CanFastForward) {
                $merge = Invoke-RepositoryFastForward -RepoPath $Plan.Path -Upstream $afterState.Upstream

                if ($merge.Success) {
                    $steps += "Fast-forwarded $($Plan.DefaultBranch) by $($afterState.Behind) commit(s)."
                }
                else {
                    $steps += 'The fast-forward was skipped. Sync this repository later.'
                }
            }
        }
        else {
            $steps += 'Remote state could not be refreshed. Sync this repository later.'
        }
    }

    $steps += "$($Plan.CurrentBranch) is still on disk. Use Branch cleanup if you want to remove it."

    return [pscustomobject]@{
        Success = $true
        Steps   = @($steps)
        Error   = ''
    }
}

# ---------------------------------------------------------------------------
# Merged branch cleanup
# ---------------------------------------------------------------------------

function Test-BranchIsSafeToDelete {
    <#
    .SYNOPSIS
        The branch deletion safety rule. Pure function.
    .DESCRIPTION
        A branch is only safe to delete when Git can prove it is fully merged.
        Being stale, or having a deleted upstream, is never enough on its own.
    #>
    param([Parameter(Mandatory = $true)]$Candidate)

    if ($Candidate.IsCurrent) { return $false }
    if ($Candidate.IsProtected) { return $false }
    if (-not $Candidate.IsMerged) { return $false }

    return $true
}

function Get-BranchCleanupCandidates {
    <#
    .SYNOPSIS
        Lists local branches that are candidates for cleanup, with proof of merge.
    .DESCRIPTION
        Works for any branch naming scheme. Agent branches such as claude/*,
        cursor/*, or codex/* are matched by the same generic rules.
    #>
    param(
        [Parameter(Mandatory = $true)]$State,
        [string]$CompareRef = ''
    )

    if ([string]::IsNullOrWhiteSpace($CompareRef)) {
        $remoteDefaultExists = $false
        $localDefaultExists = $false

        if (-not [string]::IsNullOrWhiteSpace($State.DefaultBranch)) {
            if (-not [string]::IsNullOrWhiteSpace($State.RemoteName)) {
                $remoteDefaultExists = Test-RepositoryRefExists -RepoPath $State.Path -Ref "refs/remotes/$($State.RemoteName)/$($State.DefaultBranch)"
            }
            $localDefaultExists = Test-RepositoryRefExists -RepoPath $State.Path -Ref "refs/heads/$($State.DefaultBranch)"
        }

        $CompareRef = Get-RepositoryComparisonRef -State $State -RemoteDefaultExists $remoteDefaultExists -LocalDefaultExists $localDefaultExists
    }

    if ([string]::IsNullOrWhiteSpace($CompareRef)) {
        return @()
    }

    $protected = Get-ProtectedBranchNames -DefaultBranch $State.DefaultBranch

    $mergedResult = Invoke-DevToolsGit -RepoPath $State.Path -GitArgs @('for-each-ref', '--merged', $CompareRef, '--format=%(refname:short)', 'refs/heads')
    $mergedBranches = @()
    if ($mergedResult.Success) {
        $mergedBranches = @($mergedResult.Lines | ForEach-Object { $_.Trim() })
    }

    $listResult = Invoke-DevToolsGit -RepoPath $State.Path -GitArgs @('for-each-ref', '--format=%(refname:short)|%(upstream:short)|%(upstream:track)', 'refs/heads')

    if (-not $listResult.Success) {
        return @()
    }

    $candidates = @()

    foreach ($line in $listResult.Lines) {
        $parts = $line -split '\|', 3
        $branchName = $parts[0].Trim()

        if ([string]::IsNullOrWhiteSpace($branchName)) { continue }

        $upstream = ''
        if ($parts.Count -gt 1) { $upstream = $parts[1].Trim() }

        $track = ''
        if ($parts.Count -gt 2) { $track = $parts[2].Trim() }

        $hasUpstream = -not [string]::IsNullOrWhiteSpace($upstream)
        $upstreamGone = $hasUpstream -and ($track -match '(?i)gone')
        $isCurrent = ($branchName -eq $State.CurrentBranch)
        $isProtected = ($protected -contains $branchName)
        $isMerged = ($mergedBranches -contains $branchName)
        $isStale = (-not $isCurrent) -and (-not $isProtected) -and ($upstreamGone -or (-not $hasUpstream) -or $isMerged)

        if (-not $isStale) { continue }

        $candidate = [pscustomobject]@{
            Name         = $branchName
            Upstream     = $upstream
            HasUpstream  = $hasUpstream
            UpstreamGone = $upstreamGone
            IsMerged     = $isMerged
            IsCurrent    = $isCurrent
            IsProtected  = $isProtected
            SafeToDelete = $false
            Reason       = ''
        }

        $candidate.SafeToDelete = Test-BranchIsSafeToDelete -Candidate $candidate

        if ($candidate.SafeToDelete) {
            $candidate.Reason = "Fully merged into $($State.DefaultBranch)."
        }
        elseif ($upstreamGone) {
            $candidate.Reason = "Upstream $upstream is gone, but this branch has commits that are not in $($State.DefaultBranch)."
        }
        else {
            $candidate.Reason = "Not fully merged into $($State.DefaultBranch). Review manually."
        }

        $candidates += $candidate
    }

    return @($candidates | Sort-Object Name)
}

function Get-BranchCleanupSummary {
    param([AllowEmptyCollection()][array]$Candidates = @())

    $safe = @($Candidates | Where-Object { $_.SafeToDelete })

    return [pscustomobject]@{
        Total       = @($Candidates).Count
        SafeCount   = $safe.Count
        ReviewCount = (@($Candidates).Count - $safe.Count)
        SafeNames   = @($safe | ForEach-Object { $_.Name })
    }
}

function Remove-MergedBranches {
    <#
    .SYNOPSIS
        Deletes only provably merged branches, using safe deletion semantics.
    .DESCRIPTION
        Uses `git branch -d`, never `-D`. If Git refuses because a branch is not
        fully merged, DevTools reports it and moves on.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [AllowEmptyCollection()][array]$Candidates = @()
    )

    $results = @()

    foreach ($candidate in @($Candidates)) {
        if (-not (Test-BranchIsSafeToDelete -Candidate $candidate)) {
            $results += [pscustomobject]@{
                Name    = $candidate.Name
                Deleted = $false
                Reason  = 'Refused: this branch is not provably merged.'
            }
            continue
        }

        $delete = Invoke-DevToolsGit -RepoPath $RepoPath -GitArgs @('branch', '-d', $candidate.Name)

        if ($delete.Success) {
            $results += [pscustomobject]@{
                Name    = $candidate.Name
                Deleted = $true
                Reason  = 'Deleted.'
            }
        }
        else {
            $reason = 'Git refused to delete this branch.'
            if ($delete.ErrorCategory -eq 'NotMerged') {
                $reason = 'Refused: Git reports this branch is not fully merged.'
            }

            $results += [pscustomobject]@{
                Name    = $candidate.Name
                Deleted = $false
                Reason  = $reason
            }
        }
    }

    return @($results)
}
