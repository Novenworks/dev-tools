# Deployment Manager

Find every website you have on GitHub, compare it with Vercel, and fix what is missing — without opening 200 repositories and 50 Vercel projects by hand.

Deployment Manager is **optional**. DevTools works fully without it, and `dev doctor` stays green whether or not Vercel is connected.

---

## What it does

```text
GitHub repositories
        |
   discover eligible repositories
        |
   inspect deployability
        |
   compare against Vercel projects
        |
   classify every candidate
        |
   preview proposed actions   (dev deploy plan)
        |
   apply with your approval   (dev deploy sync)
        |
   verify production          (dev deploy verify)
```

Once a repository is connected through Vercel's Git integration, future merges to the production branch deploy automatically. DevTools handles **discovery, onboarding, auditing, and verification** — not repeated redeployment of healthy sites.

---

## Commands

| Command | Changes anything? | What it does |
| --- | --- | --- |
| `dev deploy` | No (menu) | Interactive Deployment Manager |
| `dev deploy audit` | **No** | Compare every eligible repository against Vercel |
| `dev deploy plan` | **No** | Show exactly what `sync` would create |
| `dev deploy sync` | **Yes** | Create missing projects and start first deployments, after you approve |
| `dev deploy verify` | **No** | Check that production deployments are healthy |
| `dev deploy status` | **No** | Show deployment settings and readiness |
| `dev deploy help` | **No** | Command help |

### Options

| Option | Applies to | Meaning |
| --- | --- | --- |
| `--apply` | `sync` | Skip the interactive confirmation. **This creates real Vercel projects and deployments.** |
| `--owner NAME` | all | Audit one GitHub owner instead of every configured owner |
| `--no-http` | `verify` | Skip the production URL health check |

`dev deploy sync --apply` exists for automation. Use it only when you have already reviewed `dev deploy plan`.

---

## First run

```powershell
# 1. See the current state. Nothing is changed.
dev deploy audit

# 2. See exactly what would be created. Nothing is changed.
dev deploy plan

# 3. Approve and apply.
dev deploy sync

# 4. Confirm production is healthy. Nothing is changed.
dev deploy verify
```

---

## Connecting Vercel

DevTools reads your Vercel token from an environment variable. **It is never stored in `config.json`, never written to a report, and never printed.**

```powershell
# Current PowerShell session only
$env:VERCEL_TOKEN = "your-token"
dev deploy audit
```

Create a token at <https://vercel.com/account/tokens>.

### Team accounts

If your projects live in a Vercel team, set the team once in `config.json`:

```json
{
  "deployments": {
    "vercelTeam": "your-team-slug"
  }
}
```

A team **slug** is not a secret, so storing it is safe. `VERCEL_TEAM_ID` in the environment overrides it when set.

### Persisting the token

Persisting `VERCEL_TOKEN` to your user environment means any program running as you can read it. It is a credential with write access to your Vercel account — treat it like a password, scope it as narrowly as Vercel allows, and rotate it if it may have been exposed.

```powershell
# Persist for your user account (understand the risk above first)
[Environment]::SetEnvironmentVariable('VERCEL_TOKEN', 'your-token', 'User')
```

Never put the token in a script, a tracked file, or a commit.

---

## Which repositories are considered?

Deployment Manager is conservative by default. A repository becomes a **candidate** only when it matches your rules.

Rules apply in this order — the first match wins:

1. `excludeRepositories` — always skipped
2. `includeRepositories` — always a candidate (overrides archived, fork, and template)
3. Archived repository — skipped unless `includeArchived` is on
4. Template repository — skipped
5. Fork — skipped unless `includeForks` is on
6. `includeNamePatterns` — a candidate (default: `*demo*`, case-insensitive)
7. Everything else — skipped

Repository names are matched against both `Repo-Name` and `Owner/Repo-Name`.

---

## Is it actually a website?

Before proposing anything, DevTools inspects the repository's root **remotely through GitHub** — no cloning required.

Recognized indicators include `package.json`, `next.config.*`, `vite.config.*`, `astro.config.*`, `svelte.config.*`, `nuxt.config.*`, `vercel.json`, `index.html`, and `src/`, `app/`, `pages/`, `public/` folders.

Detected frameworks: Next.js, Nuxt, Astro, SvelteKit, Vite, React, Vue, Static HTML, or Other.

A README-only repository, an empty repository, or a repository with no web application is classified `NOT_DEPLOYABLE` and is never proposed for creation.

---

## How repositories are matched to Vercel projects

Matching is deliberately careful. A wrong match could attach your repository to somebody else's live site.

Priority order:

1. **Vercel Git integration metadata** — the project is linked to `owner/repo`. Definitive.
2. **Explicit mapping** in `projectMappings`.
3. **A single, unambiguous normalized name match.**
4. Anything else → `AMBIGUOUS_MATCH`, reported for you to resolve.

Name normalization lowercases, replaces spaces/underscores/dots with hyphens, collapses repeats, and trims:

```text
Amazing-Head-Spa-Demo  ->  amazing-head-spa-demo
TIA_Medspa_Demo        ->  tia-medspa-demo
```

### Ambiguity example

```text
GitHub:  Novenworks/Good-Quality-HVAC-Demo

Vercel:  good-quality-hvac-demo
         good-quality-hvac-demo-8lrn
```

