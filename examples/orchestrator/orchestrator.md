# Orchestrator — Sub-Agent Permission Matrix

## Overview

The orchestrator is a two-level agent pipeline coordinator.
It does NOT generate content — it only handles initialization, parameter confirmation, dispatch, and failure rollback.

```
orchestrator ──▶ creative ──▶ render
                    │            │
               outline.md    *.png
               NN-*.md    summary.json
```

**Two modes**:
- **`auto`**: Full pipeline runs continuously, no pause.
- **`review`**: Pauses after creative output for human feedback before continuing.

## Subagent Interaction Matrix

|  | plan.lock | outline.md | NN-*.md | *.png | summary.json |
| --- | --- | --- | --- | --- | --- |
| **orchestrator** | Write (bootstrap) | — | — | — | — |
| **creative** | Read | Write | Write | — | — |
| **render** | Read | — | Read | Write | Write |

— means the agent does not touch this file.

## plan.lock Contract

`plan.lock.yaml` is the single source of truth for the entire pipeline.

### Whitelist Fields

Only these keys are allowed — unknown fields must be removed:

| Field | Description |
| --- | --- |
| `density` | Image density |
| `style_guide` | Visual style |
| `negative_prompt` | Negative prompt |
| `generation.model` | Generation model |
| `generation.aspect_ratio` | Aspect ratio |
| `generation.image_size` | Image size |
| `created_at` | Creation timestamp |
| `spec_version` | Spec version |

### Write Permissions

| Role | Permission | Description |
| --- | --- | --- |
| orchestrator | Bootstrap write | Creates initial lock in Step 1 |
| creative | Read-only | Reads parameters, never writes lock |
| render | Read-only | Reads parameters for execution, never modifies lock |

### Conflict Rule

- Parameter values confirmed via user interaction → cannot be overridden at any stage.

## Failure Handling

| Failure Point | Rollback Target | Action |
| --- | --- | --- |
| Gate 0 | Step 1 | Rebuild or clean lock file, re-execute Step 2 |
| Gate A | Step 3 | Creative fills in missing drafts, re-pass Gate A |
