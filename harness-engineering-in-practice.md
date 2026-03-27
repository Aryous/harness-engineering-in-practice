# Vibe Coding is not Coding

> "It's not a model problem. It's a configuration problem."
> — HumanLayer, *Skill Issue: Harness Engineering for Coding Agents*

---

我不会逐行读 React 代码。

过去三个月，我用 Claude Code 构建了多个 AI 驱动的项目。我能描述需求，能判断产出好不好用，但如果你让我解释一个 TypeScript 泛型的实现细节，我做不到。

**这个限制迫使我思考一个不同的问题。** 工程师的直觉是"我来 review 代码"。我的处境是：我没法 review 代码。所以我必须让坏代码更难产生。

为了验证这个想法，我做了一个对照实验：同一个 AI 模型，同一个人，同一个领域（简历编辑器），两个项目。一个让 Agent 自由发挥（Vibe Coding）。另一个先搭建运行环境，再让 Agent 开发（Harness Engineering）。

**代码质量差异是可量化的。**

---

## Vibe Coding 的真实产出

第一个项目：Typst 简历编辑器。需求是一句话——"做一个在线简历编辑器，用 Typst 编译，支持 AI 优化"。Agent 从零开始，自由发挥。

70 个 commit 后，项目跑起来了。模板画廊、实时预览、AI 聊天优化——功能齐全。

然后我让 Claude 从六个维度扫描了整个项目：架构分层、类型安全、测试覆盖、API 调用模式、状态管理、错误处理。我选这六个维度是因为它们能被量化——有还是没有，耦合还是分离，测试覆盖率是零还是非零。

结果出来的时候，我意识到每一个问题都指向同一个根因：**没有人给 Agent 画过边界。**

### UI 组件直接调用 API

```tsx
// web/src/components/AiInputBar.tsx:80-88
const res = await fetch("/api/chat", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    messages: newMessages,
    resumeData: state.data,
    apiKey: config.apiKey,
    model: config.model || undefined,
  }),
});
```

UI 组件直接发 HTTP 请求。没有服务层抽象，没有统一的 API 客户端。项目里每个需要调 API 的组件各自写一遍 `fetch`。

**API 路径变了，或者需要加统一的错误处理，你要改每一个组件。** 维护成本随调用点数量线性增长。这让我在墨简中做了第一个设计决策：所有 API 调用必须走 Service 层单一入口，用 ESLint 规则锁死这条边界。

### Store 混合了三种职责

```tsx
// web/src/store/resume-store.tsx:152-173
const compile = useCallback((d: ResumeData) => {
  if (compileTimer.current) clearTimeout(compileTimer.current);
  compileTimer.current = setTimeout(async () => {
    dispatch({ type: "COMPILE_START" });
    try {
      const res = await fetch("/api/compile", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(d),
      });
      if (res.ok) {
        dispatch({ type: "COMPILE_SUCCESS", svg: await res.text() });
      } else {
        const { error } = await res.json();
        dispatch({ type: "COMPILE_ERROR", error });
      }
    } catch {
      dispatch({ type: "COMPILE_ERROR", error: "网络错误，无法连接编译服务" });
    }
  }, 700);
}, []);
```

一个函数里同时做了三件事：防抖（setTimeout 700ms）、网络请求（fetch）、状态管理（dispatch）。

React 的 reducer 模式要求纯函数——给定相同输入，返回相同输出，没有副作用。这里的 store 已经变成了一个混合了业务逻辑、网络 IO 和定时器的超级对象。

**三个关注点耦合在一起，你没法单独测试其中任何一个。** 这意味着墨简的架构必须把状态管理、网络请求、业务逻辑放在不同的层——六层分层架构的出发点就在这里。

### 类型系统被架空

```tsx
// web/src/store/resume-store.tsx:66
data: setNestedField(
  state.data as unknown as Record<string, unknown>,
  action.path,
  action.value
) as unknown as ResumeData,
```

`as unknown as` —— 两次类型强转。先假装数据是通用字典，操作完再假装它是 ResumeData。中间发生了什么？TypeScript 不知道，开发者不知道，只有运行时才知道。

