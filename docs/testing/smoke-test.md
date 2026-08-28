# DevTools Smoke Test Checklist

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

- [ ] DevTools starts successfully
- [ ] Home screen loads
- [ ] Header displays correctly
- [ ] No parser errors
- [ ] No unexpected warnings
- [ ] No execution policy errors when using global `dev`

**Commands to try:**

```powershell
cd C:\Projects\dev-tools
.\dev.cmd
```

---

## Global install

- [ ] `powershell -ExecutionPolicy Bypass -File install.ps1` completes successfully
- [ ] Post-install validation shows dev.cmd, dev-core.ps1, and user PATH
- [ ] After reopening PowerShell, `dev` works from any directory
- [ ] `dev self path` shows safe resolution to dev.cmd
- [ ] No execution policy error when running global `dev`

**Install flow:**

```powershell
git clone https://github.com/Novenworks/dev-tools.git
cd dev-tools
powershell -ExecutionPolicy Bypass -File install.ps1
```

Close and reopen PowerShell, then:

```powershell
dev
dev test
dev self path
```

---

## Home

- [ ] Home dashboard loads
- [ ] Workspace displayed
- [ ] GitHub owners displayed
- [ ] Repository count displayed
- [ ] System Status displayed
- [ ] When all required checks pass, shows **Ready to Build**
- [ ] When ready, shows “Everything required is ready.” (no parameter errors)
- [ ] Status icons render without errors (emoji or ASCII fallback)
- [ ] Recent Projects section appears after opening a project
- [ ] Press **O** opens recent project picker when recents exist
- [ ] Menu options respond correctly

**Command:**

```powershell
.\dev.cmd home
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
.\dev.cmd configure
```

---

## Settings

- [ ] Settings opens
- [ ] Each setting can be edited
- [ ] About screen loads
- [ ] Configuration persists after restart

**Command:**

```powershell
.\dev.cmd settings
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
.\dev.cmd doctor
```

---

## Repositories

- [ ] Clone works
- [ ] Update works
- [ ] Status works
- [ ] Backup prompts before committing
- [ ] Backup completes successfully

**Commands:**

```powershell
.\dev.cmd clone
.\dev.cmd update
.\dev.cmd status
.\dev.cmd backup
```

---

## Redundant Backup

A secondary backup remote is optional. Run this section against a real throwaway GitLab or Bitbucket repository — the push itself can't be safely automated in CI.

- [ ] `dev backup status` reports "not configured" and 0 repos when no `backup` section exists yet
- [ ] `dev backup setup` prompts for provider, namespace/workspace, and connection type, and shows the exact expected repository URL before adding the remote
- [ ] `dev backup setup` does not push and does not contact any provider API — it only runs `git remote add`/`set-url`
- [ ] After setup, `git remote -v` shows a `backup` remote with the expected URL
- [ ] `dev backup status` now reports the repo as configured
- [ ] `dev backup` pushes the current branch to `origin`, then pushes all branches and tags to `backup`
- [ ] Repeat `dev backup setup` on an already-configured repo — it shows the current URL and asks before replacing it
- [ ] Point the `backup` remote at an unreachable path and confirm `dev backup` still reports the GitHub push as successful, with only the secondary marked failed
- [ ] `dev doctor` shows a "Redundant Backup" section without changing the overall Ready to Build status
- [ ] No GitLab/Bitbucket token, password, or PAT is ever requested, displayed, or written to `config.json`

**Commands:**

```powershell
.\dev.cmd backup setup
.\dev.cmd backup status
.\dev.cmd backup
.\dev.cmd doctor
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
.\dev.cmd open
.\dev.cmd open walkreplay
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
.\dev.cmd recent
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
.\dev.cmd info
.\dev.cmd info walkreplay
```

---

## Deployment Manager

Vercel is optional. Run this section only when you use Deployment Manager.

**Without a Vercel token:**

- [ ] `dev doctor` still reports the same overall status (Vercel does not make DevTools "not ready")
- [ ] Doctor shows `Vercel authentication  AUTH REQUIRED` with setup instructions
- [ ] No token value appears anywhere on screen

**With `$env:VERCEL_TOKEN` set:**

- [ ] `dev deploy` menu opens and every option returns cleanly
- [ ] `dev deploy status` shows provider, team, owners, and include patterns
- [ ] `dev deploy audit` completes and creates **nothing**
- [ ] Audit table stays readable with long repository names
- [ ] `dev deploy plan` lists proposed creations and ends with `NO CHANGES HAVE BEEN MADE.`
- [ ] `dev deploy sync` shows the plan and asks `Continue? [y/N]`
- [ ] Answering `n` (or pressing Enter) creates nothing
- [ ] `dev deploy verify` completes and creates nothing
- [ ] `reports/deployments/latest.json` is written and contains no token
- [ ] `git status` shows no new tracked files from the audit

**Commands:**

```powershell
.\dev.cmd deploy
.\dev.cmd deploy status
.\dev.cmd deploy audit
.\dev.cmd deploy plan
.\dev.cmd deploy verify
```

Do **not** run `dev deploy sync` to completion during a smoke test unless you intend to create real Vercel projects.

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
.\dev.cmd home
.\dev.cmd menu
.\dev.cmd quick
.\dev.cmd recent
.\dev.cmd info
.\dev.cmd deploy
.\dev.cmd help
.\dev.cmd settings
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

Future versions of DevTools may automate parts of this checklist using GitHub Actions and PowerShell validation.

For now, this checklist is the official release validation process.
