function Get-DevToolsUserPath {
    return [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Get-DevToolsUserPathEntries {
    $userPath = Get-DevToolsUserPath

    if ([string]::IsNullOrWhiteSpace($userPath)) {
        return @()
    }

    return @(
        $userPath -split ';' |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function ConvertTo-NormalizedDirectoryPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    try {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
        return $fullPath.TrimEnd('\')
    }
    catch {
        return $Path.Trim().TrimEnd('\')
    }
}

function Test-DevToolsRootInUserPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root
    )

    $normalizedRoot = ConvertTo-NormalizedDirectoryPath -Path $Root

    foreach ($entry in Get-DevToolsUserPathEntries) {
        if ((ConvertTo-NormalizedDirectoryPath -Path $entry) -eq $normalizedRoot) {
            return $true
        }
    }

    return $false
}

function Get-DevToolsPathInstallState {
    param(
        [Parameter(Mandatory = $true)][string]$Root
    )

    return [pscustomobject]@{
        Root            = $Root
        DevCmdPath      = Join-Path $Root 'dev.cmd'
        DevCorePath     = Join-Path $Root 'dev-core.ps1'
        LegacyDevPs1Path = Join-Path $Root 'dev.ps1'
        InUserPath      = (Test-DevToolsRootInUserPath -Root $Root)
        UserPathEntries = @(Get-DevToolsUserPathEntries)
    }
}

function Get-DevToolsCommandResolution {
    param([ValidateSet('devrepo', 'dev')][string]$Name = 'dev')

    $commands = @(Get-Command -Name $Name -ErrorAction SilentlyContinue -All |
        Where-Object { $_.CommandType -in @('Application', 'ExternalScript', 'Alias', 'Function') })

    return @(
        $commands |
            ForEach-Object {
                $source = $_.Source
                if ([string]::IsNullOrWhiteSpace($source)) { $source = $_.Name }
                $commandRoot = $null
                if ($_.CommandType -in @('Application', 'ExternalScript')) {
                    $commandRoot = ConvertTo-NormalizedDirectoryPath -Path (Split-Path -Parent $source)
                }
                $isDevTools = $commandRoot -and (Test-DevToolsInstallationRoot -Path $commandRoot)

                [pscustomobject]@{
                    Source     = $source
                    Root       = $commandRoot
                    IsDevTools = $isDevTools
                    Extension  = [System.IO.Path]::GetExtension($source).ToLower()
                }
            }
    )
}

function Get-DevToolsEarlierPathConflicts {
    param(
        [Parameter(Mandatory = $true)][string]$Root
    )

    $normalizedRoot = ConvertTo-NormalizedDirectoryPath -Path $Root
    $entries = @(
        $env:Path -split ';' |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    $devToolsIndex = -1
    for ($index = 0; $index -lt $entries.Count; $index++) {
        if ((ConvertTo-NormalizedDirectoryPath -Path $entries[$index]) -eq $normalizedRoot) {
            $devToolsIndex = $index
            break
        }
    }

    $conflicts = @()

    for ($index = 0; $index -lt $entries.Count; $index++) {
        if ($devToolsIndex -ge 0 -and $index -ge $devToolsIndex) {
            break
        }

        $entry = ConvertTo-NormalizedDirectoryPath -Path $entries[$index]

        foreach ($commandName in @('devrepo.cmd', 'devrepo.ps1', 'devrepo.exe', 'devrepo.bat', 'dev.cmd', 'dev.ps1', 'dev.exe', 'dev.bat')) {
            $commandPath = Join-Path $entry $commandName

            if (Test-Path -LiteralPath $commandPath) {
                $conflicts += [pscustomobject]@{
                    PathEntry  = $entry
                    CommandPath = $commandPath
                    CommandName = $commandName
                    IsDevTools = (Test-DevToolsInstallationRoot -Path $entry)
                }
            }
        }
    }

    return @($conflicts)
}

function Test-DevToolsCommandResolvesSafely {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [ValidateSet('devrepo', 'dev')][string]$Name = 'dev'
    )

    $commands = @(Get-DevToolsCommandResolution -Name $Name)
    $normalizedRoot = ConvertTo-NormalizedDirectoryPath -Path $Root

    if ($commands.Count -eq 0) {
        return $false
    }

    $first = $commands[0]

    return $first.IsDevTools `
        -and ($first.Root -eq $normalizedRoot) `
        -and ($first.Extension -eq '.cmd')
}

function Test-DevToolsConflictingDevCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Root
    )

    $normalizedRoot = ConvertTo-NormalizedDirectoryPath -Path $Root
    $conflicts = @()

    foreach ($command in @((Get-DevToolsCommandResolution -Name devrepo) + (Get-DevToolsCommandResolution -Name dev))) {
        if ($command.Root -eq $normalizedRoot -and $command.Extension -eq '.cmd') {
            continue
        }

        $conflicts += $command
    }

    return @($conflicts)
}

function Add-DevToolsRootToUserPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root
    )

    $normalizedRoot = ConvertTo-NormalizedDirectoryPath -Path $Root
    $entries = @(Get-DevToolsUserPathEntries)

    if (Test-DevToolsRootInUserPath -Root $normalizedRoot) {
        return $false
    }

    if ($entries.Count -eq 0) {
        $newPath = $normalizedRoot
    }
    else {
        $newPath = ($entries + $normalizedRoot) -join ';'
    }

    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    return $true
}

