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
| `dev sync` | Refresh GitHub state and safely fast-forward repositories |
| `dev update` | Alias for `dev sync` (kept for existing scripts) |
| `dev status` | Repository Health overview |
| `dev repos` | Repository maintenance menu |
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
3. Repository Health  
4. Sync Repositories  
5. Clone Missing Repositories  
6. Repository Maintenance  
7. Main Menu  
8. Exit  

Returns to Quick Actions after each action unless you choose Main Menu or Exit.

### Main Menu

Includes Home, Quick Actions, Recent Projects, Project Info, Doctor, Configure, Settings, Clone, Sync repositories, Repository health, Repository maintenance, Backup, Open project, Deployment Manager, Help, and Exit (16 options).

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
| `dev sync` | Refresh GitHub state and safely fast-forward repositories |
| `dev update` | Alias for `dev sync` |
| `dev status` | Repository Health across the workspace |
| `dev repos` | Repository maintenance menu |
| `dev backup` | Review changed repos and back up safely |

---

## Repository Intelligence

DevTools treats repository management as five steps rather than a bare `git pull`:

**fetch → inspect → classify → safely update → report.**

One shared repository state model powers Repository Health, Sync, Project Info, repair, and reports,
so every screen agrees about what a repository's situation actually is.

### Local status vs refreshed status

| Mode | What it does | Used by |
| --- | --- | --- |
| **Local status** | Reads current refs only. Fast, no network. | `dev status` on open, Project Info, Repository Actions |
| **Refreshed status** | Runs `git fetch --prune` first, so behind/diverged/deleted-upstream states are accurate. | `dev sync`, Repository Health after choosing **R**, upstream repair, report export |

`git fetch --prune` is read-only. It updates remote-tracking refs and removes refs whose remote
branch was deleted. It never touches your working tree, your branches, or your history.

### `dev sync`

Sync refreshes GitHub state for every repository, classifies it, and updates only what is provably safe.

A repository is updated automatically **only** when all of these are true:

- It is a valid Git repository with a reachable remote
- The fetch succeeded
- HEAD is on a branch (not detached)
- No merge, rebase, cherry-pick, or revert is in progress
- There are no conflicts
- The working tree is clean
- A valid upstream branch exists
- The branch is not ahead and not diverged
- The branch is behind by at least one commit

The update itself is fast-forward only, so bulk sync never creates a merge commit.

Output stays compact for large workspaces:

```text
* Updated: MyProject (4 commits)
. Current: AnotherProject
! Skipped: OldDemo - local changes
! Skipped: AgentBranch - origin/claude/rebuild-homepage no longer exists
```

Progress is shown as `[42/298] Checking bella-demo...` while sync runs. A failure in one repository
never stops the batch.

### Classifications

| Classification | Meaning |
| --- | --- |
| Updated | Fast-forwarded successfully |
| Current | Already matches GitHub, nothing to do |
| Local changes | Uncommitted work in the working tree |
| Ahead | Local commits that are not on GitHub |
| Behind | GitHub has commits you do not have |
| Diverged | Local and remote both have unique commits |
| Missing upstream | The branch tracks nothing |
| Upstream gone | The tracked remote branch no longer exists |
| Detached HEAD | Not currently on a branch |
| Conflicts | Unresolved merge conflicts |
| Merge in progress | An unfinished merge |
| Rebase in progress | An unfinished rebase |
| Operation in progress | An unfinished cherry-pick, revert, or bisect |
| No remote | No remote is configured |
| Sign-in required | The remote refused authentication |
| Remote unavailable | The remote could not be reached |
| Refresh failed | The fetch failed for another reason |
| Not a repository | The folder could not be read as a Git repository |
| Git error | An unrecognized Git failure |

The most actionable condition always wins. A repository with unresolved conflicts is reported as
**Conflicts**, never as **Modified**.

Every unhealthy state answers three questions: what happened, is my local work safe, and what should
I do next. The underlying Git error is kept and shown on request or in the diagnostic report, rather
than dumped into the normal output.

### `dev status` — Repository Health

Repository Health shows counts for healthy, local changes, behind, ahead, diverged, broken upstream,
detached HEAD, conflicts, operations in progress, and remote/fetch failures. It opens on the
repositories that need attention, so you never scroll past hundreds of clean repositories.

Filters:

1. All repositories
2. Repositories needing attention
3. Modified repositories
4. Behind repositories
5. Ahead repositories
6. Diverged repositories
7. Broken upstreams
8. Conflicts / operations in progress
9. Return

Plus **D** to show full details for the current view, **R** to refresh GitHub state, and **E** to
export a diagnostic report.

### `dev repos` — Repository Maintenance

1. Sync repositories
2. Repository health
3. Review repositories needing attention
4. Repair broken upstreams
5. Branch cleanup
6. Export diagnostic report
7. Repository actions (single repository)
8. Return

### Repair upstream

The common AI-agent situation: a branch such as `claude/rebuild-homepage` tracked
`origin/claude/rebuild-homepage`, the pull request merged, and the remote branch was deleted.

DevTools detects this, then before changing anything it confirms the working tree is clean, that no
Git operation is in progress, and — critically — whether the branch contains commits that are not
reachable from the default branch.

- **Unmerged commits exist, or the state cannot be proven:** DevTools refuses, explains why, and
  leaves the repository exactly as it was.
- **Safe:** DevTools switches to the default branch, restores its tracking branch when a remote
  branch exists, refreshes, and fast-forwards.

The old branch is never deleted during repair. Use Branch cleanup for that, separately.

### Branch cleanup

Cleanup finds stale local branches — any branch that is not the current branch, not a protected
branch (`main`, `master`, `develop`, `trunk`, or the repository default), and either has a missing
upstream or is fully merged. Naming schemes such as `claude/*`, `cursor/*`, or `codex/*` are handled
by the same generic rules; no prefix is hardcoded.

**A branch is only offered for deletion when Git can prove it is fully merged.** Deletion uses
`git branch -d`, never `-D`, and always after you review the list and confirm.

### Repository actions

`dev repos` → Repository actions works on a single repository: open in your editor, open the folder,
open on GitHub, repository health, refresh remote status, fetch, fast-forward pull, push, switch to
the default branch, view branches, repair upstream, clean merged branches, and export a report.
Project Info also links to this menu.

Push is never silent. It always states what will be pushed and requires explicit confirmation.

### Diagnostic reports

Reports are written to the gitignored `reports/repositories/` folder:

| File | Purpose |
| --- | --- |
| `latest.json` | Machine-readable repository state |
| `latest.txt` | Markdown-style report, easy to paste into an assistant |

Each entry records name, path, branch, default branch, upstream, remote, working-tree status,
ahead/behind, detached state, conflicts, operation state, upstream existence, fetch outcome, health
classification, recommended action, and a concise Git error when there is one.

Credentials embedded in remote URLs are stripped before anything is written, and Git error text is
sanitized and truncated the same way.

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
- Bulk sync is fast-forward only and never creates a merge commit
- DevTools never runs `git reset`, `git clean`, `git stash`, or any force operation
- DevTools never resolves conflicts, merges or rebases diverged histories, commits, or pushes without an explicit action
- Unsafe repositories are skipped and explained, never modified
- Upstream repair refuses to switch branches when unmerged commits exist, and never deletes a branch
- Branch cleanup never force-deletes and never deletes a branch Git cannot prove is merged
- Repository reports never contain credentials
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