**TypeScript 存在的意义是在编译阶段捕获类型错误。这种写法让类型检查变成了摆设。**

### 字符串匹配判断错误类型

```ts
// web/src/app/api/chat/route.ts:58-59
const msg = err instanceof Error ? err.message : String(err);
if (msg.includes("401") || msg.includes("Unauthorized")) {
```

用 `msg.includes("401")` 判断认证失败。错误消息不属于 API 契约。换一个 SDK 版本，措辞变了，这个判断就坏了。正确的做法是检查 HTTP 状态码或结构化的错误代码——确定性的字段。

### 零测试，零自定义 lint，零架构约束

整个项目没有一个测试文件。ESLint 只有 Next.js 默认规则。没有任何机制验证架构是否被遵守。

**所有质量保障都依赖人工 review。** 而这个项目的开发者没有工程背景——实际上没有质量保障。这是我最清楚的一个判断：我没有能力做人工 code review，所以必须让机器来做。自定义 ESLint 规则和结构测试就是我的替代方案。

### Git 历史

```
9d80419 fix: 大幅提升表单可读性 — 输入框加白底边框，卡片实色化
629884f fix: 消除面板与画布之间的分界线
8be4e2d fix: 修复编辑面板对比度不足
ba8c7bd fix: 修复左上角品牌文字与编辑面板标题重叠
ca27b51 fix: 删除无用保存按钮 + 修复设置图标 viewBox 裁切
0680ea6 fix: 编辑面板默认打开 + 控件对比度提升
```

最近 30 条 commit 中有 8 条在修同类 UI 问题——对比度、布局、控件状态。这是我不需要读代码就能看出来的模式：commit 信息本身就在说"这里有系统性问题"。**Agent 在没有设计系统的情况下反复试错。** 改一处，另一处又坏了。没有设计令牌，没有一致性约束，只有无限循环的微调。

---

## 环境的问题

看完 Claude 的分析报告，直觉反应是"模型不行，换一个更好的"。

但这些代码就是 Claude Opus 4.6 写的。同期最强的编码模型之一。它完全有能力写分层架构，也知道测试的重要性。

**问题在于没有人告诉它这个项目需要什么。**

一个有趣的事实：正因为我不是工程师，我比工程师更早到达这个结论。工程师遇到烂代码的第一反应是"我来重构"。我的第一反应是"我没法重构，我只能让它从一开始就写对"。这个限制反而指向了正确的方向。

Mitchell Hashimoto 的定义最精确：

> "Anytime you find an agent makes a mistake, you take the time to engineer a solution such that the agent never makes that mistake again."

OpenAI 的 Codex 团队用 3 名工程师、5 个月、零手写代码，交付了超过 100 万行生产级代码。他们最早的发现：

> "早期进展比我们所预期的要慢，而这并不是因为 Codex 不具备相应的能力，而是因为环境的规范不够明确。"

LangChain 只优化运行环境，不改模型参数，Terminal Bench 2.0 排名从第 30 升至第 5。

**这些案例指向同一个结论：决定 AI agent 输出质量的主要变量，已经从模型能力转向运行环境设计。** OpenAI 把这叫 Harness Engineering。

---

## 同一个项目，加上 Harness

第二个项目叫墨简（Mojian）。同样是简历编辑器，同样用 Claude Code。

**唯一的区别：在写第一行业务代码之前，先搭建了完整的 Harness 框架。**

Typst 项目的每一个失败模式都变成了墨简的一条设计约束。UI 直调 API → 六层分层 + ESLint 规则。Store 混合职责 → 层间依赖禁令。零测试 → 14 个结构测试 + CI 门禁。我的工作不是写这些约束的代码——Claude 写的——我的工作是决定需要哪些约束、放在哪一层、违反了会怎样。

### CLAUDE.md 是地图

OpenAI 尝试过把所有规则塞进一个巨大的 `AGENTS.md`。失败了：

