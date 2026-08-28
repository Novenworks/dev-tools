# DevTools — manage local GitHub workspaces on Windows

param(
    [Parameter(Position = 0)]
    [string]$Command = 'home',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CommandArgs
)

$script:DevToolsRoot = $PSScriptRoot
$DevToolsRoot = $script:DevToolsRoot
$script:DevToolsCommandArgs = @($CommandArgs)

. (Join-Path $DevToolsRoot 'lib\utils.ps1')
. (Join-Path $DevToolsRoot 'lib\copy.ps1')
. (Join-Path $DevToolsRoot 'lib\ui.ps1')
. (Join-Path $DevToolsRoot 'lib\config.ps1')
. (Join-Path $DevToolsRoot 'lib\git.ps1')
. (Join-Path $DevToolsRoot 'lib\github.ps1')
. (Join-Path $DevToolsRoot 'lib\backup-remotes.ps1')
. (Join-Path $DevToolsRoot 'lib\doctor.ps1')
. (Join-Path $DevToolsRoot 'lib\deploy-config.ps1')
. (Join-Path $DevToolsRoot 'lib\backup-setup.ps1')
. (Join-Path $DevToolsRoot 'lib\deploy-github.ps1')
. (Join-Path $DevToolsRoot 'lib\deploy-vercel.ps1')
. (Join-Path $DevToolsRoot 'lib\deploy-model.ps1')
. (Join-Path $DevToolsRoot 'lib\deploy-report.ps1')
. (Join-Path $DevToolsRoot 'lib\deploy.ps1')
. (Join-Path $DevToolsRoot 'lib\home.ps1')
. (Join-Path $DevToolsRoot 'lib\projects.ps1')
. (Join-Path $DevToolsRoot 'lib\recent.ps1')
. (Join-Path $DevToolsRoot 'lib\project-info.ps1')
. (Join-Path $DevToolsRoot 'lib\test.ps1')
. (Join-Path $DevToolsRoot 'lib\self.ps1')

$configSetup = Initialize-DevToolsConfig
$script:FirstRun = $configSetup.Created

try {
    $Config = Get-DevToolsConfig
}
catch {
    if ($script:FirstRun) {
        $Config = Get-DefaultDevToolsConfig
    }
    else {
        ShowError $_.Exception.Message
        ShowInfo 'Run: dev configure'
        exit 1
    }
}

$commandName = $Command.ToLower()

if ($script:FirstRun -and $commandName -notin @('self', 'test')) {
    . (Join-Path $DevToolsRoot 'commands\configure.ps1')
    $Config = Set-ScriptConfig
    $script:FirstRun = $false
    . (Join-Path $DevToolsRoot 'commands\home.ps1')
    exit 0
}

$commandFile = Join-Path $DevToolsRoot "commands\$commandName.ps1"

if (-not (Test-Path $commandFile)) {
    ShowError "Unknown command: $Command"
    ShowInfo 'Valid commands: home, menu, quick, recent, info, test, self, configure, settings, doctor, clone, update, status, backup, open, deploy, help'
    exit 1
}

if ($commandName -eq 'home' -and -not $script:FirstRun) {
    . (Join-Path $DevToolsRoot 'commands\home.ps1')
    exit 0
}

. $commandFile

if ($commandName -notin @('home', 'menu', 'configure', 'settings', 'quick', 'test', 'self', 'deploy', 'backup')) {
    Wait-ForKey
}
