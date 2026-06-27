# DevTools install script for Windows

$ErrorActionPreference = 'Stop'
$InstallRoot = $PSScriptRoot

. (Join-Path $InstallRoot 'lib\utils.ps1')
. (Join-Path $InstallRoot 'lib\copy.ps1')
. (Join-Path $InstallRoot 'lib\ui.ps1')
. (Join-Path $InstallRoot 'lib\self.ps1')

$exitCode = Invoke-DevToolsInstallScript -Root $InstallRoot
exit $exitCode
