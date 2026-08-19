# Deployment Manager — configuration, naming, and eligibility rules.
#
# Everything in this file is intentionally free of network and file-system side
# effects so it can be unit tested without GitHub or Vercel credentials.

function Get-DeploymentDefaultSettings {
    <#
    .SYNOPSIS
        Returns the default "deployments" section used when config.json omits it.
    #>
    return [ordered]@{
        provider                  = 'vercel'
        vercelTeam                = ''
        repositoryFilters         = [ordered]@{
            includeNamePatterns = @('*demo*')
            includeRepositories = @()
            excludeRepositories = @()
            includeForks        = $false
            includeArchived     = $false
        }
        productionBranchOverrides = @{}
        projectMappings           = @{}
        httpHealthCheck           = $true
        deploymentTimeoutSeconds  = 600
        pollIntervalSeconds       = 10
        requestDelayMilliseconds  = 150
        maxRepositoriesPerOwner   = 1000
    }
}

function Get-DeployPropertyValue {
    <#
    .SYNOPSIS
        Reads a property from a hashtable or PSCustomObject, returning a default when absent.
    #>
    param(
        $Source,
        [Parameter(Mandatory = $true)][string]$Name,
        $Default = $null
    )

    if ($null -eq $Source) {
        return $Default
    }

    if ($Source -is [System.Collections.IDictionary]) {
        if ($Source.Contains($Name)) {
            $value = $Source[$Name]
            if ($null -eq $value) { return $Default }
            return $value
        }

        return $Default
    }

    $property = $Source.PSObject.Properties[$Name]
    if (-not $property) {
        return $Default
    }

    if ($null -eq $property.Value) {
        return $Default
    }

    return $property.Value
}

function ConvertTo-DeployLookupTable {
    <#
    .SYNOPSIS
        Converts a config object (or hashtable) into a case-insensitive lookup table.
    #>
    param($Source)

    $table = New-Object 'System.Collections.Hashtable' ([System.StringComparer]::OrdinalIgnoreCase)

    if ($null -eq $Source) {
        return $table
    }

    if ($Source -is [System.Collections.IDictionary]) {
        foreach ($key in $Source.Keys) {
            $table[[string]$key] = $Source[$key]
        }

        return $table
    }

    foreach ($property in $Source.PSObject.Properties) {
        $table[$property.Name] = $property.Value
    }

    return $table
}

function ConvertTo-DeployStringArray {
    param($Source)

    if ($null -eq $Source) {
        return @()
    }

    return @($Source | ForEach-Object { if ($null -eq $_) { '' } else { [string]$_ } } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
}

function ConvertTo-DeployBoolean {
    param($Value, [bool]$Default = $false)

    if ($null -eq $Value) { return $Default }
    if ($Value -is [bool]) { return $Value }

    $text = ([string]$Value).Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($text)) { return $Default }

    return ($text -in @('1', 'true', 'yes', 'y', 'on'))
}

function ConvertTo-DeployInteger {
    param($Value, [int]$Default = 0, [int]$Minimum = 0)

    $result = $Default

    if ($null -ne $Value) {
        $parsed = 0
        if ([int]::TryParse(([string]$Value), [ref]$parsed)) {
            $result = $parsed
        }
    }

    if ($result -lt $Minimum) {
        return $Minimum
    }

    return $result
}

