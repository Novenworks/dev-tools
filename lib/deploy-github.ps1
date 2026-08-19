# Deployment Manager — GitHub discovery and remote deployability inspection.
#
# DevTools uses the GitHub CLI (gh) that it already depends on. No second token
# system is introduced, and repositories are inspected remotely so a portfolio
# audit never requires cloning hundreds of repositories.

function Invoke-DeployGhJson {
    <#
    .SYNOPSIS
        Runs a gh command and parses its JSON output.
    .DESCRIPTION
        Returns a result object instead of throwing so that a single failing
        repository can never terminate a portfolio operation.
    #>
    param(
        [Parameter(Mandatory = $true)][string[]]$ArgumentList
    )

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    try {
        $output = & gh @ArgumentList 2>&1
        $exitCode = $LASTEXITCODE
        $text = ($output | Out-String)

        if ($exitCode -ne 0) {
            return [pscustomobject]@{
                Success       = $false
                Data          = $null
                Error         = (Get-DeployGhErrorMessage -Text $text)
                RateLimited   = [bool]($text -match 'rate limit|secondary rate|abuse detection')
                NotFound      = [bool]($text -match 'HTTP 404|Not Found')
                Unauthorized  = [bool]($text -match 'HTTP 401|HTTP 403|authentication|gh auth login')
            }
        }

        if ([string]::IsNullOrWhiteSpace($text)) {
            return [pscustomobject]@{ Success = $true; Data = $null; Error = $null; RateLimited = $false; NotFound = $false; Unauthorized = $false }
        }

        try {
            $data = $text | ConvertFrom-Json
        }
        catch {
            return [pscustomobject]@{
                Success      = $false
                Data         = $null
                Error        = 'GitHub returned a response DevTools could not read.'
                RateLimited  = $false
                NotFound     = $false
                Unauthorized = $false
            }
        }

        return [pscustomobject]@{ Success = $true; Data = $data; Error = $null; RateLimited = $false; NotFound = $false; Unauthorized = $false }
    }
    catch {
        return [pscustomobject]@{
            Success      = $false
            Data         = $null
            Error        = $_.Exception.Message
            RateLimited  = $false
            NotFound     = $false
            Unauthorized = $false
        }
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
}

function Get-DeployGhErrorMessage {
    <#
    .SYNOPSIS
        Turns raw gh output into a short, beginner-friendly message.
    #>
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return 'GitHub CLI reported an error.'
    }

    if ($Text -match 'rate limit|secondary rate|abuse detection') {
        return 'GitHub API rate limit reached. Wait a few minutes and run the audit again.'
    }

    if ($Text -match 'HTTP 404|Not Found') {
        return 'Repository or resource not found on GitHub.'
    }

    if ($Text -match 'HTTP 401|authentication|gh auth login') {
        return 'GitHub authentication is required. Run: gh auth login'
    }

    if ($Text -match 'HTTP 403') {
        return 'GitHub denied access to this resource.'
    }

    $firstLine = @($Text -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }) | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($firstLine)) {
        return 'GitHub CLI reported an error.'
    }

    return $firstLine
}

function ConvertFrom-DeployGhRepository {
    <#
    .SYNOPSIS
        Maps a gh repo list JSON record onto the DevTools repository model.
    #>
    param($Record, [string]$FallbackOwner)

    $owner = $FallbackOwner
    if ($Record.owner -and $Record.owner.login) {
        $owner = [string]$Record.owner.login
    }
    elseif ($Record.nameWithOwner -and ([string]$Record.nameWithOwner).Contains('/')) {
        $owner = ([string]$Record.nameWithOwner -split '/')[0]
    }

    $defaultBranch = ''
    if ($Record.defaultBranchRef -and $Record.defaultBranchRef.name) {
        $defaultBranch = [string]$Record.defaultBranchRef.name
    }

    $url = [string]$Record.url
    if ([string]::IsNullOrWhiteSpace($url)) {
        $url = "https://github.com/$owner/$($Record.name)"
    }

    return New-DeploymentRepository `
        -Owner $owner `
        -Name ([string]$Record.name) `
        -DefaultBranch $defaultBranch `
        -Visibility ([string]$Record.visibility) `
        -IsArchived ([bool]$Record.isArchived) `
        -IsFork ([bool]$Record.isFork) `
        -IsTemplate ([bool]$Record.isTemplate) `
        -IsEmpty ([bool]$Record.isEmpty) `
        -Url $url `
        -PushedAt ([string]$Record.pushedAt)
}

