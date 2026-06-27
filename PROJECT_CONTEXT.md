# DevTools — Project Context

**Version:** v0.3.x (see `VERSION`)  
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
- Home dashboard with system status and collapsed checklist
- Main menu and Help
- Quick Actions (`quick`) for frequent tasks

**Environment**

- Doctor with required/optional checks and interactive fixes
- DevTools-native GitHub sign-in messaging on Home (no raw `gh auth status` on Home)

**Repository workflows**

- Clone missing GitHub repositories (`gh`, no GitHub API in DevTools)
- Multi-repository update (`git pull`)
- Repository status (clean, modified, ahead, behind, conflicts)
- Safe backup (always confirms before commit/push)

**Projects**

- Open project with partial name search (`open`, `open <name>`)
- Recent Projects (`recent`) — local history, shown on Home when available
- Project Info (`info`, `info <name>`) — Git metadata, inferred stack, quick actions

**Quality and community**

- Manual smoke test checklist (`docs/testing/smoke-test.md`)
- Automated validation (`tests/Test-DevTools.ps1`, GitHub Actions CI)
- GitHub issue templates, labels/milestones docs, seed issue list

**Commands (entry point: `dev` / `dev.cmd`)**

`home`, `menu`, `quick`, `recent`, `info`, `configure`, `settings`, `doctor`, `clone`, `update`, `status`, `backup`, `open`, `help`

Update this section when features ship or are removed.

---

## Non-Goals

DevTools is intentionally **not**:

- a Git replacement
- an IDE
- a package manager
- a deployment platform
- a cloud service
- a project management application
- cross-platform (today — Windows only)

Maintain a focused scope.

---

## Current Milestone

**v0.3.x — Public Polish**

Objectives:

- Improve onboarding and Home experience
- Polish UX copy and menus
- Stabilize commands before broader sharing
- Complete public documentation
- Publish first public GitHub release
- Gather early user feedback

**Next patch focus (v0.3.1 — Stability):** See [`.github/milestones.md`](.github/milestones.md) and [`.github/ISSUES_TO_CREATE.md`](.github/ISSUES_TO_CREATE.md).

---

## Roadmap

Roadmap detail lives in GitHub Issues, labels, and milestones. See:

- [`.github/milestones.md`](.github/milestones.md)
- [`.github/ISSUES_TO_CREATE.md`](.github/ISSUES_TO_CREATE.md)
- `README.md` (public summary)

### v0.4 — Daily Workflow

**Focus:** Make DevTools faster to use every day.

**Shipped in repo (may predate next CHANGELOG entry):**

- Recent Projects
- Project search (Open Project)
- Project Info
- Quick Actions screen

**Still planned:**

- Favorite projects
- Better progress indicators (clone, update, backup)
- Multi-editor support
- GitHub release package
- Self-update command
- README screenshots and onboarding polish

### v0.5 — Power User

**Focus:** Scale to larger development environments.

Potential work: workspace profiles, project profiles, project templates, plugin system, launch workflows, auto updater.

### v1.0 — Stable Public Release

Goals: stable command interface, complete documentation, mature onboarding, reliable automated validation, contributor-friendly workflow, installation packaging.

---

## Architecture

### Repository structure

```text
dev.ps1 / dev.cmd          Entry point (dev.cmd bypasses execution policy)
install.ps1                Optional PATH setup

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
| `ui.ps1` | Screens, headers, menus, formatting |
| `config.ps1` | Load/save `config.json`, first-run setup |
| `git.ps1` | Repository status, pull, workspace repo discovery |
| `github.ps1` | GitHub CLI helpers, auth check, repo listing |
| `doctor.ps1` | Environment checks, system status, interactive fixes |
| `home.ps1` | Home dashboard, adaptive actions, GitHub sign-in flow |
| `projects.ps1` | Workspace project list, search, open-with-editor |
| `recent.ps1` | Recent project storage and pickers |
| `project-info.ps1` | Project inspection, stack detection, info actions |

### Guidelines

- Business logic belongs in `lib/`.
- Commands should remain thin wrappers.
- Avoid duplicated code; prefer shared helpers in `lib/projects.ps1` for search/open flows.
- Keep modules focused.
- Do not use the GitHub REST API — use GitHub CLI (`gh`) where needed.
- Do not rewrite `dev.ps1` into a monolith.

### Configuration and local data

| File | Purpose | Committed |
| --- | --- | --- |
| `config.json` | User settings | No (gitignored) |
| `config/recent-projects.json` | Recent project history | No (gitignored) |
| `config.example.json` | Template for new installs | Yes |

Settings: `workspacePath`, `githubOwners`, `defaultEditor`, `autoBackupMessage`, `autoUpdate` (reserved).

---

## Documentation Structure

Each document has a single responsibility.

| Document | Audience | Purpose |
| --- | --- | --- |
| `PROJECT_CONTEXT.md` | Maintainers, AI | Vision, architecture, priorities |
| `README.md` | Public | Landing page, install, quick start |
| `docs/commands.md` | Users | Detailed command reference |
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

- Stability (v0.3.1 items: onboarding edge cases, emoji fallbacks, clean install validation)
- Documentation and README screenshots
- Onboarding polish
- Keep CI green

**Medium**

- v0.4 remainder: favorites, progress indicators, multi-editor, release package, self-update
- Polish Recent Projects, Project Info, and Quick Actions based on feedback

**Lower**

- Themes
- Plugin system
- Workspace profiles
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
