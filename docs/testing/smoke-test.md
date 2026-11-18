# DevRepo Smoke Test Checklist

Run this checklist before publishing any GitHub Release.

**Estimated time:** 5–10 minutes

---

## General

| Field | Value |
| --- | --- |
| Release Version | v0.4.0 |
| Date | |
| Tester | |
| Operating System | |
| PowerShell Version | |
| Git Version | |
| GitHub CLI Version | |
| Notes | |

---

## Launch

- [ ] DevRepo starts successfully
- [ ] Home screen loads
- [ ] Header displays correctly
- [ ] No parser errors
- [ ] No unexpected warnings
- [ ] No execution policy errors when using global `dev`

**Commands to try:**

```powershell
cd C:\Projects\dev-tools
.\devrepo.cmd
```

---

## Global install

- [ ] `powershell -ExecutionPolicy Bypass -File install.ps1` completes successfully
- [ ] Post-install validation shows dev.cmd, dev-core.ps1, and user PATH
- [ ] After reopening PowerShell, `dev` works from any directory
- [ ] `devrepo self path` shows safe resolution to dev.cmd
- [ ] No execution policy error when running global `dev`

**Install flow:**

```powershell
git clone https://github.com/Novenworks/dev-tools.git
cd dev-tools
powershell -ExecutionPolicy Bypass -File install.ps1
```

Close and reopen PowerShell, then:

```powershell
devrepo
devrepo test
devrepo self path
```

---

## Home

- [ ] Both `devrepo` and legacy `dev` open the same Home dashboard from another directory
- [ ] A clean install opens setup, and canceling setup leaves settings unsaved
- [ ] Home displays the workspace and checks Git, GitHub sign-in and the configured editor
- [ ] A workspace with a regular folder and a Git checkout shows two projects and one assessed Git project
- [ ] Arrow keys move the focus, Enter selects it, shortcuts open the right action, and Esc returns
- [ ] The fallback host accepts typed shortcuts and `Back`
- [ ] `DEVTOOLS_ASCII=1` works on detailed screens
- [ ] Opening a project adds it to Recently opened, accessible with **6** or **O**

**Command:**

```powershell
.\devrepo.cmd home
```

---

## Configure

- [ ] Configure launches
- [ ] Existing values load
- [ ] Press Enter keeps values
- [ ] Saving configuration works
- [ ] Home updates after configuration

**Command:**

```powershell
.\devrepo.cmd configure
```

---

## Settings

- [ ] Settings opens
- [ ] Each setting can be edited
- [ ] About screen loads
- [ ] Configuration persists after restart

**Command:**

```powershell
.\devrepo.cmd settings
```

---

## Doctor

- [ ] Doctor runs successfully
- [ ] Required checks display
- [ ] Optional checks display
- [ ] Status summary appears
- [ ] Interactive fixes behave correctly
- [ ] GitHub login prompt works

**Command:**

```powershell
.\devrepo.cmd doctor
```

---

## Repositories

- [ ] Download preview counts missing folders and existing folders. Cancel creates no project folders
- [ ] Confirmed downloads leave existing folders alone and show verified download counts
- [ ] Canceling `devrepo sync` leaves local checkouts and tracking refs unchanged
- [ ] Confirmed `devrepo sync` refreshes remote state and shows compact per-repository lines
- [ ] `devrepo update` still works and behaves the same as `devrepo sync`
- [ ] Progress shows `[n/total] Refreshed <name>` while fetching, then `[n/total] Checking <name>...`, and never looks frozen
- [ ] Sync is noticeably faster than a sequential run (`"syncConcurrency": 1` in `config.json` to compare)
- [ ] Setting `"syncConcurrency": 1` still produces the same per-repository results, just slower
- [ ] Updated repositories report a commit count
- [ ] Skipped repositories give a real reason, never "could not update"
- [ ] The sync summary counts add up to the repository total
- [ ] "Review repositories needing attention" shows explanation, work-safety note, and next step
- [ ] `devrepo status` opens Repository Health on the repositories needing attention
- [ ] Filters 1-8 work, D shows details, R refreshes, E exports a report
- [ ] Backup prompts before committing
- [ ] Backup completes successfully

**Commands:**

```powershell
.\devrepo.cmd clone
.\devrepo.cmd sync
.\devrepo.cmd update
.\devrepo.cmd status
.\devrepo.cmd backup
```

## Automation

- [ ] `devrepo status --json` and `dev status --json` emit one equivalent schema v1 object
- [ ] `devrepo doctor --json` reports setup without opening any prompts
- [ ] `devrepo projects list --json` matches the actual workspace
- [ ] `devrepo sync --dry-run --json` leaves refs and working trees unchanged
- [ ] `devrepo sync --json` exits with code 7 and reports `unsafe_operation`

---

## Repository Maintenance

