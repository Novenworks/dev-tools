function New-DevRepoCommandError {
    param([int]$ExitCode, [string]$Code, [string]$Message)

    [pscustomobject]@{
        ExitCode = $ExitCode
        Error = [pscustomobject]@{ code = $Code; message = $Message }
    }
}

function Get-DevRepoAutomationResult {
    param(
        [string]$Name,
        [string[]]$Options
    )

    $result = [pscustomobject]@{
        ExitCode = 0
        Envelope = [ordered]@{
            schemaVersion = 1
            command = $Name
            timestamp = [DateTime]::UtcNow.ToString('o')
            success = $true
            data = $null
            warnings = @()
            errors = @()
        }
    }

    $errorResult = $null
    $dryRun = '--dry-run' -in $Options
    $unknown = @($Options | Where-Object { $_ -and $_ -notin @('--json', '--no-interactive', '--dry-run') })
    if ($unknown.Count -gt 0 -or ($dryRun -and $Name -ne 'sync')) {
        $errorResult = New-DevRepoCommandError 2 'invalid_arguments' 'Use the options documented for this command.'
    }
    elseif ($Name -eq 'sync' -and -not $dryRun) {
        $errorResult = New-DevRepoCommandError 7 'unsafe_operation' 'Use --dry-run for a preview or run sync interactively to approve changes.'
    }
    elseif ($Name -notin @('status', 'doctor', 'projects list', 'sync')) {
        $errorResult = New-DevRepoCommandError 2 'invalid_arguments' 'This command has no automation mode. Run devrepo help for available commands.'
    }
    else {
        $configExists = Test-DevToolsConfigFileExists
        try {
            if ($configExists) { $Config = Get-DevToolsConfig }
            elseif ($Name -eq 'doctor') { $Config = Get-DefaultDevToolsConfig }
            else {
                $errorResult = New-DevRepoCommandError 4 'configuration_failure' 'Run devrepo configure to set up your workspace.'
            }
        }
        catch {
            $errorResult = New-DevRepoCommandError 4 'configuration_failure' 'DevRepo could not read its settings. Review them with devrepo configure.'
        }

        if (-not $errorResult -and $Name -ne 'doctor') {
            if (-not (Test-Path -LiteralPath $Config.workspacePath -PathType Container)) {
                $errorResult = New-DevRepoCommandError 4 'configuration_failure' 'The configured workspace folder is unavailable.'
            }
            elseif ($Name -ne 'projects list' -and -not (Test-CommandExists 'git')) {
                $errorResult = New-DevRepoCommandError 5 'missing_dependency' 'Install Git or check that it is on PATH.'
            }
        }

        if (-not $errorResult) {
            try {
                switch ($Name) {
                    'doctor' {
                        $status = Get-DevToolsSystemStatus
                        $fields = @('Id', 'Label', 'Passed', 'Version', 'StatusText', 'SuggestedAction')
                        $result.Envelope.data = [ordered]@{
                            overallStatus = $status.OverallStatus
                            required = @($status.RequiredChecks | Select-Object -Property $fields)
                            optional = @($status.OptionalChecks | Select-Object -Property $fields)
                        }
                    }
                    'projects list' {
                        $projects = @(Get-WorkspaceProjects -WorkspacePath $Config.workspacePath)
                        $result.Envelope.data = [ordered]@{
                            workspace = $Config.workspacePath
                            count = $projects.Count
                            projects = @($projects | ForEach-Object {
                                [ordered]@{ name = $_.Name; path = $_.FullName; isGit = $_.IsGit }
                            })
                        }
                    }
                    default {
                        $states = @(Get-WorkspaceRepositoryStates -WorkspacePath $Config.workspacePath)
                        $result.Envelope.warnings = @('Repository data uses local tracking refs, which may be out of date.')
                        $result.Envelope.data = [ordered]@{
                            workspace = $Config.workspacePath
                            refreshed = $false
                            dryRun = $dryRun
                            summary = Get-RepositoryStateSummary -States $states
                            repositories = @($states | ForEach-Object {
                                $state = $_
                                $entry = [ordered]@{
                                    name = $state.Name
                                    path = $state.Path
                                    branch = $state.CurrentBranch
                                    healthCode = $state.HealthCode
                                    needsAttention = $state.NeedsAttention
                                    ahead = $state.Ahead
                                    behind = $state.Behind
                                }
                                if ($dryRun) {
                                    $entry['plannedAction'] = if ($state.CanFastForward) { 'fast_forward' } elseif ($state.IsHealthy) { 'current' } else { 'skip' }
                                }
                                $entry
                            })
                        }
                        if (@($states | Where-Object { $_.HealthCode -in @('InvalidRepository', 'OtherGitError') }).Count -gt 0) {
                            $errorResult = New-DevRepoCommandError 8 'partial_success' 'Some repositories could not be inspected. See their health codes in the results.'
                        }
                    }
                }
            }
            catch {
                $errorResult = New-DevRepoCommandError 9 'internal_error' 'DevRepo could not complete the requested check.'
            }
        }
    }

    if ($errorResult) {
        $result.ExitCode = $errorResult.ExitCode
        $result.Envelope.success = $false
        $result.Envelope.errors = @($errorResult.Error)
    }
    return $result
}

function Write-DevRepoAutomationResult {
    param($Envelope, [switch]$Json)

    if ($Json) {
        Write-Output (ConvertTo-Json -InputObject $Envelope -Depth 8 -Compress)
        return
    }

    foreach ($warning in $Envelope.warnings) { [Console]::Error.WriteLine("Warning: $warning") }
    foreach ($item in $Envelope.errors) { [Console]::Error.WriteLine($item.message) }
    if (-not $Envelope.data) { return }

    switch ($Envelope.command) {
        'doctor' {
            Write-Output $Envelope.data.overallStatus
            foreach ($check in ($Envelope.data.required + $Envelope.data.optional)) {
                Write-Output ("{0}  {1}" -f $check.Label, $check.StatusText)
            }
        }
        'projects list' {
            Write-Output ("{0} project folders" -f $Envelope.data.count)
            foreach ($project in $Envelope.data.projects) { Write-Output $project.name }
        }
        default {
            $summary = $Envelope.data.summary
            Write-Output ("{0} Git projects, {1} healthy, {2} need attention" -f $summary.Total, $summary.Healthy, $summary.NeedsAttention)
            foreach ($repo in $Envelope.data.repositories) {
                $detail = if ($Envelope.data.dryRun) { "$($repo.plannedAction) ($($repo.healthCode))" } else { $repo.healthCode }
                Write-Output ("{0}  {1}" -f $repo.name, $detail)
            }
        }
    }
}
