# DevTools Testing

## Why smoke testing exists

Smoke testing is a quick check to make sure the most important features still work before creating a new release.

It is not intended to replace automated testing. The goal is to catch obvious regressions — broken commands, parser errors, or confusing failures — before users see them.

## Why DevTools uses manual smoke testing

DevTools is a Windows PowerShell CLI that interacts with Git, GitHub CLI, and your local filesystem. Many flows depend on your machine, your GitHub account, and your workspace setup.

A short manual checklist is the most practical way to validate releases today without building a full test harness.

## How long it takes

Most smoke tests should take **less than ten minutes**.

Run the checklist before **every GitHub Release**.

Also run automated validation before releasing:

```powershell
powershell -ExecutionPolicy Bypass -File ./tests/Test-DevTools.ps1
```

GitHub Actions runs the same script on pushes and pull requests.

## Optional development tools

Automated tests **do not require** optional tools to pass.

When **PSScriptAnalyzer** is not installed, the test runner explains what it is, why it helps, and how to install it — then continues normally.

Install PSScriptAnalyzer for additional PowerShell code quality checks during `dev test`:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

This pattern may expand to other optional tools (for example Pester or PowerShell 7) in the future.

## Checklist

See [smoke-test.md](smoke-test.md) for the current release checklist.

## Who should run it

- Maintainers before publishing a release
- Contributors before opening a pull request that touches commands or core library code

If something fails, document the issue in the smoke test result section and open a GitHub issue before releasing.
