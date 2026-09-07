# DevTools Testing

How DevTools is validated before release.

---

## Automated tests

Run from the DevTools folder or globally after install:

```powershell
dev test
```

Or invoke the script directly:

```powershell
powershell -ExecutionPolicy Bypass -File ./tests/Test-DevTools.ps1
```

**Checks include:**

- PowerShell syntax for all scripts
- Required files and command scripts
- Launcher architecture (`dev.cmd`, `dev-core.ps1`)
- Example configuration validity
- README and installation doc expectations
- No committed Vercel token literals, and `reports/` is gitignored
- The repository intelligence suite (`tests/Test-Repos.ps1`)
- The Deployment Manager suite (`tests/Test-Deploy.ps1`)

---

## Repository intelligence tests

`tests/Test-Repos.ps1` runs as part of `dev test`, and can also be run on its own:

```powershell
powershell -ExecutionPolicy Bypass -File ./tests/Test-Repos.ps1
```

These are real behavioral tests, not syntax checks. The suite builds throwaway Git repositories in a
temporary folder and uses **local bare repositories as remotes**, so it runs offline, needs no GitHub
authentication, and never touches your real workspace. The fixture folder is removed afterwards.

Covered scenarios:

- Clean and current, clean but behind, local uncommitted changes, ahead, diverged
- Deleted upstream branch, branch with no upstream, detached HEAD
- Merge conflict, merge in progress, rebase in progress
- No remote configured, fetch failure, and a broken repository folder
- Safe fast-forward succeeds and reports its commit count
- Upstream repair on a safe branch, and refusal on a branch with unmerged commits or a dirty tree
- Branch cleanup deletes a provably merged branch and refuses an unmerged one
- Report generation, JSON round-trip, and credential sanitization
- Classification priority, porcelain v2 parsing, and Git error categorization
- Output formatting, the ASCII fallback, and compact progress text
- `dev update` compatibility and the new `dev sync` command

**The most important assertions prove no local work is lost.** After a full bulk sync, dirty, ahead,
diverged, detached, conflicted, and broken-upstream repositories must have an unchanged HEAD,
unchanged history, and unchanged working-tree files. A separate check scans the repository modules
and fails the suite if they ever pass `reset`, `stash`, `clean`, `rebase`, `-D`, or `--force` to Git.

---

## Deployment Manager tests

`tests/Test-Deploy.ps1` runs as part of `dev test`, and can also be run on its own:

```powershell
powershell -ExecutionPolicy Bypass -File ./tests/Test-Deploy.ps1
```

It covers repository filtering, name normalization, deployability detection, repository-to-project matching, status classification, planning, reporting, and the safety rules: audit and plan perform zero writes, sync requires confirmation, a declined confirmation writes nothing, and a second sync creates no duplicates.

**GitHub and Vercel are fully mocked.** These tests never contact either service and never create a real Vercel project.

GitHub Actions runs the same script on pushes and pull requests.

---

## Manual smoke tests

Before every GitHub Release, complete the manual checklist:

- [testing/smoke-test.md](testing/smoke-test.md)
- [testing/README.md](testing/README.md)

Estimated time: 5–10 minutes.

---

## Optional tools

PSScriptAnalyzer adds lint checks during `dev test`. Tests pass without it.

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

---

## Self-management

DevTools dogfoods its own test runner:

```powershell
dev self test
dev self doctor
dev self path
```

---

## See also

- [Contributing](../CONTRIBUTING.md)
- [Smoke test checklist](testing/smoke-test.md)
- [Deployment Manager](deployments.md)
