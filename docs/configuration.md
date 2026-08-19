# DevTools Configuration

DevTools stores settings in `config.json` at the installation root. This file is local and gitignored.

On first run, DevTools creates `config.json` from `config.example.json`.

---

## Settings

| Key | Description | Example |
| --- | --- | --- |
| `workspacePath` | Root folder for your projects | `C:\\Projects` |
| `githubOwners` | GitHub usernames or orgs to clone from | `["Novenworks"]` |
| `defaultEditor` | Editor command for Open Project | `cursor`, `code`, `explorer` |
| `autoBackupMessage` | Default commit message for backup | `Auto backup` |
| `autoUpdate` | Reserved for future auto-update behavior | `false` |
| `deployments` | Deployment Manager settings (optional) | see below |

---

## Deployment settings

The `deployments` section is optional. Configuration files written before Deployment Manager shipped keep working — every missing field falls back to a safe default.

```json
{
  "deployments": {
    "provider": "vercel",
    "vercelTeam": "your-team-slug",
    "repositoryFilters": {
      "includeNamePatterns": ["*demo*"],
      "includeRepositories": [],
      "excludeRepositories": [],
      "includeForks": false,
      "includeArchived": false
    },
    "productionBranchOverrides": {},
    "projectMappings": {},
    "httpHealthCheck": true,
    "deploymentTimeoutSeconds": 600,
    "pollIntervalSeconds": 10,
    "maxRepositoriesPerOwner": 1000
  }
}
```

| Key | Description | Default |
| --- | --- | --- |
| `provider` | Deployment provider | `vercel` |
| `vercelTeam` | Vercel team slug or id. A slug is not a secret. | `""` (personal account) |
| `repositoryFilters.includeNamePatterns` | Wildcard patterns that make a repository a candidate | `["*demo*"]` |
| `repositoryFilters.includeRepositories` | Always a candidate, even if archived, a fork, or a template | `[]` |
| `repositoryFilters.excludeRepositories` | Never a candidate. Wins over every other rule. | `[]` |
| `repositoryFilters.includeForks` | Consider forks | `false` |
| `repositoryFilters.includeArchived` | Consider archived repositories | `false` |
| `productionBranchOverrides` | Per-repository production branch, keyed by `Repo` or `Owner/Repo` | `{}` |
| `projectMappings` | Explicit repository to Vercel project mapping | `{}` |
| `httpHealthCheck` | Run one lightweight HTTP check during `dev deploy verify` | `true` |
| `deploymentTimeoutSeconds` | How long sync waits for a deployment | `600` |
| `pollIntervalSeconds` | How often sync checks deployment state | `10` |
| `maxRepositoriesPerOwner` | Upper bound when enumerating an owner | `1000` |

Repository names in the filter lists match either `Repo-Name` or `Owner/Repo-Name`, case-insensitively.

### Vercel token

Your Vercel token is **never** stored in `config.json`. DevTools reads it from the `VERCEL_TOKEN` environment variable only, and never writes it to a log or report.

```powershell
$env:VERCEL_TOKEN = "your-token"
```

`VERCEL_TEAM_ID` overrides `vercelTeam` when set.

See [deployments.md](deployments.md) for the full guide.

---

## Local data

| File | Purpose |
| --- | --- |
| `config/recent-projects.json` | Recent Projects history (not committed) |
| `reports/deployments/latest.json` | Latest deployment report (not committed) |

---

## Changing settings

Prefer the guided menus:

```powershell
dev configure    # Full setup wizard
dev settings     # Change one setting at a time
```

Manual editing of `config.json` is supported but rarely needed.

---

## See also

- [Installation](installation.md)
- [Command reference](commands.md)
- [Deployment Manager](deployments.md)
