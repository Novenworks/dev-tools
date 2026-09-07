# Repository intelligence - terminal rendering and interactive flows.
#
# All Git access happens through repo-git / repo-sync / repo-repair.
# This module only formats results and drives menus.

function Get-RepositoryOutcomeSymbol {
    param([Parameter(Mandatory = $true)][string]$Outcome)

    switch ($Outcome) {
        'Updated' { return (Get-DevToolsDisplaySymbol -Name 'check-pass') }
        'Current' { return (Get-DevToolsDisplaySymbol -Name 'item-current') }
        default { return (Get-DevToolsDisplaySymbol -Name 'item-attention') }
    }
}

function Get-RepositoryOutcomeColor {
    param([Parameter(Mandatory = $true)][string]$Outcome)

    switch ($Outcome) {
        'Updated' { return 'Green' }
        'Current' { return 'DarkGray' }
        default { return 'Yellow' }
    }
}

function Format-RepositoryProgressLine {
    <#
    .SYNOPSIS
        Compact progress text for large workspaces. Pure function.
    #>
    param(
        [Parameter(Mandatory = $true)][int]$Index,
        [Parameter(Mandatory = $true)][int]$Total,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return "[$Index/$Total] Checking $Name..."
}

function Format-RepositorySyncLine {
    <#
    .SYNOPSIS
        One compact line per repository. Pure function, so wording is testable.
    #>
    param([Parameter(Mandatory = $true)]$Result)

    $symbol = Get-RepositoryOutcomeSymbol -Outcome $Result.Outcome

    switch ($Result.Outcome) {
        'Updated' {
            $commits = $Result.CommitsPulled
            if ($commits -gt 0) {
                return "$symbol Updated: $($Result.Name) ($commits commit(s))"
            }
            return "$symbol Updated: $($Result.Name)"
        }
        'Current' {
            return "$symbol Current: $($Result.Name)"
        }
        'Failed' {
            $reason = $Result.Reason
            if ([string]::IsNullOrWhiteSpace($reason)) { $reason = 'Git reported an error' }
            return "$symbol Failed: $($Result.Name) - $reason"
        }
        default {
            $reason = $Result.Reason
            if ([string]::IsNullOrWhiteSpace($reason)) { $reason = 'DevTools could not update this safely' }
            return "$symbol Skipped: $($Result.Name) - $reason"
        }
    }
}

function Clear-RepositoryProgressLine {
    param([int]$Width = 78)

    Write-Host ("`r" + (' ' * $Width) + "`r") -NoNewline
}

function Show-RepositoryProgress {
    param(
        [Parameter(Mandatory = $true)][int]$Index,
        [Parameter(Mandatory = $true)][int]$Total,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $text = Format-RepositoryProgressLine -Index $Index -Total $Total -Name $Name

    if ($text.Length -gt 74) {
        $text = $text.Substring(0, 71) + '...'
    }

    Write-Host ("`r  $text") -NoNewline -ForegroundColor DarkGray
}

function Show-RepositorySyncResultLine {
    param([Parameter(Mandatory = $true)]$Result)

    Clear-RepositoryProgressLine
    Write-Host ('  ' + (Format-RepositorySyncLine -Result $Result)) -ForegroundColor (Get-RepositoryOutcomeColor -Outcome $Result.Outcome)
}

function Show-RepositorySummaryCounts {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)]$Counts
    )

    $lines = @()
    foreach ($key in $Counts.Keys) {
        $lines += ('{0,-20}{1}' -f $key, $Counts[$key])
    }

    ShowSummary -Title $Title -Lines $lines
}

