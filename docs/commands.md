# DevTools Commands

Detailed command reference for DevTools.

For a quick overview, see the [README](../README.md).

---

## Core navigation

| Command | Description |
| --- | --- |
| `dev` / `dev home` | Home dashboard (default) |
| `dev menu` | Main menu |
| `dev quick` | Quick Actions for frequent tasks |
| `dev help` | Beginner-friendly help |

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
- Clone skips existing folders
- Update runs `git pull` only inside existing repositories
- Project Info may open a GitHub URL in your browser when you choose that action

---

## See also

- [Smoke test checklist](testing/smoke-test.md)
- [Contributing](../CONTRIBUTING.md)
