# Repository intelligence - diagnostic report generation.
#
# Reports are written to the gitignored reports/repositories folder.
# Remote URLs are sanitized so credentials and tokens are never written to disk.

function Get-RepositoryReportDirectory {
    return Join-Path $DevToolsRoot 'reports\repositories'
}

function Get-RepositoryReportPath {
    param([string]$Extension = 'json')
    return Join-Path (Get-RepositoryReportDirectory) "latest.$Extension"
}

function ConvertTo-RepositoryReportEntry {
    <#
    .SYNOPSIS
        Converts one repository state into a report-safe record. Pure function.
    #>
    param([Parameter(Mandatory = $true)]$State)

    $gitError = $State.FetchError
    if ([string]::IsNullOrWhiteSpace($gitError)) { $gitError = $State.GitError }
    if ($null -eq $gitError) { $gitError = '' }

    # Keep the underlying Git message useful but bounded, and never leak credentials.
    $gitError = Get-SanitizedRemoteUrl -Url $gitError
    if ($gitError.Length -gt 500) {
        $gitError = $gitError.Substring(0, 500) + '...'
    }

    return [ordered]@{
        name                = $State.Name
        path                = $State.Path
        isGitRepository     = [bool]$State.IsGitRepository
        branch              = $State.BranchDisplay
        detachedHead        = [bool]$State.IsDetachedHead
        defaultBranch       = $State.DefaultBranch
        remote              = $State.RemoteName
        remoteUrl           = (Get-SanitizedRemoteUrl -Url $State.RemoteUrl)
        upstream            = $State.Upstream
        upstreamConfigured  = [bool]$State.UpstreamConfigured
        upstreamExists      = [bool]$State.UpstreamExists
        workingTree         = $(if ($State.IsDirty) { 'dirty' } else { 'clean' })
        modifiedFiles       = [int]$State.ModifiedFilesCount
        untrackedFiles      = [int]$State.UntrackedFilesCount
        conflicts           = [bool]$State.HasConflicts
        conflictFiles       = [int]$State.ConflictFilesCount
        mergeInProgress     = [bool]$State.MergeInProgress
        rebaseInProgress    = [bool]$State.RebaseInProgress
        ahead               = [int]$State.Ahead
        behind              = [int]$State.Behind
        diverged            = [bool]$State.IsDiverged
        fetchAttempted      = [bool]$State.FetchAttempted
        fetchSucceeded      = [bool]$State.FetchSucceeded
        health              = $State.HealthCode
        healthLabel         = $State.HealthLabel
        severity            = $State.HealthSeverity
        canFastForward      = [bool]$State.CanFastForward
        recommendedAction   = $State.RecommendedAction
        explanation         = $State.Explanation
        gitError            = $gitError
    }
}

function New-RepositoryReport {
    <#
    .SYNOPSIS
        Builds the machine-readable repository diagnostic report. Pure function.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Operation,
        [string]$WorkspacePath = '',
        [AllowEmptyCollection()][array]$States = @(),
        [switch]$Refreshed
    )

    $summary = Get-RepositoryStateSummary -States $States
    $summaryObject = [ordered]@{}
    foreach ($key in $summary.Keys) {
        $summaryObject[$key] = $summary[$key]
    }

    $entries = @()
    foreach ($state in @($States)) {
        $entries += ConvertTo-RepositoryReportEntry -State $state
    }

    return [ordered]@{
        generatedAt     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        devToolsVersion = (Get-DevToolsVersion)
        operation       = $Operation
        workspacePath   = $WorkspacePath
        remoteRefreshed = [bool]$Refreshed
        summary         = $summaryObject
        repositories    = $entries
    }
}