function Remove-DevToolsRootFromUserPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root
    )

    $normalizedRoot = ConvertTo-NormalizedDirectoryPath -Path $Root
    $entries = @(Get-DevToolsUserPathEntries)
    $remaining = @(
        $entries | Where-Object {
            (ConvertTo-NormalizedDirectoryPath -Path $_) -ne $normalizedRoot
        }
    )

    if ($remaining.Count -eq $entries.Count) {
        return $false
    }

    $newPath = if ($remaining.Count -eq 0) { '' } else { ($remaining -join ';') }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    return $true
}

function Test-DevToolsInstallValidation {
    param(
        [Parameter(Mandatory = $true)][string]$Root
    )

    $checks = @(
        [pscustomobject]@{ Label = 'DevRepo root exists'; Passed = (Test-Path -LiteralPath $Root) }
        [pscustomobject]@{ Label = 'devrepo.cmd exists'; Passed = (Test-Path -LiteralPath (Join-Path $Root 'devrepo.cmd')) }
        [pscustomobject]@{ Label = 'dev.cmd exists'; Passed = (Test-Path -LiteralPath (Join-Path $Root 'dev.cmd')) }
        [pscustomobject]@{ Label = 'dev-core.ps1 exists'; Passed = (Test-Path -LiteralPath (Join-Path $Root 'dev-core.ps1')) }
        [pscustomobject]@{ Label = 'User PATH contains DevRepo root'; Passed = (Test-DevToolsRootInUserPath -Root $Root) }
    )

    return @($checks)
}

function Invoke-DevToolsInstallScript {
    param(
        [Parameter(Mandatory = $true)][string]$Root
    )

    Write-Host ''
    Write-Host 'Installing DevRepo...' -ForegroundColor Cyan
    Write-Host ''

    $normalizedRoot = ConvertTo-NormalizedDirectoryPath -Path $Root
    $devCmdPath = Join-Path $normalizedRoot 'dev.cmd'
    $devCorePath = Join-Path $normalizedRoot 'dev-core.ps1'
    $primaryLauncher = Join-Path $normalizedRoot 'devrepo.cmd'

    if (-not (Test-Path -LiteralPath $primaryLauncher)) {
        Write-Host "Missing required launcher: $primaryLauncher" -ForegroundColor Red
        return 1
    }

    if (-not (Test-Path -LiteralPath $devCmdPath)) {
        Write-Host "Missing required launcher: $devCmdPath" -ForegroundColor Red
        return 1
    }

    if (-not (Test-Path -LiteralPath $devCorePath)) {
        Write-Host "Missing required entrypoint: $devCorePath" -ForegroundColor Red
        return 1
    }

    if (Test-DevToolsRootInUserPath -Root $normalizedRoot) {
        Write-Host 'DevRepo is already installed on your user PATH.' -ForegroundColor Green
        Write-Host "Location: $normalizedRoot" -ForegroundColor DarkGray
        Write-Host ''
    }
    else {
        $pathConflicts = @(Get-DevToolsEarlierPathConflicts -Root $normalizedRoot)
        $commandConflicts = @(Test-DevToolsConflictingDevCommand -Root $normalizedRoot)

        if ($pathConflicts.Count -gt 0 -or $commandConflicts.Count -gt 0) {
            Write-Host 'Warning: another devrepo or dev command appears earlier on your PATH.' -ForegroundColor Yellow
            Write-Host ''

            foreach ($conflict in $pathConflicts) {
                Write-Host "  Found: $($conflict.CommandPath)" -ForegroundColor DarkGray
            }

            foreach ($conflict in $commandConflicts) {
                Write-Host "  Found: $($conflict.Source)" -ForegroundColor DarkGray
            }

            Write-Host ''
            Write-Host 'DevRepo will still be added to your user PATH.' -ForegroundColor DarkGray
            Write-Host 'If another devrepo or dev command comes first, type devrepo self path after reopening PowerShell.' -ForegroundColor DarkGray
            Write-Host ''
        }

        $added = Add-DevToolsRootToUserPath -Root $normalizedRoot

        if ($added) {
            Write-Host "Added $normalizedRoot to your user PATH." -ForegroundColor Green
            Write-Host ''
        }
    }

    Write-Host 'Install validation:' -ForegroundColor Cyan

    foreach ($check in (Test-DevToolsInstallValidation -Root $normalizedRoot)) {
        $symbol = if ($check.Passed) { '*' } else { 'x' }
        $color = if ($check.Passed) { 'Green' } else { 'Yellow' }
        Write-Host "  $symbol $($check.Label)" -ForegroundColor $color
    }

    Write-Host ''
    Write-Host 'DevRepo installed successfully.' -ForegroundColor Green
    Write-Host ''
    Write-Host 'Close and reopen PowerShell, then run:' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  devrepo' -ForegroundColor Cyan
    Write-Host '  dev remains supported.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Run devrepo self path if the global dev command does not resolve correctly.' -ForegroundColor DarkGray
    Write-Host ''

    return 0
}