function Get-DeploymentRepositoriesForOwner {
    <#
    .SYNOPSIS
        Enumerates every repository for a GitHub owner or organization.
    .DESCRIPTION
        gh handles paging internally; DevTools raises the page limit far above the
        default 30 so large organizations are fully enumerated, and warns when the
        result may have been truncated.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Owner,
        [int]$Limit = 1000
    )

    if ($Limit -lt 1) { $Limit = 1000 }

    $fields = 'name,nameWithOwner,owner,defaultBranchRef,visibility,isArchived,isFork,isTemplate,isEmpty,url,pushedAt'
    $result = Invoke-DeployGhJson -ArgumentList @('repo', 'list', $Owner, '--limit', "$Limit", '--json', $fields)

    if (-not $result.Success) {
        return [pscustomobject]@{
            Owner        = $Owner
            Repositories = @()
            Error        = $result.Error
            Truncated    = $false
        }
    }

    $records = @($result.Data)
    $repositories = @()

    foreach ($record in $records) {
        if ($null -eq $record) { continue }

        try {
            $repositories += (ConvertFrom-DeployGhRepository -Record $record -FallbackOwner $Owner)
        }
        catch {
            # A malformed record must never stop the rest of the portfolio.
            continue
        }
    }

    return [pscustomobject]@{
        Owner        = $Owner
        Repositories = @($repositories | Sort-Object Name)
        Error        = $null
        Truncated    = ($repositories.Count -ge $Limit)
    }
}

function Get-DeployRepositoryRootEntries {
    <#
    .SYNOPSIS
        Lists the root-level files and folders of a repository without cloning it.
    #>
    param(
        [Parameter(Mandatory = $true)]$Repository
    )

    $path = "repos/$($Repository.Owner)/$($Repository.Name)/contents"
    $result = Invoke-DeployGhJson -ArgumentList @('api', $path)

    if (-not $result.Success) {
        if ($result.NotFound) {
            return [pscustomobject]@{ Entries = @(); Error = $null; Empty = $true }
        }

        return [pscustomobject]@{ Entries = @(); Error = $result.Error; Empty = $false }
    }

    $entries = @()
    foreach ($item in @($result.Data)) {
        if ($null -eq $item -or -not $item.name) { continue }

        $entries += [pscustomobject]@{
            Name = [string]$item.name
            Type = [string]$item.type
        }
    }

    return [pscustomobject]@{ Entries = $entries; Error = $null; Empty = ($entries.Count -eq 0) }
}

