# Changelog

All notable changes to DevTools are documented here.

## v0.4.0

**Developer Command Center**

### Added

- Global `dev` command support
- Safer CMD launcher to avoid PowerShell execution policy friction
- `dev test` command
- `dev self` namespace (test, update, version, doctor, info, PATH management)
- Recent Projects
- Project Info command
- Quick Actions improvements
- Automated validation test runner
- GitHub Actions CI
- Manual smoke test documentation
- `PROJECT_CONTEXT.md` as internal project source of truth
- Improved documentation structure

### Changed

- README now focuses more on public onboarding
- Documentation moved into dedicated `docs/` guides
- Installation flow simplified (`install.ps1` with clear next steps)
- Test runner now includes a Development Environment summary
- PSScriptAnalyzer missing state now explains how to install it
- PowerShell entrypoint renamed to `dev-core.ps1` for reliable global launch
- `dev self path` shows resolved launcher paths and PATH conflicts

### Fixed

- Home screen now handles zero attention items
- Global launcher now avoids execution policy errors
- GitHub login flow no longer exposes raw CLI output where avoidable
- Help screen parameter edge cases
- Unicode/status indicator fallback issues on legacy consoles

### Notes

This release moves DevTools from a repository utility toward a lightweight developer command center.

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
