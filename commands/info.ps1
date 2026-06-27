$query = $null

if ($script:DevToolsCommandArgs -and $script:DevToolsCommandArgs.Count -gt 0) {
    $query = ($script:DevToolsCommandArgs -join ' ').Trim()
}

Invoke-ProjectInfoFlow -ProjectQuery $query
