# Deployment Manager — Vercel REST client.
#
# Security rules for this file:
#   * The token is read from the VERCEL_TOKEN environment variable only.
#   * The token is never written to config.json, reports, logs, or the terminal.
#   * Authorization headers are never printed, even in error paths.

function Get-VercelApiBaseUrl {
    return 'https://api.vercel.com'
}

function Get-VercelToken {
    <#
    .SYNOPSIS
        Returns the Vercel API token from the environment, or an empty string.
    #>
    $token = [string]$env:VERCEL_TOKEN

    if ([string]::IsNullOrWhiteSpace($token)) {
        return ''
    }

    return $token.Trim()
}

function Test-VercelAuthenticated {
    return -not [string]::IsNullOrWhiteSpace((Get-VercelToken))
}

function Get-VercelTeamSetting {
    <#
    .SYNOPSIS
        Returns the configured Vercel team slug or id.
    .DESCRIPTION
        VERCEL_TEAM_ID wins when set; otherwise the non-secret team value stored
        in DevTools configuration is used.
    #>
    param($DeploymentConfig)

    $fromEnvironment = [string]$env:VERCEL_TEAM_ID
    if (-not [string]::IsNullOrWhiteSpace($fromEnvironment)) {
        return $fromEnvironment.Trim()
    }

    if ($DeploymentConfig -and -not [string]::IsNullOrWhiteSpace([string]$DeploymentConfig.VercelTeam)) {
        return ([string]$DeploymentConfig.VercelTeam).Trim()
    }

    return ''
}

function Enable-DeployTls12 {
    <#
    .SYNOPSIS
        Ensures TLS 1.2 is available on Windows PowerShell 5.1.
    #>
    try {
        if ([Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12') {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        }
    }
    catch {
        # Older or restricted hosts: continue with the platform default.
    }
}

function ConvertTo-VercelQueryString {
    param($Query)

    if (-not $Query -or $Query.Keys.Count -eq 0) {
        return ''
    }

    $parts = @()
    foreach ($key in $Query.Keys) {
        $value = $Query[$key]
        if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { continue }
        $parts += ('{0}={1}' -f [uri]::EscapeDataString([string]$key), [uri]::EscapeDataString([string]$value))
    }

    if ($parts.Count -eq 0) {
        return ''
    }

    return '?' + ($parts -join '&')
}

function Get-VercelErrorMessage {
    <#
    .SYNOPSIS
        Produces a safe, readable message from a failed Vercel request.
    .DESCRIPTION
        Only the response body's error message is surfaced. Request headers are
        never included so the token cannot leak into output or reports.
    #>
    param($ErrorRecord)

    $statusCode = 0
    $body = ''

    try {
        $response = $ErrorRecord.Exception.Response
        if ($response) {
            try { $statusCode = [int]$response.StatusCode } catch { $statusCode = 0 }

            if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
                $body = [string]$ErrorRecord.ErrorDetails.Message
            }
            elseif ($response.GetResponseStream) {
                $stream = $response.GetResponseStream()
                if ($stream) {
                    $reader = New-Object System.IO.StreamReader($stream)
                    $body = $reader.ReadToEnd()
                    $reader.Dispose()
                }
            }
        }
    }
    catch {
        $body = ''
    }

    $message = ''
    $code = ''

    if (-not [string]::IsNullOrWhiteSpace($body)) {
        try {
            $parsed = $body | ConvertFrom-Json
            if ($parsed.error) {
                $message = [string]$parsed.error.message
                $code = [string]$parsed.error.code
            }
        }
        catch {
            $message = ''
        }
    }

    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = $ErrorRecord.Exception.Message
    }

    return [pscustomobject]@{
        StatusCode  = $statusCode
        Code        = $code
        Message     = $message
        RateLimited = ($statusCode -eq 429)
        NotFound    = ($statusCode -eq 404)
        AuthFailed  = ($statusCode -eq 401 -or $statusCode -eq 403)
        Conflict    = ($statusCode -eq 409 -or $code -eq 'conflict' -or $message -match 'already exists')
    }
}

