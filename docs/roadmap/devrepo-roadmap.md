# DevRepo roadmap

The migration builds on the v0.5.0 repository and deployment models. See the [baseline audit](../architecture/current-state.md), [target architecture](../architecture/target-state.md) and [migration plan](../architecture/migration-plan.md). Track implementation and validation in [Implementation status](implementation-status.md).

| Phase | Delivery | Exit gate |
| --- | --- | --- |
| 0. Audit | Inventory commands, config, operations, tests and Windows assumptions | Document baseline, hazards and incremental migration |
| 1. CLI experience | Dual launchers, Home tasks, plain-English menus, keyboard controls and guided results | Both launchers, safe mutation prompts, recovery paths and Windows smoke |
| 2. Automation | Shared operations, scoped command grammar, structured output, exit codes and configuration migration | Validate JSON, legacy CLI compatibility and noninteractive safety |
| 3. Workspaces and runner | Stack detection, runtime and script selection, owned processes and profiles | Fixtures for supported stacks and lifecycle tests |
| 4. Diagnostics | Environment and project checks, ports, guided repairs, sanitized reports | Optional tool and redaction tests, including on Windows |
| 5. GitHub | PRs, CI, activity and existing maintenance tooling | Rate-limit behavior and write-safety coverage |
| 6. AI | Local tool launch and sanitized handoff; optional consent-based providers | Core offline and external transfer opt-in checks |
| 7. Desktop | Framework decision, shared bridge, accessible desktop interface and packaging | Windows installation, command boundary and long-running task tests |
| 8. Release | Stable packaging, CI, guides, changelog, compatibility matrix | Clean Windows install, verified artifacts and separate approval to publish |
