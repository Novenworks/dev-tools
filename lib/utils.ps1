function Get-CommandPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        return $null
    }

    return $command.Source
}

function Test-CommandExists {
    <#
    .SYNOPSIS
        Returns true when a command is available on PATH.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-ToolVersionLine {
    <#
    .SYNOPSIS
        Returns the first line of a tool's version output, or null when unavailable.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [string[]]$ArgumentList = @('--version')
    )

    if (-not (Test-CommandExists $Command)) {
        return $null
    }

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    try {
        $output = & $Command @ArgumentList 2>$null | Select-Object -First 1
        if (-not $output) {
            return $null
        }

        return ($output.ToString().Trim())
    }
    catch {
        return $null
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
}

function Get-ToolVersionNumber {
    <#
    .SYNOPSIS
        Extracts a version number from common CLI version output.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [string[]]$ArgumentList = @('--version')
    )

    $line = Get-ToolVersionLine -Command $Command -ArgumentList $ArgumentList
    if (-not $line) {
        return $null
    }

    if ($line -match '(\d+(?:\.\d+)+)') {
        return $Matches[1]
    }

    return $line
}

function Test-ClaudeDesktopInstalled {
    <#
    .SYNOPSIS
        Checks common Claude Desktop install locations on Windows.
    #>
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Claude\Claude.exe'),
        (Join-Path $env:ProgramFiles 'Claude\Claude.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Claude\Claude.exe')
    )

    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) {
            return $true
        }
    }

    return $false
}

function Resolve-EditorChoice {
    <#
    .SYNOPSIS
        Maps a wizard selection to a defaultEditor command name.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Choice
    )

    switch ($Choice.Trim()) {
        '1' { return 'cursor' }
        '2' { return 'code' }
        '3' { return 'explorer' }
        '4' { return 'claude' }
        'cursor' { return 'cursor' }
        'code' { return 'code' }
        'explorer' { return 'explorer' }
        'claude' { return 'claude' }
        default { return $Choice.Trim().ToLower() }
    }
}

function Get-EditorDisplayName {
    <#
    .SYNOPSIS
        Returns a friendly label for a configured editor command.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Editor
    )

    switch ($Editor.ToLower()) {
        'cursor' { return 'Cursor' }
        'code' { return 'VS Code' }
        'explorer' { return 'Explorer' }
        'claude' { return 'Claude Code' }
        default { return $Editor }
    }
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Invoke-QuietCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter()]
        [string[]]$ArgumentList = @()
    )

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    try {
        & $FilePath @ArgumentList
        return $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
}

function Read-SettingValue {
    <#
    .SYNOPSIS
        Prompts for a setting with current value and Enter-to-keep behavior.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [string]$CurrentValue,

        [string]$Hint = 'Or type a new value:'
    )

    Write-Host $Label -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Current' -ForegroundColor DarkGray
    Write-Host "  $CurrentValue" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Press Enter to keep.' -ForegroundColor DarkGray
    Write-Host $Hint -ForegroundColor DarkGray
    Write-Host ''

    $input = Read-Host $Label
    if ([string]::IsNullOrWhiteSpace($input)) {
        return $CurrentValue
    }

    return $input.Trim()
}

function Read-EditorSetting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentEditor
    )

    Write-Host 'Default Editor' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Current' -ForegroundColor DarkGray
    Write-Host "  $(Get-EditorDisplayName -Editor $CurrentEditor)" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Press Enter to keep.' -ForegroundColor DarkGray
    Write-Host 'Or choose a new editor:' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  1  Cursor'
    Write-Host '  2  VS Code'
    Write-Host '  3  Explorer'
    Write-Host '  4  Claude Code (if available)'
    Write-Host ''

    $choice = Read-Host 'Default Editor'
    if ([string]::IsNullOrWhiteSpace($choice)) {
        return $CurrentEditor
    }

    return (Resolve-EditorChoice -Choice $choice)
}

function Read-ConfigValue {
    <#
    .SYNOPSIS
        Prompts for a value and uses the current value when Enter is pressed.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [string]$CurrentValue
    )

    $display = if ($CurrentValue) { " [$CurrentValue]" } else { '' }
    $input = Read-Host "$Prompt$display"

    if ([string]::IsNullOrWhiteSpace($input)) {
        return $CurrentValue
    }

    return $input.Trim()
}

function Read-YesNo {
    <#
    .SYNOPSIS
        Prompts for a yes/no answer.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [bool]$Default = $false
    )

    $hint = if ($Default) { '(Y/n)' } else { '(y/N)' }
    $answer = Read-Host "$Prompt $hint"

    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $Default
    }

    return $answer -match '^[Yy]$'
}
