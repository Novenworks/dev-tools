# Installing DevTools

DevTools can run directly from a cloned folder or be added to your user PATH so you can type `dev` from any PowerShell window.

For a quick overview, see the [README](../README.md).

---

## Recommended install

```powershell
git clone https://github.com/Novenworks/dev-tools.git
cd dev-tools
powershell -ExecutionPolicy Bypass -File install.ps1
```

Close and reopen PowerShell, then run:

```powershell
dev
```

The installer:

1. Detects the DevTools root from the script location
2. Verifies `dev.cmd` and `dev-core.ps1` exist
3. Creates `config.json` from `config.example.json` when needed
4. Adds the DevTools root to your **User** PATH only
5. Never modifies the system (Machine) PATH
6. Does not require admin privileges
7. Warns if another `dev` command appears earlier on PATH
8. Runs a lightweight post-install validation

---

## Requirements

- Windows
- PowerShell 5.1 or later
- Git and GitHub CLI (for full workspace features)

---

## Why `dev.cmd` is the global launcher

PowerShell may prefer `dev.ps1` over `dev.cmd` when both exist on PATH, which can trigger execution policy errors.

DevTools uses this architecture:

| File | Role |
| --- | --- |
| `dev.cmd` | Public global launcher on PATH |
| `dev-core.ps1` | Real PowerShell entrypoint (not on PATH directly) |

`dev.cmd` runs:

```cmd
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dev-core.ps1" %*
```

There is no root-level `dev.ps1` in the repository.

---

## Run locally without installing

```powershell
git clone https://github.com/Novenworks/dev-tools.git
cd dev-tools
.\dev.cmd
```

Use `dev.cmd` to avoid execution policy friction even before global install.

---

## Alternative: `dev self install`

From an already-cloned folder:

```powershell
.\dev.cmd self install
```

Then close and reopen PowerShell and run:

```powershell
dev
```

### What `dev self install` does

1. Detects the DevTools installation root from the running script location
2. Verifies `dev.cmd` and `dev-core.ps1` exist
3. Checks whether that folder is already on your **User** PATH
4. Refuses to modify PATH if another `dev` command is already resolved in the current session
5. Adds the folder to your **User** PATH if needed
6. Never modifies the system (Machine) PATH

### Already installed

If DevTools is already on your user PATH, you will see:

```text
DevTools is already available on your PATH.
```

### Another `dev` command on PATH

If a different `dev` command already exists elsewhere, `dev self install` will warn you and **will not** change your PATH until the conflict is resolved.

The standalone `install.ps1` script warns about conflicts but still adds DevTools to your user PATH.

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
- Whether the root is on your user PATH (Yes/No)
- Resolved `dev` command path in the current session
- Resolved `dev.cmd` command path
- Whether `dev` appears to resolve safely to DevTools
- Conflicting `dev.ps1`, `dev.cmd`, or other `dev` commands earlier on PATH

---

## Execution policy

Do not change your global PowerShell execution policy for DevTools.

Use the installer:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

Or the launcher:

```powershell
.\dev.cmd
```

After global install, type `dev` — it routes through `dev.cmd` automatically.

---

## After installing

1. Close and reopen PowerShell
2. Run `dev`
3. Complete **Configure**
4. Run **Doctor**
5. Run **Clone** to download repositories

If `dev` does not work in a new shell, run `dev self path` for diagnostics.

See [commands.md](commands.md) for the full command reference.
