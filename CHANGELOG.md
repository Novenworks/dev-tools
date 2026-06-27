# Changelog

All notable changes to DevTools are documented here.

## Unreleased

### Added

- Quick Actions screen (`dev quick`) for frequent update, open, status, and clone tasks
- Recent Projects (`dev recent`) with local history in `config/recent-projects.json`
- Project Info (`dev info`, `dev info <name>`) with Git metadata, inferred stack, and quick actions
- Project search for Open Project (`dev open`, `dev open <name>`)
- GitHub Actions CI (`.github/workflows/ci.yml`)
- Automated validation script (`tests/Test-DevTools.ps1`)
- Manual smoke test checklist (`docs/testing/`)
- GitHub issue templates, labels/milestones docs, and seed issue list (`.github/`)
- Detailed command reference (`docs/commands.md`)
- Internal maintainer context (`PROJECT_CONTEXT.md`)
- Home Recent Projects section and **O** shortcut when recents exist
- `dev test` command for automated validation from any directory
- Development Environment summary in the automated test runner (required and optional dev tools)
- `dev self` namespace for DevTools self-management (interactive menu, test, update, version, doctor, info)
- `dev self install`, `dev self uninstall`, and `dev self path` for safe user PATH management
- Friendly optional-tool reporting for PSScriptAnalyzer in the test runner

### Fixed

- Home screen no longer errors when all required checks pass (empty attention items)
- Home ready state now shows “Everything required is ready.”
- Status and checklist symbols use safe display helpers with ASCII fallbacks on legacy consoles

### Changed

- Main menu expanded with Quick Actions, Recent Projects, and Project Info
- Home uses System Status focal point with collapsed Required/Optional checklist
- DevTools-native GitHub sign-in messaging on Home (no raw `gh auth status` output)

---

## v0.3.0

First public polish release.

**Included:**

- Home dashboard
- Guided setup
- Doctor checks
- GitHub repository cloning
- Repository status
- Safe backup flow
- Settings and Help
- Beginner-friendly copy
