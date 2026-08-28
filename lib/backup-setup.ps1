# Redundant backup — configuration and setup/status commands.
#
# GitLab/Bitbucket knowledge is confined to this file: it only builds a clone
# URL from a namespace/workspace and repo name. There is no GitLab or
# Bitbucket API client here — v1 assumes the destination repository already
# exists on the provider; DevTools never creates it, and never stores a
# token, password, or PAT for either provider. Auth for the "backup" remote
# comes from whatever git/SSH/credential-manager setup already handles
# "origin" today.

function Get-BackupDefaultSettings {
    <#
    .SYNOPSIS
        Returns the default "backup" section used when config.json omits it.
    #>
    return [ordered]@{
        provider             = ''
        namespaceOrWorkspace = ''
        protocol             = 'ssh'
        remoteName           = 'backup'
    }
}

function Get-BackupConfig {
    <#
    .SYNOPSIS
        Returns the normalized backup settings for a DevTools config object.
    .DESCRIPTION
        Configs written before redundant backup shipped have no "backup"
        section. Those configs keep working: every missing field receives a
        safe default, and a missing/empty "provider" simply means no
        secondary remote is configured.
    #>
    param($ConfigObject)

    $defaults = Get-BackupDefaultSettings
    $section = Get-DeployPropertyValue -Source $ConfigObject -Name 'backup'

    return [pscustomobject]@{
        Provider             = ([string](Get-DeployPropertyValue -Source $section -Name 'provider' -Default $defaults.provider)).Trim().ToLowerInvariant()
        NamespaceOrWorkspace = ([string](Get-DeployPropertyValue -Source $section -Name 'namespaceOrWorkspace' -Default $defaults.namespaceOrWorkspace)).Trim()
        Protocol             = ([string](Get-DeployPropertyValue -Source $section -Name 'protocol' -Default $defaults.protocol)).Trim().ToLowerInvariant()
        RemoteName           = ([string](Get-DeployPropertyValue -Source $section -Name 'remoteName' -Default $defaults.remoteName)).Trim()
    }
}

function Get-BackupProviderDefinitions {
    <#
    .SYNOPSIS
        The only provider-specific knowledge in redundant backup: display name and host.
    #>
    return [ordered]@{
        gitlab    = [pscustomobject]@{ Id = 'gitlab'; DisplayName = 'GitLab'; Host = 'gitlab.com' }
        bitbucket = [pscustomobject]@{ Id = 'bitbucket'; DisplayName = 'Bitbucket'; Host = 'bitbucket.org' }
    }
}

function Get-BackupProviderDisplayName {
    param([string]$Provider)

    $definitions = Get-BackupProviderDefinitions
    $key = ([string]$Provider).Trim().ToLowerInvariant()

    if ($definitions.Contains($key)) {
        return $definitions[$key].DisplayName
    }

    return 'Backup'
}

function New-BackupRemoteUrl {
    <#
    .SYNOPSIS
        Builds a clone URL for a repository that already exists on GitLab or Bitbucket.
    .DESCRIPTION
        Pure string construction — no network or file-system access, so it can
        be unit tested without credentials. DevTools never creates the
        destination repository; the user must create an empty one first.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('gitlab', 'bitbucket')]
        [string]$Provider,

        [Parameter(Mandatory = $true)]
        [string]$NamespaceOrWorkspace,

        [Parameter(Mandatory = $true)]
        [string]$RepoName,

        [ValidateSet('ssh', 'https')]
        [string]$Protocol = 'ssh'
    )

    $definitions = Get-BackupProviderDefinitions
    $providerHost = $definitions[$Provider].Host
    $path = "$($NamespaceOrWorkspace.Trim('/'))/$RepoName"

    if ($Protocol -eq 'https') {
        return "https://$providerHost/$path.git"
    }

    return "git@${providerHost}:$path.git"
}

