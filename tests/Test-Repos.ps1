#Requires -Version 5.1

<#
.SYNOPSIS
    Behavioral tests for the DevTools repository intelligence layer.
.DESCRIPTION
    Creates throwaway Git repositories in a temporary folder and uses local bare
    repositories as remotes, so these tests run offline and never touch the
    user's real workspace or require GitHub authentication.

    The most important thing these tests prove is that no local work is lost:
    dirty, ahead, diverged, detached, and conflicted repositories are classified
    and skipped, never modified.
#>

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$DevToolsRoot = $ProjectRoot

. (Join-Path $ProjectRoot 'lib/utils.ps1')
. (Join-Path $ProjectRoot 'lib/copy.ps1')
. (Join-Path $ProjectRoot 'lib/ui.ps1')
. (Join-Path $ProjectRoot 'lib/git.ps1')
. (Join-Path $ProjectRoot 'lib/repo-git.ps1')
. (Join-Path $ProjectRoot 'lib/repo-state.ps1')
. (Join-Path $ProjectRoot 'lib/repo-sync.ps1')
. (Join-Path $ProjectRoot 'lib/repo-repair.ps1')
. (Join-Path $ProjectRoot 'lib/repo-report.ps1')

$script:failed = $false
$script:passCount = 0
$script:failCount = 0

function Write-TestPass {
    param([string]$Message)
    Write-Host "PASS: $Message" -ForegroundColor Green
    $script:passCount++
}

function Write-TestFailure {
    param([string]$Message)
    Write-Host "FAIL: $Message" -ForegroundColor Red
    $script:failed = $true
    $script:failCount++
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)

    if ("$Expected" -eq "$Actual") {
        Write-TestPass "$Label"
    }
    else {
        Write-TestFailure "$Label (expected '$Expected', got '$Actual')"
    }
}

function Assert-True {
    param($Condition, [string]$Label)

    if ($Condition) { Write-TestPass $Label } else { Write-TestFailure $Label }
}

