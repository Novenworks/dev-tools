# Deployment Manager — repository/project matching and status classification.
#
# Pure logic only. No network, no file system, no prompts. Every function here is
# exercised directly by tests/Test-Deploy.ps1.

function Get-DeploymentStatusCatalog {
    <#
    .SYNOPSIS
        Beginner-friendly copy for each deployment status.
    #>
    return @{
        'READY'                      = @{ Label = 'Ready';                    Summary = 'Already deployed and healthy. No action needed.' }
        'MISSING_VERCEL_PROJECT'     = @{ Label = 'Missing Vercel project';   Summary = 'This repository is not on Vercel yet.' }
        'NO_PRODUCTION_DEPLOYMENT'   = @{ Label = 'No production deployment'; Summary = 'The Vercel project exists but has never deployed to production.' }
        'DEPLOYMENT_FAILED'          = @{ Label = 'Deployment failed';        Summary = 'The last production deployment did not finish successfully.' }
        'DEPLOYMENT_BUILDING'        = @{ Label = 'Deployment building';      Summary = 'A production deployment is still building.' }
        'GIT_NOT_CONNECTED'          = @{ Label = 'Git not connected';        Summary = 'The Vercel project is not connected to a GitHub repository.' }
        'PRODUCTION_BRANCH_MISMATCH' = @{ Label = 'Branch mismatch';          Summary = 'Vercel deploys production from a different branch than expected.' }
        'NOT_DEPLOYABLE'             = @{ Label = 'Not deployable';           Summary = 'No deployable web application was detected.' }
        'SKIPPED'                    = @{ Label = 'Skipped';                  Summary = 'Skipped by the deployment eligibility rules.' }
        'AMBIGUOUS_MATCH'            = @{ Label = 'Ambiguous match';          Summary = 'More than one Vercel project could belong to this repository.' }
        'AUTH_REQUIRED'              = @{ Label = 'Sign-in required';         Summary = 'Vercel authentication is required before this can be checked.' }
        'UNKNOWN'                    = @{ Label = 'Unknown';                  Summary = 'DevTools could not determine the deployment state.' }
        'CREATED'                    = @{ Label = 'Created';                  Summary = 'Vercel project created and connected to GitHub.' }
        'CREATED_AND_DEPLOYED'       = @{ Label = 'Created and deployed';     Summary = 'Vercel project created and production deployment succeeded.' }
        'DEPLOYMENT_TIMEOUT'         = @{ Label = 'Deployment timed out';     Summary = 'The deployment was still running when DevTools stopped waiting.' }
        'ACTION_FAILED'              = @{ Label = 'Action failed';            Summary = 'DevTools could not complete the requested change.' }
    }
}

function Get-DeploymentStatusLabel {
    param([string]$Status)

    $catalog = Get-DeploymentStatusCatalog
    if ($catalog.ContainsKey($Status)) {
        return $catalog[$Status].Label
    }

    return $Status
}

function Get-DeploymentStatusSummary {
    param([string]$Status)

    $catalog = Get-DeploymentStatusCatalog
    if ($catalog.ContainsKey($Status)) {
        return $catalog[$Status].Summary
    }

    return 'No additional detail available.'
}

function Test-VercelRandomSuffix {
    <#
    .SYNOPSIS
        Returns true when a trailing segment looks like a Vercel-generated suffix.
    .EXAMPLE
        good-quality-hvac-demo-8lrn  ->  '8lrn' is a generated suffix
    #>
    param([string]$Segment)

    if ([string]::IsNullOrWhiteSpace($Segment)) {
        return $false
    }

    return [bool]($Segment -match '^[a-z0-9]{3,10}$' -and $Segment -match '\d')
}

