# Sync Repositories — fetch, classify, and safely fast-forward.
# `dev update` routes here so existing scripts keep working.

ShowCommandScreen -Heading 'Sync Repositories' -Description @(
    'Refresh GitHub state and safely update repositories that can be fast-forwarded'
    'without touching local work.'
    'DevTools never stashes, resets, force-pulls, merges, or pushes for you.'
)

Invoke-RepositorySyncFlow -SkipHeader | Out-Null