function Invoke-VercelApi {
    <#
    .SYNOPSIS
        Performs a single authenticated Vercel API request.
    .DESCRIPTION
        Returns a result object rather than throwing. Retries once on HTTP 429 so
        portfolio operations survive Vercel rate limiting.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Method = 'GET',
        $Body,
        $Query,
        [string]$TeamId,
        [int]$TimeoutSeconds = 60,
        [int]$MaxRetries = 2
    )

    $token = Get-VercelToken
    if ([string]::IsNullOrWhiteSpace($token)) {
        return [pscustomobject]@{
            Success      = $false
            Data         = $null
            Error        = 'Vercel authentication is required. Set the VERCEL_TOKEN environment variable.'
            AuthRequired = $true
            RateLimited  = $false
            NotFound     = $false
            Conflict     = $false
            StatusCode   = 0
        }
    }

    Enable-DeployTls12

    $queryTable = New-Object 'System.Collections.Specialized.OrderedDictionary'
    if ($Query) {
        foreach ($key in $Query.Keys) {
            $queryTable[$key] = $Query[$key]
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($TeamId)) {
        $queryTable['teamId'] = $TeamId
    }

    $uri = '{0}{1}{2}' -f (Get-VercelApiBaseUrl), $Path, (ConvertTo-VercelQueryString -Query $queryTable)
    $headers = @{ Authorization = "Bearer $token" }

    $attempt = 0
    while ($true) {
        $attempt++

        try {
            $parameters = @{
                Uri         = $uri
                Method      = $Method
                Headers     = $headers
                TimeoutSec  = $TimeoutSeconds
                ErrorAction = 'Stop'
            }

            if ($null -ne $Body) {
                $parameters['Body'] = ($Body | ConvertTo-Json -Depth 10)
                $parameters['ContentType'] = 'application/json'
            }

            $response = Invoke-RestMethod @parameters

            return [pscustomobject]@{
                Success      = $true
                Data         = $response
                Error        = $null
                AuthRequired = $false
                RateLimited  = $false
                NotFound     = $false
                Conflict     = $false
                StatusCode   = 200
            }
        }
        catch {
            $details = Get-VercelErrorMessage -ErrorRecord $_

            if ($details.RateLimited -and $attempt -lt $MaxRetries) {
                Start-Sleep -Seconds ([math]::Min(30, 5 * $attempt))
                continue
            }

            $message = $details.Message
            if ($details.RateLimited) {
                $message = 'Vercel rate limit reached. Wait a moment and try again.'
            }
            elseif ($details.AuthFailed) {
                $message = 'Vercel rejected the request. Check VERCEL_TOKEN and team access.'
            }

            return [pscustomobject]@{
                Success      = $false
                Data         = $null
                Error        = $message
                AuthRequired = $details.AuthFailed
                RateLimited  = $details.RateLimited
                NotFound     = $details.NotFound
                Conflict     = $details.Conflict
                StatusCode   = $details.StatusCode
            }
        }
    }
}

function Resolve-VercelTeamId {
    <#
    .SYNOPSIS
        Resolves a configured team slug or id into a Vercel team id.
    #>
    param([string]$TeamSetting)

    if ([string]::IsNullOrWhiteSpace($TeamSetting)) {
        return [pscustomobject]@{ Success = $true; TeamId = ''; TeamSlug = ''; Error = $null }
    }

    $value = $TeamSetting.Trim()

    if ($value.StartsWith('team_')) {
        return [pscustomobject]@{ Success = $true; TeamId = $value; TeamSlug = ''; Error = $null }
    }

    $result = Invoke-VercelApi -Path '/v2/team' -Query @{ slug = $value }

    if (-not $result.Success) {
        return [pscustomobject]@{ Success = $false; TeamId = ''; TeamSlug = $value; Error = $result.Error }
    }

    $teamId = [string]$result.Data.id
    if ([string]::IsNullOrWhiteSpace($teamId)) {
        return [pscustomobject]@{ Success = $false; TeamId = ''; TeamSlug = $value; Error = "Vercel team '$value' was not found." }
    }

    return [pscustomobject]@{ Success = $true; TeamId = $teamId; TeamSlug = $value; Error = $null }
}

