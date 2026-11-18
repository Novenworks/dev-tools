# Target architecture

Keep one PowerShell operations layer for the Windows CLI and future desktop client. Use the existing repository facts, classifier and mutation safeguards as canonical. Retain the GitHub CLI and Vercel adapters. Refactor UI-oriented orchestrators behind a narrow boundary as their next caller appears.

| Boundary | Responsibility |
| --- | --- |
| Command entry | Resolve fixed command paths and aliases, validate options, choose interactive or structured mode and map errors to process exit status. |
| Operations | Accept typed requests with explicit workspace and confirmation intent. Return data, warnings and errors. Emit progress through callbacks and recheck mutating preconditions before applying a plan. |
| Execution | Launch a known executable with explicit argument arrays and working directory. Apply timeouts, normalize failures and sanitize diagnostics. |
| Storage | Read compatible settings through versioned defaults and migration. Use user and workspace overrides and stable project identifiers, with credentials supplied through existing auth mechanisms. |
| Presentation | Render terminal menus and results or emit a versioned JSON envelope. A future desktop host invokes an allowlist of operations and forwards progress and cancellation. |

The first machine contract uses `schemaVersion`, `command`, UTC `timestamp`, `success`, `data`, `warnings` and `errors`. Keep status local by default. A strict sync preview uses cached refs and discloses their age. Network refresh and apply are distinct operations, since a fetch writes tracking refs.

Choose a desktop framework only after CLI contracts stabilize. Compare Tauri's WebView and Rust bridge, Electron's packaged runtime and native Windows options against PS 5.1/7 integration, x64 and ARM64 installation, update signing, accessibility and measured startup. The frontend receives sanitized data and narrowly scoped operations. It receives neither tokens nor a general-purpose shell channel.
