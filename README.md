# BELCORT Harness

**Planner → Generator → Evaluator pipeline for Claude Code.**
File-based, git-tracked, opinionated. Adapted from Anthropic's engineering research on long-running agent harnesses.

```
user idea  →  Planner (spec)  →  Generator ↔ Evaluator negotiate  →  Generator BUILD (TDD)  →  Evaluator EVALUATE (Playwright + grade)  →  retrospective  →  merge
```

Three fresh subagents. Isolated contexts. No chat back-channel. Every decision recorded on disk. Designed so the agent doing the work never sees the agent judging it — the GAN insight from Anthropic's research, which is the single most reliable lever for producing decent code from LLMs.

---

## v2.2-staging 更新说明（2026-04-27 · 中文）

> 本分支基于 v2.1.9，新增**完整的设计循环**——让没有技术 / 设计背景的 AI-first 用户能用「先出原型 → 验证 → 再写代码」的工作流构建产品。

### 为什么有这个分支

v2.1.9 的 BELCORT 是**工程化 harness**——擅长把 spec 转成 production-grade 代码。但对没有技术 / 设计背景的用户来说，**spec 是黑盒**：纯文字描述里「用户可以筛选 bookmark」看起来都对，真做出来才发现错。这时已经投入了大量工程时间，返工代价很高。

v2.2-staging 加了一个 **Designer subagent** 和 `/harness:design` 命令族，把「判断成本」从代码完成后**前移到原型阶段**——失败几分钟就丢，工程师一行代码不动。

### 更新清单

| # | Commit | 改动 | 解决什么问题 |
|---|---|---|---|
| 1 | `2efafd0` | karpathy-guidelines 集成 | LLM 写代码常犯的 4 大失败模式（过度复杂、隐藏假设、scope 蔓延、模糊验收）三个 agent 都内置了反制 |
| 2 | `1c4289f` | Context7 强制审计 | Context7 之前是「软指令」，现在是「可审计契约」——架构 log + Generator coverage + Evaluator audit 三层闸门 |
| 3 | `fb9aad8` + `e9f6c8d` | Designer subagent + `/harness:design` 命令骨架（Step 1） | 引入第 4 个 subagent；EXPLORE / REROLL 模式上线 |
| 4 | `0b41c93` | TEACH 模式 + sprint 设计上下文注入（Step 2） | 设计系统 codify 成 DESIGN.md，sprint 自动读 |
| 5 | `4a5c0cb` + `b400120` | AUDIT 模式 + 自动审计闸门 + P0 重试循环（Step 3） | sprint Evaluator PASS 后自动跑设计审计，P0 自动重跑 BUILD（cap 2 次） |
| 6 | `8d8ab0d` | EXTRACT 模式 + brownfield 检测（Step 4） | 已有项目能从源码抽 design tokens；brownfield 自动识别 |
| 7 | `9ed8007` + `d201b1a` | REROLL 增强 + `--reference-image` 输入（Step 5） | reroll 历史感知 + 5 轮预算 + 可附参考图锚定方向 |

### 各更新详细说明

#### 1. karpathy-guidelines 集成（`2efafd0`）

