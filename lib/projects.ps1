function Test-ProjectIsGitRepo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return Test-Path -LiteralPath (Join-Path $Path '.git')
}

function Get-WorkspaceProjects {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath
    )

    if (-not (Test-Path -LiteralPath $WorkspacePath -PathType Container)) {
        return @()
    }

    $entries = @()

    foreach ($dir in Get-ChildItem -LiteralPath $WorkspacePath -Directory -ErrorAction SilentlyContinue) {
        $isGit = Test-ProjectIsGitRepo -Path $dir.FullName
        $entries += [pscustomobject]@{
            Name     = $dir.Name
            FullName = $dir.FullName
            IsGit    = $isGit
        }
    }

    return @($entries | Sort-Object { -not $_.IsGit }, Name)
}

function Get-ProjectSearchRank {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Query
    )

    if ([string]::IsNullOrWhiteSpace($Query)) {
        return 0
    }

    if ($Name.Equals($Query, [System.StringComparison]::OrdinalIgnoreCase)) {
        return 0
    }

    if ($Name.StartsWith($Query, [System.StringComparison]::OrdinalIgnoreCase)) {
        return 1
    }

    if ($Name.IndexOf($Query, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        return 2
    }

    return 99
}

function Search-WorkspaceProjects {
    param(
        [Parameter(Mandatory = $true)][string]$WorkspacePath,
        [string]$Query
    )

    $all = @(Get-WorkspaceProjects -WorkspacePath $WorkspacePath)

    if ([string]::IsNullOrWhiteSpace($Query)) {
        return $all
    }

    $normalized = $Query.Trim()
    $matches = @()

    foreach ($project in $all) {
        $rank = Get-ProjectSearchRank -Name $project.Name -Query $normalized
        if ($rank -lt 99) {
            $matches += [pscustomobject]@{
                Name     = $project.Name
                FullName = $project.FullName
                IsGit    = $project.IsGit
                Rank     = $rank
            }
        }
    }

    return @(
        $matches |
            Sort-Object Rank, { -not $_.IsGit }, Name |
            ForEach-Object {
                [pscustomobject]@{
                    Name     = $_.Name
                    FullName = $_.FullName
                    IsGit    = $_.IsGit
                }
            }
    )
}

function Get-ProjectTypeLabel {
    param(
        [Parameter(Mandatory = $true)][bool]$IsGit
    )

    if ($IsGit) {
        return '[git]'
    }

    return '[folder]'
}

