function Test-ProjectIsGitRepo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return Test-Path (Join-Path $Path '.git')
}

function Get-WorkspaceProjects {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspacePath
    )

    if (-not (Test-Path $WorkspacePath)) {
        return @()
    }

    $entries = @()

    foreach ($dir in Get-ChildItem -Path $WorkspacePath -Directory -ErrorAction SilentlyContinue) {
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

function Show-ProjectSearchResults {
    param(
        [Parameter(Mandatory = $true)][array]$Projects
    )

    Write-Host 'Results' -ForegroundColor Cyan
    Write-Host ''

    for ($i = 0; $i -lt $Projects.Count; $i++) {
        $project = $Projects[$i]
        $typeLabel = Get-ProjectTypeLabel -IsGit $project.IsGit
        Write-Host ("  {0}  {1} {2}" -f ($i + 1), $project.Name, $typeLabel)
    }

    Write-Host ''
}

function Open-WorkspaceProject {
    param(
        [Parameter(Mandatory = $true)]$Project
    )

    $editor = $Config.defaultEditor
    $projectName = $Project.Name
    $editorName = Get-EditorDisplayName -Editor $editor
    $target = $Project.FullName

    if ($editor -eq 'explorer') {
        ShowInfo "Opening $projectName in Explorer..."
        explorer $target
    }
    elseif (Test-CommandExists $editor) {
        ShowInfo "Opening $projectName in $editorName..."
        & $editor $target
    }
    else {
        ShowWarning "$editorName was not found. Opening in Explorer instead."
        explorer $target
    }

    Write-Host ''
    ShowSuccess 'Have a productive coding session.'
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

function Invoke-OpenProjectFlow {
    if (-not (Test-Path $Config.workspacePath)) {
        ShowWarning 'Your workspace folder is not set up yet.'
        ShowInfo 'Next step: run Configure first.'
        return
    }

    $projects = @(Get-WorkspaceProjects -WorkspacePath $Config.workspacePath)

    if ($projects.Count -eq 0) {
        ShowInfo 'No projects found yet.'
        ShowInfo 'Next step: run Clone missing repositories.'
        return
    }

    while ($true) {
        ShowCommandScreen -Heading 'Open Project' -Description @(
            'Search by project name, or press Enter to list all projects.'
        )

        $query = Read-Host 'Search'
        $searchTerm = if ($null -eq $query) { '' } else { $query.Trim() }
        $results = @(Search-WorkspaceProjects -WorkspacePath $Config.workspacePath -Query $searchTerm)

        if ($results.Count -eq 0) {
            Show-ProjectNoMatchMenu -Query $searchTerm
            $noMatchChoice = Read-Host 'Choose an option'

            switch ($noMatchChoice) {
                '1' { continue }
                '2' {
                    $results = @(Get-WorkspaceProjects -WorkspacePath $Config.workspacePath)
                    Show-ProjectSearchResults -Projects $results
                }
                '3' { return }
                default {
                    ShowWarning 'Please choose 1, 2, or 3.'
                    Wait-ForKey -Message 'Press Enter to try again'
                    continue
                }
            }
        }
        elseif ($results.Count -eq 1 -and -not [string]::IsNullOrWhiteSpace($searchTerm) -and (Get-ProjectSearchRank -Name $results[0].Name -Query $searchTerm) -eq 0) {
            $project = $results[0]

            if (ShowYesNoPrompt -Prompt "Open $($project.Name)?" -YesLabel '[Y] Yes' -NoLabel '[N] Search again') {
                Open-WorkspaceProject -Project $project
                return
            }

            continue
        }
        else {
            Show-ProjectSearchResults -Projects $results
        }

        Write-Host 'Select a project:' -ForegroundColor DarkGray
        $choice = Read-Host 'Project number'

        if ($choice -match '^\d+$') {
            $index = [int]$choice - 1
            if ($index -ge 0 -and $index -lt $results.Count) {
                Open-WorkspaceProject -Project $results[$index]
                return
            }
        }

        ShowWarning 'Enter a valid project number from the list.'
        Wait-ForKey -Message 'Press Enter to try again'
    }
}
