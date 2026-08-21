# dev deploy — Deployment Manager.
#
# audit, plan, verify, and status are read-only. Only sync can change anything,
# and only after an explicit confirmation (or the deliberate --apply flag).

$deployArgs = @($script:DevToolsCommandArgs)
$deploySubCommand = ''
$deployApply = $false
$deploySkipHttp = $false
$deployOwners = @()

for ($i = 0; $i -lt $deployArgs.Count; $i++) {
    $argument = [string]$deployArgs[$i]
    if ([string]::IsNullOrWhiteSpace($argument)) { continue }

    switch -Regex ($argument) {
        '^--(apply|yes)$' { $deployApply = $true; break }
        '^--no-http$' { $deploySkipHttp = $true; break }
        '^--owner=' { $deployOwners += $argument.Substring(8); break }
        '^--owner$' {
            if ($i + 1 -lt $deployArgs.Count) {
                $i++
                $deployOwners += [string]$deployArgs[$i]
            }

            break
        }
        '^-' { ShowWarning "Unknown option: $argument"; break }
        default {
            if ([string]::IsNullOrWhiteSpace($deploySubCommand)) {
                $deploySubCommand = $argument.ToLower()
            }
        }
    }
}

switch ($deploySubCommand) {
    'audit' {
        $exitCode = Invoke-DeploymentAuditCommand -ConfigObject $Config -OwnerOverride $deployOwners
        Wait-ForKey
        exit $exitCode
    }
    'plan' {
        $exitCode = Invoke-DeploymentPlanCommand -ConfigObject $Config -OwnerOverride $deployOwners
        Wait-ForKey
        exit $exitCode
    }
    'sync' {
        $exitCode = Invoke-DeploymentSyncCommand -ConfigObject $Config -OwnerOverride $deployOwners -Apply:$deployApply
        if (-not $deployApply) { Wait-ForKey }
        exit $exitCode
    }
    'verify' {
        $exitCode = Invoke-DeploymentVerifyCommand -ConfigObject $Config -OwnerOverride $deployOwners -SkipHttp:$deploySkipHttp
        Wait-ForKey
        exit $exitCode
    }
    'status' {
        $exitCode = Invoke-DeploymentStatusCommand -ConfigObject $Config
        Wait-ForKey
        exit $exitCode
    }
    'settings' {
        $exitCode = Invoke-DeploymentStatusCommand -ConfigObject $Config
        Wait-ForKey
        exit $exitCode
    }
    'help' {
        $exitCode = Show-DeploymentHelp
        Wait-ForKey
        exit $exitCode
    }
    '' {
        $exitCode = Invoke-DeploymentManagerMenu -ConfigObject $Config
        exit $exitCode
    }
    default {
        ShowError "Unknown deploy command: $deploySubCommand"
        Write-Host ''
        Show-DeploymentHelp | Out-Null
        Wait-ForKey
        exit 1
    }
}
