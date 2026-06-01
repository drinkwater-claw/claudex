# Collaboration Playbook

**中文** | [English](#english)

本手册说明如何把 Claudex 用成一套长期稳定的主从协作系统：Codex 做主控大脑，Claude Desktop/Cowork 做执行 worker；如果 Claude Desktop 通过 CC Switch 路由到 DeepSeek V4 或其他第三方模型，worker 仍然只负责可验证的执行任务。

目标不是让低成本 worker 模型“假装等同”高端模型，而是通过任务拆分、结构化交付、Codex 审查和测试验收，尽量接近全程使用高端前沿模型的项目质量，同时显著节省 Codex 额度。

> 本文中的 CC Switch/DeepSeek 路线是推荐 worker provider 方案之一，不是 Claudex 的硬依赖。Claudex 只要求 Claude Desktop/Cowork 能按 worker prompt 读写本地桥接文件。

---

## 角色分工

Codex 永远负责：

- 项目目标理解和方案设计。
- 任务拆分和优先级判断。
- 决定哪些工作交给 worker，哪些必须自己完成。
- 审查 worker 输出，包括正确性、安全性、边界条件和风格一致性。
- 运行或要求运行关键测试。
- 最终验收、提交、发布和对用户解释结果。

Claude Desktop/Cowork worker 负责：

- 读取 Codex 分配的窄任务。
- 做初步代码阅读、总结、草稿、重复性编辑建议。
- 写第一版实现、第一版测试或第一版文档。
- 返回结构化 result JSON 和 markdown 结果。
- 明确报告假设、无法访问的文件、未运行的测试和阻塞点。

worker 不负责：

- 直接决定项目方向。
- 直接把自己的结果视为最终结果。
- 接受用户需求、扩大范围或自行创建长期目标。
- 处理敏感凭据、权限绕过或不可审计的外部操作。

---

## 省额度阶梯

每个任务都从最低成本层开始，只有必要时才升级。

```text
第 1 层：本地工具、搜索、shell、git、测试命令
  成本：0 Codex 额度

第 2 层：Claude Desktop/Cowork worker（可通过 CC Switch 路由 DeepSeek V4）
  成本：消耗 worker 后端，不消耗 Codex 主要推理额度

第 3 层：Codex 审查 worker 输出
  成本：少量 Codex 额度，重点花在判断和验收

第 4 层：Codex 直接实现
  成本：最高，只用于高风险或 worker 失败的工作
```

推荐规则：

- 能用 `rg`、`git diff`、测试命令和本地脚本解决的，先不用任何模型。
- 需要大段阅读、草稿、重复性修改、表格化总结时，优先交给 worker。
- worker 输出必须回到 Codex 这里过审；Codex 用少量上下文检查结论、风险和测试结果。
- 涉及核心架构、安全边界、数据迁移、发布流程、权限控制时，Codex 直接主导，worker 只可做辅助调查。

这套模式省额度的关键不是“让 worker 代替 Codex”，而是让 Codex 只在判断最值钱的地方出手。

---

## CC Switch + DeepSeek Worker 配置原则

CC Switch 可用于管理 Claude Desktop 的第三方 provider 配置。根据 CC Switch 文档，Claude Desktop 的配置入口和 Claude Code 不同；非 Claude 模型，例如 DeepSeek、Kimi、DouBao、OpenAI、Gemini，通常需要使用 model mapping，把 Claude Desktop 的 Sonnet/Opus/Haiku 角色路由映射到实际后端模型。切换 provider 后通常需要重启 Claude Desktop 才生效。

实操建议：

- 在 CC Switch 中为 Claude Desktop 单独配置 provider，不要把 Claude Code 的配置误认为 Claude Desktop 配置。
- 如果后端是 DeepSeek V4 这类非 Claude 模型，启用 model mapping。
- 常见映射方式是把 Claude Desktop 的 Sonnet 路由映射到主要 worker 模型，把 Haiku 路由映射到轻量模型，把 Opus 路由保留给最强可用后端。
- 运行 Claudex 时保持 CC Switch 和本地 provider 路由可用。
- 每次切换 provider 后，重启 Claude Desktop，并用 Claudex 的端到端测试确认 worker 仍能领取和完成任务。

推荐验收命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Invoke-ClaudeBridgeTask.ps1 `
  -Prompt "Return markdown saying the Claudex worker route is active. Include the model/provider name if visible." `
  -TimeoutSeconds 300
```

如果命令超时，先检查 Claude Desktop 是否登录、CC Switch provider 是否启用、Claude Desktop 是否重启过、`C:\ai-bridge\logs` 是否有窗口唤醒或授权错误。

参考：

- [CC Switch official site](https://cc-switch.cc/en)
- [CC Switch Claude Desktop provider documentation](https://github.com/farion1231/cc-switch/blob/main/docs/user-manual/en/2-providers/2.6-claude-desktop.md)

---

## 什么任务适合交给 worker

适合交给 worker：

- 针对 1 到 5 个文件的代码阅读和总结。
- 写第一版文档、README 小节、排障表。
- 写小函数、小组件、小测试。
- 按明确规则重排、重命名、补充注释。
- 对 diff 做第一轮风险扫描。
- 根据 Codex 给出的验收标准补齐边界测试。

不适合直接交给 worker：

- “把整个项目做好”。
- 大范围架构重构。
- 安全敏感逻辑，例如鉴权、加密、权限、支付、数据删除。
- 需要真实业务判断的产品取舍。
- 发布、签名、密钥、凭据、生产环境操作。
- worker 已经两次同类失败的任务。

升级规则：

- worker 第一次失败：Codex 缩小任务，补充上下文，给出更明确验收标准。
- worker 第二次同类失败：Codex 改成调查任务，或直接接手。
- worker 输出可用但不稳：Codex 只吸收思路，自己重写关键实现。
- worker 输出通过测试但涉及高风险：Codex 仍要做人工级别审查。

---

## 好任务的规格

每个 worker 任务都应包含：

- 单一目标：只做一件事。
- 文件边界：列出 `context_files`，不要让 worker 自由漫游整个仓库。
- 验收标准：用可判断的清单写明完成条件。
- 输出格式：要求 markdown 报告、diff block、JSON checklist 或测试结果。
- 测试指令：告诉 worker 需要运行什么命令，或者说明不能运行时如何报告。
- 禁止事项：明确不要改哪些文件、不要引入哪些依赖、不要扩大范围。

推荐模板：

```text
任务：在 <target_file> 中实现 <specific_change>。

上下文文件：
- <target_file>
- <related_test_file>
- <small_related_file>

验收标准：
- <criterion_1>
- <criterion_2>
- <criterion_3>

输出格式：
- 返回 markdown。
- 包含变更摘要、diff block、测试结果、风险和未解决问题。

测试：
- 运行 <test_command>。
- 如果无法运行，说明原因，不要假装测试通过。

限制：
- 不要修改未列出的文件。
- 不要新增依赖。
- 不要改变公开 API，除非验收标准明确要求。
```

---

## 质量闭环

```text
用户目标
  |
  v
Codex 理解目标、设计方案、拆成小任务
  |
  v
worker 执行一个小任务并写回 result JSON
  |
  v
Codex 结构校验：Test-AIBridgePayload.ps1
  |
  v
Codex 语义审查：正确性、边界、安全、风格、测试
  |
  +-- 通过：Codex 整合、运行验证、提交或继续下一任务
  |
  +-- 不通过：Codex 写出具体缺陷，派发更窄的 follow-up
```

Codex 审查 worker 输出时至少问 7 个问题：

1. 它是否严格回答了原任务？
2. 它是否引用了真实文件和真实代码？
3. 它是否偷偷扩大了范围？
4. 它是否遗漏边界条件？
5. 它是否引入新依赖或新风险？
6. 它报告的测试是否真实运行？
7. 如果把这段结果发给用户，是否会让用户误以为 worker 输出已经最终通过？

只有第 7 个问题也安全时，Codex 才能把结果作为最终交付的一部分。

---

## 最省额度的功能开发流程

1. Codex 用本地工具读代码。

```powershell
rg "相关关键词" D:\project\src
git status --short
git diff --stat
```

2. Codex 写出 3 到 7 条设计要点，不把整个仓库塞给模型。
3. Codex 把第一版探索或草稿交给 worker。
4. worker 返回报告或 diff。
5. Codex 只读取 worker 输出和必要的目标文件，做审查。
6. Codex 对可用部分进行整合，自己处理高风险细节。
7. Codex 运行测试。
8. 如果测试失败，Codex 判断是自己修、还是派一个更窄的修复任务。
9. Codex 最终总结：变更、测试、风险、下一步。

这样 Codex 的额度主要花在“判断”上，不花在“让模型大段读文件和写第一版草稿”上。

---

## 反模式

不要这样：

```text
帮我把整个项目优化一下。
```

应该这样：

```text
审查 D:\project\src\auth.ts 的输入校验问题。
只返回 findings，不修改文件。
每条 finding 包含：位置、风险、建议修复。
```

不要这样：

```text
worker 返回了代码，所以直接复制进去。
```

应该这样：

```text
Codex 校验 result JSON，阅读 diff，检查边界条件，运行测试，然后决定整合或返工。
```

不要这样：

```text
这是 API key：sk-...
```

应该这样：

```text
代码应从环境变量 API_KEY 读取密钥。参考 .env.example，不要在任务中写真实密钥。
```

不要这样：

```text
worker 失败了，再发同一个任务。
```

应该这样：

```text
Codex 先判断失败原因，然后缩小任务、补充上下文、降低输出要求，或直接接手。
```

---

## 给 Codex 的调度 prompt

用户可以把这段交给 Codex，要求它按 Claudex 的省额度模式工作：

```text
请按 Claudex master-worker 模式执行。

你是 Codex master：负责架构、任务拆分、审查、验收和最终交付。
Claude Desktop/Cowork 是 worker：只执行你派发的小任务。

省额度规则：
1. 先用本地 shell/git/rg/test 获取信息。
2. 把探索、草稿、重复性编辑和第一版测试交给 worker。
3. 你必须校验 worker result JSON，并审查内容后才能采纳。
4. 高风险、安全敏感、架构关键和发布相关工作由你亲自处理。
5. worker 连续两次同类失败时，不要无限重试；缩小任务或直接接手。

请先给出任务拆分，然后执行第一步。
```

---

## 给 worker 的任务模板

```text
你是 Claudex worker。Codex 是 master 和最终审查者。

只执行下面这个任务，不扩大范围。

任务：
<one specific task>

上下文文件：
<file_1>
<file_2>

验收标准：
- <criterion_1>
- <criterion_2>
- <criterion_3>

输出要求：
- Markdown。
- 包含：摘要、具体结果、测试/验证、风险、未解决问题。
- 如果需要代码，返回 diff block，不要声称已经最终合并。

限制：
- 不要读取未授权文件。
- 不要写入敏感信息。
- 不要做产品方向决定。
- 如果无法完成，返回 failed 并解释阻塞原因。
```

---

## 速查表

| 问题 | 答案 |
| --- | --- |
| 谁做主？ | Codex |
| 谁执行？ | Claude Desktop/Cowork worker，可通过 CC Switch 路由 DeepSeek V4 |
| 谁验收？ | Codex |
| worker 输出能直接给用户吗？ | 不能，必须 Codex 审查 |
| 怎样省 Codex 额度？ | 本地工具优先，worker 做草稿和重复劳动，Codex 做判断 |
| 怎样接近高端模型全程完成的质量？ | 小任务、明确验收、结构校验、语义审查、测试闭环 |
| worker 失败怎么办？ | 缩小任务、补充上下文、重试一次；同类失败两次后 Codex 接手 |
| 可以把密钥写进任务吗？ | 不可以 |

---

## English

This playbook explains how to run Claudex as a long-lived master-worker collaboration system: Codex is the master controller, and Claude Desktop/Cowork is the execution worker. If Claude Desktop is routed through CC Switch to DeepSeek V4 or another third-party model, that worker still only handles verifiable execution tasks.

The goal is not to pretend a lower-cost model is automatically equivalent to a premium frontier model. The goal is to use task decomposition, structured outputs, Codex review, and test gates to approach premium-model project quality while saving Codex quota.

> The CC Switch/DeepSeek path is a recommended worker provider option, not a hard dependency. Claudex only requires Claude Desktop/Cowork to follow the worker prompt and read/write the local bridge files.

## Roles

Codex always owns:

- Product and project understanding.
- Architecture and implementation strategy.
- Task decomposition and prioritization.
- Deciding what to delegate and what to handle directly.
- Reviewing worker output for correctness, safety, edge cases, and style.
- Running or requiring important tests.
- Final acceptance, commits, releases, and user-facing explanations.

The Claude Desktop/Cowork worker owns:

- Reading narrow tasks assigned by Codex.
- First-pass exploration, summaries, drafts, repetitive edits, and tests.
- Returning structured result JSON and markdown.
- Reporting assumptions, missing file access, skipped tests, and blockers.

The worker does not own:

- Project direction.
- Final acceptance.
- Scope expansion.
- Sensitive credentials, permission bypasses, or unaudited external operations.

## The Budget Ladder

Start every task at the cheapest useful layer and escalate only when needed.

```text
Layer 1: local tools, search, shell, git, tests
  Cost: zero Codex quota

Layer 2: Claude Desktop/Cowork worker, optionally routed through CC Switch + DeepSeek V4
  Cost: worker-side compute, minimal Codex reasoning

Layer 3: Codex reviews worker output
  Cost: small Codex spend, focused on judgment and acceptance

Layer 4: Codex implements directly
  Cost: highest, reserved for risky or failed work
```

Recommended rules:

- If `rg`, `git diff`, tests, or local scripts can answer it, do that first.
- Delegate broad reading, drafts, repetitive edits, tables, and first-pass tests to the worker.
- Always bring worker output back to Codex for review.
- Keep architecture, security, migrations, releases, permissions, and production operations under direct Codex control.

The quota-saving trick is not replacing Codex. It is spending Codex only where judgment matters most.

## CC Switch + DeepSeek Worker Principles

CC Switch can manage third-party provider configuration for Claude Desktop. According to CC Switch documentation, Claude Desktop and Claude Code use different configuration entry points. Non-Claude models such as DeepSeek, Kimi, DouBao, OpenAI, and Gemini usually require model mapping so Claude Desktop role routes such as Sonnet/Opus/Haiku can point to the real backend model. After switching providers, Claude Desktop usually needs a restart.

Practical guidance:

- Configure the Claude Desktop provider separately in CC Switch.
- Enable model mapping when the backend is a non-Claude model such as DeepSeek V4.
- A common setup is Sonnet route to the main worker model, Haiku route to a lighter model, and Opus route to the strongest available backend.
- Keep CC Switch and the local provider route running while using Claudex.
- After switching providers, restart Claude Desktop and run an end-to-end Claudex test.

Recommended validation command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ai-bridge\bin\Invoke-ClaudeBridgeTask.ps1 `
  -Prompt "Return markdown saying the Claudex worker route is active. Include the model/provider name if visible." `
  -TimeoutSeconds 300
```

References:

- [CC Switch official site](https://cc-switch.cc/en)
- [CC Switch Claude Desktop provider documentation](https://github.com/farion1231/cc-switch/blob/main/docs/user-manual/en/2-providers/2.6-claude-desktop.md)

## Good Worker Tasks

Good worker tasks are:

- Single-purpose.
- Bounded to a small list of files.
- Driven by clear acceptance criteria.
- Explicit about output format.
- Explicit about tests.
- Clear about what must not change.

Template:

```text
Task: implement <specific_change> in <target_file>.

Context files:
- <target_file>
- <related_test_file>
- <small_related_file>

Acceptance criteria:
- <criterion_1>
- <criterion_2>
- <criterion_3>

Output:
- Markdown.
- Include summary, diff block, test results, risks, and open questions.

Test:
- Run <test_command>.
- If you cannot run it, say why. Do not claim tests passed.

Limits:
- Do not edit unlisted files.
- Do not add dependencies.
- Do not change public APIs unless explicitly requested.
```

## Quality Loop

```text
User goal
  |
  v
Codex designs and decomposes
  |
  v
Worker executes one narrow task
  |
  v
Codex validates result JSON
  |
  v
Codex reviews correctness, safety, style, and tests
  |
  +-- accept: integrate, verify, commit, or continue
  |
  +-- reject: send a narrower follow-up with concrete defects
```

Codex should ask:

1. Did the worker answer the actual task?
2. Did it ground claims in real files and code?
3. Did it silently expand scope?
4. Did it miss edge cases?
5. Did it add dependencies or risk?
6. Were tests actually run?
7. Would showing this to the user imply the worker result is final before Codex approval?

## Minimal-Quota Feature Workflow

1. Codex surveys locally:

```powershell
rg "relevant keyword" D:\project\src
git status --short
git diff --stat
```

2. Codex writes 3 to 7 design notes instead of loading the whole repo into a model.
3. Codex delegates exploration, drafts, or first-pass tests to the worker.
4. The worker returns a report or diff.
5. Codex reads the worker result plus the target files only.
6. Codex integrates useful parts and handles risky details directly.
7. Codex runs tests.
8. If tests fail, Codex decides whether to fix directly or send a narrower repair task.
9. Codex finalizes with changes, tests, risks, and next steps.

## Anti-Patterns

Bad:

```text
Make the whole project better.
```

Good:

```text
Review D:\project\src\auth.ts for input validation issues.
Return findings only. Do not edit files.
Each finding must include location, risk, and suggested fix.
```

Bad:

```text
The worker returned code, so copy it directly.
```

Good:

```text
Codex validates the result JSON, reviews the diff, checks edge cases, runs tests, then decides whether to integrate.
```

Bad:

```text
Here is the API key: sk-...
```

Good:

```text
Read the key from API_KEY. See .env.example for the variable name. Never put the real key in the task.
```

Bad:

```text
The worker failed, so send the exact same task again.
```

Good:

```text
Codex diagnoses the failure, narrows the task, adds context, lowers output complexity, or handles it directly.
```

## Codex Coordination Prompt

```text
Use Claudex master-worker mode.

You are Codex master: architecture, decomposition, review, acceptance, and final delivery.
Claude Desktop/Cowork is the worker: it only executes narrow tasks assigned by you.

Quota rules:
1. Use local shell/git/rg/tests first.
2. Delegate exploration, drafts, repetitive edits, and first-pass tests to the worker.
3. Validate worker result JSON and review content before accepting it.
4. Handle high-risk, security-sensitive, architecture-critical, and release tasks directly.
5. If the worker fails twice with the same error class, stop retrying and either narrow the task or take over.

First produce the task breakdown, then execute step one.
```

## Worker Task Prompt

```text
You are the Claudex worker. Codex is the master and final reviewer.

Execute only this task. Do not expand scope.

Task:
<one specific task>

Context files:
<file_1>
<file_2>

Acceptance criteria:
- <criterion_1>
- <criterion_2>
- <criterion_3>

Output:
- Markdown.
- Include summary, concrete result, tests/verification, risks, and open questions.
- If code is needed, return diff blocks. Do not claim final merge.

Limits:
- Do not read unauthorized files.
- Do not write secrets.
- Do not make product direction decisions.
- If blocked, return failed and explain why.
```

## Quick Reference

| Question | Answer |
| --- | --- |
| Who leads? | Codex |
| Who executes? | Claude Desktop/Cowork worker, optionally routed through CC Switch + DeepSeek V4 |
| Who accepts? | Codex |
| Can worker output go straight to the user? | No. Codex reviews first |
| How do we save Codex quota? | Local tools first, worker for drafts and repetitive work, Codex for judgment |
| How do we approach premium-model quality? | Small tasks, acceptance criteria, structural validation, semantic review, tests |
| What if the worker fails? | Narrow and retry once; after repeated same-class failures, Codex takes over |
| Can tasks include secrets? | No |
