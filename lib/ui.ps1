function Get-ProductName {
    return 'DevRepo'
}

function Get-ProductSubtitle {
    return 'Your development workspace, simplified.'
}

function Get-ProductTitle {
    return "$(Get-ProductName) v$(Get-DevToolsVersion)"
}

function Get-DevToolsVersion {
    $versionPath = Join-Path $DevToolsRoot 'VERSION'

    if (Test-Path $versionPath) {
        $version = (Get-Content -Path $versionPath -Raw).Trim()
        if (-not [string]::IsNullOrWhiteSpace($version)) {
            return $version
        }
    }

    return '0.0.0'
}

function Test-DevToolsUnicodeSupported {
    if ($null -ne $script:DevToolsUnicodeSupportCached) {
        return $script:DevToolsUnicodeSupportCached
    }

    $supported = $false

    try {
        if ($env:DEVTOOLS_ASCII -eq '1') {
            $script:DevToolsUnicodeSupportCached = $false
            return $false
        }

        if ($env:DEVTOOLS_FORCE_UNICODE -eq '1') {
            $script:DevToolsUnicodeSupportCached = $true
            return $true
        }

        if ($env:WT_SESSION -or $env:TERM_PROGRAM -eq 'vscode') {
            $supported = $true
        }
        else {
            try {
                $supported = ([Console]::OutputEncoding.CodePage -eq 65001)
            }
            catch {
                $supported = $false
            }
        }
    }
    catch {
        $supported = $false
    }

    $script:DevToolsUnicodeSupportCached = $supported
    return $supported
}

function Get-DevToolsDisplaySymbol {
    <#
    .SYNOPSIS
        Returns a display symbol as a string — emoji when the console supports it, ASCII otherwise.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet(
            'status-ready',
            'status-almost',
            'status-setup',
            'check-pass',
            'check-fail',
            'check-optional',
            'success-mark',
            'item-current',
            'item-attention'
        )]
        [string]$Name
    )

    $ascii = switch ($Name) {
        'status-ready' { return '*' }
        'status-almost' { return '-' }
        'status-setup' { return 'o' }
        'check-pass' { return '*' }
        'check-fail' { return 'x' }
        'check-optional' { return 'o' }
        'success-mark' { return '*' }
        'item-current' { return '.' }
        'item-attention' { return '!' }
    }

    if (-not (Test-DevToolsUnicodeSupported)) {
        return $ascii
    }

    try {
        $unicode = switch ($Name) {
            'status-ready' { [char]::ConvertFromUtf32(0x1F7E2) }
            'status-almost' { [char]::ConvertFromUtf32(0x1F7E1) }
            'status-setup' { [char]::ConvertFromUtf32(0x1F7E0) }
            'check-pass' { [char]::ConvertFromUtf32(0x2713) }
            'check-fail' { [char]::ConvertFromUtf32(0x2717) }
            'check-optional' { [char]::ConvertFromUtf32(0x25CB) }
            'success-mark' { [char]::ConvertFromUtf32(0x2713) }
            'item-current' { [char]::ConvertFromUtf32(0x00B7) }
            'item-attention' { '!' }
        }

        if (-not [string]::IsNullOrEmpty($unicode)) {
            return $unicode
        }
    }
    catch {
        # Fall back to ASCII on any conversion or rendering issue.
    }

    return $ascii
}

function Get-UiIcon {
    param(
        [ValidateSet('ready', 'attention', 'missing', 'pass', 'warn', 'fail')]
        [string]$Name
    )

    switch ($Name) {
        'ready' { return '*' }
        'attention' { return '-' }
        'missing' { return 'x' }
        'pass' { return '*' }
        'warn' { return '-' }
        'fail' { return 'x' }
    }
}

function ShowScreenTitle {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ''
}

function ShowScreenDescription {
    param([Parameter(Mandatory = $true)][string[]]$Lines)

    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            Write-Host ''
        }
        else {
            Write-Host $line -ForegroundColor DarkGray
        }
    }

    Write-Host ''
}

