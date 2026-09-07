# DevTools — Project Context

**Version:** v0.5.0 (see `VERSION`)  
**Status:** Active Development  
**Repository:** https://github.com/Novenworks/dev-tools  
**Product:** DevTools  
**Built by:** Novenworks

> **Internal document.** This file is the source of truth for AI assistants, maintainers, and contributors. It is not public user documentation. For users, see `README.md` and `docs/`.

---

## Mission

Help developers spend less time managing projects and more time building.

DevTools is a Windows-first PowerShell CLI that simplifies working across multiple local Git repositories through a beginner-friendly command-line experience. The focus is reducing repetitive development tasks while improving developer experience (DX).

---

## Vision

DevTools should become the first command developers launch before they begin coding.

Instead of remembering repository names, Git commands, folder locations, setup steps, and editor commands, users should run:

```text
dev
```

and manage their development workspace from one place.

DevTools complements Git, GitHub CLI, Cursor, VS Code, and GitHub Desktop. It does not replace them.

---

## Product Philosophy

DevTools exists to remove friction.

Every feature should answer one question: **Does this save developers time every day?**

If not, it probably belongs in the backlog instead of the current milestone.

Developer experience is the product.

---

## Target Audience

**Primary**

- Solo developers
- Freelancers
- Indie hackers
- Small agencies
- Consultants
- Open-source maintainers

**Secondary**

- Students learning Git
- PowerShell users
- Windows developers
- AI-assisted developers using Cursor or Claude

---

## Core Principles

When making product decisions, prioritize:

1. Simplicity
2. Reliability
3. Beginner friendliness
4. Speed
5. Maintainability

Small improvements used every day are more valuable than large features used occasionally. Avoid feature creep.

---

## Current Features

At the time of writing, DevTools includes:

**Setup and navigation**

- Guided setup (`configure`)
- Settings menu and About screen
- Home dashboard with system status, collapsed checklist, and ready-state messaging
- Main menu and Help
- Quick Actions (`quick`) for frequent tasks

**Environment**

- Doctor with required/optional checks and interactive fixes
- DevTools-native GitHub sign-in messaging on Home (no raw `gh auth status` on Home)
- Display symbols with emoji or ASCII fallback (`Get-DevToolsDisplaySymbol`)

**Repository workflows (Repository Intelligence, v0.5.0)**

- Clone missing GitHub repositories (`gh`, no GitHub API in DevTools)
- One shared repository state model: facts (`repo-git.ps1`) -> pure classification (`repo-state.ps1`) -> everything else
- `dev sync` — fetch/prune, classify, and fast-forward only provably safe repositories; `dev update` is an alias
- Repository Health (`dev status`) — counts plus filters for attention, modified, behind, ahead, diverged, broken upstreams, and blocked repositories
- Detailed classifications with explanation, local-work reassurance, and recommended action
- Guided upstream repair for deleted remote branches (the AI agent branch case)
- Safe merged-branch cleanup (`git branch -d` only, never `-D`, never unmerged)
- Repository Maintenance menu (`dev repos`) and single-repository actions
- Diagnostic reports in the gitignored `reports/repositories/` folder
- Compact progress feedback at ~300-repository scale
- Safe backup (always confirms before commit/push)

**Projects**

- Open project with partial name search (`open`, `open <name>`)
- Recent Projects (`recent`) — local history, shown on Home when available
- Project Info (`info`, `info <name>`) — Git metadata, inferred stack, quick actions

**Deployments (optional)**

- Deployment Manager (`dev deploy`) — Vercel portfolio audit, planning, onboarding, and verification
- Read-only `audit`, `plan`, `verify`, `status`; mutating `sync` behind explicit confirmation
- Conservative eligibility rules, safe repository/project matching, idempotent onboarding
- Machine-readable reports in the gitignored `reports/` folder
- `VERCEL_TOKEN` is read from the environment only and never stored, logged, or printed

**Quality and community**