function Find-VercelProjectMatch {
    <#
    .SYNOPSIS
        Matches one GitHub repository against the known Vercel projects.
    .DESCRIPTION
        Priority:
          1. GitHub Git-integration metadata on the Vercel project (definitive)
          2. Explicit mapping stored in DevTools configuration
          3. A single, unambiguous normalized project-name match
          4. Otherwise the result is Ambiguous or None

        Normalized-name matching is deliberately conservative: when a suffixed
        sibling project also exists (for example "site-demo" and "site-demo-8lrn")
        DevTools reports ambiguity instead of guessing, because guessing wrong
        would attach a repository to somebody else's live project.
    #>
    param(
        [Parameter(Mandatory = $true)]$Repository,
        [AllowEmptyCollection()][array]$Projects = @(),
        $Mappings,
        [string[]]$ExcludeProjectIds = @(),
        [switch]$GitIntegrationOnly
    )

    $projects = @($Projects | Where-Object { $_ })
    $excluded = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($id in @($ExcludeProjectIds)) {
        if (-not [string]::IsNullOrWhiteSpace($id)) { $null = $excluded.Add($id) }
    }

    $linked = @($projects | Where-Object {
        $_.GitType -eq 'github' -and
        -not [string]::IsNullOrWhiteSpace($_.GitOwner) -and
        [string]$_.GitOwner -ieq [string]$Repository.Owner -and
        [string]$_.GitRepo -ieq [string]$Repository.Name
    })

    if ($linked.Count -eq 1) {
        return [pscustomobject]@{
            Method     = 'GitIntegration'
            Project    = $linked[0]
            Candidates = @($linked)
            Reason     = 'Matched by Vercel Git integration metadata.'
        }
    }

    if ($linked.Count -gt 1) {
        return [pscustomobject]@{
            Method     = 'Ambiguous'
            Project    = $null
            Candidates = @($linked)
            Reason     = "$($linked.Count) Vercel projects are connected to this repository."
        }
    }

    if ($GitIntegrationOnly) {
        return [pscustomobject]@{ Method = 'None'; Project = $null; Candidates = @(); Reason = 'No Git integration match.' }
    }

    if ($Mappings) {
        $table = ConvertTo-DeployLookupTable $Mappings

        foreach ($key in @([string]$Repository.FullName, [string]$Repository.Name)) {
            if ([string]::IsNullOrWhiteSpace($key) -or -not $table.ContainsKey($key)) { continue }

            $target = [string]$table[$key]
            if ([string]::IsNullOrWhiteSpace($target)) { continue }

            $mapped = @($projects | Where-Object {
                ([string]$_.Name -ieq $target) -or ([string]$_.Id -ieq $target)
            })

            if ($mapped.Count -eq 1) {
                return [pscustomobject]@{
                    Method     = 'ExplicitMapping'
                    Project    = $mapped[0]
                    Candidates = @($mapped)
                    Reason     = 'Matched by an explicit mapping in deployment configuration.'
                }
            }

            if ($mapped.Count -eq 0) {
                return [pscustomobject]@{
                    Method     = 'None'
                    Project    = $null
                    Candidates = @()
                    Reason     = "Configured Vercel project '$target' was not found."
                }
            }

            return [pscustomobject]@{
                Method     = 'Ambiguous'
                Project    = $null
                Candidates = @($mapped)
                Reason     = "Configured mapping '$target' matches more than one Vercel project."
            }
        }
    }

    $slug = ConvertTo-VercelProjectName -Name $Repository.Name
    if ([string]::IsNullOrWhiteSpace($slug)) {
        return [pscustomobject]@{ Method = 'None'; Project = $null; Candidates = @(); Reason = 'Repository name could not be normalized.' }
    }

    $available = @($projects | Where-Object { -not $excluded.Contains([string]$_.Id) })
    $candidates = @()

    foreach ($project in $available) {
        $projectSlug = ConvertTo-VercelProjectName -Name $project.Name

        if ($projectSlug -eq $slug) {
            $candidates += $project
            continue
        }

        if ($projectSlug.StartsWith("$slug-")) {
            $suffix = $projectSlug.Substring($slug.Length + 1)
            if (Test-VercelRandomSuffix -Segment $suffix) {
                $candidates += $project
            }
        }
    }

    if ($candidates.Count -eq 1) {
        return [pscustomobject]@{
            Method     = 'NormalizedName'
            Project    = $candidates[0]
            Candidates = @($candidates)
            Reason     = 'Matched by normalized project name.'
        }
    }

    if ($candidates.Count -gt 1) {
        return [pscustomobject]@{
            Method     = 'Ambiguous'
            Project    = $null
            Candidates = @($candidates)
            Reason     = "$($candidates.Count) possible Vercel projects."
        }
    }

    return [pscustomobject]@{
        Method     = 'None'
        Project    = $null
        Candidates = @()
        Reason     = 'No Vercel project found for this repository.'
    }
}