function ShowWorkspaceContext {
    $repoCount = 0

    if ($Config -and -not [string]::IsNullOrWhiteSpace($Config.workspacePath) -and (Test-Path $Config.workspacePath)) {
        $repoCount = @(Get-WorkspaceGitRepos -WorkspacePath $Config.workspacePath).Count
    }

    Write-Host 'Workspace' -ForegroundColor Cyan
    Write-Host "  $($Config.workspacePath)" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'GitHub Owners' -ForegroundColor Cyan

    foreach ($owner in @($Config.githubOwners)) {
        Write-Host "  $owner" -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Host 'Repositories' -ForegroundColor Cyan
    Write-Host "  $repoCount" -ForegroundColor DarkGray
    Write-Host ''
}

function ShowContextHeader {
    param([switch]$Clear)

    if ($Clear) {
        Clear-Host
    }

    Write-Host (Get-ProductTitle) -ForegroundColor Cyan
    Write-Host (Get-ProductSubtitle) -ForegroundColor DarkGray
    Write-Host 'by Novenworks' -ForegroundColor DarkGray
    Write-Host ''

    if ($Config) {
        ShowWorkspaceContext
    }
}

function ShowHeader {
    param(
        [switch]$Clear,
        [switch]$Menu
    )

    ShowContextHeader -Clear:$Clear

    if ($Menu) {
        Write-Host 'Menu' -ForegroundColor Cyan
        Write-Host ''
    }
}

function ShowCommandScreen {
    param(
        [Parameter(Mandatory = $true)][string]$Heading,
        [Parameter(Mandatory = $true)][string[]]$Description,
        [switch]$Clear
    )

    ShowContextHeader -Clear:$Clear
    ShowScreenTitle -Title $Heading
    ShowScreenDescription -Lines $Description
}

function ShowSection {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [string]$Value
    )

    Write-Host $Label -ForegroundColor Cyan

    if ($PSBoundParameters.ContainsKey('Value')) {
        Write-Host "  $Value" -ForegroundColor DarkGray
    }

    Write-Host ''
}