- Manual smoke test checklist (`docs/testing/smoke-test.md`)
- Automated validation (`tests/Test-DevTools.ps1`, GitHub Actions CI)
- Behavioral repository tests (`tests/Test-Repos.ps1`) using throwaway Git fixtures and local bare remotes
- `dev test` — run validation from any directory
- `dev self` — test, inspect, update, and manage PATH for DevTools itself
- Global install via `install.ps1` or `dev self install` (User PATH only)
- GitHub issue templates, labels/milestones docs, seed issue list

DevTools dogfoods itself through `dev self` and `dev test`.

**Commands (entry point: `dev` / `dev.cmd`)**

`home`, `menu`, `quick`, `recent`, `info`, `repos`, `test`, `self`, `configure`, `settings`, `doctor`, `clone`, `sync`, `update`, `status`, `backup`, `open`, `deploy`, `help`

`dev update` is preserved as an alias for `dev sync`. Do not break it.

`dev self install` adds the installation folder to the **User** PATH only (no admin, no Machine PATH).

DevTools should increasingly dogfood itself. Commands under `dev self` are responsible for testing, inspecting, and safely updating the DevTools installation.

Update this section when features ship or are removed.

---

## Non-Goals

DevTools is intentionally **not**:

- a Git replacement
- an IDE
- a package manager
- a deployment platform (DevTools *manages* deployments on Vercel; it never becomes a host or build system of its own)
- a cloud service
- a project management application
- cross-platform (today — Windows only)

Maintain a focused scope.

---

## Current Milestone

**v0.5.0 — Repository Intelligence**

Shipped in this release:

- Shared repository state model across status, sync, Project Info, repair, and reporting
- `dev sync` with fast-forward-only bulk updates (`dev update` preserved)
- Repository Health with workspace counts and filters
- Actionable classifications replacing "Could not update"
- Guided upstream repair and safe merged-branch cleanup
- Repository Maintenance menu and single-repository actions
- Diagnostic report export
- Deployment Manager (previously unreleased) ships here too
- Behavioral repository test suite

**Next focus (v0.5.x — Stabilization):** See [`.github/milestones.md`](.github/milestones.md) and [`.github/ISSUES_TO_CREATE.md`](.github/ISSUES_TO_CREATE.md).

---

## Roadmap

Roadmap detail lives in GitHub Issues, labels, and milestones. See:

- [`.github/milestones.md`](.github/milestones.md)
- [`.github/ISSUES_TO_CREATE.md`](.github/ISSUES_TO_CREATE.md)
- `README.md` (public summary)

### v0.4.0 — Developer Command Center

**Status:** Shipped.

### v0.5.0 — Repository Intelligence

**Status:** Current release.

Repository state model, safe sync, health, repair, cleanup, reporting, Deployment Manager.

### v0.5.x — Stabilization

**Focus:** Polish, screenshots, installer edge cases, clean install validation, and real-world
validation against very large workspaces.

**Remaining:**

- README screenshots
- Clean Windows install test
- Installer polish
- Sync performance validation at ~300 repositories
- Edge-case fixes

Potential work: favorites, project profiles, workspace profiles, project launch workflows, self-update improvements, guided publish workflow.

### v1.0 — Stable Public Release

Goals: stable command interface, complete documentation, mature onboarding, reliable automated validation, contributor-friendly workflow, installation packaging.

---

## Architecture

### Repository structure

```text
dev.cmd / dev-core.ps1     Entry point (dev.cmd is the public launcher; dev-core.ps1 is the real script)
install.ps1                Recommended PATH installer (`powershell -ExecutionPolicy Bypass -File install.ps1`)

commands/                  User-facing commands (thin wrappers)
lib/                       Shared business logic
docs/                      User and developer documentation
tests/                     Validation scripts (CI support)
.github/                   CI, issue templates, maintainer docs
config/                    Local runtime data (gitignored)
config.example.json        Example settings (committed)
VERSION                    Single source for version string
```

