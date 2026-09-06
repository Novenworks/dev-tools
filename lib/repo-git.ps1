# Repository intelligence — Git invocation and raw fact acquisition.
#
# This module is the only place that runs Git for repository state. It returns
# raw facts. It never classifies, never renders UI, and never mutates history.

$script:DevToolsProtectedBranches = @('main', 'master', 'develop', 'trunk')

function New-GitResult {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [int]$ExitCode = 0,
        [string]$Output = '',
        [switch]$Invoked
    )

    return [pscustomobject]@{
        Command       = $Command
        ExitCode      = $ExitCode
        Success       = ($ExitCode -eq 0)
        Output        = $Output
        Lines         = @($Output -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        ErrorCategory = (Get-GitErrorCategory -Output $Output -ExitCode $ExitCode)
        Invoked       = [bool]$Invoked
    }
}

function Get-GitErrorCategory {
    <#
    .SYNOPSIS
        Normalizes Git failure output into a stable category. Pure function.
    #>
    param(
        [string]$Output = '',
        [int]$ExitCode = 0
    )

    if ($ExitCode -eq 0) {
        return 'None'
    }

    if ([string]::IsNullOrWhiteSpace($Output)) {
        return 'Unknown'
    }

    $text = $Output

    if ($text -match '(?i)(authentication failed|could not read Username|could not read Password|Permission denied \(publickey\)|terminal prompts disabled|invalid username or password|HTTP Basic: Access denied|403 Forbidden|Support for password authentication was removed)') {
        return 'Authentication'
    }

    if ($text -match '(?i)(could not resolve host|unable to access|connection timed out|connection refused|network is unreachable|failed to connect|operation timed out|ssl certificate problem|proxy)') {
        return 'Network'
    }

    if ($text -match '(?i)(repository not found|does not appear to be a git repository|remote branch .* not found|couldn''t find remote ref|no such remote)') {
        return 'RemoteMissing'
    }

    if ($text -match '(?i)(not possible to fast-forward|refusing to merge unrelated histories|divergent branches)') {
        return 'NotFastForward'
    }

    if ($text -match '(?i)(local changes .* would be overwritten|your local changes|please commit your changes|untracked working tree files would be overwritten)') {
        return 'LocalChanges'
    }

    if ($text -match '(?i)(is not fully merged)') {
        return 'NotMerged'
    }

    return 'Unknown'
}

function Invoke-DevToolsGit {
    <#
    .SYNOPSIS
        Runs Git against a repository path and returns a normalized result model.
    .DESCRIPTION
        Never throws. Captures combined output so callers can classify errors and
        surface a concise message without exposing raw Git noise by default.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][string[]]$GitArgs,
        [int]$TimeoutSeconds = 0
    )

    $allArgs = @('-C', $RepoPath) + $GitArgs
    $display = 'git ' + ($GitArgs -join ' ')

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    try {
        $raw = & git @allArgs 2>&1
        $exitCode = $LASTEXITCODE
        $text = (@($raw) | ForEach-Object { "$_" }) -join [Environment]::NewLine
    }
    catch {
        $exitCode = 1
        $text = $_.Exception.Message
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if ($null -eq $exitCode) { $exitCode = 0 }

    return New-GitResult -Command $display -ExitCode $exitCode -Output ($text.Trim()) -Invoked
}

function Get-SanitizedRemoteUrl {
    <#
    .SYNOPSIS
        Removes embedded credentials from a remote URL so reports never leak tokens.
    #>
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return ''
    }

    $clean = $Url.Trim()

    # https://user:token@host/... and https://token@host/...
    $clean = [regex]::Replace($clean, '(?i)^(https?://)([^/@]+)@', '$1')

    # ssh://user:password@host/...
    $clean = [regex]::Replace($clean, '(?i)^(ssh://)([^/@]*:[^/@]*)@', '$1')

    return $clean
}