function ConvertTo-RepositoryReportText {
    <#
    .SYNOPSIS
        Renders a Markdown-style report that is easy to paste into an assistant.
    #>
    param([Parameter(Mandatory = $true)]$Report)

    $lines = @()
    $lines += "# DevTools Repository Report"
    $lines += ''
    $lines += "Generated: $($Report.generatedAt)"
    $lines += "DevTools: v$($Report.devToolsVersion)"
    $lines += "Operation: $($Report.operation)"
    $lines += "Workspace: $($Report.workspacePath)"
    $lines += "Remote refreshed: $(if ($Report.remoteRefreshed) { 'yes' } else { 'no' })"
    $lines += ''
    $lines += '## Summary'
    $lines += ''

    foreach ($key in $Report.summary.Keys) {
        $lines += "- $key`: $($Report.summary[$key])"
    }

    $attention = @($Report.repositories | Where-Object { $_.severity -ne 'Healthy' })

    $lines += ''
    $lines += '## Repositories needing attention'
    $lines += ''

    if ($attention.Count -eq 0) {
        $lines += 'None. Every repository is current.'
    }

    foreach ($entry in $attention) {
        $lines += "### $($entry.name)"
        $lines += ''
        $lines += "- Health: $($entry.healthLabel) ($($entry.health))"
        $lines += "- Branch: $($entry.branch)"
        $lines += "- Default branch: $($entry.defaultBranch)"
        $lines += "- Upstream: $(if ($entry.upstream) { $entry.upstream } else { 'none' })"
        $lines += "- Upstream exists: $($entry.upstreamExists)"
        $lines += "- Remote: $(if ($entry.remote) { $entry.remote } else { 'none' })"
        $lines += "- Working tree: $($entry.workingTree) (modified $($entry.modifiedFiles), untracked $($entry.untrackedFiles))"
        $lines += "- Ahead/behind: $($entry.ahead)/$($entry.behind)"
        $lines += "- Conflicts: $($entry.conflicts)"
        $lines += "- Operation in progress: merge=$($entry.mergeInProgress) rebase=$($entry.rebaseInProgress)"
        $lines += "- Fetch succeeded: $($entry.fetchSucceeded)"
        $lines += "- Explanation: $($entry.explanation)"
        $lines += "- Recommended action: $($entry.recommendedAction)"

        if (-not [string]::IsNullOrWhiteSpace($entry.gitError)) {
            $lines += "- Git error: $($entry.gitError)"
        }

        $lines += ''
    }

    $healthy = @($Report.repositories | Where-Object { $_.severity -eq 'Healthy' })

    $lines += '## Healthy repositories'
    $lines += ''

    if ($healthy.Count -eq 0) {
        $lines += 'None.'
    }
    else {
        foreach ($entry in $healthy) {
            $lines += "- $($entry.name) ($($entry.branch))"
        }
    }

    $lines += ''

    return ($lines -join [Environment]::NewLine)
}

function Save-RepositoryReport {
    <#
    .SYNOPSIS
        Writes latest.json and latest.txt into the gitignored reports folder.
    #>
    param(
        [Parameter(Mandatory = $true)]$Report,
        [string]$Directory = ''
    )

    try {
        if ([string]::IsNullOrWhiteSpace($Directory)) {
            $Directory = Get-RepositoryReportDirectory
        }

        if (-not (Test-Path -LiteralPath $Directory)) {
            New-Item -ItemType Directory -Path $Directory -Force | Out-Null
        }

        $jsonPath = Join-Path $Directory 'latest.json'
        $textPath = Join-Path $Directory 'latest.txt'

        ($Report | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $jsonPath -Encoding UTF8
        (ConvertTo-RepositoryReportText -Report $Report) | Set-Content -LiteralPath $textPath -Encoding UTF8

        return [pscustomobject]@{
            Success  = $true
            JsonPath = $jsonPath
            TextPath = $textPath
            Error    = ''
        }
    }
    catch {
        return [pscustomobject]@{
            Success  = $false
            JsonPath = ''
            TextPath = ''
            Error    = $_.Exception.Message
        }
    }
}
