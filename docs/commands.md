# DevTools Commands

Detailed command reference for DevTools.

For a quick overview, see the [README](../README.md).

---

## Command index

| Command | Description |
| --- | --- |
| `dev` | Home dashboard (default) |
| `dev home` | Home dashboard |
| `dev menu` | Main menu |
| `dev quick` | Quick Actions |
| `dev recent` | Open a recent project |
| `dev info` | Inspect a project |
| `dev open` | Search and open a project |
| `dev doctor` | Development environment check |
| `dev test` | Automated validation suite |
| `dev self` | DevTools self-management menu |
| `dev self test` | Same as `dev test` |
| `dev self update` | Safely pull DevTools updates |
| `dev self version` | Show DevTools version |
| `dev self doctor` | Diagnose DevTools installation |
| `dev self info` | Show install and Git details |
| `dev self install` | Add DevTools to user PATH |
| `dev self uninstall` | Remove DevTools from user PATH |
| `dev self path` | PATH and launcher diagnostics |
| `dev configure` | Guided setup wizard |
| `dev settings` | Change preferences |
| `dev clone` | Clone missing repositories |
| `dev update` | Pull latest changes |
| `dev status` | Repository status overview |
| `dev backup` | Safe backup workflow |
| `dev deploy` | Deployment Manager (Vercel) |
| `dev deploy audit` | Compare GitHub repositories against Vercel (read-only) |
| `dev deploy plan` | Preview exactly what sync would create (read-only) |
| `dev deploy sync` | Create missing Vercel projects after confirmation |
| `dev deploy verify` | Check production deployments (read-only) |
| `dev deploy status` | Show deployment settings and readiness (read-only) |
| `dev deploy help` | Deployment Manager help |
| `dev help` | Beginner-friendly help |

Commands under **`dev self`** manage DevTools itself. They do not replace `dev doctor`, which checks your general development environment.

---

## Core navigation

| Command | Description |
| --- | --- |
| `dev` / `dev home` | Home dashboard (default) |
| `dev menu` | Main menu |
| `dev quick` | Quick Actions for frequent tasks |
| `dev help` | Beginner-friendly help |

### Quick Actions

Menu options:

1. Open Recent Project  
2. Open Project Search  
3. Repository Status  
4. Update Repositories  
5. Clone Missing Repositories  
6. Main Menu  
7. Exit  

Returns to Quick Actions after each action unless you choose Main Menu or Exit.

### Main Menu

Includes Home, Quick Actions, Recent Projects, Project Info, Doctor, Configure, Settings, clone/update/status/backup/open workflows, Deployment Manager, Help, and Exit (15 options).

---

## Setup and configuration

| Command | Description |
| --- | --- |
| `dev configure` | Guided setup wizard |
| `dev settings` | Change preferences one at a time |
| `dev doctor` | Development environment check |

---

## Workspace workflows

| Command | Description |
| --- | --- |
| `dev clone` | Download missing GitHub repositories |
| `dev update` | Pull latest changes in existing repos |
| `dev status` | Show repository status across the workspace |
| `dev backup` | Review changed repos and back up safely |

---

## Deployments

Deployment Manager compares your GitHub repositories with Vercel, onboards the ones that are missing, and verifies production. Vercel is optional — DevTools is fully usable without it.

| Command | Changes anything? | Description |
| --- | --- | --- |
| `dev deploy` | No | Interactive Deployment Manager menu |
| `dev deploy audit` | **No** | Discover, inspect, match, and classify every candidate |
| `dev deploy plan` | **No** | Dry run: the exact projects sync would create |
| `dev deploy sync` | **Yes** | Create missing projects and start first deployments |
| `dev deploy verify` | **No** | Confirm production deployments are healthy |
| `dev deploy status` | **No** | Show deployment settings and readiness |
| `dev deploy help` | **No** | Deployment Manager help |

Options:

| Option | Applies to | Meaning |
| --- | --- | --- |
| `--apply` | `sync` | Skip the confirmation prompt. Creates real Vercel projects. |
| `--owner NAME` | all | Limit the operation to one GitHub owner |
| `--no-http` | `verify` | Skip the production URL health check |

