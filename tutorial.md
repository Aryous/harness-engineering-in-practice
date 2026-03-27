# Harness Engineering 实践教程

> 同一个人，同一个模型，同一个领域。两个项目写出了两种代码质量。唯一的变量是 Harness。

---

## 1. 先看结果

两个简历编辑器项目，条件完全相同，结果完全不同：

| 维度 | Typst（Vibe Coding） | 墨简（Harness） |
|---|---|---|
| API 调用 | UI 组件直接 fetch，散落各处 | Service 层单一入口，lint 强制 |
| 状态管理 | reducer 混合防抖、网络、dispatch | 分层隔离，状态管理只管状态 |
| 类型安全 | `as unknown as` 双重强转 | 叶子层 Types，全链路类型安全 |
| 测试 | 0 | 52（14 结构 + 38 单元） |
| 架构验证 | 无 | 自定义 ESLint + 14 结构测试 |
| 设计一致性 | 8/30 commit 修同类 UI bug | 三级令牌系统 + rules 约束 |
| 质量门禁 | 无 | QUALITY_SCORE < 40 阻断 Agent |

同一个人，同一个模型，同一个领域。**唯一的变量是开发前有没有搭 Harness。**

---

## 2. 实验设计

**不变的条件：**

- 开发者：非工程师（不能逐行读代码）
- 模型：Claude Opus 4.6
- 领域：简历编辑器（Web 应用）
- 工具：Claude Code

**变化的条件：**

- Typst：一句话需求 → Agent 自由编码 → 70 个 commit → 功能齐全但质量失控
- 墨简：一句话需求 → 先搭 Harness（ESLint / 结构测试 / CLAUDE.md / Agent 角色）→ Agent 在约束内编码

**衡量维度：** API 调用模式、状态管理、类型安全、测试覆盖、架构验证、设计一致性、质量门禁。每个维度都是二元判断：有还是没有，耦合还是分离，零还是非零。

**为什么这个对比成立：** 同一个人消除了技能变量。同一个模型消除了能力变量。同一个领域消除了复杂度变量。剩下的唯一解释就是 Harness。

---

## 3. 先约束环境，再让 AI 写代码

**症状：** Typst 项目里，UI 组件直接调 API。每个组件各写一遍 `fetch`。Store 把防抖、网络请求、状态管理混在一个函数里。

```tsx
// Typst: UI 组件直接发请求，没有服务层
const res = await fetch("/api/chat", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ messages, resumeData, apiKey }),
});
```

**原因：** 没有人定义边界。Agent 选了最省事的架构——把所有东西塞在一起。

**修复：** 墨简在第一行业务代码之前就定义了六层架构：`Types → Config → Repo → Service → Runtime → UI`。只允许向下依赖。用自定义 ESLint 规则锁死。

**模板：**
1. 写代码之前，先定义层级结构和依赖方向
2. 用 ESLint 规则或结构测试强制执行
3. Agent 不需要自觉遵守——环境不允许它违反

---

## 4. 知识写成地图，不要写成百科

**症状：** 把所有规则塞进一个大文件。Agent 的上下文被挤满，分不清什么跟当前任务有关。

**原因：** 上下文窗口是有限的。OpenAI 的发现：

> "情境是一种稀缺资源。一个巨大的指令文件会挤掉任务、代码和相关文档。当一切都'重要'时，一切都不重要了。"

**修复：** 墨简的 CLAUDE.md 只有 162 行，全部是导航信息。产品规格在 `docs/product-specs/`，技术决策在 `docs/design-docs/`，设计规范在 `docs/design-docs/design-spec.md`。Agent 按任务类型加载对应文档，不全量加载。

**模板：**
1. CLAUDE.md 只放路径和导航，不超过 160 行
2. 详细内容放 `docs/` 目录，按类型分文件夹
3. Agent 按当前任务加载对应的文档切片，不是所有文档

---

## 5. 约束必须能执行，不能只写在文档里

**症状：** Typst 项目零测试、零自定义 lint、零架构约束。"保持代码整洁"写在文档里。Agent 没读。

**原因：** 写在文档里的规则是建议，不是约束。Agent 可以不读，也可以读了不遵守。

**修复：** 墨简用三层约束，从软到硬：

| 层级 | 机制 | 能绕过吗 |
|---|---|---|
| 硬 | 自定义 ESLint + 14 结构测试 | 不能，构建失败 |
| 中 | `.claude/rules/` | 自动注入，理论上能绕 |
| 软 | `docs/` | 不读就不知道 |

```js
// eslint-rules/layer-dependency.js（精简版）
const ALLOWED_DEPS = {
  types:   ['types'],
  config:  ['config', 'types'],
  repo:    ['repo', 'config', 'types'],
  service: ['service', 'repo', 'config', 'types'],
  runtime: ['runtime', 'service', 'config', 'types'],
  ui:      ['ui', 'runtime', 'config', 'types'],
}
```

违反时，错误信息直接告诉 Agent 怎么修："禁止从 ui 层引用 service 层。通过 Runtime 层中转。"

**约束只升级，不降级。** 软约束被违反两次 → 升级为中约束。中约束仍违反 → 升级为硬约束。系统越跑越可靠。

**模板：**
1. 关键架构规则直接写成 ESLint 或测试
2. 错误信息里注入修复指令，Agent 能自行修复
3. 约束升级路径：`docs/` → `.claude/rules/` → `lint rule`，只升不降

---

## 6. Harness 不是设计出来的，是被失败逼出来的