function Resolve-DeploymentMatches {
    <#
    .SYNOPSIS
        Matches a whole portfolio, resolving definitive Git-integration links first.
    .DESCRIPTION
        Two passes prevent a project that definitively belongs to repository A from
        being claimed by repository B through a name-only match.
    #>
    param(
        [AllowEmptyCollection()][array]$Repositories = @(),
        [AllowEmptyCollection()][array]$Projects = @(),
        $Mappings
    )

    $results = New-Object 'System.Collections.Hashtable' ([System.StringComparer]::OrdinalIgnoreCase)
    $claimed = @()

    foreach ($repository in @($Repositories)) {
        $match = Find-VercelProjectMatch -Repository $repository -Projects $Projects -GitIntegrationOnly

        if ($match.Method -eq 'GitIntegration') {
            $results[[string]$repository.FullName] = $match
            $claimed += [string]$match.Project.Id
        }
        elseif ($match.Method -eq 'Ambiguous') {
            $results[[string]$repository.FullName] = $match
        }
    }

    foreach ($repository in @($Repositories)) {
        $key = [string]$repository.FullName
        if ($results.ContainsKey($key)) { continue }

        $results[$key] = Find-VercelProjectMatch -Repository $repository -Projects $Projects -Mappings $Mappings -ExcludeProjectIds $claimed
    }

    return $results
}

function Get-DeploymentStatus {
    <#
    .SYNOPSIS
        Classifies a single repository into one deployment status.
    #>
    param(
        [Parameter(Mandatory = $true)]$Eligibility,
        $Deployability,
        $Match,
        $Deployment,
        [string]$ExpectedBranch,
        [switch]$AuthRequired
    )

    if (-not $Eligibility.Eligible) {
        return [pscustomobject]@{ Status = 'SKIPPED'; Detail = $Eligibility.Reason }
    }

    if ($Deployability -and -not $Deployability.Deployable) {
        return [pscustomobject]@{ Status = 'NOT_DEPLOYABLE'; Detail = $Deployability.Reason }
    }

    if ($AuthRequired) {
        return [pscustomobject]@{ Status = 'AUTH_REQUIRED'; Detail = 'Vercel authentication is required.' }
    }

    if ($null -eq $Match) {
        return [pscustomobject]@{ Status = 'UNKNOWN'; Detail = 'No matching information was available.' }
    }

    if ($Match.Method -eq 'Ambiguous') {
        return [pscustomobject]@{ Status = 'AMBIGUOUS_MATCH'; Detail = $Match.Reason }
    }

    if ($Match.Method -eq 'None' -or $null -eq $Match.Project) {
        return [pscustomobject]@{ Status = 'MISSING_VERCEL_PROJECT'; Detail = $Match.Reason }
    }

    $project = $Match.Project

    if ([string]::IsNullOrWhiteSpace([string]$project.GitFullName)) {
        return [pscustomobject]@{ Status = 'GIT_NOT_CONNECTED'; Detail = 'This Vercel project has no connected Git repository.' }
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$project.ProductionBranch) -and
        -not [string]::IsNullOrWhiteSpace($ExpectedBranch) -and
        [string]$project.ProductionBranch -ine $ExpectedBranch) {
        return [pscustomobject]@{
            Status = 'PRODUCTION_BRANCH_MISMATCH'
            Detail = "Vercel deploys from '$($project.ProductionBranch)' but '$ExpectedBranch' was expected."
        }
    }

    if ($null -eq $Deployment -or [string]::IsNullOrWhiteSpace([string]$Deployment.Id)) {
        return [pscustomobject]@{ Status = 'NO_PRODUCTION_DEPLOYMENT'; Detail = 'No production deployment was found.' }
    }

    switch (([string]$Deployment.State).ToUpperInvariant()) {
        'READY' { return [pscustomobject]@{ Status = 'READY'; Detail = 'Production deployment is ready.' } }
        'ERROR' { return [pscustomobject]@{ Status = 'DEPLOYMENT_FAILED'; Detail = 'Vercel build failed.' } }
        'CANCELED' { return [pscustomobject]@{ Status = 'DEPLOYMENT_FAILED'; Detail = 'The production deployment was canceled.' } }
        'BUILDING' { return [pscustomobject]@{ Status = 'DEPLOYMENT_BUILDING'; Detail = 'Vercel is building this deployment.' } }
        'QUEUED' { return [pscustomobject]@{ Status = 'DEPLOYMENT_BUILDING'; Detail = 'The deployment is queued.' } }
        'INITIALIZING' { return [pscustomobject]@{ Status = 'DEPLOYMENT_BUILDING'; Detail = 'The deployment is starting.' } }
        default { return [pscustomobject]@{ Status = 'UNKNOWN'; Detail = "Vercel reported state '$($Deployment.State)'." } }
    }
}

