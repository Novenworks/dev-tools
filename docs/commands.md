# DevRepo Commands

Both launchers use the same commands. Legacy scripts can continue to invoke `dev`. Interactive sync and clone now require explicit approval.

Detailed command reference for DevRepo.

For a quick overview, see the [README](../README.md).

---

## Command index

| Command | Description |
| --- | --- |
| `devrepo` (legacy `dev`) | Home dashboard (default) |
| `devrepo home` | Home dashboard |
| `devrepo menu` | Main menu |
| `devrepo quick` | Quick Actions |
| `devrepo recent` | Open a recent project |
| `devrepo info` | Inspect a project |
| `devrepo open` | Search and open a project |
| `devrepo doctor` | Development environment check |
| `devrepo test` | Automated validation suite |
| `devrepo self` | DevRepo self-management menu |
| `devrepo self test` | Same as `devrepo test` |
| `devrepo self update` | Safely pull DevRepo updates |
| `devrepo self version` | Show DevRepo version |
| `devrepo self doctor` | Diagnose DevRepo installation |
| `devrepo self info` | Show install and Git details |
| `devrepo self install` | Add DevRepo to user PATH |
| `devrepo self uninstall` | Remove DevRepo from user PATH |
| `devrepo self path` | PATH and launcher diagnostics |
| `devrepo configure` | Guided setup wizard |
| `dev settings` | Change preferences |
| `devrepo clone` | Clone missing repositories |
| `devrepo sync` | Confirm a remote check and fast-forward update of safe projects |
| `devrepo update` | Alias for `devrepo sync` (kept for existing scripts) |
| `devrepo status` | Repository Health overview |
| `devrepo repos` | Repository maintenance menu |
| `devrepo backup` | Safe backup workflow |
| `devrepo deploy` | Deployment Manager (Vercel) |
| `devrepo deploy audit` | Compare GitHub repositories against Vercel (read-only) |
| `devrepo deploy plan` | Preview exactly what sync would create (read-only) |
| `devrepo deploy sync` | Create missing Vercel projects after confirmation |
| `devrepo deploy verify` | Check production deployments (read-only) |
| `devrepo deploy status` | Show deployment settings and readiness (read-only) |
| `devrepo deploy help` | Deployment Manager help |
| `devrepo help` | Beginner-friendly help |

Commands under **`devrepo self`** manage DevRepo itself. They do not replace `devrepo doctor`, which checks your general development environment.

---

## Core navigation

| Command | Description |
| --- | --- |
| `dev` / `devrepo home` | Home dashboard (default) |
| `devrepo menu` | Main menu |
| `devrepo quick` | Quick Actions for frequent tasks |
| `devrepo help` | Beginner-friendly help |

### Quick Actions

Menu options:

1. Recently opened
2. Open a project
3. Check project health
4. Update my projects
5. Download new projects
6. Fix repository issues
7. All actions
8. Quit

Returns to Quick Actions after each action unless you choose Main Menu or Exit.

### Main Menu

Includes Home, Quick Actions, Recent Projects, Project Info, Doctor, Configure, Settings, Clone, Sync repositories, Repository health, Repository maintenance, Backup, Open project, Deployment Manager, Help, and Exit (16 options).

---

## Setup and configuration

| Command | Description |
| --- | --- |
| `devrepo configure` | Guided setup wizard |
| `dev settings` | Change preferences one at a time |
| `devrepo doctor` | Development environment check |

---

## Workspace workflows

| Command | Description |
| --- | --- |
| `devrepo clone` | Preview and confirm downloads of missing GitHub projects |
| `devrepo sync` | Confirm a remote check and fast-forward update of safe projects |
| `devrepo update` | Alias for `devrepo sync` |
| `devrepo status` | Repository Health across the workspace |
| `devrepo repos` | Repository maintenance menu |
| `devrepo backup` | Review changed repos and back up safely |

---

## Repository Intelligence

DevRepo treats repository management as five steps rather than a bare `git pull`:

**fetch → inspect → classify → safely update → report.**

One shared repository state model powers Repository Health, Sync, Project Info, repair, and reports,
so every screen agrees about what a repository's situation actually is.

### Local status vs refreshed status

| Mode | What it does | Used by |
| --- | --- | --- |
| **Local status** | Reads current refs only. Fast, no network. | `devrepo status` on open, Project Info, Repository Actions |
| **Refreshed status** | Runs `git fetch --prune` first, so behind/diverged/deleted-upstream states are accurate. | `devrepo sync`, Repository Health after choosing **R**, upstream repair, report export |

`git fetch --prune` is read-only. It updates remote-tracking refs and removes refs whose remote
branch was deleted. It never touches your working tree, your branches, or your history.

### `devrepo sync`

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

Progress is shown as `[42/298] Refreshed bella-demo` during the refresh phase and
`[42/298] Checking bella-demo...` while repositories are inspected. A failure in one repository
never stops the batch.

### Sync speed and concurrency

Sync runs in two phases:

| Phase | What it does | Parallel? |
| --- | --- | --- |
| Refresh | `git fetch --prune` per repository | **Yes** - up to `syncConcurrency` at once |
| Inspect and update | Classify each repository, then fast-forward what is safe | No - one at a time |

Fetching is network-bound and dominates the time for a large workspace, so it runs in parallel.
Inspection, classification and the fast-forward itself stay single-threaded, so only one repository
is ever modified at a time and the safe-update policy is applied exactly as it is sequentially.
Concurrency changes how long sync takes, never what it decides.

`git fetch --prune` is read-only, so running several at once is safe. Each repository is still
fetched exactly once.

