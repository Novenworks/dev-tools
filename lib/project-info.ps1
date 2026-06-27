function Invoke-ProjectGitCommand {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [Parameter(Mandatory = $true)][string[]]$GitArgs
    )

    Push-Location $ProjectPath
    try {
        $output = & git @GitArgs 2>$null
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output | Out-String).Trim()
        }
    }
    finally {
        Pop-Location
    }
}

function ConvertTo-GitHubWebUrl {
    param(
        [Parameter(Mandatory = $true)][string]$RemoteUrl
    )

    if ([string]::IsNullOrWhiteSpace($RemoteUrl)) {
        return $null
    }

    $url = $RemoteUrl.Trim()

    if ($url -match '^git@github\.com:(.+?)(?:\.git)?$') {
        return "https://github.com/$($Matches[1])"
    }

    if ($url -match '^https?://github\.com/(.+?)(?:\.git)?/?$') {
        return "https://github.com/$($Matches[1])"
    }

    return $null
}

function Get-ProjectGitMetadata {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath
    )

    if (-not (Test-ProjectIsGitRepo -Path $ProjectPath)) {
        return [pscustomobject]@{
            IsGit              = $false
            StatusText         = 'Not a Git repository'
            Branch             = '—'
            Remote             = '—'
            LastCommitMessage  = '—'
            LastCommitRelative = '—'
            LastPullRelative   = '—'
            GitHubUrl          = $null
        }
    }

    $statusResult = Invoke-ProjectGitCommand -ProjectPath $ProjectPath -GitArgs @('status', '--porcelain')
    $isClean = [string]::IsNullOrWhiteSpace($statusResult.Output)
    $statusText = if ($isClean) { 'Clean' } else { 'Modified' }

    $branchResult = Invoke-ProjectGitCommand -ProjectPath $ProjectPath -GitArgs @('branch', '--show-current')
    $branch = if ($branchResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($branchResult.Output)) {
        $branchResult.Output
    }
    else {
        '(unknown)'
    }

    $remoteResult = Invoke-ProjectGitCommand -ProjectPath $ProjectPath -GitArgs @('remote', 'get-url', 'origin')
    $remote = if ($remoteResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($remoteResult.Output)) {
        $remoteResult.Output
    }
    else {
        '—'
    }

    $commitResult = Invoke-ProjectGitCommand -ProjectPath $ProjectPath -GitArgs @('log', '-1', '--format=%s|%cr')
    $commitMessage = '—'
    $commitRelative = '—'

    if ($commitResult.ExitCode -eq 0 -and $commitResult.Output -match '\|') {
        $parts = $commitResult.Output -split '\|', 2
        $commitMessage = $parts[0]
        $commitRelative = $parts[1]
    }

    $pullRelative = '—'
    $pullResult = Invoke-ProjectGitCommand -ProjectPath $ProjectPath -GitArgs @('reflog', '--grep-reflog=pull', '-1', '--format=%cr')

    if ($pullResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($pullResult.Output)) {
        $pullRelative = $pullResult.Output
    }

    $githubUrl = $null
    if ($remote -ne '—') {
        $githubUrl = ConvertTo-GitHubWebUrl -RemoteUrl $remote
    }

    return [pscustomobject]@{
        IsGit              = $true
        StatusText         = $statusText
        Branch             = $branch
        Remote             = $remote
        LastCommitMessage  = $commitMessage
        LastCommitRelative = $commitRelative
        LastPullRelative   = $pullRelative
        GitHubUrl          = $githubUrl
    }
}

function Get-ProjectStackTags {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath
    )

    $tags = @()

    if (Test-Path (Join-Path $ProjectPath 'package.json')) {
        $tags += 'Node.js / JavaScript project'
    }

    if ((Test-Path (Join-Path $ProjectPath 'next.config.js')) -or (Test-Path (Join-Path $ProjectPath 'next.config.mjs')) -or (Test-Path (Join-Path $ProjectPath 'next.config.ts'))) {
        $tags += 'Next.js'
    }

    if ((Test-Path (Join-Path $ProjectPath 'vite.config.js')) -or (Test-Path (Join-Path $ProjectPath 'vite.config.ts'))) {
        $tags += 'Vite'
    }

    if ((Test-Path (Join-Path $ProjectPath 'tailwind.config.js')) -or (Test-Path (Join-Path $ProjectPath 'tailwind.config.ts'))) {
        $tags += 'Tailwind CSS'
    }

    if (Test-Path (Join-Path $ProjectPath 'tsconfig.json')) {
        $tags += 'TypeScript'
    }

    if ((Test-Path (Join-Path $ProjectPath 'requirements.txt')) -or (Test-Path (Join-Path $ProjectPath 'pyproject.toml'))) {
        $tags += 'Python'
    }

    if ((Test-Path (Join-Path $ProjectPath 'supabase')) -or (Test-Path (Join-Path $ProjectPath 'supabase\config.toml'))) {
        $tags += 'Supabase'
    }

    if (Test-Path (Join-Path $ProjectPath 'vercel.json')) {
        $tags += 'Vercel'
    }

    if (Test-Path (Join-Path $ProjectPath '.env.example')) {
        $tags += 'Environment variables template'
    }

    if ($tags.Count -eq 0) {
        return @('No stack detected from project files')
    }

    return $tags
}

