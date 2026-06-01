# Codex Master Policy

This bridge is a master-worker system.

## Roles

- Codex is the project lead, architect, reviewer, quality gate, and final decision maker.
- Claude is a worker that executes scoped tasks and returns results through `C:\ai-bridge\outbox`.

## Operating Loop

1. Codex turns the user's product goal into scoped tasks.
2. Codex submits a task to `C:\ai-bridge\inbox`.
3. The local daemon wakes Claude and sends the worker command.
4. Claude claims the task, executes it, and writes a result.
5. Codex validates the result JSON and reviews the content.
6. Codex either accepts the result into its own implementation flow or sends a follow-up task.

## Quality Rules

- Claude output is never final by itself.
- Codex must review Claude output before using it.
- Follow-up tasks should be specific and include concrete defects, missing requirements, or acceptance criteria.
- If Claude returns a failed or partial result, Codex decides whether to retry, narrow the task, or handle the work directly.

## Stability Rules

- The daemon should only wake Claude for tasks present in `inbox`.
- Task invocation uses per-task lock files in `locks`.
- Results must validate with `Test-AIBridgePayload.ps1`.
- Long-running or unattended work should keep logs under `logs`.
