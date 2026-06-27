# Installing DevTools

DevTools can run directly from a cloned folder or be added to your user PATH so you can type `dev` from any PowerShell window.

For a quick overview, see the [README](../README.md).

---

## Requirements

- Windows
- PowerShell 5.1 or later
- Git and GitHub CLI (for full workspace features)

---

## Clone and run locally

```powershell
git clone https://github.com/Novenworks/dev-tools.git C:\Projects\dev-tools
cd C:\Projects\dev-tools
.\dev.cmd
```

Use `dev.cmd` to avoid common PowerShell execution policy issues.

---

## Global install (recommended)

Add DevTools to your **user PATH** without admin privileges:

```powershell
cd C:\Projects\dev-tools
.\dev.cmd self install
```

Then close and reopen PowerShell and run:

```powershell
dev
```

### What `dev self install` does

1. Detects the DevTools installation root from the running script location
2. Verifies `dev.cmd` exists in that folder
3. Checks whether that folder is already on your **User** PATH
4. Adds the folder to your **User** PATH if needed
5. Never modifies the system (Machine) PATH

### Already installed

If DevTools is already on your user PATH, you will see:

```text
DevTools is already available on your PATH.
```

### Another `dev` command on PATH

If a different `dev` command already exists elsewhere, DevTools will warn you and **will not** change your PATH until the conflict is resolved.

Check details with:

```powershell
dev self path
```

---

## Uninstall from PATH

Remove DevTools from your user PATH without deleting the repository:

```powershell
dev self uninstall
```

This removes only the exact DevTools installation path. Other PATH entries are not changed.

Close and reopen PowerShell after uninstalling.

---

## Inspect PATH status

```powershell
dev self path
```

Shows:

- DevTools root directory
- Whether the root is on your user PATH
- Detected `dev` command locations in the current session

---

## Legacy installer script

The standalone script `install.ps1` also adds DevTools to your user PATH and creates `config.json` on first run.

```powershell
.\install.ps1
```

Prefer `dev self install` for a clearer, integrated workflow.

---

## Execution policy

If PowerShell blocks scripts, use the launcher:

```powershell
.\dev.cmd self install
```

Or:

```powershell
powershell -ExecutionPolicy Bypass -File ".\dev.ps1" self install
```

---

## After installing

1. Close and reopen PowerShell
2. Run `dev`
3. Complete **Configure**
4. Run **Doctor**
5. Run **Clone** to download repositories

See [commands.md](commands.md) for the full command reference.