function Get-RepositoryOperationState {
    <#
    .SYNOPSIS
        Detects in-progress Git operations from files inside the Git directory.
    #>
    param([string]$GitDirectory)

    $state = [pscustomobject]@{
        MergeInProgress      = $false
        RebaseInProgress     = $false
        CherryPickInProgress = $false
        RevertInProgress     = $false
        BisectInProgress     = $false
    }

    if ([string]::IsNullOrWhiteSpace($GitDirectory) -or -not (Test-Path -LiteralPath $GitDirectory)) {
        return $state
    }

    $state.MergeInProgress = Test-Path -LiteralPath (Join-Path $GitDirectory 'MERGE_HEAD')
    $state.RebaseInProgress = (Test-Path -LiteralPath (Join-Path $GitDirectory 'rebase-merge')) -or
                              (Test-Path -LiteralPath (Join-Path $GitDirectory 'rebase-apply'))
    $state.CherryPickInProgress = Test-Path -LiteralPath (Join-Path $GitDirectory 'CHERRY_PICK_HEAD')
    $state.RevertInProgress = Test-Path -LiteralPath (Join-Path $GitDirectory 'REVERT_HEAD')
    $state.BisectInProgress = Test-Path -LiteralPath (Join-Path $GitDirectory 'BISECT_LOG')

    return $state
}

function ConvertFrom-GitPorcelainV2 {
    <#
    .SYNOPSIS
        Parses `git status --porcelain=v2 --branch` output into structured facts.
    .DESCRIPTION
        Pure function. Porcelain v2 is stable and locale-independent, so DevTools
        does not parse human-readable Git prose.
    #>
    param([string[]]$Lines = @())

    $result = [pscustomobject]@{
        Head                = ''
        Branch              = ''
        IsDetachedHead      = $false
        Upstream            = ''
        HasUpstreamConfig   = $false
        HasAheadBehind      = $false
        Ahead               = 0
        Behind              = 0
        ModifiedFilesCount  = 0
        UntrackedFilesCount = 0
        ConflictFilesCount  = 0
    }

    foreach ($line in @($Lines)) {
        if ($null -eq $line) { continue }

        if ($line.StartsWith('# branch.oid ')) {
            $result.Head = $line.Substring(13).Trim()
            continue
        }

        if ($line.StartsWith('# branch.head ')) {
            $head = $line.Substring(14).Trim()
            if ($head -eq '(detached)') {
                $result.IsDetachedHead = $true
                $result.Branch = ''
            }
            else {
                $result.Branch = $head
            }
            continue
        }

        if ($line.StartsWith('# branch.upstream ')) {
            $result.Upstream = $line.Substring(18).Trim()
            $result.HasUpstreamConfig = -not [string]::IsNullOrWhiteSpace($result.Upstream)
            continue
        }

        if ($line.StartsWith('# branch.ab ')) {
            $ab = $line.Substring(12).Trim()
            if ($ab -match '^\+(\d+)\s+-(\d+)$') {
                $result.HasAheadBehind = $true
                $result.Ahead = [int]$Matches[1]
                $result.Behind = [int]$Matches[2]
            }
            continue
        }

        if ($line.StartsWith('#')) { continue }

        if ($line.StartsWith('? ')) {
            $result.UntrackedFilesCount++
            continue
        }

        if ($line.StartsWith('u ')) {
            $result.ConflictFilesCount++
            continue
        }

        if ($line.StartsWith('1 ') -or $line.StartsWith('2 ')) {
            $result.ModifiedFilesCount++
            continue
        }
    }

    return $result
}

function Get-RepositoryRemotes {
    <#
    .SYNOPSIS
        Returns remote names and fetch URLs from a single `git remote -v` call.
    #>
    param([Parameter(Mandatory = $true)][string]$RepoPath)

    $result = Invoke-DevToolsGit -RepoPath $RepoPath -GitArgs @('remote', '-v')
    $remotes = [ordered]@{}

    if (-not $result.Success) {
        return $remotes
    }

    foreach ($line in $result.Lines) {
        if ($line -match '^(\S+)\s+(\S+)\s+\(fetch\)$') {
            $remotes[$Matches[1]] = $Matches[2]
        }
    }

    return $remotes
}

function Select-PreferredRemoteName {
    <#
    .SYNOPSIS
        Chooses which remote DevTools treats as authoritative. Pure function.
    #>
    param($Remotes)

    if (-not $Remotes) { return '' }

    $names = @($Remotes.Keys)
    if ($names.Count -eq 0) { return '' }

    if ($names -contains 'origin') { return 'origin' }

    return $names[0]
}

