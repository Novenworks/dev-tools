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
