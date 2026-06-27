function Show-SettingsMenu {
    while ($true) {
        ShowCommandScreen -Heading 'Settings' -Description @(
            'Update your DevTools preferences.'
        ) -Clear

        Write-Host '  1  Workspace'
        Write-Host '  2  GitHub Owners'
        Write-Host '  3  Default Editor'
        Write-Host '  4  Backup Commit Message'
        Write-Host '  5  Automatic Updates'
        Write-Host '  6  About DevTools'
        Write-Host '  7  Back'
        Write-Host ''

        $choice = Read-Host 'Choose an option'

        switch ($choice) {
            '1' {
                $value = Read-SettingValue -Label 'Workspace' -CurrentValue $Config.workspacePath -Hint 'Or enter a new location.'
                $script:Config = Update-DevToolsConfig -Updates @{ workspacePath = $value }
                Ensure-Directory -Path $script:Config.workspacePath
                Show-SavedConfiguration
                Wait-ForKey
            }
            '2' {
                $currentOwners = (@($Config.githubOwners) -join ', ')
                $value = Read-SettingValue -Label 'GitHub Owners' -CurrentValue $currentOwners -Hint 'Or enter a new value.'
                $owners = @($value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                $script:Config = Update-DevToolsConfig -Updates @{ githubOwners = $owners }
                Show-SavedConfiguration
                Wait-ForKey
            }
            '3' {
                $value = Read-EditorSetting -CurrentEditor $Config.defaultEditor
                $script:Config = Update-DevToolsConfig -Updates @{ defaultEditor = $value }
                Show-SavedConfiguration
                Wait-ForKey
            }
            '4' {
                $value = Read-SettingValue -Label 'Backup Commit Message' -CurrentValue $Config.autoBackupMessage -Hint 'Or enter a new value.'
                $script:Config = Update-DevToolsConfig -Updates @{ autoBackupMessage = $value }
                Show-SavedConfiguration
                Wait-ForKey
            }
            '5' {
                $current = if ($Config.autoUpdate) { 'On' } else { 'Off' }
                Write-Host 'Automatic Updates' -ForegroundColor Cyan
                Write-Host ''
                Write-Host 'Current' -ForegroundColor DarkGray
                Write-Host "  $current" -ForegroundColor DarkGray
                Write-Host ''
                Write-Host 'Press Enter to keep.' -ForegroundColor DarkGray
                Write-Host 'Type on or off to change it.' -ForegroundColor DarkGray
                Write-Host ''
                $input = Read-Host 'Automatic Updates'
                if (-not [string]::IsNullOrWhiteSpace($input)) {
                    $enabled = $input.Trim().ToLower() -in @('on', 'true', 'yes', 'y', '1')
                    $script:Config = Update-DevToolsConfig -Updates @{ autoUpdate = $enabled }
                }
                Show-SavedConfiguration
                Wait-ForKey
            }
            '6' {
                ShowContextHeader -Clear
                ShowAboutScreen
                Wait-ForKey
            }
            '7' { return }
            default {
                ShowWarning 'Please choose a number from the menu.'
                Wait-ForKey -Message 'Press Enter to try again'
            }
        }
    }
}

Show-SettingsMenu
