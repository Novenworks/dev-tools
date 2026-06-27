# DevTools FAQ

Common questions about DevTools. For installation, see [installation.md](installation.md). For commands, see [commands.md](commands.md).

---

## General

**What is DevTools?**  
A Windows PowerShell CLI for managing local GitHub workspaces — clone, update, check status, open projects, and back up changes from one menu.

**Who is it for?**  
Developers, freelancers, students, and builders who work across multiple repositories on Windows.

**What version is current?**  
See the `VERSION` file in the repository (currently v0.4.0).

---

## Installation

**How do I install DevTools?**

```powershell
git clone https://github.com/Novenworks/dev-tools.git
cd dev-tools
powershell -ExecutionPolicy Bypass -File install.ps1
```

Close and reopen PowerShell, then run `dev`.

**Why do I need to reopen PowerShell?**  
PATH changes apply to new shell sessions. The installer updates your user PATH; existing windows keep the old PATH.

**Why use `dev.cmd` instead of running a `.ps1` file directly?**  
PowerShell may prefer `dev.ps1` over `dev.cmd` on PATH, which can trigger execution policy errors. DevTools uses `dev.cmd` as the global launcher.

---

## Usage

**Does DevTools replace Git?**  
No. DevTools wraps common Git and GitHub CLI workflows. You still use Git underneath.

**Does it work with private repositories?**  
Yes, when you are signed in to GitHub CLI with access.

**Does it work on macOS or Linux?**  
Not yet. DevTools is Windows-first today.

**Is backup safe?**  
Yes. Backup shows changes and asks for confirmation before committing or pushing.

**Do I need Node.js?**  
No. Node.js is optional. Doctor reports optional tools.

**What is `dev self`?**  
Commands that manage DevTools itself — test the installation, inspect PATH, update safely, and more. Separate from `dev doctor`, which checks your development environment.

**What is `dev test`?**  
Runs automated validation (syntax, required files, config). Safe to run from any directory after global install.

---

## Troubleshooting

**`dev` is not recognized after install**  
Close and reopen PowerShell. Run `dev self path` to diagnose PATH and launcher resolution.

**Execution policy errors**  
Use global `dev` (routes through `dev.cmd`) or run `.\dev.cmd` from the repo folder.

---

## See also

- [Installation guide](installation.md)
- [Command reference](commands.md)
- [Roadmap](roadmap.md)
- [README](../README.md)