function Assert-False {
    param($Condition, [string]$Label)

    if (-not $Condition) { Write-TestPass $Label } else { Write-TestFailure $Label }
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

$script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("devtools-repos-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$script:Workspace = Join-Path $script:TestRoot 'workspace'
$script:Remotes = Join-Path $script:TestRoot 'remotes'

function Invoke-FixtureGit {
    param(
        [string]$RepoPath,
        [string[]]$GitArgs,
        [switch]$AllowFailure
    )

    $all = @()
    if ($RepoPath) { $all += @('-C', $RepoPath) }
    $all += $GitArgs

    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & git @all 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $previous

    if ($code -ne 0 -and -not $AllowFailure) {
        throw "Fixture git failed ($code): git $($GitArgs -join ' ')`n$output"
    }

    return ($output | Out-String)
}

function Set-FixtureIdentity {
    param([string]$RepoPath)

    Invoke-FixtureGit -RepoPath $RepoPath -GitArgs @('config', 'user.name', 'DevTools Test') | Out-Null
    Invoke-FixtureGit -RepoPath $RepoPath -GitArgs @('config', 'user.email', 'test@example.invalid') | Out-Null
    Invoke-FixtureGit -RepoPath $RepoPath -GitArgs @('config', 'commit.gpgsign', 'false') | Out-Null
}

function New-FixtureCommit {
    param(
        [string]$RepoPath,
        [string]$FileName,
        [string]$Content,
        [string]$Message
    )

    Set-Content -LiteralPath (Join-Path $RepoPath $FileName) -Value $Content -Encoding UTF8
    Invoke-FixtureGit -RepoPath $RepoPath -GitArgs @('add', '.') | Out-Null
    Invoke-FixtureGit -RepoPath $RepoPath -GitArgs @('commit', '-m', $Message) | Out-Null
}

function New-FixtureRepository {
    <#
    .SYNOPSIS
        Creates a bare remote plus a clone inside the fixture workspace.
    #>
    param([string]$Name)

    $bare = Join-Path $script:Remotes "$Name.git"
    Invoke-FixtureGit -GitArgs @('-c', 'init.defaultBranch=main', 'init', '--bare', '--quiet', $bare) | Out-Null

    $seed = Join-Path $script:TestRoot "seed-$Name"
    Invoke-FixtureGit -GitArgs @('-c', 'init.defaultBranch=main', 'init', '--quiet', $seed) | Out-Null
    Set-FixtureIdentity -RepoPath $seed
    New-FixtureCommit -RepoPath $seed -FileName 'README.md' -Content 'seed' -Message 'Initial commit'
    Invoke-FixtureGit -RepoPath $seed -GitArgs @('remote', 'add', 'origin', $bare) | Out-Null
    Invoke-FixtureGit -RepoPath $seed -GitArgs @('push', '--quiet', '-u', 'origin', 'main') | Out-Null
    Remove-Item -LiteralPath $seed -Recurse -Force

    $work = Join-Path $script:Workspace $Name
    Invoke-FixtureGit -GitArgs @('clone', '--quiet', $bare, $work) | Out-Null
    Set-FixtureIdentity -RepoPath $work

    return [pscustomobject]@{ Name = $Name; Path = $work; Bare = $bare }
}

function Add-RemoteCommit {
    <#
    .SYNOPSIS
        Adds a commit to the bare remote through a throwaway clone.
    #>
    param(
        $Repository,
        [string]$FileName = 'remote.txt',
        [string]$Content = 'remote change',
        [string]$Branch = 'main'
    )

    $driver = Join-Path $script:TestRoot ("driver-" + [Guid]::NewGuid().ToString('N').Substring(0, 6))
    Invoke-FixtureGit -GitArgs @('clone', '--quiet', $Repository.Bare, $driver) | Out-Null
    Set-FixtureIdentity -RepoPath $driver
    Invoke-FixtureGit -RepoPath $driver -GitArgs @('checkout', '--quiet', $Branch) | Out-Null
    New-FixtureCommit -RepoPath $driver -FileName $FileName -Content $Content -Message "Remote change to $FileName"
    Invoke-FixtureGit -RepoPath $driver -GitArgs @('push', '--quiet', 'origin', $Branch) | Out-Null
    Remove-Item -LiteralPath $driver -Recurse -Force
}

function Get-FixtureHead {
    param([string]$RepoPath)
    return (Invoke-FixtureGit -RepoPath $RepoPath -GitArgs @('rev-parse', 'HEAD')).Trim()
}

function Get-FixtureState {
    param([string]$RepoPath, [switch]$Refresh)

    $facts = Get-RepositoryFacts -RepoPath $RepoPath -Refresh:$Refresh
    return Get-RepositoryState -Facts $facts
}

Write-Host ''
Write-Host 'DevTools Repository Intelligence Tests' -ForegroundColor Cyan
Write-Host "Fixture root: $script:TestRoot"
Write-Host ''

New-Item -ItemType Directory -Path $script:Workspace -Force | Out-Null
New-Item -ItemType Directory -Path $script:Remotes -Force | Out-Null

try {
    # -----------------------------------------------------------------------
    # 1. Clean and current
    # -----------------------------------------------------------------------
    $current = New-FixtureRepository -Name 'repo-current'
    $state = Get-FixtureState -RepoPath $current.Path -Refresh
    Assert-Equal 'Current' $state.HealthCode 'Clean, up-to-date repository classifies as Current'
    Assert-True $state.IsHealthy 'Current repository is healthy'
    Assert-False $state.CanFastForward 'Current repository has nothing to fast-forward'
    Assert-Equal 'main' $state.DefaultBranch 'Default branch is detected'
    Assert-Equal 'origin/main' $state.Upstream 'Upstream is detected'

    # -----------------------------------------------------------------------
    # 2. Clean but behind
    # -----------------------------------------------------------------------
    $behind = New-FixtureRepository -Name 'repo-behind'
    Add-RemoteCommit -Repository $behind
    $state = Get-FixtureState -RepoPath $behind.Path -Refresh
    Assert-Equal 'Behind' $state.HealthCode 'Clean repository behind remote classifies as Behind'
    Assert-Equal 1 $state.Behind 'Behind count is 1'
    Assert-True $state.CanFastForward 'Behind repository is eligible for fast-forward'

    # -----------------------------------------------------------------------
    # 3. Local uncommitted changes
    # -----------------------------------------------------------------------
    $dirty = New-FixtureRepository -Name 'repo-dirty'
    Set-Content -LiteralPath (Join-Path $dirty.Path 'README.md') -Value 'work in progress' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $dirty.Path 'scratch.txt') -Value 'untracked' -Encoding UTF8
    Add-RemoteCommit -Repository $dirty
    $state = Get-FixtureState -RepoPath $dirty.Path -Refresh
    Assert-Equal 'LocalChanges' $state.HealthCode 'Uncommitted changes classify as LocalChanges'
    Assert-Equal 1 $state.ModifiedFilesCount 'Modified file count is tracked'
    Assert-Equal 1 $state.UntrackedFilesCount 'Untracked file count is tracked'
    Assert-False $state.CanFastForward 'Dirty repository is never auto-updated'

    # -----------------------------------------------------------------------
    # 4. Ahead of remote
    # -----------------------------------------------------------------------
    $ahead = New-FixtureRepository -Name 'repo-ahead'
    New-FixtureCommit -RepoPath $ahead.Path -FileName 'local.txt' -Content 'local only' -Message 'Local commit'
    $state = Get-FixtureState -RepoPath $ahead.Path -Refresh
    Assert-Equal 'Ahead' $state.HealthCode 'Local commits classify as Ahead'
    Assert-Equal 1 $state.Ahead 'Ahead count is 1'
    Assert-False $state.CanFastForward 'Ahead repository is never auto-updated'

    # -----------------------------------------------------------------------
    # 5. Diverged
    # -----------------------------------------------------------------------
    $diverged = New-FixtureRepository -Name 'repo-diverged'
    New-FixtureCommit -RepoPath $diverged.Path -FileName 'local.txt' -Content 'local only' -Message 'Local commit'
    Add-RemoteCommit -Repository $diverged
    $state = Get-FixtureState -RepoPath $diverged.Path -Refresh
    Assert-Equal 'Diverged' $state.HealthCode 'Divergence classifies as Diverged'
    Assert-True ($state.Ahead -eq 1 -and $state.Behind -eq 1) 'Diverged repository reports both counts'
    Assert-False $state.CanFastForward 'Diverged repository is never auto-updated'

    # -----------------------------------------------------------------------
    # 6. Deleted upstream branch (the AI agent branch scenario)
    # -----------------------------------------------------------------------
    $gone = New-FixtureRepository -Name 'repo-upstream-gone'
    Invoke-FixtureGit -RepoPath $gone.Path -GitArgs @('checkout', '--quiet', '-b', 'claude/rebuild-homepage') | Out-Null
    Invoke-FixtureGit -RepoPath $gone.Path -GitArgs @('push', '--quiet', '-u', 'origin', 'claude/rebuild-homepage') | Out-Null
    Invoke-FixtureGit -RepoPath $gone.Path -GitArgs @('push', '--quiet', 'origin', '--delete', 'claude/rebuild-homepage') | Out-Null
    $state = Get-FixtureState -RepoPath $gone.Path -Refresh
    Assert-Equal 'UpstreamGone' $state.HealthCode 'Deleted remote branch classifies as UpstreamGone'
    Assert-True $state.UpstreamConfigured 'Upstream is still configured'
    Assert-False $state.UpstreamExists 'Upstream remote branch no longer exists'
    Assert-True ($state.Detail -match 'no longer exists') 'UpstreamGone detail explains the missing branch'

    # -----------------------------------------------------------------------
    # 7. Missing upstream (branch never pushed)
    # -----------------------------------------------------------------------
    $noUpstream = New-FixtureRepository -Name 'repo-no-upstream'
    Invoke-FixtureGit -RepoPath $noUpstream.Path -GitArgs @('checkout', '--quiet', '-b', 'cursor/experiment') | Out-Null
    $state = Get-FixtureState -RepoPath $noUpstream.Path -Refresh
    Assert-Equal 'MissingUpstream' $state.HealthCode 'Branch with no upstream classifies as MissingUpstream'

    # -----------------------------------------------------------------------
    # 8. Detached HEAD
    # -----------------------------------------------------------------------
    $detached = New-FixtureRepository -Name 'repo-detached'
    Invoke-FixtureGit -RepoPath $detached.Path -GitArgs @('checkout', '--quiet', '--detach', 'HEAD') | Out-Null
    $state = Get-FixtureState -RepoPath $detached.Path -Refresh
    Assert-Equal 'DetachedHead' $state.HealthCode 'Detached HEAD is detected'
    Assert-Equal '(detached)' $state.BranchDisplay 'Detached HEAD renders a clear branch label'

    # -----------------------------------------------------------------------
    # 9. Merge conflict
    # -----------------------------------------------------------------------
    $conflict = New-FixtureRepository -Name 'repo-conflict'
    New-FixtureCommit -RepoPath $conflict.Path -FileName 'shared.txt' -Content 'local version' -Message 'Local edit'
    Add-RemoteCommit -Repository $conflict -FileName 'shared.txt' -Content 'remote version'
    Invoke-FixtureGit -RepoPath $conflict.Path -GitArgs @('fetch', '--quiet', 'origin') | Out-Null
    Invoke-FixtureGit -RepoPath $conflict.Path -GitArgs @('merge', 'origin/main') -AllowFailure | Out-Null
    $state = Get-FixtureState -RepoPath $conflict.Path
    Assert-Equal 'Conflicts' $state.HealthCode 'Unresolved conflicts classify as Conflicts, not Modified'
    Assert-True $state.MergeInProgress 'Merge in progress is detected alongside conflicts'
    Assert-True ($state.ConflictFilesCount -ge 1) 'Conflicted file count is reported'

    # -----------------------------------------------------------------------
    # 10. Merge in progress without conflicts
    # -----------------------------------------------------------------------
    $merging = New-FixtureRepository -Name 'repo-merging'
    New-FixtureCommit -RepoPath $merging.Path -FileName 'local.txt' -Content 'local' -Message 'Local edit'
    Add-RemoteCommit -Repository $merging -FileName 'other.txt' -Content 'remote'
    Invoke-FixtureGit -RepoPath $merging.Path -GitArgs @('fetch', '--quiet', 'origin') | Out-Null
    Invoke-FixtureGit -RepoPath $merging.Path -GitArgs @('merge', '--no-commit', '--no-ff', 'origin/main') -AllowFailure | Out-Null
    $state = Get-FixtureState -RepoPath $merging.Path
    Assert-Equal 'MergeInProgress' $state.HealthCode 'A clean merge in progress classifies as MergeInProgress'

    # -----------------------------------------------------------------------
    # 11. Rebase in progress
    # -----------------------------------------------------------------------
    $rebasing = New-FixtureRepository -Name 'repo-rebasing'
    New-FixtureCommit -RepoPath $rebasing.Path -FileName 'shared.txt' -Content 'local version' -Message 'Local edit'
    Add-RemoteCommit -Repository $rebasing -FileName 'shared.txt' -Content 'remote version'
    Invoke-FixtureGit -RepoPath $rebasing.Path -GitArgs @('fetch', '--quiet', 'origin') | Out-Null
    Invoke-FixtureGit -RepoPath $rebasing.Path -GitArgs @('rebase', 'origin/main') -AllowFailure | Out-Null
    $state = Get-FixtureState -RepoPath $rebasing.Path
    Assert-True ($state.HealthCode -eq 'RebaseInProgress' -or $state.HealthCode -eq 'Conflicts') 'A stopped rebase is reported as an operation or conflict, never as Clean'
    Assert-True $state.RebaseInProgress 'Rebase in progress is detected'
    Invoke-FixtureGit -RepoPath $rebasing.Path -GitArgs @('rebase', '--abort') -AllowFailure | Out-Null

    # -----------------------------------------------------------------------
    # 12. No remote configured
    # -----------------------------------------------------------------------
    $noRemote = Join-Path $script:Workspace 'repo-no-remote'
    Invoke-FixtureGit -GitArgs @('-c', 'init.defaultBranch=main', 'init', '--quiet', $noRemote) | Out-Null
    Set-FixtureIdentity -RepoPath $noRemote
    New-FixtureCommit -RepoPath $noRemote -FileName 'README.md' -Content 'local only project' -Message 'Initial commit'
    $state = Get-FixtureState -RepoPath $noRemote -Refresh
    Assert-Equal 'RemoteMissing' $state.HealthCode 'Repository without a remote classifies as RemoteMissing'
    Assert-False $state.CanFastForward 'Repository without a remote is never auto-updated'

    # -----------------------------------------------------------------------
    # 13. Fetch failure
    # -----------------------------------------------------------------------
    $fetchFail = New-FixtureRepository -Name 'repo-fetch-fail'
    $missingRemote = Join-Path $script:Remotes 'does-not-exist.git'
    Invoke-FixtureGit -RepoPath $fetchFail.Path -GitArgs @('remote', 'set-url', 'origin', $missingRemote) | Out-Null
    $state = Get-FixtureState -RepoPath $fetchFail.Path -Refresh
    Assert-True ($state.HealthGroup -eq 'Remote') 'A failed fetch is classified as a remote problem'
    Assert-False $state.FetchSucceeded 'Fetch failure is recorded'
    Assert-True (-not [string]::IsNullOrWhiteSpace($state.FetchError)) 'The underlying Git error is retained for the detailed view'
    Assert-False $state.CanFastForward 'A repository whose fetch failed is never auto-updated'

    # -----------------------------------------------------------------------
    # 14. Broken repository does not stop the batch
    # -----------------------------------------------------------------------
    $broken = Join-Path $script:Workspace 'repo-broken'
    New-Item -ItemType Directory -Path $broken -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $broken '.git') -Value 'gitdir: /nowhere/at/all' -Encoding UTF8

    # -----------------------------------------------------------------------
    # Bulk sync across the whole fixture workspace
    # -----------------------------------------------------------------------
    $before = @{}
    foreach ($dir in Get-ChildItem -Path $script:Workspace -Directory) {
        if ($dir.Name -eq 'repo-broken') { continue }
        $before[$dir.Name] = [pscustomobject]@{
            Head   = (Invoke-FixtureGit -RepoPath $dir.FullName -GitArgs @('rev-parse', 'HEAD') -AllowFailure).Trim()
            Readme = (Get-Content -LiteralPath (Join-Path $dir.FullName 'README.md') -Raw -ErrorAction SilentlyContinue)
            Log    = (Invoke-FixtureGit -RepoPath $dir.FullName -GitArgs @('log', '--oneline', '--all') -AllowFailure)
        }
    }

    $results = Invoke-RepositorySync -WorkspacePath $script:Workspace
    $byName = @{}
    foreach ($result in $results) { $byName[$result.Name] = $result }

    Assert-Equal (@(Get-ChildItem -Path $script:Workspace -Directory).Count) $results.Count 'Every repository produced a sync result'
    Assert-True ($byName.ContainsKey('repo-broken')) 'The batch continued past the broken repository'
    Assert-Equal 'Skipped' $byName['repo-broken'].Outcome 'The broken repository is skipped, not fatal'
    Assert-Equal 'not a Git repository' $byName['repo-broken'].Reason 'The broken repository gets an actionable reason'

    Assert-Equal 'Updated' $byName['repo-behind'].Outcome 'A safe behind repository is updated'
    Assert-Equal 1 $byName['repo-behind'].CommitsPulled 'The updated repository reports the commit count'
    Assert-Equal 'Current' $byName['repo-behind'].State.HealthCode 'The updated repository is current afterwards'
    Assert-Equal 'Current' $byName['repo-current'].Outcome 'An already current repository reports Current'

    Assert-Equal 'Skipped' $byName['repo-dirty'].Outcome 'A dirty repository is skipped'
    Assert-Equal 'local changes' $byName['repo-dirty'].Reason 'A dirty repository explains why it was skipped'
    Assert-Equal 'Skipped' $byName['repo-diverged'].Outcome 'A diverged repository is skipped'
    Assert-Equal 'local and remote have diverged' $byName['repo-diverged'].Reason 'A diverged repository explains why it was skipped'
    Assert-Equal 'Skipped' $byName['repo-ahead'].Outcome 'An ahead repository is skipped'
    Assert-Equal 'Skipped' $byName['repo-detached'].Outcome 'A detached repository is skipped'
    Assert-Equal 'not on a branch' $byName['repo-detached'].Reason 'A detached repository explains why it was skipped'
    Assert-Equal 'Skipped' $byName['repo-conflict'].Outcome 'A conflicted repository is skipped'
    Assert-Equal 'unresolved conflicts' $byName['repo-conflict'].Reason 'A conflicted repository explains why it was skipped'
    Assert-True ($byName['repo-upstream-gone'].Reason -match 'no longer exists') 'A deleted upstream is named in the skip reason'

    # No generic failure text anywhere.
    $genericReasons = @($results | Where-Object { $_.Reason -match '(?i)could not update' })
    Assert-Equal 0 $genericReasons.Count 'No repository falls back to a generic "could not update" message'

    # -----------------------------------------------------------------------
    # NO LOCAL WORK IS LOST
    # -----------------------------------------------------------------------
    foreach ($name in @('repo-dirty', 'repo-ahead', 'repo-diverged', 'repo-detached', 'repo-conflict', 'repo-merging', 'repo-upstream-gone')) {
        $path = Join-Path $script:Workspace $name
        $head = (Invoke-FixtureGit -RepoPath $path -GitArgs @('rev-parse', 'HEAD') -AllowFailure).Trim()
        Assert-Equal $before[$name].Head $head "Sync did not move HEAD in $name"

        $log = (Invoke-FixtureGit -RepoPath $path -GitArgs @('log', '--oneline', '--all') -AllowFailure)
        Assert-Equal $before[$name].Log $log "Sync did not rewrite history in $name"
    }

    $dirtyReadme = Get-Content -LiteralPath (Join-Path $script:Workspace 'repo-dirty/README.md') -Raw
    Assert-True ($dirtyReadme -match 'work in progress') 'Uncommitted changes survive a sync untouched'
    Assert-True (Test-Path -LiteralPath (Join-Path $script:Workspace 'repo-dirty/scratch.txt')) 'Untracked files survive a sync untouched'

    $divergedLog = Invoke-FixtureGit -RepoPath (Join-Path $script:Workspace 'repo-diverged') -GitArgs @('log', '--oneline', 'HEAD')
    Assert-False ($divergedLog -match '(?i)merge') 'Sync never creates a merge commit in a diverged repository'

    # -----------------------------------------------------------------------
    # Summary counts
    # -----------------------------------------------------------------------
    $summary = Get-RepositorySyncSummary -Results $results
    Assert-Equal 1 $summary.Updated 'Sync summary counts one update'
    Assert-Equal 1 $summary.Dirty 'Sync summary counts local changes'
    # repo-diverged plus repo-rebasing, whose aborted rebase leaves it diverged.
    Assert-Equal 2 $summary.Diverged 'Sync summary counts divergence'
    Assert-Equal 2 $summary.Upstream 'Sync summary counts broken and missing upstreams'
    Assert-Equal 1 $summary.Detached 'Sync summary counts detached HEAD'
    Assert-True ($summary.NeedsAttention -ge 8) 'Sync summary reports repositories needing attention'

    $attention = Get-RepositorySyncAttentionResults -Results $results
    Assert-True ($attention.Count -eq $summary.NeedsAttention) 'The attention list matches the summary count'

    # The summary must account for every repository exactly once.
    $partition = $summary.Updated + $summary.Current + $summary.Dirty + $summary.Ahead + $summary.Diverged +
                 $summary.Upstream + $summary.Detached + $summary.Conflicts + $summary.Operation +
                 $summary.Remote + $summary.Other
    Assert-Equal $summary.Total $partition 'Every repository is counted exactly once in the sync summary'

    # -----------------------------------------------------------------------
    # 15. Upstream repair — safe case
    # -----------------------------------------------------------------------
    $safeRepair = New-FixtureRepository -Name 'repo-repair-safe'
    Invoke-FixtureGit -RepoPath $safeRepair.Path -GitArgs @('checkout', '--quiet', '-b', 'claude/merged-work') | Out-Null
    Invoke-FixtureGit -RepoPath $safeRepair.Path -GitArgs @('push', '--quiet', '-u', 'origin', 'claude/merged-work') | Out-Null
    Invoke-FixtureGit -RepoPath $safeRepair.Path -GitArgs @('push', '--quiet', 'origin', '--delete', 'claude/merged-work') | Out-Null
    Add-RemoteCommit -Repository $safeRepair -FileName 'after-merge.txt' -Content 'merged upstream'

    $state = Get-FixtureState -RepoPath $safeRepair.Path -Refresh
    $plan = Get-UpstreamRepairPlan -State $state
    Assert-True $plan.CanRepair 'A fully merged agent branch with a deleted upstream is safe to repair'
    Assert-Equal 0 $plan.UnmergedCommits 'The safe repair plan finds no unmerged commits'
    Assert-Equal 'main' $plan.DefaultBranch 'The repair plan targets the default branch'

    $repair = Invoke-UpstreamRepair -Plan $plan
    Assert-True $repair.Success 'The safe repair completes'
    $afterState = Get-FixtureState -RepoPath $safeRepair.Path
    Assert-Equal 'main' $afterState.CurrentBranch 'Repair switched to the default branch'
    Assert-Equal 'Current' $afterState.HealthCode 'Repair left the repository current'
    Assert-True (Test-RepositoryRefExists -RepoPath $safeRepair.Path -Ref 'refs/heads/claude/merged-work') 'Repair never deletes the old branch'

    # -----------------------------------------------------------------------
    # 16. Upstream repair — unsafe case (unmerged local commits)
    # -----------------------------------------------------------------------
    $unsafeRepair = New-FixtureRepository -Name 'repo-repair-unsafe'
    Invoke-FixtureGit -RepoPath $unsafeRepair.Path -GitArgs @('checkout', '--quiet', '-b', 'claude/unmerged-work') | Out-Null
    Invoke-FixtureGit -RepoPath $unsafeRepair.Path -GitArgs @('push', '--quiet', '-u', 'origin', 'claude/unmerged-work') | Out-Null
    New-FixtureCommit -RepoPath $unsafeRepair.Path -FileName 'unmerged.txt' -Content 'not on main' -Message 'Unmerged work'
    Invoke-FixtureGit -RepoPath $unsafeRepair.Path -GitArgs @('push', '--quiet', 'origin', '--delete', 'claude/unmerged-work') | Out-Null

    $state = Get-FixtureState -RepoPath $unsafeRepair.Path -Refresh
    $headBefore = Get-FixtureHead -RepoPath $unsafeRepair.Path
    $plan = Get-UpstreamRepairPlan -State $state
    Assert-False $plan.CanRepair 'A branch with unmerged commits is never repaired automatically'
    Assert-Equal 1 $plan.UnmergedCommits 'The unsafe plan counts the unmerged commits'
    Assert-True (($plan.Blockers -join ' ') -match 'not in main') 'The unsafe plan explains the blocker in plain language'

    $refused = Invoke-UpstreamRepair -Plan $plan
    Assert-False $refused.Success 'Repair refuses to run on an unsafe plan'
    Assert-Equal 'claude/unmerged-work' (Get-FixtureState -RepoPath $unsafeRepair.Path).CurrentBranch 'The unsafe repository stays on its branch'
    Assert-Equal $headBefore (Get-FixtureHead -RepoPath $unsafeRepair.Path) 'The unsafe repository keeps its commits'

    # A dirty working tree also blocks repair.
    $dirtyRepair = New-FixtureRepository -Name 'repo-repair-dirty'
    Invoke-FixtureGit -RepoPath $dirtyRepair.Path -GitArgs @('checkout', '--quiet', '-b', 'codex/wip') | Out-Null
    Invoke-FixtureGit -RepoPath $dirtyRepair.Path -GitArgs @('push', '--quiet', '-u', 'origin', 'codex/wip') | Out-Null
    Invoke-FixtureGit -RepoPath $dirtyRepair.Path -GitArgs @('push', '--quiet', 'origin', '--delete', 'codex/wip') | Out-Null
    Set-Content -LiteralPath (Join-Path $dirtyRepair.Path 'README.md') -Value 'uncommitted' -Encoding UTF8
    $dirtyPlan = Get-UpstreamRepairPlan -State (Get-FixtureState -RepoPath $dirtyRepair.Path -Refresh)
    Assert-False $dirtyPlan.CanRepair 'Repair refuses when the working tree is dirty'
    Assert-True (($dirtyPlan.Blockers -join ' ') -match 'uncommitted changes') 'The dirty blocker is explained'

    # -----------------------------------------------------------------------
    # 17. Branch cleanup — deletes merged, refuses unmerged
    # -----------------------------------------------------------------------
    $cleanup = New-FixtureRepository -Name 'repo-cleanup'
    Invoke-FixtureGit -RepoPath $cleanup.Path -GitArgs @('branch', 'claude/merged-feature') | Out-Null
    Invoke-FixtureGit -RepoPath $cleanup.Path -GitArgs @('checkout', '--quiet', '-b', 'claude/unmerged-feature') | Out-Null
    New-FixtureCommit -RepoPath $cleanup.Path -FileName 'feature.txt' -Content 'unmerged feature' -Message 'Unmerged feature work'
    Invoke-FixtureGit -RepoPath $cleanup.Path -GitArgs @('checkout', '--quiet', 'main') | Out-Null

    $state = Get-FixtureState -RepoPath $cleanup.Path -Refresh
    $candidates = @(Get-BranchCleanupCandidates -State $state)
    $mergedCandidate = $candidates | Where-Object { $_.Name -eq 'claude/merged-feature' } | Select-Object -First 1
    $unmergedCandidate = $candidates | Where-Object { $_.Name -eq 'claude/unmerged-feature' } | Select-Object -First 1
    $mainCandidate = $candidates | Where-Object { $_.Name -eq 'main' } | Select-Object -First 1

    Assert-True ($null -ne $mergedCandidate) 'The merged stale branch is found'
    Assert-True ($null -ne $unmergedCandidate) 'The unmerged stale branch is found'
    Assert-True ($null -eq $mainCandidate) 'The default branch is never a cleanup candidate'
    Assert-True $mergedCandidate.SafeToDelete 'A provably merged branch is safe to delete'
    Assert-False $unmergedCandidate.SafeToDelete 'An unmerged branch is never safe to delete'

    $cleanupSummary = Get-BranchCleanupSummary -Candidates $candidates
    Assert-Equal 1 $cleanupSummary.SafeCount 'Cleanup summary counts one safely deletable branch'
    Assert-Equal 1 $cleanupSummary.ReviewCount 'Cleanup summary counts one branch needing review'

    $deleted = Remove-MergedBranches -RepoPath $cleanup.Path -Candidates $candidates
    $mergedResult = $deleted | Where-Object { $_.Name -eq 'claude/merged-feature' } | Select-Object -First 1
    $unmergedResult = $deleted | Where-Object { $_.Name -eq 'claude/unmerged-feature' } | Select-Object -First 1
    Assert-True $mergedResult.Deleted 'Cleanup deletes the merged branch'
    Assert-False $unmergedResult.Deleted 'Cleanup refuses the unmerged branch'
    Assert-False (Test-RepositoryRefExists -RepoPath $cleanup.Path -Ref 'refs/heads/claude/merged-feature') 'The merged branch is gone'
    Assert-True (Test-RepositoryRefExists -RepoPath $cleanup.Path -Ref 'refs/heads/claude/unmerged-feature') 'The unmerged branch still exists'

    # The current branch can never be a deletion candidate.
    Invoke-FixtureGit -RepoPath $cleanup.Path -GitArgs @('checkout', '--quiet', 'claude/unmerged-feature') | Out-Null
    $currentBranchState = Get-FixtureState -RepoPath $cleanup.Path
    $currentCandidates = @(Get-BranchCleanupCandidates -State $currentBranchState)
    Assert-False (@($currentCandidates | Where-Object { $_.Name -eq 'claude/unmerged-feature' }).Count -gt 0) 'The current branch is never a cleanup candidate'

    # -----------------------------------------------------------------------
    # 18. Diagnostic report
    # -----------------------------------------------------------------------
    $states = @(Get-WorkspaceRepositoryStates -WorkspacePath $script:Workspace)
    $report = New-RepositoryReport -Operation 'health' -WorkspacePath $script:Workspace -States $states
    Assert-Equal 'health' $report.operation 'The report records the operation'
    Assert-Equal $states.Count $report.repositories.Count 'The report includes every repository'
    Assert-True ($report.summary.Total -eq $states.Count) 'The report summary matches the repository count'

    $reportDirectory = Join-Path $script:TestRoot 'reports'
    $saved = Save-RepositoryReport -Report $report -Directory $reportDirectory
    Assert-True $saved.Success 'The report is saved'
    Assert-True (Test-Path -LiteralPath $saved.JsonPath) 'latest.json is written'
    Assert-True (Test-Path -LiteralPath $saved.TextPath) 'latest.txt is written'

    $roundTrip = Get-Content -LiteralPath $saved.JsonPath -Raw | ConvertFrom-Json
    Assert-True ($roundTrip.repositories.Count -eq $states.Count) 'The saved JSON report round-trips'

    $textReport = Get-Content -LiteralPath $saved.TextPath -Raw
    Assert-True ($textReport -match 'Repositories needing attention') 'The text report has an attention section'
    Assert-True ($textReport -match 'Recommended action') 'The text report includes recommended actions'

    # Credentials must never reach a report.
    Assert-Equal 'https://github.com/acme/site.git' (Get-SanitizedRemoteUrl -Url 'https://user:ghp_secrettokenvalue@github.com/acme/site.git') 'Remote URL credentials are stripped'
    Assert-Equal 'https://github.com/acme/site.git' (Get-SanitizedRemoteUrl -Url 'https://ghp_secrettokenvalue@github.com/acme/site.git') 'Remote URL tokens are stripped'
    Assert-Equal 'git@github.com:acme/site.git' (Get-SanitizedRemoteUrl -Url 'git@github.com:acme/site.git') 'SSH remotes are left intact'

    $secretFacts = New-RepositoryFacts -Name 'secret' -Path 'C:\secret'
    $secretFacts.IsGitRepository = $true
    $secretFacts.HasRemote = $true
    $secretFacts.RemoteName = 'origin'
    $secretFacts.RemoteUrl = 'https://user:ghp_shouldnotleak@github.com/acme/site.git'
    $secretEntry = ConvertTo-RepositoryReportEntry -State (Get-RepositoryState -Facts $secretFacts)
    Assert-False ($secretEntry.remoteUrl -match 'ghp_shouldnotleak') 'A report entry never contains a token'

    # -----------------------------------------------------------------------
    # 19. Classification priority (pure, no Git required)
    # -----------------------------------------------------------------------
    $facts = New-RepositoryFacts -Name 'priority' -Path 'C:\priority'
    $facts.IsGitRepository = $true
    $facts.HasRemote = $true
    $facts.RemoteName = 'origin'
    $facts.UpstreamConfigured = $true
    $facts.UpstreamExists = $true
    $facts.Upstream = 'origin/main'
    $facts.IsDirty = $true
    $facts.ModifiedFilesCount = 3
    $facts.Behind = 2
    Assert-Equal 'LocalChanges' (Get-RepositoryHealthCode -Facts $facts) 'Local changes outrank being behind'

    $facts.Ahead = 1
    Assert-Equal 'Diverged' (Get-RepositoryHealthCode -Facts $facts) 'Divergence outranks local changes'

    $facts.HasConflicts = $true
    $facts.ConflictFilesCount = 1
    Assert-Equal 'Conflicts' (Get-RepositoryHealthCode -Facts $facts) 'Conflicts outrank divergence and local changes'

    $facts.HasConflicts = $false
    $facts.ConflictFilesCount = 0
    $facts.IsDetachedHead = $true
    Assert-Equal 'DetachedHead' (Get-RepositoryHealthCode -Facts $facts) 'Detached HEAD outranks divergence'

    $facts.IsDetachedHead = $false

    # A local-only project with uncommitted work is reported as Local changes,
    # which is more actionable than "no remote".
    $facts.Ahead = 0
    $facts.HasRemote = $false
    Assert-Equal 'LocalChanges' (Get-RepositoryHealthCode -Facts $facts) 'Local changes outrank a missing remote'
    $facts.IsDirty = $false
    Assert-Equal 'RemoteMissing' (Get-RepositoryHealthCode -Facts $facts) 'A clean repository with no remote reports No remote'
    $facts.IsDirty = $true
    $facts.HasRemote = $true

    $facts.UpstreamConfigured = $false
    Assert-Equal 'LocalChanges' (Get-RepositoryHealthCode -Facts $facts) 'Local changes outrank a missing upstream'
    $facts.UpstreamConfigured = $true
    $facts.Ahead = 1

    $facts.RebaseInProgress = $true
    Assert-Equal 'RebaseInProgress' (Get-RepositoryHealthCode -Facts $facts) 'A rebase in progress outranks divergence'

    $facts.RebaseInProgress = $false
    $facts.FetchAttempted = $true
    $facts.FetchSucceeded = $false
    $facts.FetchErrorCategory = 'Authentication'
    Assert-Equal 'AuthenticationFailed' (Get-RepositoryHealthCode -Facts $facts) 'An authentication failure is identified specifically'

    $facts.FetchErrorCategory = 'Network'
    Assert-Equal 'RemoteUnavailable' (Get-RepositoryHealthCode -Facts $facts) 'A network failure is identified specifically'

    $facts.FetchErrorCategory = 'Unknown'
    Assert-Equal 'FetchFailed' (Get-RepositoryHealthCode -Facts $facts) 'An unrecognized fetch failure is still classified'

    Assert-Equal 'Authentication' (Get-GitErrorCategory -Output 'fatal: Authentication failed for https://github.com/acme/site.git' -ExitCode 128) 'Authentication errors are categorized'
    Assert-Equal 'Network' (Get-GitErrorCategory -Output 'fatal: unable to access: Could not resolve host: github.com' -ExitCode 128) 'Network errors are categorized'
    Assert-Equal 'None' (Get-GitErrorCategory -Output '' -ExitCode 0) 'Success is not an error category'

    # Every catalog entry has beginner-friendly copy.
    foreach ($definition in Get-RepositoryHealthCatalog) {
        if ([string]::IsNullOrWhiteSpace($definition.Explanation) -or
            [string]::IsNullOrWhiteSpace($definition.LocalWork) -or
            [string]::IsNullOrWhiteSpace($definition.Action)) {
            Write-TestFailure "Health state $($definition.Code) is missing guidance copy"
        }
    }
    Write-TestPass 'Every health state answers what happened, is my work safe, and what next'

    # -----------------------------------------------------------------------
    # 20. Filters
    # -----------------------------------------------------------------------
    $allStates = @(Get-WorkspaceRepositoryStates -WorkspacePath $script:Workspace)
    $attentionStates = @(Select-RepositoryStatesByFilter -States $allStates -Filter 'Attention')
    Assert-True ($attentionStates.Count -lt $allStates.Count) 'The attention filter hides healthy repositories'
    Assert-False (@($attentionStates | Where-Object { $_.IsHealthy }).Count -gt 0) 'The attention filter contains no healthy repositories'
    Assert-Equal 8 (@(Get-RepositoryFilterDefinitions)).Count 'Repository Health offers eight filters'

    $dirtyStates = @(Select-RepositoryStatesByFilter -States $allStates -Filter 'Dirty')
    Assert-True (@($dirtyStates | Where-Object { $_.HealthGroup -ne 'Dirty' }).Count -eq 0) 'The modified filter only returns modified repositories'

    # -----------------------------------------------------------------------
    # 21. Backward compatibility of Get-RepoStatusDetails
    # -----------------------------------------------------------------------
    $legacy = Get-RepoStatusDetails -RepoPath (Join-Path $script:Workspace 'repo-dirty')
    Assert-Equal 'Modified' $legacy.DisplayStatus 'Get-RepoStatusDetails still reports Modified for dirty repositories'
    Assert-True $legacy.IsModified 'Get-RepoStatusDetails still exposes IsModified'
    Assert-False $legacy.IsClean 'Get-RepoStatusDetails still exposes IsClean'
    Assert-Equal 'main' $legacy.Branch 'Get-RepoStatusDetails still exposes Branch'

    $legacyClean = Get-RepoStatusDetails -RepoPath (Join-Path $script:Workspace 'repo-current')
    Assert-Equal 'Clean' $legacyClean.DisplayStatus 'Get-RepoStatusDetails still reports Clean'
    Assert-True $legacyClean.IsClean 'A clean repository is still reported as clean'

    # -----------------------------------------------------------------------
    # 22. Porcelain parsing (pure)
    # -----------------------------------------------------------------------
    $parsed = ConvertFrom-GitPorcelainV2 -Lines @(
        '# branch.oid abc123'
        '# branch.head feature/x'
        '# branch.upstream origin/feature/x'
        '# branch.ab +2 -3'
        '1 .M N... 100644 100644 100644 aaa bbb file1.txt'
        '2 R. N... 100644 100644 100644 aaa bbb R100 new.txt' + "`t" + 'old.txt'
        '? untracked.txt'
        'u UU N... 100644 100644 100644 100644 aaa bbb ccc conflict.txt'
    )
    Assert-Equal 'feature/x' $parsed.Branch 'Porcelain v2 branch is parsed'
    Assert-Equal 'origin/feature/x' $parsed.Upstream 'Porcelain v2 upstream is parsed'
    Assert-Equal 2 $parsed.Ahead 'Porcelain v2 ahead count is parsed'
    Assert-Equal 3 $parsed.Behind 'Porcelain v2 behind count is parsed'
    Assert-Equal 2 $parsed.ModifiedFilesCount 'Porcelain v2 modified and renamed entries are counted'
    Assert-Equal 1 $parsed.UntrackedFilesCount 'Porcelain v2 untracked entries are counted'
    Assert-Equal 1 $parsed.ConflictFilesCount 'Porcelain v2 unmerged entries are counted'

    $detachedParsed = ConvertFrom-GitPorcelainV2 -Lines @('# branch.oid abc123', '# branch.head (detached)')
    Assert-True $detachedParsed.IsDetachedHead 'Porcelain v2 detects a detached HEAD'
    Assert-False $detachedParsed.HasUpstreamConfig 'A detached HEAD has no upstream'

    # -----------------------------------------------------------------------
    # 23. Output formatting replaces generic errors with actionable reasons
    # -----------------------------------------------------------------------
    $env:DEVTOOLS_ASCII = '1'
    $script:DevToolsUnicodeSupportCached = $null

    . (Join-Path $ProjectRoot 'lib/repo-ui.ps1')

    $skippedLine = Format-RepositorySyncLine -Result $byName['repo-dirty']
    Assert-True ($skippedLine -match 'Skipped: repo-dirty - local changes') 'A skipped repository renders an actionable reason'
    Assert-False ($skippedLine -match '(?i)could not update') 'The generic "could not update" message is gone'

    $updatedLine = Format-RepositorySyncLine -Result $byName['repo-behind']
    Assert-True ($updatedLine -match 'Updated: repo-behind \(1 commit') 'An updated repository renders its commit count'

    $currentLine = Format-RepositorySyncLine -Result $byName['repo-current']
    Assert-True ($currentLine -match 'Current: repo-current') 'A current repository renders a compact line'

    foreach ($line in @($skippedLine, $updatedLine, $currentLine)) {
        $nonAscii = @($line.ToCharArray() | Where-Object { [int]$_ -gt 127 })
        if ($nonAscii.Count -gt 0) {
            Write-TestFailure "ASCII fallback produced a non-ASCII character in: $line"
        }
    }
    Write-TestPass 'Sync output honours the ASCII fallback'

    Assert-Equal '[42/298] Checking bella-demo...' (Format-RepositoryProgressLine -Index 42 -Total 298 -Name 'bella-demo') 'Progress output is compact at workspace scale'

    Remove-Item Env:\DEVTOOLS_ASCII -ErrorAction SilentlyContinue
    $script:DevToolsUnicodeSupportCached = $null

    # -----------------------------------------------------------------------
    # 24. Command surface: dev update still works, dev sync exists
    # -----------------------------------------------------------------------
    $syncCommand = Join-Path $ProjectRoot 'commands/sync.ps1'
    $updateCommand = Join-Path $ProjectRoot 'commands/update.ps1'
    Assert-True (Test-Path -LiteralPath $syncCommand) 'dev sync exists'
    Assert-True (Test-Path -LiteralPath $updateCommand) 'dev update still exists'

    $updateContent = Get-Content -LiteralPath $updateCommand -Raw
    Assert-True ($updateContent -match 'sync\.ps1') 'dev update routes into the sync workflow'

    $coreContent = Get-Content -LiteralPath (Join-Path $ProjectRoot 'dev-core.ps1') -Raw
    foreach ($module in @('repo-git', 'repo-state', 'repo-sync', 'repo-repair', 'repo-report', 'repo-ui')) {
        Assert-True ($coreContent -match [regex]::Escape($module)) "dev-core.ps1 loads lib/$module.ps1"
    }
    Assert-True ($coreContent -match 'dev sync|sync, update' -or $coreContent -match 'clone, sync') 'dev-core lists sync as a valid command'

    # -----------------------------------------------------------------------
    # 25. Safety: no destructive Git verbs anywhere in the repository layer
    # -----------------------------------------------------------------------
    $forbiddenArguments = @('reset', 'stash', 'clean', 'rebase', 'cherry-pick', 'revert', '-D', '--force', '-f', '--hard', '--allow-unrelated-histories')

    foreach ($module in @('repo-git.ps1', 'repo-state.ps1', 'repo-sync.ps1', 'repo-repair.ps1', 'repo-report.ps1', 'repo-ui.ps1')) {
        $content = Get-Content -LiteralPath (Join-Path $ProjectRoot "lib/$module") -Raw

        foreach ($match in [regex]::Matches($content, '-GitArgs\s+@\(([^)]*)\)')) {
            $arguments = @($match.Groups[1].Value -split ',' | ForEach-Object { $_.Trim().Trim("'").Trim('"') })

            foreach ($argument in $arguments) {
                if ($forbiddenArguments -ccontains $argument) {
                    Write-TestFailure "lib/$module invokes a forbidden Git argument: $argument"
                }
            }
        }
    }

    Write-TestPass 'The repository layer never invokes reset, stash, clean, force, or rebase'
}
catch {
    Write-TestFailure "Unhandled test error: $($_.Exception.Message)`n$($_.ScriptStackTrace)"
}
finally {
    if (Test-Path -LiteralPath $script:TestRoot) {
        # Git writes read-only objects on some platforms; clear them before removing.
        try {
            Get-ChildItem -LiteralPath $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue |
                ForEach-Object { if ($_.Attributes -band [System.IO.FileAttributes]::ReadOnly) { $_.Attributes = 'Normal' } }
        }
        catch {
            # Best effort only.
        }

        Remove-Item -LiteralPath $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path -LiteralPath $script:TestRoot) {
        Write-Host "WARN: fixture folder could not be removed: $script:TestRoot" -ForegroundColor Yellow
    }
    else {
        Write-Host ''
        Write-Host 'Fixture folder cleaned up.' -ForegroundColor DarkGray
    }
}

Write-Host ''
Write-Host 'Repository Intelligence Test Summary' -ForegroundColor Cyan
Write-Host "Passed: $script:passCount"
Write-Host "Failed: $script:failCount"

if ($script:failed) {
    Write-Host 'Result: FAIL' -ForegroundColor Red
    exit 1
}

Write-Host 'Result: PASS' -ForegroundColor Green
exit 0
