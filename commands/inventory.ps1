# Workspace inventory: read-only by default.
# Usage: dev inventory [--export]
# Does not fetch, pull, commit, push, or modify project files.

$workspace = [string]$Config.workspacePath
if (-not (Test-Path -LiteralPath $workspace -PathType Container)) {
    ShowWarning "Workspace not found: $workspace"
    return
}

$export = @($script:DevToolsCommandArgs) -contains '--export'
$unknown = @($script:DevToolsCommandArgs | Where-Object { $_ -ne '--export' })
if ($unknown.Count -gt 0) {
    ShowWarning 'Usage: dev inventory [--export]'
    return
}

$items = @()
foreach ($folder in @(Get-ChildItem -LiteralPath $workspace -Directory -Force -ErrorAction SilentlyContinue | Sort-Object Name)) {
    $gitMarker = Join-Path $folder.FullName '.git'
    $item = [ordered]@{
        name = $folder.Name
        kind = 'folder'
        branch = $null
        remote = $null
        upstream = $null
        dirty = $null
        ahead = $null
        behind = $null
        note = $null
    }
    if (Test-Path -LiteralPath $gitMarker) {
        $item.kind = 'git'
        $branch = & git -C $folder.FullName symbolic-ref --quiet --short HEAD 2>$null
        if ($LASTEXITCODE -eq 0) { $item.branch = ($branch | Select-Object -First 1) }
        else { $item.note = 'Detached HEAD or unavailable branch' }

        $remote = & git -C $folder.FullName remote 2>$null
        if ($LASTEXITCODE -eq 0 -and @($remote).Count -gt 0) {
            $item.remote = @($remote)[0]
        } else {
            $item.note = 'No Git remote'
        }

        $porcelain = & git -C $folder.FullName status --porcelain --untracked-files=normal 2>$null
        if ($LASTEXITCODE -eq 0) {
            $item.dirty = @($porcelain).Count -gt 0
        } else {
            $item.note = 'Could not read Git status'
        }

        $upstream = & git -C $folder.FullName rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>$null
        if ($LASTEXITCODE -eq 0) {
            $item.upstream = ($upstream | Select-Object -First 1)
            $counts = & git -C $folder.FullName rev-list --left-right --count 'HEAD...@{upstream}' 2>$null
            if ($LASTEXITCODE -eq 0 -and ($counts -join ' ') -match '^\s*(\d+)\s+(\d+)\s*$') {
                $item.ahead = [int]$Matches[1]
                $item.behind = [int]$Matches[2]
            } else {
                $item.note = 'Could not compare local tracking refs'
            }
        } elseif (-not $item.note) {
            $item.note = 'No local upstream tracking ref'
        }
    }
    $items += [pscustomobject]$item
}

Write-Host ''
Write-Host ("Workspace inventory: {0}" -f $workspace) -ForegroundColor Cyan
Write-Host 'Local Git refs only. Remote state may be stale; no network requests made.'
Write-Host ''
foreach ($item in $items) {
    if ($item.kind -eq 'folder') {
        Write-Host ("[folder] {0} - not a Git repository" -f $item.name)
    } else {
        $change = if ($null -eq $item.dirty) { 'unknown changes' } elseif ($item.dirty) { 'local changes' } else { 'clean' }
        $ahead = if ($null -eq $item.ahead) { '?' } else { $item.ahead }
        $behind = if ($null -eq $item.behind) { '?' } else { $item.behind }
        Write-Host ("[git] {0} | {1} | ahead {2}, behind {3} | {4}" -f $item.name, $change, $ahead, $behind, $item.note)
    }
}
Write-Host ''
Write-Host ("Projects: {0} | Git: {1} | Local folders: {2}" -f $items.Count, @($items | Where-Object kind -eq 'git').Count, @($items | Where-Object kind -eq 'folder').Count)

if ($export) {
    $reports = Join-Path $DevToolsRoot 'reports\workspace'
    if (-not (Test-Path -LiteralPath $reports)) { New-Item -ItemType Directory -Path $reports -Force | Out-Null }
    $destination = Join-Path $reports 'inventory.json'
    $payload = [ordered]@{
        schemaVersion = 1
        generatedAtUtc = [DateTime]::UtcNow.ToString('o')
        computerName = $env:COMPUTERNAME
        workspacePath = $workspace
        note = 'Local Git refs only. This report is not a remote refresh or cross-device comparison.'
        projects = @($items)
    }
    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $destination -Encoding UTF8
    Write-Host ("Exported: {0}" -f $destination) -ForegroundColor Green
    Write-Host 'Review the report before sharing: project names and paths may be sensitive.'
} else {
    Write-Host 'Run dev inventory --export to save a JSON report.'
}