function Show-ProjectInfoBlock {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$GitInfo,
        [Parameter(Mandatory = $true)][array]$StackTags
    )

    Write-Host $Project.Name -ForegroundColor Cyan
    Write-Host ''

    Write-Host 'Location' -ForegroundColor Cyan
    Write-Host "  $($Project.FullName)" -ForegroundColor DarkGray
    Write-Host ''

    Write-Host 'Git' -ForegroundColor Cyan
    Write-Host "  $($GitInfo.StatusText)" -ForegroundColor DarkGray

    if ($GitInfo.IsGit) {
        Write-Host ''
        Write-Host 'Branch' -ForegroundColor Cyan
        Write-Host "  $($GitInfo.Branch)" -ForegroundColor DarkGray
        Write-Host ''
        Write-Host 'Remote' -ForegroundColor Cyan
        Write-Host "  $($GitInfo.Remote)" -ForegroundColor DarkGray
        Write-Host ''
        Write-Host 'Last Commit' -ForegroundColor Cyan
        Write-Host "  $($GitInfo.LastCommitMessage)" -ForegroundColor DarkGray
        Write-Host "  $($GitInfo.LastCommitRelative)" -ForegroundColor DarkGray
        Write-Host ''
        Write-Host 'Last Pull' -ForegroundColor Cyan
        Write-Host "  $($GitInfo.LastPullRelative)" -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Host 'Stack' -ForegroundColor Cyan
    ShowInfo 'Inferred from project files.'

    foreach ($tag in $StackTags) {
        Write-Host "  $tag" -ForegroundColor DarkGray
    }

    Write-Host ''
}

function Invoke-ProjectInfoActions {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$GitInfo
    )

    while ($true) {
        Write-Host 'Actions' -ForegroundColor Cyan
        Write-Host ''
        Write-Host "  1  Open in $(Get-EditorDisplayName -Editor $Config.defaultEditor)"
        Write-Host '  2  Open in Explorer'
        Write-Host '  3  Open GitHub Repository'
        Write-Host '  4  Repository Status'
        Write-Host '  5  Back'
        Write-Host ''

        $choice = Read-Host 'Choose an option'

        switch ($choice) {
            '1' {
                Open-ProjectWithEditor -Project $Project
                return
            }
            '2' {
                ShowInfo "Opening $($Project.Name) in Explorer..."
                explorer $Project.FullName
                return
            }
            '3' {
                if ($GitInfo.GitHubUrl) {
                    ShowInfo 'Opening GitHub repository in your browser...'
                    Start-Process $GitInfo.GitHubUrl
                }
                else {
                    ShowWarning 'No GitHub remote URL was found for this project.'
                    Wait-ForKey -Message 'Press Enter to continue'
                }
            }
            '4' {
                if (-not $GitInfo.IsGit) {
                    ShowInfo 'This folder is not a Git repository.'
                    Wait-ForKey -Message 'Press Enter to continue'
                    continue
                }

                $details = Get-RepoStatusDetails -RepoPath $Project.FullName
                Write-Host ''
                Write-Host 'Repository Status' -ForegroundColor Cyan
                Write-Host "  Branch: $($details.Branch)" -ForegroundColor DarkGray
                Write-Host "  Status: $($details.DisplayStatus)" -ForegroundColor DarkGray
                Wait-ForKey -Message 'Press Enter to continue'
            }
            '5' { return }
            default {
                ShowWarning 'Please choose a number from the menu.'
                Wait-ForKey -Message 'Press Enter to try again'
            }
        }
    }
}

function Invoke-ProjectInfoFlow {
    param(
        [string]$ProjectQuery = ''
    )

    $project = $null

    if (-not [string]::IsNullOrWhiteSpace($ProjectQuery)) {
        $resolved = Resolve-ProjectFromQuery -Query $ProjectQuery

        if ($resolved.Error -eq 'workspace') {
            ShowWarning 'Your workspace folder is not set up yet.'
            ShowInfo 'Next step: run Configure first.'
            return
        }

        $results = @($resolved.Projects)

        if ($results.Count -eq 0) {
            ShowWarning "No projects found for `"$ProjectQuery`"."
            return
        }

        if ($results.Count -eq 1) {
            $project = $results[0]
        }
        else {
            ShowCommandScreen -Heading 'Project Info' -Description @(
                'Multiple projects matched.'
                'Choose the project you want to inspect.'
            )
            $project = Select-ProjectFromResults -Results $results -Prompt 'Select a project:'
            if (-not $project) {
                return
            }
        }
    }
    else {
        $project = Select-Project -Heading 'Project Info' -Description @(
            'Which project do you want info for?'
            'Search by project name, or press Enter to list all projects.'
        )

        if (-not $project) {
            return
        }
    }

    $gitInfo = Get-ProjectGitMetadata -ProjectPath $project.FullName
    $stackTags = @(Get-ProjectStackTags -ProjectPath $project.FullName)

    ShowCommandScreen -Heading 'Project Info' -Description @(
        'Quick project summary without leaving DevTools.'
    )

    Show-ProjectInfoBlock -Project $project -GitInfo $gitInfo -StackTags $stackTags
    Invoke-ProjectInfoActions -Project $project -GitInfo $gitInfo
}
