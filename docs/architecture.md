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
reports/                   Generated deployment and repository reports (gitignored)
VERSION                    Single source for version string
```

---

## Design rules

- Business logic lives in `lib/`.
- Commands stay thin.
- No GitHub REST API — use GitHub CLI (`gh`) where needed, including `gh api`.
- Backup never commits or pushes without confirmation.
- Repository state has one source of truth: `repo-git.ps1` acquires facts, `repo-state.ps1` classifies them, and everything else consumes the result.
- Git data acquisition, classification, recommended actions, UI rendering, and mutation are separate layers. Classification is pure and testable without Git.
- Bulk repository updates are fast-forward only. Unsafe states are classified and reported, never automatically modified.
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
| `git.ps1` | Workspace repository discovery and backward-compatible status projection |
| `repo-git.ps1` | Git invocation result model, porcelain v2 parsing, fetch, raw repository facts |
| `repo-state.ps1` | Pure health classification, safe-update policy, filters, summaries |
| `repo-sync.ps1` | Workspace collection and the fast-forward-only sync engine |
| `repo-repair.ps1` | Upstream repair safety rules and merged-branch cleanup |
| `repo-report.ps1` | Repository diagnostic reports (JSON and Markdown-style text) |
| `repo-ui.ps1` | Repository Health, Sync, maintenance menus, repair and cleanup flows |
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
