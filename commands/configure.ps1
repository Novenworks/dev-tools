function Read-WizardSetting {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Explanation,
        [Parameter(Mandatory = $true)][string]$CurrentValue,
        [string]$Hint = 'Or type a new value:'
    )

    Write-Host $Label -ForegroundColor Cyan
    ShowInfo $Explanation
    Write-Host ''
    return (Read-SettingValue -Label $Label -CurrentValue $CurrentValue -Hint $Hint)
}

function Invoke-ConfigureWizard {
    while ($true) {
        ShowCommandScreen -Heading 'Setup Wizard' -Description @(
            "Let's configure DevRepo for your computer."
            'Choose your project folder, GitHub accounts and editor. Review your choices before saving.'
        )

        $currentOwners = (@($Config.githubOwners) | ForEach-Object { $_.ToString() }) -join ', '

        $workspacePath = Read-WizardSetting `
            -Label 'Workspace' `
            -Explanation 'This is where DevRepo stores and manages your Git repositories.' `
            -CurrentValue $Config.workspacePath `
            -Hint 'Or type a new workspace path:'

        $ownersInput = Read-WizardSetting `
            -Label 'GitHub Owners' `
            -Explanation 'Enter one or more GitHub usernames or organizations separated by commas.' `
            -CurrentValue $currentOwners `
            -Hint 'Or type one or more owners separated by commas:'

        Write-Host 'Default Editor' -ForegroundColor Cyan
        ShowInfo 'Choose which editor opens when selecting Open Project.'
        Write-Host ''
        $defaultEditor = Read-EditorSetting -CurrentEditor $Config.defaultEditor

        $autoBackupMessage = Read-WizardSetting `
            -Label 'Backup Message' `
            -Explanation 'This message is used when creating automatic backup commits.' `
            -CurrentValue $Config.autoBackupMessage `
            -Hint 'Or type a new backup message:'

        $githubOwners = @(
            $ownersInput.Split(',') |
                ForEach-Object { $_.Trim() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )

        Write-Host ''
        ShowScreenTitle -Title 'Everything look good?'
        ShowReviewBlock -Label 'Workspace' -Value $workspacePath
        ShowReviewBlock -Label 'GitHub Owners' -Value ($githubOwners -join ', ')
        ShowReviewBlock -Label 'Default Editor' -Value (Get-EditorDisplayName -Editor $defaultEditor)
        ShowReviewBlock -Label 'Backup Message' -Value $autoBackupMessage

        if (-not (Confirm-DevRepoAction -Label 'Save settings and create the workspace folder if needed')) {
            ShowInfo 'Setup canceled. Your settings were not saved.'
            return
        }

        $newConfig = [pscustomobject]@{
            workspacePath     = $workspacePath
            githubOwners      = $githubOwners
            defaultEditor     = $defaultEditor
            autoBackupMessage = $autoBackupMessage
            autoUpdate        = [bool]$Config.autoUpdate
        }

        try {
            $storedConfig = $null
            try { $storedConfig = Import-DevToolsConfigRaw } catch { }
            if ($storedConfig) {
                foreach ($property in $storedConfig.PSObject.Properties) {
                    if (-not $newConfig.PSObject.Properties[$property.Name]) {
                        $newConfig | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
                    }
                }
            }

            $validation = Test-DevToolsConfigValid -ConfigObject $newConfig
            if (-not $validation.Valid) { throw ($validation.Errors -join ' ') }
            Ensure-Directory -Path $workspacePath
            Save-DevToolsConfig -ConfigObject $newConfig
            $script:Config = Set-ScriptConfig

            Write-Host ''
            Show-SavedConfiguration

            if ($script:FirstRun) {
                ShowSuccess 'Welcome to DevRepo.'
                ShowInfo 'Choose D on Home to check GitHub access and see sign-in steps.'
                $script:FirstRun = $false
            }

            Wait-ForKey -Message 'Press Enter to return.'
            return
        }
        catch {
            ShowWarning $_.Exception.Message
            ShowInfo 'Please review your settings and try again.'
            Wait-ForKey -Message 'Press Enter to continue'
        }
    }
}

Invoke-ConfigureWizard
