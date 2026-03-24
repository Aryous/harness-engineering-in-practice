# Harness Engineering 实践指南

你的 AI 编程代理又犯了同样的错误。

你改了 prompt，好了一次，下次又坏了。你加了更多指令，它开始忽略其中一半。你换了更强的模型，旧问题消失了，新问题冒出来了。

这不是模型的问题。这是环境的问题。

[Mitchell Hashimoto](https://mitchellh.com/writing/my-ai-adoption-journey#step-5-engineer-the-harness) 把这个过程叫做 **Harness Engineering**（驾驭工程）：

> Anytime you find an agent makes a mistake, you take the time to engineer a solution such that the agent never makes that mistake again.

这篇教程不是文献综述。下面的每个组件、每段代码，都来自我围绕 Claude Code 构建的真实工具链——一个 AI 配图生成系统的 harness。它们不是一次性设计出来的，而是在 agent 反复犯错的过程中，一个一个被逼出来的。

---

## 第一章：什么是 Harness Engineering

### 起源

2026 年初，OpenAI 发表了一篇内部实验报告：[3 名工程师，5 个月，零手写代码，产出超过 100 万行生产级代码](https://openai.com/index/harness-engineering/)。工程师的工作不是写代码，而是维护文档、定义意图、构建验证机制。Codex agent 负责执行。

Mitchell Hashimoto 在同一时期独立提出了相同的方法论。他的表述更直接：**agent 犯了错，就修环境，让它不再犯**。不是修 prompt，不是换模型，是修环境。

HumanLayer 在[数十个企业项目](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)后得出同样的结论：

> It's not a model problem. It's a **configuration problem**.

### 三层框架

[Birgitta Böckeler](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html) 在 Martin Fowler 的网站上将 harness 拆解为三层：

| 层 | 做什么 | 例子 |
|---|---|---|
| **Context Engineering** | 给 agent 提供正确的上下文 | AGENTS.md、知识库、动态可观测性数据 |
| **Architectural Constraints** | 用确定性规则约束 agent 行为 | Linter、结构测试、参数契约 |
| **Garbage Collection** | 周期性清理熵增 | 文档漂移扫描、索引重建、工作目录清理 |

### 核心原则

Harness Engineering 是**反应式**的。不是提前设计完美系统，而是：

```
agent 犯错 → 诊断根因 → 修改环境 → 永不重犯
```

你今天的 harness 可能只有一个 CLAUDE.md。这完全没问题。它会在 agent 犯错的过程中自然生长。

---

## 第二章：Harness 的六个组件

以下六个组件来自 [HumanLayer 的实战总结](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)。每个组件我都用自己的真实工件来说明——它们都在 [`examples/`](./examples/) 目录下，可以直接查看完整代码。

### 1. CLAUDE.md / AGENTS.md — 仓库级指令

**问题**：每次新对话，agent 都忘了项目的基本规则。哪些文件在哪里，用什么命令，什么不能碰。每次都要重新说一遍。

**解法**：写一个 CLAUDE.md，让 harness 在每次对话开始时自动注入 agent 的系统提示。

**代码**：[`examples/CLAUDE.md`](./examples/CLAUDE.md)

```markdown
## Context Loading

Claude loads relevant background on demand based on conversation content.
It does NOT load everything at the start.

### Memory

@~/.claude/memories/INDEX.md
@~/.claude/memories/PROFILE.md

- When a topic relates to a memory entry, check INDEX first,
  then Read the specific file
```

关键设计决策：**按需加载，不是全量注入**。ETH Zurich 的[研究](https://arxiv.org/abs/2602.11988)证实了这一点——往 agent 系统提示里塞太多内容，反而让它变蠢。目录结构、文件列表这些 agent 自己就能发现的东西，不要写进去。只写它无法自行推断的规则。

**教训**：CLAUDE.md 的价值不在于全面，在于精准。我们的 CLAUDE.md 不到 50 行。

### 2. Skills — 渐进式披露

**问题**：把所有指令塞进 CLAUDE.md，agent 的上下文窗口很快就满了。指令越多，每条指令被遵守的概率越低。

**解法**：把领域专用知识封装成 Skill，agent 需要时才加载。这就是 HumanLayer 说的 **progressive disclosure**——渐进式披露。

**代码**：[`examples/skills/memv2/SKILL.md`](./examples/skills/memv2/SKILL.md)

```markdown
---
name: memv2
description: >
  Classify, structure, and persist conversation knowledge.
  Explicit trigger: user says /mem.
  Implicit trigger: when conversation produces reusable methodology...
---

# Knowledge Persistence Spec

## Philosophy

Records exist not to "miss nothing," but to
**let your future self reactivate the thinking state of the present moment**.

## Record Types

| Type | When to Use | Spec File |
| --- | --- | --- |
| Snapshot | Preferences, inspiration | references/snapshot.md |
| Archive | Structured output, methodology | references/archive.md |
| ...
```

Skill 的 `description` 字段告诉 harness 什么时候该加载它。用户说 `/mem` 时触发，或者对话中产生了方法论性质的内容时隐式触发。Skill 没被触发时，它不占上下文空间。

Skill 目录本身就是一个渐进式披露结构：主 SKILL.md 告诉 agent 有哪些 reference 文件，agent 按需读取。不是一次性塞进去。

**教训**：如果你发现 CLAUDE.md 越写越长，说明你需要把领域知识拆成 Skill。

### 3. Scripts / Tools — 确定性工具

**问题**：配图生成完成后，需要把 `imgs-spec/` 下的文件归档到正确目录、加正确前缀、插入正确的文章引用、最后清空工作目录。让 agent 手动做这些步骤，每次都会出错——忘记加前缀、归档到错误路径、清理不干净。

**解法**：写一个 shell 脚本，agent 调用一次就全部搞定。

**代码**：[`examples/skills/illustration-archive/scripts/archive.sh`](./examples/skills/illustration-archive/scripts/archive.sh)

```bash
#!/usr/bin/env bash
# Archive imgs-spec/ to Resource/illustrations/<project>/
set -e

FILENAME=$(basename "$ARTICLE_PATH" .md)
DATE_RAW=$(echo "$FILENAME" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')
DATE=$(echo "$DATE_RAW" | tr -d '-')
PROJECT=$(echo "$FILENAME" | sed "s/^${DATE_RAW}-//")
PREFIX="${DATE}-${PROJECT}"

# Archive images with prefix
for f in "$IMGS_SPEC"/*.jpg; do
  [[ -e "$f" ]] || continue
  cp "$f" "$RESOURCE_BASE/$PROJECT/images/${PREFIX}-$(basename "$f")"
done

# Clean imgs-spec/ only after successful archive
rm -f "$IMGS_SPEC"/*.jpg "$IMGS_SPEC"/*.md "$IMGS_SPEC"/*.yaml
```

注意 `set -e`：任何一步失败，脚本立刻停止。不是 agent 去判断"要不要继续"，是确定性地失败。

Mitchell Hashimoto 把这类工具分为两类：
1. **隐式提示**（AGENTS.md）——告诉 agent 用什么命令、避免什么行为
2. **实际工具**（脚本）——把多步操作封装成一次调用

两者通常配合使用：SKILL.md 里写 `bash archive.sh "<path>"`，agent 照做就行。

**教训**：能用脚本确定性完成的事，不要让 agent 自由发挥。

### 4. Architectural Constraints — 参数契约

**问题**：配图系统是一个三级流水线——orchestrator 设定参数，creative agent 设计构图，render agent 出图。问题是：downstream agent 会偷偷覆写 upstream 设定的参数。creative agent 觉得 4:3 比 16:9 更好看，就自己改了。

**解法**：用 `plan.lock.yaml` 锁定参数，配合 `pipeline-gates.md` 在每个阶段入口校验。

**代码**：[`examples/constraints/plan-lock.yaml`](./examples/constraints/plan-lock.yaml)

```yaml
# plan.lock.yaml — Global parameter contract (orchestrator-owned)
# Only the orchestrator can write this file. All downstream agents read-only.

density: standard          # minimal | standard | full
style_guide: digital-rationalism
generation:
  model: gemini-3-pro-image-preview
  aspect_ratio: "16:9"     # 1:1 | 3:4 | 4:3 | 9:16 | 16:9
  image_size: "2K"         # 1K | 2K | 4K
```

**代码**：[`examples/constraints/pipeline-gates.md`](./examples/constraints/pipeline-gates.md)

```markdown
## Gate 0 — Before creative phase

- plan.lock.yaml exists
- Only contains approved keys (whitelist)
- Value domains are valid:
  - density: minimal / standard / full
  - aspect_ratio: 1:1 / 3:4 / 4:3 / 9:16 / 16:9
  - image_size: 1K / 2K / 4K

## Gate B — Before render phase

- plan.lock.yaml contains no unknown fields
- At least one NN-*.md exists
- Each NN-*.md has non-empty ## English Prompt
```

Gate 的设计原则：**成功静默，失败出声**。通过了就继续，不通过就停下来报错。不要在成功时输出一大段确认信息——那些文字会塞满 agent 的上下文窗口，让它变蠢。HumanLayer 称之为 **context-efficient back-pressure**。

**教训**：agent 之间的信任不能靠 prompt 建立。用文件锁定契约，用 gate 校验合规。

### 5. Sub-Agents — 上下文防火墙

**问题**：让一个 agent 同时处理创意设计和图片渲染，它的上下文窗口很快被中间过程塞满——文件读取结果、API 调用日志、错误重试记录。窗口越长，agent 越蠢。

**解法**：拆成独立的 sub-agent，每个 sub-agent 有自己的上下文窗口。orchestrator 只看到 sub-agent 的最终输出，不被中间噪音污染。

**代码**：[`examples/orchestrator/orchestrator.md`](./examples/orchestrator/orchestrator.md)

```markdown
## Subagent Interaction Matrix

|  | plan.lock | outline.md | NN-*.md | *.png | summary.json |
|---|---|---|---|---|---|
| **orchestrator** | Write | — | — | — | — |
| **creative**     | Read  | Write | Write | — | — |
| **render**       | Read  | —     | Read  | Write | Write |
```

关键不是"角色分工"——不是"前端 agent"和"后端 agent"。HumanLayer 试过这种模式，[不好用](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)。关键是**上下文隔离**。creative agent 的所有探索、试错、回溯，都封装在它自己的上下文里。orchestrator 只拿到最终的 outline.md 和 NN-*.md。

Sub-agent 还有成本收益：orchestrator 用贵的 Opus 做规划，sub-agent 用便宜的 Sonnet 做执行。任务越简单、上下文越干净的窗口，越不需要强模型。

**教训**：如果你觉得需要更长的上下文窗口，你可能需要的是更好的上下文隔离。

### 6. Back-Pressure — 自检验证

**问题**：agent 说"完成了"，但输出有问题。缺少必需字段、格式不对、文件没写完。你不检查就直接用了，到下游才发现。

**解法**：让 agent 在声称完成之前，先自己验证。验证通过才能继续，不通过就回退重做。

这不需要单独的代码——它是 pipeline-gates 的另一面。Gate B 要求每个 `NN-*.md` 都有非空的 `## English Prompt`。如果 creative agent 偷懒跳过了某张图的提示词，Gate B 拦住它，要求补齐后重新过检。

设计原则和 hooks 一样：**成功静默，失败出声**。验证通过时不要输出任何东西。只有失败时才把错误信息注入 agent 上下文，迫使它修复。HumanLayer 早期的做法是每次都跑完整测试套件——4000 行通过的测试结果涌入上下文，agent 反而开始幻觉。后来改成只暴露失败，问题消失了。

**教训**：给 agent 验证自己工作的能力，是投入产出比最高的 harness 改进。

---

## 第三章：一个真实的迭代故事

理论容易讲，但 harness 的价值必须用数据说话。下面是我的配图系统从 33% 通过率到 100% 的完整迭代过程。每一步提升，都对应一个具体的 harness 修改。

### 背景

我围绕 Claude Code 构建了一个 AI 配图生成系统（[LayerAxis](https://github.com/Aryous)）。它读取一篇文章，为每个章节设计配图的视觉隐喻、色彩方案和构图，输出英文提示词，再调用图像生成 API 出图。

系统架构：orchestrator → creative agent → render agent。creative agent 是核心——它要读懂文章、选隐喻、展开为视觉场景、写出精确的设计规格。

### 迭代数据

| 日期 | 干预 | 通过率 | 对应 Harness 维度 |
|---|---|---|---|
| 02-16 | 隐喻展开三步法 + 提示词规格化 | 33%（2/6） | Context Engineering |
| 02-17a | dimension-catalog 引用内联 + "退后一步看"认知锚点 | 71%（5/7） | Context Engineering |
| 02-17b | 一句话执行流约束 | 100%（6/6） | Architectural Constraints |

### 第一次：33%（2/6）—— 隐喻选了但没展开

6 张配图跑完，只有 2 张能用。把生成的提示词和之前手工流程产出的高质量提示词对比，发现系统性差距：

**问题**：SKILL.md 的流程是"选隐喻类型 → 直接写提示词"，中间跳过了把抽象隐喻展开为具体视觉规格的步骤。"坐标系"只是一个类型标签，不是施工图纸。

**Harness 修复**：在 SKILL.md 中增加隐喻展开三步——选类型、定规格（物件形态/尺寸/位置/标注/空间关系）、验可读。同时把提示词的写法从"叙述式"改为"规格式"——每个视觉元素写成组件规格（fill/border/radius），不写氛围描述。

这是 **Context Engineering**：agent 不是不会做，是缺少做好的知识。补上就行。

### 第二次：71%（5/7）—— 参考文件没加载

通过率从 33% 升到 71%，但仍有 2 张失败。图 06 的网络图布局视觉动线混乱，图 07 的 3D 等距台阶让 AI 渲染成千层饼。

**问题**：`dimension-catalog.md`（结构类型列表、隐喻表、情绪修辞表）藏在 ref 的 ref 里，SKILL.md 完全没有指向它。agent 不知道这个文件存在。另外，硬规则全是数量上限（≤7 元素、≤3 颜色），缺少引导 agent"感受"设计质量的锚点。

**Harness 修复**：
1. 在 SKILL.md 三个维度展开处各加 `@references/dimension-catalog.md` 引用
2. 插入"退后一步看"认知锚点——不是清单，是三个引导性问题：
   - "眼睛先落在哪里？然后往哪移动？"（视觉动线唯一性）
   - "几样东西在争夺注意力？超过七个就砍"（信息密度控制）
   - "3D 的深度方向在表达什么信息？说不出就换 2D"（维度适配）

仍然是 **Context Engineering**：不是加规则，是用引导式提问让模型主动内化设计原则。

### 第三次：100%（6/6）—— 一句话修复执行流

6/6 全部通过，但质量只有 65-70 分——能用，但不出彩。图 04 之前的版本用双色反向梯度条直接"画出"核心洞察，这次只是四张卡片加底部文字，把洞察"说出来"而非"画出来"。

**问题**：这看起来是创意不足，但实际是**执行流程**的问题。模型把 Step 2/3/4 理解为横向批处理——先写完所有 6 张图的场景设计，再回头逐个追加上色和提示词。这导致写提示词时，场景设计已经是几分钟前的内容，注意力从"构建视觉世界"变成"机械翻译已有描述"。

**Harness 修复**：在 SKILL.md Step 2 开头加一句话：

> 对每张图，走完 Step 2→3→4 完整链路后再做下一张。

一句话。不改步骤结构，不引入新编号。这是 **Architectural Constraint**——不是告诉 agent"创意要好"，而是约束执行顺序，让创意连贯性自然恢复。

### 迭代的启示

回看这三次迭代：

1. **33% → 71%**：补知识（Context Engineering）
2. **71% → 100%**：补引导（Context Engineering）
3. **100% 但不出彩 → 100% 且出彩**：改执行流（Architectural Constraint）

没有一次是换模型解决的。每次都是问"环境里缺了什么"，然后补进去。

第三次尤其值得注意：问题表现为"创意不足"，但根因是执行流程切断了注意力连贯性。如果不诊断根因直接加 prompt"请更有创意"，不会有任何效果。

这就是 Mitchell Hashimoto 说的：**agent 犯了错，修环境，不是修 prompt。**

---

## 第四章：如何开始建你自己的 Harness

### 从 CLAUDE.md 开始

如果你还没有 CLAUDE.md（或 AGENTS.md），现在就建一个。它是最低成本的 harness 组件——一个 markdown 文件，zero infrastructure。

不要试图提前设计完美的 CLAUDE.md。先写三件事：
- 项目用什么语言/框架
- 测试怎么跑
- 什么文件不能碰

然后开始用 agent 干活。

### 反应式迭代

Mitchell Hashimoto 的路径：

```
Step 1: Agent 犯了错
Step 2: 诊断根因（不是表面症状）
Step 3: 修改环境（CLAUDE.md / Skill / 脚本 / 约束）
Step 4: 验证修复
Step 5: 回到 Step 1
```

每次 agent 犯错，问自己两个问题：
1. 这是第几次犯同类错误？
2. 我能用什么确定性手段阻止它再犯？

第一次犯 → 写进 CLAUDE.md。
第二次同类错误 → 升级为 Skill 或 Hook。
第三次 → 考虑 Architectural Constraint（linter、gate、脚本）。

### 避免过度工程

HumanLayer 的经验值得记住——他们试过的但**不好用**的：

- 提前设计完美 harness（还没遇到真实失败就开始优化）
- 安装几十个 MCP 服务器"以备不时之需"（工具太多反而让 agent 变蠢）
- 每次都跑完整测试套件（成功的测试输出塞满上下文窗口）
- 精细控制每个 sub-agent 能访问哪些工具（增加复杂度但没有改善结果）

好用的：

- **只在 agent 实际失败时才加配置**
- 成功静默，失败出声
- 优化迭代速度，不优化"一次成功概率"
- 不好用的配置果断删掉

Harness 不是越复杂越好。它应该是 agent 犯错历史的最小充分集。

---

## 结尾

Harness Engineering 改变了工程师的工作内容。

从前你是 maker——写代码，调 bug，优化性能。现在你越来越像 manager——你不直接写代码，你设计让 agent 写好代码的环境。你的产出不是代码行数，是约束、工具、文档和验证机制。

Martin Fowler 在他的文章最后问了一个问题：

> **What's your harness today?**

你的回答不需要很复杂。一个 50 行的 CLAUDE.md、一个 pre-commit hook、一个跑测试的脚本——这就是 harness 的起点。

重要的不是你今天有多少组件，而是你是否建立了这个循环：

**agent 犯错 → 诊断根因 → 修环境 → 永不重犯。**

---

## 参考文献

| # | 文章 | 作者 |
|---|---|---|
| 1 | [Harness Engineering: Leveraging Codex in an Agent-First World](https://openai.com/index/harness-engineering/) | OpenAI |
| 2 | [Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html) | Birgitta Böckeler (Martin Fowler) |
| 3 | [Skill Issue: Harness Engineering for Coding Agents](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents) | HumanLayer |
| 4 | [My AI Adoption Journey](https://mitchellh.com/writing/my-ai-adoption-journey) | Mitchell Hashimoto |
| 5 | [The Emerging Harness Engineering Playbook](https://www.ignorance.ai/p/the-emerging-harness-engineering) | Ignorance.ai |
| 6 | [From Prompt Engineering to Harness Engineering](https://softmaxdata.com/blog/from-prompt-engineering-to-harness-engineering-the-three-eras-of-building-with-ai/) | Softmax |

## License

MIT