function Show-ProjectNoMatchMenu {
    param(
        [Parameter(Mandatory = $true)][string]$Query
    )

    ShowWarning "No projects found for `"$Query`"."
    ShowInfo 'Try a different search.'
    Write-Host ''
    Write-Host '  1  Search again'
    Write-Host '  2  List all projects'
    Write-Host '  3  Return'
    Write-Host ''
}

function Search-Projects {
    param(
        [Parameter(Mandatory = $true)][string]$WorkspacePath,
        [string]$Query
    )

    return Search-WorkspaceProjects -WorkspacePath $WorkspacePath -Query $Query
}

function Open-ProjectWithEditor {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [switch]$SkipRecent
    )

    $editor = $Config.defaultEditor
    $projectName = $Project.Name
    $editorName = Get-EditorDisplayName -Editor $editor
    $target = $Project.FullName

    if (-not (Test-CommandExists $editor)) {
        ShowWarning "$editorName is unavailable."
        if (-not (Test-CommandExists 'explorer')) {
            ShowInfo 'Next: open Settings and choose an installed editor.'
            return
        }
        $editor = 'explorer'
        $editorName = 'Explorer'
        ShowInfo 'Opening the folder in Explorer instead.'
    }

    try {
        if ($editor -eq 'explorer') {
            Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $target) -ErrorAction Stop
        }
        else {
            & $editor $target
            if (-not $?) {
                ShowWarning "$editorName reported an error while opening $projectName."
                ShowInfo 'Next: check your editor in Settings or open the folder directly.'
                return
            }
        }
    }
    catch {
        ShowWarning "Could not launch $editorName for $projectName."
        ShowInfo $_.Exception.Message
        return
    }

    if (-not $SkipRecent) {
        Add-RecentProject -Project $Project
    }

    Write-Host ''
    ShowSuccess "Launch requested for $projectName in $editorName."
}

function Open-WorkspaceProject {
    param(
        [Parameter(Mandatory = $true)]$Project
    )

    Open-ProjectWithEditor -Project $Project
}

function Resolve-ProjectFromQuery {
    param(
        [Parameter(Mandatory = $true)][string]$Query
    )

    if (-not (Test-Path -LiteralPath $Config.workspacePath -PathType Container)) {
        return [pscustomobject]@{
            Projects = @()
            Error    = 'workspace'
        }
    }

    $results = @(Search-Projects -WorkspacePath $Config.workspacePath -Query $Query.Trim())

    return [pscustomobject]@{
        Projects = $results
        Error    = $null
    }
}

function Select-ProjectFromResults {
    param(
        [Parameter(Mandatory = $true)][array]$Results,
        [Parameter(Mandatory = $true)][string]$Prompt
    )

    if ($Results.Count -eq 0) {
        return $null
    }

    ShowInfo $Prompt
    $options = @(
        for ($i = 0; $i -lt $Results.Count; $i++) {
            $project = $Results[$i]
            $type = Get-ProjectTypeLabel -IsGit $project.IsGit
            [pscustomobject]@{ Key = [string]($i + 1); Label = "$($project.Name) ($type)" }
        }
        [pscustomobject]@{ Key = '0'; Label = 'Back' }
    )
    $choice = Read-DevRepoMenuChoice -Options $options -BackKey '0'
    $number = 0
    if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $Results.Count) {
        return $Results[$number - 1]
    }
    if ($choice -ne '0') { ShowWarning 'Choose a project number from the list.' }
    return $null
}

function Select-Project {
    param(
        [Parameter(Mandatory = $true)][string]$Heading,
        [Parameter(Mandatory = $true)][string[]]$Description,
        [string]$InitialQuery = '',
        [switch]$AllowExactConfirm
    )

    if (-not (Test-Path -LiteralPath $Config.workspacePath -PathType Container)) {
        ShowWarning 'Your workspace folder is not set up yet.'
        ShowInfo 'Next step: run Configure first.'
        return $null
    }

    $projects = @(Get-WorkspaceProjects -WorkspacePath $Config.workspacePath)

    if ($projects.Count -eq 0) {
        ShowInfo 'No projects found yet.'
        ShowInfo 'Next step: run Download new projects.'
        return $null
    }

    while ($true) {
        ShowCommandScreen -Heading $Heading -Description $Description

        if (-not [string]::IsNullOrWhiteSpace($InitialQuery)) {
            $searchTerm = $InitialQuery.Trim()
            $InitialQuery = ''
        }
        else {
            $query = Read-Host 'Search (Enter lists all, :back returns)'
            if ($null -eq $query -or $query.Trim() -eq ':back') { return $null }
            $searchTerm = if ($null -eq $query) { '' } else { $query.Trim() }
        }

        $results = @(Search-Projects -WorkspacePath $Config.workspacePath -Query $searchTerm)

        if ($results.Count -eq 0) {
            Show-ProjectNoMatchMenu -Query $searchTerm
            $noMatchChoice = Read-Host 'Choose an option'

            switch ($noMatchChoice) {
                '1' { continue }
                '2' {
                    $results = @(Get-WorkspaceProjects -WorkspacePath $Config.workspacePath)
                }
                '3' { return $null }
                default {
                    ShowWarning 'Please choose 1, 2, or 3.'
                    Wait-ForKey -Message 'Press Enter to try again'
                    continue
                }
            }
        }
        elseif ($AllowExactConfirm -and $results.Count -eq 1 -and -not [string]::IsNullOrWhiteSpace($searchTerm) -and (Get-ProjectSearchRank -Name $results[0].Name -Query $searchTerm) -eq 0) {
            $project = $results[0]

            if (ShowYesNoPrompt -Prompt "Open $($project.Name)?" -YesLabel '[Y] Yes' -NoLabel '[N] Search again') {
                return $project
            }

            continue
        }
        return (Select-ProjectFromResults -Results $results -Prompt 'Choose a project from the results.')
    }
}

function Invoke-OpenProjectByName {
    param(
        [Parameter(Mandatory = $true)][string]$Query
    )

    $resolved = Resolve-ProjectFromQuery -Query $Query

    if ($resolved.Error -eq 'workspace') {
        ShowWarning 'Your workspace folder is not set up yet.'
        ShowInfo 'Next step: run Configure first.'
        return
    }

    $results = @($resolved.Projects)

    if ($results.Count -eq 0) {
        ShowWarning "No projects found for `"$Query`"."
        return
    }

    if ($results.Count -eq 1) {
        Open-ProjectWithEditor -Project $results[0]
        return
    }

    $selected = Select-ProjectFromResults -Results $results -Prompt 'Multiple projects matched. Select a project:'
    if ($selected) {
        Open-ProjectWithEditor -Project $selected
    }
}

function Invoke-OpenProjectFlow {
    $project = Select-Project -Heading 'Open Project' -Description @(
        'Search by project name, then choose a result to launch your editor.'
        'Opened projects are saved to your local recent list.'
    ) -AllowExactConfirm

    if ($project) {
        Open-ProjectWithEditor -Project $project
    }
}
