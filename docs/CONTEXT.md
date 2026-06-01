# Agent Context

This file is a compact handoff for future Codex/Claude sessions.

Project name: Claudex.

Goal: provide a reusable local Windows bridge where Codex remains the master controller and Claude Desktop/Cowork acts as a subordinate worker.

Core runtime root: `C:\ai-bridge`.

Important invariant: Claude output is never final until Codex validates and reviews it.

Primary scripts:

- `Invoke-ClaudeBridgeTask.ps1`: complete one-shot orchestration.
- `Start-ClaudeBridgeDaemon.ps1`: long-running daemon.
- `Install-ClaudeBridgeDaemon.ps1`: Windows logon scheduled task installer.
- `Watch-ClaudeBridgeApprovals.ps1`: limited GUI approval watcher.
- `Test-AIBridgePayload.ps1`: payload validation gate.

Tests:

- `tests/bridge-smoke.ps1` runs without Claude Desktop by using a temporary bridge root.

Packaging rule:

- Do not publish local runtime state such as `archive`, `outbox`, `tmp`, `logs`, or real task payloads.
