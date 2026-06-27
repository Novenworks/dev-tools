# GitHub Issues to Create

Copy each section below into a new GitHub Issue. Create milestones and labels first using `.github/labels.md` and `.github/milestones.md`.

---

## v0.3.1 — Stability

### 1. Fix onboarding edge cases

**Labels:** `bug`, `onboarding`, `stability`, `v0.3.1`  
**Milestone:** v0.3.1 — Stability

**Description:**  
Review first-run flows (missing config, partial config, invalid config, empty GitHub owners) and ensure DevTools always guides users to a clear next step without crashes or confusing loops.

**Acceptance Criteria:**

- First launch always reaches Configure or Home with clear guidance.
- Invalid `config.json` shows a friendly message and path to Configure.
- No nested Home/Configure loops.
- All edge cases covered in manual test notes.

**Suggested Implementation Notes:**

- Review `Initialize-DevToolsConfig`, `commands/configure.ps1`, and `commands/home.ps1`.
- Add guardrails in `lib/config.ps1` for malformed JSON.

---

### 2. Improve GitHub login flow

**Labels:** `enhancement`, `github`, `onboarding`, `ui`, `v0.3.1`  
**Milestone:** v0.3.1 — Stability

**Description:**  
Polish the DevTools-native GitHub sign-in experience on Home and Doctor. No raw `gh auth status` output should appear on Home.

**Acceptance Criteria:**

- Home shows DevTools copy for unsigned-in state.
- Sign-in re-verifies automatically after `gh auth login`.
- Success message uses DevTools wording.
- Doctor and Home flows stay consistent.

**Suggested Implementation Notes:**

- Use `Test-GhAuthenticated` with suppressed CLI output.
- Keep interactive `gh auth login` when user chooses sign-in.

---

### 3. Fix Help screen non-fatal error

**Labels:** `bug`, `stability`, `ui`, `v0.3.1`  
**Milestone:** v0.3.1 — Stability

**Description:**  
Running `dev help` should not throw a parameter validation error from `ShowCommandScreen`.

**Acceptance Criteria:**

- `dev.cmd help` runs without errors.
- Help content displays fully.
- Empty description lines are handled safely.

**Suggested Implementation Notes:**

- Filter blank lines in `ShowScreenDescription` or remove empty strings from `commands/help.ps1`.

---

### 4. Add ASCII fallbacks for emoji/status icons

**Labels:** `enhancement`, `windows`, `ui`, `v0.3.1`  
**Milestone:** v0.3.1 — Stability

**Description:**  
Some Windows consoles render emoji status indicators as mojibake. Provide ASCII fallbacks (for example `*`, `-`, `x`) when emoji cannot display cleanly.

**Acceptance Criteria:**

- Home status and checklist icons have ASCII fallback.
- Fallback activates automatically on unsupported consoles.
- Doctor remains readable in legacy PowerShell windows.

**Suggested Implementation Notes:**

- Add detection helper in `lib/ui.ps1` or `lib/home.ps1`.
- Prefer char codes with fallback map.

---

### 5. Add README screenshots

**Labels:** `documentation`, `ui`, `v0.3.1`  
**Milestone:** v0.3.1 — Stability

**Description:**  
Capture and add screenshots for the public README.

**Acceptance Criteria:**

- Screenshots for Home, Doctor, Configure, Status, Open Project, and Settings.
- Images stored under `docs/screenshots/`.
- README references real image paths.

**Suggested Implementation Notes:**

- Use consistent terminal size and theme.
- Keep filenames lowercase and descriptive.

---

### 6. Test clean Windows install flow

**Labels:** `stability`, `onboarding`, `windows`, `v0.3.1`  
**Milestone:** v0.3.1 — Stability

**Description:**  
Validate DevTools on a clean Windows machine or VM from clone through first clone/open workflow.

**Acceptance Criteria:**

- Document test matrix (Windows version, PowerShell version).
- All required steps complete without manual JSON editing.
- Issues found are filed separately.