function Get-RepositoryDefaultBranch {
    <#
    .SYNOPSIS
        Resolves the repository's default branch without guessing when Git knows.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [string]$RemoteName = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($RemoteName)) {
        $symbolic = Invoke-DevToolsGit -RepoPath $RepoPath -GitArgs @('symbolic-ref', '--quiet', '--short', "refs/remotes/$RemoteName/HEAD")
        if ($symbolic.Success -and -not [string]::IsNullOrWhiteSpace($symbolic.Output)) {
            $value = $symbolic.Output.Trim()
            $prefix = "$RemoteName/"
            if ($value.StartsWith($prefix)) {
                return $value.Substring($prefix.Length)
            }
            return $value
        }

        foreach ($candidate in @('main', 'master')) {
            $probe = Invoke-DevToolsGit -RepoPath $RepoPath -GitArgs @('rev-parse', '--verify', '--quiet', "refs/remotes/$RemoteName/$candidate")
            if ($probe.Success -and -not [string]::IsNullOrWhiteSpace($probe.Output)) {
                return $candidate
            }
        }
    }

    foreach ($candidate in @('main', 'master')) {
        $probe = Invoke-DevToolsGit -RepoPath $RepoPath -GitArgs @('rev-parse', '--verify', '--quiet', "refs/heads/$candidate")
        if ($probe.Success -and -not [string]::IsNullOrWhiteSpace($probe.Output)) {
            return $candidate
        }
    }

    $configured = Invoke-DevToolsGit -RepoPath $RepoPath -GitArgs @('config', '--get', 'init.defaultBranch')
    if ($configured.Success -and -not [string]::IsNullOrWhiteSpace($configured.Output)) {
        return $configured.Output.Trim()
    }

    return ''
}

function Test-RepositoryRefExists {
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][string]$Ref
    )

    $result = Invoke-DevToolsGit -RepoPath $RepoPath -GitArgs @('rev-parse', '--verify', '--quiet', $Ref)
    return ($result.Success -and -not [string]::IsNullOrWhiteSpace($result.Output))
}

function Invoke-RepositoryFetch {
    <#
    .SYNOPSIS
        Refreshes remote state with a conservative, read-only fetch.
    .DESCRIPTION
        `--prune` removes local remote-tracking refs whose remote branch was deleted.
        This never modifies the working tree, local branches, or history.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [string]$RemoteName = ''
    )

    $gitArgs = @('fetch', '--prune', '--quiet')
    if (-not [string]::IsNullOrWhiteSpace($RemoteName)) {
        $gitArgs += $RemoteName
    }

    return Invoke-DevToolsGit -RepoPath $RepoPath -GitArgs $gitArgs
}

function New-RepositoryFacts {
    <#
    .SYNOPSIS
        Creates an empty repository facts object. Used by acquisition and by tests.
    #>
    param(
        [string]$Name = '',
        [string]$Path = ''
    )

    return [pscustomobject]@{
        Name                 = $Name
        Path                 = $Path
        IsGitRepository      = $false
        GitDirectory         = ''
        Head                 = ''
        CurrentBranch        = ''
        IsDetachedHead       = $false
        DefaultBranch        = ''
        RemoteName           = ''
        RemoteUrl            = ''
        HasRemote            = $false
        Upstream             = ''
        UpstreamConfigured   = $false
        UpstreamExists       = $false
        RemoteBranchExists   = $false
        IsDirty              = $false
        ModifiedFilesCount   = 0
        UntrackedFilesCount  = 0
        HasConflicts         = $false
        ConflictFilesCount   = 0
        MergeInProgress      = $false
        RebaseInProgress     = $false
        CherryPickInProgress = $false
        RevertInProgress     = $false
        BisectInProgress     = $false
        Ahead                = 0
        Behind               = 0
        IsDiverged           = $false
        FetchAttempted       = $false
        FetchSucceeded       = $false
        FetchError           = ''
        FetchErrorCategory   = 'None'
        RemoteAvailable      = $false
        GitError             = ''
    }
}

