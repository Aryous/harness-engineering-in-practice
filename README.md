# 一个非工程师的 Harness Engineering 实践

## 关于我

我不是软件工程师。

我的背景是数据运营——做过 SQE、主数据管理、数据分析。我没有系统学过软件工程，不懂设计模式，不会写测试框架。我使用 AI 编程工具（主要是 Claude Code）的方式，就是大多数人说的 vibe coding——描述我想要什么，让 agent 去写，出了问题就再描述一遍。

这篇文章不是教程。我没有资格写教程。

这是一篇**实践笔记**。我读了 OpenAI 关于 [Harness Engineering](https://openai.com/index/harness-engineering/) 的文章，觉得里面的想法对我有用。然后我试着照做了。过程中我大量使用了现成的 Skill、脚本和工具——很多不是我写的，是 Claude 帮我写的，或者是社区现有的。我尽我所能给 agent 搭脚手架，最终做出了一些之前我自己做不到的东西。

我想诚实地分享这个过程：我理解了什么，做了什么，哪里做得还不够。

---

## 我从 OpenAI 的文章中读到了什么

OpenAI 在 2026 年初发表了一篇内部实验报告：[3 名工程师，5 个月，零手写代码，产出超过 100 万行生产级代码](https://openai.com/index/harness-engineering/)。

对我冲击最大的不是数字，是这句话：

> **人类掌舵。智能体执行。**

以及他们对工程师角色的重新定义：

> 工程师工作的重点转向了系统、架构和杠杆作用。

他们发现，早期进展慢不是因为 Codex 不够强，而是因为**环境的规范不够明确**。agent 缺乏完成任务所需的工具、文档和结构。所以工程师的工作变成了：给 agent 创造能做好工作的环境。

[Mitchell Hashimoto](https://mitchellh.com/writing/my-ai-adoption-journey#step-5-engineer-the-harness) 把这个方法论叫 Harness Engineering：

> 每当 agent 犯错，就花时间设计一个解决方案，让它永远不再犯同样的错误。

[Birgitta Böckeler](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html) 在 Martin Fowler 的网站上将 harness 拆解为三层：

| 层 | 做什么 | 例子 |
|---|---|---|
| **Context Engineering** | 给 agent 提供正确的上下文 | AGENTS.md、知识库、可观测性数据 |
| **Architectural Constraints** | 用确定性规则约束 agent 行为 | Linter、结构测试、参数契约 |
| **Garbage Collection** | 周期性清理熵增 | 文档漂移扫描、索引重建、目录清理 |

读到这里，我意识到一件事：**我一直在做的 vibe coding，缺的不是更强的模型，是环境。** 我每次都在重新告诉 agent 同样的规则，每次它都以新的方式犯同样的错。因为我没有把规则固化到环境里。

### OpenAI 文章中对我影响最大的三点

**1. 给地图，不是给手册**

他们试过"一个巨大的 AGENTS.md"，失败了。原因很直觉：当一切都"重要"时，一切都不重要。agent 的注意力是有限的，塞太多指令反而更差。

他们的解法：AGENTS.md 只有约 100 行，是一张**目录**，指向 `docs/` 下的深层文档。agent 需要什么就去查什么。这叫**渐进式披露**。

**2. 不是模型的问题，是配置的问题**

[HumanLayer](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents) 在几十个企业项目后得出了同样的结论：

> It's not a model problem. It's a **configuration problem**.

这句话改变了我遇到问题时的第一反应。以前是"模型不够聪明"或者"我描述得不够好"，现在是"**环境里缺了什么？**"

**3. 代码仓库是唯一的真相来源**

> 从智能体的角度来看，它在运行时无法在情境中访问的任何内容都是不存在的。存储在 Google Docs、聊天记录或人们头脑中的知识都无法被系统访问。

这意味着：如果我希望 agent 遵守某个规则，这个规则必须写在它能看到的地方——代码仓库里的文件。不能只在对话里说一次。

---

## 我的实践：从零构建一个简历编辑器

### 为什么选这个项目

我需要一份好的简历。我之前用 Typst（一种排版语言）手写简历模板，但每次修改内容都要手动编辑源码、重新编译、检查排版。我想要一个左边表单、右边实时预览的编辑器，能自动编译 Typst 并导出 PDF。

这个项目在以前我是做不出来的。它需要：Next.js 前端、API routes、Typst 编译集成、实时预览、数据持久化。任何一项我都不会。

通过 vibe coding 我能让 agent 写出能跑的代码，但质量不稳定——它会忘记之前的设计决策，重复引入已修复的 bug，风格不一致。所以我决定试试 Harness Engineering 的方法。

### 第一步：写 CLAUDE.md

OpenAI 的文章说"给地图，不是给手册"。所以我的 CLAUDE.md 不长，大约 100 行，分成几个明确的 section：

```markdown
## 开发命令

cd web
npm run dev      # 启动开发服务器 (localhost:3000)
npm run build    # 生产构建
npm run lint     # ESLint 检查

## 项目架构

这是一个本地简历编辑器，
左侧表单 → 实时生成 Typst 源码 → 调用本地 typst 编译 → 右侧预览 SVG。

### 目录结构

typst/               # Typst 模板与数据层
  template.typ       # 布局与样式定义
  resume.json        # 简历数据（gitignored）
  resume.example.json # 示例数据

web/                 # Next.js 16 前端
  src/
    types/resume.ts        # 核心类型定义
    lib/generateTypst.ts   # ResumeData → .typ 源码
    app/api/compile/       # POST: 生成 SVG 预览
    app/api/export/        # POST: 导出 PDF
    components/
      ResumeEditor.tsx     # 主组件
      FormEditor.tsx       # 左栏表单
      Preview.tsx          # 右栏 SVG 预览
```

这里的每一行都是 agent 犯过错之后加的：

- **开发命令**：agent 不知道要 `cd web` 才能跑项目，在根目录执行 `npm run dev` 然后报错
- **编译流程**：agent 不理解 Typst 源码怎么变成 SVG，写 API 时路径全搞错了
- **目录结构**：agent 不知道 `template.typ` 在哪里，每次都在错误的位置创建新文件

这就是 Mitchell Hashimoto 说的反应式方法：**agent 犯了错 → 写进 CLAUDE.md → 永不重犯。**

### 第二步：自主工作流规则

只有"是什么"（项目结构）还不够，还需要"怎么做"（工作流程）。agent 反复出现的问题是：

- 改完代码不 lint，提交了才发现有错
- 改完不看效果，继续往下写，错误层层叠加
- 不知道什么时候该停下来

所以我在 CLAUDE.md 里加了自主工作流规则：

```markdown
## 自主工作流规则

### 完成一项工作后立即 commit

每次完成一个功能点、修复、或设计改动后，自动执行：

cd web && npm run lint      # 必须 lint 通过
git add -A
git commit -m "..."

lint 有报错时先修复，再 commit。

### 自主测试

- 每次改动组件后，确认 dev server 正在运行
- 用 Playwright 截图验证页面可正常加载、无明显布局崩溃
- 如果截图显示异常，优先修复，再继续

### 停止条件

以下情况停止，等待用户反馈：
- 遇到需要用户决策的设计方向分歧
- 某个问题修复超过 2 次仍未解决
```

对照 Harness Engineering 的框架：

| 规则 | 对应的 Harness 维度 |
|---|---|
| lint → commit 流程 | **Architectural Constraints**：确定性校验 |
| Playwright 截图自检 | **Back-Pressure**：agent 验证自己的工作 |
| 停止条件 | **Architectural Constraints**：明确的边界 |

这些规则加进去之后，agent 的行为立刻变得更可预测。它不再是"想到哪写到哪"，而是有节奏的：改动 → 检查 → 提交 → 下一个。

### 结果

14 个 commit 后，我有了一个能用的简历编辑器：左栏表单编辑个人信息和工作经历，右栏实时渲染 Typst 并预览 SVG，一键导出 PDF。经历了暗色极简风 → Figma 风格重构 → 浅色系重设计三次 UI 迭代。

这是之前 vibe coding 做不到的。不是模型变强了——从头到尾用的都是同一个模型。是**环境变了**。agent 有了地图（CLAUDE.md）、有了规则（lint 流程）、有了自检能力（Playwright 截图）、有了边界（停止条件）。

---

## 进阶：当单文件不够用

Typst 简历编辑器的 harness 只有一个 CLAUDE.md。对简单项目来说够了。但当系统变复杂，一个文件装不下所有知识。

我在另一个项目——AI 配图生成系统 [LayerAxis](https://github.com/Aryous)——上遇到了这个问题。它是一个三级流水线（orchestrator → creative agent → render agent），为文章的每个章节设计和生成配图。这个系统的 harness 需要更多组件。

以下工件都在 [`examples/`](./examples/) 目录下，是真实使用中的代码，做了脱敏处理。

### Skills — 渐进式披露

CLAUDE.md 越写越长时，agent 的上下文窗口开始不够用。[HumanLayer 称之为 progressive disclosure](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)：把领域知识封装成 Skill，需要时才加载。

[`examples/skills/memv2/SKILL.md`](./examples/skills/memv2/SKILL.md) 是一个知识持久化的 Skill：

```markdown
---
name: memv2
description: >
  Classify, structure, and persist conversation knowledge.
  Explicit trigger: user says /mem.
---

# Knowledge Persistence Spec

## Record Types

| Type | When to Use | Spec File |
| --- | --- | --- |
| Snapshot | Preferences, inspiration | references/snapshot.md |
| Archive | Structured output, methodology | references/archive.md |
```

`description` 字段告诉 harness 什么时候加载这个 Skill。没被触发时，不占上下文空间。

### Architectural Constraints — 参数契约

多 agent 系统的问题是：downstream agent 会偷偷覆写 upstream 的决定。creative agent 觉得 4:3 比 16:9 好看，就自己改了 orchestrator 设定的参数。

解法是 [`examples/constraints/plan-lock.yaml`](./examples/constraints/plan-lock.yaml)——锁定参数，只有 orchestrator 能写，所有 downstream agent 只读：

```yaml
# plan.lock.yaml — Only the orchestrator can write. Downstream read-only.
density: standard
generation:
  model: gemini-3-pro-image-preview
  aspect_ratio: "16:9"
  image_size: "2K"
```

配合 [`examples/constraints/pipeline-gates.md`](./examples/constraints/pipeline-gates.md)——每个阶段入口的校验清单：

```markdown
## Gate 0 — Before creative phase
- plan.lock.yaml exists
- Only contains approved keys (whitelist)
- Value domains are valid

## Gate B — Before render phase
- At least one NN-*.md exists
- Each NN-*.md has non-empty ## English Prompt
```

Gate 的原则是 **成功静默，失败出声**——验证通过不输出任何东西，只有失败时才注入 agent 上下文。这个原则来自 HumanLayer 的教训：他们早期让 agent 每次跑完整测试套件，4000 行通过的测试输出涌入上下文，agent 反而开始幻觉。

### Sub-Agents — 上下文防火墙

一个 agent 同时处理创意设计和图片渲染时，中间过程（文件读取、API 日志、错误重试）会塞满上下文窗口。窗口越长，agent 越蠢——[Chroma 的研究](https://research.trychroma.com/context-rot)证实了这一点。

拆成独立 sub-agent 后，orchestrator 只看到最终输出（[`examples/orchestrator/orchestrator.md`](./examples/orchestrator/orchestrator.md)）：

```markdown
|              | plan.lock | outline.md | NN-*.md | *.png | summary.json |
|--------------|-----------|------------|---------|-------|--------------|
| orchestrator | Write     | —          | —       | —     | —            |
| creative     | Read      | Write      | Write   | —     | —            |
| render       | Read      | —          | Read    | Write | Write        |
```

### 一个迭代故事：33% → 100%

这些组件不是一次性设计出来的。下面是配图系统的真实迭代数据：

| 日期 | 干预 | 通过率 | Harness 维度 |
|---|---|---|---|
| 02-16 | 隐喻展开三步法 + 提示词从叙述改为规格书 | 33%（2/6） | Context Engineering |
| 02-17a | 补上遗漏的参考文件引用 + 加设计原则引导问题 | 71%（5/7） | Context Engineering |
| 02-17b | 加一句执行流约束：每张图走完全链路再做下一张 | 100%（6/6） | Architectural Constraints |

没有一次是换模型解决的。每次都是问"环境里缺了什么"，然后补进去。

第三次尤其有意思：问题表现为"创意不足"，但根因是执行流程把 Step 2/3/4 理解成了批处理——先写完所有场景设计，再回头补提示词。注意力断了。修复方法是加一句话约束执行顺序，创意连贯性自然恢复。

---

## 我还不会做的事

诚实地说，我的实践和 OpenAI 文章描述的还有很大差距：

- **我没有自定义 linter。** OpenAI 用自定义 linter 机械化执行架构约束（依赖方向、命名规范、文件大小限制）。我的约束全靠 CLAUDE.md 里的文字描述，依赖 agent 自觉遵守。
- **我没有自动化 CI。** OpenAI 的每个 PR 都经过 agent 审查 + CI 校验。我的项目只有本地 lint。
- **我的垃圾回收是手动的。** OpenAI 有后台 agent 定期扫描漂移、开重构 PR。我还在手动清理。
- **我的可观测性为零。** OpenAI 给 Codex 接了完整的日志/指标/追踪栈。我的 agent 看不到运行时数据。

这些差距不是因为工具不存在，是因为我的工程能力还不够把它们搭起来。但方向是清晰的：**把更多的规则从文档变成代码，从依赖 agent 自觉变成机械化执行。**

---

## 写在最后

回到开头的问题：一个非工程师能从 Harness Engineering 中得到什么？

对我来说，最大的收获是一个思维方式的转变。以前 agent 出了问题，我的反应是"这个模型不行"或者"我再试一次"。现在我的反应是：**环境里缺了什么？**

这个问题让我从"试运气"变成了"建系统"。即使我建的系统很粗糙，它也比每次从零开始要好。

Martin Fowler 在他的文章最后问了一个问题：

> **What's your harness today?**

我的 harness 今天是：一个 100 行的 CLAUDE.md、几个现成的 Skill、一些 shell 脚本、一套参数锁定文件。不多，但比上个月多。

如果你也在用 AI 编程工具，不管你的工程背景如何，我觉得 harness 的核心思想对每个人都适用：

**agent 犯了错 → 诊断根因 → 固化到环境里 → 下次不再犯。**

不需要一次做对。只需要每次比上次好一点。

---

## 代码

本仓库的 [`examples/`](./examples/) 目录包含我在实践中使用的真实 harness 工件（已脱敏）：

```
examples/
├── CLAUDE.md                     # 全局 agent 指令（渐进式上下文加载）
├── skills/
│   ├── memv2/                    # 知识持久化 Skill
│   └── illustration-archive/     # 配图归档 Skill + 清理脚本
├── constraints/
│   ├── plan-lock.yaml            # 参数锁定契约
│   └── pipeline-gates.md         # 阶段门禁校验
└── orchestrator/
    └── orchestrator.md           # 多 agent 权限矩阵
```

## 参考文献

| # | 文章 | 作者 |
|---|---|---|
| 1 | [Harness Engineering: Leveraging Codex in an Agent-First World](https://openai.com/index/harness-engineering/) | OpenAI |
| 2 | [Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html) | Birgitta Böckeler (Martin Fowler) |
| 3 | [Skill Issue: Harness Engineering for Coding Agents](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents) | HumanLayer |
| 4 | [My AI Adoption Journey](https://mitchellh.com/writing/my-ai-adoption-journey) | Mitchell Hashimoto |
| 5 | [The Emerging Harness Engineering Playbook](https://www.ignorance.ai/p/the-emerging-harness-engineering) | Ignorance.ai |

## License

MIT
