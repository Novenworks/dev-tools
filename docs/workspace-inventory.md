# Workspace Inventory (experimental)

Use `dev inventory` to inspect top-level folders in the configured workspace without changing any project. Use `dev inventory --export` to write `reports/workspace/inventory.json`.

The inventory includes ordinary folders, Git working-tree cleanliness (including untracked files), current branch, remote name, upstream, and ahead/behind counts based on **local tracking refs**. It does **not** fetch from GitHub; counts may be stale. It does not compare two computers, copy files, stage changes, commit, push, or pull.

For a first laptop test:

1. Save any important work separately before testing.
2. Run `dev inventory`; verify project classification.
3. Run `dev inventory --export`; inspect the JSON report.
4. Repeat on the desktop, preserving each exported report under a different filename before comparing manually.

Limitations: scans immediate child directories only; nested repositories, submodules, ignored files, and linked worktrees may require additional handling. `dirty` does not enumerate ignored files. Do not share exported paths/project names without review.

This is a safe foundation for a later cross-device report comparison and guided handoff. No automatic handoff is implemented yet.
