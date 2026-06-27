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
