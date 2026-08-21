# Deployment Manager — orchestration for audit, plan, sync, and verify.
#
# Safety model:
#   DISCOVER -> CLASSIFY -> PLAN -> DISPLAY PLAN -> CONFIRM -> APPLY -> VERIFY -> REPORT
#
# audit, plan, verify, and status never write to GitHub, Vercel, or the workspace.
# Only sync mutates, and only after an explicit confirmation.

function Get-DeploymentPrerequisites {
    <#
    .SYNOPSIS
        Checks everything Deployment Manager needs before it can run.
    #>
    param($DeploymentConfig)

    $ghInstalled = Test-CommandExists 'gh'
    $ghAuthenticated = $false

    if ($ghInstalled) {
        $ghAuthenticated = Test-GhAuthenticated
    }

    $vercelReady = Test-VercelAuthenticated
    $teamSetting = Get-VercelTeamSetting -DeploymentConfig $DeploymentConfig
    $teamId = ''
    $teamError = $null

    if ($vercelReady -and -not [string]::IsNullOrWhiteSpace($teamSetting)) {
        $resolved = Resolve-VercelTeamId -TeamSetting $teamSetting

        if ($resolved.Success) {
            $teamId = $resolved.TeamId
        }
        else {
            $teamError = $resolved.Error
        }
    }

    return [pscustomobject]@{
        GhInstalled     = $ghInstalled
        GhAuthenticated = $ghAuthenticated
        GithubReady     = ($ghInstalled -and $ghAuthenticated)
        VercelReady     = $vercelReady
        TeamSetting     = $teamSetting
        TeamId          = $teamId
        TeamError       = $teamError
    }
}

function Show-DeploymentPrerequisites {
    <#
    .SYNOPSIS
        Prints the Deployment Tools readiness block used by Doctor and dev deploy.
    #>
    param($State)

    Write-Host 'Deployment Tools' -ForegroundColor Cyan
    Write-Host ''

    ShowStatusLine -Label 'GitHub CLI' -State $(if ($State.GhInstalled) { 'ready' } else { 'missing' }) -Detail $(if ($State.GhInstalled) { 'READY' } else { 'NOT INSTALLED' })
    ShowStatusLine -Label 'GitHub authentication' -State $(if ($State.GhAuthenticated) { 'ready' } else { 'missing' }) -Detail $(if ($State.GhAuthenticated) { 'READY' } else { 'AUTH REQUIRED' })
    ShowStatusLine -Label 'Vercel authentication' -State $(if ($State.VercelReady) { 'ready' } else { 'missing' }) -Detail $(if ($State.VercelReady) { 'READY' } else { 'AUTH REQUIRED' })

    if (-not [string]::IsNullOrWhiteSpace([string]$State.TeamSetting)) {
        $teamReady = (-not $State.TeamError) -and -not [string]::IsNullOrWhiteSpace([string]$State.TeamId)
        ShowStatusLine -Label 'Vercel team' -State $(if ($teamReady) { 'ready' } else { 'attention' }) -Detail $(if ($teamReady) { 'READY' } else { 'NEEDS ATTENTION' })
    }

    Write-Host ''

    if (-not $State.GhInstalled -or -not $State.GhAuthenticated) {
        ShowInfo 'Run: dev doctor  (installs GitHub CLI and signs you in)'
    }

    if (-not $State.VercelReady) {
        Show-VercelSetupHelp
    }

    if ($State.TeamError) {
        ShowWarning $State.TeamError
    }
}

function Show-VercelSetupHelp {
    <#
    .SYNOPSIS
        Beginner-friendly Vercel setup instructions. Never prints a token.
    #>
    Write-Host ''
    Write-Host 'Connect Vercel' -ForegroundColor Cyan
    Write-Host ''
    ShowInfo '1. Create a token at https://vercel.com/account/tokens'
    ShowInfo '2. In PowerShell, set it for this session:'
    ShowInfo '     $env:VERCEL_TOKEN = "your-token"'
    ShowInfo '3. Run: dev deploy audit'
    Write-Host ''
    ShowInfo 'DevTools never stores your token. It is read from the environment only.'
    ShowInfo 'To keep it across sessions, add it to your user environment variables.'
    ShowInfo 'Anything on your computer can read a persisted variable, so treat it like a password.'
    Write-Host ''
}

function Get-DeploymentOwners {
    <#
    .SYNOPSIS
        Returns the GitHub owners a deployment operation should scan.
    #>
    param($ConfigObject, [string[]]$OwnerOverride = @())

    if ($OwnerOverride -and @($OwnerOverride).Count -gt 0) {
        return @($OwnerOverride | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    return @($ConfigObject.githubOwners | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Invoke-DeploymentPacing {
    <#
    .SYNOPSIS
        Short pause between API calls so DevTools never floods GitHub or Vercel.
    #>
    param([int]$Milliseconds)

    if ($Milliseconds -gt 0) {
        Start-Sleep -Milliseconds $Milliseconds
    }
}

function Invoke-DeploymentAudit {
    <#
    .SYNOPSIS
        READ-ONLY portfolio audit. Discovers, inspects, matches, and classifies.
    .DESCRIPTION
        This function never creates, deploys, or modifies anything. A failure on a
        single repository is recorded and the audit continues.
    #>
    param(
        [Parameter(Mandatory = $true)]$ConfigObject,
        [Parameter(Mandatory = $true)]$DeploymentConfig,
        [string[]]$OwnerOverride = @(),
        [switch]$Quiet
    )

    $warnings = @()
    $candidates = @()
    $skipped = @()
    $repositories = @()

    $prerequisites = Get-DeploymentPrerequisites -DeploymentConfig $DeploymentConfig

    if (-not $prerequisites.GithubReady) {
        return [pscustomobject]@{
            Fatal         = $true
            Error         = 'GitHub CLI must be installed and signed in before Deployment Manager can run.'
            Prerequisites = $prerequisites
            Candidates    = @()
            Skipped       = @()
            Warnings      = @()
            Owners        = @()
            Discovered    = 0
            Projects      = @()
            TeamId        = ''
        }
    }

    $owners = @(Get-DeploymentOwners -ConfigObject $ConfigObject -OwnerOverride $OwnerOverride)

    if ($owners.Count -eq 0) {
        return [pscustomobject]@{
            Fatal         = $true
            Error         = 'No GitHub owners are configured. Run: dev settings'
            Prerequisites = $prerequisites
            Candidates    = @()
            Skipped       = @()
            Warnings      = @()
            Owners        = @()
            Discovered    = 0
            Projects      = @()
            TeamId        = ''
        }
    }

    foreach ($owner in $owners) {
        if (-not $Quiet) { ShowInfo "Reading repositories for $owner..." }

        $listing = Get-DeploymentRepositoriesForOwner -Owner $owner -Limit $DeploymentConfig.MaxRepositoriesPerOwner

        if ($listing.Error) {
            $warnings += "$owner : $($listing.Error)"
            continue
        }

        if ($listing.Truncated) {
            $warnings += "$owner : repository list may be truncated at $($DeploymentConfig.MaxRepositoriesPerOwner). Raise maxRepositoriesPerOwner in config.json."
        }

        $repositories += @($listing.Repositories)
    }

    if (-not $Quiet) {
        ShowInfo "Repositories discovered: $($repositories.Count)"
    }

    $eligibleRepositories = @()

    foreach ($repository in $repositories) {
        $eligibility = Test-RepositoryEligible -Repository $repository -Filters $DeploymentConfig.RepositoryFilters

        if ($eligibility.Eligible) {
            $eligibleRepositories += [pscustomobject]@{ Repository = $repository; Eligibility = $eligibility }
            continue
        }

        $skipped += New-DeploymentCandidate `
            -Repository $repository `
            -Eligibility $eligibility `
            -ExpectedBranch (Resolve-DeploymentProductionBranch -Repository $repository -Overrides $DeploymentConfig.ProductionBranchOverrides) `
            -Status 'SKIPPED' `
            -Detail $eligibility.Reason
    }

    if (-not $Quiet) {
        ShowInfo "Deployment candidates: $($eligibleRepositories.Count)"
        ShowInfo "Skipped by eligibility rules: $($skipped.Count)"
        Write-Host ''
    }

    $projects = @()
    $authRequired = -not $prerequisites.VercelReady

    if (-not $authRequired) {
        if (-not $Quiet) { ShowInfo 'Reading Vercel projects...' }

        $projectResult = Get-VercelProjects -TeamId $prerequisites.TeamId

        if ($projectResult.Success) {
            $projects = @($projectResult.Projects)
            if (-not $Quiet) { ShowInfo "Vercel projects found: $($projects.Count)" }
        }
        else {
            $warnings += "Vercel: $($projectResult.Error)"
            $authRequired = $true
        }
    }
    else {
        $warnings += 'Vercel authentication is required. Set VERCEL_TOKEN to compare against Vercel.'
    }

    $matchTable = Resolve-DeploymentMatches `
        -Repositories @($eligibleRepositories | ForEach-Object { $_.Repository }) `
        -Projects $projects `
        -Mappings $DeploymentConfig.ProjectMappings

    if (-not $Quiet -and $eligibleRepositories.Count -gt 0) {
        Write-Host ''
        ShowInfo "Inspecting $($eligibleRepositories.Count) candidate repositories..."
    }

    foreach ($entry in $eligibleRepositories) {
        $repository = $entry.Repository
        $eligibility = $entry.Eligibility
        $expectedBranch = Resolve-DeploymentProductionBranch -Repository $repository -Overrides $DeploymentConfig.ProductionBranchOverrides
        $deployability = $null
        $deployment = $null
        $errorMessage = $null

        try {
            $deployability = Get-DeploymentRepositoryInspection -Repository $repository

            if ($deployability.Error) {
                $errorMessage = $deployability.Error
            }
        }
        catch {
            $errorMessage = $_.Exception.Message
            $deployability = [pscustomobject]@{ Deployable = $false; Framework = 'Unknown'; Reason = $errorMessage; Indicators = @() }
        }

        $match = $null
        if ($matchTable.ContainsKey([string]$repository.FullName)) {
            $match = $matchTable[[string]$repository.FullName]
        }

        if (-not $authRequired -and $deployability.Deployable -and $match -and $match.Project) {
            try {
                $deployment = ConvertFrom-VercelDeployment -Record $match.Project.LatestProductionRecord

                if ($null -eq $deployment -or [string]::IsNullOrWhiteSpace([string]$deployment.Id)) {
                    $latest = Get-VercelLatestProductionDeployment -ProjectId $match.Project.Id -TeamId $prerequisites.TeamId

                    if ($latest.Success) {
                        $deployment = $latest.Deployment
                    }
                    else {
                        $errorMessage = $latest.Error
                    }
                }
            }
            catch {
                $errorMessage = $_.Exception.Message
            }
        }

        $classification = Get-DeploymentStatus `
            -Eligibility $eligibility `
            -Deployability $deployability `
            -Match $match `
            -Deployment $deployment `
            -ExpectedBranch $expectedBranch `
            -AuthRequired:$authRequired

        $candidates += New-DeploymentCandidate `
            -Repository $repository `
            -Eligibility $eligibility `
            -Deployability $deployability `
            -Match $match `
            -Deployment $deployment `
            -ExpectedBranch $expectedBranch `
            -Status $classification.Status `
            -Detail $classification.Detail `
            -ErrorMessage $errorMessage

        Invoke-DeploymentPacing -Milliseconds $DeploymentConfig.RequestDelayMilliseconds
    }

    return [pscustomobject]@{
        Fatal         = $false
        Error         = $null
        Prerequisites = $prerequisites
        Candidates    = @($candidates | Sort-Object GithubRepo)
        Skipped       = @($skipped | Sort-Object GithubRepo)
        Warnings      = @($warnings)
        Owners        = @($owners)
        Discovered    = $repositories.Count
        Projects      = @($projects)
        TeamId        = [string]$prerequisites.TeamId
        AuthRequired  = $authRequired
    }
}

function Show-DeploymentDiscoveryStats {
    param([Parameter(Mandatory = $true)]$Audit)

    $healthy = @($Audit.Candidates | Where-Object { $_.Status -eq 'READY' }).Count
    $missing = @($Audit.Candidates | Where-Object { $_.Status -eq 'MISSING_VERCEL_PROJECT' }).Count
    $unhealthy = @($Audit.Candidates | Where-Object { $_.Status -in @('DEPLOYMENT_FAILED', 'NO_PRODUCTION_DEPLOYMENT', 'DEPLOYMENT_BUILDING', 'GIT_NOT_CONNECTED', 'PRODUCTION_BRANCH_MISMATCH') }).Count
    $notDeployable = @($Audit.Candidates | Where-Object { $_.Status -eq 'NOT_DEPLOYABLE' }).Count

    ShowSummary -Title 'Portfolio' -Lines @(
        ('{0} {1}' -f 'Repositories discovered:'.PadRight(34), $Audit.Discovered)
        ('{0} {1}' -f 'Deployment candidates:'.PadRight(34), @($Audit.Candidates).Count)
        ('{0} {1}' -f 'Already healthy:'.PadRight(34), $healthy)
        ('{0} {1}' -f 'Missing Vercel projects:'.PadRight(34), $missing)
        ('{0} {1}' -f 'Existing but unhealthy:'.PadRight(34), $unhealthy)
        ('{0} {1}' -f 'Not deployable:'.PadRight(34), $notDeployable)
        ('{0} {1}' -f 'Skipped by rules:'.PadRight(34), @($Audit.Skipped).Count)
    )
}

function Show-DeploymentWarnings {
    param([AllowEmptyCollection()][array]$Warnings = @())

    if (@($Warnings).Count -eq 0) { return }

    Write-Host ''
    Write-Host 'Warnings' -ForegroundColor Cyan
    Write-Host ''

    foreach ($warning in @($Warnings)) {
        Write-Host "  $warning" -ForegroundColor Yellow
    }
}

function Save-DeploymentAuditReport {
    param(
        [Parameter(Mandatory = $true)]$Audit,
        [Parameter(Mandatory = $true)][string]$Operation
    )

    $report = ConvertTo-DeploymentReportObject `
        -Operation $Operation `
        -Owners $Audit.Owners `
        -Candidates @(@($Audit.Candidates) + @($Audit.Skipped)) `
        -RepositoriesDiscovered $Audit.Discovered `
        -Warnings $Audit.Warnings

    return (Save-DeploymentReport -Report $report)
}

function Invoke-DeploymentAuditCommand {
    <#
    .SYNOPSIS
        dev deploy audit — READ-ONLY portfolio audit.
    #>
    param(
        [Parameter(Mandatory = $true)]$ConfigObject,
        [string[]]$OwnerOverride = @()
    )

    $deploymentConfig = Get-DeploymentConfig -ConfigObject $ConfigObject

    ShowCommandScreen -Heading 'Deployment Audit' -Description @(
        'Comparing your GitHub repositories against Vercel.'
        'This is read-only. Nothing is created, deployed, or changed.'
    )

    $audit = Invoke-DeploymentAudit -ConfigObject $ConfigObject -DeploymentConfig $deploymentConfig -OwnerOverride $OwnerOverride

    if ($audit.Fatal) {
        ShowWarning $audit.Error
        Write-Host ''
        Show-DeploymentPrerequisites -State $audit.Prerequisites
        return 1
    }

    Write-Host ''
    Show-DeploymentTable -Candidates $audit.Candidates
    Show-DeploymentDiscoveryStats -Audit $audit
    Show-DeploymentPortfolioSummary -Candidates $audit.Candidates
    Show-DeploymentAttention -Candidates $audit.Candidates
    Show-DeploymentWarnings -Warnings $audit.Warnings

    Show-DeploymentReportLocation -SaveResult (Save-DeploymentAuditReport -Audit $audit -Operation 'audit')

    Write-Host ''
    ShowInfo 'Nothing was changed. Run: dev deploy plan'

    return 0
}

function Show-DeploymentPlan {
    <#
    .SYNOPSIS
        Renders the exact proposed changes without applying anything.
    #>
    param(
        [Parameter(Mandatory = $true)]$Audit,
        [Parameter(Mandatory = $true)]$Plan
    )

    Show-DeploymentDiscoveryStats -Audit $Audit

    Write-Host ''
    Write-Host 'Proposed Creations' -ForegroundColor Cyan
    Write-Host ''

    if (@($Plan.Creations).Count -eq 0) {
        ShowInfo 'None. Every deployable candidate already has a Vercel project.'
    }
    else {
        foreach ($candidate in @($Plan.Creations)) {
            Write-Host "  $($candidate.GithubRepo)" -ForegroundColor Yellow
            ShowInfo "  GitHub: $($candidate.GithubFullName)"
            ShowInfo "  Proposed Vercel project: $($candidate.ProposedProject)"
            ShowInfo "  Production branch: $($candidate.ProductionBranch)"
            ShowInfo "  Framework: $($candidate.Framework)"
            Write-Host ''
        }
    }

    Write-Host 'Proposed Deployments' -ForegroundColor Cyan
    Write-Host ''

    if (@($Plan.Deployments).Count -eq 0) {
        ShowInfo 'None. No connected project is missing a production deployment.'
    }
    else {
        foreach ($candidate in @($Plan.Deployments)) {
            Write-Host "  $($candidate.GithubRepo)" -ForegroundColor Yellow
            ShowInfo "  Vercel project: $($candidate.VercelProjectName)"
            ShowInfo "  Production branch: $($candidate.ProductionBranch)"
            Write-Host ''
        }
    }

    if (@($Plan.Review).Count -gt 0) {
        Write-Host ''
        Write-Host 'Needs Your Review' -ForegroundColor Cyan
        Write-Host ''
        ShowInfo 'DevTools will not change these automatically.'
        Write-Host ''

        foreach ($candidate in @($Plan.Review)) {
            Write-Host "  $($candidate.GithubRepo)" -ForegroundColor Yellow
            ShowInfo "  $($candidate.Status)"
            if (-not [string]::IsNullOrWhiteSpace([string]$candidate.Detail)) {
                ShowInfo "  $($candidate.Detail)"
            }
            Write-Host ''
        }
    }
}

function Invoke-DeploymentPlanCommand {
    <#
    .SYNOPSIS
        dev deploy plan — READ-ONLY dry run of the proposed changes.
    #>
    param(
        [Parameter(Mandatory = $true)]$ConfigObject,
        [string[]]$OwnerOverride = @()
    )

    $deploymentConfig = Get-DeploymentConfig -ConfigObject $ConfigObject

    ShowCommandScreen -Heading 'Deployment Sync Plan' -Description @(
        'Exactly what DevTools would create if you ran sync.'
        'This is read-only. Nothing is created, deployed, or changed.'
    )

    $audit = Invoke-DeploymentAudit -ConfigObject $ConfigObject -DeploymentConfig $deploymentConfig -OwnerOverride $OwnerOverride

    if ($audit.Fatal) {
        ShowWarning $audit.Error
        Write-Host ''
        Show-DeploymentPrerequisites -State $audit.Prerequisites
        return 1
    }

    $plan = New-DeploymentPlan -Candidates $audit.Candidates

    Write-Host ''
    Show-DeploymentPlan -Audit $audit -Plan $plan
    Show-DeploymentWarnings -Warnings $audit.Warnings

    Show-DeploymentReportLocation -SaveResult (Save-DeploymentAuditReport -Audit $audit -Operation 'plan')

    Write-Host ''
    ShowSuccess 'NO CHANGES HAVE BEEN MADE.'
    ShowInfo 'Run: dev deploy sync'
    ShowInfo 'to review and apply this plan.'

    return 0
}

function Show-DeploymentSyncConfirmation {
    <#
    .SYNOPSIS
        Asks for explicit approval before any Vercel resource is created.
    .DESCRIPTION
        The default answer is always No.
    #>
    param([Parameter(Mandatory = $true)]$Plan)

    Write-Host ''
    Write-Host "$(@($Plan.Creations).Count) new Vercel projects will be created." -ForegroundColor Yellow
    Write-Host "$(@($Plan.Deployments).Count) existing projects will get a first production deployment." -ForegroundColor Yellow
    Write-Host '0 existing healthy projects will be modified.' -ForegroundColor DarkGray
    Write-Host ''

    $answer = Read-Host 'Continue? [y/N]'
    return ($answer -match '^[Yy]$')
}

function Invoke-DeploymentCreateAction {
    <#
    .SYNOPSIS
        Creates one Vercel project, connects GitHub, and observes the first deployment.
    .DESCRIPTION
        Idempotent: an existing project with the same name that is already connected
        to this repository is reused instead of creating a duplicate.
    #>
    param(
        [Parameter(Mandatory = $true)]$Candidate,
        [Parameter(Mandatory = $true)]$DeploymentConfig,
        [string]$TeamId
    )

    $projectName = [string]$Candidate.ProposedProject
    $branch = [string]$Candidate.ProductionBranch
    $project = $null

    $existing = Get-VercelProjectByName -ProjectName $projectName -TeamId $TeamId

    if ($existing.Success -and $existing.Project) {
        $project = $existing.Project
        ShowInfo 'Previously created project found.'
    }
    else {
        $created = New-VercelGitProject -ProjectName $projectName -RepositoryFullName $Candidate.GithubFullName -ProductionBranch $branch -TeamId $TeamId

        if (-not $created.Success) {
            if ($created.Conflict) {
                $retry = Get-VercelProjectByName -ProjectName $projectName -TeamId $TeamId

                if ($retry.Success -and $retry.Project) {
                    $project = $retry.Project
                    ShowInfo 'Previously created project found.'
                }
            }

            if ($null -eq $project) {
                return [pscustomobject]@{ Status = 'ACTION_FAILED'; Detail = 'Could not create the Vercel project.'; Error = $created.Error; Project = $null; Deployment = $null }
            }
        }
        else {
            $project = $created.Project
            ShowSuccess "Created Vercel project: $projectName"
        }
    }

    if ($null -eq $project) {
        return [pscustomobject]@{ Status = 'ACTION_FAILED'; Detail = 'Vercel did not return the project.'; Error = 'No project payload.'; Project = $null; Deployment = $null }
    }

    $deploymentResult = Invoke-DeploymentTriggerAction -Candidate $Candidate -Project $project -DeploymentConfig $DeploymentConfig -TeamId $TeamId -CreatedNow

    return [pscustomobject]@{
        Status     = $deploymentResult.Status
        Detail     = $deploymentResult.Detail
        Error      = $deploymentResult.Error
        Project    = $project
        Deployment = $deploymentResult.Deployment
    }
}

function Invoke-DeploymentTriggerAction {
    <#
    .SYNOPSIS
        Ensures a production deployment exists, then waits for the result.
    .DESCRIPTION
        If Vercel already started a deployment, that deployment is observed instead
        of triggering a redundant second build.
    #>
    param(
        [Parameter(Mandatory = $true)]$Candidate,
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$DeploymentConfig,
        [string]$TeamId,
        [switch]$CreatedNow
    )

    $branch = [string]$Candidate.ProductionBranch
    if ([string]::IsNullOrWhiteSpace($branch)) {
        $branch = [string]$Project.ProductionBranch
    }

    if ([string]::IsNullOrWhiteSpace($branch)) {
        return [pscustomobject]@{ Status = 'ACTION_FAILED'; Detail = 'No production branch could be determined.'; Error = 'Missing production branch.'; Deployment = $null }
    }

    $gitOwner = [string]$Project.GitOwner
    $gitRepo = [string]$Project.GitRepo

    if ([string]::IsNullOrWhiteSpace($gitOwner)) { $gitOwner = [string]$Candidate.GithubOwner }
    if ([string]::IsNullOrWhiteSpace($gitRepo)) { $gitRepo = [string]$Candidate.GithubRepo }

    $deployment = $null

    # For a project DevTools just created, any deployment means Vercel started the
    # first build itself. For an existing project only a production deployment
    # counts, so a preview build is never mistaken for the production one.
    $existing = Get-VercelProjectDeploymentCount -ProjectId $Project.Id -TeamId $TeamId -ProductionOnly:(-not $CreatedNow)

    if ($existing.Success -and $existing.Count -gt 0 -and $existing.Deployment) {
        $deployment = $existing.Deployment
        ShowInfo 'Vercel already started a deployment. Watching it instead of starting another.'
    }
    else {
        $started = Start-VercelProductionDeployment `
            -ProjectName $Project.Name `
            -GitOwner $gitOwner `
            -GitRepo $gitRepo `
            -Branch $branch `
            -GitRepoId $Project.GitRepoId `
            -TeamId $TeamId

        if (-not $started.Success) {
            $status = if ($CreatedNow) { 'CREATED' } else { 'ACTION_FAILED' }
            return [pscustomobject]@{ Status = $status; Detail = 'The project exists but the deployment could not be started.'; Error = $started.Error; Deployment = $null }
        }

        $deployment = $started.Deployment
        ShowInfo "Deployment started for $($Project.Name)."
    }

    if ($null -eq $deployment -or [string]::IsNullOrWhiteSpace([string]$deployment.Id)) {
        $status = if ($CreatedNow) { 'CREATED' } else { 'ACTION_FAILED' }
        return [pscustomobject]@{ Status = $status; Detail = 'Vercel did not return a deployment id.'; Error = 'Missing deployment id.'; Deployment = $null }
    }

    $waited = Wait-VercelDeployment `
        -DeploymentId $deployment.Id `
        -TeamId $TeamId `
        -TimeoutSeconds $DeploymentConfig.DeploymentTimeoutSeconds `
        -IntervalSeconds $DeploymentConfig.PollIntervalSeconds

    $final = $waited.Deployment
    if ($null -eq $final) { $final = $deployment }

    if ($waited.Error) {
        return [pscustomobject]@{ Status = 'ACTION_FAILED'; Detail = 'DevTools lost track of the deployment.'; Error = $waited.Error; Deployment = $final }
    }

    if ($waited.TimedOut) {
        return [pscustomobject]@{ Status = 'DEPLOYMENT_TIMEOUT'; Detail = "Still building after $($DeploymentConfig.DeploymentTimeoutSeconds) seconds."; Error = $null; Deployment = $final }
    }

    switch (([string]$final.State).ToUpperInvariant()) {
        'READY' {
            $status = if ($CreatedNow) { 'CREATED_AND_DEPLOYED' } else { 'READY' }
            return [pscustomobject]@{ Status = $status; Detail = 'Production deployment is ready.'; Error = $null; Deployment = $final }
        }
        'ERROR' { return [pscustomobject]@{ Status = 'DEPLOYMENT_FAILED'; Detail = 'Vercel build failed.'; Error = $null; Deployment = $final } }
        'CANCELED' { return [pscustomobject]@{ Status = 'DEPLOYMENT_FAILED'; Detail = 'The deployment was canceled.'; Error = $null; Deployment = $final } }
        default { return [pscustomobject]@{ Status = 'UNKNOWN'; Detail = "Vercel reported state '$($final.State)'."; Error = $null; Deployment = $final } }
    }
}

function Invoke-DeploymentSyncApply {
    <#
    .SYNOPSIS
        Applies an approved plan sequentially, isolating every failure.
    #>
    param(
        [Parameter(Mandatory = $true)]$Plan,
        [Parameter(Mandatory = $true)]$DeploymentConfig,
        [string]$TeamId
    )

    $results = @()

    foreach ($candidate in @($Plan.Creations)) {
        Write-Host ''
        Write-Host $candidate.GithubRepo -ForegroundColor Cyan

        try {
            $action = Invoke-DeploymentCreateAction -Candidate $candidate -DeploymentConfig $DeploymentConfig -TeamId $TeamId

            $candidate.Status = $action.Status
            $candidate.Detail = $action.Detail
            $candidate.Error = $action.Error

            if ($action.Project) {
                $candidate.VercelProjectId = [string]$action.Project.Id
                $candidate.VercelProjectName = [string]$action.Project.Name
                $candidate.MatchMethod = 'GitIntegration'
            }

            if ($action.Deployment) {
                $candidate.DeploymentId = [string]$action.Deployment.Id
                $candidate.DeploymentState = [string]$action.Deployment.State
                $candidate.ProductionUrl = [string]$action.Deployment.Url
            }
        }
        catch {
            $candidate.Status = 'ACTION_FAILED'
            $candidate.Detail = 'DevTools could not finish this repository.'
            $candidate.Error = $_.Exception.Message
        }

        Write-Host "  $($candidate.Status)" -ForegroundColor DarkGray
        $results += $candidate
        Invoke-DeploymentPacing -Milliseconds $DeploymentConfig.RequestDelayMilliseconds
    }

    foreach ($candidate in @($Plan.Deployments)) {
        Write-Host ''
        Write-Host $candidate.GithubRepo -ForegroundColor Cyan

        try {
            $project = [pscustomobject]@{
                Id               = $candidate.VercelProjectId
                Name             = $candidate.VercelProjectName
                GitOwner         = $candidate.GithubOwner
                GitRepo          = $candidate.GithubRepo
                GitRepoId        = ''
                ProductionBranch = $candidate.ProductionBranch
            }

            $action = Invoke-DeploymentTriggerAction -Candidate $candidate -Project $project -DeploymentConfig $DeploymentConfig -TeamId $TeamId

            $candidate.Status = $action.Status
            $candidate.Detail = $action.Detail
            $candidate.Error = $action.Error

            if ($action.Deployment) {
                $candidate.DeploymentId = [string]$action.Deployment.Id
                $candidate.DeploymentState = [string]$action.Deployment.State
                $candidate.ProductionUrl = [string]$action.Deployment.Url
            }
        }
        catch {
            $candidate.Status = 'ACTION_FAILED'
            $candidate.Detail = 'DevTools could not finish this repository.'
            $candidate.Error = $_.Exception.Message
        }

        Write-Host "  $($candidate.Status)" -ForegroundColor DarkGray
        $results += $candidate
        Invoke-DeploymentPacing -Milliseconds $DeploymentConfig.RequestDelayMilliseconds
    }

    return @($results)
}

function Invoke-DeploymentSyncCommand {
    <#
    .SYNOPSIS
        dev deploy sync — the only mutating Deployment Manager command.
    #>
    param(
        [Parameter(Mandatory = $true)]$ConfigObject,
        [string[]]$OwnerOverride = @(),
        [switch]$Apply
    )

    $deploymentConfig = Get-DeploymentConfig -ConfigObject $ConfigObject

    ShowCommandScreen -Heading 'Deployment Sync' -Description @(
        'Sync can create Vercel projects and start production deployments.'
        'A fresh audit runs first, and nothing changes without your approval.'
    )

    $audit = Invoke-DeploymentAudit -ConfigObject $ConfigObject -DeploymentConfig $deploymentConfig -OwnerOverride $OwnerOverride

    if ($audit.Fatal) {
        ShowWarning $audit.Error
        Write-Host ''
        Show-DeploymentPrerequisites -State $audit.Prerequisites
        return 1
    }

    if ($audit.AuthRequired) {
        Write-Host ''
        ShowWarning 'Vercel authentication is required before sync can make changes.'
        Show-VercelSetupHelp
        return 1
    }

    $plan = New-DeploymentPlan -Candidates $audit.Candidates

    Write-Host ''
    Show-DeploymentPlan -Audit $audit -Plan $plan
    Show-DeploymentWarnings -Warnings $audit.Warnings

    if ($plan.ChangeCount -eq 0) {
        Write-Host ''
        ShowSuccess 'Nothing to do. Your portfolio already matches the desired state.'
        Show-DeploymentReportLocation -SaveResult (Save-DeploymentAuditReport -Audit $audit -Operation 'sync')
        return 0
    }

    if ($Apply) {
        Write-Host ''
        ShowWarning '--apply was supplied. Applying the plan without an interactive prompt.'
    }
    elseif (-not (Show-DeploymentSyncConfirmation -Plan $plan)) {
        Write-Host ''
        ShowInfo 'Sync cancelled. No Vercel projects were created or changed.'
        return 0
    }

    Write-Host ''
    ShowSection -Label 'Applying plan'

    $applied = @(Invoke-DeploymentSyncApply -Plan $plan -DeploymentConfig $deploymentConfig -TeamId $audit.TeamId)

    $created = @($applied | Where-Object { $_.Status -in @('CREATED', 'CREATED_AND_DEPLOYED') }).Count
    $deployed = @($applied | Where-Object { $_.Status -in @('CREATED_AND_DEPLOYED', 'READY') }).Count
    $failed = @($applied | Where-Object { $_.Status -in @('DEPLOYMENT_FAILED', 'ACTION_FAILED') }).Count
    $pending = @($applied | Where-Object { $_.Status -in @('DEPLOYMENT_TIMEOUT', 'DEPLOYMENT_BUILDING', 'UNKNOWN') }).Count

    Write-Host ''
    ShowSummary -Title 'Sync Results' -Lines @(
        ('{0} {1}' -f 'Created:'.PadRight(30), $created)
        ('{0} {1}' -f 'Successfully deployed:'.PadRight(30), $deployed)
        ('{0} {1}' -f 'Failed:'.PadRight(30), $failed)
        ('{0} {1}' -f 'Still running:'.PadRight(30), $pending)
    )

    Show-DeploymentPortfolioSummary -Candidates $audit.Candidates
    Show-DeploymentAttention -Candidates $audit.Candidates

    Show-DeploymentReportLocation -SaveResult (Save-DeploymentAuditReport -Audit $audit -Operation 'sync')

    Write-Host ''
    ShowInfo 'Future merges to the production branch now deploy automatically through Vercel.'

    return 0
}

function Invoke-DeploymentVerifyCommand {
    <#
    .SYNOPSIS
        dev deploy verify — READ-ONLY production verification.
    #>
    param(
        [Parameter(Mandatory = $true)]$ConfigObject,
        [string[]]$OwnerOverride = @(),
        [switch]$SkipHttp
    )

    $deploymentConfig = Get-DeploymentConfig -ConfigObject $ConfigObject

    ShowCommandScreen -Heading 'Verify Production' -Description @(
        'Checking that every matched project has a healthy production deployment.'
        'This is read-only. Nothing is created, deployed, or changed.'
    )

    $audit = Invoke-DeploymentAudit -ConfigObject $ConfigObject -DeploymentConfig $deploymentConfig -OwnerOverride $OwnerOverride

    if ($audit.Fatal) {
        ShowWarning $audit.Error
        Write-Host ''
        Show-DeploymentPrerequisites -State $audit.Prerequisites
        return 1
    }

    $checkHttp = $deploymentConfig.HttpHealthCheck -and -not $SkipHttp
    $verified = @($audit.Candidates | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.VercelProjectName) })

    Write-Host ''

    foreach ($candidate in $verified) {
        Write-Host "  $($candidate.GithubRepo)" -ForegroundColor Cyan
        ShowInfo "  Vercel: $(Get-DeploymentConnectionLabel -Candidate $candidate)"
        ShowInfo "  Production: $(Get-DeploymentProductionLabel -Candidate $candidate)"

        if (-not [string]::IsNullOrWhiteSpace([string]$candidate.ProductionUrl)) {
            ShowInfo "  URL: $($candidate.ProductionUrl)"

            if ($checkHttp -and $candidate.Status -eq 'READY') {
                $health = Test-DeploymentUrlHealth -Url $candidate.ProductionUrl

                if ($health.Checked -and $health.StatusCode -gt 0) {
                    $candidate.HttpStatus = $health.StatusCode
                    ShowInfo "  HTTP: $($health.StatusCode)"
                }
                else {
                    ShowInfo "  HTTP: no response"
                    if ($health.Error) {
                        $candidate.Error = $health.Error
                    }
                }
            }
        }

        Write-Host ''
        Invoke-DeploymentPacing -Milliseconds $deploymentConfig.RequestDelayMilliseconds
    }

    if ($verified.Count -eq 0) {
        ShowInfo 'No matched Vercel projects to verify yet.'
    }

    Show-DeploymentPortfolioSummary -Candidates $audit.Candidates
    Show-DeploymentAttention -Candidates $audit.Candidates
    Show-DeploymentWarnings -Warnings $audit.Warnings

    Show-DeploymentReportLocation -SaveResult (Save-DeploymentAuditReport -Audit $audit -Operation 'verify')

    return 0
}

function Invoke-DeploymentStatusCommand {
    <#
    .SYNOPSIS
        dev deploy status — Deployment Manager settings and readiness. Read-only.
    #>
    param([Parameter(Mandatory = $true)]$ConfigObject)

    $deploymentConfig = Get-DeploymentConfig -ConfigObject $ConfigObject

    ShowCommandScreen -Heading 'Deployment Settings' -Description @(
        'How Deployment Manager is configured on this computer.'
    )

    Show-DeploymentPrerequisites -State (Get-DeploymentPrerequisites -DeploymentConfig $deploymentConfig)

    ShowSection -Label 'Provider' -Value $deploymentConfig.Provider

    $teamDisplay = if ([string]::IsNullOrWhiteSpace([string]$deploymentConfig.VercelTeam)) { 'Personal account' } else { $deploymentConfig.VercelTeam }
    ShowSection -Label 'Vercel team' -Value $teamDisplay

    ShowSection -Label 'GitHub owners'
    foreach ($owner in @(Get-DeploymentOwners -ConfigObject $ConfigObject)) {
        ShowInfo $owner
    }

    Write-Host ''
    ShowSection -Label 'Include patterns'
    foreach ($pattern in @($deploymentConfig.RepositoryFilters.IncludeNamePatterns)) {
        ShowInfo $pattern
    }

    if (@($deploymentConfig.RepositoryFilters.IncludeRepositories).Count -gt 0) {
        Write-Host ''
        ShowSection -Label 'Always include'
        foreach ($name in @($deploymentConfig.RepositoryFilters.IncludeRepositories)) {
            ShowInfo $name
        }
    }

    if (@($deploymentConfig.RepositoryFilters.ExcludeRepositories).Count -gt 0) {
        Write-Host ''
        ShowSection -Label 'Never include'
        foreach ($name in @($deploymentConfig.RepositoryFilters.ExcludeRepositories)) {
            ShowInfo $name
        }
    }

    Write-Host ''
    ShowSection -Label 'Reports' -Value (Get-DeploymentReportPath)
    ShowInfo 'Reports stay on your computer and are never committed.'

    return 0
}

function Show-DeploymentHelp {
    ShowCommandScreen -Heading 'Deployment Manager' -Description @(
        'Find every website you have on GitHub, compare it with Vercel, and fix what is missing.'
    )

    ShowSection -Label 'Commands'
    ShowInfo 'dev deploy           Interactive Deployment Manager'
    ShowInfo 'dev deploy audit     Compare GitHub and Vercel (changes nothing)'
    ShowInfo 'dev deploy plan      Show exactly what sync would create (changes nothing)'
    ShowInfo 'dev deploy sync      Create missing projects after you approve'
    ShowInfo 'dev deploy verify    Check production deployments (changes nothing)'
    ShowInfo 'dev deploy status    Show deployment settings and readiness'
    ShowInfo 'dev deploy help      This screen'

    Write-Host ''
    ShowSection -Label 'What changes anything?'
    ShowInfo 'audit   read-only'
    ShowInfo 'plan    read-only'
    ShowInfo 'verify  read-only'
    ShowInfo 'status  read-only'
    ShowInfo 'sync    can create Vercel projects and start production deployments'

    Write-Host ''
    ShowSection -Label 'Options'
    ShowInfo '--apply      Skip the confirmation prompt for sync. Use with care.'
    ShowInfo '--owner NAME Audit a single GitHub owner instead of all configured owners.'
    ShowInfo '--no-http    Skip the production URL health check during verify.'

    Write-Host ''
    ShowSection -Label 'Typical first run'
    ShowInfo '1. dev deploy audit'
    ShowInfo '2. dev deploy plan'
    ShowInfo '3. dev deploy sync'
    ShowInfo '4. dev deploy verify'

    Write-Host ''
    ShowSection -Label 'Existing projects'
    ShowInfo 'Healthy Vercel projects are never modified, renamed, redeployed, or disconnected.'

    Write-Host ''
    ShowSection -Label 'Setup'
    ShowInfo 'Vercel is optional. DevTools works fine without it.'
    ShowInfo 'To connect Vercel, set the VERCEL_TOKEN environment variable.'
    ShowInfo 'See docs/deployments.md for the full guide.'

    return 0
}

function Show-DeploymentManagerMenu {
    Write-Host 'Deployment Manager' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  1  Audit portfolio'
    Write-Host '  2  Preview missing deployments'
    Write-Host '  3  Sync missing Vercel projects'
    Write-Host '  4  Verify production deployments'
    Write-Host '  5  Deployment settings'
    Write-Host '  6  Help'
    Write-Host '  0  Back'
    Write-Host ''
    Write-Host 'Type a number and press Enter.' -ForegroundColor DarkGray
    Write-Host ''
}

function Invoke-DeploymentManagerMenu {
    <#
    .SYNOPSIS
        dev deploy — interactive Deployment Manager.
    #>
    param([Parameter(Mandatory = $true)]$ConfigObject)

    while ($true) {
        ShowContextHeader -Clear
        Show-DeploymentManagerMenu

        $choice = Read-Host 'Choose an option'

        switch ($choice) {
            '1' { Invoke-DeploymentAuditCommand -ConfigObject $ConfigObject | Out-Null; Wait-ForKey }
            '2' { Invoke-DeploymentPlanCommand -ConfigObject $ConfigObject | Out-Null; Wait-ForKey }
            '3' { Invoke-DeploymentSyncCommand -ConfigObject $ConfigObject | Out-Null; Wait-ForKey }
            '4' { Invoke-DeploymentVerifyCommand -ConfigObject $ConfigObject | Out-Null; Wait-ForKey }
            '5' { Invoke-DeploymentStatusCommand -ConfigObject $ConfigObject | Out-Null; Wait-ForKey }
            '6' { Show-DeploymentHelp | Out-Null; Wait-ForKey }
            '0' { return 0 }
            default {
                ShowWarning 'Please choose a number from the menu.'
                Wait-ForKey -Message 'Press Enter to try again'
            }
        }
    }
}