function Get-DeploymentConfig {
    <#
    .SYNOPSIS
        Returns the normalized deployment settings for a DevTools config object.
    .DESCRIPTION
        Config files written before Deployment Manager shipped have no "deployments"
        section. Those configs keep working: every missing field receives a safe default.
    #>
    param($ConfigObject)

    $defaults = Get-DeploymentDefaultSettings
    $section = Get-DeployPropertyValue -Source $ConfigObject -Name 'deployments'
    $filtersSource = Get-DeployPropertyValue -Source $section -Name 'repositoryFilters'
    $defaultFilters = $defaults.repositoryFilters

    $includePatterns = ConvertTo-DeployStringArray (Get-DeployPropertyValue -Source $filtersSource -Name 'includeNamePatterns' -Default $defaultFilters.includeNamePatterns)
    if ($includePatterns.Count -eq 0 -and $null -eq (Get-DeployPropertyValue -Source $filtersSource -Name 'includeNamePatterns')) {
        $includePatterns = @($defaultFilters.includeNamePatterns)
    }

    $filters = [pscustomobject]@{
        IncludeNamePatterns = $includePatterns
        IncludeRepositories = ConvertTo-DeployStringArray (Get-DeployPropertyValue -Source $filtersSource -Name 'includeRepositories')
        ExcludeRepositories = ConvertTo-DeployStringArray (Get-DeployPropertyValue -Source $filtersSource -Name 'excludeRepositories')
        IncludeForks        = ConvertTo-DeployBoolean (Get-DeployPropertyValue -Source $filtersSource -Name 'includeForks') $defaultFilters.includeForks
        IncludeArchived     = ConvertTo-DeployBoolean (Get-DeployPropertyValue -Source $filtersSource -Name 'includeArchived') $defaultFilters.includeArchived
    }

    return [pscustomobject]@{
        Provider                  = [string](Get-DeployPropertyValue -Source $section -Name 'provider' -Default $defaults.provider)
        VercelTeam                = ([string](Get-DeployPropertyValue -Source $section -Name 'vercelTeam' -Default '')).Trim()
        RepositoryFilters         = $filters
        ProductionBranchOverrides = ConvertTo-DeployLookupTable (Get-DeployPropertyValue -Source $section -Name 'productionBranchOverrides')
        ProjectMappings           = ConvertTo-DeployLookupTable (Get-DeployPropertyValue -Source $section -Name 'projectMappings')
        HttpHealthCheck           = ConvertTo-DeployBoolean (Get-DeployPropertyValue -Source $section -Name 'httpHealthCheck') $defaults.httpHealthCheck
        DeploymentTimeoutSeconds  = ConvertTo-DeployInteger (Get-DeployPropertyValue -Source $section -Name 'deploymentTimeoutSeconds') $defaults.deploymentTimeoutSeconds 30
        PollIntervalSeconds       = ConvertTo-DeployInteger (Get-DeployPropertyValue -Source $section -Name 'pollIntervalSeconds') $defaults.pollIntervalSeconds 2
        RequestDelayMilliseconds  = ConvertTo-DeployInteger (Get-DeployPropertyValue -Source $section -Name 'requestDelayMilliseconds') $defaults.requestDelayMilliseconds 0
        MaxRepositoriesPerOwner   = ConvertTo-DeployInteger (Get-DeployPropertyValue -Source $section -Name 'maxRepositoriesPerOwner') $defaults.maxRepositoriesPerOwner 1
    }
}

function ConvertTo-VercelProjectName {
    <#
    .SYNOPSIS
        Converts a repository name into a safe, normalized Vercel project name.
    .EXAMPLE
        ConvertTo-VercelProjectName -Name 'Amazing-Head-Spa-Demo'   # amazing-head-spa-demo
        ConvertTo-VercelProjectName -Name 'TIA_Medspa_Demo'         # tia-medspa-demo
    #>
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return ''
    }

    $value = $Name.Trim().ToLowerInvariant()
    $value = [regex]::Replace($value, '[^a-z0-9]+', '-')
    $value = [regex]::Replace($value, '-{2,}', '-')
    $value = $value.Trim('-')

    if ($value.Length -gt 100) {
        $value = $value.Substring(0, 100).Trim('-')
    }

    return $value
}