### `lib/` modules

| Module | Responsibility |
| --- | --- |
| `utils.ps1` | Command detection, version helpers, prompts |
| `copy.ps1` | Product mission, status labels, Doctor copy catalog |
| `ui.ps1` | Screens, headers, menus, display symbols (emoji/ASCII), formatting |
| `config.ps1` | Load/save `config.json`, first-run setup |
| `git.ps1` | Workspace repo discovery, Git availability, backward-compatible status projection |
| `repo-git.ps1` | Git result model, porcelain v2 parsing, fetch/prune, raw repository facts |
| `repo-state.ps1` | Pure classification, safe-update policy, filters, summaries (no Git, no UI) |
| `repo-sync.ps1` | Workspace state collection and the fast-forward-only sync engine |
| `repo-repair.ps1` | Upstream repair safety rules, merged-branch cleanup |
| `repo-report.ps1` | Repository diagnostic reports (JSON + Markdown-style text), sanitization |
| `repo-ui.ps1` | Repository Health, Sync, maintenance menus, repair/cleanup/actions flows |
| `github.ps1` | GitHub CLI helpers, auth check, repo listing |
| `doctor.ps1` | Environment checks, system status, interactive fixes |
| `home.ps1` | Home dashboard, adaptive actions, GitHub sign-in flow |
| `projects.ps1` | Workspace project list, search, open-with-editor |
| `recent.ps1` | Recent project storage and pickers |
| `project-info.ps1` | Project inspection, stack detection, info actions |
| `test.ps1` | Automated test runner wrapper and optional-tool reports |
| `self.ps1` | User PATH install, uninstall, and diagnostics |
| `deploy-config.ps1` | Deployment settings, name normalization, eligibility rules (pure) |
| `deploy-github.ps1` | Repository discovery and remote deployability inspection via `gh` |
| `deploy-vercel.ps1` | Vercel REST client, pagination, deployment polling, HTTP health check |
| `deploy-model.ps1` | Repository/project matching, classification, planning (pure) |
| `deploy-report.ps1` | Deployment tables, summaries, JSON report generation |
| `deploy.ps1` | Deployment Manager orchestration and menu |

### Guidelines

- Business logic belongs in `lib/`.
- Commands should remain thin wrappers.
- Avoid duplicated code; prefer shared helpers in `lib/projects.ps1` for search/open flows.
- Keep modules focused.
- Do not use the GitHub REST API directly — use GitHub CLI (`gh`), including `gh api`, where needed.
- Deployment discovery and reporting must stay read-only. Only `dev deploy sync` mutates, and only after explicit confirmation.
- Repository state has one source of truth. Do not add parallel Git status parsing to commands.
- Keep the layers separate: acquisition -> classification -> recommended action -> rendering -> mutation. Classification stays pure and testable without Git.
- Prefer Git plumbing (`rev-parse`, `status --porcelain=v2`, `for-each-ref`, `symbolic-ref`, `rev-list`) over parsing localized Git prose.
- DevTools must never automatically run `reset`, `clean`, `stash`, any force operation, conflict resolution, merges or rebases of diverged history, commits, pushes, branch switches that risk local work, or deletion of unmerged branches. When uncertain: skip and explain.
- Never store credentials in tracked files. Deployment credentials come from the environment.
- Do not build a provider plugin framework. Vercel is the supported provider today.
- Do not rewrite `dev-core.ps1` into a monolith.
- Do not add a root-level `dev.ps1` — PowerShell may prefer it over `dev.cmd` on PATH.

### Configuration and local data

| File | Purpose | Committed |
| --- | --- | --- |
| `config.json` | User settings | No (gitignored) |
| `config/recent-projects.json` | Recent project history | No (gitignored) |
| `reports/deployments/latest.json` | Latest deployment report | No (gitignored) |
| `reports/repositories/latest.json` | Latest repository diagnostic report | No (gitignored) |
| `reports/repositories/latest.txt` | Pasteable repository diagnostic report | No (gitignored) |
| `config.example.json` | Template for new installs | Yes |

