# Claudex

Claudex is a local Windows bridge that lets OpenAI Codex orchestrate Claude Desktop/Cowork as a subordinate execution worker.

Codex stays in charge: it designs, schedules, reviews, and decides. Claude executes scoped tasks through a local file bridge and writes structured results back for Codex review.

This is not an official Claude API and not an official OpenAI product. It is a pragmatic local automation layer for developers who already run Codex and Claude Desktop on the same Windows machine.

## What It Does

- Creates a local bridge root, defaulting to `C:\ai-bridge`.
- Lets Codex submit JSON tasks to `inbox`.
- Wakes Claude Desktop/Cowork through GUI automation.
- Starts an approval watcher for bridge-related Claude command prompts.
- Lets Claude claim tasks, execute them, and write result JSON to `outbox`.
- Keeps Codex as the master reviewer through a documented master-worker policy.
- Supports a Windows logon daemon that polls for pending tasks.

## Architecture

```text
Codex master
  |
  | writes task JSON
  v
C:\ai-bridge\inbox
  |
  | local daemon wakes Claude Desktop
  v
Claude worker
  |
  | claims task, performs scoped work
  v
C:\ai-bridge\outbox
  |
  | Codex validates and reviews
  v
Follow-up task, acceptance, or direct Codex correction
```

## Requirements

- Windows 10/11.
- PowerShell 5.1 or later.
- Python available as `python`.
- Python packages used by the GUI helper: `pywinauto`.
- Claude Desktop/Cowork installed and signed in.
- Codex running on the same machine with filesystem access.

Install the Python dependency:

```powershell
python -m pip install --user --upgrade pywinauto
```

## Quick Start

Clone the repository:

```powershell
git clone https://github.com/drinkwater-claw/claudex.git
cd claudex
```

Install the bridge runtime:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -BridgeRoot C:\ai-bridge
```

Install and start the long-running Claude daemon:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -BridgeRoot C:\ai-bridge -InstallDaemon -StartDaemon
```

Give Claude the worker prompt:

```text
C:\ai-bridge\docs\CLAUDE_WORKER_PROMPT.md
```

Run a one-shot task:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Invoke-ClaudeBridgeTask.ps1 `
  -Prompt "Return markdown saying the Claudex bridge is installed and ready." `
  -TimeoutSeconds 300
```

## Runtime Layout

```text
C:\ai-bridge\
  inbox\      Codex writes pending task JSON files.
  working\    Claude claims active tasks here.
  outbox\     Claude writes result JSON files here.
  archive\    Completed task JSON files are archived here.
  locks\      Per-task invocation locks.
  logs\       Daemon, invoke, and approval logs.
  tmp\        Temporary response markdown files.
  bin\        Runtime PowerShell scripts.
  docs\       Worker and policy documentation.
  schemas\    JSON schemas.
  examples\   Example payloads.
```

## Important Safety Model

Claudex is intentionally a master-worker system.

- Codex is the project lead, architect, reviewer, and final decision maker.
- Claude is a scoped execution worker.
- Claude output is not final until Codex validates and reviews it.
- The GUI approval watcher is a convenience layer, not a security boundary.
- Keep the bridge root limited to a known local path such as `C:\ai-bridge`.

See [docs/CODEX_MASTER_POLICY.md](docs/CODEX_MASTER_POLICY.md).

## Commands

Submit a task without waking Claude:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\New-AIBridgeTask.ps1 `
  -Prompt "Review this file and return findings." `
  -ContextFiles "D:\project\src\auth.ts"
```

Run a complete Codex-to-Claude invocation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Invoke-ClaudeBridgeTask.ps1 `
  -Prompt "Review D:\project\src\auth.ts for security issues." `
  -ContextFiles "D:\project\src\auth.ts" `
  -TimeoutSeconds 900
```

Validate a result:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Test-AIBridgePayload.ps1 `
  -Path C:\ai-bridge\outbox\task-YYYYMMDD-HHMMSS-xxxxxxxx.result.json `
  -Kind result
```

Install the daemon directly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Install-ClaudeBridgeDaemon.ps1 -StartNow
```

## Testing

Run the smoke test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\bridge-smoke.ps1
```

The smoke test uses a temporary bridge root and does not require Claude Desktop.

## Limits

- Claude Desktop must be installed, signed in, and usable.
- Long-running unattended operation requires an interactive Windows session.
- GUI automation can break if Claude Desktop changes labels, layout, or permission prompts.
- This project does not bypass Claude safety prompts or OS permissions.
- The bridge is local-first and file-based; it does not expose a network API.

## License

MIT. See [LICENSE](LICENSE).