> "情境是一种稀缺资源。一个巨大的指令文件会挤掉任务、代码和相关文档。当一切都'重要'时，一切都不重要了。"

他们的解法：`AGENTS.md` 只有约 100 行，当目录用，指向更深的文档。

墨简的 CLAUDE.md 采用同样的设计：

```markdown
# 墨简 (Mojian) — Agent 地图

> 这是一张地图，不是说明书。细节在 docs/ 里。
> Agent 看不到的知识不存在——所有决策必须落库。

## 系统目标

**产品目标**：构建一个中古风 AI 驱动的简历编辑器。
**系统目标**：使 Agent 能够自主、可靠地构建和维护这个产品，
人类只在意图输入和裁决节点介入。
```

162 行，全部是导航信息。产品规格在 `docs/product-specs/`，技术决策在 `docs/design-docs/tech-decisions.md`，设计规范在 `docs/design-docs/design-spec.md`。Agent 按图索骥。

### 六层架构，写在代码里

```
Types → Config → Repo → Service → Runtime → UI
```

允许向下依赖。禁止向上依赖。禁止跨层依赖。

这个约束直接写在自定义 ESLint 规则里：

```js
// eslint-rules/layer-dependency.js

const ALLOWED_DEPS = {
  types:   ['types'],
  config:  ['config', 'types'],
  repo:    ['repo', 'config', 'types'],
  service: ['service', 'repo', 'config', 'types'],
  runtime: ['runtime', 'service', 'config', 'types'],
  ui:      ['ui', 'runtime', 'config', 'types'],
}
```

UI 组件试图直接引用 Service 层？ESLint 报错，构建失败。错误信息里直接注入修复指令：

```
禁止从 ui 层引用 service 层。
允许的依赖方向：Types → Config → Repo → Service → Runtime → UI
修复方法：如需跨层通信，通过 Runtime 层中转，
或将共享逻辑下沉到 Types/Config 层。
```

OpenAI 的做法一样："由于这些 lint 是自定义的，我们编写错误信息时会在智能体情境中注入修复指令。"

在此之上，14 个结构测试验证目录完整性和依赖关系：

```ts
// tests/structure/layers.test.ts
const ALLOWED_DEPS: Record<string, string[]> = {
  types:   ['types'],
  config:  ['config', 'types'],
  repo:    ['repo', 'config', 'types'],
  service: ['service', 'repo', 'config', 'types'],
  runtime: ['runtime', 'service', 'config', 'types'],
  ui:      ['ui', 'runtime', 'config', 'types'],
}
// 遍历所有 .ts/.tsx，解析 import，验证目标层是否在允许列表中
```

ESLint 在编码时拦截，结构测试在 CI 时兜底。**Agent 没有办法绕过这些约束。**

OpenAI 有一个相关的观察："这种架构通常要等到你拥有数百名工程师时才会推迟。对于编码智能体来说，这是一个早期的先决条件。"

这说明了一件值得注意的事情。**对人来说，约束通常是负担。对 Agent 来说，约束是能力的来源。**

### 三层约束

| 层级 | 机制 | 执行方式 | 能绕过吗 |
|---|---|---|---|
| 硬约束 | 自定义 ESLint + 结构测试 | 构建失败即阻断 | 不能 |
| 中约束 | `.claude/rules/` | 自动注入 Agent 上下文 | 理论上可以 |
| 软约束 | `docs/` | Agent 需主动读取 | 不读就不知道 |

**约束只升级，不降级。** 如果一条软约束被违反两次，它就应该升级为中约束。如果中约束还不够，升级为硬约束。这来自墨简的 `protocols.md`：

> First occurrence → Update docs/
> 2nd occurrence → Watch for pattern
> 3rd occurrence → Upgrade to .claude/rules/
> Still violated → Upgrade to lint rule

这意味着系统的可靠性只增不减。每一次 Agent 犯错，都会让 Harness 变得更强。

### 五个专职 Agent

