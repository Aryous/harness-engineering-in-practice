---
name: memv2
description: >
  Classify, structure, and persist conversation knowledge.
  Explicit trigger: user says /mem.
  Implicit trigger: when conversation produces reusable methodology, clear decisions,
  or user mentions significant life events — proactively ask if they want to persist it.
---

# Knowledge Persistence Spec

## Philosophy

Records exist not to "miss nothing," but to **let your future self reactivate the thinking state of the present moment**.

## Record Types

| Type | When to Use | Spec File |
| --- | --- | --- |
| Snapshot | Preferences, inspiration, moments worth keeping | [references/snapshot.md](references/snapshot.md) |
| Archive | Structured output, methodology, decisions | [references/archive.md](references/archive.md) |
| Upgrade | Snapshot refined into reusable archive | [references/upgrade.md](references/upgrade.md) |
| Milestone | Life experiences that shape decision patterns | [references/milestone.md](references/milestone.md) |

## Record Flow

```
Snapshot → (validated) → Upgrade → Archive
Milestone (standalone, no flow)
```

## Decision Tree

- User shares preference/inspiration/unformed idea → Snapshot
- Produced structured methodology/decision/procedure → Archive
- User says "this really affected me" / mentions life turning point → Milestone
- Snapshot repeatedly referenced and now clear → Upgrade
- Uncertain → ask user: "Snapshot or archive?"

## Storage

`~/.claude/memories/` is a symlink pointing to the Obsidian vault's `memories/` directory.
Writing here writes to the vault — single source of truth, no sync needed.

## Execution Flow

**Write**
1. Determine record type, read the corresponding spec from references/
2. Write record file to `~/.claude/memories/{type}/`
3. Update PROFILE.md per [references/profile.md](references/profile.md); if any "current focus" entries are stale, note them for confirmation

**Refresh**
4. Rebuild INDEX.md and refresh todo snapshot:
   ```bash
   bash ~/.claude/skills/memv2/scripts/sync.sh
   ```

**Confirm**
5. Tell user: save path, content summary; if PROFILE has stale entries, list them and ask whether to remove