Settings: `workspacePath`, `githubOwners`, `defaultEditor`, `autoBackupMessage`, `autoUpdate` (reserved), `deployments` (optional).

Existing `config.json` files must keep loading. New sections are optional and receive safe defaults when missing.

---

## Documentation Structure

Each document has a single responsibility.

| Document | Audience | Purpose |
| --- | --- | --- |
| `PROJECT_CONTEXT.md` | Maintainers, AI | Vision, architecture, priorities |
| `README.md` | Public | Landing page, install, quick start |
| `docs/commands.md` | Users | Detailed command reference |
| `docs/installation.md` | Users | Clone, global install, PATH management |
| `docs/configuration.md` | Users | Settings and config.json |
| `docs/roadmap.md` | Public | Milestone summary |
| `docs/faq.md` | Users | Common questions |
| `docs/architecture.md` | Contributors | High-level structure |
| `docs/deployments.md` | Users | Deployment Manager guide |
| `docs/testing.md` | Maintainers | Automated and smoke testing overview |
| `docs/commands.md` (Repository Intelligence) | Users | Sync, health, repair, cleanup, reports |
| `docs/testing/` | Maintainers | Smoke test process |
| `CHANGELOG.md` | Public | Release history |
| `CONTRIBUTING.md` | Contributors | How to contribute |
| `.github/` | Maintainers | Issues, labels, milestones, CI |

Avoid duplicating information across files. README introduces; PROJECT_CONTEXT guides development; GitHub Issues track future work.

---

## UX Philosophy

DevTools should feel like an application — not a collection of scripts.

**Home** answers: *Am I ready to build?*  
**Doctor** answers: *Why is this happening? How do I fix it?*

Every screen should answer: *What should I do next?*

Use calm language, beginner-friendly wording, consistent menus, actionable guidance, and minimal cognitive load. Avoid exposing raw tool output when a clearer DevTools-native message can be shown (especially on Home).

Status labels prefer **Ready to Build**, **Almost Ready**, **Setup Recommended** — not Failed/Broken/Error unless something actually crashes.

---

## Coding Standards

**Prefer**

- Modular functions
- Descriptive names
- Small files
- Reusable logic in `lib/`
- Consistent command patterns
- PowerShell 5.1 compatibility where practical

**Avoid**

- Monolithic scripts
- Hidden side effects
- Duplicate logic across commands
- Breaking existing workflows without good reason
- Unnecessary dependencies
- Automatic git commit/push without user confirmation

---

## Design Principles

Every feature should save time, reduce repetition, improve clarity, require little configuration, and scale to many repositories.

Before implementing, ask: *Would a developer use this every week?*

If not, add a GitHub Issue to the backlog instead of expanding the current milestone.

---

## Current Priorities

**Highest**

- v0.5.x stabilization: validate sync against a real ~300-repository workspace, README screenshots, clean install validation
- Documentation sync with shipped features
- Keep CI green

**Medium**

- Sync performance tuning if fetch-per-repository proves too slow at scale
- Favorites, project profiles, workspace profiles, launch workflows
- Polish Recent Projects, Project Info, and Quick Actions based on feedback

**Lower**

- Themes
- Plugin system
- Cross-platform exploration

---

## Release Process

Before every release:

1. Update `CHANGELOG.md` and `VERSION`
2. Complete [docs/testing/smoke-test.md](docs/testing/smoke-test.md)
3. Run `tests/Test-DevTools.ps1` (CI runs this on push/PR)
4. Review `README.md` and `docs/commands.md`
5. Review open Issues and milestones
6. Create GitHub Release, tag version, publish release notes

---

## Decision Log

Significant decisions (append new entries; do not delete history).