| Agent | 职责 | 触发条件 | 输出 |
|---|---|---|---|
| req-review | 结构化需求 | 新功能意图 | requirements.md |
| tech-selection | 技术决策 | 新依赖/架构变更 | tech-decisions.md |
| design | 设计规范 + 实现 | 设计任务 | design-spec.md + src/ui/ |
| feature | 功能开发 | 有 exec-plan | src/ 代码 + 测试 |
| doc-gardening | 文档清理 | 每 5 个 PR / 质量下降 | 修复 PR |

每个 Agent 有硬编码的前置检查。feature agent 在 `QUALITY_SCORE < 40` 时拒绝工作。design agent 在 `tech-decisions.md` 未审批前拒绝启动。

### 质量追踪与闭环

```
| 维度         | 满分 | 当前 |
|-------------|------|------|
| 需求覆盖     | 25   | 20   |
| 架构合规     | 25   | 23   |
| 文档新鲜度   | 25   | 22   |
| 测试覆盖     | 25   | 18   |
| 总分         | 100  | 83   |
```

总分低于 40，feature agent 和 design agent 自动阻断。任何单项低于 15，触发 doc-gardening 扫描。

这构成了一个闭环：Agent 输出 → 质量评分 → 分数过低 → 阻断 → 修复后才能继续。

---

## 证据

同一个维度，Typst 项目 vs 墨简项目：

| 维度 | Typst（无 Harness） | 墨简（有 Harness） |
|---|---|---|
| API 调用 | UI 组件直接 fetch，N 处散落 | Service 层单一入口，lint 强制 |
| 状态管理 | reducer 混合防抖、网络、dispatch | 分层隔离，Zustand 只管状态 |
| 类型安全 | `as unknown as` 强转链 | 叶子层 Types，全链路类型安全 |
| 测试 | 0 | 52（14 结构 + 38 单元） |
| 架构验证 | 无 | 自定义 ESLint + 14 结构测试 |
| 设计一致性 | 8/30 commit 修同类 UI 问题 | 三级令牌系统 + rules 约束 |
| 质量门禁 | 无 | QUALITY_SCORE < 40 阻断 Agent |

**同一个人，同一个模型，同一个领域。唯一的变量是 Harness。**

---

## 迭代比结构更重要

简历项目的对比展示了 Harness 的结构价值。但 Harness Engineering 更核心的部分是迭代方法——agent 犯错，诊断环境缺口，修 Harness，这个错误就不再发生。

我的配图系统（LayerAxis）完整经历了这个过程。从 33% 的可用率迭代到 100%。模型没有换，约束变得更精确了。

### 33%——隐喻选完没展开

6 张配图只有 2 张可用。Agent 选了隐喻（"灯塔"代表方向），但没有展开为视觉规格——灯塔多大？在画面什么位置？光束往哪照？

**Harness 修改**：在 SKILL.md 中加入 6 项视觉规格清单和提示词写法原则对比表。

### 71%——引用被埋太深

7 张中 5 张可用。关键参考文件被埋在两层引用深处，agent 没读到。同时，声明式规则列表（"必须做 X"）被模型跳过了。

**Harness 修改**：3 处直接内联引用。用引导式问题替代声明式列表：

> - "视线先落在哪里？然后移向哪里？"
> - "有多少个东西在争夺注意力？超过 7 个就砍。"
> - "三维纵深表达了什么信息？说不出来就换二维。"

这里有一个值得注意的发现。**规则够了，问题出在呈现方式。声明式列表被模型扫过去，引导式提问让模型主动思考。** 同样的知识，换一种格式交付给 agent，执行效果完全不同。

### 100%——一句话修复执行流

6 张全部可用。但质量停留在 65-70——可用但无亮点。诊断发现 agent 在横向批处理：先把所有图的场景设计做完，再批量上色，再批量写提示词。批处理打断了创意的连贯性。

Harness 修改：在 SKILL.md 开头加了一句话：

> "对每张图，走完 Step 2→3→4 完整链路，一次性写入，再做下一张。"

一句话。通过率稳定在 100%。

**模型没变，prompt 的措辞没变，执行流变了。** 环境约束的改变直接改变了 Agent 的行为模式。