function Invoke-DevToolsSelfInstall {
    $root = Get-DevToolsRoot

    if (-not $root) {
        ShowError 'Unable to determine the DevRepo installation root.'
        return 1
    }

    $devCmdPath = Join-Path $root 'dev.cmd'
    $devCorePath = Join-Path $root 'dev-core.ps1'
    $primaryLauncher = Join-Path $root 'devrepo.cmd'
    if (-not (Test-Path -LiteralPath $primaryLauncher)) {
        ShowError "Missing required launcher: $primaryLauncher"
        return 1
    }

    if (-not (Test-Path -LiteralPath $devCmdPath)) {
        ShowError 'This DevRepo installation appears incomplete.'
        ShowInfo "Missing: $devCmdPath"
        return 1
    }

    if (-not (Test-Path -LiteralPath $devCorePath)) {
        ShowError 'This DevRepo installation appears incomplete.'
        ShowInfo "Missing: $devCorePath"
        return 1
    }

    $conflicts = @(Test-DevToolsConflictingDevCommand -Root $root)

    if ($conflicts.Count -gt 0) {
        ShowWarning 'Another devrepo or dev command is already available on your PATH.'
        Write-Host ''

        foreach ($conflict in $conflicts) {
            ShowInfo "Found: $($conflict.Source)"
        }

        Write-Host ''
        ShowInfo 'DevRepo will not modify your user PATH until this is resolved.'
        ShowInfo 'Run: devrepo self path'
        return 1
    }

    if (Test-DevToolsRootInUserPath -Root $root) {
        ShowSuccess 'DevRepo is already available on your PATH.'
        ShowInfo "Location: $(ConvertTo-NormalizedDirectoryPath -Path $root)"
        return 0
    }

    $added = Add-DevToolsRootToUserPath -Root $root

    if (-not $added) {
        ShowSuccess 'DevRepo is already available on your PATH.'
        return 0
    }

    Write-Host ''
    ShowSuccess 'DevRepo was added to your user PATH.'
    ShowInfo 'Close and reopen PowerShell, then run: devrepo'
    Write-Host ''
    return 0
}

function Invoke-DevToolsSelfUninstall {
    $root = Get-DevToolsRoot

    if (-not $root) {
        ShowError 'Unable to determine the DevRepo installation root.'
        return 1
    }

    $removed = Remove-DevToolsRootFromUserPath -Root $root

    if (-not $removed) {
        ShowInfo 'DevRepo is not currently on your user PATH.'
        ShowInfo "Location: $(ConvertTo-NormalizedDirectoryPath -Path $root)"
        return 0
    }

    Write-Host ''
    ShowSuccess 'DevRepo was removed from your user PATH.'
    ShowInfo 'Close and reopen PowerShell for the change to take effect.'
    Write-Host ''
    return 0
}

