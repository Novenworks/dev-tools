# DevTools

Manage your local development workspace from one place.

Clone repositories.  
Update projects.  
Check your development environment.  
Open projects instantly.

Built by Novenworks.

---

## Overview

DevTools is a beginner-friendly Windows PowerShell utility for managing multiple local GitHub projects from one menu.

It helps you set up your workspace, clone repositories, check your development environment, keep hundreds of repositories healthy and safely synchronized, open project folders, and back up changes.

It was built for developers, freelancers, students, and builders who work across multiple repositories and want less friction in their daily workflow.

DevTools is an open-source project by Novenworks. The goal is simple: help developers spend less time managing projects and more time building.

---

## Screenshots

Screenshots coming soon.

Recommended screenshots:

- Home Dashboard
- Doctor
- Configure Wizard
- Repository Health
- Open Project
- Settings

---

## Features

- **Guided setup wizard** — Configure your workspace in a few guided steps
- **Home dashboard** — System Status, collapsed checklist, and recent projects when available
- **Development environment check** — Doctor finds missing tools and guides fixes
- **GitHub repository cloning** — Download repositories from your GitHub owners
- **Smart repository sync** — Refresh GitHub state and fast-forward only the repositories that are safe to update
- **Repository health** — See exactly which repositories need attention across hundreds of projects, with filters
- **Actionable classifications** — Local changes, ahead, diverged, missing upstream, detached HEAD, conflicts, and remote failures instead of "could not update"
- **Guided upstream repair** — Recover branches whose remote branch was deleted after a merged pull request
- **Safe branch cleanup** — Delete stale local branches only when Git can prove they are fully merged
- **Diagnostic reports** — Export repository health as JSON and as pasteable Markdown
- **Safe backup workflow** — Review changes and confirm before committing or pushing
- **Project launcher** — Open a project in your preferred editor
- **Quick Actions** — Fast path for sync, open, health, and clone
- **Recent Projects** — Jump back into projects you open most often
- **Project Info** — Inspect Git status, stack, and quick actions
- **Project search** — Find projects by partial name in large workspaces
- **Deployment Manager** — Audit many GitHub repositories against Vercel, preview missing deployments, and onboard them safely (optional)
- **Settings menu** — Update preferences one at a time
- **Beginner-friendly help** — Plain-language guidance built into the CLI
- **Automated validation** — CI and local test script (`dev test`) for syntax and project structure
- **Global install** — Type `dev` from any PowerShell window after installation
- **`dev self`** — Test, inspect, and safely update DevTools itself

---

## Who It Is For

DevTools is useful for:

- Developers managing multiple repositories
- Freelancers working across client projects
- Agency builders
- Students learning Git and GitHub
- Indie hackers
- AI-assisted developers using Cursor, Claude, or similar tools
- Anyone who wants a simpler local project workflow

---

## Requirements

**Required**

