# DevTools Configuration

DevTools stores settings in `config.json` at the installation root. This file is local and gitignored.

On first run, DevTools creates `config.json` from `config.example.json`.

---

## Settings

| Key | Description | Example |
| --- | --- | --- |
| `workspacePath` | Root folder for your projects | `C:\\Projects` |
| `githubOwners` | GitHub usernames or orgs to clone from | `["Novenworks"]` |
| `defaultEditor` | Editor command for Open Project | `cursor`, `code`, `explorer` |
| `autoBackupMessage` | Default commit message for backup | `Auto backup` |
| `autoUpdate` | Reserved for future auto-update behavior | `false` |

---

## Local data

| File | Purpose |
| --- | --- |
| `config/recent-projects.json` | Recent Projects history (not committed) |

---

## Changing settings

Prefer the guided menus:

```powershell
dev configure    # Full setup wizard
dev settings     # Change one setting at a time
```

Manual editing of `config.json` is supported but rarely needed.

---

## See also

- [Installation](installation.md)
- [Command reference](commands.md)