function Invoke-DevToolsSelfPath {
    $root = Get-DevToolsRoot

    if (-not $root) {
        ShowError 'Unable to determine the DevRepo installation root.'
        return 1
    }

    $state = Get-DevToolsPathInstallState -Root $root
    $pathConflicts = @(Get-DevToolsEarlierPathConflicts -Root $root)

    ShowCommandScreen -Heading 'DevRepo PATH' -Description @(
        'Check where Windows finds devrepo and the legacy dev launcher.'
    )
    ShowInfo "Installation: $($state.Root)"
    ShowInfo "On User PATH: $($state.InUserPath)"

    foreach ($name in @('devrepo', 'dev')) {
        ShowSection -Label $name
        $commands = @(Get-DevToolsCommandResolution -Name $name)
        if ($commands.Count -eq 0) {
            ShowInfo 'Unavailable in this session. Reopen PowerShell after installing.'
            continue
        }
        foreach ($command in $commands) {
            ShowInfo $command.Source
        }
        if (-not (Test-DevToolsCommandResolvesSafely -Root $root -Name $name)) {
            ShowWarning "Expected $name.cmd from this installation first."
        }
    }

    if (Test-Path -LiteralPath $state.LegacyDevPs1Path) {
        Write-Host ''
        Write-Host 'Conflicting root dev.ps1' -ForegroundColor Cyan
        Write-Host "  Found: $($state.LegacyDevPs1Path)" -ForegroundColor DarkGray
        Write-Host '  Remove dev.ps1 from the DevRepo root to avoid PowerShell preferring it over dev.cmd.' -ForegroundColor DarkGray
    }

    if ($pathConflicts.Count -gt 0) {
        Write-Host ''
        Write-Host 'Earlier PATH conflicts' -ForegroundColor Cyan

        foreach ($conflict in $pathConflicts) {
            Write-Host "  $($conflict.CommandPath)" -ForegroundColor DarkGray
        }
    }

    Write-Host ''
    return 0
}

function Invoke-DevToolsSelfTest {
    return Invoke-DevToolsTestSuite
}

function Invoke-DevToolsSelfVersion {
    $root = Get-DevToolsRoot

    ShowCommandScreen -Heading (Get-ProductName) -Description @(
        'Version information for this DevRepo installation.'
    )

    Write-Host 'Version' -ForegroundColor Cyan
    Write-Host "  v$(Get-DevToolsVersion)" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Repository' -ForegroundColor Cyan
    Write-Host "  $(Get-DevToolsRepositoryUrl)" -ForegroundColor DarkGray

    if ($root) {
        Write-Host ''
        Write-Host 'Installation Path' -ForegroundColor Cyan
        Write-Host "  $(ConvertTo-NormalizedDirectoryPath -Path $root)" -ForegroundColor DarkGray
    }

    Write-Host ''
    return 0
}

function Invoke-DevToolsGitCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string[]]$GitArgs
    )

    if (-not (Test-CommandExists 'git')) {
        return [pscustomobject]@{
            ExitCode = 1
            Output   = ''
        }
    }

    Push-Location $Root
    try {
        $output = & git @GitArgs 2>$null
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output | Out-String).Trim()
        }
    }
    catch {
        return [pscustomobject]@{
            ExitCode = 1
            Output   = ''
        }
    }
    finally {
        Pop-Location
    }
}

function Get-DevToolsSelfGitDetails {
    param(
        [Parameter(Mandatory = $true)][string]$Root
    )

    if (-not (Test-Path (Join-Path $Root '.git'))) {
        return [pscustomobject]@{
            IsRepo     = $false
            Remote     = 'Unknown'
            Branch     = 'Unknown'
            LastCommit = 'Unknown'
            TreeStatus = 'Unknown'
        }
    }

    $remote = 'Unknown'
    $branch = 'Unknown'
    $lastCommit = 'Unknown'
    $treeStatus = 'Unknown'

    $remoteResult = Invoke-DevToolsGitCommand -Root $Root -GitArgs @('remote', 'get-url', 'origin')
    if ($remoteResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($remoteResult.Output)) {
        $remote = $remoteResult.Output
    }

    $branchResult = Invoke-DevToolsGitCommand -Root $Root -GitArgs @('branch', '--show-current')
    if ($branchResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($branchResult.Output)) {
        $branch = $branchResult.Output
    }

    $commitResult = Invoke-DevToolsGitCommand -Root $Root -GitArgs @('log', '-1', '--format=%h %s (%cr)')
    if ($commitResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($commitResult.Output)) {
        $lastCommit = $commitResult.Output
    }

    $statusResult = Invoke-DevToolsGitCommand -Root $Root -GitArgs @('status', '--porcelain')
    if ($statusResult.ExitCode -eq 0) {
        if ([string]::IsNullOrWhiteSpace($statusResult.Output)) {
            $treeStatus = 'Clean'
        }
        else {
            $treeStatus = 'Modified'
        }
    }

    return [pscustomobject]@{
        IsRepo     = $true
        Remote     = $remote
        Branch     = $branch
        LastCommit = $lastCommit
        TreeStatus = $treeStatus
    }
}