### 80%——规模暴露新问题

密度从 6 张扩展到 15 张，通过率降到 80%。情绪层被渲染为结构图，冗余图复制了文章中已有的表格。

**规模放大暴露新的系统性问题。** Harness 是一个持续演进的系统。每次你以为它稳定了，新的规模或新的需求会揭示下一个缺口。

### 配图系统的 Harness 工件

**plan.lock.yaml（参数契约）**：

```yaml
density: standard
style_guide: digital-rationalism
negative_prompt: "no neon, no cyberpunk, no heavy texture..."
generation:
  model: gemini-3-pro-image-preview
  aspect_ratio: "16:9"
  image_size: "2K"
```

上游 orchestrator 锁定参数，下游 creative 和 render agent 不可覆写。这解决了一个真实发生过的问题：creative agent 擅自修改了图片尺寸和风格指南，导致产出与预期不一致。参数契约让这件事不可能再发生。

**pipeline-gates.md（质量门禁）**：

```
Gate 0 → plan.lock.yaml 存在且值域合法 → 才允许进入 creative
Gate A → creative-draft.md 非空 → 才允许进入 compiler
Gate B → 每个 NN-*.md 有非空 English Prompt → 才允许 render
Review → review-feedback.yaml 存在 → 打回 creative 重写
```

每个 gate 是一个确定性检查点。通过才能继续，没通过就回退。这是管道的物理结构。

---

## 五条原则

从两个案例中可以提炼出构建 Harness 的核心原则。

**1. 环境先于代码。**

墨简的 ESLint 规则、结构测试、CI 配置在第一行业务代码之前就存在了。约束是基础设施。OpenAI："有了约束，速度才不会下降，架构才不会漂移。"

**2. Agent 看不到的东西不存在。**

Google Docs 里的讨论、Slack 里的共识、人脑中的判断——agent 都访问不到。在墨简项目中，每一个技术决策都写进 `docs/design-docs/tech-decisions.md`，包括被拒绝的方案和拒绝原因。答案在仓库里。

**3. 用代码强制执行。**

Typst 项目的 CLAUDE.md 写了"保持代码整洁"。这是一个没有执行力的软约束。墨简的做法：把"UI 不能直接调用 Service"写成 ESLint 规则。违反了，构建失败。Agent 不需要自觉遵守——环境不允许它违反。

**4. 反应式迭代，只升不降。**

让 agent 跑起来，等它犯错，再修环境。但约束只升级：`docs/ → .claude/rules/ → lint rule`。可靠性只增不减。

**5. 地图，不给说明书。**

上下文窗口是有限的。大文件挤掉了真正重要的任务信息。CLAUDE.md 应该是一个约 100 行的目录，指向更深的文档。渐进式披露，按需加载。

---

## Closing

这篇文章里的所有代码，我一行都没写。代码分析是 Claude 做的。ESLint 规则是 Claude 写的。结构测试是 Claude 写的。

**我做的事情是：决定让 Claude 查什么，判断结果意味着什么，然后把判断变成 Agent 没法绕过的约束。**

这就是我理解的 Agent 工程师的工作：把模糊的意图变成可执行、可验证、可迭代的工程系统。模型会越来越强。但"让模型在正确的边界内工作"这件事，仍然需要人来做。

---

## 参考资料

- [OpenAI: Harness Engineering — 在智能体优先的世界中利用 Codex](https://openai.com/index/harness-engineering/)
- [Mitchell Hashimoto: My AI Adoption Journey](https://mitchellh.com/writing/my-ai-adoption-journey)
- [Martin Fowler / Böckeler: Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [HumanLayer: Skill Issue — Harness Engineering for Coding Agents](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)

## 项目仓库

- [Typst 简历优化](https://github.com/Aryous/typst-resume)（无 Harness 对照组）
- [墨简 Mojian](https://github.com/Aryous/Mojian)（Harness Engineering 实验组）
- [本文及写作素材](https://github.com/Aryous/harness-engineering-in-practice)
