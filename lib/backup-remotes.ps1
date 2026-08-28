# Redundant backup — provider-agnostic git remote helpers.
#
# This file never knows about GitLab or Bitbucket. It only knows how to
# detect, add, and push to a git remote by name. Provider-specific URL
# construction lives in lib/backup-setup.ps1.

function Get-GitRemoteUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath,

        [Parameter(Mandatory = $true)]
        [string]$RemoteName
    )

    Push-Location $RepoPath
    try {
        $url = git remote get-url $RemoteName 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($url)) {
            return $null
        }

        return $url.Trim()
    }
    finally {
        Pop-Location
    }
}

function Test-GitRemoteExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath,

        [Parameter(Mandatory = $true)]
        [string]$RemoteName
    )

    return $null -ne (Get-GitRemoteUrl -RepoPath $RepoPath -RemoteName $RemoteName)
}

function Add-GitRemote {
    <#
    .SYNOPSIS
        Adds a git remote, or updates its URL if a remote by that name already exists.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath,

        [Parameter(Mandatory = $true)]
        [string]$RemoteName,

        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    Push-Location $RepoPath
    try {
        if (Test-GitRemoteExists -RepoPath $RepoPath -RemoteName $RemoteName) {
            $null = git remote set-url $RemoteName $Url 2>&1 | Out-String
        }
        else {
            $null = git remote add $RemoteName $Url 2>&1 | Out-String
        }

        return ($LASTEXITCODE -eq 0)
    }
    finally {
        Pop-Location
    }
}

function Invoke-GitPushToRemote {
    <#
    .SYNOPSIS
        Pushes the current branch to a named remote, tracking it on first push.
    .DESCRIPTION
        Never throws — returns a result object so a failure on one remote or
        repository can never abort a multi-repo, multi-remote backup run.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath,

        [Parameter(Mandatory = $true)]
        [string]$RemoteName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Branch
    )

    if ([string]::IsNullOrWhiteSpace($Branch)) {
        return [pscustomobject]@{ Success = $false; ExitCode = -1; Reason = 'detached-head' }
    }

    Push-Location $RepoPath
    try {
        $output = git push -u $RemoteName $Branch 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        return [pscustomobject]@{ Success = ($exitCode -eq 0); ExitCode = $exitCode; Reason = $null; Output = $output }
    }
    catch {
        return [pscustomobject]@{ Success = $false; ExitCode = -1; Reason = $_.Exception.Message; Output = $null }
    }
    finally {
        Pop-Location
    }
}

function Invoke-GitBackupPush {
    <#
    .SYNOPSIS
        Pushes all branches and tags to the secondary backup remote.
    .DESCRIPTION
        A full mirror of history (not just the current branch), without using
        "git push --mirror" — that would also prune remote refs and copy
        DevTools' own local-only branches, which is more than a backup needs.
        The two pushes are tracked together as a single secondary result.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath,

        [Parameter(Mandatory = $true)]
        [string]$RemoteName
    )

    Push-Location $RepoPath
    try {
        $null = git push $RemoteName --all 2>&1 | Out-String
        $branchesExit = $LASTEXITCODE

        $null = git push $RemoteName --tags 2>&1 | Out-String
        $tagsExit = $LASTEXITCODE

        $success = ($branchesExit -eq 0) -and ($tagsExit -eq 0)
        return [pscustomobject]@{
            Success    = $success
            BranchesOk = ($branchesExit -eq 0)
            TagsOk     = ($tagsExit -eq 0)
        }
    }
    catch {
        return [pscustomobject]@{ Success = $false; BranchesOk = $false; TagsOk = $false }
    }
    finally {
        Pop-Location
    }
}

function Get-WorkspaceBackupSummary {
    <#
    .SYNOPSIS
        Returns per-repo backup-remote state for "dev backup status" and doctor.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath,

        [string]$RemoteName = 'backup'
    )

    $repos = Get-WorkspaceGitRepos -WorkspacePath $WorkspacePath
    $rows = @()

    foreach ($repo in $repos) {
        $backupUrl = Get-GitRemoteUrl -RepoPath $repo.FullName -RemoteName $RemoteName
        $rows += [pscustomobject]@{
            Name        = $repo.Name
            HasOrigin   = (Test-GitRemoteExists -RepoPath $repo.FullName -RemoteName 'origin')
            HasBackup   = ($null -ne $backupUrl)
            BackupUrl   = $backupUrl
        }
    }

    return $rows
}
