# GitHub Issues to Create

Copy each section below into a new GitHub Issue. Create milestones and labels first using `.github/labels.md` and `.github/milestones.md`.

---

## Completed in v0.4.0

These items shipped in v0.4.0. Do not recreate as open issues unless follow-up polish is needed.

- Global install and global `dev` command (`install.ps1`, `dev.cmd` launcher)
- `dev test` automated validation
- `dev self` namespace (test, update, version, doctor, info, PATH)
- Recent Projects (`dev recent`)
- Project Info (`dev info`)
- Quick Actions (`dev quick`)
- Project search for Open Project (`dev open`)
- GitHub Actions CI
- Smoke test documentation
- `PROJECT_CONTEXT.md`
- Improved GitHub sign-in messaging on Home
- Help screen parameter edge case fix
- ASCII/status symbol fallbacks
- Home screen zero attention items fix
- Development Environment summary in test runner

---

## v0.4.x — Stabilization

### 1. Fix onboarding edge cases

**Labels:** `bug`, `onboarding`, `stability`, `v0.4.x`  
**Milestone:** v0.4.x — Stabilization

**Description:**  
Review first-run flows (missing config, partial config, invalid config, empty GitHub owners) and ensure DevTools always guides users to a clear next step without crashes or confusing loops.

**Acceptance Criteria:**

- First launch always reaches Configure or Home with clear guidance.
- Invalid `config.json` shows a friendly message and path to Configure.
- No nested Home/Configure loops.
- All edge cases covered in manual test notes.

---

### 2. Add README screenshots

**Labels:** `documentation`, `ui`, `v0.4.x`  
**Milestone:** v0.4.x — Stabilization

**Description:**  
Capture and add screenshots for the public README.

**Acceptance Criteria:**

- Screenshots for Home, Doctor, Configure, Status, Open Project, and Settings.
- Images stored under `docs/screenshots/`.
- README references real image paths.

---

### 3. Test clean Windows install flow

**Labels:** `stability`, `onboarding`, `windows`, `v0.4.x`  
**Milestone:** v0.4.x — Stabilization

**Description:**  
Validate DevTools on a clean Windows machine or VM from clone through first clone/open workflow.

**Acceptance Criteria:**

- Document test matrix (Windows version, PowerShell version).
- All required steps complete without manual JSON editing.
- Global `dev` works after reopening PowerShell.
- Issues found are filed separately.

---

### 4. Improve progress indicators

**Labels:** `enhancement`, `ui`, `performance`, `v0.4.x`  
**Milestone:** v0.4.x — Stabilization

**Description:**  
Add clearer progress feedback during Clone, Update, and Backup operations.

**Acceptance Criteria:**

- Users see which repo is being processed and overall progress.
- No noisy raw git/gh output on primary screens.

---

### 5. Installer polish

**Labels:** `enhancement`, `onboarding`, `windows`, `v0.4.x`  
**Milestone:** v0.4.x — Stabilization

**Description:**  
Polish `install.ps1` and `dev self install` based on clean-install testing feedback.

**Acceptance Criteria:**

- Clear conflict warnings when another `dev` command exists.
- Post-install validation covers all launcher files.
- Documentation matches actual behavior.

---

## v0.5 — Power User Workflows

### 6. Add favorite projects

**Labels:** `enhancement`, `v0.5`  
**Milestone:** v0.5 — Power User Workflows

**Description:**  
Let users pin favorite projects for faster access.

**Acceptance Criteria:**

- Favorites accessible from Open Project or Quick Actions.
- Favorites persist locally.

---

### 7. Add project profiles

**Labels:** `enhancement`, `v0.5`  
**Milestone:** v0.5 — Power User Workflows

**Description:**  
Store per-project metadata such as editor, notes, and launch commands.

**Acceptance Criteria:**

- Profile data stored locally per project.
- Open Project can use profile defaults.

---

### 8. Add workspace profiles

**Labels:** `enhancement`, `v0.5`  
**Milestone:** v0.5 — Power User Workflows

**Description:**  
Switch between multiple workspace configurations (path, owners, editor).

**Acceptance Criteria:**

- Named profiles in local config.
- Switching profiles updates active workspace context.

---

### 9. Add project launch workflows

**Labels:** `enhancement`, `v0.5`  
**Milestone:** v0.5 — Power User Workflows

**Description:**  
Run repeatable launch steps (open editor, start dev server, open docs).

**Acceptance Criteria:**

- Workflow defined per project or profile.
- Quick Actions can trigger workflows.

---

### 10. Self-update improvements

**Labels:** `enhancement`, `v0.5`  
**Milestone:** v0.5 — Power User Workflows

**Description:**  
Expand `dev self update` with release awareness and clearer guidance.

**Acceptance Criteria:**

- Shows current and latest version when available.
- User confirms before updating.
- Safe rollback guidance documented.

---

### 11. Add multi-editor support

**Labels:** `enhancement`, `v0.5`  
**Milestone:** v0.5 — Power User Workflows

**Description:**  
Support choosing different editors per project or per open action.

**Acceptance Criteria:**

- User can override default editor when opening a project.
- Settings remain beginner-friendly.

---

### 12. Add GitHub release package

**Labels:** `enhancement`, `github`, `v0.5`  
**Milestone:** v0.5 — Power User Workflows

**Description:**  
Publish a downloadable release artifact on GitHub Releases.

**Acceptance Criteria:**

- Zip or installer package attached to GitHub Release.
- README documents download and install path.

---

### 13. Add plugin system

**Labels:** `enhancement`, `future`, `v0.5`  
**Milestone:** v0.5 — Power User Workflows

**Description:**  
Allow optional plugins to extend DevTools commands.

**Acceptance Criteria:**

- Documented plugin interface.
- Sample plugin loads safely.
- Core commands unaffected when no plugins installed.

---

## Future

### 14. Add AI project summaries

**Labels:** `enhancement`, `future`  
**Milestone:** Future Ideas

**Description:**  
Summarize project status or recent activity using optional AI tools.

---

### 15. Launch dev server automatically

**Labels:** `enhancement`, `future`  
**Milestone:** Future Ideas

**Description:**  
Optional dev server launch when opening a project.

---

### 16. Add .devtools.json project profiles

**Labels:** `enhancement`, `future`  
**Milestone:** Future Ideas

**Description:**  
Support project-level configuration file for editor, scripts, and notes.

---

### 17. Explore cross-platform support

**Labels:** `enhancement`, `future`  
**Milestone:** Future Ideas

**Description:**  
Research macOS and Linux support for DevTools.

---

### 18. Create DevTools website landing page

**Labels:** `documentation`, `future`  
**Milestone:** Future Ideas

**Description:**  
Create a simple public landing page for DevTools with install instructions and screenshots.
