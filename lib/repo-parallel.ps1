# Repository intelligence - parallel remote refresh.
#
# Only the fetch phase runs in parallel. Fetching is network-bound and dominates
# the wall-clock time of a large workspace sync; inspection, classification and
# the fast-forward itself stay single-threaded on the calling thread, so every
# safety rule in repo-sync.ps1 and repo-state.ps1 is unchanged.
#
# `git fetch --prune` is read-only: it updates remote-tracking refs and drops
# refs whose remote branch was deleted. It never touches the working tree,
# local branches, or history. Running several at once is therefore safe, and
# each repository is still fetched exactly once.
#
# Runspaces are used rather than ForEach-Object -Parallel because DevTools
# supports Windows PowerShell 5.1, where -Parallel does not exist.

$script:DevToolsDefaultSyncConcurrency = 8
$script:DevToolsMinSyncConcurrency = 1
$script:DevToolsMaxSyncConcurrency = 32

function Get-RepositorySyncConcurrency {
    <#
    .SYNOPSIS
        Resolves how many repositories may be fetched at once. Pure function.
    .DESCRIPTION
        Reads the optional top-level "syncConcurrency" setting. Configs written
        before this shipped have no such key and fall back to the default.
        A value of 1 makes sync fully sequential, which is a useful escape hatch
        on a slow or rate-limited connection.
    #>
    param(
        $ConfigObject,
        [int]$Default = 0
    )

    if ($Default -le 0) {
        $Default = $script:DevToolsDefaultSyncConcurrency
    }

    $value = $null

    if ($ConfigObject -and $ConfigObject.PSObject.Properties.Name -contains 'syncConcurrency') {
        $value = $ConfigObject.syncConcurrency
    }

    if ($null -eq $value -or [string]::IsNullOrWhiteSpace("$value")) {
        return $Default
    }

    $parsed = 0
    if (-not [int]::TryParse("$value", [ref]$parsed)) {
        return $Default
    }

    if ($parsed -lt $script:DevToolsMinSyncConcurrency) {
        return $script:DevToolsMinSyncConcurrency
    }

    if ($parsed -gt $script:DevToolsMaxSyncConcurrency) {
        return $script:DevToolsMaxSyncConcurrency
    }

    return $parsed
}

function New-RepositoryFetchTarget {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$RemoteName = ''
    )

    return [pscustomobject]@{
        Name       = $Name
        Path       = $Path
        RemoteName = $RemoteName
    }
}

function Get-RepositoryFetchTargets {
    <#
    .SYNOPSIS
        Resolves which repositories have a remote worth fetching.
    .DESCRIPTION
        Remote selection stays on the calling thread and keeps using
        Select-PreferredRemoteName, so the parallel phase never re-implements
        the rule for which remote DevTools treats as authoritative.
    #>
    param([AllowEmptyCollection()][array]$Repositories = @())

    $targets = @()

    foreach ($repo in @($Repositories)) {
        try {
            $remotes = Get-RepositoryRemotes -RepoPath $repo.FullName
            $remoteName = Select-PreferredRemoteName -Remotes $remotes
        }
        catch {
            $remoteName = ''
        }

        if ([string]::IsNullOrWhiteSpace($remoteName)) {
            # No remote means nothing to fetch. The repository is still
            # inspected and classified later as "No remote".
            continue
        }

        $targets += New-RepositoryFetchTarget -Name $repo.Name -Path $repo.FullName -RemoteName $remoteName
    }

    return @($targets)
}

function Get-ParallelFetchScriptBlock {
    <#
    .SYNOPSIS
        The work each runspace performs: one fetch, for one repository.
    .DESCRIPTION
        Deliberately self-contained. It calls git directly rather than any
        DevTools function, so no module state has to be copied into runspaces
        and the parallel path cannot drift from the sequential one.
    #>

    return {
        param($RepoPath, $RemoteName)

        $gitArgs = @('-C', $RepoPath, 'fetch', '--prune', '--quiet')
        if (-not [string]::IsNullOrWhiteSpace($RemoteName)) {
            $gitArgs += $RemoteName
        }

        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'

        try {
            $raw = & git @gitArgs 2>&1
            $exitCode = $LASTEXITCODE
            $text = (@($raw) | ForEach-Object { "$_" }) -join [Environment]::NewLine
        }
        catch {
            $exitCode = 1
            $text = $_.Exception.Message
        }
        finally {
            $ErrorActionPreference = $previous
        }

        if ($null -eq $exitCode) { $exitCode = 0 }

        return [pscustomobject]@{
            ExitCode = $exitCode
            Output   = "$text".Trim()
        }
    }
}

function New-FetchOutcome {
    <#
    .SYNOPSIS
        Shapes a raw fetch result like Invoke-DevToolsGit does, so callers can
        consume parallel and sequential fetches identically.
    #>
    param(
        [int]$ExitCode = 0,
        [string]$Output = ''
    )

    return New-GitResult -Command 'git fetch --prune' -ExitCode $ExitCode -Output $Output -Invoked
}