DevTools reports `AMBIGUOUS_MATCH` and does nothing. It will not pick one, will not create a third project, and will not modify either. Resolve it by adding a `projectMappings` entry, or by connecting the correct project to GitHub in Vercel.

Definitive Git-integration matches are resolved first across the whole portfolio, so a project that clearly belongs to one repository is never claimed by another through a name-only match.

---

## Statuses

| Status | Meaning |
| --- | --- |
| `READY` | Already deployed and healthy. No action needed. |
| `MISSING_VERCEL_PROJECT` | Not on Vercel yet. `sync` can create it. |
| `NO_PRODUCTION_DEPLOYMENT` | Project exists but has never deployed to production. |
| `DEPLOYMENT_FAILED` | The last production deployment failed or was canceled. |
| `DEPLOYMENT_BUILDING` | A production deployment is still building. |
| `GIT_NOT_CONNECTED` | The Vercel project has no connected Git repository. |
| `PRODUCTION_BRANCH_MISMATCH` | Vercel deploys from a different branch than expected. |
| `NOT_DEPLOYABLE` | No deployable web application detected. |
| `SKIPPED` | Skipped by the eligibility rules. |
| `AMBIGUOUS_MATCH` | More than one Vercel project could belong to this repository. |
| `AUTH_REQUIRED` | Vercel authentication is needed before this can be checked. |
| `UNKNOWN` | DevTools could not determine the state. |

---

## What sync will and will not do

**Sync will:**

- Create a Vercel project for a deployable repository that has none
- Connect it to the correct GitHub repository through Git integration
- Set the production branch to the repository's real default branch (or your override)
- Start the first production deployment if Vercel did not start one already
- Wait for `READY`, `ERROR`, `CANCELED`, or the timeout
- Continue to the next repository when one fails

**Sync will never:**

- Modify, rename, redeploy, or delete a healthy project
- Replace domains or aliases
- Read, write, or copy environment variables
- Change build settings or framework settings
- Disconnect or reconnect GitHub on an existing project
- Retry a failed build automatically — a failed build is reported for you to investigate
- Act on an ambiguous match
- Change anything in your GitHub repositories or local workspace

### Idempotency

Running `dev deploy sync` twice does not create duplicates. On the second run the newly created project matches through Git integration, audits as `READY`, and no action is taken.

---

## Reports

Every operation writes a machine-readable report:

```text
reports/deployments/latest.json
```

`reports/` is gitignored. Reports contain no tokens, no authorization headers, and no repository contents.

```json
{
  "generatedAt": "2026-08-19T12:00:00Z",
  "operation": "audit",
  "githubOwners": ["Novenworks"],
  "repositoriesDiscovered": 211,
  "summary": { "READY": 44, "MISSING_VERCEL_PROJECT": 11 },
  "repositories": [
    {
      "githubOwner": "Novenworks",
      "githubRepo": "Dream-Med-Spa-Demo",
      "defaultBranch": "main",
      "eligible": true,
      "framework": "Next.js",
      "vercelProjectName": "dream-med-spa-demo",
      "matchMethod": "GitIntegration",
      "productionUrl": "https://dream-med-spa-demo.vercel.app",
      "deploymentState": "READY",
      "status": "READY"
    }
  ]
}
```

The read-only `audit` is safe to run unattended — for example from a scheduled task — because it can never modify anything.

---

## Configuration

See [configuration.md](configuration.md) for every deployment setting.

Minimal example:

```json
{
  "deployments": {
    "provider": "vercel",
    "vercelTeam": "your-team-slug",
    "repositoryFilters": {
      "includeNamePatterns": ["*demo*"],
      "includeRepositories": ["Client-Site-Without-Demo-In-Name"],
      "excludeRepositories": ["Owner/internal-tooling"]
    },
    "productionBranchOverrides": {
      "Owner/Legacy-Site": "master"
    },
    "projectMappings": {
      "Owner/Good-Quality-HVAC-Demo": "good-quality-hvac-demo"
    }
  }
}
```

Configuration files written before Deployment Manager shipped keep working. Every missing field falls back to a safe default.

---

## Troubleshooting

### `Vercel: AUTH REQUIRED`

`VERCEL_TOKEN` is not set in this PowerShell session. Set it and run the command again. Opening a new terminal clears a session-only variable.

### `Vercel team 'x' was not found`

Check the team slug in `config.json`, and confirm your token has access to that team.

### `AMBIGUOUS_MATCH`

Two or more Vercel projects could belong to one repository. Add a `projectMappings` entry, or connect the correct project to GitHub inside Vercel so the definitive Git-integration match applies.

### `PRODUCTION_BRANCH_MISMATCH`

Vercel deploys production from a different branch than the repository default. Either change it in Vercel, or add a `productionBranchOverrides` entry so DevTools expects that branch.

### `DEPLOYMENT_FAILED`

The build failed on Vercel. DevTools does not retry it — open the project in Vercel and read the build log. Re-running the same commit would fail the same way.

### GitHub API rate limit

The audit records the failure for that repository, keeps going, and shows a warning. Wait a few minutes and run the audit again.

### The audit is slow on a large organization

Each candidate repository needs one or two GitHub API calls. Narrow `includeNamePatterns`, or audit one owner at a time with `dev deploy audit --owner NAME`.

---

## See also

- [Command reference](commands.md)
- [Configuration](configuration.md)
- [Testing](testing.md)