function ConvertFrom-VercelProject {
    <#
    .SYNOPSIS
        Maps a Vercel project payload onto the DevTools deployment model.
    #>
    param($Record)

    $link = $Record.link
    $gitType = ''
    $gitOwner = ''
    $gitRepo = ''
    $gitRepoId = ''
    $productionBranch = ''

    if ($link) {
        $gitType = [string]$link.type
        $gitOwner = [string]$link.org
        if ([string]::IsNullOrWhiteSpace($gitOwner)) { $gitOwner = [string]$link.owner }
        $gitRepo = [string]$link.repo
        $gitRepoId = [string]$link.repoId
        $productionBranch = [string]$link.productionBranch
    }

    $latestProduction = $null
    if ($Record.targets -and $Record.targets.production) {
        $latestProduction = $Record.targets.production
    }

    $gitFullName = ''
    if (-not [string]::IsNullOrWhiteSpace($gitOwner) -and -not [string]::IsNullOrWhiteSpace($gitRepo)) {
        $gitFullName = "$gitOwner/$gitRepo"
    }

    return [pscustomobject]@{
        Id                     = [string]$Record.id
        Name                   = [string]$Record.name
        Framework              = [string]$Record.framework
        GitType                = $gitType
        GitOwner               = $gitOwner
        GitRepo                = $gitRepo
        GitRepoId              = $gitRepoId
        GitFullName            = $gitFullName
        ProductionBranch       = $productionBranch
        LatestProductionRecord = $latestProduction
    }
}

function Get-VercelProjects {
    <#
    .SYNOPSIS
        Retrieves every Vercel project for the configured account or team.
    .DESCRIPTION
        Follows Vercel's cursor pagination. Never assumes the account holds fewer
        than one page of projects.
    #>
    param(
        [string]$TeamId,
        [int]$PageSize = 100,
        [int]$MaxPages = 100
    )

    $projects = @()
    $until = $null
    $page = 0

    while ($page -lt $MaxPages) {
        $page++

        $query = @{ limit = "$PageSize" }
        if ($until) { $query['until'] = "$until" }

        $result = Invoke-VercelApi -Path '/v9/projects' -Query $query -TeamId $TeamId

        if (-not $result.Success) {
            return [pscustomobject]@{
                Success      = $false
                Projects     = @($projects)
                Error        = $result.Error
                AuthRequired = $result.AuthRequired
            }
        }

        foreach ($record in @($result.Data.projects)) {
            if ($null -eq $record) { continue }
            $projects += (ConvertFrom-VercelProject -Record $record)
        }

        $next = $null
        if ($result.Data.pagination) {
            $next = $result.Data.pagination.next
        }

        if ($null -eq $next -or [string]::IsNullOrWhiteSpace([string]$next)) {
            break
        }

        $until = $next
    }

    return [pscustomobject]@{
        Success      = $true
        Projects     = @($projects)
        Error        = $null
        AuthRequired = $false
    }
}

function ConvertFrom-VercelDeployment {
    <#
    .SYNOPSIS
        Normalizes the several shapes Vercel uses for deployment records.
    #>
    param($Record)

    if ($null -eq $Record) {
        return $null
    }

    $id = [string]$Record.uid
    if ([string]::IsNullOrWhiteSpace($id)) { $id = [string]$Record.id }

    $state = [string]$Record.readyState
    if ([string]::IsNullOrWhiteSpace($state)) { $state = [string]$Record.state }
    if ([string]::IsNullOrWhiteSpace($state)) { $state = 'UNKNOWN' }

    $url = [string]$Record.url
    if (-not [string]::IsNullOrWhiteSpace($url) -and $url -notmatch '^https?://') {
        $url = "https://$url"
    }

    $branch = ''
    if ($Record.meta) {
        $branch = [string]$Record.meta.githubCommitRef
        if ([string]::IsNullOrWhiteSpace($branch)) { $branch = [string]$Record.meta.branch }
    }
    if ([string]::IsNullOrWhiteSpace($branch) -and $Record.gitSource) {
        $branch = [string]$Record.gitSource.ref
    }

    return [pscustomobject]@{
        Id     = $id
        State  = $state.ToUpperInvariant()
        Url    = $url
        Branch = $branch
        Target = [string]$Record.target
    }
}

