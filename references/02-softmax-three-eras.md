If you have been building with large language models over the past couple of years, you have lived through a quiet revolution in how we think about this work. It started with prompt engineering, the art of asking the model the right question. Then it shifted to context engineering, the discipline of giving the model the right information. And now a third phase is emerging: harness engineering, which is about building the right environment for AI agents to do reliable, autonomous work.

Each era did not replace the previous one. They stacked. Think of it like building a house: prompt engineering is learning how to talk to the electrician, context engineering is handing them the blueprint, and harness engineering is designing the entire job site so a crew of electricians, plumbers, and carpenters can all work at the same time without bumping into each other.

Let us walk through all three and see what changed, why it changed, and what it means for developers shipping AI-powered products today.

## Era 1: Prompt Engineering

When GPT-3 landed and developers first got API access to a powerful language model, the immediate question was: how do I get this thing to do what I want? The answer was prompt engineering, the practice of carefully wording your instructions to get useful, consistent output from the model.

In this era, most use cases were one-shot: classify this text, summarize this document, generate a marketing blurb. The workflow was straightforward. You wrote a system prompt, maybe added a few examples (few-shot prompting), and called the API. If the output was wrong, you tweaked the wording and tried again. The entire discipline revolved around finding the right incantation to make the model behave.

Prompt engineering taught the developer community something important: the words you use to talk to a model matter a lot. Telling the model to "think step by step" could dramatically improve accuracy on reasoning tasks. Structuring your prompt with clear sections, role assignments, and explicit constraints made outputs more predictable. These were real, practical discoveries, and they remain useful today.

But prompt engineering had a ceiling. As developers started building more complex applications, multi-step workflows, retrieval-augmented systems, agents that use tools, the prompt itself became just one small piece of the puzzle. You could have a perfectly crafted prompt, but if the model was missing critical context about the user, the task, or the state of the world, it would still get things wrong. That gap gave rise to the next era.

## Era 2: Context Engineering

By mid-2025, a new term started showing up everywhere: context engineering. Anthropic described it as the natural progression of prompt engineering in their detailed write-up on the topic. The key insight was simple but powerful: it is not enough to write a great prompt. You need to curate the entire set of information the model sees at inference time, including system instructions, tool definitions, retrieved documents, conversation history, and any other data that lands in the context window.

Why does this matter? Because models have what you might call an attention budget. Every token you feed into the context window competes for the model's focus. Stuff too much irrelevant information in there, and accuracy drops. This is sometimes called context rot: the larger the context grows, the harder it becomes for the model to locate and use the information it actually needs. It is not a hard cliff, but there is a real performance gradient. Shorter, more focused contexts tend to produce better results than sprawling ones.

Context engineering introduced several techniques that developers now use daily. Retrieval-augmented generation (RAG) pulls in relevant documents before each call. Tool design became a first-class concern: if your tools return bloated payloads, they waste the model's attention. Compaction, the practice of summarizing a long conversation so the model can keep going with a clean slate, became essential for any agent that runs for more than a few turns. And structured note-taking gave agents a way to persist important facts outside the context window and pull them back in later, like a developer keeping a scratch pad during a long debugging session.

The shift from prompt engineering to context engineering also changed what "good at AI" means for a developer. It stopped being about clever phrasing and became more about systems thinking. How does information flow through your application? What does the model see at each step? Are you loading the right data at the right time? These questions feel much more like traditional software architecture than wordsmithing.

But even with great context engineering, there was still a fundamental assumption baked in: a human is in the loop on every task, or at least on every important decision. Context engineering optimized what the model sees, but it still assumed a fairly tight feedback cycle between a human and a model. What happens when you want agents to work for hours, open pull requests, review their own code, and merge changes, all without a human touching the keyboard? That is where the third era begins.

## Era 3: Harness Engineering

In February 2026, OpenAI published a remarkable post titled "Harness engineering: leveraging Codex in an agent-first world." The team described how they built and shipped an internal software product with zero lines of manually-written code. Every line, application logic, tests, CI configuration, documentation, internal tooling, was written by Codex agents. A small team of three engineers drove roughly 1,500 pull requests across five months, generating on the order of a million lines of code.

The name "harness engineering" is intentional. A harness is the supporting structure that holds something in place and lets it do its job. In testing, we have test harnesses. In hardware, we have wiring harnesses. Harness engineering is the practice of building the entire environment, tools, guardrails, feedback loops, and architectural constraints, that allows AI agents to do useful, reliable work at scale with minimal human intervention.

To draw an analogy, imagine the entire agentic ecosystem as a computer. LLMs are the CPU, the raw processing power. Agents are the applications that run on top. And the harness is the operating system, the thing that manages resources, enforces permissions, coordinates processes, and makes sure everything works together without crashing.

## What Harness Engineering Looks Like in Practice

The OpenAI team's experience revealed several concrete principles that define this new discipline.