Set the limit in `config.json`:

```json
{ "syncConcurrency": 8 }
```

Default is 8, valid range 1-32, and **1 makes sync fully sequential** - useful on a slow or
rate-limited connection. Configs written before this setting existed keep working and get the
default. If the host cannot create a runspace pool, sync falls back to sequential fetching
automatically and still produces correct results.

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

### `devrepo status` — Repository Health

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

### `devrepo repos` — Repository Maintenance

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

DevRepo detects this, then before changing anything it confirms the working tree is clean, that no
Git operation is in progress, and — critically — whether the branch contains commits that are not
reachable from the default branch.

- **Unmerged commits exist, or the state cannot be proven:** DevRepo refuses, explains why, and
  leaves the repository exactly as it was.
- **Safe:** DevRepo switches to the default branch, restores its tracking branch when a remote
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

`devrepo repos` → Repository actions works on a single repository: open in your editor, open the folder,
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

Deployment Manager compares your GitHub repositories with Vercel, onboards the ones that are missing, and verifies production. Vercel is optional — DevRepo is fully usable without it.

| Command | Changes anything? | Description |
| --- | --- | --- |
| `devrepo deploy` | No | Interactive Deployment Manager menu |
| `devrepo deploy audit` | **No** | Discover, inspect, match, and classify every candidate |
| `devrepo deploy plan` | **No** | Dry run: the exact projects sync would create |
| `devrepo deploy sync` | **Yes** | Create missing projects and start first deployments |
| `devrepo deploy verify` | **No** | Confirm production deployments are healthy |
| `devrepo deploy status` | **No** | Show deployment settings and readiness |
| `devrepo deploy help` | **No** | Deployment Manager help |

Options:

| Option | Applies to | Meaning |
| --- | --- | --- |
| `--apply` | `sync` | Skip the confirmation prompt. Creates real Vercel projects. |
| `--owner NAME` | all | Limit the operation to one GitHub owner |
| `--no-http` | `verify` | Skip the production URL health check |

Examples:

```powershell
devrepo deploy audit
devrepo deploy plan
devrepo deploy sync
devrepo deploy verify --no-http
devrepo deploy audit --owner Novenworks
```

`audit`, `plan`, `verify`, and `status` never create, deploy, or modify anything. Only `sync` mutates, and it always shows the plan and asks for confirmation first (default answer: No).

Full guide: [deployments.md](deployments.md)

---

## Quality and validation

| Command | Description |
| --- | --- |
| `devrepo test` | Run the automated DevRepo validation suite |

`devrepo test` locates your DevRepo installation automatically and can be run from any working directory.

Example:

```powershell
devrepo test
```

---

## Global install and self-management

Commands under `devrepo self` manage **DevRepo itself** — testing, inspection, safe updates, and PATH setup. This is separate from `devrepo doctor`, which checks your general development environment.

| Command | Description |
| --- | --- |
| `devrepo self` | Interactive menu for DevRepo self-management |
| `devrepo self test` | Run the same automated tests as `devrepo test` |
| `devrepo self update` | Safely pull latest changes when the working tree is clean |
| `devrepo self version` | Show DevRepo version and repository URL |
| `devrepo self doctor` | Diagnose this DevRepo installation (files, Git status) |
| `devrepo self info` | Show install path, config path, version, and Git details |
| `devrepo self install` | Add DevRepo to your user PATH |
| `devrepo self uninstall` | Remove DevRepo from your user PATH |
| `devrepo self path` | Show install root, PATH status, resolved `dev`/`dev.cmd`, and PATH conflicts |

Examples:

```powershell
devrepo self
devrepo self test
devrepo self version
devrepo self doctor
devrepo self install
devrepo self path
devrepo self uninstall
```

Install DevRepo globally with:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

Then close and reopen PowerShell and run `dev`.

`devrepo self update` refuses to pull when you have uncommitted local changes. It does not reset, discard, commit, or push.

Only the **User** PATH is modified. Admin privileges are not required.

See [installation.md](installation.md) for the full install guide.

---

## Projects

| Command | Description |
| --- | --- |
| `devrepo open` | Search and open a project |
| `devrepo open <name>` | Open a project by partial name |
| `devrepo recent` | Open a recently used project |
| `devrepo info` | Inspect a project interactively |
| `devrepo info <name>` | Inspect a project by partial name |

### Open Project search

- Case-insensitive partial matching
- Press Enter without typing to list all projects
- Git repos are marked with `[git]`
- Other folders are marked with `[folder]`

Examples:

```powershell
devrepo open
devrepo open walkreplay
devrepo open loopforge
```

### Recent Projects

DevRepo tracks up to 10 recently opened projects in `config/recent-projects.json` (local, not committed).

Examples:

```powershell
devrepo recent
```

On Home, press **O** to open a recent project when the list is shown.

### Home dashboard

Home shows the active workspace path, Git and GitHub readiness, configured editor availability and local project counts. Repository counts are based on the shared status engine and known tracking refs. Ordinary folders are included in the total project count.

Use arrows and Enter, number or letter shortcuts, or Esc in supported consoles. The fallback accepts a shortcut or `Back`. Project search uses `:back` to leave the text prompt.

### Project Info

Shows location, Git status, branch, remote, last commit, inferred stack, and quick actions.

Examples:

```powershell
devrepo info
devrepo info walkreplay
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
- DevRepo never runs `git reset`, `git clean`, `git stash`, or any force operation
- DevRepo never resolves conflicts, merges or rebases diverged histories, commits, or pushes without an explicit action
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