- Windows
- PowerShell
- [Git](https://git-scm.com/download/win)
- [GitHub CLI](https://cli.github.com/)
- A GitHub account

**Optional**

These tools are not required to get started, but DevTools can detect and work with them:

- **Cursor** or **VS Code** — Open projects in your editor
- **Node.js** and **npm** — Useful for JavaScript and web projects
- **Claude Desktop** and **Claude Code** — Optional AI development tools

Run **Doctor** to see what is installed and what is missing.

---

## Installation

Install DevTools in three steps:

```powershell
git clone https://github.com/Novenworks/dev-tools.git
cd dev-tools
powershell -ExecutionPolicy Bypass -File install.ps1
```

Close and reopen PowerShell, then run:

```powershell
dev
```

The installer adds DevTools to your **user PATH** only (no admin required) and creates `config.json` on first run.

Close and reopen PowerShell after installation so the updated PATH takes effect.

### Why `dev.cmd`?

The global `dev` command resolves to `dev.cmd`, not a root-level `dev.ps1`. The CMD launcher runs PowerShell with `-NoProfile` and `-ExecutionPolicy Bypass`, so you should not see execution policy errors after installation.

The real PowerShell entrypoint is `dev-core.ps1`. Do not run it directly as your daily workflow; use `dev` or `.\dev.cmd`.

### Run locally without installing

From a cloned folder:

```powershell
.\dev.cmd
```

### Alternative: `dev self install`

If DevTools is already on your PATH from a previous session:

```powershell
.\dev.cmd self install
```

See [docs/installation.md](docs/installation.md) for uninstall steps, PATH troubleshooting (`dev self path`), and conflict detection.

---

## First-Time Setup

1. Launch DevTools
2. Run **Configure**
3. Choose your workspace folder
4. Add GitHub owners (usernames or organizations)
5. Choose your default editor
6. Run **Doctor** and sign in to GitHub if needed
7. **Clone** your repositories
8. **Open** a project and start building

Most users never need to edit `config.json` manually.

---

## Quick Start

```powershell
.\dev.cmd
```

```powershell
.\dev.cmd doctor
```

```powershell
.\dev.cmd configure
```

```powershell
.\dev.cmd clone
```

```powershell
.\dev.cmd status
```

```powershell
.\dev.cmd open
```

```powershell
.\dev.cmd quick
```

```powershell
.\dev.cmd recent
```

```powershell
.\dev.cmd info walkreplay
```

If DevTools is on your PATH after running `install.ps1`, you can use `dev` instead of `.\dev.cmd`.

---

## Commands

| Command | What it does | Example |
| --- | --- | --- |
| `home` | Open the Home dashboard (default) | `dev home` |
| `menu` | Open the main menu | `dev menu` |
| `quick` | Open Quick Actions for frequent tasks | `dev quick` |
| `configure` | Run the guided setup wizard | `dev configure` |
| `settings` | Change preferences one at a time | `dev settings` |
| `doctor` | Check your development environment | `dev doctor` |
| `clone` | Download missing GitHub repositories | `dev clone` |
| `sync` | Refresh GitHub state and safely fast-forward repositories | `dev sync` |
| `update` | Alias for `sync`, kept for existing scripts | `dev update` |
| `status` | Repository health across the workspace | `dev status` |
| `repos` | Repository maintenance: sync, health, repair, cleanup, reports | `dev repos` |
| `backup` | Review changed repos and back up safely | `dev backup` |
| `open` | Open a project in your default editor | `dev open` or `dev open walkreplay` |
| `recent` | Open a recently used project | `dev recent` |
| `info` | Inspect project details and quick actions | `dev info walkreplay` |
| `help` | Show beginner-friendly help | `dev help` |
| `test` | Run automated validation (works from any directory) | `dev test` |
| `self` | Manage DevTools itself (test, update, version, doctor, info, PATH) | `dev self` |
| `deploy` | Deployment Manager for Vercel (optional) | `dev deploy audit` |

**Backup safety:** Backup shows repositories with changes and asks for confirmation before committing or pushing. Nothing is committed or pushed without your approval.

### Repository Intelligence

`dev sync` fetches, classifies, and then updates only what is safe:

```text
* Updated: MyProject (4 commits)
. Current: AnotherProject
! Skipped: OldDemo - local changes
! Skipped: AgentBranch - origin/claude/rebuild-homepage no longer exists
```

Bulk sync is **fast-forward only**. DevTools never stashes, resets, force-pulls, merges diverged
histories, commits, pushes, or deletes unmerged branches on your behalf. When it is not certain a
repository is safe to update, it skips it and explains why.

`dev status` opens Repository Health, which answers "what in my workspace needs attention?" and lets
you filter to just the modified, behind, ahead, diverged, broken-upstream, or blocked repositories
instead of scrolling past hundreds of clean ones.

`dev repos` adds guided upstream repair, safe merged-branch cleanup, single-repository actions, and
diagnostic report export. See [docs/commands.md](docs/commands.md#repository-intelligence).

### Deployment Manager

Compare your GitHub repositories against Vercel and onboard the ones that are missing.

| Command | Changes anything? | What it does |
| --- | --- | --- |
| `dev deploy` | No | Interactive Deployment Manager |
| `dev deploy audit` | **No** | Compare every eligible repository against Vercel |
| `dev deploy plan` | **No** | Show exactly what `sync` would create |
| `dev deploy sync` | **Yes** | Create missing projects after you approve |
| `dev deploy verify` | **No** | Check that production deployments are healthy |
| `dev deploy status` | **No** | Show deployment settings and readiness |

Vercel is optional. DevTools stays fully usable — and `dev doctor` stays green — without it.

```powershell
$env:VERCEL_TOKEN = "your-token"
dev deploy audit
```

DevTools never stores your Vercel token in `config.json`, a report, or a log. See [docs/deployments.md](docs/deployments.md).

---

## Quick Actions

Quick Actions are for the tasks you run most often:

- Open a recent project
- Search and open a project
- View repository health
- Sync repositories
- Clone missing repositories
- Open Repository Maintenance

Launch from Home (when ready), the Main Menu, or directly:

```powershell
.\dev.cmd quick
```

After each action, DevTools returns you to Quick Actions unless you choose Main Menu or Exit.

---

## Project Search

When opening a project, you can search by partial name. This helps when you have many folders in your workspace.

Example:

```
Search: walk

Results:
  1  WalkReplay [git]
  2  Walk-Replay-App [git]
```

Press Enter without typing to list all projects. Git repositories are marked with `[git]`. Other folders show as `[folder]`.

Run:

```powershell
.\dev.cmd open
```

---

## Recent Projects

DevTools remembers the projects you open most often so you can get back to work quickly.

```powershell
.\dev.cmd recent
```

On Home, recently opened projects appear when available. Press **O** to open one quickly.

Recent data is stored locally in `config/recent-projects.json` and is not committed to Git.

---

## Project Info

Inspect a project without leaving DevTools — location, Git status, branch, remote, last commit, inferred stack, and quick actions.

```powershell
.\dev.cmd info
```

```powershell
.\dev.cmd info walkreplay
```

Stack detection is inferred from common project files (for example `package.json`, `next.config.js`, `supabase/`).

Detailed command docs: [docs/commands.md](docs/commands.md)

---

## Home Dashboard

When all required checks pass, Home shows **Ready to Build** and *Everything required is ready.*

If you have opened projects before, a **Recent Projects** list appears. Press **O** to open one quickly.

Status icons use emoji in modern terminals (Windows Terminal, VS Code) and ASCII fallbacks (`*`, `-`, `x`, `o`) elsewhere. Set `DEVTOOLS_ASCII=1` to force ASCII.

---

## Configuration

DevTools stores settings in `config.json` in the project folder. This file is created automatically on first run.

Most users should use **Configure** or **Settings** instead of editing `config.json` directly.

| Setting | Description |
| --- | --- |
| `workspacePath` | Folder where your repositories live |
| `githubOwners` | GitHub users or organizations to clone from |
| `defaultEditor` | Editor used by Open Project |
| `autoBackupMessage` | Prefix for backup commit messages |
| `autoUpdate` | Reserved for future use |
| `deployments` | Deployment Manager settings (optional — see [docs/deployments.md](docs/deployments.md)) |

Example:

```json
{
  "workspacePath": "C:\\Projects",
  "githubOwners": ["your-github-username-or-org"],
  "defaultEditor": "cursor",
  "autoBackupMessage": "Auto backup",
  "autoUpdate": false
}
```

---

## Typical Daily Workflow

1. Open DevTools
2. Check **Home**
3. **Update** repositories
4. **Open** a project
5. Build
6. Check **Status**
7. **Backup** changes when ready

---

## Safety Notes

- DevTools does **not** delete repositories
- **Backup** asks before committing or pushing
- **Clone** skips folders that already exist
- **Sync is fast-forward only** — no stash, no reset, no force, no merge of diverged histories, no automatic commit or push
- **Unsafe repositories are skipped and explained**, never modified
- **Branch cleanup never force-deletes** and never removes a branch Git cannot prove is merged
- **Upstream repair never deletes a branch** and refuses to switch when unmerged commits exist
- **Repository reports are sanitized** — credentials embedded in remote URLs are stripped before anything is written to disk
- `config.json` is local and ignored by Git
- **Deployment audit, plan, verify, and status change nothing** — only `dev deploy sync` can create Vercel projects, and it always asks first
- Healthy Vercel projects are never modified, renamed, redeployed, or disconnected
- Your Vercel token is read from `VERCEL_TOKEN` only, and is never stored, logged, or printed
- Generated deployment reports stay in the gitignored `reports/` folder

---

## Roadmap

DevTools uses GitHub Issues, labels, and milestones to track future work.

**Current planned milestones:**

- **v0.4.0** — Developer Command Center
- **v0.5.0** — Repository Intelligence (current release)
- **v0.5.x** — Stabilization
- **v1.0** — Stable Public Release

See [docs/roadmap.md](docs/roadmap.md) for details.

See [`.github/milestones.md`](.github/milestones.md) and [`.github/labels.md`](.github/labels.md) for planning details.

**Future ideas:** plugin system, cross-platform support, AI-assisted project summaries, dev server launch support.

---

## Testing

DevTools uses a lightweight manual smoke test before every GitHub release.

See [docs/testing/smoke-test.md](docs/testing/smoke-test.md) for the current release checklist.

---

## Automated Checks

DevTools runs GitHub Actions on pushes and pull requests.

The current CI checks:

- PowerShell syntax
- Required project files and command scripts
- Example configuration validity
- Home status focal with empty attention items (automated smoke)

**Optional:** [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) adds extra PowerShell lint checks during `dev test`. Automated tests pass without it. To enable linting:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

After the test summary, the runner also prints a **Development Environment** section listing required tools (Git, GitHub CLI) and optional tools (PSScriptAnalyzer, PowerShell 7, Node.js) with ASCII status markers.

Manual smoke testing is still used before releases. See [docs/testing/smoke-test.md](docs/testing/smoke-test.md).

Run the same checks locally from **any directory**:

```powershell
dev test
dev self test
```

Or invoke the test script directly from the DevTools folder:

```powershell
pwsh ./tests/Test-DevTools.ps1
```

---

## Contributing

Issues and feature requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

For now:

1. Open an issue (use a template if available)
2. Describe the problem
3. Suggest the expected behavior
4. Submit a pull request if you want to help

Repository: [github.com/Novenworks/dev-tools](https://github.com/Novenworks/dev-tools)

---

## Troubleshooting

### Git not recognized

Install Git from [git-scm.com](https://git-scm.com/download/win), restart your terminal, then run:

```powershell
dev doctor
```

### Vercel authentication required

Deployment Manager reads your token from the environment:

```powershell
$env:VERCEL_TOKEN = "your-token"
```

A session variable is cleared when you close the terminal. See [docs/deployments.md](docs/deployments.md) for team setup and persistence trade-offs.

### GitHub CLI not authenticated

Sign in through Doctor or Home, or run:

```powershell
gh auth login
```

Then run Doctor again to verify.

### PowerShell blocks scripts

Use the launcher script:

```powershell
.\dev.cmd
```

### Node.js not detected after install

Restart PowerShell so your PATH updates, then run:

```powershell
dev doctor
```

### Cursor command not found

Install Cursor and ensure the `cursor` command is available in your PATH, or choose a different editor in **Settings**.

### Status icons look wrong on Home

DevTools falls back to ASCII symbols on older consoles. Use Windows Terminal or VS Code, or set:

```powershell
$env:DEVTOOLS_FORCE_UNICODE = '1'
```

To always use ASCII:

```powershell
$env:DEVTOOLS_ASCII = '1'
```

---

## FAQ

**What does DevTools do?**  
DevTools helps you manage a local GitHub workspace from one menu — setup, cloning, safe repository sync, repository health, backup, and opening projects.

**Is this only for Novenworks?**  
No. DevTools is open source. You configure your own workspace path and GitHub owners.

**Does it work with private repositories?**  
Yes, as long as you are signed in to GitHub CLI with access to those repositories.

**Does it replace GitHub Desktop?**  
No. DevTools focuses on workspace management from the command line. GitHub Desktop is still a good choice if you prefer a graphical Git client.

**Does it work on macOS or Linux?**  
Not yet. DevTools is built for Windows today. Cross-platform support is on the long-term roadmap.

**Is backup safe?**  
Yes. Backup shows what changed and asks for confirmation before committing or pushing.

**Do I need Node.js?**  
No. Node.js is optional. Doctor will tell you if it is missing.

---

## License

MIT — see [LICENSE](LICENSE).

---

## GitHub Topics

Suggested GitHub topics:

`powershell` `git` `github` `developer-tools` `cli` `automation` `windows` `productivity` `cursor` `open-source`

---

## Release Notes

See [CHANGELOG.md](CHANGELOG.md) for full release history.

**v0.5.0 — Repository Intelligence** adds smart repository sync, Repository Health with filters, guided upstream repair, safe merged-branch cleanup, single-repository actions, and diagnostic report export — all built on one shared repository state model.
