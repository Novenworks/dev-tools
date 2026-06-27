function Get-RecentProjectsFilePath {
    return Join-Path $DevToolsRoot 'config\recent-projects.json'
}

function Ensure-RecentProjectsDirectory {
    $directory = Join-Path $DevToolsRoot 'config'
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
}

function Save-RecentProjects {
    param(
        [Parameter(Mandatory = $true)][array]$Projects
    )

    Ensure-RecentProjectsDirectory
    $path = Get-RecentProjectsFilePath
    $Projects | ConvertTo-Json -Depth 4 | Set-Content -Path $path -Encoding UTF8
}

function Get-RecentProjects {
    $path = Get-RecentProjectsFilePath

    if (-not (Test-Path $path)) {
        return @()
    }

    try {
        $items = @(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
    }
    catch {
        return @()
    }

    if ($items.Count -eq 1 -and $items[0] -is [pscustomobject]) {
        $items = @($items)
    }

    $valid = @()
    $removedStale = $false

    foreach ($item in $items) {
        if (-not $item.Path) {
            $removedStale = $true
            continue
        }

        if (Test-Path -LiteralPath $item.Path) {
            $valid += $item
        }
        else {
            $removedStale = $true
        }
    }

    if ($removedStale) {
        Save-RecentProjects -Projects $valid
    }

    return @($valid | Select-Object -First 10)
}

function Add-RecentProject {
    param(
        [Parameter(Mandatory = $true)]$Project
    )

    $path = $Project.FullName
    $name = $Project.Name
    $existing = @(Get-RecentProjects)
    $previous = @($existing | Where-Object { $_.Path -eq $path } | Select-Object -First 1)
    $openCount = 1

    if ($previous) {
        if ($previous.OpenCount) {
            $openCount = [int]$previous.OpenCount + 1
        }
    }

    $entry = [pscustomobject]@{
        Name       = $name
        Path       = $path
        LastOpened = (Get-Date).ToString('o')
        OpenCount  = $openCount
    }

    $updated = @($entry) + @($existing | Where-Object { $_.Path -ne $path })
    $updated = @($updated | Select-Object -First 10)
    Save-RecentProjects -Projects $updated
}

function Clear-RecentProjects {
    $path = Get-RecentProjectsFilePath

    if (Test-Path $path) {
        Remove-Item -LiteralPath $path -Force
    }
}

function Convert-RecentEntryToProject {
    param(
        [Parameter(Mandatory = $true)]$Entry
    )

    return [pscustomobject]@{
        Name     = $Entry.Name
        FullName = $Entry.Path
        IsGit    = (Test-ProjectIsGitRepo -Path $Entry.Path)
    }
}

function Open-RecentProject {
    param(
        [Parameter(Mandatory = $true)]$Entry
    )

    if (-not (Test-Path -LiteralPath $Entry.Path)) {
        ShowWarning "This project is no longer available: $($Entry.Name)"
        $remaining = @(Get-RecentProjects | Where-Object { $_.Path -ne $Entry.Path })
        Save-RecentProjects -Projects $remaining
        return $false
    }

    $project = Convert-RecentEntryToProject -Entry $Entry
    Open-ProjectWithEditor -Project $project
    return $true
}

function Show-HomeRecentProjects {
    $recents = @(Get-RecentProjects | Select-Object -First 5)

    if ($recents.Count -eq 0) {
        return
    }

    Write-Host 'Recent Projects' -ForegroundColor Cyan
    Write-Host ''

    for ($i = 0; $i -lt $recents.Count; $i++) {
        Write-Host ("  {0}  {1}" -f ($i + 1), $recents[$i].Name) -ForegroundColor DarkGray
    }

    Write-Host ''
    ShowInfo 'Press O to open a recent project.'
    Write-Host ''
}

function Invoke-RecentProjectsEmptyState {
    ShowCommandScreen -Heading 'Recent Projects' -Description @(
        'No recent projects yet.'
        'Open a project first, and it will appear here next time.'
    )

    Write-Host '  1  Open Project Search'
    Write-Host '  2  Main Menu'
    Write-Host '  3  Exit'
    Write-Host ''

    $choice = Read-Host 'Choose an option'

    switch ($choice) {
        '1' { Invoke-OpenProjectFlow }
        '2' {
            . (Join-Path $DevToolsRoot 'commands\menu.ps1')
            exit 0
        }
        '3' { exit 0 }
        default {
            ShowWarning 'Please choose 1, 2, or 3.'
        }
    }
}

function Invoke-RecentProjectsFlow {
    $recents = @(Get-RecentProjects)

    if ($recents.Count -eq 0) {
        Invoke-RecentProjectsEmptyState
        return
    }

    ShowCommandScreen -Heading 'Recent Projects' -Description @(
        'Your most recently opened projects.'
        'Choose a number to open a project.'
    )

    for ($i = 0; $i -lt $recents.Count; $i++) {
        $entry = $recents[$i]
        $suffix = if ($entry.OpenCount -gt 1) { "  (opened $($entry.OpenCount) times)" } else { '' }
        Write-Host ("  {0}  {1}{2}" -f ($i + 1), $entry.Name, $suffix)
    }

    Write-Host ''
    $choice = Read-Host 'Project number'

    if ($choice -notmatch '^\d+$') {
        ShowWarning 'Enter the number for the project you want.'
        return
    }

    $index = [int]$choice - 1
    if ($index -lt 0 -or $index -ge $recents.Count) {
        ShowWarning 'Invalid project number.'
        return
    }

    Open-RecentProject -Entry $recents[$index] | Out-Null
}

function Invoke-RecentProjectsPicker {
    param(
        [int]$MaxItems = 5
    )

    $recents = @(Get-RecentProjects | Select-Object -First $MaxItems)

    if ($recents.Count -eq 0) {
        ShowInfo 'No recent projects yet. Open a project first.'
        Wait-ForKey -Message 'Press Enter to continue'
        return
    }

    Write-Host ''
    Write-Host 'Open Recent Project' -ForegroundColor Cyan
    Write-Host ''

    for ($i = 0; $i -lt $recents.Count; $i++) {
        Write-Host ("  {0}  {1}" -f ($i + 1), $recents[$i].Name)
    }

    Write-Host ''
    $choice = Read-Host 'Project number'

    if ($choice -notmatch '^\d+$') {
        ShowWarning 'Enter the number for the project you want.'
        Wait-ForKey -Message 'Press Enter to try again'
        return
    }

    $index = [int]$choice - 1
    if ($index -lt 0 -or $index -ge $recents.Count) {
        ShowWarning 'Invalid project number.'
        Wait-ForKey -Message 'Press Enter to try again'
        return
    }

    Open-RecentProject -Entry $recents[$index] | Out-Null
    Wait-ForKey -Message 'Press Enter to continue'
}
