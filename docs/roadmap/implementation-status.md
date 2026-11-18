# DevRepo implementation status

| Phase | Feature | Status | Relevant files | Tests | Blocker or next step |
| --- | --- | --- | --- | --- | --- |
| 0 | Baseline audit and planning | Complete | [Architecture](../architecture/current-state.md), [target](../architecture/target-state.md), [migration](../architecture/migration-plan.md), [UX](../ux/interaction-principles.md), [roadmap](devrepo-roadmap.md) | Audited against main at `47608fd` | Start primary CLI migration |
| 1 | Dual launchers, Home, primary navigation, guided setup, download and update flows | Implemented and validated with automated tests | `devrepo.cmd`, `dev-core.ps1`, `commands/`, `lib/ui.ps1`, `lib/home.ps1` | CLI fixtures on Linux and Windows PowerShell 5.1/7, Linux keyboard smoke, scripted download and setup smoke, 214 Git assertions and 123 deployment assertions | Fresh Windows User PATH installation and hardware-specific ARM64 smoke remain. Some advanced prompts still use typed input. |
| 2 | Command grouping, JSON reads and local sync preview | Implemented for status, doctor, projects list and sync preview | `lib/automation.ps1`, `dev-core.ps1`, [command contract](../commands.md#automation) | CLI fixtures cover JSON, dry run, aliases, unsupported options and unsafe sync rejection | Extend automation to other operations and unify remaining interactive exit paths |
| 2 | Versioned user settings and workspace overrides | Planned | `lib/config.ps1` | No migration coverage yet | Keep existing config fields and establish per-user/override precedence before moving storage |
| 3–8 | Runner and workspaces through desktop and release | Planned | [Roadmap](devrepo-roadmap.md) | Pending | Complete Phase 2 contracts and configuration migration |

The [Windows CI run](https://github.com/Novenworks/dev-tools/actions/runs/44392540601) passed in Windows PowerShell 5.1 and PowerShell 7 for implementation commit `724cb4f`. The Windows jobs exercised both launchers.
