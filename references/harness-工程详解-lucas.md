---
title: Harness Engineering 详解
date: 2026-03-24
tags:
  - AI工程
  - Agent
  - 知识补充
  - 面试
source: OpenAI / Martin Fowler / Mitchell Hashimoto
related: "[[2026-03-24-面试准备-星尘数据CEO面]]"
---

# Harness Engineering（驾驭工程）详解

> 面试中提到的概念，对应星尘第三曲线 AI Agent 方向的底层工程思想

---

## 一、它是什么

**Harness Engineering** 是 OpenAI 在 2026 年初提出的 AI Agent 时代工程方法论，核心思想是：

> **"Humans steer, agents execute"**
> 人类工程师不再直接写代码，而是设计精密的系统来引导 AI Agent 完成任务。

更简洁的定义（Mitchell Hashimoto）：
> **每当 Agent 犯错，就设计解决方案使其永不重复同样错误。**

---

## 二、工程范式的三代演进

| 时代 | 范式 | 核心问题 | 工程师关注点 |
|---|---|---|---|
| 2023 | **Prompt Engineering** | 怎么说 | 提示词措辞和格式 |
| 2025 | **Context Engineering** | 知道什么 | 给模型提供什么上下文 |
| **2026** | **Harness Engineering** | **在什么环境里做事** | **设计约束、反馈、验证机制** |

核心转变：决定 AI Agent 工程质量的主要变量，**已从模型能力转向运行环境设计**。

---

## 三、三维框架（Böckeler 模型）

Martin Fowler 网站上，Birgitta Böckeler 将 OpenAI 的 Harness 拆解为三个模块：

### 1. 上下文工程（Context Engineering）
- 渐进式文档披露：不是一次性塞给模型所有信息，而是按需动态提供
- 动态可观测性：把运行时数据（日志、错误、指标）实时反馈给 Agent
- 知识库锚定：把架构原则、业务规则写进 Agent 可读取的知识库

### 2. 架构约束（Architectural Constraints）
- **机械化 Linter**：不让 Agent 自由发挥，用确定性规则约束代码结构
- 自动修复建议：Linter 检测到问题时，不只报错，同时提供修复方案
- LLM 审计 Agent：用另一个 AI 来审查 AI 生成的内容，形成 AI 互查

### 3. 熵管理（Entropy Management）
- 专用"清理 Agent"：周期性扫描文档漂移、规则腐化、知识库过时
- 防止规则体系自身腐化——约束系统不维护的话，会变成 Agent 的噪音

---

## 四、关键案例

### 案例 1：OpenAI 内部实验（最核心的案例）
- **规模**：3 名工程师，5 个月，零手写代码
- **产出**：超过 100 万行生产级代码，约 1500 个 PR
- **效率**：平均每名工程师每天合并 3.5 个 PR（传统开发的 10 倍）
- **工具**：Codex（GPT-5 驱动的 AI 编程 Agent）
- **关键**：工程师的工作是维护文档、定义业务意图、构建验证机制——而不是写代码

### 案例 2：LangChain（说明环境比模型更重要）
- **做了什么**：只优化 Harness 环境，没有改动任何模型参数
- **结果**：Terminal Bench 2.0 排名从**第 30 升至第 5**，得分从 52.8% 升至 66.5%
- **结论**：改善 Agent 运行环境的收益，可以超过换更强的模型

### 案例 3：Stripe
- Minions 体系，每周处理 **1300 个** AI 生成 PR
- devbox 隔离环境，10 秒启动，每个任务在独立沙盒里运行

---

## 五、四大关键要素（工程师的新工作内容）

| 要素 | 含义 | 具体实践 |
|---|---|---|
| **环境沙盒化** | 给 Agent 一个安全的执行空间 | 隔离环境、受控工具集、资源限制 |
| **规则代码化** | 把架构原则变成可执行的约束 | Linter、契约式设计、知识库 |
| **反馈闭环化** | 让 Agent 能从错误中自动学习 | 可观测性反馈、自愈循环 |
| **意图结构化** | 把模糊目标变成 Agent 可执行的任务 | 任务分解、验收标准明确化 |

---

## 六、核心洞察（面试可以说的判断）

> **"当 Agent 出错时，不要只修这一次——要修系统，让它不再出错。"**

这是 Harness Engineering 和之前工程范式最本质的区别：
- Prompt Engineering 时代：出错了就改提示词
- Harness Engineering 时代：出错了就问"环境里缺了什么"，然后补进去

**Martin Fowler 的闭合问题：**
> "你今天的 Harness 是什么？"
> 组织在引入 AI 维护代码之前，应该先清点自己已有的 pre-commit hooks、自定义 Linter 和结构约束。

---

## 七、和星尘第三曲线的关联

星尘第三曲线（Precise 产品）要做的事：
- 为企业客户构建"越用越聪明"的 AI Agent 系统
- 整合记忆（memory）、架构设计与数据模型闭环

这正是 Harness Engineering 的企业落地版：
- 企业数据 → **上下文工程**（给 Agent 提供业务知识）
- 业务规则 → **架构约束**（让 Agent 在边界内工作）
- 数据闭环 → **熵管理 + 反馈循环**（系统越用越好）

---

## 八、和 LayerAxis 的关联（面试时可以说）

你在 LayerAxis 里踩过的坑，本质上就是 Harness 设计问题：

| LayerAxis 遇到的问题 | Harness Engineering 的解法 |
|---|---|
| 单 Skill 注意力漂移 | 架构约束：任务边界明确化，拆分为独立 Agent |
| 多 Agent token 消耗高 | 上下文工程：按需提供上下文，不是全量传递 |
| 输出质量不稳定 | 反馈闭环：质量评分 → 自动驳回 → 重新生成 |
| 风格指南执行偏差 | 规则代码化：把风格规则变成可验证的约束 |

---

## 参考资料

- [Harness engineering: leveraging Codex in an agent-first world | OpenAI](https://openai.com/index/harness-engineering/)
- [Harness Engineering | Martin Fowler](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [Harness Engineering 成为2026年AI开发新范式 | 虎嗅](https://www.huxiu.com/article/4841931.html)
- [Harness Engineering 深度解析 | 知乎](https://zhuanlan.zhihu.com/p/2014014859164026634)
- [OpenAI 提出 Harness Engineering | InfoQ](https://www.infoq.cn/article/MCUXGhyIRqPLkFhljY9v)
