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

function Invoke-RecentProjectsFlow {
    $recents = @(Get-RecentProjects)
    if ($recents.Count -eq 0) {
        ShowCommandScreen -Heading 'Recently opened' -Description @(
            'Open a project and it will appear here next time.'
        )
        $choices = @(
            [pscustomobject]@{ Key = '1'; Label = 'Open a project' }
            [pscustomobject]@{ Key = '0'; Label = 'Back' }
        )
        if ((Read-DevRepoMenuChoice -Options $choices -BackKey '0') -eq '1') {
            Invoke-OpenProjectFlow
        }
        return
    }

    ShowCommandScreen -Heading 'Recently opened' -Description @(
        'Choose a project to open it in your configured editor.'
    )
    $choices = @(
        for ($i = 0; $i -lt $recents.Count; $i++) {
            [pscustomobject]@{ Key = [string]($i + 1); Label = $recents[$i].Name }
        }
        [pscustomobject]@{ Key = '0'; Label = 'Back' }
    )
    $choice = Read-DevRepoMenuChoice -Options $choices -BackKey '0'
    $number = 0
    if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $recents.Count) {
        Open-RecentProject -Entry $recents[$number - 1] | Out-Null
    }
    elseif ($choice -ne '0') {
        ShowWarning 'Choose a project number from the list.'
    }
}