function Test-DeployRepositoryReference {
    <#
    .SYNOPSIS
        Returns true when a configured reference matches a repository by name or owner/name.
    #>
    param(
        [Parameter(Mandatory = $true)]$Repository,
        [string[]]$References
    )

    if (-not $References -or @($References).Count -eq 0) {
        return $false
    }

    $name = [string]$Repository.Name
    $fullName = [string]$Repository.FullName

    foreach ($reference in $References) {
        if ([string]::IsNullOrWhiteSpace($reference)) { continue }

        $candidate = $reference.Trim()

        if ($candidate.Equals($name, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        if ($candidate.Equals($fullName, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }

    return $false
}

function Test-DeployNamePatternMatch {
    <#
    .SYNOPSIS
        Returns true when a repository matches any configured wildcard include pattern.
    #>
    param(
        [Parameter(Mandatory = $true)]$Repository,
        [string[]]$Patterns
    )

    if (-not $Patterns -or @($Patterns).Count -eq 0) {
        return $false
    }

    foreach ($pattern in $Patterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { continue }

        if ([string]$Repository.Name -like $pattern) { return $true }
        if ([string]$Repository.FullName -like $pattern) { return $true }
    }

    return $false
}

function Test-RepositoryEligible {
    <#
    .SYNOPSIS
        Applies deployment eligibility rules to a repository.
    .DESCRIPTION
        Rule order (first match wins):
          1. excludeRepositories  — always skipped
          2. includeRepositories  — always eligible (overrides archived / fork / template)
          3. archived repository  — skipped unless includeArchived
          4. template repository  — skipped
          5. forked repository    — skipped unless includeForks
          6. includeNamePatterns  — eligible
          7. otherwise            — skipped
    #>
    param(
        [Parameter(Mandatory = $true)]$Repository,
        [Parameter(Mandatory = $true)]$Filters
    )

    if (Test-DeployRepositoryReference -Repository $Repository -References $Filters.ExcludeRepositories) {
        return [pscustomobject]@{ Eligible = $false; Rule = 'excluded'; Reason = 'Excluded in deployment configuration.' }
    }

    if (Test-DeployRepositoryReference -Repository $Repository -References $Filters.IncludeRepositories) {
        return [pscustomobject]@{ Eligible = $true; Rule = 'explicit-include'; Reason = 'Explicitly included in deployment configuration.' }
    }

    if ($Repository.IsArchived -and -not $Filters.IncludeArchived) {
        return [pscustomobject]@{ Eligible = $false; Rule = 'archived'; Reason = 'Repository is archived.' }
    }

    if ($Repository.IsTemplate) {
        return [pscustomobject]@{ Eligible = $false; Rule = 'template'; Reason = 'Repository is a template.' }
    }

    if ($Repository.IsFork -and -not $Filters.IncludeForks) {
        return [pscustomobject]@{ Eligible = $false; Rule = 'fork'; Reason = 'Repository is a fork.' }
    }

    if (Test-DeployNamePatternMatch -Repository $Repository -Patterns $Filters.IncludeNamePatterns) {
        return [pscustomobject]@{ Eligible = $true; Rule = 'pattern'; Reason = 'Matches a deployment include pattern.' }
    }

    return [pscustomobject]@{ Eligible = $false; Rule = 'no-match'; Reason = 'Does not match any deployment include rule.' }
}

function Resolve-DeploymentProductionBranch {
    <#
    .SYNOPSIS
        Returns the production branch DevTools expects for a repository.
    .DESCRIPTION
        The repository's real default branch is used unless configuration overrides it.
        DevTools never assumes "main".
    #>
    param(
        [Parameter(Mandatory = $true)]$Repository,
        $Overrides
    )

    if ($Overrides) {
        $table = ConvertTo-DeployLookupTable $Overrides

        foreach ($key in @([string]$Repository.FullName, [string]$Repository.Name)) {
            if ([string]::IsNullOrWhiteSpace($key)) { continue }

            if ($table.ContainsKey($key)) {
                $value = [string]$table[$key]
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    return $value.Trim()
                }
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Repository.DefaultBranch)) {
        return ([string]$Repository.DefaultBranch).Trim()
    }

    return ''
}

function New-DeploymentRepository {
    <#
    .SYNOPSIS
        Builds the normalized repository record used across Deployment Manager.
    #>
    param(
        [string]$Owner,
        [string]$Name,
        [string]$DefaultBranch,
        [string]$Visibility = 'unknown',
        [bool]$IsArchived = $false,
        [bool]$IsFork = $false,
        [bool]$IsTemplate = $false,
        [bool]$IsEmpty = $false,
        [string]$Url,
        [string]$PushedAt
    )

    $fullName = if ([string]::IsNullOrWhiteSpace($Owner)) { $Name } else { "$Owner/$Name" }

    return [pscustomobject]@{
        Owner         = $Owner
        Name          = $Name
        FullName      = $fullName
        DefaultBranch = $DefaultBranch
        Visibility    = $Visibility
        IsArchived    = $IsArchived
        IsFork        = $IsFork
        IsTemplate    = $IsTemplate
        IsEmpty       = $IsEmpty
        Url           = $Url
        PushedAt      = $PushedAt
    }
}
