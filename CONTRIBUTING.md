# Contributing to DevTools

Thank you for helping improve DevTools. Contributions of all sizes are welcome — from typo fixes to new features.

DevTools is an open-source project by Novenworks. The goal is simple: help developers spend less time managing projects and more time building.

## Ways to contribute

### Report a bug

1. Check [existing issues](https://github.com/Novenworks/dev-tools/issues) first.
2. Open a **Bug Report** using the issue template.
3. Include steps to reproduce and your environment details.

### Request a feature

1. Open a **Feature Request** issue.
2. Explain the problem, who it helps, and an example workflow.

### Share UI or UX feedback

For Home, Doctor, or onboarding screens? Open a **UI / UX Improvement** issue.

### Improve documentation

README unclear? Help text confusing? Open a **Documentation** issue or submit a pull request.

## Labels and milestones

DevTools uses GitHub labels and milestones to organize work.

- See [`.github/labels.md`](.github/labels.md) for recommended labels.
- See [`.github/milestones.md`](.github/milestones.md) for release planning.
- See [`.github/ISSUES_TO_CREATE.md`](.github/ISSUES_TO_CREATE.md) for the initial roadmap issue list.

## Pull requests

1. Fork the repository.
2. Create a focused branch for your change.
3. Keep changes small and easy to review.
4. Test your change with `.\dev.cmd` on Windows and run `tests/Test-DevTools.ps1`.

Global install smoke test (optional):

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

Close and reopen PowerShell, then run `dev`.
5. Open a pull request with a clear description.

Maintainers and AI assistants: read [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) before larger changes.

### Beginner-friendly note

You do not need to understand the entire codebase to help. Documentation fixes, copy improvements, and small bug fixes are great first contributions. Look for issues labeled `good first issue`.

## Development setup

```powershell
git clone https://github.com/Novenworks/dev-tools.git C:\Projects\dev-tools
cd C:\Projects\dev-tools
.\dev.cmd
```

Use `.\dev.cmd` to avoid PowerShell execution policy issues.

## Before submitting a pull request

Please run:

```powershell
dev test
```

Or invoke the test script directly:

```powershell
pwsh ./tests/Test-DevTools.ps1
```

If `pwsh` is unavailable, use:

```powershell
powershell -ExecutionPolicy Bypass -File ./tests/Test-DevTools.ps1
```

## Code guidelines

- Keep the product voice calm and beginner-friendly.
- Home should answer: *Am I ready to build?*
- Doctor should answer: *Why is this happening and how do I fix it?*
- Do not add unrelated features in the same pull request.
- Preserve the modular `commands/` and `lib/` structure.

## Questions

Open a [GitHub Discussion](https://github.com/Novenworks/dev-tools/discussions) or an issue if you are unsure where to start.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
