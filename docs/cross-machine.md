# Working between two computers

DevTools stays a PowerShell CLI. Each computer has its own `workspacePath` in its
local, gitignored `config.json`; those paths can differ. No cloud service or AI is
needed for local inspection. GitHub CLI is only needed for GitHub-specific features.
Existing configuration is unchanged, and `githubOwners: []` is valid for local work.

## Commands

| Command | Effects |
| --- | --- |
| `dev doctor` | Offline, read-only project health and handoff report; no fixes or setup prompts |
| `dev readiness` | The same handoff report without the Doctor introduction |
| `dev sync` / `dev sync --dry-run` | Offline preview only; no fetch or file writes |
| `dev sync --refresh` | Explicitly fetch remote refs; no working-tree or local-branch updates |
| `dev sync --apply` | Show preview, fetch, inspect again, fast-forward eligible branches only |
| `dev update ...` | Alias with exactly the same options and safety rules |

`--dry-run` cannot accompany `--refresh` or `--apply`. Unknown options fail before
inspection or mutation. Commands finish without keypress prompts. Menu sync actions
also preview and explain the explicit apply command. This deliberately changes the
old immediate-update behavior; update existing scripts to use `--apply` intentionally.

Inspection never creates a missing `config.json` or enters setup. Without configuration
it uses the example workspace path and explains if that folder does not exist. Run
`dev configure` explicitly to choose a workspace on a new computer.

## Before leaving the source computer

1. Run `dev doctor` or `dev readiness`.
2. Review changed/untracked files and unpublished commits. Commit/push deliberately
   with Git or your existing reviewed backup workflow when appropriate. DevTools
   sync never commits or pushes.
3. Review ignored files and stashes separately. Back up valuable local-only files
   using a file backup/copy process you control. Do not publish secrets just to move
   them. Git does not transfer ignored files, untracked files, or stashes.
4. For folders without Git or a remote, arrange a separate backup or deliberately
   initialize/publish a repository yourself. DevTools does neither automatically.
5. Run `dev sync --refresh` if you want newer remote knowledge, then inspect again.

**Ready (cached)** means the current branch has no known changes or unpublished
commits and no other detected local work needs attention. It does not prove that
another computer has your files, that the server is reachable, or that cached refs
still match the server. A clean behind-only branch can be ready to leave: its known
commits already exist in the cached remote history.

The report includes counts of commits across *all local branches* absent from cached
remote refs. That count is separate from the current branch's ahead/behind counts.
Missing upstreams, detached HEAD, conflicts, operations in progress, inaccessible
Git metadata, local-path remotes, ignored entries, and stashes require attention.
Remote URLs and file contents are not printed by this report.

## On the destination computer

1. Run `dev doctor` there first. Any local changes are independent of the source.
2. Run `dev sync --dry-run` to preview based on cached refs.
3. Use `dev sync --refresh` for fetch-only inspection if desired.
4. Run `dev sync --apply` only when you intend to update. It fetches and rechecks
   each repository and updates only clean, behind-only branches with valid upstreams.

Dirty, ahead, diverged, conflicted, detached, missing-upstream, and failed-refresh
repositories are skipped. Ignored entries are also a conservative update blocker:
Git fast-forwards can otherwise overwrite ignored files when they become tracked.
Review/back up those entries separately rather than deleting them to satisfy the tool.
No reset, stash, force-push, automatic commit/push, branch switch, or conflict resolution
is performed. This is an inbound fast-forward workflow, not bidirectional file sync.

Discovery covers immediate project directories, including hidden directories, but
skips linked folders/junctions. Nested projects, workspace-root files, submodule
contents, files outside the workspace, and the other computer require separate
inspection. Do not edit repositories concurrently with an apply operation; rechecks
reduce stale-preview risks but cannot coordinate unrelated editors or Git processes.

## Windows / Lenovo verification before approval

Use the PR branch in a separate checkout; do not update the installed copy yet.
Do not run apply against your real projects for the first test.

```powershell
git clone --branch feat/cross-machine-readiness https://github.com/Novenworks/dev-tools.git dev-tools-review
cd dev-tools-review
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Test-DevTools.ps1
# Also run if PowerShell 7 is installed:
pwsh -NoProfile -File tests/Test-DevTools.ps1
```

The behavioral suite creates temporary repositories and local bare remotes. It tests
preview immutability, dirty/ahead/diverged/conflicted repositories, missing remotes,
non-Git folders, ignored collisions, unpublished branches, stashes, explicit refresh
and apply, stale previews, and non-origin tracking remotes. No GitHub authentication
is needed and no real workspace is used.

For a manual CLI check, create a disposable workspace with one ordinary folder, one
local Git repository without a remote, and two clones of a local bare remote. Copy
`config.example.json` to `config.json` in the review checkout, set `workspacePath`
to that disposable workspace, and optionally set `githubOwners` to `[]`.

- Run `.\dev.cmd doctor`, `.\dev.cmd readiness`, `.\dev.cmd sync`, and
  `.\dev.cmd sync --dry-run`. Confirm clear reasons and no keypress prompt or edits.
- Make one clone dirty with an untracked file; make the other behind by pushing a
  reviewed fixture commit through a third clone. Preview must update neither.
- Run `.\dev.cmd sync --refresh`: refs may change; HEAD and files must not.
- Run `.\dev.cmd sync --apply`: only the clean behind clone should fast-forward.
- Add an ignored file with valuable content. Apply must preserve it and skip updating
  that project. Confirm the dirty clone, non-Git folder, and no-remote repo survive.
- Run `.\dev.cmd update --dry-run` and verify identical preview behavior.
- In a review checkout with no `config.json`, Doctor must not create it or enter setup.

After these checks, point only the review checkout's configuration at your Lenovo
workspace and run **Doctor/readiness/dry-run only** to assess the real report. Keep
the PR unmerged until your review is complete.
