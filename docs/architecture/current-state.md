# Current architecture

Audit baseline is main at `47608fd` (v0.5.0). This describes the application before the DevRepo migration.

## Execution and data

`dev.cmd` invokes Windows PowerShell with `dev-core.ps1`. Core dot-sources shared libraries, initializes checkout-local settings and dispatches into `commands/`. Command scripts share script-scope configuration and can exit the host. The first-run wizard intercepts most commands, including help. Some menus shell out through the launcher while others dot-source commands. That leads to different back, pause and exit behavior.

`install.ps1` and `lib/self.ps1` install the checkout directory on User PATH, diagnose launcher conflicts and update the existing Git checkout. Configuration and recents live in gitignored `config.json` and `config/recent-projects.json`. Reports live under `reports/`. Existing deployment settings are optional. GitHub CLI owns its authentication, and Vercel reads its token from the process environment.

Repository acquisition, classification and mutation are already distinct. `repo-git` reads porcelain v2 status, tracking refs and in-progress Git operations. `repo-state` classifies facts and produces shared summaries. `repo-parallel` bounds remote fetch concurrency, and `repo-sync` inspects refreshed states then rechecks before fast-forwarding. `repo-repair` and `repo-ui` handle upstream repair, branch actions and confirmed cleanup. Local health is based on known tracking refs until explicitly refreshed. `projects` includes ordinary folders as well as repositories, while repository inventory uses immediate child directories with Git metadata. Project Details adds stack hints and Git metadata.

Deployment Manager already has separate configuration, GitHub and Vercel adapters, matching and planning, report output and interactive orchestration. It filters eligible websites and supports confirmed project creation or deployment. Portfolio scans can fan out to remote service calls. Current tests mock both providers. Audit, plan and verify may save local reports.

## Feature inventory

| Status | Features and entry points |
| --- | --- |
| Implemented | Default `home`, numbered `menu` and `quick`; `configure`, `settings`, `doctor`, `help`; project search with `open [name]`, `recent` and `info [name]`; local health, refresh and reports with `status`; safe bulk `sync` with `update` alias; `clone`, `backup`; `repos` maintenance and single-project actions; `deploy audit/plan/sync/verify/status/settings/help` with `--owner`, `--apply`/ `--yes`, `--no-http`; `test`; `self test/update/version/doctor/info/install/uninstall/path`. |
| Partial | Recent usage metadata has no favorites or presets. Stack labels exist for Project Details but cannot produce a runner plan. JSON and text report files exist, but stdout has no command contract. Setup checks whether an editor is configured rather than whether it is installed. Installer works through User PATH but desktop and clean Windows validation remain manual. |
| Documented only | Automatic app updates are a reserved preference. Contributor roadmap mentions release packaging, clean install and large-workspace validation without evidence that those checks run in CI. |
| Proposed | Workspace profiles, project runner, richer diagnostics, PR and CI dashboards, AI launch and handoff, desktop and public packaging. |

## Constraints and findings

- `lib/git.ps1` has legacy pull helpers alongside the repository-intelligence engine. Backup and project metadata also use separate Git wrappers. Keep compatibility projections and migrate callers to a shared process boundary gradually.
- Home computes setup state more than once per draw. Full Git status across hundreds of repositories is too expensive for every menu redraw. Count folders cheaply and reuse a local health scan with an explicit freshness label.
- Command dispatch uses input as a relative filename. Replace it with a fixed command table. Report reads, config writes and native command failures have uneven error and exit handling. A reset-free bulk sync does not imply that application's own `self update` is fast-forward-only at baseline.
- Setup rewrites core preferences from a newly constructed object and can drop optional deployment or concurrency settings. Direct settings edits preserve extra fields, but writes are in-place and schema checks are shallow.
- Most menus rely on Read-Host and color. The symbol layer has an ASCII fallback. Editor launching prints success without checking the external command result, and nested flows can exit the top-level session.
- Windows assumptions include `cmd.exe`, User PATH, Explorer, WinGet, Windows PowerShell 5.1, environment-derived AppData and Windows default paths. Desktop validation will need x64 and ARM64 installer and runtime checks.
- CI currently runs one Windows PowerShell 7 job. The runner parses scripts and calls Git-fixture and mocked-deployment suites. Existing tests do not exercise keyboard navigation or a clean User PATH install.