function Invoke-DevToolsSelfInfo {
    $root = Get-DevToolsRoot
    $configPath = if (Get-Command Get-DevToolsConfigPath -ErrorAction SilentlyContinue) {
        Get-DevToolsConfigPath
    }
    elseif ($root) {
        Join-Path $root 'config.json'
    }
    else {
        'Unknown'
    }

    $gitDetails = if ($root) {
        Get-DevToolsSelfGitDetails -Root $root
    }
    else {
        $null
    }

    ShowCommandScreen -Heading 'DevRepo Self Info' -Description @(
        'Installation details for this DevRepo copy.'
    )

    Write-Host 'Installation Path' -ForegroundColor Cyan
    Write-Host "  $(if ($root) { ConvertTo-NormalizedDirectoryPath -Path $root } else { 'Unknown' })" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Config Path' -ForegroundColor Cyan
    Write-Host "  $configPath" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Version' -ForegroundColor Cyan
    Write-Host "  v$(Get-DevToolsVersion)" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Git Remote' -ForegroundColor Cyan
    Write-Host "  $(if ($gitDetails) { $gitDetails.Remote } else { 'Unknown' })" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Current Branch' -ForegroundColor Cyan
    Write-Host "  $(if ($gitDetails) { $gitDetails.Branch } else { 'Unknown' })" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Last Commit' -ForegroundColor Cyan
    Write-Host "  $(if ($gitDetails) { $gitDetails.LastCommit } else { 'Unknown' })" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Working Tree Status' -ForegroundColor Cyan
    Write-Host "  $(if ($gitDetails) { $gitDetails.TreeStatus } else { 'Unknown' })" -ForegroundColor DarkGray
    Write-Host ''
    return 0
}

function Invoke-DevToolsSelfDoctor {
    $root = Get-DevToolsRoot

    ShowCommandScreen -Heading 'DevRepo Self Doctor' -Description @(
        'Checks this DevRepo installation itself.'
        'This is different from devrepo doctor, which checks your development environment.'
    )

    $checks = @(
        [pscustomobject]@{ Label = 'DevRepo root found'; Passed = [bool]$root }
        [pscustomobject]@{ Label = 'devrepo.cmd exists'; Passed = (Test-Path -LiteralPath (Join-Path $Root 'devrepo.cmd')) }
        [pscustomobject]@{ Label = 'dev.cmd exists'; Passed = [bool]($root -and (Test-Path (Join-Path $root 'dev.cmd'))) }
        [pscustomobject]@{ Label = 'dev-core.ps1 exists'; Passed = [bool]($root -and (Test-Path (Join-Path $root 'dev-core.ps1'))) }
        [pscustomobject]@{ Label = 'dev.ps1 absent (avoids PATH conflict)'; Passed = [bool]($root -and -not (Test-Path (Join-Path $root 'dev.ps1'))) }
        [pscustomobject]@{ Label = 'VERSION exists'; Passed = [bool]($root -and (Test-Path (Join-Path $root 'VERSION'))) }
        [pscustomobject]@{ Label = 'config.example.json exists'; Passed = [bool]($root -and (Test-Path (Join-Path $root 'config.example.json'))) }
        [pscustomobject]@{ Label = 'tests/Test-DevTools.ps1 exists'; Passed = [bool]($root -and (Test-Path (Join-Path $root 'tests\Test-DevTools.ps1'))) }
    )

    foreach ($check in $checks) {
        $symbol = if ($check.Passed) { '*' } else { 'x' }
        $color = if ($check.Passed) { 'Green' } else { 'Yellow' }
        Write-Host "  $symbol $($check.Label)" -ForegroundColor $color
    }

    if ($root) {
        $gitDetails = Get-DevToolsSelfGitDetails -Root $root
        $gitRepoSymbol = if ($gitDetails.IsRepo) { '*' } else { 'o' }
        $remoteSymbol = if ($gitDetails.Remote -ne 'Unknown') { '*' } else { 'o' }

        Write-Host "  $gitRepoSymbol Git repository detected" -ForegroundColor $(if ($gitDetails.IsRepo) { 'Green' } else { 'DarkGray' })
        Write-Host "  $remoteSymbol GitHub remote configured" -ForegroundColor $(if ($gitDetails.Remote -ne 'Unknown') { 'Green' } else { 'DarkGray' })

        if ($gitDetails.IsRepo) {
            ShowInfo "Branch: $($gitDetails.Branch)"
            ShowInfo "Working tree: $($gitDetails.TreeStatus)"
        }
    }

    Write-Host ''
    return 0
}

