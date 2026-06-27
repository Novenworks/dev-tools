function Show-QuickActionsMenu {
    ShowContextHeader -Clear

    Write-Host 'Quick Actions' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'What would you like to do?' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  1  Update all repositories'
    Write-Host '  2  Open a project'
    Write-Host '  3  Repository status'
    Write-Host '  4  Clone missing repositories'
    Write-Host '  5  Main Menu'
    Write-Host '  6  Exit'
    Write-Host ''
    Write-Host 'Type a number and press Enter.' -ForegroundColor DarkGray
    Write-Host ''
}

function Invoke-QuickSubcommand {
    param(
        [Parameter(Mandatory = $true)][string]$CommandName
    )

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $DevToolsRoot 'dev.ps1') $CommandName
}

function Invoke-QuickActions {
    while ($true) {
        Show-QuickActionsMenu
        $choice = Read-Host 'Choose an option'

        switch ($choice) {
            '1' { Invoke-QuickSubcommand -CommandName 'update' }
            '2' { Invoke-OpenProjectFlow }
            '3' { Invoke-QuickSubcommand -CommandName 'status' }
            '4' { Invoke-QuickSubcommand -CommandName 'clone' }
            '5' {
                . (Join-Path $DevToolsRoot 'commands\menu.ps1')
                exit 0
            }
            '6' { exit 0 }
            default {
                ShowWarning 'Please choose a number from the menu.'
                Wait-ForKey -Message 'Press Enter to try again'
            }
        }
    }
}

Invoke-QuickActions
