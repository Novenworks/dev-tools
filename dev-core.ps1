# DevRepo by Novenworks

param(
    [Parameter(Position = 0)]
    [string]$Command = 'home',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CommandArgs
)

$script:DevToolsRoot = $PSScriptRoot
$DevToolsRoot = $script:DevToolsRoot

. (Join-Path $DevToolsRoot 'lib\utils.ps1')
. (Join-Path $DevToolsRoot 'lib\copy.ps1')
. (Join-Path $DevToolsRoot 'lib\ui.ps1')
. (Join-Path $DevToolsRoot 'lib\config.ps1')
. (Join-Path $DevToolsRoot 'lib\git.ps1')
. (Join-Path $DevToolsRoot 'lib\repo-git.ps1')
. (Join-Path $DevToolsRoot 'lib\repo-parallel.ps1')
. (Join-Path $DevToolsRoot 'lib\repo-state.ps1')
. (Join-Path $DevToolsRoot 'lib\repo-sync.ps1')
. (Join-Path $DevToolsRoot 'lib\repo-repair.ps1')
. (Join-Path $DevToolsRoot 'lib\repo-report.ps1')
. (Join-Path $DevToolsRoot 'lib\github.ps1')
. (Join-Path $DevToolsRoot 'lib\doctor.ps1')
. (Join-Path $DevToolsRoot 'lib\deploy-config.ps1')
. (Join-Path $DevToolsRoot 'lib\deploy-github.ps1')
. (Join-Path $DevToolsRoot 'lib\deploy-vercel.ps1')
. (Join-Path $DevToolsRoot 'lib\deploy-model.ps1')
. (Join-Path $DevToolsRoot 'lib\deploy-report.ps1')
. (Join-Path $DevToolsRoot 'lib\deploy.ps1')
. (Join-Path $DevToolsRoot 'lib\home.ps1')
. (Join-Path $DevToolsRoot 'lib\projects.ps1')
. (Join-Path $DevToolsRoot 'lib\recent.ps1')
. (Join-Path $DevToolsRoot 'lib\project-info.ps1')
. (Join-Path $DevToolsRoot 'lib\repo-ui.ps1')
. (Join-Path $DevToolsRoot 'lib\test.ps1')
. (Join-Path $DevToolsRoot 'lib\self.ps1')
. (Join-Path $DevToolsRoot 'lib/automation.ps1')

if ($Command -eq 'home' -and $CommandArgs.Count -eq 1 -and $CommandArgs[0] -in @('--help', '-h')) {
    $Command = 'help'
}

$commandFiles = @{
    home = 'home'; menu = 'menu'; quick = 'quick'; recent = 'recent'
    info = 'info'; repos = 'repos'; test = 'test'; self = 'self'
    configure = 'configure'; settings = 'settings'; doctor = 'doctor'
    clone = 'clone'; sync = 'sync'; update = 'sync'; status = 'status'
    backup = 'backup'; open = 'open'; deploy = 'deploy'; help = 'help'
    '--help' = 'help'; '-h' = 'help'
}

$listedProjects = $false
if ($CommandArgs.Count -gt 0) {
    $subcommand = $CommandArgs[0]
    if ($Command -eq 'projects' -and $subcommand -in @('list', 'open', 'info')) {
        $listedProjects = $subcommand -eq 'list'
        $Command = if ($listedProjects) { 'projects list' } else { $subcommand }
        $CommandArgs = @($CommandArgs | Select-Object -Skip 1)
    }
    elseif ($Command -eq 'repos' -and $subcommand -in @('status', 'sync', 'clone')) {
        $Command = $subcommand
        $CommandArgs = @($CommandArgs | Select-Object -Skip 1)
    }
}

$script:DevToolsCommandArgs = @($CommandArgs)
$json = '--json' -in $CommandArgs
if ($listedProjects -or $json -or '--no-interactive' -in $CommandArgs -or '--dry-run' -in $CommandArgs) {
    $name = if ($Command -and $commandFiles.ContainsKey($Command)) { $commandFiles[$Command] } else { $Command }
    $result = Get-DevRepoAutomationResult -Name $name -Options $CommandArgs
    Write-DevRepoAutomationResult -Envelope $result.Envelope -Json:$json
    exit $result.ExitCode
}

if (-not $Command -or -not $commandFiles.ContainsKey($Command)) {
    ShowError "Unknown command: $Command"
    ShowInfo 'Run devrepo help for available commands.'
    exit 1
}

$commandName = $commandFiles[$Command]
$script:FirstRun = -not (Test-DevToolsConfigFileExists)
try {
    $Config = if ($script:FirstRun -or $commandName -eq 'help') {
        Get-DefaultDevToolsConfig
    }
    else {
        Get-DevToolsConfig
    }
}
catch {
    if ($commandName -ne 'configure') {
        ShowError $_.Exception.Message
        ShowInfo 'Run devrepo configure to review your settings.'
        exit 1
    }
    $Config = Get-DefaultDevToolsConfig
}

if ($script:FirstRun -and $commandName -in @('home', 'menu', 'quick', 'configure', 'settings')) {
    . (Join-Path $DevToolsRoot 'commands/configure.ps1')
    if ($script:FirstRun -or $commandName -in @('configure', 'settings')) { exit 0 }
}
elseif ($script:FirstRun -and $commandName -in @('clone', 'sync', 'backup', 'deploy')) {
    ShowWarning 'Set up your workspace before making changes.'
    ShowInfo 'Run devrepo configure, then retry the command.'
    exit 1
}

. (Join-Path $DevToolsRoot "commands/$commandName.ps1")

if ($commandName -notin @('home', 'menu', 'configure', 'settings', 'quick', 'test', 'self', 'deploy', 'status', 'repos', 'help')) {
    Wait-ForKey
}
