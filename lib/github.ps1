function Test-RequireGh {
    if (-not (Test-CommandExists 'gh')) {
        ShowError 'GitHub CLI is not installed yet. Run Doctor to install or set it up.'
        return $false
    }

    return $true
}

function Test-GhAuthenticated {
    if (-not (Test-CommandExists 'gh')) {
        return $false
    }

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        $null = gh auth status 2>&1 | Out-Null
        return $LASTEXITCODE -eq 0
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
}

function Get-GithubReposForOwner {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner
    )

    $output = gh repo list $Owner --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner' 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not list repositories for $Owner. Sign in to GitHub from Doctor and try again."
    }

    if ([string]::IsNullOrWhiteSpace($output)) {
        return @()
    }

    return @($output -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
