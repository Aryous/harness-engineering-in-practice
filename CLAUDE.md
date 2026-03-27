# harness-engineering-in-practice

## 项目概况

Harness Engineering 实践教程项目。包含两篇文章：
- `tutorial.md` — 独立教程（主线，受控实验教学格式）
- `harness-engineering-in-practice.md` — 叙事版（个人发现过程）

## 文件结构

```
tutorial.md                     # 主线教程，9 节，每节 ≤50 行
harness-engineering-in-practice.md  # 叙事版文章（保留，不覆盖）
references/                     # 参考文章（.gitignore，不推送远程）
examples/                       # 示例文件（.gitignore，不推送远程）
```

## 工作流

- 每次完成一段工作后，主动 commit 记录进度（需征得用户同意）
- commit message 用中文，格式：`类型: 简要描述`
- 不要推送到远程，除非用户明确要求
- references/ 和 examples/ 不追踪到 git（已在 .gitignore）

## 写作约束

教程（tutorial.md）遵循设计文档 `~/.gstack/projects/harness-engineering-in-practice/aryous-main-design-20260327-180624.md`：

- **每节模板：** 症状 → 原因 → 修复 → 可复用模板
- **每节 ≤50 行**（第6节允许 50-60 行）
- **每节最多 1 个代码块，≤10 行**
- **全文 ≤450 行**
- **语气：教学，不是叙事**（不要"我让 Claude 分析了..."，要"没有边界的 Agent 会..."）
- before/after 对比用表格，不用两个独立代码块

## GitHub

- 仓库：`https://github.com/Aryous/harness-engineering-in-practice`（私有）
- 关联仓库：
  - `https://github.com/Aryous/typst-resume`（Vibe Coding 对照组）
  - `https://github.com/Aryous/Mojian`（Harness 实验组）
  - `https://github.com/Aryous/layeraxis-marketplace`（迭代案例）

---

## CLAUDE.md 官方文档

- [CLAUDE.md 最佳实践](https://docs.anthropic.com/en/docs/claude-code/claude-md) — 写作规范、层级、调试
- [Claude Code 概览](https://docs.anthropic.com/en/docs/claude-code/overview) — 功能和使用方式
- [Claude Code 内存管理](https://docs.anthropic.com/en/docs/claude-code/memory) — @import、.claude/rules/、上下文加载机制

<!-- CLAUDE.md 写作规范备忘（来自上述官方文档）

## 核心原则
- CLAUDE.md 是行为引导（behavioral guidance），不是硬性执行
- 目标 200 行以内，越短遵守率越高
- 每条指令问自己："删掉它 Claude 会犯错吗？" 不会就删
- 用 markdown 标题和列表分组
- 写可验证的具体指令，不写模糊的（"2-space indent" 而不是 "format properly"）

## 应该放
- Claude 猜不到的 Bash 命令
- 与默认不同的代码风格规则
- 测试指令和首选测试运行器
- 仓库礼仪（分支命名、PR 约定）
- 项目特定的架构决策
- 常见陷阱或非显而易见的行为

## 不应该放
- Claude 读代码就能发现的东西
- 标准语言惯例
- 详细 API 文档（改为链接）
- 经常变化的信息
- 逐文件的代码库描述
- 不言自明的实践如 "write clean code"

## 层级
- 组织级：/Library/Application Support/ClaudeCode/CLAUDE.md
- 用户级：~/.claude/CLAUDE.md（个人偏好，跨项目）
- 项目级：./CLAUDE.md 或 ./.claude/CLAUDE.md（团队共享）
- 子目录：访问该目录时按需加载

## 高级
- @import 语法引入其他文件
- .claude/rules/ 按主题拆分规则
- HTML 注释不消耗 token，可给人类维护者留注释
- 超过 200 行就该拆分到 .claude/rules/

## 调试
- /memory 查看当前加载的所有指令文件
- /init 自动生成初始 CLAUDE.md
- 提交到 git，让团队共同维护
-->