function Invoke-BackupSetupCommand {
    <#
    .SYNOPSIS
        Interactive flow to configure a secondary backup remote across workspace repos.
    .DESCRIPTION
        Only ever runs "git remote add"/"git remote set-url" — it never runs
        "git push", "git ls-remote", or any provider API call. The destination
        repository must already exist on the chosen provider.
    #>
    param(
        [Parameter(Mandatory = $true)]$ConfigObject,
        [Parameter(Mandatory = $true)][string]$WorkspacePath
    )

    if (-not (Test-RequireGit)) { return 1 }

    $backupConfig = Get-BackupConfig -ConfigObject $ConfigObject
    $definitions = Get-BackupProviderDefinitions

    ShowSection -Label 'Secondary Backup Provider'
    Write-Host '  1  GitLab'
    Write-Host '  2  Bitbucket'
    Write-Host ''

    $currentChoice = switch ($backupConfig.Provider) {
        'gitlab' { '1' }
        'bitbucket' { '2' }
        default { '' }
    }

    $providerChoice = Read-ConfigValue -Prompt 'Choose a provider (1 or 2)' -CurrentValue $currentChoice
    $provider = switch ($providerChoice.Trim()) {
        '1' { 'gitlab' }
        '2' { 'bitbucket' }
        'gitlab' { 'gitlab' }
        'bitbucket' { 'bitbucket' }
        default { $backupConfig.Provider }
    }

    if ($provider -notin @('gitlab', 'bitbucket')) {
        ShowWarning 'No provider selected. Backup setup cancelled.'
        return 1
    }

    $providerDefinition = $definitions[$provider]
    $namespaceLabel = if ($provider -eq 'gitlab') { 'GitLab namespace (user or group)' } else { 'Bitbucket workspace' }
    $namespaceOrWorkspace = Read-ConfigValue -Prompt $namespaceLabel -CurrentValue $backupConfig.NamespaceOrWorkspace

    if ([string]::IsNullOrWhiteSpace($namespaceOrWorkspace)) {
        ShowWarning 'A namespace/workspace is required. Backup setup cancelled.'
        return 1
    }

    Write-Host ''
    Write-Host '  1  SSH (recommended if you already push to GitHub over SSH)'
    Write-Host '  2  HTTPS (uses your credential manager)'
    Write-Host ''
    $protocolChoice = Read-ConfigValue -Prompt 'Choose a connection type (1 or 2)' -CurrentValue $(if ($backupConfig.Protocol -eq 'https') { '2' } else { '1' })
    $protocol = if ($protocolChoice.Trim() -eq '2') { 'https' } else { 'ssh' }

    $remoteName = $backupConfig.RemoteName
    if ([string]::IsNullOrWhiteSpace($remoteName)) { $remoteName = 'backup' }

    $script:Config = Update-DevToolsConfig -Updates @{
        backup = @{
            provider             = $provider
            namespaceOrWorkspace = $namespaceOrWorkspace
            protocol             = $protocol
            remoteName           = $remoteName
        }
    }

    Write-Host ''
    ShowInfo "$($providerDefinition.DisplayName) repositories must already exist — DevTools does not create them."
    ShowInfo "Create an empty repository on $($providerDefinition.DisplayName) for each project below before continuing, using the same name."
    Write-Host ''

    $repos = @(Get-WorkspaceGitRepos -WorkspacePath $WorkspacePath)

    if ($repos.Count -eq 0) {
        ShowInfo 'No repositories found in your workspace yet.'
        return 0
    }

    foreach ($repo in $repos) {
        $existingUrl = Get-GitRemoteUrl -RepoPath $repo.FullName -RemoteName $remoteName
        $url = New-BackupRemoteUrl -Provider $provider -NamespaceOrWorkspace $namespaceOrWorkspace -RepoName $repo.Name -Protocol $protocol

        Write-Host $repo.Name -ForegroundColor Cyan

        if ($existingUrl) {
            ShowInfo "Current '$remoteName' remote: $existingUrl"
            ShowInfo "Expected repository: $url"
            $proceed = Read-YesNo -Prompt 'Replace it with the expected URL?' -Default $false
        }
        else {
            ShowInfo "Expected repository: $url"
            $proceed = Read-YesNo -Prompt "Add '$remoteName' remote for this repository?" -Default $true
        }

        if ($proceed) {
            if (Add-GitRemote -RepoPath $repo.FullName -RemoteName $remoteName -Url $url) {
                ShowSuccess "Configured '$remoteName' remote for $($repo.Name)"
            }
            else {
                ShowWarning "Could not configure '$remoteName' remote for $($repo.Name)"
            }
        }
        else {
            ShowInfo "Skipped $($repo.Name)"
        }

        Write-Host ''
    }

    ShowSuccess 'Backup setup complete.'
    ShowInfo 'Run "dev backup" to push changes to GitHub and your backup remote.'
    return 0
}

function Invoke-BackupStatusCommand {
    <#
    .SYNOPSIS
        Read-only report of which workspace repos have a secondary backup remote.
    #>
    param(
        [Parameter(Mandatory = $true)]$ConfigObject,
        [Parameter(Mandatory = $true)][string]$WorkspacePath
    )

    if (-not (Test-RequireGit)) { return 1 }

    $backupConfig = Get-BackupConfig -ConfigObject $ConfigObject
    $summary = @(Get-WorkspaceBackupSummary -WorkspacePath $WorkspacePath -RemoteName $backupConfig.RemoteName)

    if ($summary.Count -eq 0) {
        ShowInfo 'No repositories found in your workspace yet.'
        return 0
    }

    $providerLabel = if ($backupConfig.Provider) { Get-BackupProviderDisplayName -Provider $backupConfig.Provider } else { 'Backup' }
    $configuredCount = @($summary | Where-Object { $_.HasBackup }).Count

    ShowSection -Label 'Repositories'
    foreach ($row in $summary) {
        $state = if ($row.HasBackup) { 'ready' } else { 'attention' }
        $detail = if ($row.HasBackup) { $row.BackupUrl } else { 'No backup remote' }
        ShowStatusLine -Label $row.Name -State $state -Detail $detail
    }

    Write-Host ''
    ShowInfo "$configuredCount/$($summary.Count) repositories have a '$($backupConfig.RemoteName)' remote configured."

    if ([string]::IsNullOrWhiteSpace($backupConfig.Provider)) {
        ShowInfo 'Run "dev backup setup" to add a secondary backup provider.'
    }
    else {
        ShowInfo "Configured provider: $providerLabel"
    }

    return 0
}
