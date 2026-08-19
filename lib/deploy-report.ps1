# Deployment Manager — terminal output and machine-readable reports.

function Get-DeploymentReportDirectory {
    return Join-Path $DevToolsRoot 'reports\deployments'
}

function Get-DeploymentReportPath {
    return Join-Path (Get-DeploymentReportDirectory) 'latest.json'
}

function ConvertTo-DeployDisplayWidth {
    <#
    .SYNOPSIS
        Truncates a value so wide repository names never break table layout.
    #>
    param([string]$Value, [int]$Width)

    if ($null -eq $Value) { $Value = '' }

    if ($Value.Length -le $Width) {
        return $Value.PadRight($Width)
    }

    if ($Width -le 3) {
        return $Value.Substring(0, $Width)
    }

    return ($Value.Substring(0, $Width - 3) + '...')
}

function Get-DeploymentConnectionLabel {
    param([Parameter(Mandatory = $true)]$Candidate)

    switch ([string]$Candidate.Status) {
        'MISSING_VERCEL_PROJECT' { return 'Missing' }
        'AMBIGUOUS_MATCH' { return 'Ambiguous' }
        'NOT_DEPLOYABLE' { return 'Not deployable' }
        'SKIPPED' { return 'Skipped' }
        'AUTH_REQUIRED' { return 'Sign-in needed' }
        'GIT_NOT_CONNECTED' { return 'Not connected' }
        default {
            if (-not [string]::IsNullOrWhiteSpace([string]$Candidate.VercelProjectName)) {
                return 'Connected'
            }

            return 'Unknown'
        }
    }
}

function Get-DeploymentProductionLabel {
    param([Parameter(Mandatory = $true)]$Candidate)

    switch ([string]$Candidate.Status) {
        'READY' { return 'READY' }
        'DEPLOYMENT_FAILED' { return 'FAILED' }
        'DEPLOYMENT_BUILDING' { return 'BUILDING' }
        'DEPLOYMENT_TIMEOUT' { return 'TIMED OUT' }
        'CREATED' { return 'CREATED' }
        'CREATED_AND_DEPLOYED' { return 'READY' }
        'PRODUCTION_BRANCH_MISMATCH' { return 'BRANCH' }
        default { return '-' }
    }
}

function Get-DeploymentRowColor {
    param([Parameter(Mandatory = $true)]$Candidate)

    switch ([string]$Candidate.Status) {
        'READY' { return 'Green' }
        'CREATED_AND_DEPLOYED' { return 'Green' }
        'SKIPPED' { return 'DarkGray' }
        'NOT_DEPLOYABLE' { return 'DarkGray' }
        default { return 'Yellow' }
    }
}