- [ ] `devrepo repos` opens the maintenance menu
- [ ] Repair broken upstreams finds repositories whose remote branch was deleted
- [ ] A branch with unmerged commits is refused, with the reason shown
- [ ] A safe repair switches to the default branch and keeps the old branch on disk
- [ ] Branch cleanup lists safe-to-delete and needs-review counts
- [ ] Branch cleanup asks for confirmation and never deletes an unmerged branch
- [ ] Repository actions menu works (fetch, pull, push confirmation, switch branch, view branches)
- [ ] Push asks for explicit confirmation before pushing anything
- [ ] Export diagnostic report writes `reports/repositories/latest.json` and `latest.txt`
- [ ] The exported report contains no credentials or tokens

**Safety spot check** — pick a repository with uncommitted changes before running sync, then verify afterwards:

- [ ] Its uncommitted changes are still there
- [ ] `git log` is unchanged
- [ ] It was reported as skipped with "local changes"

**Command:**

```powershell
.\devrepo.cmd repos
```

---

## Open Project

- [ ] Open by number
- [ ] Open by full name
- [ ] Open by partial name
- [ ] Search returns expected results
- [ ] Invalid search handled gracefully
- [ ] Default editor opens correctly

**Command:**

```powershell
.\devrepo.cmd open
.\devrepo.cmd open walkreplay
```

---

## Recent Projects

- [ ] Recent project appears after opening a project
- [ ] Recent project can be opened by number
- [ ] Missing recent project path is handled gracefully
- [ ] Home shows recent projects when available
- [ ] Press O on Home opens recent picker

**Command:**

```powershell
.\devrepo.cmd recent
```

---

## Project Info

- [ ] Info loads for Git repo
- [ ] Info loads for non-Git folder
- [ ] Partial name search works
- [ ] GitHub URL opens if available
- [ ] Stack detection shows inferred tags

**Commands:**

```powershell
.\devrepo.cmd info
.\devrepo.cmd info walkreplay
```

---

## Deployment Manager

Vercel is optional. Run this section only when you use Deployment Manager.

**Without a Vercel token:**

- [ ] `devrepo doctor` still reports the same overall status (Vercel does not make DevRepo "not ready")
- [ ] Doctor shows `Vercel authentication  AUTH REQUIRED` with setup instructions
- [ ] No token value appears anywhere on screen

**With `$env:VERCEL_TOKEN` set:**

- [ ] `devrepo deploy` menu opens and every option returns cleanly
- [ ] `devrepo deploy status` shows provider, team, owners, and include patterns
- [ ] `devrepo deploy audit` completes and creates **nothing**
- [ ] Audit table stays readable with long repository names
- [ ] `devrepo deploy plan` lists proposed creations and ends with `NO CHANGES HAVE BEEN MADE.`
- [ ] `devrepo deploy sync` shows the plan and asks `Continue? [y/N]`
- [ ] Answering `n` (or pressing Enter) creates nothing
- [ ] `devrepo deploy verify` completes and creates nothing
- [ ] `reports/deployments/latest.json` is written and contains no token
- [ ] `git status` shows no new tracked files from the audit

**Commands:**

```powershell
.\devrepo.cmd deploy
.\devrepo.cmd deploy status
.\devrepo.cmd deploy audit
.\devrepo.cmd deploy plan
.\devrepo.cmd deploy verify
```

Do **not** run `devrepo deploy sync` to completion during a smoke test unless you intend to create real Vercel projects.

---

## Navigation

- [ ] Home
- [ ] Main Menu
- [ ] Quick Actions
- [ ] Recent Projects
- [ ] Project Info
- [ ] Deployment Manager
- [ ] Help
- [ ] Settings
- [ ] Exit

**Commands:**

```powershell
.\devrepo.cmd home
.\devrepo.cmd menu
.\devrepo.cmd quick
.\devrepo.cmd recent
.\devrepo.cmd info
.\devrepo.cmd deploy
.\devrepo.cmd help
.\devrepo.cmd settings
```

---

## Documentation

- [ ] README renders correctly
- [ ] Installation steps are accurate
- [ ] Commands are accurate
- [ ] Links work
- [ ] Screenshots are current

---

## Repository

- [ ] CHANGELOG updated
- [ ] Version number updated
- [ ] Roadmap reviewed
- [ ] Issues reviewed
- [ ] Milestones reviewed

**Files to check:**

- `VERSION`
- `CHANGELOG.md`
- `README.md`

---

## Release

Before publishing:

- [ ] All smoke tests passed
- [ ] Automated validation passed (`tests/Test-DevTools.ps1`)
- [ ] Git status clean
- [ ] Changes committed
- [ ] Changes pushed
- [ ] GitHub Release drafted
- [ ] Release notes reviewed
- [ ] Screenshots attached
- [ ] README reviewed one final time

---

## Result

### Overall

- [ ] PASS
- [ ] FAIL

### If failed

Document:

| Field | Value |
| --- | --- |
| Issue | |
| Severity | |
| Suggested fix | |

Do not publish the release until critical failures are resolved or explicitly deferred with a documented reason.

---

## Future Automation

Future versions of DevRepo may automate parts of this checklist using GitHub Actions and PowerShell validation.

For now, this checklist is the official release validation process.
