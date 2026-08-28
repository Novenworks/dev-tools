#Requires -Version 5.1

<#
.SYNOPSIS
    Validates redundant-backup git remote helpers, URL construction, and config defaults.
.DESCRIPTION
    Git-backed tests use real throwaway local repositories (no network access —
    a local bare repo stands in for the "backup" remote). Run standalone or
    through tests/Test-DevTools.ps1.
#>

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:BackupTestFailed = $false
$script:BackupTestPassed = 0

function Write-BackupTestPass {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "PASS: $Message" -ForegroundColor Green
    $script:BackupTestPassed++
}

function Write-BackupTestFailure {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "FAIL: $Message" -ForegroundColor Red
    $script:BackupTestFailed = $true
}

function Assert-BackupTrue {
    param([bool]$Condition, [Parameter(Mandatory = $true)][string]$Label)

    if ($Condition) {
        Write-BackupTestPass $Label
        return
    }

    Write-BackupTestFailure $Label
}

function Assert-BackupEqual {
    param($Expected, $Actual, [Parameter(Mandatory = $true)][string]$Label)

    if ([string]$Expected -eq [string]$Actual) {
        Write-BackupTestPass $Label
        return
    }

    Write-BackupTestFailure "$Label (expected '$Expected' but got '$Actual')"
}

# ---------------------------------------------------------------------------
# Load redundant backup modules
# ---------------------------------------------------------------------------

$DevToolsRoot = $ProjectRoot
$script:DevToolsRoot = $ProjectRoot

. (Join-Path $ProjectRoot 'lib\utils.ps1')
. (Join-Path $ProjectRoot 'lib\ui.ps1')
. (Join-Path $ProjectRoot 'lib\config.ps1')
. (Join-Path $ProjectRoot 'lib\git.ps1')
. (Join-Path $ProjectRoot 'lib\deploy-config.ps1')
. (Join-Path $ProjectRoot 'lib\backup-remotes.ps1')
. (Join-Path $ProjectRoot 'lib\backup-setup.ps1')

# ---------------------------------------------------------------------------
# New-BackupRemoteUrl — pure string construction, no network/filesystem
# ---------------------------------------------------------------------------

Assert-BackupEqual 'git@gitlab.com:novenworks/dev-tools.git' `
    (New-BackupRemoteUrl -Provider gitlab -NamespaceOrWorkspace 'novenworks' -RepoName 'dev-tools' -Protocol ssh) `
    'GitLab SSH URL'

Assert-BackupEqual 'https://gitlab.com/novenworks/dev-tools.git' `
    (New-BackupRemoteUrl -Provider gitlab -NamespaceOrWorkspace 'novenworks' -RepoName 'dev-tools' -Protocol https) `
    'GitLab HTTPS URL'

Assert-BackupEqual 'git@gitlab.com:group/subgroup/dev-tools.git' `
    (New-BackupRemoteUrl -Provider gitlab -NamespaceOrWorkspace 'group/subgroup' -RepoName 'dev-tools' -Protocol ssh) `
    'GitLab SSH URL supports nested subgroups'

Assert-BackupEqual 'git@bitbucket.org:novenworks/dev-tools.git' `
    (New-BackupRemoteUrl -Provider bitbucket -NamespaceOrWorkspace 'novenworks' -RepoName 'dev-tools' -Protocol ssh) `
    'Bitbucket SSH URL'

Assert-BackupEqual 'https://bitbucket.org/novenworks/dev-tools.git' `
    (New-BackupRemoteUrl -Provider bitbucket -NamespaceOrWorkspace 'novenworks' -RepoName 'dev-tools' -Protocol https) `
    'Bitbucket HTTPS URL'

# ---------------------------------------------------------------------------
# Get-BackupConfig — safe defaults regardless of what config.json contains
# ---------------------------------------------------------------------------

$emptyBackupConfig = Get-BackupConfig -ConfigObject ([pscustomobject]@{})
Assert-BackupEqual '' $emptyBackupConfig.Provider 'Get-BackupConfig: absent section defaults to no provider'
Assert-BackupEqual 'backup' $emptyBackupConfig.RemoteName 'Get-BackupConfig: absent section defaults remote name to "backup"'
Assert-BackupEqual 'ssh' $emptyBackupConfig.Protocol 'Get-BackupConfig: absent section defaults protocol to ssh'

$nullBackupConfig = Get-BackupConfig -ConfigObject $null
Assert-BackupEqual '' $nullBackupConfig.Provider 'Get-BackupConfig: null config object does not throw'

$populatedSource = [pscustomobject]@{
    backup = [pscustomobject]@{
        provider             = 'GitLab'
        namespaceOrWorkspace = 'novenworks'
        protocol             = 'HTTPS'
        remoteName           = 'mirror'
    }
}
$populatedBackupConfig = Get-BackupConfig -ConfigObject $populatedSource
Assert-BackupEqual 'gitlab' $populatedBackupConfig.Provider 'Get-BackupConfig: provider is normalized to lowercase'
Assert-BackupEqual 'novenworks' $populatedBackupConfig.NamespaceOrWorkspace 'Get-BackupConfig: namespace passes through'
Assert-BackupEqual 'https' $populatedBackupConfig.Protocol 'Get-BackupConfig: protocol is normalized to lowercase'
Assert-BackupEqual 'mirror' $populatedBackupConfig.RemoteName 'Get-BackupConfig: custom remote name passes through'