function Show-DeploymentTable {
    <#
    .SYNOPSIS
        Renders the Repository / Vercel / Production overview table.
    #>
    param(
        [AllowEmptyCollection()][array]$Candidates = @()
    )

    $rows = @($Candidates)
    if ($rows.Count -eq 0) {
        ShowInfo 'No deployment candidates to show.'
        return
    }

    $nameWidth = 34
    $connectionWidth = 16
    $productionWidth = 12
    $format = "  {0} {1}  {2}  {3}"

    Write-Host ($format -f ' ', (ConvertTo-DeployDisplayWidth 'Repository' $nameWidth), (ConvertTo-DeployDisplayWidth 'Vercel' $connectionWidth), (ConvertTo-DeployDisplayWidth 'Production' $productionWidth)) -ForegroundColor Cyan
    Write-Host ''

    foreach ($candidate in $rows) {
        $icon = if ([string]$candidate.Status -in @('READY', 'CREATED_AND_DEPLOYED')) {
            Get-UiIcon -Name 'ready'
        }
        elseif ([string]$candidate.Status -in @('SKIPPED', 'NOT_DEPLOYABLE')) {
            ' '
        }
        else {
            Get-UiIcon -Name 'attention'
        }

        Write-Host ($format -f `
                $icon, `
            (ConvertTo-DeployDisplayWidth $candidate.GithubRepo $nameWidth), `
            (ConvertTo-DeployDisplayWidth (Get-DeploymentConnectionLabel -Candidate $candidate) $connectionWidth), `
            (ConvertTo-DeployDisplayWidth (Get-DeploymentProductionLabel -Candidate $candidate) $productionWidth)) `
            -ForegroundColor (Get-DeploymentRowColor -Candidate $candidate)
    }

    Write-Host ''
}

function Show-DeploymentPortfolioSummary {
    <#
    .SYNOPSIS
        Renders the "Deployment Portfolio" counts block.
    #>
    param(
        [AllowEmptyCollection()][array]$Candidates = @(),
        [string]$Title = 'Deployment Portfolio'
    )

    $summary = Get-DeploymentSummary -Candidates $Candidates
    $lines = @()

    foreach ($status in $summary.Keys) {
        $label = (Get-DeploymentStatusLabel -Status $status).ToUpperInvariant()
        $lines += ('{0} {1}' -f $label.PadRight(30), $summary[$status])
    }

    $lines += ('-' * 38)
    $lines += ('{0} {1}' -f 'TOTAL CANDIDATES'.PadRight(30), @($Candidates).Count)

    ShowSummary -Title $Title -Lines $lines
}

function Show-DeploymentAttention {
    <#
    .SYNOPSIS
        Renders the problem-focused "Needs Attention" section.
    #>
    param(
        [AllowEmptyCollection()][array]$Candidates = @()
    )

    $healthy = @('READY', 'SKIPPED', 'NOT_DEPLOYABLE', 'CREATED_AND_DEPLOYED')
    $problems = @($Candidates | Where-Object { [string]$_.Status -notin $healthy })

    Write-Host ''

    if ($problems.Count -eq 0) {
        ShowSuccess 'Nothing needs attention. Every deployment candidate is healthy.'
        return
    }

    Write-Host 'Needs Attention' -ForegroundColor Cyan
    Write-Host ''

    foreach ($candidate in $problems) {
        Write-Host "  $($candidate.GithubRepo)" -ForegroundColor Yellow
        Write-Host "    $($candidate.Status)" -ForegroundColor DarkGray

        $detail = [string]$candidate.Detail
        if (-not [string]::IsNullOrWhiteSpace($detail)) {
            Write-Host "    $detail" -ForegroundColor DarkGray
        }

        if (@($candidate.MatchCandidates).Count -gt 1) {
            foreach ($name in @($candidate.MatchCandidates)) {
                Write-Host "      $name" -ForegroundColor DarkGray
            }
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$candidate.Error)) {
            Write-Host "    $($candidate.Error)" -ForegroundColor DarkGray
        }

        Write-Host ''
    }
}

function ConvertTo-DeploymentReportObject {
    <#
    .SYNOPSIS
        Builds the machine-readable report payload.
    .DESCRIPTION
        Contains no tokens, no authorization headers, and no repository contents.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Operation,
        [string[]]$Owners = @(),
        [AllowEmptyCollection()][array]$Candidates = @(),
        [int]$RepositoriesDiscovered = 0,
        [string[]]$Warnings = @()
    )

    $summary = Get-DeploymentSummary -Candidates $Candidates
    $summaryObject = [ordered]@{}
    foreach ($key in $summary.Keys) {
        $summaryObject[$key] = $summary[$key]
    }

    $repositories = @()
    foreach ($candidate in @($Candidates)) {
        $repositories += [ordered]@{
            githubOwner       = $candidate.GithubOwner
            githubRepo        = $candidate.GithubRepo
            defaultBranch     = $candidate.DefaultBranch
            productionBranch  = $candidate.ProductionBranch
            eligible          = $candidate.Eligible
            eligibilityReason = $candidate.EligibilityReason
            deployable        = $candidate.Deployable
            framework         = $candidate.Framework
            proposedProject   = $candidate.ProposedProject
            vercelProjectId   = $candidate.VercelProjectId
            vercelProjectName = $candidate.VercelProjectName
            matchMethod       = $candidate.MatchMethod
            matchCandidates   = @($candidate.MatchCandidates)
            productionUrl     = $candidate.ProductionUrl
            deploymentId      = $candidate.DeploymentId
            deploymentState   = $candidate.DeploymentState
            httpStatus        = $candidate.HttpStatus
            status            = $candidate.Status
            detail            = $candidate.Detail
            error             = $candidate.Error
        }
    }

    return [ordered]@{
        generatedAt            = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        devToolsVersion        = (Get-DevToolsVersion)
        operation              = $Operation
        provider               = 'vercel'
        githubOwners           = @($Owners)
        repositoriesDiscovered = $RepositoriesDiscovered
        warnings               = @($Warnings)
        summary                = $summaryObject
        repositories           = $repositories
    }
}

function Save-DeploymentReport {
    <#
    .SYNOPSIS
        Writes the JSON report to the local, gitignored reports folder.
    #>
    param(
        [Parameter(Mandatory = $true)]$Report
    )

    try {
        $directory = Get-DeploymentReportDirectory
        Ensure-Directory -Path $directory

        $path = Get-DeploymentReportPath
        $json = $Report | ConvertTo-Json -Depth 8
        Set-Content -Path $path -Value $json -Encoding UTF8

        return [pscustomobject]@{ Success = $true; Path = $path; Error = $null }
    }
    catch {
        return [pscustomobject]@{ Success = $false; Path = $null; Error = $_.Exception.Message }
    }
}

function Show-DeploymentReportLocation {
    param($SaveResult)

    if (-not $SaveResult) { return }

    Write-Host ''

    if ($SaveResult.Success) {
        ShowSection -Label 'Report'
        ShowInfo $SaveResult.Path
    }
    else {
        ShowWarning 'The deployment report could not be saved.'
        ShowInfo $SaveResult.Error
    }
}
