function Get-RepoStatusDetails {
    <#
    .SYNOPSIS
        Returns branch, change, sync, and conflict details for a repository.
    .DESCRIPTION
        Backward-compatible shape kept for existing callers. It is now a thin
        projection of the shared repository state model in lib/repo-state.ps1,
        so DevTools has one source of truth for repository status.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    $facts = Get-RepositoryFacts -RepoPath $RepoPath
    $state = Get-RepositoryState -Facts $facts

    $displayStatus = $state.HealthLabel

    if ($state.HealthCode -eq 'LocalChanges') {
        $displayStatus = 'Modified'
    }
    elseif ($state.HealthCode -eq 'Current') {
        $displayStatus = 'Clean'
    }
    elseif ($state.HealthCode -eq 'Diverged') {
        $displayStatus = 'Ahead, Behind'
    }

    $branch = $state.CurrentBranch
    if ([string]::IsNullOrWhiteSpace($branch)) {
        $branch = '(unknown)'
    }

    return [pscustomobject]@{
        Name          = $state.Name
        Branch        = $branch
        IsModified    = $state.IsDirty
        IsClean       = ($state.HealthCode -eq 'Current')
        Ahead         = $state.Ahead
        Behind        = $state.Behind
        HasConflicts  = $state.HasConflicts
        DisplayStatus = $displayStatus
        State         = $state
    }
}

function Test-RequireGit {
    if (-not (Test-CommandExists 'git')) {
        ShowError 'Git is not installed yet. Run Doctor to check your setup.'
        ShowInfo 'Next step: dev doctor'
        return $false
    }

    return $true
}

function Get-WorkspaceGitRepos {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath
    )

    if (-not (Test-Path $WorkspacePath)) {
        return @()
    }

    return Get-ChildItem -Path $WorkspacePath -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName '.git') } |
        Sort-Object Name
}

function Get-RepoBranch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    return (Get-RepoStatusDetails -RepoPath $RepoPath).Branch
}

function Get-RepoHasChanges {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    return (Get-RepoStatusDetails -RepoPath $RepoPath).IsModified
}

function Get-ChangedWorkspaceRepos {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath
    )

    $repos = Get-WorkspaceGitRepos -WorkspacePath $WorkspacePath
    $changed = @()

    foreach ($repo in $repos) {
        if (Get-RepoHasChanges -RepoPath $repo.FullName) {
            $changed += $repo
        }
    }

    return $changed
}

function Test-GitPullAlreadyCurrent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Output
    )

    return ($Output -match 'Already up to date')
}

function Invoke-GitPullWithOutput {
    <#
    .SYNOPSIS
        Fast-forward-only pull for a single repository.
    .DESCRIPTION
        Kept for backward compatibility. It never creates a merge commit and
        never rewrites history: DevTools bulk updates are fast-forward only.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    $result = Invoke-DevToolsGit -RepoPath $RepoPath -GitArgs @('pull', '--ff-only')

    return [pscustomobject]@{
        ExitCode = $result.ExitCode
        Output   = $result.Output
    }
}
