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
        DevPs1Path      = Join-Path $Root 'dev.ps1'
        InUserPath      = (Test-DevToolsRootInUserPath -Root $Root)
        UserPathEntries = @(Get-DevToolsUserPathEntries)
    }
}

function Get-DevToolsCommandResolution {
    $commands = @(Get-Command -Name 'dev' -CommandType Application -ErrorAction SilentlyContinue -All)

    return @(
        $commands |
            ForEach-Object {
                $source = $_.Source
                $commandRoot = ConvertTo-NormalizedDirectoryPath -Path (Split-Path -Parent $source)
                $isDevTools = (Test-Path -LiteralPath (Join-Path $commandRoot 'dev.ps1'))

                [pscustomobject]@{
                    Source   = $source
                    Root     = $commandRoot
                    IsDevTools = $isDevTools
                }
            }
    )
}

function Test-DevToolsConflictingDevCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Root
    )

    $normalizedRoot = ConvertTo-NormalizedDirectoryPath -Path $Root
    $conflicts = @()

    foreach ($command in Get-DevToolsCommandResolution) {
        if ($command.Root -eq $normalizedRoot) {
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

function Invoke-DevToolsSelfInstall {
    $root = Get-DevToolsRoot

    if (-not $root) {
        ShowError 'Unable to determine the DevTools installation root.'
        return 1
    }

    $devCmdPath = Join-Path $root 'dev.cmd'

    if (-not (Test-Path -LiteralPath $devCmdPath)) {
        ShowError 'This DevTools installation appears incomplete.'
        ShowInfo "Missing: $devCmdPath"
        return 1
    }

    $conflicts = @(Test-DevToolsConflictingDevCommand -Root $root)

    if ($conflicts.Count -gt 0) {
        ShowWarning 'Another dev command is already available on your PATH.'
        Write-Host ''

        foreach ($conflict in $conflicts) {
            ShowInfo "Found: $($conflict.Source)"
        }

        Write-Host ''
        ShowInfo 'DevTools will not modify your user PATH until this is resolved.'
        ShowInfo 'Run: dev self path'
        return 1
    }

    if (Test-DevToolsRootInUserPath -Root $root) {
        ShowSuccess 'DevTools is already available on your PATH.'
        ShowInfo "Location: $(ConvertTo-NormalizedDirectoryPath -Path $root)"
        return 0
    }

    $added = Add-DevToolsRootToUserPath -Root $root

    if (-not $added) {
        ShowSuccess 'DevTools is already available on your PATH.'
        return 0
    }

    Write-Host ''
    ShowSuccess 'DevTools was added to your user PATH.'
    ShowInfo 'Close and reopen PowerShell, then run: dev'
    Write-Host ''
    return 0
}

function Invoke-DevToolsSelfUninstall {
    $root = Get-DevToolsRoot

    if (-not $root) {
        ShowError 'Unable to determine the DevTools installation root.'
        return 1
    }

    $removed = Remove-DevToolsRootFromUserPath -Root $root

    if (-not $removed) {
        ShowInfo 'DevTools is not currently on your user PATH.'
        ShowInfo "Location: $(ConvertTo-NormalizedDirectoryPath -Path $root)"
        return 0
    }

    Write-Host ''
    ShowSuccess 'DevTools was removed from your user PATH.'
    ShowInfo 'Close and reopen PowerShell for the change to take effect.'
    Write-Host ''
    return 0
}

function Invoke-DevToolsSelfPath {
    $root = Get-DevToolsRoot

    if (-not $root) {
        ShowError 'Unable to determine the DevTools installation root.'
        return 1
    }

    $state = Get-DevToolsPathInstallState -Root $root
    $commands = @(Get-DevToolsCommandResolution)

    ShowCommandScreen -Heading 'DevTools PATH' -Description @(
        'Installation and PATH details for this DevTools copy.'
    )

    Write-Host 'DevTools Root' -ForegroundColor Cyan
    Write-Host "  $(ConvertTo-NormalizedDirectoryPath -Path $state.Root)" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'User PATH' -ForegroundColor Cyan
    Write-Host ("  {0}" -f $(if ($state.InUserPath) { 'Installed' } else { 'Not installed' })) -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'dev command' -ForegroundColor Cyan

    if ($commands.Count -eq 0) {
        Write-Host '  Not detected on PATH in this session.' -ForegroundColor DarkGray
    }
    else {
        foreach ($command in $commands) {
            $label = if ($command.IsDevTools) { 'DevTools' } else { 'Other' }
            Write-Host "  [$label] $($command.Source)" -ForegroundColor DarkGray
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
        'Version information for this DevTools installation.'
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

    ShowCommandScreen -Heading 'DevTools Self Info' -Description @(
        'Installation details for this DevTools copy.'
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

    ShowCommandScreen -Heading 'DevTools Self Doctor' -Description @(
        'Checks this DevTools installation itself.'
        'This is different from dev doctor, which checks your development environment.'
    )

    $checks = @(
        [pscustomobject]@{ Label = 'DevTools root found'; Passed = [bool]$root }
        [pscustomobject]@{ Label = 'dev.ps1 exists'; Passed = [bool]($root -and (Test-Path (Join-Path $root 'dev.ps1'))) }
        [pscustomobject]@{ Label = 'dev.cmd exists'; Passed = [bool]($root -and (Test-Path (Join-Path $root 'dev.cmd'))) }
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
        ShowError 'Unable to determine the DevTools installation root.'
        return 1
    }

    if (-not (Test-CommandExists 'git')) {
        ShowError 'Git is required to update DevTools.'
        return 1
    }

    if (-not (Test-Path (Join-Path $root '.git'))) {
        ShowError 'This DevTools installation is not a Git repository.'
        ShowInfo 'Updates require a Git clone of the DevTools repository.'
        return 1
    }

    $statusResult = Invoke-DevToolsGitCommand -Root $root -GitArgs @('status', '--porcelain')

    if ($statusResult.ExitCode -ne 0) {
        ShowError 'Unable to read Git status for this installation.'
        return 1
    }

    if (-not [string]::IsNullOrWhiteSpace($statusResult.Output)) {
        ShowWarning 'DevTools has local changes.'
        ShowInfo 'Commit or stash them before updating.'
        Write-Host ''
        return 1
    }

    ShowInfo 'Pulling latest changes...'
    $pullResult = Invoke-DevToolsGitCommand -Root $root -GitArgs @('pull')

    if ($pullResult.ExitCode -ne 0) {
        ShowError 'DevTools update failed.'
        if (-not [string]::IsNullOrWhiteSpace($pullResult.Output)) {
            ShowInfo $pullResult.Output
        }
        return 1
    }

    ShowSuccess 'DevTools updated successfully.'
    if (-not [string]::IsNullOrWhiteSpace($pullResult.Output)) {
        ShowInfo $pullResult.Output
    }

    Write-Host ''
    return 0
}

function Show-DevToolsSelfMenuOptions {
    Write-Host '  1  Test DevTools'
    Write-Host '  2  Update DevTools'
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
        ShowCommandScreen -Heading 'DevTools Self' -Description @(
            'Manage, inspect, and safely update this DevTools installation.'
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