function Show-RepositoryAttentionDetail {
    <#
    .SYNOPSIS
        The richer explanation for one repository that needs attention.
    #>
    param(
        [Parameter(Mandatory = $true)]$State,
        [switch]$IncludeGitError
    )

    Write-Host ''
    Write-Host "  $($State.Name)" -ForegroundColor Cyan
    Write-Host "    Branch: $($State.BranchDisplay)" -ForegroundColor DarkGray
    Write-Host "    Status: $($State.HealthLabel)" -ForegroundColor Yellow

    if (-not [string]::IsNullOrWhiteSpace($State.Detail)) {
        Write-Host "    Detail: $($State.Detail)" -ForegroundColor DarkGray
    }

    Write-Host "    What happened: $($State.Explanation)" -ForegroundColor DarkGray
    Write-Host "    Your work: $($State.LocalWorkNote)" -ForegroundColor DarkGray
    Write-Host "    Next step: $($State.RecommendedAction)" -ForegroundColor DarkGray

    if ($IncludeGitError) {
        $gitError = $State.FetchError
        if ([string]::IsNullOrWhiteSpace($gitError)) { $gitError = $State.GitError }

        if (-not [string]::IsNullOrWhiteSpace($gitError)) {
            $firstLine = @($gitError -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
            Write-Host "    Git said: $firstLine" -ForegroundColor DarkGray
        }
    }
}

function Show-RepositoryHealthTable {
    param([AllowEmptyCollection()][array]$States = @())

    if (@($States).Count -eq 0) {
        ShowInfo 'No repositories match this view.'
        return
    }

    $rows = @($States)
    $nameWidth = [math]::Max(20, ($rows | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum)
    $branchWidth = [math]::Max(12, ($rows | ForEach-Object { $_.BranchDisplay.Length } | Measure-Object -Maximum).Maximum)
    $statusWidth = [math]::Max(14, ($rows | ForEach-Object { $_.HealthLabel.Length } | Measure-Object -Maximum).Maximum)
    $format = "  {0} {1,-$nameWidth}  {2,-$branchWidth}  {3,-$statusWidth}  {4}"

    Write-Host ($format -f ' ', 'Repository', 'Branch', 'Status', 'Detail') -ForegroundColor Cyan
    Write-Host ''

    foreach ($row in $rows) {
        if ($row.IsHealthy) {
            $symbol = Get-DevToolsDisplaySymbol -Name 'check-pass'
            $color = 'DarkGray'
        }
        else {
            $symbol = Get-DevToolsDisplaySymbol -Name 'item-attention'
            $color = 'Yellow'
        }

        Write-Host ($format -f $symbol, $row.Name, $row.BranchDisplay, $row.HealthLabel, $row.Detail) -ForegroundColor $color
    }
}

function Get-RepositoryHealthSummaryLines {
    <#
    .SYNOPSIS
        Health counts as display lines. Pure function.
    #>
    param([Parameter(Mandatory = $true)]$Summary)

    # ShowSummary takes a mandatory [string[]], which rejects empty elements,
    # so the spacer row is a single space rather than an empty string.
    return @(
        ('{0,-28}{1}' -f 'Healthy', $Summary.Healthy)
        ('{0,-28}{1}' -f 'Local changes', $Summary.Dirty)
        ('{0,-28}{1}' -f 'Behind (need pull)', $Summary.Behind)
        ('{0,-28}{1}' -f 'Ahead', $Summary.Ahead)
        ('{0,-28}{1}' -f 'Diverged', $Summary.Diverged)
        ('{0,-28}{1}' -f 'Broken upstream', $Summary.Upstream)
        ('{0,-28}{1}' -f 'Detached HEAD', $Summary.Detached)
        ('{0,-28}{1}' -f 'Conflicts', $Summary.Conflicts)
        ('{0,-28}{1}' -f 'Operation in progress', $Summary.Operation)
        ('{0,-28}{1}' -f 'Remote / fetch issues', $Summary.Remote)
        ('{0,-28}{1}' -f 'Other issues', $Summary.Other)
        ' '
        ('{0,-28}{1}' -f 'Repositories', $Summary.Total)
        ('{0,-28}{1}' -f 'Needing attention', $Summary.NeedsAttention)
    )
}

function Test-RepositoryWorkspaceReady {
    if (-not (Test-RequireGit)) { return $false }

    if (-not (Test-Path $Config.workspacePath)) {
        ShowWarning 'Your workspace folder is not set up yet.'
        ShowInfo 'Next step: run Configure first.'
        return $false
    }

    return $true
}

function Invoke-RepositoryReportExport {
    <#
    .SYNOPSIS
        Writes the diagnostic report and tells the user where it landed.
    #>
    param(
        [AllowEmptyCollection()][array]$States = @(),
        [string]$Operation = 'health',
        [switch]$Refreshed
    )

    $report = New-RepositoryReport -Operation $Operation -WorkspacePath $Config.workspacePath -States $States -Refreshed:$Refreshed
    $saved = Save-RepositoryReport -Report $report

    Write-Host ''

    if ($saved.Success) {
        ShowSuccess 'Diagnostic report saved.'
        ShowInfo $saved.JsonPath
        ShowInfo $saved.TextPath
        ShowInfo 'The .txt report is safe to paste into an assistant. Credentials are removed.'
    }
    else {
        ShowWarning 'The diagnostic report could not be saved.'
        ShowInfo $saved.Error
    }

    return $saved
}

# ---------------------------------------------------------------------------
# Sync
# ---------------------------------------------------------------------------

function Invoke-RepositorySyncFlow {
    <#
    .SYNOPSIS
        The Sync Repositories experience.
    #>
    param([switch]$SkipHeader)

    if (-not $SkipHeader) {
        ShowCommandScreen -Heading 'Sync Repositories' -Description @(
            'Refresh GitHub state and safely update repositories that can be fast-forwarded'
            'without touching local work.'
        )
    }

    if (-not (Test-RepositoryWorkspaceReady)) { return $null }

    $repos = @(Get-WorkspaceGitRepos -WorkspacePath $Config.workspacePath)

    if ($repos.Count -eq 0) {
        ShowInfo 'No repositories found yet.'
        ShowInfo 'Next step: run Clone missing repositories.'
        return $null
    }

    ShowInfo "Checking $($repos.Count) repositories. This refreshes GitHub state for each one."
    Write-Host ''

    $results = Invoke-RepositorySync -WorkspacePath $Config.workspacePath `
        -OnProgress { param($i, $t, $n) Show-RepositoryProgress -Index $i -Total $t -Name $n } `
        -OnResult { param($r) Show-RepositorySyncResultLine -Result $r }

    Clear-RepositoryProgressLine

    $summary = Get-RepositorySyncSummary -Results $results

    Show-RepositorySummaryCounts -Title 'Sync Summary' -Counts ([ordered]@{
        'Updated'          = $summary.Updated
        'Already current'  = $summary.Current
        'Local changes'    = $summary.Dirty
        'Ahead'            = $summary.Ahead
        'Diverged'         = $summary.Diverged
        'Missing upstream' = $summary.Upstream
        'Detached HEAD'    = $summary.Detached
        'Conflicts'        = $summary.Conflicts
        'In progress'      = $summary.Operation
        'Remote issues'    = $summary.Remote
        'Other issues'     = $summary.Other
    })

    Write-Host ''
    ShowInfo "Repositories needing attention: $($summary.NeedsAttention)"

    $attention = Get-RepositorySyncAttentionResults -Results $results

    if ($attention.Count -eq 0) {
        Write-Host ''
        ShowSuccess 'Every repository is current. Nothing needs your attention.'
        return $results
    }

    Invoke-RepositorySyncNextSteps -Results $results -Attention $attention
    return $results
}

function Invoke-RepositorySyncNextSteps {
    param(
        [Parameter(Mandatory = $true)][array]$Results,
        [Parameter(Mandatory = $true)][array]$Attention
    )

    while ($true) {
        Write-Host ''
        Write-Host 'What next?' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '  1  Review repositories needing attention'
        Write-Host '  2  Export diagnostic report'
        Write-Host '  3  Return'
        Write-Host ''

        $choice = Read-Host 'Choose an option'

        switch ($choice) {
            '1' {
                Write-Host ''
                Write-Host 'Repositories needing attention' -ForegroundColor Cyan

                foreach ($item in $Attention) {
                    Show-RepositoryAttentionDetail -State $item.State -IncludeGitError
                }

                Wait-ForKey -Message 'Press Enter to continue'
            }
            '2' {
                $states = @($Results | ForEach-Object { $_.State })
                Invoke-RepositoryReportExport -States $states -Operation 'sync' -Refreshed | Out-Null
                Wait-ForKey -Message 'Press Enter to continue'
            }
            '3' { return }
            default {
                ShowWarning 'Please choose 1, 2, or 3.'
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

function Invoke-RepositoryHealthFlow {
    <#
    .SYNOPSIS
        The Repository Health experience: what in my workspace needs attention?
    #>
    param([switch]$Refresh)

    if (-not (Test-RepositoryWorkspaceReady)) { return }

    $repos = @(Get-WorkspaceGitRepos -WorkspacePath $Config.workspacePath)

    if ($repos.Count -eq 0) {
        ShowInfo 'No repositories found yet.'
        ShowInfo 'Next step: run Clone missing repositories after signing in to GitHub.'
        return
    }

    $refreshed = [bool]$Refresh

    while ($true) {
        if ($refreshed) {
            ShowInfo "Refreshing GitHub state for $($repos.Count) repositories..."
        }

        $states = Get-WorkspaceRepositoryStates -WorkspacePath $Config.workspacePath -Refresh:$refreshed `
            -OnProgress { param($i, $t, $n) Show-RepositoryProgress -Index $i -Total $t -Name $n }

        Clear-RepositoryProgressLine

        $summary = Get-RepositoryStateSummary -States $states
        $filter = 'Attention'

        while ($true) {
            ShowCommandScreen -Heading 'Repository Health' -Clear -Description @(
                'What in your workspace needs attention?'
                $(if ($refreshed) { 'Remote state was refreshed for this view.' } else { 'Local view. Choose R to refresh GitHub state.' })
            )

            ShowSummary -Title 'Workspace' -Lines (Get-RepositoryHealthSummaryLines -Summary $summary)
            Write-Host ''

            $filtered = @(Select-RepositoryStatesByFilter -States $states -Filter $filter)

            if ($filter -eq 'Attention' -and $filtered.Count -eq 0) {
                ShowSuccess 'Everything looks good. No repository needs attention.'
            }
            else {
                Show-RepositoryHealthTable -States $filtered
            }

            Write-Host ''
            Write-Host 'View' -ForegroundColor Cyan
            Write-Host ''

            foreach ($definition in Get-RepositoryFilterDefinitions) {
                Write-Host "  $($definition.Key)  $($definition.Label)"
            }

            Write-Host '  9  Return'
            Write-Host ''
            Write-Host '  D  Show details for the repositories in this view'
            Write-Host '  R  Refresh GitHub state'
            Write-Host '  E  Export diagnostic report'
            Write-Host ''

            $choice = Read-Host 'Choose an option'
            if ($null -eq $choice) { $choice = '' }
            $normalized = $choice.Trim().ToUpper()

            $definition = Get-RepositoryFilterDefinitions | Where-Object { $_.Key -eq $normalized } | Select-Object -First 1

            if ($definition) {
                $filter = $definition.Filter
                continue
            }

            switch ($normalized) {
                '9' { return }
                'D' {
                    if ($filtered.Count -eq 0) {
                        ShowInfo 'Nothing to show for this view.'
                    }
                    else {
                        foreach ($state in $filtered) {
                            Show-RepositoryAttentionDetail -State $state -IncludeGitError
                        }
                    }
                    Wait-ForKey -Message 'Press Enter to continue'
                }
                'R' {
                    $refreshed = $true
                    break
                }
                'E' {
                    Invoke-RepositoryReportExport -States $states -Operation 'health' -Refreshed:$refreshed | Out-Null
                    Wait-ForKey -Message 'Press Enter to continue'
                }
                default {
                    ShowWarning 'Please choose an option from the list.'
                    Wait-ForKey -Message 'Press Enter to try again'
                }
            }

            if ($normalized -eq 'R') { break }
        }
    }
}

# ---------------------------------------------------------------------------
# Upstream repair
# ---------------------------------------------------------------------------

function Show-UpstreamRepairPlan {
    param([Parameter(Mandatory = $true)]$Plan)

    Write-Host ''
    Write-Host 'Broken Upstream' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "  Project: $($Plan.Name)" -ForegroundColor DarkGray
    Write-Host "  Current branch: $($Plan.CurrentBranch)" -ForegroundColor DarkGray
    Write-Host "  Upstream: $(if ($Plan.Upstream) { $Plan.Upstream } else { 'none' })" -ForegroundColor DarkGray
    Write-Host "  Remote branch: $(if ($Plan.RemoteDefaultExists -and $Plan.Upstream) { 'no longer exists' } else { 'not available' })" -ForegroundColor DarkGray
    Write-Host "  Default branch: $(if ($Plan.DefaultBranch) { $Plan.DefaultBranch } else { 'unknown' })" -ForegroundColor DarkGray
    Write-Host ''

    if ($Plan.CanRepair) {
        Write-Host '  Suggested repair:' -ForegroundColor Cyan
        foreach ($step in $Plan.Steps) {
            Write-Host "    $step" -ForegroundColor DarkGray
        }
    }
    else {
        ShowWarning '  DevTools will not repair this automatically.'
        foreach ($blocker in $Plan.Blockers) {
            Write-Host "    $blocker" -ForegroundColor DarkGray
        }
        Write-Host ''
        Write-Host '  Your local commits are safe. Review this repository manually.' -ForegroundColor DarkGray
    }

    Write-Host ''
}

function Invoke-UpstreamRepairFlow {
    <#
    .SYNOPSIS
        Guided, confirmation-gated repair for a repository with a broken upstream.
    #>
    param([Parameter(Mandatory = $true)]$State)

    $plan = Get-UpstreamRepairPlan -State $State
    Show-UpstreamRepairPlan -Plan $plan

    if (-not $plan.CanRepair) {
        Wait-ForKey -Message 'Press Enter to continue'
        return
    }

    Write-Host '  1  Review safety'
    Write-Host '  2  Repair'
    Write-Host '  3  Skip'
    Write-Host ''

    $choice = Read-Host 'Choose an option'

    switch ($choice) {
        '1' {
            Write-Host ''
            Write-Host '  Safety checks' -ForegroundColor Cyan
            Write-Host "    Working tree is clean: yes" -ForegroundColor DarkGray
            Write-Host "    Conflicts or operations in progress: none" -ForegroundColor DarkGray
            Write-Host "    Commits on $($plan.CurrentBranch) missing from $($plan.DefaultBranch): $($plan.UnmergedCommits)" -ForegroundColor DarkGray
            Write-Host "    Branch deletion: DevTools never deletes a branch during repair" -ForegroundColor DarkGray
            Write-Host ''

            if (-not (ShowYesNoPrompt -Prompt "Repair $($plan.Name)?" -YesLabel '[Y] Repair' -NoLabel '[N] Skip')) {
                ShowInfo 'No changes were made.'
                return
            }
        }
        '2' {
            if (-not (ShowYesNoPrompt -Prompt "Switch $($plan.Name) to $($plan.DefaultBranch)?" -YesLabel '[Y] Repair' -NoLabel '[N] Skip')) {
                ShowInfo 'No changes were made.'
                return
            }
        }
        default {
            ShowInfo 'Skipped. No changes were made.'
            return
        }
    }

    $result = Invoke-UpstreamRepair -Plan $plan

    Write-Host ''

    if ($result.Success) {
        ShowSuccess "Repaired $($plan.Name)."
        foreach ($step in $result.Steps) {
            ShowInfo $step
        }
    }
    else {
        ShowWarning "DevTools did not change $($plan.Name)."
        ShowInfo $result.Error
    }
}

# ---------------------------------------------------------------------------
# Branch cleanup
# ---------------------------------------------------------------------------

function Invoke-BranchCleanupFlow {
    <#
    .SYNOPSIS
        Safe cleanup for stale local branches, including AI agent branches.
    #>
    param([Parameter(Mandatory = $true)]$State)

    $candidates = @(Get-BranchCleanupCandidates -State $State)

    Write-Host ''
    Write-Host 'Branch Cleanup' -ForegroundColor Cyan
    Write-Host ''

    if ($candidates.Count -eq 0) {
        ShowInfo 'No stale local branches were found.'
        return
    }

    $summary = Get-BranchCleanupSummary -Candidates $candidates

    ShowInfo "$($summary.Total) stale local branch(es) found."
    ShowInfo "Safe to delete because fully merged: $($summary.SafeCount)"
    ShowInfo "Needs review: $($summary.ReviewCount)"
    Write-Host ''
    Write-Host '  1  Delete safely merged branches'
    Write-Host '  2  Review individually'
    Write-Host '  3  Cancel'
    Write-Host ''

    $choice = Read-Host 'Choose an option'

    switch ($choice) {
        '1' {
            $safe = @($candidates | Where-Object { $_.SafeToDelete })

            if ($safe.Count -eq 0) {
                ShowInfo 'No branch is provably merged, so nothing can be deleted safely.'
                return
            }

            Write-Host ''
            Write-Host '  These branches will be deleted:' -ForegroundColor Cyan
            foreach ($branch in $safe) {
                Write-Host "    $($branch.Name)" -ForegroundColor DarkGray
            }

            if (-not (ShowYesNoPrompt -Prompt "Delete $($safe.Count) merged branch(es)?" -YesLabel '[Y] Delete' -NoLabel '[N] Cancel')) {
                ShowInfo 'Cancelled. No branches were deleted.'
                return
            }

            $results = Remove-MergedBranches -RepoPath $State.Path -Candidates $safe
            Write-Host ''

            foreach ($result in $results) {
                if ($result.Deleted) {
                    ShowSuccess "  Deleted: $($result.Name)"
                }
                else {
                    ShowWarning "  Kept: $($result.Name) - $($result.Reason)"
                }
            }
        }
        '2' {
            foreach ($branch in $candidates) {
                Write-Host ''
                Write-Host "  $($branch.Name)" -ForegroundColor Cyan
                Write-Host "    Upstream: $(if ($branch.Upstream) { $branch.Upstream } else { 'none' })" -ForegroundColor DarkGray
                Write-Host "    Fully merged: $(if ($branch.IsMerged) { 'yes' } else { 'no' })" -ForegroundColor DarkGray
                Write-Host "    $($branch.Reason)" -ForegroundColor DarkGray

                if (-not $branch.SafeToDelete) {
                    ShowWarning '    DevTools will not delete this branch.'
                    continue
                }

                if (ShowYesNoPrompt -Prompt "Delete $($branch.Name)?" -YesLabel '[Y] Delete' -NoLabel '[N] Keep') {
                    $results = Remove-MergedBranches -RepoPath $State.Path -Candidates @($branch)
                    foreach ($result in $results) {
                        if ($result.Deleted) {
                            ShowSuccess "    Deleted: $($result.Name)"
                        }
                        else {
                            ShowWarning "    Kept: $($result.Name) - $($result.Reason)"
                        }
                    }
                }
                else {
                    ShowInfo "    Kept: $($branch.Name)"
                }
            }
        }
        default {
            ShowInfo 'Cancelled. No branches were deleted.'
        }
    }
}

# ---------------------------------------------------------------------------
# Single repository actions
# ---------------------------------------------------------------------------

function Show-RepositoryStateCard {
    param([Parameter(Mandatory = $true)]$State)

    Write-Host ''
    Write-Host $State.Name -ForegroundColor Cyan
    Write-Host "  Branch: $($State.BranchDisplay)" -ForegroundColor DarkGray
    Write-Host "  Default branch: $(if ($State.DefaultBranch) { $State.DefaultBranch } else { 'unknown' })" -ForegroundColor DarkGray
    Write-Host "  Upstream: $(if ($State.Upstream) { $State.Upstream } else { 'none' })" -ForegroundColor DarkGray
    Write-Host "  Status: $($State.HealthLabel)" -ForegroundColor $(if ($State.IsHealthy) { 'Green' } else { 'Yellow' })

    if (-not [string]::IsNullOrWhiteSpace($State.Detail)) {
        Write-Host "  Detail: $($State.Detail)" -ForegroundColor DarkGray
    }

    Write-Host "  Next step: $($State.RecommendedAction)" -ForegroundColor DarkGray
    Write-Host ''
}

function Invoke-RepositoryPushAction {
    <#
    .SYNOPSIS
        Pushes only after an explicit confirmation. Never force pushes.
    #>
    param([Parameter(Mandatory = $true)]$State)

    if ($State.IsDetachedHead) {
        ShowWarning 'This repository is not on a branch, so there is nothing to push.'
        return
    }

    if ($State.Ahead -le 0 -and $State.UpstreamConfigured -and $State.UpstreamExists) {
        ShowInfo 'Nothing to push. This branch matches GitHub.'
        return
    }

    if ($State.UpstreamConfigured -and $State.UpstreamExists) {
        Write-Host ''
        ShowInfo "This will push $($State.Ahead) commit(s) from $($State.CurrentBranch) to $($State.Upstream)."

        if (-not (ShowYesNoPrompt -Prompt 'Push now?' -YesLabel '[Y] Push' -NoLabel '[N] Cancel')) {
            ShowInfo 'Cancelled. Nothing was pushed.'
            return
        }

        $result = Invoke-DevToolsGit -RepoPath $State.Path -GitArgs @('push')
    }
    else {
        if ([string]::IsNullOrWhiteSpace($State.RemoteName)) {
            ShowWarning 'This repository has no remote, so DevTools cannot push.'
            return
        }

        Write-Host ''
        ShowInfo "$($State.CurrentBranch) has no upstream yet."
        ShowInfo "This will publish it to $($State.RemoteName)/$($State.CurrentBranch)."

        if (-not (ShowYesNoPrompt -Prompt 'Publish this branch?' -YesLabel '[Y] Push' -NoLabel '[N] Cancel')) {
            ShowInfo 'Cancelled. Nothing was pushed.'
            return
        }

        $result = Invoke-DevToolsGit -RepoPath $State.Path -GitArgs @('push', '-u', $State.RemoteName, $State.CurrentBranch)
    }

    if ($result.Success) {
        ShowSuccess 'Push complete.'
    }
    else {
        ShowWarning 'The push did not complete.'
        ShowInfo (@($result.Lines) | Select-Object -First 1)
    }
}

function Show-RepositoryBranches {
    param([Parameter(Mandatory = $true)]$State)

    $result = Invoke-DevToolsGit -RepoPath $State.Path -GitArgs @('for-each-ref', '--sort=-committerdate', '--format=%(refname:short)|%(upstream:short)|%(upstream:track)', 'refs/heads')

    Write-Host ''
    Write-Host 'Branches' -ForegroundColor Cyan
    Write-Host ''

    if (-not $result.Success) {
        ShowWarning 'DevTools could not list branches for this repository.'
        return
    }

    foreach ($line in $result.Lines) {
        $parts = $line -split '\|', 3
        $name = $parts[0]
        $upstream = ''
        if ($parts.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace($parts[1])) { $upstream = $parts[1] }
        $track = ''
        if ($parts.Count -gt 2) { $track = $parts[2] }

        $marker = '  '
        if ($name -eq $State.CurrentBranch) { $marker = '* ' }

        $detail = 'no upstream'
        if ($upstream) {
            $detail = $upstream
            if ($track -match '(?i)gone') { $detail = "$upstream (gone)" }
        }

        Write-Host "  $marker$name  -  $detail" -ForegroundColor DarkGray
    }
}

function Invoke-RepositoryActionsMenu {
    <#
    .SYNOPSIS
        Focused maintenance actions for a single repository.
    #>
    param([Parameter(Mandatory = $true)]$Project)

    if (-not (Test-ProjectIsGitRepo -Path $Project.FullName)) {
        ShowWarning 'This folder is not a Git repository.'
        Wait-ForKey -Message 'Press Enter to continue'
        return
    }

    $facts = Get-RepositoryFacts -RepoPath $Project.FullName -Name $Project.Name
    $state = Get-RepositoryState -Facts $facts

    while ($true) {
        ShowCommandScreen -Heading 'Repository Actions' -Clear -Description @(
            'Inspect and maintain a single repository.'
        )

        Show-RepositoryStateCard -State $state

        Write-Host 'Actions' -ForegroundColor Cyan
        Write-Host ''
        Write-Host "  1   Open in $(Get-EditorDisplayName -Editor $Config.defaultEditor)"
        Write-Host '  2   Open folder'
        Write-Host '  3   Open on GitHub'
        Write-Host '  4   Repository health'
        Write-Host '  5   Refresh remote status'
        Write-Host '  6   Fetch'
        Write-Host '  7   Pull (fast-forward only)'
        Write-Host '  8   Push'
        Write-Host '  9   Switch to default branch'
        Write-Host '  10  View branches'
        Write-Host '  11  Repair upstream'
        Write-Host '  12  Clean merged branches'
        Write-Host '  13  Export diagnostic report'
        Write-Host '  14  Return'
        Write-Host ''

        $choice = Read-Host 'Choose an option'
        $refresh = $false

        switch ($choice) {
            '1' {
                Open-ProjectWithEditor -Project $Project
                return
            }
            '2' {
                ShowInfo "Opening $($Project.Name) in Explorer..."
                explorer $Project.FullName
                Wait-ForKey -Message 'Press Enter to continue'
            }
            '3' {
                $webUrl = ConvertTo-GitHubWebUrl -RemoteUrl $state.RemoteUrl
                if ($webUrl) {
                    ShowInfo 'Opening GitHub repository in your browser...'
                    Start-Process $webUrl
                }
                else {
                    ShowWarning 'No GitHub remote URL was found for this repository.'
                }
                Wait-ForKey -Message 'Press Enter to continue'
            }
            '4' {
                Show-RepositoryAttentionDetail -State $state -IncludeGitError
                Wait-ForKey -Message 'Press Enter to continue'
            }
            '5' { $refresh = $true }
            '6' {
                if ([string]::IsNullOrWhiteSpace($state.RemoteName)) {
                    ShowWarning 'This repository has no remote to fetch from.'
                }
                else {
                    ShowInfo 'Refreshing remote state...'
                    $fetch = Invoke-RepositoryFetch -RepoPath $state.Path -RemoteName $state.RemoteName

                    if ($fetch.Success) {
                        ShowSuccess 'Remote state refreshed.'
                    }
                    else {
                        ShowWarning 'DevTools could not refresh the remote state.'
                        ShowInfo (@($fetch.Lines) | Select-Object -First 1)
                    }
                }

                Wait-ForKey -Message 'Press Enter to continue'
                $refresh = $true
            }
            '7' {
                $result = Invoke-RepositorySyncForState -State $state
                Write-Host ''

                switch ($result.Outcome) {
                    'Updated' { ShowSuccess "Updated $($result.Name) by $($result.CommitsPulled) commit(s)." }
                    'Current' { ShowInfo 'Already current.' }
                    'Failed' { ShowWarning "Not updated - $($result.Reason)" }
                    default {
                        ShowWarning "Skipped - $($result.Reason)"
                        ShowInfo $state.RecommendedAction
                    }
                }

                Wait-ForKey -Message 'Press Enter to continue'
                $refresh = $true
            }
            '8' {
                Invoke-RepositoryPushAction -State $state
                Wait-ForKey -Message 'Press Enter to continue'
                $refresh = $true
            }
            '9' {
                if ([string]::IsNullOrWhiteSpace($state.DefaultBranch)) {
                    ShowWarning 'DevTools could not determine the default branch.'
                }
                elseif ($state.CurrentBranch -eq $state.DefaultBranch) {
                    ShowInfo "Already on $($state.DefaultBranch)."
                }
                elseif ($state.IsDirty -or $state.HasConflicts) {
                    ShowWarning 'This repository has uncommitted changes.'
                    ShowInfo 'Review or commit them first. DevTools will not switch branches and risk local work.'
                }
                elseif (ShowYesNoPrompt -Prompt "Switch to $($state.DefaultBranch)?" -YesLabel '[Y] Switch' -NoLabel '[N] Cancel') {
                    $checkout = Invoke-DevToolsGit -RepoPath $state.Path -GitArgs @('checkout', $state.DefaultBranch)

                    if ($checkout.Success) {
                        ShowSuccess "Switched to $($state.DefaultBranch)."
                    }
                    else {
                        ShowWarning 'DevTools could not switch branches.'
                        ShowInfo (@($checkout.Lines) | Select-Object -First 1)
                    }
                }

                Wait-ForKey -Message 'Press Enter to continue'
                $refresh = $true
            }
            '10' {
                Show-RepositoryBranches -State $state
                Wait-ForKey -Message 'Press Enter to continue'
            }
            '11' {
                Invoke-UpstreamRepairFlow -State $state
                Wait-ForKey -Message 'Press Enter to continue'
                $refresh = $true
            }
            '12' {
                Invoke-BranchCleanupFlow -State $state
                Wait-ForKey -Message 'Press Enter to continue'
                $refresh = $true
            }
            '13' {
                Invoke-RepositoryReportExport -States @($state) -Operation 'repository' -Refreshed:$state.FetchAttempted | Out-Null
                Wait-ForKey -Message 'Press Enter to continue'
            }
            '14' { return }
            default {
                ShowWarning 'Please choose a number from the menu.'
                Wait-ForKey -Message 'Press Enter to try again'
            }
        }

        if ($refresh) {
            $facts = Get-RepositoryFacts -RepoPath $Project.FullName -Name $Project.Name -Refresh:($choice -eq '5')
            $state = Get-RepositoryState -Facts $facts
        }
    }
}

function Invoke-RepositoryActionsFlow {
    param([string]$ProjectQuery = '')

    $project = $null

    if (-not [string]::IsNullOrWhiteSpace($ProjectQuery)) {
        $resolved = Resolve-ProjectFromQuery -Query $ProjectQuery
        $results = @($resolved.Projects)

        if ($results.Count -eq 1) {
            $project = $results[0]
        }
        elseif ($results.Count -gt 1) {
            ShowCommandScreen -Heading 'Repository Actions' -Description @('Multiple projects matched.')
            $project = Select-ProjectFromResults -Results $results -Prompt 'Select a project:'
        }
        else {
            ShowWarning "No projects found for `"$ProjectQuery`"."
            return
        }
    }
    else {
        $project = Select-Project -Heading 'Repository Actions' -Description @(
            'Which repository do you want to work on?'
            'Search by project name, or press Enter to list all projects.'
        )
    }

    if (-not $project) { return }

    Invoke-RepositoryActionsMenu -Project $project
}

# ---------------------------------------------------------------------------
# Repository maintenance menu
# ---------------------------------------------------------------------------

function Invoke-RepositoryMaintenanceMenu {
    <#
    .SYNOPSIS
        One place for workspace-wide repository work.
    #>

    while ($true) {
        ShowCommandScreen -Heading 'Repository Maintenance' -Clear -Description @(
            'Keep a large workspace healthy without risking local work.'
        )

        Write-Host '  1  Sync repositories'
        Write-Host '  2  Repository health'
        Write-Host '  3  Review repositories needing attention'
        Write-Host '  4  Repair broken upstreams'
        Write-Host '  5  Branch cleanup'
        Write-Host '  6  Export diagnostic report'
        Write-Host '  7  Repository actions (single repository)'
        Write-Host '  8  Return'
        Write-Host ''

        $choice = Read-Host 'Choose an option'

        switch ($choice) {
            '1' {
                Invoke-RepositorySyncFlow | Out-Null
                Wait-ForKey
            }
            '2' { Invoke-RepositoryHealthFlow }
            '3' {
                if (Test-RepositoryWorkspaceReady) {
                    ShowInfo 'Reading local repository state...'
                    $states = @(Get-WorkspaceRepositoryStates -WorkspacePath $Config.workspacePath `
                        -OnProgress { param($i, $t, $n) Show-RepositoryProgress -Index $i -Total $t -Name $n })
                    Clear-RepositoryProgressLine

                    $attention = @(Select-RepositoryStatesByFilter -States $states -Filter 'Attention')

                    if ($attention.Count -eq 0) {
                        ShowSuccess 'Everything looks good. No repository needs attention.'
                    }
                    else {
                        foreach ($state in $attention) {
                            Show-RepositoryAttentionDetail -State $state -IncludeGitError
                        }
                    }
                }

                Wait-ForKey
            }
            '4' { Invoke-UpstreamRepairWorkspaceFlow }
            '5' {
                $project = Select-Project -Heading 'Branch Cleanup' -Description @(
                    'Which repository do you want to clean up?'
                )

                if ($project) {
                    $facts = Get-RepositoryFacts -RepoPath $project.FullName -Name $project.Name -Refresh
                    $state = Get-RepositoryState -Facts $facts
                    Invoke-BranchCleanupFlow -State $state
                    Wait-ForKey
                }
            }
            '6' {
                if (Test-RepositoryWorkspaceReady) {
                    ShowInfo 'Refreshing GitHub state for the report...'
                    $states = @(Get-WorkspaceRepositoryStates -WorkspacePath $Config.workspacePath -Refresh `
                        -OnProgress { param($i, $t, $n) Show-RepositoryProgress -Index $i -Total $t -Name $n })
                    Clear-RepositoryProgressLine
                    Invoke-RepositoryReportExport -States $states -Operation 'health' -Refreshed | Out-Null
                }

                Wait-ForKey
            }
            '7' {
                Invoke-RepositoryActionsFlow
            }
            '8' { return }
            default {
                ShowWarning 'Please choose a number from the menu.'
                Wait-ForKey -Message 'Press Enter to try again'
            }
        }
    }
}

function Invoke-UpstreamRepairWorkspaceFlow {
    <#
    .SYNOPSIS
        Walks every repository whose upstream is broken and offers a guided repair.
    #>

    if (-not (Test-RepositoryWorkspaceReady)) { return }

    ShowInfo 'Refreshing GitHub state to find broken upstreams...'

    $states = @(Get-WorkspaceRepositoryStates -WorkspacePath $Config.workspacePath -Refresh `
        -OnProgress { param($i, $t, $n) Show-RepositoryProgress -Index $i -Total $t -Name $n })

    Clear-RepositoryProgressLine

    $broken = @(Select-RepositoryStatesByFilter -States $states -Filter 'Upstream')

    Write-Host ''

    if ($broken.Count -eq 0) {
        ShowSuccess 'No repository has a broken upstream.'
        Wait-ForKey
        return
    }

    ShowInfo "$($broken.Count) repository(ies) have a broken upstream."

    foreach ($state in $broken) {
        Invoke-UpstreamRepairFlow -State $state
    }

    Wait-ForKey
}
