function Invoke-DevToolsMenuAction {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    & $Action
    Wait-ForKey
}

while ($true) {
    ShowHeader -Clear -Menu

    ShowMainMenuOptions

    $choice = Read-Host 'Choose an option'

    switch ($choice) {
        '1' { . (Join-Path $DevToolsRoot 'commands\home.ps1'); exit 0 }
        '2' { . (Join-Path $DevToolsRoot 'commands\quick.ps1'); exit 0 }
        '3' { Invoke-DevToolsMenuAction { Invoke-RecentProjectsFlow } }
        '4' { Invoke-DevToolsMenuAction { Invoke-ProjectInfoFlow } }
        '5' { Invoke-DevToolsMenuAction { . (Join-Path $DevToolsRoot 'commands\doctor.ps1') } }
        '6' {
            Invoke-DevToolsMenuAction {
                . (Join-Path $DevToolsRoot 'commands\configure.ps1')
                $script:Config = Set-ScriptConfig
            }
        }
        '7' { Invoke-DevToolsMenuAction { . (Join-Path $DevToolsRoot 'commands\settings.ps1') } }
        '8' { Invoke-DevToolsMenuAction { . (Join-Path $DevToolsRoot 'commands\clone.ps1') } }
        '9' { Invoke-DevToolsMenuAction { . (Join-Path $DevToolsRoot 'commands\update.ps1') } }
        '10' { Invoke-DevToolsMenuAction { . (Join-Path $DevToolsRoot 'commands\status.ps1') } }
        '11' { Invoke-DevToolsMenuAction { . (Join-Path $DevToolsRoot 'commands\backup.ps1') } }
        '12' { Invoke-DevToolsMenuAction { . (Join-Path $DevToolsRoot 'commands\open.ps1') } }
        '13' { Invoke-DeploymentManagerMenu -ConfigObject $Config | Out-Null }
        '14' { Invoke-DevToolsMenuAction { . (Join-Path $DevToolsRoot 'commands\help.ps1') } }
        '15' { exit 0 }
        default {
            ShowError 'That option is not available. Please choose a number from the menu.'
            Wait-ForKey
        }
    }
}
