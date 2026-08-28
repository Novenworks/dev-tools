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
| `backup` | Secondary backup remote settings (optional) | see below |

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

## Backup settings

GitHub (`origin`) is always DevTools' primary remote. The `backup` section is optional and lets you configure **one** secondary remote — GitLab or Bitbucket — that `dev backup` pushes to in addition to GitHub. Configuration files written before this shipped keep working: the section is optional and every missing field falls back to a safe default (no secondary remote configured).

```json
{
  "backup": {
    "provider": "",
    "namespaceOrWorkspace": "",
    "protocol": "ssh",
    "remoteName": "backup"
  }
}
```

| Key | Description | Default |
| --- | --- | --- |
| `provider` | Secondary provider: `gitlab`, `bitbucket`, or `""` for none | `""` |
| `namespaceOrWorkspace` | GitLab namespace/group, or Bitbucket workspace slug. Not a secret — just a path segment. | `""` |
| `protocol` | `ssh` or `https` — which URL DevTools builds when adding the remote | `ssh` |
| `remoteName` | The git remote name DevTools looks for and pushes to | `backup` |

Run `dev backup setup` to fill this in interactively; run `dev backup status` to see which repositories currently have a `remoteName` remote configured.

### No credentials are ever stored

DevTools never stores a GitLab or Bitbucket token, password, or app password anywhere — not in `config.json`, not in a constructed URL. The `backup` remote's URL lives only in each repository's own `.git/config`, exactly like `origin` does. Authentication for pushes to it relies entirely on whatever you already use for git: an SSH key/agent, or Git Credential Manager for HTTPS.

`dev backup setup` also does not create the destination repository — it only wires the local git remote. Create an empty repository with the same name on GitLab or Bitbucket first; setup shows you the exact URL it expects before adding the remote.

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