| Date | Decision | Rationale |
| --- | --- | --- |
| — | **Windows-first** | Primary audience uses Windows; PowerShell is native; cross-platform deferred to Future. |
| — | **PowerShell + modular `commands/` / `lib/`** | Replace monolithic script; easier to test, review, and extend. |
| — | **`dev.cmd` as recommended launcher** | Avoids execution policy friction for beginners. |
| — | **Home as default command** | Answers readiness first; menu is secondary. |
| — | **Doctor vs Home split** | Home = readiness at a glance; Doctor = detailed diagnostics and fixes. |
| — | **No GitHub API in DevTools** | Use `gh` CLI only; simpler auth and maintenance. |
| — | **Roadmap via GitHub Issues** | No automatic issue creation; `.github/ISSUES_TO_CREATE.md` for manual seeding. |
| — | **README stays concise** | Detailed commands in `docs/commands.md`; README is the public landing page. |
| — | **PROJECT_CONTEXT.md exists** | Single internal doc for AI and maintainers; reduces context loss across sessions. |
| — | **Manual smoke tests + CI syntax checks** | CI validates structure/syntax; human smoke test catches UX regressions before release. |
| — | **Recent data in `config/` (gitignored)** | User-specific; not committed. |
| — | **Backup always confirms** | Safety over automation; no silent commits or pushes. |
| — | **Display symbols with ASCII fallback** | `Get-DevToolsDisplaySymbol` avoids Unicode rendering errors on legacy consoles. |
| — | **Home accepts empty attention items** | `[AllowEmptyCollection()]` plus ready-state copy when all required checks pass. |
| — | **User PATH via `dev self install`** | Safe global `dev` access; User PATH only; conflict detection before install. |
| — | **Repository health uses one shared state model consumed by status, sync, repair, and reporting** | Removes duplicated Git parsing across commands and keeps every screen consistent. |
| — | **Bulk repository sync is conservative and fast-forward-only. Unsafe repository states are classified and reported rather than automatically modified** | Losing local work is worse than an out-of-date repository. When uncertain, skip and explain. |
| — | **Git plumbing over Git prose** | `status --porcelain=v2 --branch` is stable and locale-independent; parsing human-readable output is fragile. |
| — | **`dev sync` added, `dev update` kept as an alias** | Sync is the honest name for the workflow; breaking existing scripts is not acceptable. |
| — | **Repository reports live in gitignored `reports/repositories/`** | Matches the deployment report convention; remote URLs are sanitized so credentials never reach disk. |
| — | **Branch deletion requires proof of merge** | `git branch -d` only, never `-D`; stale is not the same as safe. |

---

## Guidance for AI Assistants

When assisting with DevTools:

- Read `PROJECT_CONTEXT.md` before making recommendations.
- Treat this file as the project's internal source of truth.
- Preserve backward compatibility whenever practical.
- Prefer incremental improvements over rewrites.
- Keep documentation synchronized with code (`README`, `docs/commands.md`, `CHANGELOG`).
- Suggest new GitHub Issues rather than expanding the current milestone without maintainer intent.
- Respect the existing architecture (`commands/` thin, `lib/` thick).
- Optimize for daily developer workflows.
- Minimize complexity.
- Do not invent features that are not in the repository.
- Do not change application behavior when asked for documentation-only tasks.
- If a proposed feature does not clearly improve the daily experience, recommend backlog instead of immediate implementation.

**Useful commands for validation**

```powershell
powershell -ExecutionPolicy Bypass -File ./tests/Test-DevTools.ps1
.\dev.cmd
.\dev.cmd doctor
.\dev.cmd help
```

---

## Maintaining PROJECT_CONTEXT.md

Update when:

- Vision or mission shifts
- Current milestone changes
- Architecture changes (new `lib/` modules, new patterns)
- Major design decisions are made
- Shipped features change the roadmap balance

Do **not** update for every minor bug fix.

Keep this file concise (roughly 3–5 pages). It should remain the authoritative engineering and product context for the repository.

**Last reviewed:** Align with `VERSION` and repository state when editing.
