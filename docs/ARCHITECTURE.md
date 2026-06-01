# Architecture

Claudex is a local file bridge with desktop automation at the edge.

## Components

- `src/powershell/New-AIBridgeTask.ps1`: writes task JSON into `inbox`.
- `src/powershell/Get-AIBridgeNextTask.ps1`: claims the oldest task by moving it into `working`.
- `src/powershell/Complete-AIBridgeTask.ps1`: writes result JSON into `outbox` and archives the task.
- `src/powershell/Invoke-ClaudeBridgeTask.ps1`: one-shot orchestration for Codex to create or invoke a task, wake Claude, wait, validate, and return the result.
- `src/powershell/Start-ClaudeBridgeDaemon.ps1`: long-running local daemon that polls `inbox`.
- `src/powershell/Watch-ClaudeBridgeApprovals.ps1`: limited GUI watcher for Claude command approval prompts.
- `src/powershell/Send-ClaudeBridgeWorkerCommand.ps1`: sends the worker prompt into Claude Desktop.

## Control Flow

1. Codex creates a task.
2. The daemon or one-shot invoker sends the worker command to Claude Desktop.
3. Claude claims the task and writes the result.
4. Codex validates the result payload.
5. Codex reviews the work and decides the next step.

## Why Files

Claude Desktop/Cowork is not exposed as a stable HTTP API. A filesystem bridge is simple, local-first, observable, and easy to recover from.

## Failure Modes

- Claude Desktop is closed or signed out.
- The interactive Windows session is locked or unavailable.
- GUI labels change after an app update.
- Permissions for `C:\ai-bridge` are revoked.
- A task times out or returns `failed`/`partial`.

Codex should treat Claude results as untrusted worker output until validated and reviewed.
