function Show-DevToolsSelfUsage {
    ShowInfo 'Usage:'
    ShowInfo '  dev self install    Add DevTools to your user PATH'
    ShowInfo '  dev self uninstall  Remove DevTools from your user PATH'
    ShowInfo '  dev self path       Show installation and PATH details'
}

$subCommand = if ($script:DevToolsCommandArgs.Count -gt 0) {
    $script:DevToolsCommandArgs[0].ToLower()
}
else {
    ''
}

switch ($subCommand) {
    'install' {
        $exitCode = Invoke-DevToolsSelfInstall
        exit $exitCode
    }
    'uninstall' {
        $exitCode = Invoke-DevToolsSelfUninstall
        exit $exitCode
    }
    'path' {
        $exitCode = Invoke-DevToolsSelfPath
        exit $exitCode
    }
    default {
        ShowCommandScreen -Heading 'DevTools Self' -Description @(
            'Manage global access to DevTools from any PowerShell window.'
        )
        Show-DevToolsSelfUsage
    }
}