function Get-VercelLatestProductionDeployment {
    <#
    .SYNOPSIS
        Returns the latest production deployment for a project.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$ProjectId,
        [string]$TeamId
    )

    $result = Invoke-VercelApi -Path '/v6/deployments' -Query @{ projectId = $ProjectId; target = 'production'; limit = '1' } -TeamId $TeamId

    if (-not $result.Success) {
        return [pscustomobject]@{ Success = $false; Deployment = $null; Error = $result.Error }
    }

    $record = @($result.Data.deployments) | Select-Object -First 1

    return [pscustomobject]@{
        Success    = $true
        Deployment = (ConvertFrom-VercelDeployment -Record $record)
        Error      = $null
    }
}

function Get-VercelDeployment {
    param(
        [Parameter(Mandatory = $true)][string]$DeploymentId,
        [string]$TeamId
    )

    $result = Invoke-VercelApi -Path "/v13/deployments/$DeploymentId" -TeamId $TeamId

    if (-not $result.Success) {
        return [pscustomobject]@{ Success = $false; Deployment = $null; Error = $result.Error }
    }

    return [pscustomobject]@{
        Success    = $true
        Deployment = (ConvertFrom-VercelDeployment -Record $result.Data)
        Error      = $null
    }
}

function New-VercelGitProject {
    <#
    .SYNOPSIS
        Creates a Vercel project permanently connected to a GitHub repository.
    .DESCRIPTION
        Git-based creation is used deliberately so that future merges to the
        production branch deploy automatically through Vercel's Git integration.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$RepositoryFullName,
        [string]$ProductionBranch,
        [string]$TeamId
    )

    $gitRepository = @{
        type = 'github'
        repo = $RepositoryFullName
    }

    if (-not [string]::IsNullOrWhiteSpace($ProductionBranch)) {
        $gitRepository['productionBranch'] = $ProductionBranch
    }

    $body = @{
        name          = $ProjectName
        gitRepository = $gitRepository
    }

    $result = Invoke-VercelApi -Path '/v11/projects' -Method 'POST' -Body $body -TeamId $TeamId

    if (-not $result.Success) {
        return [pscustomobject]@{
            Success  = $false
            Project  = $null
            Error    = $result.Error
            Conflict = $result.Conflict
        }
    }

    return [pscustomobject]@{
        Success  = $true
        Project  = (ConvertFrom-VercelProject -Record $result.Data)
        Error    = $null
        Conflict = $false
    }
}

function Get-VercelProjectByName {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [string]$TeamId
    )

    $result = Invoke-VercelApi -Path "/v9/projects/$([uri]::EscapeDataString($ProjectName))" -TeamId $TeamId

    if (-not $result.Success) {
        return [pscustomobject]@{ Success = $false; Project = $null; Error = $result.Error }
    }

    return [pscustomobject]@{
        Success = $true
        Project = (ConvertFrom-VercelProject -Record $result.Data)
        Error   = $null
    }
}

function Get-VercelProjectDeploymentCount {
    <#
    .SYNOPSIS
        Returns how many deployments a project already has.
    .DESCRIPTION
        Used to detect whether Vercel started the first deployment on its own, so
        DevTools never triggers a redundant second build. Pass -ProductionOnly when
        preview deployments should not count.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$ProjectId,
        [string]$TeamId,
        [switch]$ProductionOnly
    )

    $query = @{ projectId = $ProjectId; limit = '5' }
    if ($ProductionOnly) {
        $query['target'] = 'production'
    }

    $result = Invoke-VercelApi -Path '/v6/deployments' -Query $query -TeamId $TeamId

    if (-not $result.Success) {
        return [pscustomobject]@{ Success = $false; Count = 0; Deployment = $null; Error = $result.Error }
    }

    $records = @($result.Data.deployments)

    return [pscustomobject]@{
        Success    = $true
        Count      = $records.Count
        Deployment = (ConvertFrom-VercelDeployment -Record ($records | Select-Object -First 1))
        Error      = $null
    }
}

