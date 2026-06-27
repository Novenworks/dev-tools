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

It helps you set up your workspace, clone repositories, check your development environment, update projects, open project folders, and safely back up changes.

It was built for developers, freelancers, students, and builders who work across multiple repositories and want less friction in their daily workflow.

DevTools is an open-source project by Novenworks. The goal is simple: help developers spend less time managing projects and more time building.

---

## Screenshots

Screenshots coming soon.

Recommended screenshots:

- Home Dashboard
- Doctor
- Configure Wizard
- Repository Status
- Open Project
- Settings

---

## Features

- **Guided setup wizard** — Configure your workspace in a few guided steps
- **Home dashboard** — System Status, collapsed checklist, and recent projects when available
- **Development environment check** — Doctor finds missing tools and guides fixes
- **GitHub repository cloning** — Download repositories from your GitHub owners
- **Multi-repository updates** — Pull the latest changes across your workspace
- **Repository status overview** — Review clean, modified, ahead, behind, and conflict states
- **Safe backup workflow** — Review changes and confirm before committing or pushing
- **Project launcher** — Open a project in your preferred editor
- **Quick Actions** — Fast path for update, open, status, and clone
- **Recent Projects** — Jump back into projects you open most often
- **Project Info** — Inspect Git status, stack, and quick actions
- **Project search** — Find projects by partial name in large workspaces
- **Settings menu** — Update preferences one at a time
- **Beginner-friendly help** — Plain-language guidance built into the CLI
- **Automated validation** — CI and local test script for syntax and project structure

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

### Clone and run

```powershell
git clone https://github.com/Novenworks/dev-tools.git C:\Projects\dev-tools
cd C:\Projects\dev-tools
.\dev.cmd
```

### If PowerShell blocks scripts

Use `dev.cmd`, which is the recommended way to launch DevTools because it avoids common PowerShell execution policy friction:

```powershell
.\dev.cmd
```

Or run the entry script directly:

```powershell
powershell -ExecutionPolicy Bypass -File ".\dev.ps1"
```

### Global install (recommended)

From the DevTools folder, add it to your **user PATH** (no admin required):

```powershell
.\dev.cmd self install
```

Close and reopen PowerShell, then run:

```powershell
dev
```

See [docs/installation.md](docs/installation.md) for details, uninstall steps, and PATH troubleshooting.

### Legacy: install.ps1

After cloning, you can also run:

```powershell
.\install.ps1
```

This adds DevTools to your user PATH and creates `config.json` on first run. Prefer `dev self install` for the integrated workflow.

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
| `update` | Pull latest changes in existing repos | `dev update` |
| `status` | Show repository status across the workspace | `dev status` |
| `backup` | Review changed repos and back up safely | `dev backup` |
| `open` | Open a project in your default editor | `dev open` or `dev open walkreplay` |
| `recent` | Open a recently used project | `dev recent` |
| `info` | Inspect project details and quick actions | `dev info walkreplay` |
| `help` | Show beginner-friendly help | `dev help` |
| `test` | Run automated validation (works from any directory) | `dev test` |
| `self` | Manage global PATH install | `dev self install` |

**Backup safety:** Backup shows repositories with changes and asks for confirmation before committing or pushing. Nothing is committed or pushed without your approval.

---

## Quick Actions

Quick Actions are for the tasks you run most often:

- Open a recent project
- Search and open a project
- View repository status
- Update repositories
- Clone missing repositories

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
- **Update** runs `git pull` inside existing repositories
- `config.json` is local and ignored by Git

---

## Roadmap

DevTools uses GitHub Issues, labels, and milestones to track future work.

**Current planned milestones:**

- **v0.3.1** — Stability
- **v0.4** — Quality of Life
- **v0.5** — Power User Features
- **v1.0** — Stable Public Release

See [`.github/ISSUES_TO_CREATE.md`](.github/ISSUES_TO_CREATE.md) for the initial roadmap issue list.

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

Manual smoke testing is still used before releases. See [docs/testing/smoke-test.md](docs/testing/smoke-test.md).

Run the same checks locally from **any directory**:

```powershell
dev test
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
DevTools helps you manage a local GitHub workspace from one menu — setup, cloning, updates, status, backup, and opening projects.

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

## v0.3.0 Release Notes Draft

DevTools v0.3.0 is the first public release of DevTools, an open-source developer utility for managing local GitHub workspaces.

**Highlights**

- Guided setup
- Home dashboard
- Doctor environment check
- GitHub repository cloning
- Multi-repository update workflow
- Repository status view
- Safe backup workflow
- Project launcher
- Beginner-friendly Help and Settings
