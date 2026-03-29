# Harness Engineering 实践教程

> 同一个模型，同一个领域，同一套工具。两个项目写出了两种代码质量。唯一的变量是 Harness。

---

## 1. 什么是 Harness Engineering

### 1.1 定义与背景

AI 编程代理（Claude Code、Codex、Cursor）的输出质量不稳定。常见的反应是换更强的模型、改 prompt 措辞、或者人工 review 每一行代码。这些方法的共同问题是：**治标不治本，同类错误会反复出现。**

Harness Engineering 提出一个不同的思路：**问题不在模型，在环境。**

> "Anytime you find an agent makes a mistake, you take the time to engineer a solution such that the agent never makes that mistake again."
> — Mitchell Hashimoto, [My AI Adoption Journey](https://mitchellh.com/writing/my-ai-adoption-journey)

Harness 是 Agent 的运行环境——CLAUDE.md、自定义 lint、结构测试、质量门禁、Agent 角色定义、自动化脚本——所有模型之外的、决定 Agent 行为边界的东西。OpenAI Codex 团队用 3 名工程师、5 个月、零手写代码，交付了超过 100 万行生产级代码，他们最早的发现是"环境的规范不够明确"才是瓶颈，而非模型能力。

**这篇教程不讲理论。** 以下用两个项目做对照实验，再用一个配图系统的迭代过程展示 Harness 如何从失败中生长。

### 1.2 先看结果

两个简历编辑器项目。模型相同（Claude Opus 4.6），领域相同，工具相同（Claude Code）。唯一的变量是有没有在写代码之前搭 Harness。

| 维度 | Typst 简历优化（无 Harness） | 墨简（有 Harness） |
|---|---|---|
| CLAUDE.md | 114 行，描述架构 + 自主工作流 | 137 行，伪代码路由 + 管线定义 |
| 架构约束 | 无分层，UI 直接 fetch | 六层分层 + ESLint 锁死依赖方向 |
| 测试 | 0 | 结构测试 + 单元测试 |
| Agent 体系 | 无 | 7 Agent + 7 协议 + 5 Skill 契约 |
| 溯源 | 无 | sidecar YAML + `@req` 注解 + trace.sh |
| 门禁 | 无 | 5 道 Gate（G1–G5） |
| 自动化脚本 | 无 | 8 个（trace / doctor / closeout / sync-state ...） |
| 典型 commit | `fix: 修复编辑面板对比度不足` | `feat(harness): trace.sh --sync 回写 disposition` |
| 总 commit | 57（8/30 修同类 UI 问题） | 96（结构化阶段推进） |

### 1.3 实验设计

**不变的条件：**
- 模型：Claude Opus 4.6
- 领域：简历编辑器（Web 应用）
- 工具：Claude Code

**变化的条件：**
- Typst 简历优化：一句话需求 → Agent 自由编码 → 57 个 commit → 功能齐全但质量失控
- 墨简：一句话需求 → 先搭 Harness → Agent 在约束内编码

**为什么这个对比成立：** 同一个模型消除了能力变量。同一个领域消除了复杂度变量。同一套工具消除了平台变量。剩下的唯一解释就是 Harness。

---

## 2. 怎么搭 Harness

### 2.1 先约束环境，再让 AI 写代码

**症状：** 没有 Harness 时 Agent 写出什么代码？这是 Typst 简历优化项目的真实产出：

```tsx
// UI 组件直接发请求，每个组件各写一遍 fetch
const res = await fetch("/api/chat", { method: "POST", body: JSON.stringify({ messages, resumeData, apiKey }) });

// 一个函数同时做防抖、网络请求、状态管理
const compile = useCallback((d: ResumeData) => {
  if (compileTimer.current) clearTimeout(compileTimer.current);
  compileTimer.current = setTimeout(async () => {
    dispatch({ type: "COMPILE_START" });
    const res = await fetch("/api/compile", { ... });
    dispatch({ type: "COMPILE_SUCCESS", svg: await res.text() });
  }, 700);
}, []);
```

每一个问题都指向同一个根因：**没有人定义边界。** Agent 选了最省事的架构——把所有东西塞在一起。

**修复：** 墨简在第一行业务代码之前就定义了六层架构，只允许向下依赖：

```
Types → Config → Repo → Service → Runtime → UI
```

用自定义 ESLint 规则锁死这个方向。违反时，错误信息直接告诉 Agent 怎么修：

```
禁止从 ui 层引用 service 层。
允许的依赖方向：Types → Config → Repo → Service → Runtime → UI
修复方法：如需跨层通信，通过 Runtime 层中转，
或将共享逻辑下沉到 Types/Config 层。
```

OpenAI 的做法一样："由于这些 lint 是自定义的，我们编写错误信息时会在智能体情境中注入修复指令。"

OpenAI 还有一个观察："这种架构通常要等到你拥有数百名工程师时才会推行。对于编码智能体来说，这是一个早期的先决条件。"

**对人来说，约束通常是负担。对 Agent 来说，约束是能力的来源。**

**模板：**
1. 写代码之前，先定义层级结构和依赖方向
2. 用 ESLint 规则或结构测试强制执行
3. 错误信息里注入修复指令——Agent 不需要自觉遵守，环境不允许它违反

### 2.2 知识写成地图，不写成百科

**症状：** 把所有规则塞进一个大文件。Agent 的上下文被挤满，分不清什么跟当前任务有关。

**原因：** 上下文窗口是有限的。OpenAI 的发现：

> "情境是一种稀缺资源。一个巨大的指令文件会挤掉任务、代码和相关文档。当一切都'重要'时，一切都不重要了。"

**两个项目的 CLAUDE.md 对比：**

| 维度 | Typst 简历优化 CLAUDE.md | 墨简 CLAUDE.md |
|---|---|---|
| 行数 | 114 行 | 137 行 |
| 内容 | 目录结构描述 + 开发命令 + 自主工作流规则 | 伪代码路由 + 管线定义 + 资源索引表 |
| 导航 | 无——Agent 需要自己猜该读什么 | 有——按消息类型路由到对应文档 |
| 状态 | 无 | STATE.yaml 实时控制面 |

Typst 简历优化的 CLAUDE.md 是一本说明书——描述了项目长什么样，但没告诉 Agent 遇到不同任务该去哪找信息。

墨简的 CLAUDE.md 是一张地图——用伪代码定义路由逻辑：

```python
on_user_message(msg):
    if is_question(msg):
        route via FAQ routing table     # @.claude/docs/FAQ.md
    elif is_bug_report(msg):
        reproduce → classify → plan → fix → verify
    elif is_new_feature_request(msg):
        write intent.md → wait approval → follow_pipeline
    else:
        follow_pipeline(state.recommended_next)
```

Agent 不猜——按图索骥。详细内容在 `docs/` 目录下 20+ 文件中，按需加载。

墨简还有一个设计决策：**CLAUDE.md 是操作系统，`project.md` 是应用。** 框架通用部分在 CLAUDE.md，项目特有身份在 `.claude/project.md`。换项目只改一个文件。这个设计后来被抽象为独立框架 [HarnessPractice](https://github.com/Aryous/HarnessPractice)。

**模板：**
1. CLAUDE.md 只放路径和导航，不超过 ~140 行
2. 用伪代码定义路由，不用自然语言描述
3. 详细内容放 `docs/`，按类型分文件夹

### 2.3 约束必须能执行

**症状：** Typst 简历优化项目零测试、零自定义 lint、零架构约束。CLAUDE.md 写了"lint 有报错时先修复，再 commit"，但除此之外没有任何约束机制。

**原因：** 写在文档里的规则是建议，不是约束。Agent 可以不读，也可以读了不遵守。

**修复：** 墨简用三层约束，从软到硬：

| 层级 | 机制 | 执行方式 | 能绕过吗 |
|---|---|---|---|
| 硬 | ESLint + trace.sh + 结构测试 | 构建失败即阻断 | 不能 |
| 中 | `.claude/rules/`（7 个规则文件） | 自动注入 Agent 上下文 | 理论上可以 |
| 软 | `docs/` | Agent 需主动读取 | 不读就不知道 |

**约束只升级，不降级。** 如果一条软约束被违反两次，升级为中约束。中约束还不够，升级为硬约束。这条协议写在 `protocols.md` 里：

```
docs/（软约束）→ .claude/rules/（中约束）→ lint 规则（硬约束）
```

实际案例：AI 服务调用规范最初写在 `docs/`，被违反两次后升级为 `.claude/rules/ai-service.md`，从此自动注入每个 Agent 的上下文。

**豁免协议：** 当硬约束被历史债阻塞时，不降低标准，用受控例外：

```yaml
# docs/exemptions/trace-legacy-gaps.md
status: approved          # draft → review → approved → consumed → expired
mode: until_resolved      # one_shot | until_resolved
covers: [F06, F07, F08, F09, F13]
expires: 2026-04-30       # 必须有过期时间
```

没有豁免文档 = 没有例外。豁免有生命周期，提交成功后由脚本自动推进状态。

**模板：**
1. 关键架构规则写成 ESLint 或测试——不可绕过
2. 行为规范写成 `.claude/rules/`——自动注入
3. 约束升级路径：只升不降
4. 需要绕过时用豁免协议，不口头说"先跳过"

### 2.4 上下文冲突了才拆 Agent

**症状：** 一个 Agent 同时做需求分析、技术决策、设计、编码、测试。上下文膨胀，角色混乱。

**原因：** 不同任务需要不同的上下文。需求分析需要产品规格，编码需要技术文档。塞在一起，Agent 分不清当前该关注什么。

**修复：** 墨简用 7 个专职 Agent，每个只做一件事：

```
intent.md (approved)
  → [G1]  req-review        → requirements.md
  → [G1a] arch-bootstrap    → ARCHITECTURE.md
  → [G2]  tech-selection    → tech-decisions.md
  → [G3]  design            → design-spec.md
  → [G4]  plan              → exec-plan
  → [G5]  feature           → code + trace --strict
```

每个 Agent 有明确的输入、输出和前置检查。Agent 之间的契约是文件——上一个 Agent 的输出文件是下一个 Agent 的输入。

**7 条协议连接 Agent：**

| # | 协议 | 一句话 |
|---|---|---|
| 1 | 交接 | 输出必须有 frontmatter（`draft → review → approved`） |
| 2 | 上报 | 不可决问题上报人类，≥2 选项，标注阻塞 |
| 3 | 决策写入 | 口头决策写入文档，否则不存在 |
| 4 | 提交 | closeout + lint + tsc + test，一阶段一 commit |
| 5 | 环境演进 | Agent 失败不重试，诊断环境缺口 |
| 6 | 约束升级 | ≥3 次违反，docs → rules → lint，只升不降 |
| 7 | 豁免 | 受控例外，有生命周期和过期时间 |

每个 Agent 还配一个 Skill，定义输出格式契约。三者解耦：

```
Agent 定义 → "你是谁"
Skill      → "你的输出长什么样"
脚本       → "读 sidecar 验证"
```

**拆了之后的陷阱——有损传递：**

墨简的 7 Agent 链路在实际运行中暴露了一个系统性 bug：

```
requirements.md（完整）
  → plan agent（可能漏条目）    ← 第一次丢失
  → feature agent（只看 plan）  ← 第二次丢失
  → 无验证                      ← bug: 无闭环
```

`requirements.md` 写了"富文本编辑 P0"，经过 plan → feature 两次传递后被遗漏。每次 Agent 间传递都是有损的，链条越长，丢失越多。

**修复：** 在链路末端加入机械化闭环——`trace.sh --strict`。代码中用 `@req R1.1` 注解标记实现了哪个需求，脚本逐条核对。不靠 Agent 记忆回溯，靠脚本扫描。

**什么时候不该拆：** 任务之间上下文高度重叠时，拆分反而增加通信成本。拆分标准是上下文冲突，不是任务数量。

**模板：**
1. 上下文冲突时才拆，不是默认拆
2. Agent 之间用文件传递——文件就是契约
3. 链路末端必须有机械化闭环验证
4. 门禁连接 Agent：通过才能继续，成功静默，失败出声

### 2.5 让机器做追踪

**症状：** 需求写在文档里，但没有机制验证需求是否被实现。人工核对不现实——文档多、条目多、链路长。

**原因：** 文档不能自我执行。写了需求文档不等于需求被覆盖。

**修复：** 墨简建了一套溯源体系：sidecar YAML 存结构化数据，trace.sh 机械化扫描。

**Sidecar 架构——叙事和控制数据解耦：**

```
requirements.md              ← 叙事文档（给人看）
requirements.trace.yaml      ← 结构化注册表（给脚本读）
```

为什么要分离？早期 `trace.sh` 直接 grep Markdown 表格。一个缺陷从 S2 升级为 S1 后格式不匹配，脚本漏抓。**叙事和控制数据必须解耦。**

**trace.sh——185 行的机械化阻塞门：**

```bash
# .claude/scripts/trace.sh — 从 sidecar 读取 trackable ID
# 在 src/ + tests/ 中 grep @req 注解，报告覆盖率

# 三种模式：
# trace.sh            → 报告覆盖率和缺失
# trace.sh --strict   → 未覆盖则 exit 1，阻断提交
# trace.sh --sync     → 有覆盖的 open → resolved
```

运行效果：

```
═══════════════════════════════════════════════
  溯源覆盖率报告
  来源: requirements.trace.yaml (sidecar)
  总计: 12 条
  扫描: src/ + tests/
  约定: @req <ID>
═══════════════════════════════════════════════

  ✅ R1.1 简历内容编辑
     └─ src/service/resume-service.ts:42
  ✅ R2.1 Typst 渲染
     └─ src/service/compile-service.ts:15
  ❌ F06 AI 冷启动生成
  ❌ F07 description 格式化

───────────────────────────────────────────────
  覆盖: 10/12 (83%)
  缺失: 2/12
═══════════════════════════════════════════════
```

`--strict` 模式下，有未覆盖的条目就 exit 1——提交被阻断。`--sync` 模式下，有代码覆盖的 `open` 状态自动回写为 `resolved`。

**harness-doctor.sh——会话健康检查：**

每次新会话启动时运行，扫描：文档 frontmatter 一致性、sidecar 同步状态、豁免是否过期、worktree 是否干净。输出 STATE.yaml。Agent 不靠记忆判断系统状态——脚本告诉它。

**模板：**
1. 叙事文档给人看，结构化 sidecar 给脚本读——两者解耦
2. 代码中用 `@req <ID>` 标注需求覆盖
3. 用脚本机械化验证，不靠 Agent 记忆
4. 每次会话启动跑 doctor，输出状态快照

### 2.6 Harness 是被失败逼出来的

前面五节讲的是墨简的 Harness 结构。但 Harness Engineering 更核心的部分不是结构——是迭代方法。

配图系统 [LayerAxis](https://github.com/Aryous/layeraxis-marketplace) 完整经历了这个过程。它是一个 3-Agent 流水线，为文章的每个章节设计和生成配图：

```
orchestrator (调度 + 锁参数)
    ├─> creative-agent (Opus，创意设计 + 出提示词)
    └─> render-agent  (Haiku，执行生成脚本)
```

模型选择匹配认知负载：creative 用 Opus（创意需要推理能力），render 用 Haiku（只跑脚本，不需要推理）。

从 33% 的可用率迭代到 100%。**模型没换，约束变得更精确了。**

**33%（2/6 可用）——隐喻选完没展开：**

Agent 选了隐喻（"灯塔"代表方向），但没展开为视觉规格——灯塔多大？画面哪个位置？光束往哪照？

**Harness 修改：** 在 SKILL.md 中加入隐喻展开三步法：选类型 → 定规格 → 验可读。

**71%（5/7 可用）——声明式规则被跳过：**

关键参考文件被埋在两层引用深处，Agent 没读到。声明式规则列表（"必须做 X"）被模型扫过去了。

**Harness 修改：** 3 处直接内联引用。用引导式问题替代声明式列表：

> - "视线先落在哪里？然后移向哪里？"
> - "有多少个东西在争夺注意力？超过 7 个就砍。"

**规则够了，问题出在呈现方式。** 声明式列表被模型扫过去，引导式提问让模型主动思考。同样的知识，换一种格式交付给 Agent，执行效果完全不同。

**100%（6/6 可用）——一句话修复执行流：**

全部可用，但质量停留在 65-70。诊断发现 Agent 在横向批处理：先做完所有图的场景设计，再批量上色，再批量写提示词。批处理打断了创意连贯性。

**Harness 修改：** 一句话——

> "对每张图，走完 Step 2→3→4 完整链路，一次性写入，再做下一张。"

通过率稳定在 100%。**模型没变，执行流变了。**

**80%（12/15 可用）——规模暴露新问题：**

密度从 6 张扩展到 15 张，新的系统性问题出现。情绪层被渲染为结构图，冗余图复制了文章中已有的表格。

**规模放大暴露新的系统性问题。Harness 是一个持续演进的系统。**

**配图系统的 Harness 工件：**

**plan.lock.yaml（参数契约）：**

```yaml
# 上游 orchestrator 锁定，下游 creative/render 不可覆写
density: standard
style_guide: digital-rationalism
negative_prompt: "no neon, no cyberpunk, no heavy texture..."
generation:
  model: gemini-3-pro-image-preview
  aspect_ratio: "16:9"
  image_size: "2K"
```

**pipeline-gates.md（质量门禁）：**

```
Gate 0 → plan.lock.yaml 存在且值域合法      → 才允许进入 creative
Gate A → creative-draft.md 非空              → 才允许进入 compiler
Gate B → 每个 NN-*.md 有非空 English Prompt  → 才允许 render
Review → review-feedback.yaml 存在           → 打回 creative 重写
```

Gate 的设计原则是**成功静默，失败出声**。验证通过不输出任何信息，只有失败时才注入 Agent 上下文。

**模板：**
1. 最小约束启动，不要过度设计
2. 让 Agent 跑起来，观察它在哪犯错
3. 每次犯错修 Harness，不是修代码
4. 注意格式：声明式规则容易被跳过，引导式问题更有效
5. 规模变化会暴露新问题——Harness 永远在演进

---

## 3. 怎么开始

### 3.1 最小 Harness

任何项目都可以从这 5 个组件开始：

- [ ] **边界** — 在第一行业务代码前定义层级结构和依赖方向。做法：写一个 ESLint 规则或目录结构约束。
- [ ] **地图** — CLAUDE.md 作为导航索引，不是百科全书。做法：≤140 行，伪代码路由，细节在 `docs/`。
- [ ] **检查** — 自动化验证，构建时拦截违规。做法：结构测试 + closeout 脚本 + trace.sh。
- [ ] **反馈** — 质量评分 + 阈值阻断。做法：定义 QUALITY_SCORE，低于阈值时 Agent 拒绝继续工作。
- [ ] **角色** — 按职责拆分 Agent，文件做契约。做法：每个 Agent 的输出文件是下一个 Agent 的输入。

先搭这 5 个。从失败中迭代。约束只升级，不降级。

### 3.2 成本与局限

| 成本 | 说明 |
|---|---|
| 冷启动慢 | 先写文档/脚本/规则，再写业务代码 |
| 文档腐烂 | 状态源超过一个就会漂移，需要 doctor 持续扫描 |
| 规则误伤 | 过硬的门禁会阻断小修复，需要豁免协议 |
| 链路损耗 | Agent 越多传递越有损，trace.sh 闭环是补丁不是根治 |
| 形式主义 | 分数/模板/frontmatter 可能变成仪式而非保障 |

**什么时候值得搭：** 代码需要长期维护、同类错误反复出现、不止一个人（或 Agent）改、需要稳定交付。

**什么时候不值得：** 一次性脚本、原型探索、两天后就扔的项目。

### 3.3 结语

模型每个季度都在变强。"最好的模型"和"第二好的模型"之间的差距在缩小。

但"有 Harness 的 Agent"和"没有 Harness 的 Agent"之间的差距在扩大。

这篇教程里的所有代码都不是人工编写的。代码分析是 Claude 做的。ESLint 规则是 Claude 写的。结构测试是 Claude 写的。trace.sh 是 Claude 写的。

**人类做的事情是：决定查什么，判断结果意味着什么，然后把判断变成 Agent 没法绕过的约束。**

**先升级 Harness，再升级模型。**

---

## 参考资料

- [OpenAI: Harness Engineering — 在智能体优先的世界中利用 Codex](https://openai.com/index/harness-engineering/)
- [Mitchell Hashimoto: My AI Adoption Journey](https://mitchellh.com/writing/my-ai-adoption-journey)
- [Martin Fowler / Böckeler: Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [HumanLayer: Skill Issue — Harness Engineering for Coding Agents](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)
- [Anthropic: Building Effective AI Agents](https://www.anthropic.com/research/building-effective-agents)

## 项目仓库

- [墨简 Mojian](https://github.com/Aryous/Mojian)（Harness 实验组）
- [Typst 简历编辑器](https://github.com/Aryous/typst-resume)（无 Harness 对照组）
- [LayerAxis 配图系统](https://github.com/Aryous/layeraxis-marketplace)（迭代案例）
- [HarnessPractice](https://github.com/Aryous/HarnessPractice)（可复用框架，44 文件 ~4000 行）
- [本文及写作素材](https://github.com/Aryous/harness-engineering-in-practice)