function Start-VercelProductionDeployment {
    <#
    .SYNOPSIS
        Triggers a production deployment from the connected GitHub repository.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$GitOwner,
        [Parameter(Mandatory = $true)][string]$GitRepo,
        [Parameter(Mandatory = $true)][string]$Branch,
        [string]$GitRepoId,
        [string]$TeamId
    )

    $gitSource = @{
        type = 'github'
        org  = $GitOwner
        repo = $GitRepo
        ref  = $Branch
    }

    if (-not [string]::IsNullOrWhiteSpace($GitRepoId)) {
        $gitSource['repoId'] = $GitRepoId
    }

    $body = @{
        name      = $ProjectName
        target    = 'production'
        gitSource = $gitSource
    }

    $result = Invoke-VercelApi -Path '/v13/deployments' -Method 'POST' -Body $body -TeamId $TeamId

    if (-not $result.Success) {
        return [pscustomobject]@{ Success = $false; Deployment = $null; Error = $result.Error }
    }

    return [pscustomobject]@{
        Success    = $true
        Deployment = (ConvertFrom-VercelDeployment -Record $result.Data)
        Error      = $null
    }
}

function Test-VercelDeploymentStateTerminal {
    param([string]$State)

    if ([string]::IsNullOrWhiteSpace($State)) { return $false }

    return ($State.ToUpperInvariant() -in @('READY', 'ERROR', 'CANCELED'))
}

function Wait-VercelDeployment {
    <#
    .SYNOPSIS
        Polls a deployment until it reaches READY, ERROR, CANCELED, or the timeout.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$DeploymentId,
        [string]$TeamId,
        [int]$TimeoutSeconds = 600,
        [int]$IntervalSeconds = 10,
        [scriptblock]$OnPoll
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $last = $null

    while ($true) {
        $result = Get-VercelDeployment -DeploymentId $DeploymentId -TeamId $TeamId

        if ($result.Success -and $result.Deployment) {
            $last = $result.Deployment

            if ($OnPoll) {
                & $OnPoll $last
            }

            if (Test-VercelDeploymentStateTerminal -State $last.State) {
                return [pscustomobject]@{ TimedOut = $false; Deployment = $last; Error = $null }
            }
        }
        elseif (-not $result.Success) {
            return [pscustomobject]@{ TimedOut = $false; Deployment = $last; Error = $result.Error }
        }

        if ((Get-Date) -ge $deadline) {
            return [pscustomobject]@{ TimedOut = $true; Deployment = $last; Error = $null }
        }

        Start-Sleep -Seconds $IntervalSeconds
    }
}

function Test-DeploymentUrlHealth {
    <#
    .SYNOPSIS
        Performs a single lightweight HTTP check against a production URL.
    .DESCRIPTION
        Short timeout, standard redirects, one request. This never crawls the
        site and never runs a browser.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [int]$TimeoutSeconds = 10
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return [pscustomobject]@{ Checked = $false; StatusCode = 0; Healthy = $false; Error = 'No production URL available.' }
    }

    Enable-DeployTls12

    foreach ($method in @('Head', 'Get')) {
        try {
            $response = Invoke-WebRequest -Uri $Url -Method $method -TimeoutSec $TimeoutSeconds -MaximumRedirection 5 -UseBasicParsing -ErrorAction Stop
            $statusCode = [int]$response.StatusCode

            return [pscustomobject]@{
                Checked    = $true
                StatusCode = $statusCode
                Healthy    = ($statusCode -ge 200 -and $statusCode -lt 400)
                Error      = $null
            }
        }
        catch {
            $statusCode = 0
            try {
                if ($_.Exception.Response) {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                }
            }
            catch {
                $statusCode = 0
            }

            if ($statusCode -gt 0 -and $method -eq 'Get') {
                return [pscustomobject]@{
                    Checked    = $true
                    StatusCode = $statusCode
                    Healthy    = ($statusCode -ge 200 -and $statusCode -lt 400)
                    Error      = $null
                }
            }

            if ($method -eq 'Get') {
                return [pscustomobject]@{ Checked = $true; StatusCode = 0; Healthy = $false; Error = $_.Exception.Message }
            }
        }
    }

    return [pscustomobject]@{ Checked = $true; StatusCode = 0; Healthy = $false; Error = 'No response from the production URL.' }
}