function Invoke-DevToolsSelfUpdate {
    $root = Get-DevToolsRoot

    if (-not $root) {
        ShowError 'Unable to determine the DevRepo installation root.'
        return 1
    }

    if (-not (Test-CommandExists 'git')) {
        ShowError 'Git is required to update DevRepo.'
        return 1
    }

    if (-not (Test-Path (Join-Path $root '.git'))) {
        ShowError 'This DevRepo installation is not a Git repository.'
        ShowInfo 'Updates require a Git clone of the DevRepo repository.'
        return 1
    }

    $statusResult = Invoke-DevToolsGitCommand -Root $root -GitArgs @('status', '--porcelain')

    if ($statusResult.ExitCode -ne 0) {
        ShowError 'Unable to read Git status for this installation.'
        return 1
    }

    if (-not [string]::IsNullOrWhiteSpace($statusResult.Output)) {
        ShowWarning 'DevRepo has local changes.'
        ShowInfo 'Commit or stash them before updating.'
        Write-Host ''
        return 1
    }

    ShowInfo 'This checks the remote and fast-forwards this DevRepo installation when possible.'
    if (-not (Confirm-DevRepoAction -Label 'Check for and apply a fast-forward update')) {
        ShowInfo 'Installation update canceled.'
        return 0
    }
    $pullResult = Invoke-DevToolsGitCommand -Root $root -GitArgs @('pull', '--ff-only')

    if ($pullResult.ExitCode -ne 0) {
        ShowError 'DevRepo update failed.'
        if (-not [string]::IsNullOrWhiteSpace($pullResult.Output)) {
            ShowInfo $pullResult.Output
        }
        return 1
    }

    ShowSuccess 'DevRepo updated successfully.'
    if (-not [string]::IsNullOrWhiteSpace($pullResult.Output)) {
        ShowInfo $pullResult.Output
    }

    Write-Host ''
    return 0
}

function Show-DevToolsSelfMenuOptions {
    Write-Host '  1  Test DevRepo'
    Write-Host '  2  Update DevRepo'
    Write-Host '  3  Version'
    Write-Host '  4  Doctor'
    Write-Host '  5  Info'
    Write-Host '  6  Back'
    Write-Host ''
    Write-Host 'Type a number and press Enter.' -ForegroundColor DarkGray
    Write-Host ''
}

function Invoke-DevToolsSelfMenu {
    while ($true) {
        ShowCommandScreen -Heading 'DevRepo Self' -Description @(
            'Manage, inspect, and safely update this DevRepo installation.'
        )

        Show-DevToolsSelfMenuOptions
        $choice = Read-Host 'Choose an option'

        switch ($choice) {
            '1' {
                Invoke-DevToolsSelfTest | Out-Null
                Wait-ForKey -Message 'Press Enter to continue'
            }
            '2' {
                Invoke-DevToolsSelfUpdate | Out-Null
                Wait-ForKey -Message 'Press Enter to continue'
            }
            '3' {
                Invoke-DevToolsSelfVersion | Out-Null
                Wait-ForKey -Message 'Press Enter to continue'
            }
            '4' {
                Invoke-DevToolsSelfDoctor | Out-Null
                Wait-ForKey -Message 'Press Enter to continue'
            }
            '5' {
                Invoke-DevToolsSelfInfo | Out-Null
                Wait-ForKey -Message 'Press Enter to continue'
            }
            '6' { return }
            default {
                ShowWarning 'Please choose a number from the menu.'
                Wait-ForKey -Message 'Press Enter to try again'
            }
        }
    }
}