function ShowSuccess {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function ShowWarning {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function ShowError {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function ShowInfo {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "  $Message" -ForegroundColor DarkGray
}

function ShowStatusLine {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][ValidateSet('ready', 'attention', 'missing')][string]$State,
        [string]$Detail
    )

    $icon = Get-UiIcon -Name $State
    $color = switch ($State) {
        'ready' { 'Green' }
        'attention' { 'Yellow' }
        'missing' { 'Yellow' }
    }

    $suffix = if ($Detail) { "  $Detail" } else { '' }
    Write-Host "  $icon $Label$suffix" -ForegroundColor $color
}

function ShowSummary {
    param(
        [string]$Title,
        [Parameter(Mandatory = $true)][string[]]$Lines
    )

    Write-Host ''

    if (-not [string]::IsNullOrWhiteSpace($Title)) {
        Write-Host $Title -ForegroundColor Cyan
        Write-Host ''
    }

    foreach ($line in $Lines) {
        Write-Host "  $line" -ForegroundColor DarkGray
    }
}

function ShowRepositoryStatusTable {
    param([Parameter(Mandatory = $true)][array]$Rows)

    if ($Rows.Count -eq 0) {
        return
    }

    $nameWidth = [math]::Max(20, ($Rows | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum)
    $branchWidth = [math]::Max(10, ($Rows | ForEach-Object { $_.Branch.Length } | Measure-Object -Maximum).Maximum)
    $statusWidth = [math]::Max(10, ($Rows | ForEach-Object { $_.DisplayStatus.Length } | Measure-Object -Maximum).Maximum)
    $format = "  {0} {1,-$nameWidth}  {2,-$branchWidth}  {3,-$statusWidth}"

    Write-Host ($format -f '', 'Repository', 'Branch', 'Status') -ForegroundColor Cyan
    Write-Host ''

    foreach ($row in $Rows) {
        $icon = switch ($row.DisplayStatus) {
            'Clean' { Get-UiIcon -Name 'ready' }
            default { Get-UiIcon -Name 'attention' }
        }

        $color = if ($row.DisplayStatus -eq 'Clean') { 'DarkGray' } else { 'Yellow' }
        Write-Host ($format -f $icon, $row.Name, $row.Branch, $row.DisplayStatus) -ForegroundColor $color
    }
}

function Wait-ForKey {
    param([string]$Message = 'Press Enter to return.')

    Write-Host ''
    Write-Host $Message -ForegroundColor DarkGray
    if (Test-DevRepoKeyboardInput) {
        do { $key = [Console]::ReadKey($true) } while ($key.Key -notin @('Enter', 'Escape'))
    }
    else { Read-Host | Out-Null }
}

function Test-DevRepoKeyboardInput {
    if ($Host.Name -ne 'ConsoleHost' -or [Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        return $false
    }

    try {
        $null = [Console]::KeyAvailable
        return $true
    }
    catch {
        return $false
    }
}

function Read-DevRepoMenuChoice {
    param(
        [Parameter(Mandatory = $true)][array]$Options,
        [string]$BackKey = 'Back',
        [hashtable]$Shortcuts = @{}
    )

    foreach ($option in $Options) {
        Write-Host ("  {0,-2} {1}" -f $option.Key, $option.Label)
    }

    Write-Host ''
    if (-not (Test-DevRepoKeyboardInput)) {
        $choice = Read-Host 'Enter a shortcut or type Back'
        if ($null -eq $choice -or $choice.Trim() -eq 'Back') { return $BackKey }
        return $choice.Trim()
    }

    Write-Host 'Use arrow keys and Enter, type a shortcut, or press Esc to go back.'
    $index = 0
    $typed = ''

    while ($true) {
        $focus = if ($typed) { "Shortcut: $typed" } else { "> $($Options[$index].Key) $($Options[$index].Label)" }
        try {
            $width = [Console]::BufferWidth - 1
            if ($width -lt 1) { $width = 79 }
            [Console]::Write("`r" + $focus.Substring(0, [Math]::Min($focus.Length, $width)).PadRight($width))
            $key = [Console]::ReadKey($true)
        }
        catch {
            Write-Host ''
            $choice = Read-Host 'Enter a shortcut or type Back'
            if ($null -eq $choice -or $choice.Trim() -eq 'Back') { return $BackKey }
            return $choice.Trim()
        }

        switch ($key.Key) {
            'UpArrow' {
                $index = ($index + $Options.Count - 1) % $Options.Count
                $typed = ''
            }
            'DownArrow' {
                $index = ($index + 1) % $Options.Count
                $typed = ''
            }
            'Backspace' {
                if ($typed.Length -gt 0) { $typed = $typed.Substring(0, $typed.Length - 1) }
            }
            'Escape' { Write-Host ''; return $BackKey }
            'Enter' {
                Write-Host ''
                if ($typed) { return $typed }
                return $Options[$index].Key
            }
            default {
                $character = [string]$key.KeyChar
                if ($character -notmatch '^[a-z0-9]$') { continue }
                $typed = "$typed$character"
                $exact = $typed -in $Options.Key -or $Shortcuts.ContainsKey($typed)
                $longer = $Options.Key -like "${typed}?*"
                if ($exact -and -not $longer) { Write-Host ''; return $typed }
            }
        }
    }
}

function Confirm-DevRepoAction {
    param([Parameter(Mandatory = $true)][string]$Label)

    $choices = @(
        [pscustomobject]@{ Key = 'N'; Label = 'Go back' }
        [pscustomobject]@{ Key = 'Y'; Label = $Label }
    )
    return (Read-DevRepoMenuChoice -Options $choices -BackKey 'N') -eq 'Y'
}

function ShowYesNoPrompt {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [string]$YesLabel = '[Y] Yes',
        [string]$NoLabel = '[N] Later'
    )

    Write-Host ''
    Write-Host $YesLabel -ForegroundColor Green
    Write-Host $NoLabel -ForegroundColor DarkGray
    Write-Host ''

    $answer = Read-Host $Prompt
    return ($answer -match '^[Yy]$')
}

function ShowInstallPrompt {
    param([Parameter(Mandatory = $true)][string]$Prompt)

    Write-Host ''
    Write-Host '[Y] Install' -ForegroundColor Green
    Write-Host '[N] Later' -ForegroundColor DarkGray
    Write-Host ''

    $answer = Read-Host $Prompt
    return ($answer -match '^[Yy]$')
}

function ShowReviewBlock {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Value
    )

    Write-Host $Label -ForegroundColor Cyan
    Write-Host "  $Value" -ForegroundColor DarkGray
    Write-Host ''
}

function ShowDoctorCheckCard {
    param(
        [Parameter(Mandatory = $true)]$Check
    )

    Write-Host $Check.Label -ForegroundColor Cyan
    Write-Host "  Status: $($Check.StatusText)" -ForegroundColor DarkGray

    $versionDisplay = if ($Check.Version) { $Check.Version } else { '—' }
    Write-Host "  Version: $versionDisplay" -ForegroundColor DarkGray
    Write-Host "  $($Check.WhyItMatters)" -ForegroundColor DarkGray

    if ($Check.Passed) {
        Write-Host "  $($Check.SuggestedAction)" -ForegroundColor Green
    }
    else {
        Write-Host "  Suggested Fix: $($Check.SuggestedAction)" -ForegroundColor Yellow
    }

    Write-Host ''
}

function ShowDoctorSystemStatus {
    param(
        [Parameter(Mandatory = $true)]$Status
    )

    ShowSummary -Title 'System Status' -Lines @(
        'Required'
        "Ready: $($Status.RequiredReady)"
        "Needs Attention: $($Status.RequiredAttention)"
        'Optional'
        "Installed: $($Status.OptionalInstalled)"
        "Missing: $($Status.OptionalMissing)"
    )

    Write-Host ''
    $color = switch ($Status.OverallStatus) {
        'Ready to Build' { 'Green' }
        'Almost Ready' { 'Green' }
        default { 'Yellow' }
    }

    Write-Host $Status.OverallStatus -ForegroundColor $color
    Write-Host ''
}

function ShowAboutScreen {
    ShowScreenTitle -Title (Get-ProductName)
    ShowInfo "Version: $(Get-DevToolsVersion)"
    ShowInfo 'Author: Novenworks'
    ShowInfo 'License: MIT'
    ShowInfo "Repository: $(Get-DevToolsRepositoryUrl)"
    ShowInfo "Mission: $(Get-ProductMission)"
    ShowInfo 'Built by Novenworks.'
}
