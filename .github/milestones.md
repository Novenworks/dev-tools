# Planned Milestones

DevTools uses GitHub milestones to group related work. Create these milestones manually in **Issues → Milestones**.

---

## v0.4.0 — Developer Command Center

**Status:** Shipped.

**Shipped:**

- Global install and global `dev` command
- Recent Projects, Project Info, Quick Actions
- `dev test` and `dev self`
- Automated validation and GitHub Actions CI
- Improved installation flow and documentation structure

---

## v0.5.0 — Repository Intelligence

**Status:** Current release.

**Shipped:**

- Shared repository state model (`lib/repo-*.ps1`)
- `dev sync` with fast-forward-only bulk updates, and `dev update` as an alias
- Repository Health (`dev status`) with attention filters
- Detailed repository classifications and recommended actions
- Guided upstream repair and safe merged-branch cleanup
- Repository maintenance menu (`dev repos`) and single-repository actions
- Diagnostic report export
- Behavioral repository tests with local Git fixtures

---

## v0.5.x — Stabilization

**Purpose:** Polish and reliability after v0.5.0.

**Issues:**

- Add README screenshots
- Test clean Windows install flow
- Installer polish
- Validate sync performance against a ~300-repository workspace
- Onboarding edge-case fixes
- Add favorite projects
- Add project profiles
- Add workspace profiles
- Add project launch workflows
- Self-update improvements
- Guided publish workflow

---

## v1.0 — Stable Public Release

**Purpose:** Stable public-ready release with documentation, packaging, and clear contribution workflow.

**Issues:**

- Finalize README and screenshots
- Add installation package
- Security policy review
- Release checklist validation
- Validate clean install path on fresh Windows

---

## Future Ideas

- AI project summaries
- Launch dev server automatically
- `.devtools.json` project profiles
- Cross-platform support
- Website landing page

See `.github/ISSUES_TO_CREATE.md` for copy-paste issue drafts.