**Suggested Implementation Notes:**

- Test with and without `install.ps1` PATH setup.
- Test `dev.cmd` execution policy path.

---

## v0.4 — Quality of Life

### 7. Improve progress indicators

**Labels:** `enhancement`, `ui`, `performance`, `v0.4`  
**Milestone:** v0.4 — Quality of Life

**Description:**  
Add clearer progress feedback during Clone, Update, and Backup operations.

**Acceptance Criteria:**

- Users see which repo is being processed and overall progress.
- No noisy raw git/gh output on primary screens.

**Suggested Implementation Notes:**

- Add lightweight progress helper in `lib/ui.ps1`.

---

### 8. Add recent projects

**Labels:** `enhancement`, `v0.4`  
**Milestone:** v0.4 — Quality of Life

**Description:**  
Track recently opened projects and surface them on Home or Quick Actions.

**Acceptance Criteria:**

- Recent list persists locally (not in Git).
- Open Project updates recents.
- Recent list is optional and easy to clear.

**Suggested Implementation Notes:**

- Store in a local state file under DevTools root or user app data.

---

### 9. Add favorite projects

**Labels:** `enhancement`, `v0.4`  
**Milestone:** v0.4 — Quality of Life

**Description:**  
Let users pin favorite projects for faster access.

**Acceptance Criteria:**

- Favorites accessible from Open Project or Quick Actions.
- Favorites persist locally.

**Suggested Implementation Notes:**

- Consider simple JSON state file ignored by Git.

---

### 10. Improve project search

**Labels:** `enhancement`, `ui`, `v0.4`  
**Milestone:** v0.4 — Quality of Life

**Description:**  
Enhance Open Project search for large workspaces with partial name matching and sorted results.

**Acceptance Criteria:**

- Case-insensitive partial search.
- Exact and starts-with matches rank higher.
- Git repos marked separately from plain folders.

**Suggested Implementation Notes:**

- Implemented in `lib/projects.ps1` — track follow-up polish in this issue.

---

### 11. Add multi-editor support

**Labels:** `enhancement`, `v0.4`  
**Milestone:** v0.4 — Quality of Life

**Description:**  
Support choosing different editors per project or per open action.

**Acceptance Criteria:**

- User can override default editor when opening a project.
- Settings remain beginner-friendly.

**Suggested Implementation Notes:**

- Extend Settings or Open Project prompt.

---

### 12. Add GitHub release package

**Labels:** `enhancement`, `github`, `v0.4`  
**Milestone:** v0.4 — Quality of Life

**Description:**  
Publish a downloadable release artifact on GitHub Releases.

**Acceptance Criteria:**

- Zip or installer package attached to GitHub Release.
- README documents download and install path.

**Suggested Implementation Notes:**

- Script packaging in CI or manual release checklist.

---

### 13. Add self-update command

**Labels:** `enhancement`, `v0.4`  
**Milestone:** v0.4 — Quality of Life

**Description:**  
Add a DevTools command to check for and apply updates from GitHub Releases.

**Acceptance Criteria:**

- `dev update-devtools` or similar checks current version.
- User confirms before updating.
- Safe rollback guidance documented.

**Suggested Implementation Notes:**

- Coordinate with release package issue.

---

### 14. Add Quick Actions screen

**Labels:** `enhancement`, `ui`, `v0.4`  
**Milestone:** v0.4 — Quality of Life

**Description:**  
Add a Quick Actions screen for frequent tasks: update, open, status, clone.

**Acceptance Criteria:**

- `dev quick` opens Quick Actions.
- Accessible from Home, Main Menu, and Help.
- Returns to Quick Actions after each action unless exiting.

**Suggested Implementation Notes:**

- Implemented in `commands/quick.ps1` — track follow-up polish in this issue.

---

### 15. Add Project Search for Open Project

**Labels:** `enhancement`, `ui`, `v0.4`  
**Milestone:** v0.4 — Quality of Life

