# Claudex

**中文** | [English](#english)

Claudex 是一套本地 Windows 桥接系统，用来把 **OpenAI Codex** 和 **Claude Desktop/Cowork** 连接起来，让 Codex 作为主导大脑调度项目，让 Claude 作为执行 worker 完成被分配的具体任务。

它的核心目标不是让两个 AI “聊天”，而是建立一条可审计、可恢复、可长期运行的本地协作链路：

```text
Codex 负责设计、拆任务、审查、验收、继续追问
Claude 负责领取任务、执行任务、写回结构化结果
```

> Claudex 不是 Claude API，不是 OpenAI 官方产品，也不是 Anthropic 官方产品。它是一个务实的本地自动化桥，适合已经在同一台 Windows 机器上使用 Codex 和 Claude Desktop 的开发者。

---

## 这个项目实现了什么

Claudex 在本地创建一个默认目录 `C:\ai-bridge`，作为 Codex 和 Claude 之间的文件桥。

它实现了：

- **任务投递**：Codex 把任务写成 JSON 文件，放入 `C:\ai-bridge\inbox`。
- **Claude 唤醒**：本地 daemon 发现新任务后，通过 GUI 自动化唤醒 Claude Desktop/Cowork。
- **任务认领**：Claude 把任务从 `inbox` 移到 `working`，开始执行。
- **结果回写**：Claude 把结果写成 JSON 文件，放入 `outbox`。
- **结构校验**：Codex 使用脚本校验 Claude 返回的 result JSON 是否符合协议。
- **主从协作**：Codex 永远是项目主导，Claude 只是 scoped execution worker。
- **持续运行**：Windows 登录后可自动启动 daemon，持续轮询任务。
- **授权辅助**：提供一个受限 GUI watcher，辅助处理 Claude 对桥接命令的授权提示。

整体链路如下：

```text
Codex master
  |
  | 写入 task JSON
  v
C:\ai-bridge\inbox
  |
  | daemon 唤醒 Claude Desktop
  v
Claude worker
  |
  | 领取任务、执行、写回 result JSON
  v
C:\ai-bridge\outbox
  |
  | Codex 校验、审查、决定下一步
  v
接受结果 / 继续派发修改任务 / Codex 亲自修正
```

---

## 能力边界

Claudex 能做：

- 在同一台 Windows 电脑上桥接 Codex 和 Claude Desktop/Cowork。
- 让 Codex 自动派发任务给 Claude。
- 让 Claude 自动读取任务、执行并回写结果。
- 让 Codex 自动检查结果格式，并把 Claude 输出纳入自己的审查流程。
- 支持长期本地 daemon，减少人工提醒。
- 适合作为 AI 协作开发中的“副手执行层”。

Claudex 不能做：

- 它不能把 Claude Desktop 变成官方 HTTP API。
- 它不能绕过 Claude、Windows 或应用本身的权限控制。
- 它不能保证 Claude GUI 更新后自动化脚本永远不需要维护。
- 它不能在没有 Claude Desktop 登录状态的情况下让 Claude 执行任务。
- 它不能替代 Codex 的审查和决策。
- 它默认不提供公网服务，也不建议把 `C:\ai-bridge` 暴露为网络共享。

安全原则：

- Claude 的输出永远不是最终结果，必须由 Codex 审查。
- GUI approval watcher 是便利层，不是安全边界。
- 任务应尽量小、明确、可验证。
- 不要把敏感凭据写入任务 prompt 或共享目录。

---

## 三种电脑状态如何部署并实现互联

### 场景 A：这台电脑只安装了 Codex

这种情况下，Codex 已经能创建任务和读取结果，但还没有 Claude worker。

步骤：

1. 安装 Claude Desktop，并登录账号。
2. 在 Claude Desktop 中启用/进入 Cowork 模式。
3. 安装 Git、Python，并安装 GUI 自动化依赖：

```powershell
python -m pip install --user --upgrade pywinauto
```

4. 克隆 Claudex：

```powershell
git clone https://github.com/drinkwater-claw/claudex.git
cd claudex
```

5. 安装桥和 daemon：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -BridgeRoot C:\ai-bridge -InstallDaemon -StartDaemon
```

6. 把这个文件里的 worker prompt 交给 Claude：

```text
C:\ai-bridge\docs\CLAUDE_WORKER_PROMPT.md
```

7. 从 Codex 或 PowerShell 发一个测试任务：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Invoke-ClaudeBridgeTask.ps1 `
  -Prompt "Return markdown saying Claudex is connected." `
  -TimeoutSeconds 300
```

完成后，Codex 就可以主导调度 Claude。

### 场景 B：这台电脑只安装了 Claude Desktop

这种情况下，Claude 可以作为 worker，但还没有 Codex master。

步骤：

1. 安装 Codex，并确保 Codex 可以访问本地文件系统。
2. 安装 Git、Python，并安装 GUI 自动化依赖：

```powershell
python -m pip install --user --upgrade pywinauto
```

3. 克隆并安装 Claudex：

```powershell
git clone https://github.com/drinkwater-claw/claudex.git
cd claudex
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -BridgeRoot C:\ai-bridge -InstallDaemon -StartDaemon
```

4. 在 Claude Desktop/Cowork 中打开或粘贴：

```text
C:\ai-bridge\docs\CLAUDE_WORKER_PROMPT.md
```

5. 在 Codex 中要求它使用：

```text
C:\ai-bridge\bin\Invoke-ClaudeBridgeTask.ps1
```

从这一步开始，Codex 可以负责拆任务、调度、审查，Claude 只负责执行。

### 场景 C：一台全新的 Windows 电脑

这是最完整、最推荐的部署路径。

先安装：

- Git for Windows
- Python 3
- PowerShell 5.1+ 或 PowerShell 7+
- Codex
- Claude Desktop

然后执行：

```powershell
python -m pip install --user --upgrade pywinauto
git clone https://github.com/drinkwater-claw/claudex.git
cd claudex
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -BridgeRoot C:\ai-bridge -InstallDaemon -StartDaemon
```

打开 Claude Desktop/Cowork，交给它：

```text
C:\ai-bridge\docs\CLAUDE_WORKER_PROMPT.md
```

运行 smoke test：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\bridge-smoke.ps1
```

运行真实桥接测试：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Invoke-ClaudeBridgeTask.ps1 `
  -Prompt "Return markdown saying Codex is master and Claude is worker." `
  -TimeoutSeconds 300
```

如果 result JSON 出现在 `C:\ai-bridge\outbox`，互联完成。

---

## 运行目录

默认运行目录：

```text
C:\ai-bridge\
  inbox\      Codex 写入待处理任务
  working\    Claude 认领中的任务
  outbox\     Claude 写回的结果
  archive\    已完成任务归档
  locks\      单任务调度锁
  logs\       daemon、invoke、approval 日志
  tmp\        Claude 临时 markdown 响应
  bin\        运行时 PowerShell 脚本
  docs\       worker prompt 和主从策略
  schemas\    JSON schema
  examples\   示例 task/result payload
```

---

## 常用命令

提交任务但不主动唤醒 Claude：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\New-AIBridgeTask.ps1 `
  -Prompt "Review this file and return findings." `
  -ContextFiles "D:\project\src\auth.ts"
```

完整执行一次 Codex -> Claude 调度：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Invoke-ClaudeBridgeTask.ps1 `
  -Prompt "Review D:\project\src\auth.ts for security issues." `
  -ContextFiles "D:\project\src\auth.ts" `
  -TimeoutSeconds 900
```

校验结果：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Test-AIBridgePayload.ps1 `
  -Path C:\ai-bridge\outbox\task-YYYYMMDD-HHMMSS-xxxxxxxx.result.json `
  -Kind result
```

检查 daemon：

```powershell
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -like '*Start-ClaudeBridgeDaemon.ps1*' } |
  Select-Object ProcessId,CommandLine
```

清理 30 天前的运行态文件：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Clear-ClaudeBridgeRuntime.ps1
```

只预览将会清理什么：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Clear-ClaudeBridgeRuntime.ps1 -WhatIf
```

默认只清理 `tmp`、`logs`、`outbox`、`archive` 中超过保留期的文件，不会清理 `bin`、`docs`、`schemas`、`examples`，也不会清理正在流转的 `inbox`、`working`、`locks`。

---

## 测试

运行 smoke test：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\bridge-smoke.ps1
```

这个测试使用临时 bridge root，不需要 Claude Desktop。

---

## 更多文档

- [Architecture](docs/ARCHITECTURE.md)
- [Operations](docs/OPERATIONS.md)
- [Codex Master Policy](docs/CODEX_MASTER_POLICY.md)
- [Claude Worker Prompt](docs/CLAUDE_WORKER_PROMPT.md)
- [Security](SECURITY.md)

---

## English

Claudex is a local Windows bridge that connects **OpenAI Codex** with **Claude Desktop/Cowork**. Codex acts as the project lead and master controller. Claude acts as a subordinate execution worker.

The goal is not to make two AI systems casually chat. The goal is to create a local, observable, recoverable collaboration loop:

```text
Codex designs, plans, delegates, reviews, and decides.
Claude claims scoped tasks, executes them, and writes structured results back.
```

> Claudex is not a Claude API, not an official OpenAI product, and not an official Anthropic product. It is a pragmatic local automation bridge for developers who run Codex and Claude Desktop on the same Windows machine.

## What This Project Implements

Claudex creates a local bridge root, defaulting to `C:\ai-bridge`, and uses JSON files as the coordination protocol.

It provides:

- **Task submission**: Codex writes task JSON files into `C:\ai-bridge\inbox`.
- **Claude wake-up**: a local daemon detects pending tasks and wakes Claude Desktop/Cowork through GUI automation.
- **Task claiming**: Claude moves tasks from `inbox` to `working`.
- **Result writing**: Claude writes structured result JSON into `outbox`.
- **Payload validation**: Codex validates result JSON before reviewing it.
- **Master-worker workflow**: Codex remains the lead; Claude only executes scoped work.
- **Long-running daemon**: a Windows logon task can keep the bridge running.
- **Approval helper**: a limited GUI watcher can help with bridge-related Claude command prompts.

## Capability Boundaries

Claudex can:

- Bridge Codex and Claude Desktop/Cowork on the same Windows machine.
- Let Codex delegate scoped tasks to Claude.
- Let Claude read tasks, execute them, and write results.
- Let Codex validate and review Claude output.
- Run as a local daemon for long-lived workflows.

Claudex cannot:

- Turn Claude Desktop into an official HTTP API.
- Bypass Claude, Windows, or application permissions.
- Guarantee GUI automation will survive every Claude Desktop UI update.
- Run Claude tasks if Claude Desktop is closed, signed out, or unavailable.
- Replace Codex review and decision-making.
- Safely expose the bridge directory as a public or network service.

Security model:

- Claude output is never final until Codex validates and reviews it.
- The approval watcher is a convenience layer, not a security boundary.
- Keep tasks small, explicit, and verifiable.
- Do not put secrets into prompts or bridge files.

## Deployment Scenarios

### Scenario A: The Machine Only Has Codex Installed

Codex can submit and inspect tasks, but there is no Claude worker yet.

1. Install Claude Desktop and sign in.
2. Enable or open Cowork mode.
3. Install Git, Python, and the GUI dependency:

```powershell
python -m pip install --user --upgrade pywinauto
```

4. Clone and install Claudex:

```powershell
git clone https://github.com/drinkwater-claw/claudex.git
cd claudex
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -BridgeRoot C:\ai-bridge -InstallDaemon -StartDaemon
```

5. Give Claude this worker prompt:

```text
C:\ai-bridge\docs\CLAUDE_WORKER_PROMPT.md
```

6. Run a bridge task:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Invoke-ClaudeBridgeTask.ps1 `
  -Prompt "Return markdown saying Claudex is connected." `
  -TimeoutSeconds 300
```

### Scenario B: The Machine Only Has Claude Desktop Installed

Claude can act as a worker, but there is no Codex master yet.

1. Install Codex and ensure it can access the local filesystem.
2. Install Git, Python, and `pywinauto`.
3. Clone and install Claudex:

```powershell
git clone https://github.com/drinkwater-claw/claudex.git
cd claudex
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -BridgeRoot C:\ai-bridge -InstallDaemon -StartDaemon
```

4. In Claude Desktop/Cowork, open or paste:

```text
C:\ai-bridge\docs\CLAUDE_WORKER_PROMPT.md
```

5. In Codex, instruct it to use:

```text
C:\ai-bridge\bin\Invoke-ClaudeBridgeTask.ps1
```

From that point on, Codex can delegate, review, and refine; Claude executes only scoped tasks.

### Scenario C: A Fresh Windows Machine

Install:

- Git for Windows
- Python 3
- PowerShell 5.1+ or PowerShell 7+
- Codex
- Claude Desktop

Then run:

```powershell
python -m pip install --user --upgrade pywinauto
git clone https://github.com/drinkwater-claw/claudex.git
cd claudex
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -BridgeRoot C:\ai-bridge -InstallDaemon -StartDaemon
```

Give Claude Desktop/Cowork:

```text
C:\ai-bridge\docs\CLAUDE_WORKER_PROMPT.md
```

Run the smoke test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\bridge-smoke.ps1
```

Run an end-to-end bridge task:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Invoke-ClaudeBridgeTask.ps1 `
  -Prompt "Return markdown saying Codex is master and Claude is worker." `
  -TimeoutSeconds 300
```

If result JSON appears in `C:\ai-bridge\outbox`, the bridge is connected.

## Disk Usage And Cleanup

The fixed runtime files are small. The directories that can grow over time are:

- `tmp`: temporary markdown responses.
- `logs`: daemon, invoke, and approval logs.
- `outbox`: Claude result JSON files.
- `archive`: completed task JSON files.

Clean files older than 30 days:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Clear-ClaudeBridgeRuntime.ps1
```

Preview cleanup without deleting:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Clear-ClaudeBridgeRuntime.ps1 -WhatIf
```

Use a custom retention period:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Clear-ClaudeBridgeRuntime.ps1 -RetentionDays 7
```

By default the cleanup script only touches `tmp`, `logs`, `outbox`, and `archive`. It does not delete runtime scripts, docs, schemas, examples, pending tasks, active tasks, or lock files.

## License

MIT. See [LICENSE](LICENSE).
