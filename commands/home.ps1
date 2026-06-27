function Invoke-HomeDashboard {
    while ($true) {
        $screen = Show-HomeScreen
        $choice = Read-Host 'Choose an option'

        $selected = @($screen.Actions | Where-Object { $_.Key -eq $choice } | Select-Object -First 1)

        if (-not $selected) {
            ShowWarning 'Please choose a number from the menu.'
            Wait-ForKey -Message 'Press Enter to try again'
            continue
        }

        switch ($selected.Action) {
            'fix-primary' {
                Invoke-HomePrimaryFix -CheckId $selected.CheckId
            }
            'menu' {
                . (Join-Path $DevToolsRoot 'commands\menu.ps1')
                exit 0
            }
            'doctor' {
                . (Join-Path $DevToolsRoot 'commands\doctor.ps1')
                Wait-ForKey -Message 'Press Enter to return to Home'
            }
            'configure' {
                . (Join-Path $DevToolsRoot 'commands\configure.ps1')
                $script:Config = Set-ScriptConfig
            }
            'settings' {
                . (Join-Path $DevToolsRoot 'commands\settings.ps1')
            }
            'quick' {
                . (Join-Path $DevToolsRoot 'commands\quick.ps1')
                exit 0
            }
            'exit' {
                exit 0
            }
        }
    }
}

Invoke-HomeDashboard