**Description:**  
Search projects by partial folder name when opening a project.

**Acceptance Criteria:**

- Search prompt with list-all on Enter.
- Numbered results with `[git]` / `[folder]` markers.
- Graceful no-match flow with search again / list all / return.

**Suggested Implementation Notes:**

- Implemented in `lib/projects.ps1` — track follow-up polish in this issue.

---

## v0.5 — Power User

### 16. Add project profiles

**Labels:** `enhancement`, `v0.5`  
**Milestone:** v0.5 — Power User

**Description:**  
Store per-project metadata such as editor, notes, and launch commands.

**Acceptance Criteria:**

- Profile data stored locally per project.
- Open Project can use profile defaults.

**Suggested Implementation Notes:**

- Consider `.devtools.json` in project root (see Future issue #24).

---

### 17. Add workspace profiles

**Labels:** `enhancement`, `v0.5`  
**Milestone:** v0.5 — Power User

**Description:**  
Switch between multiple workspace configurations (path, owners, editor).

**Acceptance Criteria:**

- Named profiles in local config.
- Switching profiles updates active workspace context.

---

### 18. Add plugin system

**Labels:** `enhancement`, `future`, `v0.5`  
**Milestone:** v0.5 — Power User

**Description:**  
Allow optional plugins to extend DevTools commands.

**Acceptance Criteria:**

- Documented plugin interface.
- Sample plugin loads safely.
- Core commands unaffected when no plugins installed.

---

### 19. Add auto updater

**Labels:** `enhancement`, `v0.5`  
**Milestone:** v0.5 — Power User

**Description:**  
Optional automatic update check on launch using `autoUpdate` config flag.

**Acceptance Criteria:**

- Respects user opt-in.
- Never updates without confirmation.

---

### 20. Add project templates

**Labels:** `enhancement`, `v0.5`  
**Milestone:** v0.5 — Power User

**Description:**  
Scaffold new projects from templates in the workspace.

**Acceptance Criteria:**

- Template list configurable locally.
- Clone or copy template into workspace with guided naming.

---

### 21. Add project launch workflows

**Labels:** `enhancement`, `v0.5`  
**Milestone:** v0.5 — Power User

**Description:**  
Run repeatable launch steps (open editor, start dev server, open docs).

**Acceptance Criteria:**

- Workflow defined per project or profile.
- Quick Actions can trigger workflows.

---

## Future

### 22. Add AI project summaries

**Labels:** `enhancement`, `future`  
**Milestone:** Future Ideas

**Description:**  
Summarize project status or recent activity using optional AI tools.

**Acceptance Criteria:**

- Opt-in only.
- Works without AI when not configured.

---

### 23. Launch dev server automatically

**Labels:** `enhancement`, `future`  
**Milestone:** Future Ideas

**Description:**  
Optional dev server launch when opening a project.

**Acceptance Criteria:**

- Detect common scripts (`npm run dev`, etc.) with confirmation.
- Never starts servers silently.

---

### 24. Add .devtools.json project profiles

**Labels:** `enhancement`, `future`  
**Milestone:** Future Ideas

**Description:**  
Support project-level configuration file for editor, scripts, and notes.

**Acceptance Criteria:**

- Schema documented.
- DevTools reads optional `.devtools.json` in project root.

---

### 25. Explore cross-platform support

**Labels:** `enhancement`, `future`  
**Milestone:** Future Ideas

**Description:**  
Research macOS and Linux support for DevTools.

**Acceptance Criteria:**

- Document platform gaps and feasibility.
- No unsupported claims in README until implemented.

---

### 26. Create DevTools website landing page

**Labels:** `documentation`, `future`  
**Milestone:** Future Ideas

**Description:**  
Create a simple public landing page for DevTools with install instructions and screenshots.

**Acceptance Criteria:**

- Links to GitHub repository and releases.
- Matches product voice and branding.
