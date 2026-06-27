$subCommand = if ($script:DevToolsCommandArgs.Count -gt 0) {
    $script:DevToolsCommandArgs[0].ToLower()
}
else {
    ''
}

switch ($subCommand) {
    'test' {
        $exitCode = Invoke-DevToolsSelfTest
        exit $exitCode
    }
    'update' {
        $exitCode = Invoke-DevToolsSelfUpdate
        exit $exitCode
    }
    'version' {
        $exitCode = Invoke-DevToolsSelfVersion
        exit $exitCode
    }
    'doctor' {
        $exitCode = Invoke-DevToolsSelfDoctor
        exit $exitCode
    }
    'info' {
        $exitCode = Invoke-DevToolsSelfInfo
        exit $exitCode
    }
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
    '' {
        Invoke-DevToolsSelfMenu
        exit 0
    }
    default {
        ShowCommandScreen -Heading 'DevTools Self' -Description @(
            'Manage DevTools itself — testing, inspection, updates, and PATH setup.'
        )
        ShowInfo 'Usage:'
        ShowInfo '  dev self'
        ShowInfo '  dev self test'
        ShowInfo '  dev self update'
        ShowInfo '  dev self version'
        ShowInfo '  dev self doctor'
        ShowInfo '  dev self info'
        ShowInfo '  dev self install'
        ShowInfo '  dev self uninstall'
        ShowInfo '  dev self path'
    }
}
