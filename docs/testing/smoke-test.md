# DevTools Smoke Test Checklist

Run this checklist before publishing any GitHub Release.

**Estimated time:** 5–10 minutes

---

## General

| Field | Value |
| --- | --- |
| Release Version | |
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

**Commands to try:**

```powershell
cd C:\Projects\dev-tools
.\dev.cmd
```

---

## Home

- [ ] Home dashboard loads
- [ ] Workspace displayed
- [ ] GitHub owners displayed
- [ ] Repository count displayed
- [ ] Status displayed
- [ ] Menu options respond correctly

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

## Navigation

- [ ] Home
- [ ] Main Menu
- [ ] Quick Actions
- [ ] Recent Projects
- [ ] Project Info
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