# ---------------------------------------------------------------------------
# Git-backed tests: real throwaway local repositories, fully offline
# ---------------------------------------------------------------------------

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("devtools-backup-test-$([guid]::NewGuid())")
$repoPath = Join-Path $tempRoot 'repo'
$bareBackupPath = Join-Path $tempRoot 'bare-backup.git'
$bareOriginPath = Join-Path $tempRoot 'bare-origin.git'

New-Item -ItemType Directory -Force -Path $repoPath | Out-Null

try {
    git init --quiet $bareOriginPath --bare | Out-Null
    git init --quiet $bareBackupPath --bare | Out-Null

    Push-Location $repoPath
    try {
        git init --quiet -b main . | Out-Null
        git config user.email 'devtools-test@example.com' | Out-Null
        git config user.name 'DevTools Test' | Out-Null
        Set-Content -Path (Join-Path $repoPath 'README.md') -Value 'test'
        git add . | Out-Null
        git commit --quiet -m 'initial commit' | Out-Null
        git tag v0.0.1 | Out-Null
        git remote add origin $bareOriginPath | Out-Null
    }
    finally {
        Pop-Location
    }

    Assert-BackupTrue (Test-GitRemoteExists -RepoPath $repoPath -RemoteName 'origin') 'Test-GitRemoteExists: true for an existing remote'
    Assert-BackupTrue (-not (Test-GitRemoteExists -RepoPath $repoPath -RemoteName 'backup')) 'Test-GitRemoteExists: false for a remote that has not been added yet'

    $addResult = Add-GitRemote -RepoPath $repoPath -RemoteName 'backup' -Url $bareBackupPath
    Assert-BackupTrue $addResult 'Add-GitRemote: adding a new remote succeeds'
    Assert-BackupEqual $bareBackupPath (Get-GitRemoteUrl -RepoPath $repoPath -RemoteName 'backup') 'Get-GitRemoteUrl: round-trips the URL just added'

    $updateResult = Add-GitRemote -RepoPath $repoPath -RemoteName 'backup' -Url $bareBackupPath
    Assert-BackupTrue $updateResult 'Add-GitRemote: re-adding the same remote updates instead of failing'

    $originPush = Invoke-GitPushToRemote -RepoPath $repoPath -RemoteName 'origin' -Branch 'main'
    Assert-BackupTrue $originPush.Success 'Invoke-GitPushToRemote: first push to origin succeeds with -u'

    $backupPush = Invoke-GitBackupPush -RepoPath $repoPath -RemoteName 'backup'
    Assert-BackupTrue $backupPush.Success 'Invoke-GitBackupPush: pushes all branches and tags successfully'
    Assert-BackupTrue $backupPush.BranchesOk 'Invoke-GitBackupPush: branches push succeeds'
    Assert-BackupTrue $backupPush.TagsOk 'Invoke-GitBackupPush: tags push succeeds'

    Push-Location $bareBackupPath
    try {
        $backupTags = git tag
        Assert-BackupTrue ($backupTags -contains 'v0.0.1') 'Invoke-GitBackupPush: tag exists on the backup remote'
    }
    finally {
        Pop-Location
    }

    $missingRemotePush = Invoke-GitPushToRemote -RepoPath $repoPath -RemoteName 'backup' -Branch 'does-not-exist-locally'
    Assert-BackupTrue (-not $missingRemotePush.Success) 'Invoke-GitPushToRemote: pushing an unknown local branch fails without throwing'

    $detachedPush = Invoke-GitPushToRemote -RepoPath $repoPath -RemoteName 'origin' -Branch ''
    Assert-BackupTrue (-not $detachedPush.Success) 'Invoke-GitPushToRemote: empty branch (detached HEAD) is rejected without throwing'
    Assert-BackupEqual 'detached-head' $detachedPush.Reason 'Invoke-GitPushToRemote: detached HEAD reason is reported'

    Push-Location $repoPath
    try {
        git rm --cached --quiet backup 2>$null | Out-Null
    }
    catch {
        # ignore — not a real git command misuse path, just clearing state defensively
    }
    finally {
        Pop-Location
    }

    $summary = @(Get-WorkspaceBackupSummary -WorkspacePath $tempRoot -RemoteName 'backup')
    Assert-BackupTrue ($summary.Count -ge 1) 'Get-WorkspaceBackupSummary: finds the repo under the workspace path'
    $summaryRow = $summary | Where-Object { $_.Name -eq 'repo' } | Select-Object -First 1
    Assert-BackupTrue ($null -ne $summaryRow -and $summaryRow.HasBackup) 'Get-WorkspaceBackupSummary: reports HasBackup true when a backup remote exists'
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host 'Backup Test Summary' -ForegroundColor Cyan
Write-Host "Assertions passed: $($script:BackupTestPassed)"

if ($script:BackupTestFailed) {
    Write-Host 'Result: FAIL' -ForegroundColor Red
    exit 1
}

Write-Host 'Result: PASS' -ForegroundColor Green
exit 0