First, the repository becomes the source of truth for everything. Not Slack, not Google Docs, not someone's head. If the agent cannot find it in the repo, it effectively does not exist. The OpenAI team organized their knowledge base into a structured docs/ directory with architecture documentation, design documents, execution plans, and quality scores, all versioned and co-located with the code. A short AGENTS.md file served as a table of contents pointing to deeper sources, not a giant instruction manual. They learned early that one massive instruction file actually hurt performance because it crowded out the actual task context.

Second, architecture is enforced mechanically, not by convention. The team defined strict dependency rules between layers of their application and enforced them with custom linters and structural tests, all generated by Codex itself. Each business domain had a fixed set of layers with validated dependency directions. In a human-first codebase, these kinds of rules can feel pedantic. In an agent-first codebase, they become essential. Without hard boundaries, agents will replicate whatever patterns already exist in the code, including bad ones, and drift accumulates fast.

Third, you make the application legible to the agent, not just to humans. The team wired Chrome DevTools Protocol into the agent runtime so Codex could take screenshots, inspect DOM snapshots, and navigate the UI. They built a local observability stack where agents could query logs and metrics. This meant prompts like "make sure no span in these four user journeys exceeds two seconds" became something the agent could actually verify on its own. They regularly saw single Codex runs work on a task for six or more hours, often while the human engineers slept.

Fourth, you build garbage collection into the process. Agents replicate patterns, including bad ones. The team initially spent every Friday (20% of their time) cleaning up what they called "AI slop." That did not scale. Instead, they encoded "golden principles" into the repo and set up recurring background tasks that scan for deviations, update quality grades, and open targeted refactoring pull requests. Technical debt gets paid down continuously in small increments rather than piling up for a painful burst later.

## How the Three Eras Compare

Here is a helpful way to think about how these three eras differ across several dimensions.

In the prompt engineering era, the core question was "what words do I use?" The unit of work was a single API call. The human role was author, writing the prompt, reading the output, and deciding what to do next. When something went wrong, you rewrote the prompt. The feedback loop was manual: try, read, tweak, repeat.

In the context engineering era, the core question became "what information does the model need right now?" The unit of work expanded to a multi-turn session or a chain of tool calls. The human role shifted to architect, designing the information pipeline that feeds the model at each step. When something went wrong, you examined what data was in the context window and whether it was the right data at the right time. Techniques like RAG, compaction, and memory tools became standard.

In the harness engineering era, the core question is "what environment does the agent need to work autonomously?" The unit of work is an entire feature, from bug reproduction to fix to review to merge. The human role shifts again to environment designer, building the scaffolding, setting the constraints, and defining what "good" looks like so the agent can validate its own work. When something goes wrong, the fix is rarely "try harder." It is almost always "what capability or guardrail is missing?" Feedback loops are automated: linters, tests, agent-to-agent reviews, and observability stacks that let the agent self-correct.

## What This Means for Developers Today

You do not need to be building a million-line agent-generated codebase to start applying these ideas. The lessons from each era are cumulative and practical, and you can start using them in your existing projects right now.

From prompt engineering, keep the fundamentals. Write clear, well-structured prompts. Use XML tags or markdown headers to organize sections. Provide a few high-quality examples instead of a laundry list of edge cases. These basics have not gone away; they have just become one layer of a larger stack.

From context engineering, treat your model's context window as a budget. Audit what goes in. Use retrieval to pull in relevant information dynamically rather than stuffing everything up front. Design your tools to return concise, focused outputs. If your agent runs for many turns, implement compaction so the context stays fresh. Think about what the model sees at each step the way you would think about what arguments you pass to a function.

From harness engineering, start thinking about how you can make your codebase and your development environment more legible to agents. Add an AGENTS.md or CLAUDE.md to your repo as a starting point, a short map of your codebase that points to key documentation. Invest in tests and linters that encode your architectural decisions. If you use coding agents like Codex, Claude Code, or Cursor, give them access to the same tools your team uses: your test suite, your linter, your build system. The more an agent can verify its own work, the less you have to babysit it.

## The Bigger Picture

What connects all three eras is a steady shift in where the leverage is. In the prompt era, the leverage was in the words. In the context era, the leverage was in the data. In the harness era, the leverage is in the systems you build around the agent.

The role of the developer is also shifting with each era, but it is not shrinking. If anything, it is becoming more interesting. You move from writing individual functions to designing systems where intelligent agents can operate safely and effectively. You think less about implementation details and more about invariants, constraints, and feedback mechanisms. It looks a lot more like platform engineering or systems design than traditional coding, and that is not a bad thing.

The OpenAI team summarized their philosophy with a line that captures where the industry is heading: "Humans steer. Agents execute." The job of the engineer is not disappearing. It is elevating. And the three eras of prompt engineering, context engineering, and harness engineering are the roadmap of that elevation.

## References

OpenAI, "Harness engineering: leveraging Codex in an agent-first world" (February 2026) - https://openai.com/index/harness-engineering/

Anthropic, "Effective context engineering for AI agents" (September 2025) - https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents