#Requires -Version 5.1

<#
.SYNOPSIS
    Validates Deployment Manager logic, matching, classification, and safety rules.
.DESCRIPTION
    Every external service is mocked. These tests never call GitHub or Vercel and
    never create a real Vercel project. Run standalone or through tests/Test-DevTools.ps1.
#>

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:DeployTestFailed = $false
$script:DeployTestPassed = 0

function Write-DeployTestPass {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "PASS: $Message" -ForegroundColor Green
    $script:DeployTestPassed++
}

function Write-DeployTestFailure {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "FAIL: $Message" -ForegroundColor Red
    $script:DeployTestFailed = $true
}

function Assert-DeployTrue {
    param([bool]$Condition, [Parameter(Mandatory = $true)][string]$Label)

    if ($Condition) {
        Write-DeployTestPass $Label
        return
    }

    Write-DeployTestFailure $Label
}

function Assert-DeployEqual {
    param($Expected, $Actual, [Parameter(Mandatory = $true)][string]$Label)

    if ([string]$Expected -eq [string]$Actual) {
        Write-DeployTestPass $Label
        return
    }

    Write-DeployTestFailure "$Label (expected '$Expected' but got '$Actual')"
}

# ---------------------------------------------------------------------------
# Load Deployment Manager
# ---------------------------------------------------------------------------

$DevToolsRoot = $ProjectRoot
$script:DevToolsRoot = $ProjectRoot

. (Join-Path $ProjectRoot 'lib\utils.ps1')
. (Join-Path $ProjectRoot 'lib\copy.ps1')
. (Join-Path $ProjectRoot 'lib\ui.ps1')
. (Join-Path $ProjectRoot 'lib\github.ps1')
. (Join-Path $ProjectRoot 'lib\deploy-config.ps1')
. (Join-Path $ProjectRoot 'lib\deploy-github.ps1')
. (Join-Path $ProjectRoot 'lib\deploy-vercel.ps1')
. (Join-Path $ProjectRoot 'lib\deploy-model.ps1')
. (Join-Path $ProjectRoot 'lib\deploy-report.ps1')
. (Join-Path $ProjectRoot 'lib\deploy.ps1')

Write-Host ''
Write-Host 'Deployment Manager Tests' -ForegroundColor Cyan
Write-Host ''

# ---------------------------------------------------------------------------
# Name normalization
# ---------------------------------------------------------------------------

Assert-DeployEqual 'amazing-head-spa-demo' (ConvertTo-VercelProjectName -Name 'Amazing-Head-Spa-Demo') 'Normalize: Amazing-Head-Spa-Demo'
Assert-DeployEqual 'tia-medspa-demo' (ConvertTo-VercelProjectName -Name 'TIA_Medspa_Demo') 'Normalize: TIA_Medspa_Demo'
Assert-DeployEqual 'good-quality-hvac-demo' (ConvertTo-VercelProjectName -Name 'Good Quality HVAC Demo') 'Normalize: spaces become hyphens'
Assert-DeployEqual 'my-site-demo' (ConvertTo-VercelProjectName -Name '--My..Site___Demo--') 'Normalize: collapses and trims separators'
Assert-DeployEqual '' (ConvertTo-VercelProjectName -Name '   ') 'Normalize: blank name returns empty string'
Assert-DeployTrue ((ConvertTo-VercelProjectName -Name ('a' * 150)).Length -le 100) 'Normalize: caps length at 100 characters'

# ---------------------------------------------------------------------------
# Configuration defaults and migration
# ---------------------------------------------------------------------------

$legacyConfig = '{"workspacePath":"C:\\Projects","githubOwners":["Novenworks"],"defaultEditor":"cursor","autoBackupMessage":"Auto backup","autoUpdate":false}' | ConvertFrom-Json
$legacyDeployment = Get-DeploymentConfig -ConfigObject $legacyConfig

Assert-DeployEqual 'vercel' $legacyDeployment.Provider 'Migration: legacy config gets the default provider'
Assert-DeployEqual '*demo*' (@($legacyDeployment.RepositoryFilters.IncludeNamePatterns) -join ',') 'Migration: legacy config gets the default include pattern'
Assert-DeployEqual 600 $legacyDeployment.DeploymentTimeoutSeconds 'Migration: legacy config gets the default deployment timeout'
Assert-DeployTrue (-not $legacyDeployment.RepositoryFilters.IncludeForks) 'Migration: forks excluded by default'
Assert-DeployEqual '' $legacyDeployment.VercelTeam 'Migration: no team configured by default'

$exampleConfig = Get-Content -LiteralPath (Join-Path $ProjectRoot 'config.example.json') -Raw | ConvertFrom-Json
$exampleDeployment = Get-DeploymentConfig -ConfigObject $exampleConfig
Assert-DeployEqual '*demo*' (@($exampleDeployment.RepositoryFilters.IncludeNamePatterns) -join ',') 'Config example: ships the *demo* include pattern'
Assert-DeployTrue ($null -eq $exampleConfig.deployments.vercelToken) 'Security: config.example.json contains no token field'

$customConfig = @{
    deployments = @{
        vercelTeam        = 'novenworks-abbd0c90'
        repositoryFilters = @{
            includeNamePatterns = @('*site*', '*demo*')
            excludeRepositories = @('Novenworks/dev-tools')
            includeRepositories = @('Special-Client-Site')
            includeForks        = $true
        }
        productionBranchOverrides = @{ 'Novenworks/Legacy-Demo' = 'master' }
    }
}
$customDeployment = Get-DeploymentConfig -ConfigObject $customConfig
Assert-DeployEqual 'novenworks-abbd0c90' $customDeployment.VercelTeam 'Config: custom team slug is read'
Assert-DeployEqual 2 @($customDeployment.RepositoryFilters.IncludeNamePatterns).Count 'Config: custom include patterns are read'
Assert-DeployTrue $customDeployment.RepositoryFilters.IncludeForks 'Config: includeForks can be enabled'

# ---------------------------------------------------------------------------
# Repository eligibility
# ---------------------------------------------------------------------------

$defaultFilters = $legacyDeployment.RepositoryFilters

function New-TestRepository {
    param(
        [string]$Name,
        [string]$Owner = 'Novenworks',
        [string]$DefaultBranch = 'main',
        [bool]$IsArchived = $false,
        [bool]$IsFork = $false,
        [bool]$IsTemplate = $false
    )

    return New-DeploymentRepository -Owner $Owner -Name $Name -DefaultBranch $DefaultBranch `
        -IsArchived $IsArchived -IsFork $IsFork -IsTemplate $IsTemplate -Visibility 'public'
}

$demoRepo = New-TestRepository -Name 'Dream-Med-Spa-Demo'
Assert-DeployTrue (Test-RepositoryEligible -Repository $demoRepo -Filters $defaultFilters).Eligible 'Eligibility: demo repository is a candidate'

$upperDemoRepo = New-TestRepository -Name 'TIA-Medspa-DEMO'
Assert-DeployTrue (Test-RepositoryEligible -Repository $upperDemoRepo -Filters $defaultFilters).Eligible 'Eligibility: demo matching is case-insensitive'

$toolingRepo = New-TestRepository -Name 'dev-tools'
$toolingResult = Test-RepositoryEligible -Repository $toolingRepo -Filters $defaultFilters
Assert-DeployTrue (-not $toolingResult.Eligible) 'Eligibility: non-matching tooling repository is skipped'
Assert-DeployEqual 'no-match' $toolingResult.Rule 'Eligibility: non-matching repository reports the no-match rule'

$archivedRepo = New-TestRepository -Name 'Old-Demo' -IsArchived $true
$archivedResult = Test-RepositoryEligible -Repository $archivedRepo -Filters $defaultFilters
Assert-DeployTrue (-not $archivedResult.Eligible) 'Eligibility: archived repository is skipped'
Assert-DeployEqual 'archived' $archivedResult.Rule 'Eligibility: archived repository reports the archived rule'

$forkRepo = New-TestRepository -Name 'Forked-Demo' -IsFork $true
$forkResult = Test-RepositoryEligible -Repository $forkRepo -Filters $defaultFilters
Assert-DeployTrue (-not $forkResult.Eligible) 'Eligibility: fork is skipped by default'
Assert-DeployTrue (Test-RepositoryEligible -Repository $forkRepo -Filters $customDeployment.RepositoryFilters).Eligible 'Eligibility: fork is included when includeForks is on'

$templateRepo = New-TestRepository -Name 'Starter-Demo' -IsTemplate $true
Assert-DeployEqual 'template' (Test-RepositoryEligible -Repository $templateRepo -Filters $defaultFilters).Rule 'Eligibility: template repository is skipped'

$explicitRepo = New-TestRepository -Name 'Special-Client-Site'
$explicitResult = Test-RepositoryEligible -Repository $explicitRepo -Filters $customDeployment.RepositoryFilters
Assert-DeployTrue $explicitResult.Eligible 'Eligibility: explicitly included repository is a candidate'
Assert-DeployEqual 'explicit-include' $explicitResult.Rule 'Eligibility: explicit include reports its own rule'

$excludedRepo = New-TestRepository -Name 'dev-tools'
$excludedResult = Test-RepositoryEligible -Repository $excludedRepo -Filters $customDeployment.RepositoryFilters
Assert-DeployTrue (-not $excludedResult.Eligible) 'Eligibility: excluded repository is skipped'
Assert-DeployEqual 'excluded' $excludedResult.Rule 'Eligibility: exclusion wins over include patterns'

# ---------------------------------------------------------------------------
# Production branch resolution
# ---------------------------------------------------------------------------

$masterRepo = New-TestRepository -Name 'Legacy-Demo' -DefaultBranch 'develop'
Assert-DeployEqual 'develop' (Resolve-DeploymentProductionBranch -Repository $masterRepo -Overrides @{}) 'Branch: uses the repository default branch, not "main"'
Assert-DeployEqual 'master' (Resolve-DeploymentProductionBranch -Repository $masterRepo -Overrides $customDeployment.ProductionBranchOverrides) 'Branch: configuration override wins'

# ---------------------------------------------------------------------------
# Deployability detection
# ---------------------------------------------------------------------------

function New-TestEntries {
    param([string[]]$Files = @(), [string[]]$Directories = @())

    $entries = @()
    foreach ($file in $Files) { $entries += [pscustomobject]@{ Name = $file; Type = 'file' } }
    foreach ($directory in $Directories) { $entries += [pscustomobject]@{ Name = $directory; Type = 'dir' } }
    return $entries
}

$nextResult = Get-RepositoryDeployability -Entries (New-TestEntries -Files @('package.json', 'next.config.js') -Directories @('app', 'public'))
Assert-DeployTrue $nextResult.Deployable 'Deployability: Next.js repository is deployable'
Assert-DeployEqual 'Next.js' $nextResult.Framework 'Deployability: detects Next.js'

$astroResult = Get-RepositoryDeployability -Entries (New-TestEntries -Files @('package.json', 'astro.config.mjs') -Directories @('src'))
Assert-DeployEqual 'Astro' $astroResult.Framework 'Deployability: detects Astro'

$svelteResult = Get-RepositoryDeployability -Entries (New-TestEntries -Files @('package.json', 'svelte.config.js') -Directories @('src'))
Assert-DeployEqual 'SvelteKit' $svelteResult.Framework 'Deployability: detects SvelteKit'

$viteResult = Get-RepositoryDeployability -Entries (New-TestEntries -Files @('package.json', 'vite.config.ts') -Directories @('src', 'public'))
Assert-DeployEqual 'Vite' $viteResult.Framework 'Deployability: detects Vite'

$reactResult = Get-RepositoryDeployability -Entries (New-TestEntries -Files @('package.json') -Directories @('src')) -PackageJson (@{ dependencies = @{ react = '18.0.0' } } | ConvertTo-Json | ConvertFrom-Json)
Assert-DeployEqual 'React' $reactResult.Framework 'Deployability: detects React from package.json'

$staticResult = Get-RepositoryDeployability -Entries (New-TestEntries -Files @('index.html', 'style.css'))
Assert-DeployTrue $staticResult.Deployable 'Deployability: static HTML site is deployable'
Assert-DeployEqual 'Static HTML' $staticResult.Framework 'Deployability: detects static HTML'

$readmeResult = Get-RepositoryDeployability -Entries (New-TestEntries -Files @('README.md', 'LICENSE'))
Assert-DeployTrue (-not $readmeResult.Deployable) 'Deployability: README-only repository is not deployable'
Assert-DeployEqual 'Repository contains documentation only.' $readmeResult.Reason 'Deployability: README-only reason is explained'

$emptyResult = Get-RepositoryDeployability -Entries @()
Assert-DeployTrue (-not $emptyResult.Deployable) 'Deployability: empty repository is not deployable'

$scriptOnlyResult = Get-RepositoryDeployability -Entries (New-TestEntries -Files @('main.py', 'requirements.txt'))
Assert-DeployTrue (-not $scriptOnlyResult.Deployable) 'Deployability: repository with no web application is not deployable'

# ---------------------------------------------------------------------------
# Matching
# ---------------------------------------------------------------------------

function New-TestProject {
    param(
        [string]$Id,
        [string]$Name,
        [string]$GitOwner = '',
        [string]$GitRepo = '',
        [string]$ProductionBranch = ''
    )

    $gitFullName = ''
    if ($GitOwner -and $GitRepo) { $gitFullName = "$GitOwner/$GitRepo" }

    return [pscustomobject]@{
        Id                     = $Id
        Name                   = $Name
        Framework              = 'nextjs'
        GitType                = $(if ($GitOwner) { 'github' } else { '' })
        GitOwner               = $GitOwner
        GitRepo                = $GitRepo
        GitRepoId              = '12345'
        GitFullName            = $gitFullName
        ProductionBranch       = $ProductionBranch
        LatestProductionRecord = $null
    }
}

$projects = @(
    New-TestProject -Id 'prj_1' -Name 'dream-med-spa-demo' -GitOwner 'Novenworks' -GitRepo 'Dream-Med-Spa-Demo' -ProductionBranch 'main'
    New-TestProject -Id 'prj_2' -Name 'good-quality-hvac-demo'
    New-TestProject -Id 'prj_3' -Name 'good-quality-hvac-demo-8lrn'
    New-TestProject -Id 'prj_4' -Name 'healthzen-wellness-center-demo'
    New-TestProject -Id 'prj_5' -Name 'renamed-on-vercel'
)

$gitMatch = Find-VercelProjectMatch -Repository (New-TestRepository -Name 'Dream-Med-Spa-Demo') -Projects $projects
Assert-DeployEqual 'GitIntegration' $gitMatch.Method 'Matching: Git integration metadata wins'
Assert-DeployEqual 'prj_1' $gitMatch.Project.Id 'Matching: Git integration returns the linked project'

$nameMatch = Find-VercelProjectMatch -Repository (New-TestRepository -Name 'HealthZen-Wellness-Center-Demo') -Projects $projects
Assert-DeployEqual 'NormalizedName' $nameMatch.Method 'Matching: unique normalized name matches'
Assert-DeployEqual 'prj_4' $nameMatch.Project.Id 'Matching: normalized name returns the right project'

$ambiguousMatch = Find-VercelProjectMatch -Repository (New-TestRepository -Name 'Good-Quality-HVAC-Demo') -Projects $projects
Assert-DeployEqual 'Ambiguous' $ambiguousMatch.Method 'Matching: suffixed sibling project produces ambiguity'
Assert-DeployEqual 2 @($ambiguousMatch.Candidates).Count 'Matching: ambiguity lists both candidates'
Assert-DeployTrue ($null -eq $ambiguousMatch.Project) 'Matching: ambiguity never picks a project'

$mappedMatch = Find-VercelProjectMatch -Repository (New-TestRepository -Name 'Client-Portal-Demo') -Projects $projects -Mappings @{ 'Novenworks/Client-Portal-Demo' = 'renamed-on-vercel' }
Assert-DeployEqual 'ExplicitMapping' $mappedMatch.Method 'Matching: explicit configuration mapping is honored'
Assert-DeployEqual 'prj_5' $mappedMatch.Project.Id 'Matching: explicit mapping returns the mapped project'

$noMatch = Find-VercelProjectMatch -Repository (New-TestRepository -Name 'TIA-Medspa-Demo') -Projects $projects
Assert-DeployEqual 'None' $noMatch.Method 'Matching: unknown repository has no match'

$duplicateLinks = @(
    New-TestProject -Id 'prj_a' -Name 'twin-demo' -GitOwner 'Novenworks' -GitRepo 'Twin-Demo'
    New-TestProject -Id 'prj_b' -Name 'twin-demo-copy' -GitOwner 'Novenworks' -GitRepo 'Twin-Demo'
)
Assert-DeployEqual 'Ambiguous' (Find-VercelProjectMatch -Repository (New-TestRepository -Name 'Twin-Demo') -Projects $duplicateLinks).Method 'Matching: two projects linked to one repository is ambiguous'

$claimedProjects = @(
    New-TestProject -Id 'prj_x' -Name 'shared-demo' -GitOwner 'Novenworks' -GitRepo 'Other-Repo'
)
$portfolioMatches = Resolve-DeploymentMatches -Repositories @(
    (New-TestRepository -Name 'Other-Repo'),
    (New-TestRepository -Name 'Shared-Demo')
) -Projects $claimedProjects
Assert-DeployEqual 'GitIntegration' $portfolioMatches['Novenworks/Other-Repo'].Method 'Portfolio matching: definitive link resolved first'
Assert-DeployEqual 'None' $portfolioMatches['Novenworks/Shared-Demo'].Method 'Portfolio matching: a claimed project is not stolen by a name match'

# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

$eligible = [pscustomobject]@{ Eligible = $true; Rule = 'pattern'; Reason = 'Matches a deployment include pattern.' }
$ineligible = [pscustomobject]@{ Eligible = $false; Rule = 'archived'; Reason = 'Repository is archived.' }
$deployable = [pscustomobject]@{ Deployable = $true; Framework = 'Next.js'; Reason = 'Deployable web application detected.'; Indicators = @() }
$notDeployable = [pscustomobject]@{ Deployable = $false; Framework = 'Unknown'; Reason = 'Repository contains documentation only.'; Indicators = @() }

$readyDeployment = [pscustomobject]@{ Id = 'dpl_1'; State = 'READY'; Url = 'https://dream-med-spa-demo.vercel.app'; Branch = 'main'; Target = 'production' }

Assert-DeployEqual 'READY' (Get-DeploymentStatus -Eligibility $eligible -Deployability $deployable -Match $gitMatch -Deployment $readyDeployment -ExpectedBranch 'main').Status 'Classification: healthy project is READY'
Assert-DeployEqual 'SKIPPED' (Get-DeploymentStatus -Eligibility $ineligible -Deployability $deployable -Match $gitMatch -Deployment $readyDeployment -ExpectedBranch 'main').Status 'Classification: ineligible repository is SKIPPED'
Assert-DeployEqual 'NOT_DEPLOYABLE' (Get-DeploymentStatus -Eligibility $eligible -Deployability $notDeployable -Match $noMatch -ExpectedBranch 'main').Status 'Classification: non-deployable repository is NOT_DEPLOYABLE'
Assert-DeployEqual 'MISSING_VERCEL_PROJECT' (Get-DeploymentStatus -Eligibility $eligible -Deployability $deployable -Match $noMatch -ExpectedBranch 'main').Status 'Classification: unmatched repository is MISSING_VERCEL_PROJECT'
Assert-DeployEqual 'AMBIGUOUS_MATCH' (Get-DeploymentStatus -Eligibility $eligible -Deployability $deployable -Match $ambiguousMatch -ExpectedBranch 'main').Status 'Classification: ambiguous match is AMBIGUOUS_MATCH'
Assert-DeployEqual 'NO_PRODUCTION_DEPLOYMENT' (Get-DeploymentStatus -Eligibility $eligible -Deployability $deployable -Match $gitMatch -Deployment $null -ExpectedBranch 'main').Status 'Classification: no deployment is NO_PRODUCTION_DEPLOYMENT'
Assert-DeployEqual 'DEPLOYMENT_FAILED' (Get-DeploymentStatus -Eligibility $eligible -Deployability $deployable -Match $gitMatch -Deployment ([pscustomobject]@{ Id = 'dpl_2'; State = 'ERROR' }) -ExpectedBranch 'main').Status 'Classification: failed build is DEPLOYMENT_FAILED'
Assert-DeployEqual 'DEPLOYMENT_FAILED' (Get-DeploymentStatus -Eligibility $eligible -Deployability $deployable -Match $gitMatch -Deployment ([pscustomobject]@{ Id = 'dpl_3'; State = 'CANCELED' }) -ExpectedBranch 'main').Status 'Classification: canceled build is DEPLOYMENT_FAILED'
Assert-DeployEqual 'DEPLOYMENT_BUILDING' (Get-DeploymentStatus -Eligibility $eligible -Deployability $deployable -Match $gitMatch -Deployment ([pscustomobject]@{ Id = 'dpl_4'; State = 'BUILDING' }) -ExpectedBranch 'main').Status 'Classification: in-flight build is DEPLOYMENT_BUILDING'
Assert-DeployEqual 'PRODUCTION_BRANCH_MISMATCH' (Get-DeploymentStatus -Eligibility $eligible -Deployability $deployable -Match $gitMatch -Deployment $readyDeployment -ExpectedBranch 'develop').Status 'Classification: wrong production branch is PRODUCTION_BRANCH_MISMATCH'
Assert-DeployEqual 'AUTH_REQUIRED' (Get-DeploymentStatus -Eligibility $eligible -Deployability $deployable -Match $noMatch -ExpectedBranch 'main' -AuthRequired).Status 'Classification: missing Vercel auth is AUTH_REQUIRED'

$disconnectedMatch = [pscustomobject]@{
    Method     = 'NormalizedName'
    Project    = (New-TestProject -Id 'prj_9' -Name 'orphan-demo')
    Candidates = @()
    Reason     = 'Matched by normalized project name.'
}
Assert-DeployEqual 'GIT_NOT_CONNECTED' (Get-DeploymentStatus -Eligibility $eligible -Deployability $deployable -Match $disconnectedMatch -Deployment $readyDeployment -ExpectedBranch 'main').Status 'Classification: project without Git integration is GIT_NOT_CONNECTED'

# ---------------------------------------------------------------------------
# Planning
# ---------------------------------------------------------------------------

function New-TestCandidate {
    param([string]$Name, [string]$Status, [bool]$Deployable = $true)

    return New-DeploymentCandidate -Repository (New-TestRepository -Name $Name) `
        -Eligibility $eligible `
        -Deployability ([pscustomobject]@{ Deployable = $Deployable; Framework = 'Next.js'; Reason = ''; Indicators = @() }) `
        -Match $noMatch -ExpectedBranch 'main' -Status $Status -Detail ''
}

$planCandidates = @(
    New-TestCandidate -Name 'Healthy-Demo' -Status 'READY'
    New-TestCandidate -Name 'Missing-Demo' -Status 'MISSING_VERCEL_PROJECT'
    New-TestCandidate -Name 'Docs-Demo' -Status 'MISSING_VERCEL_PROJECT' -Deployable $false
    New-TestCandidate -Name 'Stale-Demo' -Status 'NO_PRODUCTION_DEPLOYMENT'
    New-TestCandidate -Name 'Broken-Demo' -Status 'DEPLOYMENT_FAILED'
    New-TestCandidate -Name 'Twin-Demo' -Status 'AMBIGUOUS_MATCH'
)
$plan = New-DeploymentPlan -Candidates $planCandidates

Assert-DeployEqual 1 @($plan.Creations).Count 'Plan: only deployable missing projects are proposed for creation'
Assert-DeployEqual 'Missing-Demo' $plan.Creations[0].GithubRepo 'Plan: proposes the right repository'
Assert-DeployEqual 1 @($plan.Deployments).Count 'Plan: proposes a deployment for a connected project with no production build'
Assert-DeployEqual 2 @($plan.Review).Count 'Plan: failures and ambiguity go to human review'
Assert-DeployEqual 2 $plan.ChangeCount 'Plan: change count covers only mutating actions'
Assert-DeployEqual 'None' (Get-DeploymentActionForCandidate -Candidate $planCandidates[0]) 'Safety: a healthy project is never touched'
Assert-DeployEqual 'Review' (Get-DeploymentActionForCandidate -Candidate $planCandidates[4]) 'Safety: a failed build is reported, never auto-redeployed'

$summary = Get-DeploymentSummary -Candidates $planCandidates
Assert-DeployEqual 2 $summary['MISSING_VERCEL_PROJECT'] 'Reporting: summary counts statuses'

$reportObject = ConvertTo-DeploymentReportObject -Operation 'audit' -Owners @('Novenworks') -Candidates $planCandidates -RepositoriesDiscovered 211
$reportJson = $reportObject | ConvertTo-Json -Depth 8
Assert-DeployEqual 6 @($reportObject.repositories).Count 'Reporting: report includes every candidate'
Assert-DeployEqual 211 $reportObject.repositoriesDiscovered 'Reporting: report records repositories discovered'
Assert-DeployTrue ($reportJson -notmatch '(?i)token|authorization|bearer|secret') 'Security: JSON report contains no credential fields'

# ---------------------------------------------------------------------------
# Mocked GitHub and Vercel services
# ---------------------------------------------------------------------------

$script:MockGhRepositories = @{}
$script:MockGhContents = @{}
$script:MockGhFailures = @{}
$script:MockVercelProjects = @()
$script:MockVercelDeployments = @()
$script:MockApiCalls = @()
$script:MockProjectCounter = 0
$script:MockDeploymentCounter = 0

function Reset-MockServices {
    $script:MockGhRepositories = @{}
    $script:MockGhContents = @{}
    $script:MockGhFailures = @{}
    $script:MockVercelProjects = @()
    $script:MockVercelDeployments = @()
    $script:MockApiCalls = @()
    $script:MockProjectCounter = 0
    $script:MockDeploymentCounter = 0
}

function Get-MockMutatingCallCount {
    # Counts Vercel write calls only. GitHub reads are recorded with a "GH " prefix.
    return @($script:MockApiCalls | Where-Object { $_ -match '^(POST|PATCH|PUT|DELETE) ' }).Count
}

function Test-CommandExists { param([string]$Name) return $true }
function Test-GhAuthenticated { return $true }

function Invoke-DeployGhJson {
    param([string[]]$ArgumentList)

    $joined = ($ArgumentList -join ' ')
    $script:MockApiCalls += "GH $joined"

    if ($ArgumentList[0] -eq 'repo' -and $ArgumentList[1] -eq 'list') {
        $owner = $ArgumentList[2]

        if ($script:MockGhFailures.ContainsKey("owner:$owner")) {
            return [pscustomobject]@{ Success = $false; Data = $null; Error = $script:MockGhFailures["owner:$owner"]; RateLimited = $false; NotFound = $false; Unauthorized = $false }
        }

        $records = @()
        if ($script:MockGhRepositories.ContainsKey($owner)) {
            $records = @($script:MockGhRepositories[$owner])
        }

        return [pscustomobject]@{ Success = $true; Data = $records; Error = $null; RateLimited = $false; NotFound = $false; Unauthorized = $false }
    }

    if ($ArgumentList[0] -eq 'api') {
        $path = $ArgumentList[1]

        if ($script:MockGhFailures.ContainsKey($path)) {
            return [pscustomobject]@{ Success = $false; Data = $null; Error = $script:MockGhFailures[$path]; RateLimited = $false; NotFound = $false; Unauthorized = $false }
        }

        if ($script:MockGhContents.ContainsKey($path)) {
            return [pscustomobject]@{ Success = $true; Data = $script:MockGhContents[$path]; Error = $null; RateLimited = $false; NotFound = $false; Unauthorized = $false }
        }

        return [pscustomobject]@{ Success = $false; Data = $null; Error = 'Repository or resource not found on GitHub.'; RateLimited = $false; NotFound = $true; Unauthorized = $false }
    }

    return [pscustomobject]@{ Success = $false; Data = $null; Error = 'Unsupported mock command.'; RateLimited = $false; NotFound = $false; Unauthorized = $false }
}

function Invoke-VercelApi {
    param(
        [string]$Path,
        [string]$Method = 'GET',
        $Body,
        $Query,
        [string]$TeamId,
        [int]$TimeoutSeconds = 60,
        [int]$MaxRetries = 2
    )

    $script:MockApiCalls += "$Method $Path"

    if ($Method -eq 'GET' -and $Path -eq '/v9/projects') {
        return [pscustomobject]@{
            Success = $true
            Data    = [pscustomobject]@{ projects = @($script:MockVercelProjects); pagination = [pscustomobject]@{ next = $null } }
            Error   = $null; AuthRequired = $false; RateLimited = $false; NotFound = $false; Conflict = $false; StatusCode = 200
        }
    }

    if ($Method -eq 'GET' -and $Path -like '/v9/projects/*') {
        $name = [uri]::UnescapeDataString($Path.Substring('/v9/projects/'.Length))
        $found = @($script:MockVercelProjects | Where-Object { $_.name -eq $name }) | Select-Object -First 1

        if ($found) {
            return [pscustomobject]@{ Success = $true; Data = $found; Error = $null; AuthRequired = $false; RateLimited = $false; NotFound = $false; Conflict = $false; StatusCode = 200 }
        }

        return [pscustomobject]@{ Success = $false; Data = $null; Error = 'Not found'; AuthRequired = $false; RateLimited = $false; NotFound = $true; Conflict = $false; StatusCode = 404 }
    }

    if ($Method -eq 'POST' -and $Path -eq '/v11/projects') {
        $name = [string]$Body.name

        if (@($script:MockVercelProjects | Where-Object { $_.name -eq $name }).Count -gt 0) {
            return [pscustomobject]@{ Success = $false; Data = $null; Error = 'A project with that name already exists.'; AuthRequired = $false; RateLimited = $false; NotFound = $false; Conflict = $true; StatusCode = 409 }
        }

        $script:MockProjectCounter++
        $repoParts = ([string]$Body.gitRepository.repo -split '/')

        $project = [pscustomobject]@{
            id      = "prj_mock_$($script:MockProjectCounter)"
            name    = $name
            link    = [pscustomobject]@{
                type             = 'github'
                org              = $repoParts[0]
                repo             = $repoParts[1]
                repoId           = '999'
                productionBranch = [string]$Body.gitRepository.productionBranch
            }
            targets = $null
        }

        $script:MockVercelProjects += $project
        return [pscustomobject]@{ Success = $true; Data = $project; Error = $null; AuthRequired = $false; RateLimited = $false; NotFound = $false; Conflict = $false; StatusCode = 200 }
    }

    if ($Method -eq 'GET' -and $Path -eq '/v6/deployments') {
        $projectId = [string]$Query['projectId']
        $found = @($script:MockVercelDeployments | Where-Object { $_.projectId -eq $projectId })

        return [pscustomobject]@{
            Success = $true
            Data    = [pscustomobject]@{ deployments = @($found) }
            Error   = $null; AuthRequired = $false; RateLimited = $false; NotFound = $false; Conflict = $false; StatusCode = 200
        }
    }

    if ($Method -eq 'POST' -and $Path -eq '/v13/deployments') {
        $script:MockDeploymentCounter++
        $name = [string]$Body.name
        $project = @($script:MockVercelProjects | Where-Object { $_.name -eq $name }) | Select-Object -First 1

        $deployment = [pscustomobject]@{
            uid        = "dpl_mock_$($script:MockDeploymentCounter)"
            projectId  = $(if ($project) { $project.id } else { 'prj_unknown' })
            readyState = 'READY'
            url        = "$name.vercel.app"
            target     = 'production'
            meta       = [pscustomobject]@{ githubCommitRef = [string]$Body.gitSource.ref }
        }

        $script:MockVercelDeployments += $deployment
        return [pscustomobject]@{ Success = $true; Data = $deployment; Error = $null; AuthRequired = $false; RateLimited = $false; NotFound = $false; Conflict = $false; StatusCode = 200 }
    }

    if ($Method -eq 'GET' -and $Path -like '/v13/deployments/*') {
        $id = $Path.Substring('/v13/deployments/'.Length)
        $found = @($script:MockVercelDeployments | Where-Object { $_.uid -eq $id }) | Select-Object -First 1

        if ($found) {
            return [pscustomobject]@{ Success = $true; Data = $found; Error = $null; AuthRequired = $false; RateLimited = $false; NotFound = $false; Conflict = $false; StatusCode = 200 }
        }

        return [pscustomobject]@{ Success = $false; Data = $null; Error = 'Not found'; AuthRequired = $false; RateLimited = $false; NotFound = $true; Conflict = $false; StatusCode = 404 }
    }

    return [pscustomobject]@{ Success = $false; Data = $null; Error = "Unmocked call: $Method $Path"; AuthRequired = $false; RateLimited = $false; NotFound = $false; Conflict = $false; StatusCode = 500 }
}

function Save-DeploymentReport {
    param($Report)
    return [pscustomobject]@{ Success = $true; Path = '(test)'; Error = $null }
}

function Add-MockRepository {
    param(
        [string]$Owner = 'Novenworks',
        [string]$Name,
        [string]$DefaultBranch = 'main',
        [bool]$IsArchived = $false,
        [string[]]$Files = @('package.json', 'next.config.js'),
        [string[]]$Directories = @('app')
    )

    if (-not $script:MockGhRepositories.ContainsKey($Owner)) {
        $script:MockGhRepositories[$Owner] = @()
    }

    $script:MockGhRepositories[$Owner] += [pscustomobject]@{
        name             = $Name
        nameWithOwner    = "$Owner/$Name"
        owner            = [pscustomobject]@{ login = $Owner }
        defaultBranchRef = [pscustomobject]@{ name = $DefaultBranch }
        visibility       = 'PUBLIC'
        isArchived       = $IsArchived
        isFork           = $false
        isTemplate       = $false
        isEmpty          = $false
        url              = "https://github.com/$Owner/$Name"
        pushedAt         = '2026-01-01T00:00:00Z'
    }

    $entries = @()
    foreach ($file in $Files) { $entries += [pscustomobject]@{ name = $file; type = 'file' } }
    foreach ($directory in $Directories) { $entries += [pscustomobject]@{ name = $directory; type = 'dir' } }
    $script:MockGhContents["repos/$Owner/$Name/contents"] = $entries
}

function New-MockTestConfig {
    return @{
        workspacePath = 'C:\Projects'
        githubOwners  = @('Novenworks')
        deployments   = @{
            repositoryFilters = @{ includeNamePatterns = @('*demo*') }
            requestDelayMilliseconds = 0
            pollIntervalSeconds      = 2
        }
    }
}

# ---------------------------------------------------------------------------
# Audit is read-only
# ---------------------------------------------------------------------------

$env:VERCEL_TOKEN = 'mock'

Reset-MockServices
Add-MockRepository -Name 'Dream-Med-Spa-Demo'
Add-MockRepository -Name 'TIA-Medspa-Demo'
Add-MockRepository -Name 'Docs-Demo' -Files @('README.md') -Directories @()
Add-MockRepository -Name 'dev-tools' -Files @('README.md') -Directories @()
Add-MockRepository -Name 'Old-Demo' -IsArchived $true

$script:MockVercelProjects += [pscustomobject]@{
    id      = 'prj_existing'
    name    = 'dream-med-spa-demo'
    link    = [pscustomobject]@{ type = 'github'; org = 'Novenworks'; repo = 'Dream-Med-Spa-Demo'; repoId = '1'; productionBranch = 'main' }
    targets = [pscustomobject]@{ production = [pscustomobject]@{ uid = 'dpl_existing'; readyState = 'READY'; url = 'dream-med-spa-demo.vercel.app'; target = 'production' } }
}

$testConfig = New-MockTestConfig
$deploymentConfig = Get-DeploymentConfig -ConfigObject $testConfig
$audit = Invoke-DeploymentAudit -ConfigObject $testConfig -DeploymentConfig $deploymentConfig -Quiet

Assert-DeployEqual 5 $audit.Discovered 'Audit: discovers every repository'
Assert-DeployEqual 3 @($audit.Candidates).Count 'Audit: applies eligibility rules to build candidates'
Assert-DeployEqual 2 @($audit.Skipped).Count 'Audit: records skipped repositories separately'
Assert-DeployEqual 0 (Get-MockMutatingCallCount) 'Safety: audit performs zero mutating API calls'

$dreamCandidate = @($audit.Candidates | Where-Object { $_.GithubRepo -eq 'Dream-Med-Spa-Demo' })[0]
Assert-DeployEqual 'READY' $dreamCandidate.Status 'Audit: existing healthy project is READY'
Assert-DeployEqual 'GitIntegration' $dreamCandidate.MatchMethod 'Audit: healthy project matched by Git integration'
Assert-DeployEqual 'https://dream-med-spa-demo.vercel.app' $dreamCandidate.ProductionUrl 'Audit: production URL is captured'

$tiaCandidate = @($audit.Candidates | Where-Object { $_.GithubRepo -eq 'TIA-Medspa-Demo' })[0]
Assert-DeployEqual 'MISSING_VERCEL_PROJECT' $tiaCandidate.Status 'Audit: repository with no Vercel project is MISSING_VERCEL_PROJECT'
Assert-DeployEqual 'tia-medspa-demo' $tiaCandidate.ProposedProject 'Audit: proposes a normalized project name'

$docsCandidate = @($audit.Candidates | Where-Object { $_.GithubRepo -eq 'Docs-Demo' })[0]
Assert-DeployEqual 'NOT_DEPLOYABLE' $docsCandidate.Status 'Audit: documentation-only repository is NOT_DEPLOYABLE'

# ---------------------------------------------------------------------------
# Plan is read-only
# ---------------------------------------------------------------------------

$auditPlan = New-DeploymentPlan -Candidates $audit.Candidates
Assert-DeployEqual 1 @($auditPlan.Creations).Count 'Plan: exactly one project would be created'
Assert-DeployEqual 0 (Get-MockMutatingCallCount) 'Safety: planning performs zero mutating API calls'

# ---------------------------------------------------------------------------
# Sync requires confirmation
# ---------------------------------------------------------------------------

$script:ConfirmationRequested = $false
$script:ConfirmationAnswer = $false

function Show-DeploymentSyncConfirmation {
    param($Plan)
    $script:ConfirmationRequested = $true
    return $script:ConfirmationAnswer
}

$script:ConfirmationAnswer = $false
$declinedExit = Invoke-DeploymentSyncCommand -ConfigObject $testConfig 6>$null

Assert-DeployTrue $script:ConfirmationRequested 'Safety: sync asks for confirmation before changing anything'
Assert-DeployEqual 0 (Get-MockMutatingCallCount) 'Safety: declining confirmation performs zero writes'
Assert-DeployEqual 0 $declinedExit 'Safety: a declined sync exits cleanly'
Assert-DeployEqual 1 @($script:MockVercelProjects).Count 'Safety: declining confirmation created no Vercel project'

# ---------------------------------------------------------------------------
# Sync applies the plan after approval, and is idempotent
# ---------------------------------------------------------------------------

$script:ConfirmationAnswer = $true
$firstExit = Invoke-DeploymentSyncCommand -ConfigObject $testConfig 6>$null

Assert-DeployEqual 0 $firstExit 'Sync: approved sync completes successfully'
Assert-DeployEqual 2 @($script:MockVercelProjects).Count 'Sync: the missing project was created'
Assert-DeployTrue (@($script:MockVercelProjects | Where-Object { $_.name -eq 'tia-medspa-demo' }).Count -eq 1) 'Sync: created project uses the normalized name'
Assert-DeployTrue (@($script:MockVercelDeployments).Count -ge 1) 'Sync: a production deployment was started'

$createdProject = @($script:MockVercelProjects | Where-Object { $_.name -eq 'tia-medspa-demo' })[0]
Assert-DeployEqual 'Novenworks' $createdProject.link.org 'Sync: created project is connected to the right GitHub owner'
Assert-DeployEqual 'TIA-Medspa-Demo' $createdProject.link.repo 'Sync: created project is connected to the right repository'
Assert-DeployEqual 'main' $createdProject.link.productionBranch 'Sync: created project uses the repository default branch'

$createCallsAfterFirst = @($script:MockApiCalls | Where-Object { $_ -eq 'POST /v11/projects' }).Count
$deployCallsAfterFirst = @($script:MockApiCalls | Where-Object { $_ -eq 'POST /v13/deployments' }).Count

$secondExit = Invoke-DeploymentSyncCommand -ConfigObject $testConfig 6>$null
$createCallsAfterSecond = @($script:MockApiCalls | Where-Object { $_ -eq 'POST /v11/projects' }).Count
$deployCallsAfterSecond = @($script:MockApiCalls | Where-Object { $_ -eq 'POST /v13/deployments' }).Count

Assert-DeployEqual 0 $secondExit 'Idempotency: a second sync completes successfully'
Assert-DeployEqual 2 @($script:MockVercelProjects).Count 'Idempotency: a second sync creates no duplicate project'
Assert-DeployEqual $createCallsAfterFirst $createCallsAfterSecond 'Idempotency: a second sync issues no new create calls'
Assert-DeployEqual $deployCallsAfterFirst $deployCallsAfterSecond 'Idempotency: a second sync issues no new deployment calls'

$finalAudit = Invoke-DeploymentAudit -ConfigObject $testConfig -DeploymentConfig $deploymentConfig -Quiet
$tiaFinal = @($finalAudit.Candidates | Where-Object { $_.GithubRepo -eq 'TIA-Medspa-Demo' })[0]
Assert-DeployEqual 'READY' $tiaFinal.Status 'Idempotency: the created project audits as READY on the next run'
Assert-DeployEqual 0 (New-DeploymentPlan -Candidates $finalAudit.Candidates).ChangeCount 'Idempotency: nothing is left to change'

# ---------------------------------------------------------------------------
# Error resilience
# ---------------------------------------------------------------------------

Reset-MockServices
Add-MockRepository -Name 'Working-Demo'
Add-MockRepository -Name 'Broken-Demo'
Add-MockRepository -Name 'Another-Demo'
$script:MockGhFailures['repos/Novenworks/Broken-Demo/contents'] = 'GitHub API rate limit reached.'

$resilientAudit = Invoke-DeploymentAudit -ConfigObject $testConfig -DeploymentConfig $deploymentConfig -Quiet
Assert-DeployEqual 3 @($resilientAudit.Candidates).Count 'Resilience: one failing repository does not stop the batch'

$brokenCandidate = @($resilientAudit.Candidates | Where-Object { $_.GithubRepo -eq 'Broken-Demo' })[0]
Assert-DeployTrue (-not [string]::IsNullOrWhiteSpace([string]$brokenCandidate.Error)) 'Resilience: the failing repository records its error'
Assert-DeployEqual 'NOT_DEPLOYABLE' $brokenCandidate.Status 'Resilience: an uninspectable repository is never proposed for creation'
Assert-DeployEqual 'MISSING_VERCEL_PROJECT' (@($resilientAudit.Candidates | Where-Object { $_.GithubRepo -eq 'Working-Demo' })[0]).Status 'Resilience: healthy repositories are still classified'

Reset-MockServices
Add-MockRepository -Name 'Solo-Demo'
$script:MockGhFailures['owner:Missing-Org'] = 'Could not list repositories.'
$multiOwnerConfig = New-MockTestConfig
$multiOwnerConfig.githubOwners = @('Novenworks', 'Missing-Org')

$multiOwnerAudit = Invoke-DeploymentAudit -ConfigObject $multiOwnerConfig -DeploymentConfig $deploymentConfig -Quiet
Assert-DeployEqual 1 @($multiOwnerAudit.Candidates).Count 'Resilience: a failing owner does not stop the other owners'
Assert-DeployTrue (@($multiOwnerAudit.Warnings).Count -ge 1) 'Resilience: the failing owner is recorded as a warning'

# ---------------------------------------------------------------------------
# Missing Vercel authentication
# ---------------------------------------------------------------------------

Reset-MockServices
Add-MockRepository -Name 'Offline-Demo'
$env:VERCEL_TOKEN = ''

$offlineAudit = Invoke-DeploymentAudit -ConfigObject $testConfig -DeploymentConfig $deploymentConfig -Quiet
Assert-DeployEqual 'AUTH_REQUIRED' (@($offlineAudit.Candidates)[0]).Status 'Auth: without a Vercel token candidates report AUTH_REQUIRED'
Assert-DeployTrue $offlineAudit.AuthRequired 'Auth: the audit flags that Vercel authentication is required'
Assert-DeployEqual 0 (Get-MockMutatingCallCount) 'Auth: no calls are attempted without a token'

$offlineSyncExit = Invoke-DeploymentSyncCommand -ConfigObject $testConfig 6>$null
Assert-DeployEqual 1 $offlineSyncExit 'Auth: sync refuses to run without Vercel authentication'
Assert-DeployEqual 0 (Get-MockMutatingCallCount) 'Auth: a refused sync performs zero writes'

$env:VERCEL_TOKEN = ''
Remove-Item Env:\VERCEL_TOKEN -ErrorAction SilentlyContinue

# ---------------------------------------------------------------------------
# Saving preferences must not delete the deployments section
# ---------------------------------------------------------------------------

. (Join-Path $ProjectRoot 'lib\config.ps1')

$originalRoot = $DevToolsRoot
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('devtools-config-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $DevToolsRoot = $tempRoot

    $configWithDeployments = '{"workspacePath":"C:\\Projects","githubOwners":["Novenworks"],"defaultEditor":"cursor","autoBackupMessage":"Auto backup","autoUpdate":false,"deployments":{"vercelTeam":"novenworks-team","repositoryFilters":{"includeNamePatterns":["*demo*"]}}}' | ConvertFrom-Json

    Save-DevToolsConfig -ConfigObject $configWithDeployments
    $reloaded = Get-Content -LiteralPath (Join-Path $tempRoot 'config.json') -Raw | ConvertFrom-Json

    Assert-DeployTrue ($null -ne $reloaded.deployments) 'Config: saving preferences preserves the deployments section'
    Assert-DeployEqual 'novenworks-team' $reloaded.deployments.vercelTeam 'Config: preserved deployment settings keep their values'
    Assert-DeployEqual 'C:\Projects' $reloaded.workspacePath 'Config: core settings still save correctly'
    Assert-DeployTrue (((Get-Content -LiteralPath (Join-Path $tempRoot 'config.json') -Raw) -notmatch '(?i)token')) 'Security: saved config contains no token field'
}
finally {
    $DevToolsRoot = $originalRoot
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host 'Deployment Manager Test Summary' -ForegroundColor Cyan
Write-Host "Assertions passed: $($script:DeployTestPassed)"

if ($script:DeployTestFailed) {
    Write-Host 'Result: FAIL' -ForegroundColor Red
    exit 1
}

Write-Host 'Result: PASS' -ForegroundColor Green
exit 0