function Get-DeployRepositoryPackageJson {
    <#
    .SYNOPSIS
        Reads a repository's root package.json remotely, or returns $null.
    #>
    param(
        [Parameter(Mandatory = $true)]$Repository
    )

    $path = "repos/$($Repository.Owner)/$($Repository.Name)/contents/package.json"
    $result = Invoke-DeployGhJson -ArgumentList @('api', $path)

    if (-not $result.Success -or -not $result.Data -or -not $result.Data.content) {
        return $null
    }

    try {
        $bytes = [System.Convert]::FromBase64String((([string]$result.Data.content) -replace '\s', ''))
        $json = [System.Text.Encoding]::UTF8.GetString($bytes)
        return ($json | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Get-DeployPackageDependencyNames {
    <#
    .SYNOPSIS
        Returns the combined dependency names declared in a package.json object.
    #>
    param($PackageJson)

    if ($null -eq $PackageJson) {
        return @()
    }

    $names = @()

    foreach ($section in @('dependencies', 'devDependencies')) {
        $block = Get-DeployPropertyValue -Source $PackageJson -Name $section
        if ($null -eq $block) { continue }

        if ($block -is [System.Collections.IDictionary]) {
            $names += @($block.Keys | ForEach-Object { [string]$_ })
        }
        else {
            $names += @($block.PSObject.Properties | ForEach-Object { $_.Name })
        }
    }

    return @($names | Where-Object { $_ })
}

function Get-RepositoryDeployability {
    <#
    .SYNOPSIS
        Decides whether a repository plausibly contains a deployable web application.
    .DESCRIPTION
        Pure function: takes the repository's root listing (and optionally its
        package.json) and returns deployability plus a detected framework.
    #>
    param(
        [AllowEmptyCollection()]
        [array]$Entries = @(),
        $PackageJson
    )

    $entries = @($Entries | Where-Object { $_ -and $_.Name })

    if ($entries.Count -eq 0) {
        return [pscustomobject]@{
            Deployable = $false
            Framework  = 'Unknown'
            Reason     = 'Repository is empty.'
            Indicators = @()
        }
    }

    $files = @($entries | Where-Object { $_.Type -ne 'dir' } | ForEach-Object { [string]$_.Name })
    $directories = @($entries | Where-Object { $_.Type -eq 'dir' } | ForEach-Object { [string]$_.Name })

    $indicators = @()
    $framework = 'Unknown'

    $configPatterns = [ordered]@{
        'next.config.*'   = 'Next.js'
        'nuxt.config.*'   = 'Nuxt'
        'astro.config.*'  = 'Astro'
        'svelte.config.*' = 'SvelteKit'
        'vite.config.*'   = 'Vite'
    }

    foreach ($pattern in $configPatterns.Keys) {
        $match = @($files | Where-Object { $_ -like $pattern }) | Select-Object -First 1
        if ($match) {
            $indicators += $match
            if ($framework -eq 'Unknown') {
                $framework = $configPatterns[$pattern]
            }
        }
    }

    $hasPackageJson = [bool](@($files | Where-Object { $_ -ieq 'package.json' }).Count)
    if ($hasPackageJson) { $indicators += 'package.json' }

    $hasVercelJson = [bool](@($files | Where-Object { $_ -ieq 'vercel.json' }).Count)
    if ($hasVercelJson) { $indicators += 'vercel.json' }

    $hasIndexHtml = [bool](@($files | Where-Object { $_ -ieq 'index.html' }).Count)
    if ($hasIndexHtml) { $indicators += 'index.html' }

    foreach ($directoryName in @('src', 'app', 'pages', 'public')) {
        if (@($directories | Where-Object { $_ -ieq $directoryName }).Count) {
            $indicators += "$directoryName/"
        }
    }

    if ($framework -eq 'Unknown' -and $hasPackageJson -and $PackageJson) {
        $dependencies = @(Get-DeployPackageDependencyNames -PackageJson $PackageJson)

        $dependencyFrameworks = [ordered]@{
            'next'           = 'Next.js'
            'nuxt'           = 'Nuxt'
            'astro'          = 'Astro'
            '@sveltejs/kit'  = 'SvelteKit'
            'vite'           = 'Vite'
            'react'          = 'React'
            'vue'            = 'Vue'
        }

        foreach ($dependency in $dependencyFrameworks.Keys) {
            if (@($dependencies | Where-Object { $_ -ieq $dependency }).Count) {
                $framework = $dependencyFrameworks[$dependency]
                break
            }
        }
    }

    if ($framework -eq 'Unknown' -and $hasIndexHtml) {
        $framework = 'Static HTML'
    }

    $hasApplicationSource = $hasPackageJson -or $hasVercelJson -or $hasIndexHtml -or ($indicators | Where-Object { $_ -like '*/' })

    if (-not $hasApplicationSource) {
        $documentationOnly = -not (@($files | Where-Object { $_ -notmatch '(?i)^(readme|license|licence|changelog|contributing|code_of_conduct|security)(\.|$)' -and $_ -notmatch '^\.' }).Count)

        $reason = if ($documentationOnly) {
            'Repository contains documentation only.'
        }
        else {
            'No deployable web application detected.'
        }

        return [pscustomobject]@{
            Deployable = $false
            Framework  = 'Unknown'
            Reason     = $reason
            Indicators = @()
        }
    }

    if ($framework -eq 'Unknown') {
        $framework = 'Other'
    }

    return [pscustomobject]@{
        Deployable = $true
        Framework  = $framework
        Reason     = 'Deployable web application detected.'
        Indicators = @($indicators | Select-Object -Unique)
    }
}

function Get-DeploymentRepositoryInspection {
    <#
    .SYNOPSIS
        Inspects one repository remotely and returns its deployability result.
    #>
    param(
        [Parameter(Mandatory = $true)]$Repository
    )

    $listing = Get-DeployRepositoryRootEntries -Repository $Repository

    if ($listing.Error) {
        return [pscustomobject]@{
            Deployable = $false
            Framework  = 'Unknown'
            Reason     = $listing.Error
            Indicators = @()
            Error      = $listing.Error
        }
    }

    $entries = @($listing.Entries)
    $packageJson = $null

    $needsPackageJson = @($entries | Where-Object { $_.Type -ne 'dir' -and $_.Name -ieq 'package.json' }).Count -gt 0
    $hasFrameworkConfig = @($entries | Where-Object { $_.Name -like '*.config.*' }).Count -gt 0

    if ($needsPackageJson -and -not $hasFrameworkConfig) {
        $packageJson = Get-DeployRepositoryPackageJson -Repository $Repository
    }

    $deployability = Get-RepositoryDeployability -Entries $entries -PackageJson $packageJson

    return [pscustomobject]@{
        Deployable = $deployability.Deployable
        Framework  = $deployability.Framework
        Reason     = $deployability.Reason
        Indicators = $deployability.Indicators
        Error      = $null
    }
}