function New-DeploymentCandidate {
    <#
    .SYNOPSIS
        Builds the per-repository record shared by the terminal report and JSON output.
    #>
    param(
        [Parameter(Mandatory = $true)]$Repository,
        $Eligibility,
        $Deployability,
        $Match,
        $Deployment,
        [string]$ExpectedBranch,
        [string]$Status,
        [string]$Detail,
        [string]$ErrorMessage
    )

    $project = $null
    if ($Match) { $project = $Match.Project }

    $matchMethod = 'None'
    if ($Match) { $matchMethod = [string]$Match.Method }

    $candidateNames = @()
    if ($Match -and $Match.Candidates) {
        $candidateNames = @($Match.Candidates | ForEach-Object { [string]$_.Name })
    }

    return [pscustomobject]@{
        GithubOwner       = [string]$Repository.Owner
        GithubRepo        = [string]$Repository.Name
        GithubFullName    = [string]$Repository.FullName
        RepositoryUrl     = [string]$Repository.Url
        DefaultBranch     = [string]$Repository.DefaultBranch
        ProductionBranch  = $ExpectedBranch
        Visibility        = [string]$Repository.Visibility
        Eligible          = [bool]$Eligibility.Eligible
        EligibilityReason = [string]$Eligibility.Reason
        EligibilityRule   = [string]$Eligibility.Rule
        Deployable        = [bool]($Deployability -and $Deployability.Deployable)
        Framework         = if ($Deployability) { [string]$Deployability.Framework } else { 'Unknown' }
        ProposedProject   = (ConvertTo-VercelProjectName -Name $Repository.Name)
        VercelProjectId   = if ($project) { [string]$project.Id } else { '' }
        VercelProjectName = if ($project) { [string]$project.Name } else { '' }
        MatchMethod       = $matchMethod
        MatchCandidates   = $candidateNames
        ProductionUrl     = if ($Deployment) { [string]$Deployment.Url } else { '' }
        DeploymentId      = if ($Deployment) { [string]$Deployment.Id } else { '' }
        DeploymentState   = if ($Deployment) { [string]$Deployment.State } else { '' }
        Status            = $Status
        Detail            = $Detail
        HttpStatus        = 0
        Error             = $ErrorMessage
    }
}

function Get-DeploymentActionForCandidate {
    <#
    .SYNOPSIS
        Returns the action Deployment Manager would take for one candidate.
    .DESCRIPTION
        Healthy projects always return 'None'. Failures, ambiguity, branch
        mismatches, and disconnected Git integrations always return 'Review':
        DevTools reports them and lets a human decide, rather than mutating an
        existing Vercel project.
    #>
    param([Parameter(Mandatory = $true)]$Candidate)

    switch ([string]$Candidate.Status) {
        'MISSING_VERCEL_PROJECT' {
            if ($Candidate.Deployable) { return 'CreateProject' }
            return 'None'
        }
        'NO_PRODUCTION_DEPLOYMENT' { return 'TriggerDeployment' }
        'DEPLOYMENT_FAILED' { return 'Review' }
        'AMBIGUOUS_MATCH' { return 'Review' }
        'GIT_NOT_CONNECTED' { return 'Review' }
        'PRODUCTION_BRANCH_MISMATCH' { return 'Review' }
        'UNKNOWN' { return 'Review' }
        'AUTH_REQUIRED' { return 'Review' }
        default { return 'None' }
    }
}

function New-DeploymentPlan {
    <#
    .SYNOPSIS
        Turns an audit into an explicit, reviewable list of proposed changes.
    #>
    param(
        [AllowEmptyCollection()][array]$Candidates = @()
    )

    $creations = @()
    $deployments = @()
    $review = @()

    foreach ($candidate in @($Candidates)) {
        switch (Get-DeploymentActionForCandidate -Candidate $candidate) {
            'CreateProject' { $creations += $candidate }
            'TriggerDeployment' { $deployments += $candidate }
            'Review' { $review += $candidate }
        }
    }

    return [pscustomobject]@{
        Creations   = @($creations)
        Deployments = @($deployments)
        Review      = @($review)
        ChangeCount = (@($creations).Count + @($deployments).Count)
    }
}

function Get-DeploymentSummary {
    <#
    .SYNOPSIS
        Counts candidates by status for the portfolio report.
    #>
    param(
        [AllowEmptyCollection()][array]$Candidates = @()
    )

    $summary = [ordered]@{}

    foreach ($candidate in @($Candidates)) {
        $status = [string]$candidate.Status
        if ([string]::IsNullOrWhiteSpace($status)) { $status = 'UNKNOWN' }

        if (-not $summary.Contains($status)) {
            $summary[$status] = 0
        }

        $summary[$status] = [int]$summary[$status] + 1
    }

    return $summary
}
