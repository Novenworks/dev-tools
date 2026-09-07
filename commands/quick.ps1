function Show-QuickActionsMenu {
    ShowContextHeader -Clear

    Write-Host 'Quick Actions' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'What would you like to do?' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  1  Open Recent Project'
    Write-Host '  2  Open Project Search'
    Write-Host '  3  Repository Health'
    Write-Host '  4  Sync Repositories'
    Write-Host '  5  Clone Missing Repositories'
    Write-Host '  6  Repository Maintenance'
    Write-Host '  7  Main Menu'
    Write-Host '  8  Exit'
    Write-Host ''
    Write-Host 'Type a number and press Enter.' -ForegroundColor DarkGray
    Write-Host ''
}

function Invoke-QuickSubcommand {
    param(
        [Parameter(Mandatory = $true)][string]$CommandName
    )

    & (Join-Path $DevToolsRoot 'dev.cmd') $CommandName
}

function Invoke-QuickActions {
    while ($true) {
        Show-QuickActionsMenu
        $choice = Read-Host 'Choose an option'

        switch ($choice) {
            '1' { Invoke-RecentProjectsFlow }
            '2' { Invoke-OpenProjectFlow }
            '3' { Invoke-QuickSubcommand -CommandName 'status' }
            '4' { Invoke-QuickSubcommand -CommandName 'sync' }
            '5' { Invoke-QuickSubcommand -CommandName 'clone' }
            '6' { Invoke-QuickSubcommand -CommandName 'repos' }
            '7' {
                . (Join-Path $DevToolsRoot 'commands\menu.ps1')
                exit 0
            }
            '8' { exit 0 }
            default {
                ShowWarning 'Please choose a number from the menu.'
                Wait-ForKey -Message 'Press Enter to try again'
            }
        }
    }
}

Invoke-QuickActions
