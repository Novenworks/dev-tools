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
        ShowCommandScreen -Heading 'DevRepo Self' -Description @(
            'Manage DevRepo itself — testing, inspection, updates, and PATH setup.'
        )
        ShowInfo 'Usage:'
        ShowInfo '  devrepo self'
        ShowInfo '  devrepo self test'
        ShowInfo '  devrepo self update'
        ShowInfo '  devrepo self version'
        ShowInfo '  devrepo self doctor'
        ShowInfo '  devrepo self info'
        ShowInfo '  devrepo self install'
        ShowInfo '  devrepo self uninstall'
        ShowInfo '  devrepo self path'
    }
}
