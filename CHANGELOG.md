# Changelog

All notable changes to DevTools are documented here.

## Unreleased

**Deployment Manager**

### Added

- `dev deploy` — interactive Deployment Manager for Vercel
- `dev deploy audit` — read-only portfolio audit comparing GitHub repositories against Vercel
- `dev deploy plan` — read-only dry run showing exactly what `sync` would create
- `dev deploy sync` — creates missing Vercel projects and starts first production deployments, always after explicit confirmation (`--apply` for automation)
- `dev deploy verify` — read-only production verification with an optional lightweight HTTP check
- `dev deploy status` and `dev deploy help`
- Conservative repository eligibility rules (`*demo*` by default), explicit include/exclude lists, and per-repository production branch overrides
- Remote deployability inspection through `gh api` with framework detection (Next.js, Nuxt, Astro, SvelteKit, Vite, React, Vue, static HTML)
- Safe repository-to-project matching: Git integration metadata, then explicit mapping, then a single unambiguous normalized name — otherwise `AMBIGUOUS_MATCH`
- Machine-readable reports in the gitignored `reports/deployments/latest.json`
- Deployment Tools readiness section in `dev doctor` (Vercel stays optional)
- Optional `deployments` section in `config.json`
- `tests/Test-Deploy.ps1` — Deployment Manager test suite with fully mocked GitHub and Vercel
- `docs/deployments.md` — full Deployment Manager guide

### Changed

- Main menu now includes Deployment Manager (15 options)
- Saving preferences preserves settings owned by other features
- `dev test` also runs the Deployment Manager suite and scans for committed token literals

### Security

- The Vercel token is read from `VERCEL_TOKEN` only. It is never stored in `config.json`, written to a report, or printed.

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
