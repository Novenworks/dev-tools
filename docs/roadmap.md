# DevTools Roadmap

Public summary of DevTools milestones. Detailed issue tracking lives in GitHub Issues and [`.github/milestones.md`](../.github/milestones.md).

---

## v0.4.0 — Developer Command Center

**Status:** Shipped.

**Completed:**

- Global install
- Recent Projects
- Project Info
- Quick Actions
- `dev test`
- `dev self`
- Automated validation
- GitHub Actions CI
- Documentation structure
- Improved installation flow

---

## v0.5.0 — Repository Intelligence

**Status:** Current release.

**Completed:**

- One shared repository state model behind status, sync, repair, and reporting
- `dev sync` — fetch, classify, and fast-forward only what is safe (`dev update` still works)
- Repository Health (`dev status`) with counts and filters for large workspaces
- Detailed classifications replacing "Could not update"
- Guided upstream repair for deleted remote branches
- Safe merged-branch cleanup
- Repository maintenance menu (`dev repos`) and single-repository actions
- Diagnostic report export (`reports/repositories/`)
- Progress feedback at ~300-repository scale
- Deployment Manager (`dev deploy`) — audit, plan, sync, and verify Vercel projects
- Behavioral test suite with local Git fixtures

---

## v0.5.x — Stabilization

**Focus:** Polish and reliability before expanding scope.

**Remaining:**

- README screenshots
- Clean Windows install test
- Installer polish
- Real-world validation against very large workspaces
- Edge-case fixes from early user feedback

**Potential:**

- Favorites
- Project profiles
- Workspace profiles
- Project launch workflows
- Self-update improvements
- Guided publish workflow

---

## v1.0 — Stable Public Release

**Goals:**

- Stable command interface
- Complete documentation
- Mature onboarding
- Reliable automated validation
- Contributor-friendly workflow
- Installation packaging

---

## Future ideas

- Plugin system
- Cross-platform support
- AI-assisted project summaries
- Dev server launch support

See [`.github/ISSUES_TO_CREATE.md`](../.github/ISSUES_TO_CREATE.md) for issue drafts.
