# DevTools Architecture

Overview of how DevTools is structured. For maintainer detail, see [PROJECT_CONTEXT.md](../PROJECT_CONTEXT.md).

---

## Entry points

| File | Role |
| --- | --- |
| `dev.cmd` | Public global launcher on PATH |
| `dev-core.ps1` | Real PowerShell entrypoint (loaded via `dev.cmd` with execution policy bypass) |
| `install.ps1` | Recommended installer for user PATH setup |

There is no root-level `dev.ps1`. This avoids PowerShell preferring `.ps1` over `.cmd` on PATH.

---

## Repository layout

```text
dev.cmd / dev-core.ps1     Launchers
install.ps1                Installer

commands/                  Thin command wrappers
lib/                       Shared business logic
docs/                      User documentation
tests/                     Automated validation
.github/                   CI and issue templates
config/                    Local runtime data (gitignored)
reports/                   Generated deployment reports (gitignored)
VERSION                    Single source for version string
```

---

## Design rules

- Business logic lives in `lib/`.
- Commands stay thin.
- No GitHub REST API — use GitHub CLI (`gh`) where needed, including `gh api`.
- Backup never commits or pushes without confirmation.
- User config stays local and gitignored.
- Deployment `audit`, `plan`, `verify`, and `status` are read-only. Only `sync` mutates, and only after confirmation.
- Credentials come from the environment, never from tracked files.

---

## Key modules

| Module | Responsibility |
| --- | --- |
| `utils.ps1` | Root detection, command helpers |
| `config.ps1` | Settings load/save |
| `home.ps1` | Home dashboard |
| `doctor.ps1` | Environment checks |
| `projects.ps1` | Project search and open |
| `recent.ps1` | Recent project history |
| `project-info.ps1` | Project inspection |
| `test.ps1` | Test runner wrapper |
| `self.ps1` | DevTools self-management |
| `deploy-config.ps1` | Deployment settings, name normalization, eligibility rules |
| `deploy-github.ps1` | Repository discovery and remote deployability inspection (`gh`) |
| `deploy-vercel.ps1` | Vercel REST client, pagination, deployment polling |
| `deploy-model.ps1` | Repository/project matching, status classification, planning |
| `deploy-report.ps1` | Deployment tables, summaries, JSON reports |
| `deploy.ps1` | Deployment Manager orchestration (audit, plan, sync, verify) |

---

## See also

- [Configuration](configuration.md)
- [Testing](testing.md)
- [Command reference](commands.md)
- [Deployment Manager](deployments.md)