把 [Andrej Karpathy 关于 LLM 写代码的反 slop 原则](https://x.com/karpathy/status/2015883857489522876)分别映射到三个 agent：

- **Generator**：全部 4 条原则（思考再写、最简实现、外科手术式改动、可验证目标驱动）
- **Evaluator**：作为审查 lens，识别过度工程、隐藏假设、scope 蔓延
- **Planner**：narrow slice——只用 §K1（思考再写：surface assumptions 显式化）+ §K4（可验证 AC / NFR）

**为什么需要**：LLM 写代码默认会过度复杂化、生成不必要的抽象、对 task 做隐性假设。Karpathy 的原则是反制这些的具体行动指引。

#### 2. Context7 强制审计（`1c4289f`）

之前 Context7 是 “MUST use” 的软指令，agent 可以声称用了但没证据。现在变成**可审计的工作流契约**：

- **Planner**：`spec/architecture.md` 加强制 `## Context7 Verification Log` 表（每个库一行：版本、上次发布、维护状态、对比的备选）+ V9 / V9b self-validation 闸门
- **Generator**：`proposal.md` 加强制 `## Context7 Lookups Performed`；`implementation-report.md` 加强制 `## Context7 Coverage`
- **Evaluator**：REVIEW-PROPOSAL 和 EVALUATE 都加 Context7 完整性检查（grep `src/` 里的 imports 跨对照两份 log，发现未审计 lib 直接 finding）

**为什么需要**：real-use sprint 实测发现 agent 命名了过时 lib 或用 training-data 里的旧 API。强制 artifact + 自动 audit 关闭这个 gap。

#### 3. Designer subagent + `/harness:design` 命令（Step 1：`fb9aad8`、`e9f6c8d`）

引入第 4 个 subagent `harness:designer`，5 个模式（EXPLORE / REROLL / TEACH / AUDIT / EXTRACT）。Step 1 实现 **EXPLORE + REROLL**：

- `/harness:design explore "<intent>"`——huashu-design 出 3 个不同设计哲学方向 → 用户挑一个 → 生成 hi-fi 可点击 HTML 原型 + Playwright 验证
- `/harness:design reroll "<feedback>"`——用户不满意，附 feedback 重抽

**为什么需要**：非技术用户能「看图说话」判断对 / 不对，但写不出好 spec。原型给他们一个能用产品本能反应的 artifact。

**Follow-up（`e9f6c8d`）** 修了 Evaluator 抓出的 4 MAJOR + 3 MINOR：REROLL 步骤编号矛盾、`.harness/` 路径前缀漏写 4 处、缺 working-directory contract、huashu 输出捕获方式没说清。

#### 4. TEACH 模式 + sprint 设计上下文注入（Step 2：`0b41c93`）

- **TEACH 模式**：用户验证完原型后跑 `/harness:design teach`——impeccable 把原型 codify 成 `.harness/design/DESIGN.md`（设计 tokens、原则、反 patterns、动效、可访问性）
- **sprint.md INPUT 补丁**：Planner Step 1 + Generator BUILD 现在条件性读 `.harness/design/{prototype.html, DESIGN.md, PRODUCT.md}` 作为输入——条件性意味着没有这些文件的 sprint 行为完全不变

**为什么需要**：原型只是视觉契约；要让 Planner 写 PRD 和 Generator 写代码时都尊重这个契约，得有可机读的 DESIGN.md 桥接。

#### 5. AUDIT 模式 + 自动审计闸门 + P0 重试循环（Step 3：`4a5c0cb`、`b400120`）

整个 v1 改动最大的一步：

- **AUDIT 模式**：包 impeccable 5 维度 audit（Accessibility / Performance / Theming / Responsive Design / Anti-Patterns）+ **宪法交叉检查**（任何违反 `spec/constitution.md` 的发现自动升级 P0，无视 impeccable 给的 0-4 分）
- **sprint 自动审计闸门**：Evaluator PASS 后自动 dispatch designer AUDIT。P0 → 自动重跑 BUILD（cap 2 次），P1 → 用户决定，P2 / P3 → 记录
- **`/harness:design audit`**：用户手动审计（不带自动重试，纯展示）

**为什么需要**：sprint 验完功能但不验视觉。Generator 可能写出「功能对但难看 / 违反 constitution 的 a11y」代码——之前没人接住。

**Follow-up（`b400120`）** 修了 Evaluator 抓出的 2 个 CRITICAL bash bug：
- `grep -c PATTERN file 2>/dev/null || echo "0"`——零匹配存在文件时 grep 同时输出 `0` + exit 1，触发 `||` 后再输出一个 `0\n0`，整数比较失败让 clean audit 跑成失败重试
- `$(cat \"...\")`——反斜杠在 `$(...)` 里是字面量，cat 收到带引号字符的文件名找不到文件，让 AUDIT_FEEDBACK 内容为空

这两个都是 LLM 自己写的、看着对实际错的 bash idiom——单 agent 模式很难自查这种盲点，**这就是 generator + evaluator 双 agent 模式的价值**。

#### 6. EXTRACT 模式 + brownfield 检测（Step 4：`8d8ab0d`）

- **EXTRACT 模式**：包 impeccable 的 `document` Scan mode（**只读**抽 tokens——刻意避开 impeccable 自己的 `extract` flow，那个会改源码）。输出到 `.harness/design/extraction/extracted-tokens.md`，含 confidence 评级（HIGH / MEDIUM / LOW）
- **`/harness:design explore` brownfield gate**：检测到已有项目（`package.json` + `src/` 有内容）但还没 extract → 警告用户先 extract
- **sprint.md 友好跳过**：brownfield 没 DESIGN.md 时审计闸门优雅跳过，不会硬 fail

**为什么需要**：往已有 app 加 feature 时，AI 不能从零生成方向（会跟现有视觉脱节）。先抽现有 design tokens 作为约束。

**关键决策**：Generator 自己核了 impeccable 源码，发现 `document` 是只读的、`extract` 会改源码——选了 `document`。如果误用 `extract`，brownfield 模式会**无声修改用户源代码**。这种实证验证而非盲信 brief 的工作方式是 v2.2 idiom。

#### 7. REROLL 增强 + `--reference-image`（Step 5：`9ed8007`、`d201b1a`）

最后一步，体验 polish：

- **REROLL 历史感知**：读 prior `directions-summary.md` 的 `## Reroll History`，累积 ban list（之前用过的哲学 / 调色板 / 布局），保证新 round 真的不同
- **轮次预算硬上限 5 轮**：到顶 halt + 3 个 escape 选项（接受现有 / 重新 explore / 加参考图）
- **Feedback → constraint 翻译**：用户的「more editorial」被翻译成具体约束（哲学倾向、调色板限制、布局密度）
- **`--reference-image <path>` 选项**（EXPLORE + REROLL 都支持）：用户附图作为方向锚点。最多 3 张图。pre-validation 校验路径

**为什么需要**：之前 reroll 只是把 feedback 当字符串传给 huashu，没保证新 round 跟旧 round 真的不同。参考图是「用户在跟 AI 设计审美对话」这个根本问题最强的 mitigation——直接附图比文字描述精确得多。

**Follow-up（`d201b1a`）** 修了 Evaluator 抓出的 1 个 CRITICAL：round counter off-by-one——首次 reroll 同时写了 Round 1 + Round 2 共 2 entries，导致后续 round 编号全部偏移 1，cap 提前一轮触发。

### 端到端工作流

#### Greenfield（从零做新产品）

```
/harness:design explore "要做的产品" [--reference-image ~/inspiration.jpg]
   → 3 个不同设计哲学方向 → 选 1 → hi-fi 可点击原型

（如果 3 个都不喜欢）
/harness:design reroll "feedback" [--reference-image ~/another.jpg]
   → 历史感知重抽，5 轮预算

/harness:design teach
   → impeccable codify 原型 → .harness/design/DESIGN.md

/harness:sprint "build feature 1"
   → Planner 自动读 prototype + DESIGN.md
   → Generator BUILD 应用 design tokens
   → Evaluator PASS 后自动 AUDIT
   → P0 自动重跑 BUILD（cap 2 次）
   → 全过 → merge
```

#### Brownfield（往已有产品加 feature）

```
/harness:design explore "新 feature"
   → 检测到 brownfield + 没 extraction → 警告

/harness:design extract
   → impeccable document scan-mode（只读）→ extracted-tokens.md

/harness:design teach
   → 用 extraction 写 DESIGN.md（结合现有 app 风格）

/harness:design explore "新 feature"   ← 重新跑
   → 现在有 DESIGN.md 约束，方向跟现有 app 一致

后面流程同 greenfield
```

### 总改动量（基于 v2.1.9）

- **10 个 commit**（5 个 step 主 commit + 4 个 follow-up + karpathy + Context7）
- **11 个文件改动**，**+2459 行 / -4 行**——零删除其他东西

### 设计哲学

整套循环遵循 BELCORT 的核心原则：

1. **GAN 隔离**：Designer 写 design artifacts，Generator 写代码，Evaluator 审两者——三方互不污染
2. **文件契约**：所有 inter-agent 通信经 `.harness/design/` 文件，不经 chat
3. **可审计 artifact**：每个 mode 都产出可读 markdown，用户和 Evaluator 都能查
4. **失败前移**：原型阶段 catch 大部分错误，工程阶段只面对验证过的设计
5. **conditional injection**：设计循环是 opt-in 的——不跑 design 命令的 sprint 行为完全不变

### 已知未来工作

Step 5 Evaluator 在 v1 retrospective 里点出 3 件未来要验证或修的事：

1. **huashu-design 的 `--reference-image` 实际效果**：BELCORT wiring 正确，但 huashu 实际能不能「读本地图片让它影响 palette」还需真实测过——可能是 silent no-op
2. **Brownfield gate 不在 reroll 时触发**：用户 explore 时被 warn 接受了，reroll 时附新图风格可能跟现有 app 撞，没人提醒
3. **Reroll history 损坏的恢复**：如果用户手动改坏 `directions-summary.md` 的 History 段，Designer 当前没明确 halt

这些都不影响 v1 跑通，作为 v2 候选。

### 给使用者的下一步建议

1. **重启 Claude Code**：让本地 plugin 加载 v2.2-staging 的 Designer + 新命令
2. **真项目测一次完整流程**：是验证 synthesis 是否真的对的最直接方式
3. **决定是否合并**：staging → v2-beta（进活跃开发分支）或 → main（出新 release）

---

## Why this exists

Most "AI code generators" are a single LLM doing everything — planning, coding, self-grading — in one fat context. That setup produces confident-looking but fragile output: the generator reliably praises its own work, misses edge cases because its context is already contaminated with its own assumptions, and skips tests it knows are failing.

The fix — documented in [*Harness design for long-running application development*](https://www.anthropic.com/engineering/harness-design-long-running-apps) (Rajasekaran 2026) — is **specialization through decomposition with isolated contexts**:

> *"Separating the agent doing the work from the agent judging it proves to be a strong lever."*

BELCORT is a production-grade implementation of that harness, shipped as a Claude Code plugin.

---

## Quick start

### Install

In Claude Code:

```
/plugin marketplace add https://github.com/mosaladtaooo/belcort-harness.git#v2-beta
/plugin install harness@belcort-harness
/reload-plugins
```

Verify: `/plugin` → Installed tab → `harness@2.2.0`. `/agents` → four custom agents listed: `harness:planner`, `harness:generator`, `harness:evaluator`, `harness:designer` (v2.2+).

### Initialize a project

```
cd path/to/your/project
/harness:doctor      # verify environment (MCPs, Node, git, optional skills: huashu-design, impeccable)
/harness:setup       # scaffolds .harness/ + project-local ./CLAUDE.md
```

### Choose your entry point (v2.2+)

**For visual products (UI, mobile app, dashboard, landing page) — especially if you don't have design background, run the design loop FIRST:**

```
/harness:design explore "build a habit tracker for night-owl freelancers"
   → 3 differentiated visual directions in .harness/design/directions/
   → open the HTML files in browser, pick one ("I pick direction-2")
   → AI generates hi-fi clickable prototype + Playwright validation
   → click through, verify it FEELS right

# (optional, if 3 directions all miss)
/harness:design reroll "all three felt too playful, more editorial"
   → history-aware re-spin, 5-round budget; can also attach reference images
   /harness:design reroll "..." --reference-image ~/Pictures/inspiration.jpg

/harness:design teach
   → impeccable codifies the prototype into .harness/design/DESIGN.md

/harness:sprint "build the habit tracker (read prototype + DESIGN.md as design context)"
   → Planner reads prototype + DESIGN.md → Generator BUILD respects design tokens
   → Evaluator PASS → AUTO design audit fires → P0 findings auto-retry BUILD (cap 2)
```

**Why design-first for design-naive users**: spec-first workflows ask you to validate written PRDs — a skill you may not have. Prototype-first workflows let you validate by clicking — a skill you do have. The design loop catches "this isn't what I wanted" in minutes (just discard the HTML), not days (after engineering). See [v2.2-staging 更新说明](#v22-staging-更新说明2026-04-27--中文) above for the full rationale.

**For backend-only / CLI / data-pipeline projects (no UI surface):** skip the design loop and go straight to:

```
/harness:sprint "build a 2-FR todo CLI: user can add a todo with title; user can mark a todo complete"
```

**For tiny tasks (< 30 min, no new design surface):** use `/harness:quick "<prompt>"`.

**For brownfield (adding feature to existing app):** run `/harness:design extract` once to scan existing source for design tokens, then proceed with the design-first flow above. The brownfield gate in `/harness:design explore` will warn you if you skip extraction.

### What happens during `/harness:sprint`

Planner drafts spec → analyze auto-runs → human approval gate → Generator ↔ Evaluator negotiate the contract → Generator BUILD via TDD with atomic per-FR commits → Evaluator EVALUATE exercises the running app via Playwright and grades against 4 criteria with hard thresholds → **(v2.2+) auto design audit if `.harness/design/` exists, P0 auto-retries BUILD up to 2 times** → tuning check captures any divergence between the Evaluator's judgment and yours → retrospective reconciles spec with what actually shipped → merge.

---

## The Anthropic philosophy (what this harness encodes)

Four principles from Rajasekaran 2026, quoted verbatim, and where each lives in BELCORT:

1. **Simplest solution first.** *"Find the simplest solution possible, and only increase complexity when needed."* Every component of this harness earns its existence. If you can't articulate the failure mode a component prevents on current models, it's slated for removal in the next assumption-test cycle.

2. **Every component encodes a stale-able assumption.** *"Every component in a harness encodes an assumption about what the model can't do on its own, and those assumptions are worth stress testing, both because they may be incorrect, and because they can quickly go stale as models improve."* v2.0 removed ~900 lines of v1.3/1.4/1.5 defensive machinery whose assumptions no longer held on Opus 4.7 (progress-poller, phase-guard hook, `/harness:steer`, `/harness:assumption-test`, per-agent model pinning).

3. **File-based communication.** *"Communication was handled via files: one agent would write a file, another agent would read it."* Every subagent dispatch writes output to `.harness/features/NNN/*.md` — the orchestrator reads files, never conversation. The agent doing the work and the agent judging it share disk, not context.

4. **Context isolation is non-negotiable.** *"Separating the agent doing the work from the agent judging it proves to be a strong lever."* Evaluator NEVER shares context with Generator. v2.1 migrated from `claude -p` subprocess dispatch to native Agent-tool dispatch — same isolation guarantee, 47% less boilerplate.

Plus one Trustworthy-Agents principle:

5. **Calibrated uncertainty beats confident guessing.** *"Models are trained through scenarios that place Claude in ambiguous situations, and then reinforce Claude's choice to pause."* The Generator has a pause protocol: when a mid-build ambiguity exceeds what Context7 or the contract can resolve, it writes `pause-questions.md` with a "default if unanswered" fallback per question, and the orchestrator surfaces them to the user. Procrastination is explicitly forbidden — every pause must document what the agent would do if the user ignored the question.

---

## The three agents

| Agent | Subagent type | Job | Tools | Modes |
|---|---|---|---|---|
| **Planner** | `harness:planner` | Expands a 1-4 sentence prompt into a product-grade spec (PRD + constitution + architecture + evaluator criteria + per-FR stories + build contract) | Read, Write, Context7 MCP | PLAN, CLARIFY-QUESTIONS, CLARIFY-APPLY, AMEND, EDIT, CONSTITUTION-AMEND |
| **Generator** | `harness:generator` | Negotiates the contract's HOW, then implements it via TDD. Delegates RED→GREEN→REFACTOR to `superpowers:test-driven-development`. Atomic per-FR commits. | Read, Write, Bash, Context7 MCP | NEGOTIATE, FINALIZE-CONTRACT, BUILD |
| **Evaluator** | `harness:evaluator` | Adversarial tester. Runs the built app through Playwright, grades against 4 criteria with hard thresholds, runs git-archaeology reward-hacking scan, produces pass/fail verdict with specific findings. | Read, Write, Bash, Playwright MCP | REVIEW-PROPOSAL, EVALUATE, REVALIDATE |

Each agent has a `<SUBAGENT-CONTEXT>` block at the top of its system prompt that explicitly forbids re-invoking the harness pipeline or dispatching further subagents. Subagents do ONE job per dispatch, write output to a file, and exit.

### Pipeline (canonical sprint flow)

```
/harness:sprint "<prompt>"
  │
  ├─ doctor preflight (blocks on CRITICAL env failures)
  ├─ Planner (PLAN mode, 2 passes: Pass 1 PRD+constitution, Pass 2 architecture+criteria+contract+stories)
  ├─ analyze (automatic cross-artifact consistency)
  ├─ HUMAN GATE — approve | /clarify | /amend | /edit | /rewind planning
  ├─ Generator (NEGOTIATE) → proposal.md
  ├─ Evaluator (REVIEW-PROPOSAL) → review.md  [iterate ≤3 rounds]
  ├─ Generator (FINALIZE-CONTRACT) → contract.md (final, with **Negotiated**: marker)
  ├─ Generator (BUILD via superpowers:test-driven-development) → source code + atomic commits + implementation-report.md
  │     ↳ may pause mid-build via pause-questions.md → orchestrator collects answers → re-dispatch
  ├─ Evaluator (EVALUATE) — calibration-mandatory examples.md read → Playwright test → Part-A binary gates Part-B numeric → reward-hacking git-archaeology scan → eval-report.md
  ├─ Tuning check — user agrees/disagrees with Evaluator; divergences logged to tuning-log.md
  ├─ if PASS → retrospective (drift analysis) → merge → manifest.phase = complete
  └─ if FAIL (retries < max) → Generator BUILD again with eval-report.md as retry context
```

---

## The 17 commands

### Entry points

| Command | When to use |
|---|---|
| `/harness:sprint "<prompt>"` | Full pipeline. Use for features >15 min of work, multiple components, novel decisions, or anything touching architecture. |
| `/harness:quick "<prompt>"` | Fast path. Skip Planner, write a minimal 2-4 AC contract inline, single Generator → Evaluator pass. Use for <30 min scoped tweaks with obvious approach. |
| `/harness:resume` | Recover from an interrupted sprint. Reads manifest + changelog + git log, dispatches the right subagent for the current phase. |
| `/harness:brainstorm "<vague idea>"` | Pre-plan exploration for ambiguous prompts (<2 sentences, "maybe", "not sure"). Interviews the user, writes `.harness/brainstorm-current.md`, which the next `/harness:sprint` consumes as additional context. |

### Spec-edit (fresh Planner dispatch + mechanical patch apply)

| Command | Purpose |
|---|---|
| `/harness:clarify` | Post-plan Q&A round. Planner identifies ambiguities, user answers, surgical patches applied. |
| `/harness:amend "<change>"` | Single-file targeted spec tweak (usually PRD or architecture). |
| `/harness:edit "<change>"` | Cascade-aware multi-file spec edit (stack swap, NFR tightening, anything touching ≥2 files). Auto-runs `/analyze` then `/validate`. |
| `/harness:constitution-amend "<reason ≥50 chars>"` | High-ceremony 5-gate constitutional change: typed confirmation, in-progress-feature handling, NEW-constitution vs current-spec analyze, per-feature REVALIDATE by Evaluator, mandatory ADR, final apply confirmation. |

All spec-edit commands follow the same safety protocol: **the orchestrator never authors spec content**. A fresh Planner subagent (clean context) produces patches to a `*-patches.md` file; the orchestrator presents diffs to the user; approved patches are applied mechanically via the Edit tool. This keeps the orchestrator's fat chat context out of spec files.

### Audit family

Five distinct questions, five distinct tools:

| Command / mode | Question it answers |
|---|---|
| `/harness:analyze` | *"Are the spec files internally consistent right now?"* (PRD ↔ architecture ↔ contract ↔ criteria — cross-reference integrity) |
| `/harness:validate` | *"Is every spec section complete and quality-gated?"* (16-point V1–V16 checklist) |
| `/harness:audit` | *"Do shipped features have deferred debt, stale known-issues, suspicious skip markers?"* (cross-feature, historical) |
| Evaluator REVALIDATE mode | *"Does each previously-shipped feature still comply with the NEW constitution?"* (only inside `/harness:constitution-amend`) |
| `/harness:retrospective` | *"Did the implementation drift from the spec?"* (post-build contract ↔ reality reconciliation) |

Mnemonic: **analyze** = consistency, **validate** = completeness, **audit** = debt, **REVALIDATE** = backward-compat, **retrospective** = reality.

### Phase management + lifecycle

| Command | Purpose |
|---|---|
| `/harness:negotiate` | Standalone Generator↔Evaluator negotiation (normally auto-invoked by sprint). |
| `/harness:rewind <phase>` | Archive-based reset to `planning` \| `analyzing` \| `negotiating` \| `building` \| `evaluating`. Files move to `.archive/TIMESTAMP/`, never deleted. Requires typed confirmation. |
| `/harness:tune-evaluator` | Review Evaluator divergence patterns from `tuning-log.md`; propose new calibration examples or (rarely) prompt edits. |
| `/harness:setup` | Project-local install: creates `.harness/` + `./CLAUDE.md` activation block. Idempotent. |
| `/harness:doctor` | Environment preflight. Blocks on CRITICAL failures (missing MCPs, no jq/python, outdated Node). Auto-runs at sprint/quick start. |

---

## File ownership contract

Every file under `.harness/` has exactly one writer. If you're not the designated writer, you're a reader.

| File | Writer |
|---|---|
| `manifest.yaml` | Orchestrator (state transitions); Planner (initial features); Generator BUILD (current_task per FR) |
| `spec/prd.md`, `spec/architecture.md`, `spec/constitution.md` | Planner — never the orchestrator directly |
| `evaluator/criteria.md`, `evaluator/examples.md` | Planner (init), orchestrator (during tuning check) |
| `features/NNN/contract.md` — draft | Planner |
| `features/NNN/contract.md` — final | Generator FINALIZE-CONTRACT (overwrites draft, MUST include `**Negotiated**:` marker) |
| `features/NNN/stories/FR-NNN.md` | Planner Pass 2; Generator BUILD may refine |
| `features/NNN/proposal.md` | Generator NEGOTIATE |
| `features/NNN/review.md` | Evaluator REVIEW-PROPOSAL |
| `features/NNN/implementation-report.md` | Generator BUILD |
| `features/NNN/eval-report.md` | Evaluator EVALUATE |
| `features/NNN/{amend,clarify,edit}-patches.md` | Planner (AMEND/CLARIFY-APPLY/EDIT modes) |
| `features/NNN/pause-questions.md` | Generator BUILD (mid-build clarification) |
| `.harness/constitution-amend-patches.md` | Planner CONSTITUTION-AMEND |
| `progress/changelog.md` | All agents append |
| `progress/decisions.md` | Orchestrator (ADR on any spec/prompt change) |
| `progress/known-issues.md` | Orchestrator (via retrospective) |

Rationale: the orchestrator's context contains the whole conversation; subagents have clean contexts. Letting the orchestrator edit spec files leaks conversational noise into the spec, which downstream subagents then inherit. The rule is prose-enforced (no mechanical hook in v2) and backstopped by the Evaluator's retrospective, which catches drift.

---

## v2 architecture — what changed from v1.x

### Subagent dispatch: `claude -p` subprocess → native Agent tool

**v1.x** shelled out for every dispatch:
```bash
CLAUDE_SUBAGENT=1 claude -p "<prompt>" \
  --append-system-prompt-file "agents/planner.md" \
  --allowedTools "Read,Write,mcp__context7"
```

**v2.1+** uses Claude Code's native plugin-declared subagent types:

```
Agent tool → subagent_type: "harness:planner"
           → prompt: "You are being dispatched in PLAN mode..."
```

Cleaner, faster (no subprocess startup), no env-var isolation tricks, parallel dispatch available, structured return values.

### Installation: global CLAUDE.md → project-local CLAUDE.md

**v1.x** wrote rules into `~/.claude/CLAUDE.md`, polluting every Claude Code session with harness activation logic whether or not the current project used the harness.

**v2.0+** `/harness:setup` creates project-local `./CLAUDE.md` with a `BELCORT-HARNESS BEGIN v2` block. Scoped to projects that actually use the harness.

Legacy global installs: run `scripts/uninstall-rules.sh` once to remove the old block from `~/.claude/CLAUDE.md`.

### Commands removed

- **`/harness:steer`** — redundant with `/harness:amend` (for spec changes) and the evaluator retry loop (for quality issues).
- **`/harness:assumption-test`** — meta-audit tool that was never actually run in practice. Manual A/B is a 5-minute task when needed.

### Machinery removed

- **`progress-poller.sh` + heartbeat protocol** (~350 lines) — `claude -p` stdout already streams to the orchestrator; the poller solved a problem that didn't exist on modern Claude Code.
- **`phase-guard.sh` + FR-2 spec-edit hook** (~100 lines) — Opus 4.7 follows the prose "orchestrator doesn't edit spec files" rule. The mechanical enforcement hook was belt-and-suspenders that broke when tool namespaces changed.
- **Per-agent model pinning** (`config.models.{planner,generator,evaluator}`) — undocumented, unused.

### Audit matrix clarified

Added dedicated auto-invocations so users don't have to remember which audit to run when:

- `/amend` → auto-runs `/analyze` (consistency)
- `/edit` → auto-runs `/analyze` + `/validate` (consistency + completeness — cascade edits deserve both)
- `/clarify` → auto-runs `/analyze`
- `/constitution-amend` → includes a NEW-constitution vs current-spec `/analyze` gate BEFORE per-feature REVALIDATE (catches contradictions cheaply)

---

## Project-specific tools and MCPs

Subagents inherit the parent Claude Code session's full tool set — any MCP or skill you've installed is available. To guide the harness subagents toward project-specific tools:

1. Install the tool at the session level (not inside the plugin):
   ```
   claude mcp add figma -- npx -y @figma/mcp@latest
   /plugin install elements-of-style@some-marketplace
   ```

2. Edit your project's `./CLAUDE.md` (created by `/harness:setup`) and populate the `## Project-specific tools / MCPs / skills` section:
   ```markdown
   ### Project tools
   - **`mcp__figma`** — Planner may query for component trees when the PRD references an existing Figma design.
   - **`elements-of-style` skill** — Generator invokes this before writing any user-facing copy.
   ```

3. The orchestrator reads project CLAUDE.md before every subagent dispatch and includes relevant tool guidance in the Agent-tool `prompt` parameter under a `--- PROJECT TOOLS ---` marker.

No need to edit plugin files. Access is via inheritance; knowledge of when to use a tool is via project CLAUDE.md.

---

## Recommended companion plugins

None are required; each enhances a specific phase.

| Plugin | Used by | What it adds |
|---|---|---|
| [`superpowers`](https://github.com/obra/superpowers) | Generator BUILD | TDD skill (`test-driven-development`) drives the RED→GREEN→REFACTOR cycle. Strongly recommended. |
| `frontend-design` | Planner (Pass 2), Generator UI work | Design tokens + layout patterns for polished UI |
| `security-guidance` | Generator (pre-commit), Evaluator (Code Quality) | OWASP top-10 checks, secret-detection |
| `agentlint` | Evaluator Code Quality | 33 evidence-backed automated code checks |

`/harness:doctor` lists these and warns if missing.

---

## Directory layout

```
.harness/
├── manifest.yaml              # Single source of truth for project state
├── ROADMAP.md                 # Shipped / in-progress / planned features
├── init.sh                    # Project-health check (customize per stack)
├── spec/
│   ├── prd.md                 # Product requirements (WHAT + WHY, zero tech)
│   ├── architecture.md        # High-level tech direction (stack, ADRs)
│   ├── constitution.md        # 17 testable coding principles
│   └── evaluator-notes.md     # Project-specific calibration notes
├── evaluator/
│   ├── criteria.md            # 4-criterion rubric with hard thresholds
│   ├── examples.md            # 12 seeded few-shot calibration examples
│   └── tuning-log.md          # Evaluator-human divergence log
├── features/NNN-feature-name/
│   ├── contract.md            # Draft (Planner) → Final (Generator FINALIZE)
│   ├── stories/FR-NNN.md      # Per-FR build context (Planner Pass 2)
│   ├── proposal.md            # Generator's HOW (NEGOTIATE mode)
│   ├── review.md              # Evaluator's review of proposal
│   ├── implementation-report.md  # Generator's handoff after BUILD
│   ├── eval-report.md         # Evaluator's verdict (PASS/FAIL + findings)
│   ├── analysis-report.md     # /harness:analyze output
│   ├── retrospective.md       # /harness:retrospective drift analysis
│   └── .archive/TIMESTAMP/    # Rewind-archived files
└── progress/
    ├── changelog.md           # Append-only activity log (all agents)
    ├── decisions.md           # ADR log (orchestrator)
    └── known-issues.md        # Retrospective debt
```

All paths are relative to your project root. The harness never touches files outside `.harness/` except during Generator BUILD (source code + git commits) and the `./CLAUDE.md` activation rule file.

---

## Troubleshooting

### `Validation errors: agents: Invalid input` during `/plugin install`

You're on an older tag. v2.1.0+ uses the correct array format. Update: `/plugin marketplace remove belcort-harness && /plugin marketplace add https://github.com/mosaladtaooo/belcort-harness.git#v2-beta && /plugin install harness@belcort-harness`.

### Safety rails (force-push block, sudo block, .harness/ deletion block) seem inactive on Windows

Windows ships a `python3.exe` Microsoft Store PATH stub that resolves via `command -v python3` but doesn't execute. v2.1.1+ probes actual execution and falls back to `python` (3.x). Upgrade or install jq: `winget install jqlang.jq`.

### AgentLint hook errors look like mangled paths on Windows

If you see errors like `/usr/bin/bash: line 1: C:UserszhantAppDataLocalProgramsPythonPython312Scriptsagentlint.EXE: command not found`, the backslashes in the Windows path are being stripped inside MSYS/Git-Bash (the `\U`, `\A`, `\L` sequences eat themselves). This is an **AgentLint bug**, not belcort-harness — report upstream or uninstall agentlint if the noise bothers you. The error is tagged `non-blocking` and doesn't affect the harness pipeline.

### Generator paused because npm / npx / pnpm is blocked

Claude Code's default Bash-permission system may prompt or block npm-family commands. Generator BUILD can't run tests without them, so it pauses gracefully (pause-protocol working as designed). Fix by pre-allowing in Claude Code:

```
/allow Bash(npm *) Bash(npx *) Bash(pnpm *) Bash(node *)
```

Or add to `.claude/settings.json` → `permissions.allow`. Then `/harness:resume` — Generator picks up where it paused. `/harness:doctor` (v2.1.2+) warns if your settings don't pre-allow these commands.

### Evaluator can't find Playwright / Planner can't find Context7

Run `/harness:doctor`. It checks MCP registration. If missing:
```
claude mcp add playwright -- npx -y @playwright/mcp@latest
claude mcp add context7 -- npx -y @upstash/context7-mcp@latest
```
Or reinstall the harness plugin — its `.mcp.json` registers both automatically.

### "subagent_type 'harness:planner' not recognized"

Run `/reload-plugins`. If that doesn't work, restart Claude Code (close + reopen) — plugin.json's `agents` declaration is picked up on session start.

### Generator seems to skip TDD

Superpowers plugin missing. Install: `/plugin install superpowers@claude-plugins-official`. Generator BUILD mode delegates the RED→GREEN→REFACTOR cycle to `superpowers:test-driven-development`.

### Sprint interrupted mid-build

Run `/harness:resume`. It reads manifest + changelog + `git log --oneline | grep 'harness:'` and re-dispatches the correct subagent for the current phase. Mid-build recovery is supported — Generator BUILD reads `state.current_task` and skips already-completed FRs.

### Something went wrong; want to restart from an earlier phase

`/harness:rewind <phase>` archives current-phase artifacts to `.harness/features/NNN/.archive/TIMESTAMP/` and resets manifest state. Valid targets: `planning`, `analyzing`, `negotiating`, `building`, `evaluating`. Requires typed confirmation. Not destructive — archived files are recoverable.

---

## Design spec + implementation history

For full rationale behind every v2 change:
- `docs/superpowers/specs/2026-04-21-belcort-v2-minimalist-refactor-design.md` — the design spec
- `docs/superpowers/plans/2026-04-21-belcort-v2-minimalist-refactor.md` — the 32-task implementation plan
- `docs/anthropic-alignment.md` — point-by-point trace from BELCORT design decisions back to Anthropic's engineering articles
- `CHANGELOG.md` — version history (v2.0.0 minimalist rewrite, v2.1.0 native Agent-tool dispatch, v2.1.1 project-tool propagation)

---

## References

**Primary sources:**
- [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) — Prithvi Rajasekaran, Anthropic Labs, 2026
- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — Anthropic Labs
- [Trustworthy agents in practice](https://www.anthropic.com/research/trustworthy-agents) — Anthropic Research

**Adjacent influences:**
- [GitHub Spec Kit](https://github.com/github/spec-kit) — constitutional governance, clarify/amend patterns
- BMAD V6 — per-FR story files (Scrum Master pattern), two-pass Planner
- [Superpowers](https://github.com/obra/superpowers) — TDD skill, systematic-debugging, verification-before-completion, the 1% skill-activation rule

---

## Status

**v2.1.9 — shipped to `main` as current stable** (2026-04-24) after 9 patch releases of live stress-test iteration on `v2-beta`:
- v2.1.0 — native Agent-tool dispatch (plugin-declared `harness:planner/generator/evaluator` subagent types), migrated from `claude -p` subprocess pattern
- v2.1.1 — dropped `tools:` frontmatter allowlist (subagents inherit parent session's tool set); project-tools propagation via `./CLAUDE.md`
- v2.1.2 — stress-test patches: Windows python3-stub detection, `/quick` spec-drift check, `/clarify` ADR gap closed, doctor.sh checks for pre-allowed npm permissions + superpowers plugin
- v2.1.3 — removed ~413 lines of inline template duplication (5 templates → `@`-references + invariants); REVIEW-PROPOSAL now reads constitution.md + architecture.md to catch HOW-level violations the contract doesn't constrain
- v2.1.4 — aligned Evaluator tuning category vocabulary (fixes silent drop of `Wrong severity` / `Out of scope` entries); added watch-list for 1-2-entry categories in `/harness:tune-evaluator`; promoted 3-round negotiation rationale into `negotiate.md` Procedure with sharper escalation UX; added retrospective-vs-tuning clarifier to `SKILL.md`
- v2.1.5 — Planner feature-size gate (prevent oversized dispatches that exhaust Claude Code subagent budgets mid-build); pre-TDD scaffolding commit rule in `generator.md` (non-behavioral work now commits at logical group boundaries, not just post-FR); SKILL.md Recovery section expanded with hard-stop-mid-scaffolding case
- v2.1.6 — doc patch: replaced broken `.agentlint.toml` (never loaded — AgentLint reads `agentlint.yml`, not TOML) with proper `agentlint.yml`. `max-file-size` limit now set to 1500 globally since the rule supports only one `limit` option (verified in AgentLint source); rationale preserved as inline YAML comments.
- v2.1.7 — explicit frontmatter tuning for max context + turns: all three agents declare `model: inherit`, `effort: max`, `permissionMode: default`, `maxTurns: 2000`. **Runtime pairing**: start Claude Code with `claude --model claude-opus-4-7[1m]` for the 1M context window; without this, `inherit` picks the default 200K Opus variant. See CHANGELOG for the full rationale including fields deliberately omitted.
- v2.1.8 — closes the two-`.harness/`-folder cognitive confusion hazard (root = authoritative, worktree copy = stale snapshot). SKILL.md gains an explicit Working-directory-and-`.harness/`-location rule under File Ownership Contract; sprint.md dispatch prompts for Generator and Evaluator now lead with a "Working directory contract (v2.1.8)" paragraph; resume.md requires project-root invocation. Sparse-checkout-based mechanical prevention was considered and deferred to v3 — see ROADMAP.md.
- v2.1.9 — secrets-handling contract: Generator writes `.env.example` (placeholders); user writes `.env.local` (actual values). Forbids pausing for secret values (secrets must not enter conversation history). implementation-report.md gains a mandatory `Setup required` section. sprint.md Step 4 adds a Setup-required gate before Evaluator dispatch — prevents false-FAILs against apps that can't start because of missing env.

See [`CHANGELOG.md`](CHANGELOG.md) for per-release detail. See [`ROADMAP.md`](ROADMAP.md) for the v3 watch list + parked items.

**v1.5.x** — prior stable. See git tag `v1.5.2` for the final pre-v2 release (main was v1.5 before 2026-04-24). For existing v1.5 installs upgrading to v2: run `scripts/uninstall-rules.sh` once to remove the legacy global `~/.claude/CLAUDE.md` block, then `/harness:setup` in each project.

**`v2-beta`** — active development branch for post-v2.1.9 work; merges to `main` via FF at release points.

**License**: MIT.
**Author**: BELCORT AI Consulting `<tools@belcort.com>`.
**Repository**: https://github.com/mosaladtaooo/belcort-harness