function Get-RepositoryFacts {
    <#
    .SYNOPSIS
        Gathers raw repository facts for one repository.
    .PARAMETER Refresh
        When set, runs `git fetch --prune` first so ahead/behind and upstream
        existence reflect the real remote instead of stale local refs.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [string]$Name = '',
        [switch]$Refresh
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = Split-Path -Path $RepoPath -Leaf
    }

    $facts = New-RepositoryFacts -Name $Name -Path $RepoPath

    if (-not (Test-Path -LiteralPath $RepoPath)) {
        $facts.GitError = 'The repository folder no longer exists.'
        return $facts
    }

    $gitDirResult = Invoke-DevToolsGit -RepoPath $RepoPath -GitArgs @('rev-parse', '--absolute-git-dir')

    if (-not $gitDirResult.Success -or [string]::IsNullOrWhiteSpace($gitDirResult.Output)) {
        $facts.GitError = $gitDirResult.Output
        return $facts
    }

    $facts.IsGitRepository = $true
    $facts.GitDirectory = $gitDirResult.Output.Trim()

    $operation = Get-RepositoryOperationState -GitDirectory $facts.GitDirectory
    $facts.MergeInProgress = $operation.MergeInProgress
    $facts.RebaseInProgress = $operation.RebaseInProgress
    $facts.CherryPickInProgress = $operation.CherryPickInProgress
    $facts.RevertInProgress = $operation.RevertInProgress
    $facts.BisectInProgress = $operation.BisectInProgress

    $remotes = Get-RepositoryRemotes -RepoPath $RepoPath
    $facts.RemoteName = Select-PreferredRemoteName -Remotes $remotes
    $facts.HasRemote = -not [string]::IsNullOrWhiteSpace($facts.RemoteName)

    if ($facts.HasRemote) {
        $facts.RemoteUrl = Get-SanitizedRemoteUrl -Url $remotes[$facts.RemoteName]
    }

    if ($Refresh -and $facts.HasRemote) {
        $facts.FetchAttempted = $true
        $fetch = Invoke-RepositoryFetch -RepoPath $RepoPath -RemoteName $facts.RemoteName
        $facts.FetchSucceeded = $fetch.Success
        $facts.RemoteAvailable = $fetch.Success

        if (-not $fetch.Success) {
            $facts.FetchError = $fetch.Output
            $facts.FetchErrorCategory = $fetch.ErrorCategory
        }
    }

    $status = Invoke-DevToolsGit -RepoPath $RepoPath -GitArgs @('status', '--porcelain=v2', '--branch', '--untracked-files=normal')

    if (-not $status.Success) {
        $facts.GitError = $status.Output
        return $facts
    }

    $parsed = ConvertFrom-GitPorcelainV2 -Lines $status.Lines

    $facts.Head = $parsed.Head
    $facts.CurrentBranch = $parsed.Branch
    $facts.IsDetachedHead = $parsed.IsDetachedHead
    $facts.Upstream = $parsed.Upstream
    $facts.UpstreamConfigured = $parsed.HasUpstreamConfig
    $facts.Ahead = $parsed.Ahead
    $facts.Behind = $parsed.Behind
    $facts.ModifiedFilesCount = $parsed.ModifiedFilesCount
    $facts.UntrackedFilesCount = $parsed.UntrackedFilesCount
    $facts.ConflictFilesCount = $parsed.ConflictFilesCount
    $facts.HasConflicts = ($parsed.ConflictFilesCount -gt 0)
    $facts.IsDirty = ($parsed.ModifiedFilesCount -gt 0) -or ($parsed.UntrackedFilesCount -gt 0) -or $facts.HasConflicts
    $facts.IsDiverged = ($parsed.Ahead -gt 0 -and $parsed.Behind -gt 0)

    if ($facts.UpstreamConfigured) {
        # Git omits `branch.ab` when the upstream ref cannot be resolved, which is
        # exactly the deleted-remote-branch case. Verify before trusting it.
        if ($parsed.HasAheadBehind) {
            $facts.UpstreamExists = $true
        }
        else {
            $facts.UpstreamExists = Test-RepositoryRefExists -RepoPath $RepoPath -Ref "refs/remotes/$($facts.Upstream)"
        }
    }

    $facts.DefaultBranch = Get-RepositoryDefaultBranch -RepoPath $RepoPath -RemoteName $facts.RemoteName

    if ($facts.HasRemote -and -not [string]::IsNullOrWhiteSpace($facts.DefaultBranch)) {
        $facts.RemoteBranchExists = Test-RepositoryRefExists -RepoPath $RepoPath -Ref "refs/remotes/$($facts.RemoteName)/$($facts.DefaultBranch)"
    }

    return $facts
}

function Get-ProtectedBranchNames {
    param([string]$DefaultBranch = '')

    $names = @($script:DevToolsProtectedBranches)

    if (-not [string]::IsNullOrWhiteSpace($DefaultBranch) -and $names -notcontains $DefaultBranch) {
        $names += $DefaultBranch
    }

    return $names
}
