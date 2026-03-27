[BT](/int/bt/ "bt")

[InfoQ Homepage](/ "InfoQ Homepage") [News](/news "News") OpenAI Introduces Harness Engineering: Codex Agents Power Large‑Scale Software Development

[Architecture & Design](/architecture-design/ "Architecture & Design")

This item in [japanese](/jp/news/2026/03/openai-harness-engineering-codex)

Listen to this article - 0:00

OpenAI has detailed a new [internal engineering methodology called Harness engineering](https://openai.com/index/harness-engineering/) that leverages AI agents to drive key aspects of the software development lifecycle. The system uses Codex, a suite of AI agents, to perform tasks such as writing code, generating tests, and managing observability, based on declarative prompts defined by engineers. Harness standardizes workflows, reducing reliance on handcrafted scripts and custom tooling.

[Ryan Lopopolo](https://www.linkedin.com/in/ryanlopopolo/), member of the technical staff at OpenAI, mentioned:

> We built Harness to provide a consistent and reliable way to run large-scale AI workloads, so teams can focus on research and product development rather than infrastructure orchestration.

In a five-month internal experiment, OpenAI engineers built and shipped a beta product containing roughly a million lines of code without any manually written source code. A small team of engineers guided agents through pull requests and continuous integration workflows. The work included application logic, documentation, CI configuration, observability setup, and tooling. Engineers provided prompts and feedback, while [Codex](https://openai.com/index/introducing-codex/) agents iterated autonomously on tasks including reproducing bugs, proposing fixes, and validating outcomes.

![](news/2026/02/openai-harness-engineering-codex/en/resources/1codefeedback-1771570048741.jpeg)

*Codex Agent‑Driven Application Testing and Feedback ( Source: [OpenAI Blog Post](https://openai.com/index/harness-engineering/))*

Harness engineering shifts human engineers focus from implementing code to designing environments, specifying intent, and providing structured feedback. Codex interacts directly with development tools, opening pull requests, evaluating changes, and iterating until task criteria are satisfied. Agents use telemetry, including logs, metrics, and spans, to monitor application performance and reproduce bugs across isolated development environments.

![](news/2026/02/openai-harness-engineering-codex/en/resources/1openaiobservability-1771570245491.jpeg)

*Observability and Telemetry Workflow for Codex Agents ( Source: [OpenAI Blog Post](https://openai.com/index/harness-engineering/))*

Internal documentation is organized in a structured docs directory containing maps, execution plans, and design specifications. These documents serve as the single source of truth for agents. Cross-linked design and architecture documentation is mechanically enforced with linters and CI validation, ensuring consistency and reducing the need for manual oversight.

OpenAI enforces architectural boundaries and dependency layers across domains through mechanical rules and structural tests. Dependencies flow in a controlled sequence from Types → Config → Repo → Service → Runtime → UI, with agents restricted to operate within these layers. Structural tests validate compliance and prevent violations of modular layering.

[Martin Fowler](https://www.linkedin.com/in/martin-fowler-com/), author and Thoughtworks technologist, mentioned in a LinkedIn [Post](https://www.linkedin.com/posts/martin-fowler-com_harness-engineering-activity-7429522347822546944-4gfm?utm_source=share&utm_medium=member_desktop&rcm=ACoAAArnikgBqzTxA9Y838-O55QUcB2McACIq94)

> Harness Engineering is a valuable framing of a key part of AI‑enabled software development. Harness includes context engineering, architectural constraints, and garbage collection.

OpenAI reports that Harness encodes scaffolding, feedback loops, documentation, and architectural constraints into machine-readable artifacts, which Codex agents use to execute tasks across development workflows, including code generation, testing, and observability.

## About the Author

### The InfoQ Newsletter

A round-up of last week’s content on InfoQ sent out every Tuesday. Join a community of over 250,000 senior developers. [View an example](https://assets.infoq.com/newsletter/regular/en/newsletter_sample/newsletter_sample.html)

[BT](/int/bt/ "bt")