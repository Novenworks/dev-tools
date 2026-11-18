# Migration plan

1. Add `devrepo.cmd` beside `dev.cmd`, with both forwarding arguments and exit codes into the same core. Keep checkout paths, settings, reports, environment overrides and technical command names. Validate PATH conflicts for both launchers.
2. Share primary menu dispatch and action labels. Preserve the numbered Main Menu and Quick Actions shortcuts. Make mutating batch operations disclose scope and require approval. Guide users through existing setup, editor, GitHub and deployment tools.
3. Add structured local reads one at a time using already-tested repository and diagnostics logic. Keep the interactive defaults and publish schema and exit-code contracts before adding more consumers.
4. Load current config shapes without rewriting them at startup. Introduce versioned storage behind compatibility reads, schema tests and save/rollback handling. Preserve unknown keys and keep tokens outside config.
5. Add runner and workspace features behind explicit commands. Resolve paths before process launch and retain ownership information before offering a stop action.
6. Add diagnostics, GitHub views and optional AI handoff over small, independently tested operations. Validate redaction and rate limits before remote use.
7. Record the desktop framework decision and validate the CLI bridge before feature implementation. Test from fresh Windows profiles, including ARM64 when available, before release packaging.

Compatibility risks include PATH command precedence, pause and exit behavior, script callers expecting direct sync/clone execution, settings overwritten by setup, project folder discovery and outputs consumed by scripts. Test both launchers and old settings, preserve aliases and explain the new confirmation boundary in migration notes. Leave the repository name, release publishing and package distribution as separate user decisions.