**症状：** 配图系统（[LayerAxis](https://github.com/Aryous/layeraxis-marketplace)），三个 Agent 的流水线。第一次跑，6 张配图只有 2 张能用。33% 可用率。

这个系统迭代了四轮。模型没换过。每一轮都是同一个循环：跑起来 → 看哪里坏了 → 修 Harness。

**33%：** Agent 选了隐喻（"灯塔"代表方向）但没展开为视觉规格——灯塔多大？画面哪个位置？光束往哪照？**修复：** 加入隐喻展开三步法：选类型 → 定规格 → 验可读。

**71%：** 关键参考文件被埋在两层引用深处。声明式规则（"必须做 X"）被模型跳过。**修复：** 内联引用，用引导式问题替代规则列表——"视线先落在哪里？" "有多少个东西在争夺注意力？超过 7 个就砍。"

**100%：** 通过率满分但质量 65-70。诊断发现 Agent 在批处理：先做完所有图的场景设计，再批量上色。批处理打断了创意连贯性。**修复：** 一句话——"对每张图，走完完整链路再做下一张。" 通过率稳定在 100%。

**80%：** 规模从 6 张扩展到 15 张，新的系统性问题出现。**Harness 持续演进。每次你以为稳定了，新规模会暴露下一个缺口。**

Mitchell Hashimoto 的定义：

> "Anytime you find an agent makes a mistake, you take the time to engineer a solution such that the agent never makes that mistake again."

**模板：**
1. 最小约束启动，不要过度设计
2. 让 Agent 跑起来，观察它在哪犯错
3. 每次犯错修 Harness，不是修代码
4. 注意格式：声明式规则容易被跳过，引导式问题更有效

---

## 7. 上下文冲突了才拆 Agent

**症状：** 一个 Agent 同时做需求分析、技术决策、设计、编码、测试、文档。上下文膨胀，角色混乱。

**原因：** 不同任务需要不同的上下文。需求分析需要产品规格，编码需要技术文档。塞在一起，Agent 分不清当前该关注什么。

**修复：** 墨简用 5 个专职 Agent，每个只做一件事。`req-review` 输出 `requirements.md`，`tech-selection` 读它并输出 `tech-decisions.md`，`design` 读它并输出 `design-spec.md`。**文件就是契约。**

配图系统用 3 个 Agent。creative 用 Opus（创意需要推理能力），render 用 Haiku（只跑脚本，不需要推理）。**模型匹配认知负载。**

**拆了之后的陷阱：** 墨简的 5 Agent 链路在实际运行中暴露了一个系统性 bug——**每次 Agent 间传递都是有损的。** `requirements.md` 写了"富文本编辑 P0"，经过 plan agent → feature agent 两次传递后被遗漏。链条越长，丢失越多。而且链路末端没有任何验证机制回溯需求是否被完整实现。修复：在 Agent 链路中加入闭环验证——实现完成后，必须回溯 requirements 逐条核对。

**什么时候不该拆：** 任务之间上下文高度重叠时，拆分反而增加通信成本。单 Agent 能处理好就不要拆。拆分标准是上下文冲突，不是任务数量。

**模板：**
1. 上下文冲突时才拆，不是默认拆
2. Agent 之间用文件传递，文件就是契约
3. 模型匹配任务：推理用大模型，执行用小模型
4. 链路末端必须闭环验证：实现完成后回溯 requirements 逐条核对
5. 门禁连接 Agent：通过才能继续，成功静默，失败出声

---

## 8. 最小 Harness

任何项目都可以从这 5 个组件开始：

- [ ] **边界** — 在第一行业务代码前定义层级结构和依赖方向。做法：写一个 ESLint 规则或目录结构约束。
- [ ] **地图** — CLAUDE.md 作为导航索引，不是百科全书。做法：≤160 行，只放路径指向，细节在 `docs/`。
- [ ] **检查** — 自动化验证，构建时拦截违规。做法：结构测试验证目录和依赖，CI 门禁阻断不合格的提交。
- [ ] **反馈** — 质量评分 + 阈值阻断。做法：定义 QUALITY_SCORE，低于阈值时 Agent 拒绝继续工作。
- [ ] **角色** — 按职责拆分 Agent，文件做契约。做法：每个 Agent 的输出文件是下一个 Agent 的输入。

先搭这 5 个。从失败中迭代。约束只升级，不降级。

---

## 9. 结语

模型每个季度都在变强。"最好的模型"和"第二好的模型"之间的差距在缩小。

但"有 Harness 的 Agent"和"没有 Harness 的 Agent"之间的差距在扩大。

**先升级 Harness，再升级模型。**

---

## 参考资料

- [OpenAI: Harness Engineering](https://openai.com/index/harness-engineering/)
- [Mitchell Hashimoto: My AI Adoption Journey](https://mitchellh.com/writing/my-ai-adoption-journey)
- [Martin Fowler / Böckeler: Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [HumanLayer: Skill Issue](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)
- [Anthropic: Building Effective AI Agents](https://www.anthropic.com/research/building-effective-agents)

## 项目仓库

- [Typst 简历编辑器](https://github.com/Aryous/typst-resume)（Vibe Coding 对照组）
- [墨简 Mojian](https://github.com/Aryous/Mojian)（Harness Engineering 实验组）
- [LayerAxis 配图系统](https://github.com/Aryous/layeraxis-marketplace)（迭代案例）
- [本文及写作素材](https://github.com/Aryous/harness-engineering-in-practice)
