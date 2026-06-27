function Get-RepoStatusDetails {
    <#
    .SYNOPSIS
        Returns branch, change, sync, and conflict details for a repository.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    Push-Location $RepoPath
    try {
        $branch = git branch --show-current 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($branch)) {
            $branch = '(unknown)'
        }
        else {
            $branch = $branch.Trim()
        }

        $porcelain = git status --porcelain 2>$null
        $isModified = [bool]$porcelain
        $hasConflicts = [bool](git diff --name-only --diff-filter=U 2>$null)

        $ahead = 0
        $behind = 0
        $statusLine = git status -sb 2>$null | Select-Object -First 1

        if ($statusLine -match 'ahead (\d+)') {
            $ahead = [int]$Matches[1]
        }

        if ($statusLine -match 'behind (\d+)') {
            $behind = [int]$Matches[1]
        }

        if ($hasConflicts) {
            $displayStatus = 'Conflicts'
        }
        elseif ($isModified) {
            $displayStatus = 'Modified'
        }
        elseif ($ahead -gt 0 -and $behind -gt 0) {
            $displayStatus = 'Ahead, Behind'
        }
        elseif ($ahead -gt 0) {
            $displayStatus = 'Ahead'
        }
        elseif ($behind -gt 0) {
            $displayStatus = 'Behind'
        }
        else {
            $displayStatus = 'Clean'
        }

        return [pscustomobject]@{
            Name          = Split-Path $RepoPath -Leaf
            Branch        = $branch
            IsModified    = $isModified
            IsClean       = -not $isModified -and -not $hasConflicts -and $ahead -eq 0 -and $behind -eq 0
            Ahead         = $ahead
            Behind        = $behind
            HasConflicts  = $hasConflicts
            DisplayStatus = $displayStatus
        }
    }
    finally {
        Pop-Location
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
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    Push-Location $RepoPath
    try {
        $output = git pull 2>&1 | Out-String
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = $output
        }
    }
    finally {
        Pop-Location
    }
}
