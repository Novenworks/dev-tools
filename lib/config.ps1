function Initialize-DevToolsConfig {
    $configPath = Join-Path $DevToolsRoot 'config.json'
    $examplePath = Join-Path $DevToolsRoot 'config.example.json'

    if (-not (Test-Path $examplePath)) {
        throw "Missing config.example.json in $DevToolsRoot"
    }

    if (Test-Path $configPath) {
        return [pscustomobject]@{
            Created = $false
            Path    = $configPath
        }
    }

    Copy-Item -Path $examplePath -Destination $configPath
    return [pscustomobject]@{
        Created = $true
        Path    = $configPath
    }
}

function Get-DefaultDevToolsConfig {
    $examplePath = Join-Path $DevToolsRoot 'config.example.json'
    return Get-Content -Path $examplePath -Raw | ConvertFrom-Json
}

function Get-DevToolsConfigPath {
    return Join-Path $DevToolsRoot 'config.json'
}

function Get-DevToolsRepositoryUrl {
    return 'https://github.com/Novenworks/dev-tools'
}

function Test-DevToolsConfigFileExists {
    return Test-Path (Get-DevToolsConfigPath)
}

function Test-DevToolsConfigValid {
    param(
        [Parameter(Mandatory = $true)]
        $ConfigObject
    )

    $errors = @()

    if (-not $ConfigObject.workspacePath -or [string]::IsNullOrWhiteSpace($ConfigObject.workspacePath)) {
        $errors += 'Workspace path is required.'
    }

    if (-not $ConfigObject.githubOwners -or @($ConfigObject.githubOwners).Count -eq 0) {
        $errors += 'At least one GitHub owner is required.'
    }
    else {
        foreach ($owner in @($ConfigObject.githubOwners)) {
            if ([string]::IsNullOrWhiteSpace($owner)) {
                $errors += 'GitHub owner names cannot be blank.'
                break
            }
        }
    }

    if (-not $ConfigObject.defaultEditor -or [string]::IsNullOrWhiteSpace($ConfigObject.defaultEditor)) {
        $errors += 'Default editor is required.'
    }

    if (-not $ConfigObject.autoBackupMessage -or [string]::IsNullOrWhiteSpace($ConfigObject.autoBackupMessage)) {
        $errors += 'Auto backup message is required.'
    }

    return [pscustomobject]@{
        Valid  = ($errors.Count -eq 0)
        Errors = $errors
    }
}

function Import-DevToolsConfigRaw {
    $configPath = Get-DevToolsConfigPath

    if (-not (Test-Path $configPath)) {
        throw 'config.json not found. Run dev to create and configure it automatically.'
    }

    $raw = Get-Content -Path $configPath -Raw | ConvertFrom-Json

    if (-not $raw.defaultEditor) {
        $raw | Add-Member -NotePropertyName 'defaultEditor' -NotePropertyValue 'cursor' -Force
    }

    if (-not $raw.autoBackupMessage) {
        $raw | Add-Member -NotePropertyName 'autoBackupMessage' -NotePropertyValue 'Auto backup' -Force
    }

    if ($null -eq $raw.autoUpdate) {
        $raw | Add-Member -NotePropertyName 'autoUpdate' -NotePropertyValue $false -Force
    }

    # Configs written before Deployment Manager shipped have no "deployments"
    # section. They keep working: the section is optional and every field falls
    # back to a safe default when it is read.

    return $raw
}

function Get-DevToolsConfig {
    $raw = Import-DevToolsConfigRaw
    $validation = Test-DevToolsConfigValid -ConfigObject $raw

    if (-not $validation.Valid) {
        throw ($validation.Errors -join ' ')
    }

    return $raw
}

function Save-DevToolsConfig {
    param(
        [Parameter(Mandatory = $true)]
        $ConfigObject
    )

    $validation = Test-DevToolsConfigValid -ConfigObject $ConfigObject
    if (-not $validation.Valid) {
        throw ($validation.Errors -join ' ')
    }

    $payload = [ordered]@{
        workspacePath     = $ConfigObject.workspacePath
        githubOwners      = @($ConfigObject.githubOwners)
        defaultEditor     = $ConfigObject.defaultEditor
        autoBackupMessage = $ConfigObject.autoBackupMessage
        autoUpdate        = [bool]$ConfigObject.autoUpdate
    }

    # Preserve settings owned by other features (for example "deployments") so
    # saving one preference never silently deletes another.
    foreach ($property in $ConfigObject.PSObject.Properties) {
        if ($payload.Contains($property.Name)) { continue }
        $payload[$property.Name] = $property.Value
    }

    $json = $payload | ConvertTo-Json -Depth 8
    Set-Content -Path (Get-DevToolsConfigPath) -Value $json -Encoding UTF8
}

function Update-DevToolsConfig {
    param(
        [hashtable]$Updates
    )

    $current = Import-DevToolsConfigRaw

    foreach ($key in $Updates.Keys) {
        $current | Add-Member -NotePropertyName $key -NotePropertyValue $Updates[$key] -Force
    }

    Save-DevToolsConfig -ConfigObject $current
    return (Set-ScriptConfig)
}

function Set-ScriptConfig {
    $script:Config = Get-DevToolsConfig
    return $script:Config
}

function Show-SavedConfiguration {
    ShowSuccess 'Configuration saved successfully.'
    ShowInfo "You're ready for the next step."
    ShowInfo "Workspace: $($Config.workspacePath)"
    ShowInfo "Owners: $(@($Config.githubOwners) -join ', ')"
    ShowInfo "Editor: $(Get-EditorDisplayName -Editor $Config.defaultEditor)"
    ShowInfo "Backup message: $($Config.autoBackupMessage)"
    ShowInfo "Automatic updates: $(if ($Config.autoUpdate) { 'On' } else { 'Off' })"
}
