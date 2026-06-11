# Changelog

## Unreleased

- Added a daemon watchdog script and installer wiring so the Windows scheduled task periodically restores the Claude bridge daemon if it exits.
- Runs the watchdog scheduled task with a hidden, non-interactive PowerShell window to avoid interrupting fullscreen work.
- Changed the watchdog scheduled task to launch through `wscript.exe` so it does not create a console window before PowerShell can hide itself.

## 0.1.4

- Fixed UTF-8 JSON reading on Windows PowerShell 5.1 so Chinese and other non-ASCII task prompts validate and can be claimed reliably.
- Added smoke-test coverage for UTF-8 task prompt text.

## 0.1.3

- Added `docs/COLLABORATION_PLAYBOOK.md` with bilingual Codex/Claude worker coordination guidance.
- Documented a quota-saving budget ladder for Codex master workflows.
- Added CC Switch + DeepSeek worker routing principles and validation guidance.
- Linked the collaboration playbook from README and the Claude worker prompt.

## 0.1.2

- Added bilingual 5-minute quick start documentation.
- Added bilingual common blockers and troubleshooting guidance.
- Documented release asset expectations for source archives and convenience bundles.
- Published a downloadable release bundle for easier installation.

## 0.1.1

- Added `Clear-ClaudeBridgeRuntime.ps1` for retention-based cleanup of `tmp`, `logs`, `outbox`, and `archive`.
- Added cleanup test coverage.
- Documented disk usage and cleanup operations.

## 0.1.0

- Initial public release.
- Local file bridge for Codex-to-Claude task orchestration.
- One-shot invocation script.
- Long-running Windows daemon.
- Claude Desktop GUI wake-up helper.
- Limited approval watcher.
- Task and result schema validation.
- Smoke test and Windows CI.