function Invoke-SequentialGitFetch {
    <#
    .SYNOPSIS
        Fetch every target one at a time. Used when concurrency is 1 and as the
        fallback if a runspace pool cannot be created.
    #>
    param(
        [AllowEmptyCollection()][array]$Targets = @(),
        [scriptblock]$OnProgress
    )

    $results = @{}
    $index = 0
    $total = @($Targets).Count

    foreach ($target in @($Targets)) {
        $index++

        if ($OnProgress) {
            # Suppressed: a caller's progress output must not end up in the
            # hashtable this function returns.
            $null = & $OnProgress $index $total $target.Name
        }

        $results[$target.Path] = Invoke-RepositoryFetch -RepoPath $target.Path -RemoteName $target.RemoteName
    }

    return , $results
}

function Invoke-ParallelGitFetch {
    <#
    .SYNOPSIS
        Refreshes many repositories at once and returns one fetch result per path.
    .DESCRIPTION
        Returns a hashtable keyed by repository path. A repository whose fetch
        fails gets a failed result like any other; one failure never affects the
        rest of the batch, and the caller still classifies every repository.
    .PARAMETER ThrottleLimit
        Maximum simultaneous fetches. 1 runs sequentially.
    #>
    param(
        [AllowEmptyCollection()][array]$Targets = @(),
        [int]$ThrottleLimit = 0,
        [scriptblock]$OnProgress
    )

    $total = @($Targets).Count

    if ($total -eq 0) {
        return @{}
    }

    if ($ThrottleLimit -le 0) {
        $ThrottleLimit = $script:DevToolsDefaultSyncConcurrency
    }

    if ($ThrottleLimit -le 1 -or $total -eq 1) {
        return Invoke-SequentialGitFetch -Targets $Targets -OnProgress $OnProgress
    }

    $pool = $null

    try {
        $pool = [runspacefactory]::CreateRunspacePool(1, $ThrottleLimit)
        $pool.Open()
    }
    catch {
        # A host that cannot open a runspace pool still gets a correct sync,
        # just a slower one.
        if ($pool) { try { $pool.Dispose() } catch { Write-Verbose "Pool dispose failed: $($_.Exception.Message)" } }
        return Invoke-SequentialGitFetch -Targets $Targets -OnProgress $OnProgress
    }

    $script = Get-ParallelFetchScriptBlock
    $jobs = @()
    $results = @{}

    try {
        foreach ($target in @($Targets)) {
            $shell = [powershell]::Create()
            $shell.RunspacePool = $pool
            $null = $shell.AddScript($script).AddArgument($target.Path).AddArgument($target.RemoteName)

            $jobs += [pscustomobject]@{
                Target   = $target
                Shell    = $shell
                Handle   = $shell.BeginInvoke()
                Finished = $false
            }
        }

        $completed = 0

        while ($completed -lt $jobs.Count) {
            $madeProgress = $false

            foreach ($job in $jobs) {
                if ($job.Finished) { continue }
                if (-not $job.Handle.IsCompleted) { continue }

                $job.Finished = $true
                $completed++
                $madeProgress = $true

                try {
                    $output = $job.Shell.EndInvoke($job.Handle)
                    $record = @($output) | Select-Object -Last 1

                    if ($record) {
                        $results[$job.Target.Path] = New-FetchOutcome -ExitCode ([int]$record.ExitCode) -Output "$($record.Output)"
                    }
                    else {
                        $results[$job.Target.Path] = New-FetchOutcome -ExitCode 1 -Output 'The fetch produced no result.'
                    }
                }
                catch {
                    $results[$job.Target.Path] = New-FetchOutcome -ExitCode 1 -Output $_.Exception.Message
                }

                if ($OnProgress) {
                    $null = & $OnProgress $completed $jobs.Count $job.Target.Name
                }
            }

            if (-not $madeProgress -and $completed -lt $jobs.Count) {
                Start-Sleep -Milliseconds 50
            }
        }
    }
    finally {
        foreach ($job in $jobs) {
            try { $job.Shell.Dispose() } catch { Write-Verbose "Shell dispose failed: $($_.Exception.Message)" }
        }

        try { $pool.Close() } catch { Write-Verbose "Pool close failed: $($_.Exception.Message)" }
        try { $pool.Dispose() } catch { Write-Verbose "Pool dispose failed: $($_.Exception.Message)" }
    }

    return , $results
}

function Invoke-RepositoryPrefetch {
    <#
    .SYNOPSIS
        Refreshes remote state for a set of repositories before they are inspected.
    .DESCRIPTION
        Returns a hashtable of repository path to fetch result, ready to hand to
        Get-RepositoryFacts -FetchResult so no repository is fetched twice.
    #>
    param(
        [AllowEmptyCollection()][array]$Repositories = @(),
        [int]$ThrottleLimit = 0,
        [scriptblock]$OnProgress
    )

    $targets = @(Get-RepositoryFetchTargets -Repositories $Repositories)

    return Invoke-ParallelGitFetch -Targets $targets -ThrottleLimit $ThrottleLimit -OnProgress $OnProgress
}
