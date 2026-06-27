function Get-ProductName {
    return 'DevTools'
}

function Get-ProductSubtitle {
    return 'An open-source project by Novenworks.'
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

function ShowHomeLanding {
    param([switch]$Clear)

    if ($Clear) {
        Clear-Host
    }

    Write-Host (Get-ProductTitle) -ForegroundColor Cyan
    Write-Host (Get-ProductSubtitle) -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Manage your development workspace from one place.' -ForegroundColor DarkGray
    Write-Host ''

    if ($Config) {
        ShowWorkspaceContext
    }

    Write-Host '---' -ForegroundColor DarkGray
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
    Read-Host | Out-Null
}

function ShowMainMenuOptions {
    Write-Host '  1  Home Dashboard'
    Write-Host '  2  Quick Actions'
    Write-Host '  3  Doctor'
    Write-Host '  4  Configure'
    Write-Host '  5  Settings'
    Write-Host '  6  Clone missing repositories'
    Write-Host '  7  Update repositories'
    Write-Host '  8  Repository status'
    Write-Host '  9  Backup changed repositories'
    Write-Host '  10 Open project'
    Write-Host '  11 Help'
    Write-Host '  12 Exit'
    Write-Host ''
    Write-Host 'Type a number and press Enter.' -ForegroundColor DarkGray
    Write-Host ''
}

function ShowHomeActions {
    param(
        [Parameter(Mandatory = $true)]$Actions
    )

    Write-Host '---' -ForegroundColor DarkGray
    Write-Host ''

    foreach ($action in $Actions) {
        Write-Host "  $($action.Key)  $($action.Label)"
    }

    Write-Host ''
    Write-Host 'Type a number and press Enter.' -ForegroundColor DarkGray
    Write-Host ''
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

function ShowSavePrompt {
    Write-Host ''
    Write-Host '[Y] Save' -ForegroundColor Green
    Write-Host '[N] Start Over' -ForegroundColor DarkGray
    Write-Host ''

    $answer = Read-Host 'Save these settings?'
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
