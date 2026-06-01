# Claudex Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package the local Codex-to-Claude bridge as a reusable public GitHub project named Claudex.

**Architecture:** Runtime scripts live under `src/powershell` and install into `C:\ai-bridge\bin`. Documentation, schemas, examples, and smoke tests ship with the repository, while runtime state such as logs, tasks, outbox, archive, and temp files stays excluded.

**Tech Stack:** Windows PowerShell, JSON files, GitHub Actions on Windows, Claude Desktop/Cowork GUI automation via Python `pywinauto`.

---

### Task 1: Package Runtime Scripts

**Files:**
- Create: `src/powershell/*.ps1`
- Create: `src/powershell/Bridge.Common.psm1`

- [x] **Step 1: Copy the proven local bridge scripts**

Copied only reusable runtime scripts from `C:\ai-bridge\bin`; did not copy `logs`, `outbox`, `archive`, `tmp`, `working`, `locks`, or real task payloads.

- [x] **Step 2: Keep project runtime independent**

Smoke tests import scripts from `src/powershell` and use a temporary bridge root.

### Task 2: Add Installer

**Files:**
- Create: `install.ps1`

- [x] **Step 1: Copy project files into a bridge root**

`install.ps1` copies scripts, docs, schemas, examples, and README into the target bridge root.

- [x] **Step 2: Support daemon setup**

`install.ps1 -InstallDaemon -StartDaemon` delegates to `Install-ClaudeBridgeDaemon.ps1`.

### Task 3: Add Docs

**Files:**
- Create: `README.md`
- Create: `docs/ARCHITECTURE.md`
- Create: `docs/OPERATIONS.md`
- Create: `docs/CONTEXT.md`
- Create: `docs/CODEX_MASTER_POLICY.md`
- Create: `docs/CLAUDE_WORKER_PROMPT.md`
- Create: `SECURITY.md`
- Create: `CHANGELOG.md`
- Create: `LICENSE`

- [x] **Step 1: Explain the master-worker model**

Docs state Codex is the master controller and Claude is a scoped execution worker.

- [x] **Step 2: Document safety boundaries**

Docs explain that Claudex is a local bridge, not an official Claude API, and that GUI automation is not a security boundary.

### Task 4: Add Verification

**Files:**
- Create: `tests/bridge-smoke.ps1`
- Create: `.github/workflows/ci.yml`

- [x] **Step 1: Add temp-root smoke test**

The smoke test initializes a temporary bridge root, submits, validates, claims, completes, validates, waits, and cleans up.

- [x] **Step 2: Add Windows CI**

GitHub Actions runs the smoke test on `windows-latest`.

### Task 5: Publish

**Files:**
- GitHub repository: `drinkwater-claw/claudex`

- [ ] **Step 1: Initialize git**

Run `git init`, stage project files, and commit.

- [ ] **Step 2: Create public GitHub repo**

Run `gh repo create drinkwater-claw/claudex --public --source . --remote origin --push`.

- [ ] **Step 3: Verify remote**

Confirm repository URL and branch state after push.
