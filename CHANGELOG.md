# Changelog

All notable changes to DevTools are documented here.

## v0.5.0

**Repository Intelligence**

DevTools no longer treats `git pull` as the whole synchronization model. It now fetches, inspects,
classifies, safely updates, reports, and helps repair — which matters most in large workspaces with
hundreds of repositories, including branches created by AI coding agents.

### Added

- `dev sync` — refreshes GitHub state and safely fast-forwards only the repositories that can be updated without touching local work
- `dev repos` — Repository Maintenance menu: sync, health, review attention, repair upstreams, branch cleanup, report export, and single-repository actions
- Repository Health (`dev status`) — workspace counts plus filters for all, attention, modified, behind, ahead, diverged, broken upstreams, and conflicts/operations in progress
- One shared repository state model consumed by status, sync, Project Info, repair, and reports (`lib/repo-git.ps1`, `lib/repo-state.ps1`, `lib/repo-sync.ps1`, `lib/repo-repair.ps1`, `lib/repo-report.ps1`, `lib/repo-ui.ps1`)
- Detailed classifications: Updated, Current, Local changes, Ahead, Behind, Diverged, Missing upstream, Upstream gone, Detached HEAD, Conflicts, Merge in progress, Rebase in progress, Operation in progress, No remote, Sign-in required, Remote unavailable, Refresh failed, Not a repository, and Git error
- A plain-language explanation, a "your work is safe" note, and a recommended action for every unhealthy state
- Guided upstream repair for branches whose remote branch was deleted after a merged pull request
- Safe merged-branch cleanup that only offers deletion when Git can prove a branch is fully merged
- Single-repository actions menu, reachable from Project Info and Repository Maintenance
- Diagnostic reports in the gitignored `reports/repositories/` folder (`latest.json` and a pasteable `latest.txt`)
- Compact progress output such as `[42/298] Checking bella-demo...` for large workspaces
- `tests/Test-Repos.ps1` — behavioral tests using throwaway Git repositories and local bare remotes, proving no local work is lost

### Changed

- `dev update` now routes into the sync workflow and stays supported for existing scripts
- Repository state is read with Git plumbing (`status --porcelain=v2 --branch`, `rev-parse`, `for-each-ref`, `symbolic-ref`) instead of parsing localized Git prose
- Bulk updates are fast-forward only and never create a merge commit
- `Get-RepoStatusDetails` keeps its shape but is now a projection of the shared state model
- Main menu now has 16 options; Quick Actions surfaces Repository Health, Sync, and Repository Maintenance
- Sync refreshes remote state with `git fetch --prune` before classifying; Repository Health opens with a fast local read and refreshes on request

### Fixed

- `Could not update: repo-name` is replaced by an actionable reason, for example `Skipped: OldDemo - local changes` or `Skipped: AgentBranch - origin/claude/rebuild-homepage no longer exists`
- A failure in one repository no longer affects the rest of the batch

### Security

- Credentials embedded in remote URLs are stripped before anything is written to a report or shown in the UI
- Git error text in reports is sanitized and length-bounded

### Deployment Manager

Previously unreleased. Ships as part of v0.5.0.

#### Added

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

#### Changed

- Main menu now includes Deployment Manager (15 options)
- Saving preferences preserves settings owned by other features
- `dev test` also runs the Deployment Manager suite and scans for committed token literals

#### Security

- The Vercel token is read from `VERCEL_TOKEN` only. It is never stored in `config.json`, written to a report, or printed.

---

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