Examples:

```powershell
dev deploy audit
dev deploy plan
dev deploy sync
dev deploy verify --no-http
dev deploy audit --owner Novenworks
```

`audit`, `plan`, `verify`, and `status` never create, deploy, or modify anything. Only `sync` mutates, and it always shows the plan and asks for confirmation first (default answer: No).

Full guide: [deployments.md](deployments.md)

---

## Quality and validation

| Command | Description |
| --- | --- |
| `dev test` | Run the automated DevTools validation suite |

`dev test` locates your DevTools installation automatically and can be run from any working directory.

Example:

```powershell
dev test
```

---

## Global install and self-management

Commands under `dev self` manage **DevTools itself** — testing, inspection, safe updates, and PATH setup. This is separate from `dev doctor`, which checks your general development environment.

| Command | Description |
| --- | --- |
| `dev self` | Interactive menu for DevTools self-management |
| `dev self test` | Run the same automated tests as `dev test` |
| `dev self update` | Safely pull latest changes when the working tree is clean |
| `dev self version` | Show DevTools version and repository URL |
| `dev self doctor` | Diagnose this DevTools installation (files, Git status) |
| `dev self info` | Show install path, config path, version, and Git details |
| `dev self install` | Add DevTools to your user PATH |
| `dev self uninstall` | Remove DevTools from your user PATH |
| `dev self path` | Show install root, PATH status, resolved `dev`/`dev.cmd`, and PATH conflicts |

Examples:

```powershell
dev self
dev self test
dev self version
dev self doctor
dev self install
dev self path
dev self uninstall
```

Install DevTools globally with:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

Then close and reopen PowerShell and run `dev`.

`dev self update` refuses to pull when you have uncommitted local changes. It does not reset, discard, commit, or push.

Only the **User** PATH is modified. Admin privileges are not required.

See [installation.md](installation.md) for the full install guide.

---

## Projects

| Command | Description |
| --- | --- |
| `dev open` | Search and open a project |
| `dev open <name>` | Open a project by partial name |
| `dev recent` | Open a recently used project |
| `dev info` | Inspect a project interactively |
| `dev info <name>` | Inspect a project by partial name |

### Open Project search

- Case-insensitive partial matching
- Press Enter without typing to list all projects
- Git repos are marked with `[git]`
- Other folders are marked with `[folder]`

Examples:

```powershell
dev open
dev open walkreplay
dev open loopforge
```

### Recent Projects

DevTools tracks up to 10 recently opened projects in `config/recent-projects.json` (local, not committed).

Examples:

```powershell
dev recent
```

On Home, press **O** to open a recent project when the list is shown.

### Home dashboard

When all required checks pass, Home shows **Ready to Build** and *Everything required is ready.*

Status symbols use emoji when the terminal supports Unicode and ASCII fallbacks otherwise. Environment overrides: `DEVTOOLS_ASCII=1`, `DEVTOOLS_FORCE_UNICODE=1`.

### Project Info

Shows location, Git status, branch, remote, last commit, inferred stack, and quick actions.

Examples:

```powershell
dev info
dev info walkreplay
```

Project Info is read-only. It does not modify files, install packages, or run dev servers.

---

## Safety notes

- Backup asks before committing or pushing
- Deployment `audit`, `plan`, `verify`, and `status` are read-only
- Deployment `sync` shows the plan and requires confirmation before creating anything
- Existing healthy Vercel projects are never modified, renamed, redeployed, or disconnected
- Clone skips existing folders
- Update runs `git pull` only inside existing repositories
- Project Info may open a GitHub URL in your browser when you choose that action

---

## See also

- [Installation guide](installation.md)
- [Configuration](configuration.md)
- [Deployment Manager](deployments.md)
- [Testing](testing.md)
- [Roadmap](roadmap.md)
- [FAQ](faq.md)
- [Smoke test checklist](testing/smoke-test.md)
- [Contributing](../CONTRIBUTING.md)
- [Project context](../PROJECT_CONTEXT.md) (maintainers and AI assistants)
