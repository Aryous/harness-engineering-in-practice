---
name: illustration-archive
description: >
  Archive illustrations from imgs-spec/ to Resource/illustrations/
  and insert references into the target article.
  Triggers: (1) user says /archive-illustrations;
  (2) after illustration generation (layeraxis) completes;
  (3) imgs-spec/ contains unarchived images and prompts.
---

# Illustration Archive

Archive images and prompts from `imgs-spec/` to `Resource/illustrations/`,
insert Obsidian wikilink references into the target article,
then clean up `imgs-spec/`.

## Naming Convention

All archived files get a prefix to avoid cross-project filename collisions:

```
{date}{project-name}-{original-filename}
Example: 20260318-interview-presentation-00-cover.jpg
Article ref: ![[20260318-interview-presentation-00-cover.jpg]]
```

- **Date**: extracted from article filename (`YYYY-MM-DD` → `YYYYMMDD`)
- **Project name**: article filename minus the date prefix and `.md` extension
- Obsidian matches wikilinks by filename globally — folder location doesn't matter

## Execution Flow

### Step 1 [Script] Archive + Clean

```bash
~/.claude/skills/illustration-archive/scripts/archive.sh "<article_full_path>"
```

Script does: create archive dirs → copy with prefix to `images/` and `prompts/` → output image filename list → clean `imgs-spec/`.

### Step 2 [Claude] Build Insertion Map

- Read target article, extract existing `![[]]` references (skip these — don't duplicate)
- Read article `##` heading list
- Match script output filenames against the table below to determine insertion points

| Type | Pattern | Insert Position |
|---|---|---|
| Cover/transition | `00-*`, `*-transition`, `*-toc` | New `## Cover` section at article top |
| Main | `NN-*` (numeric prefix, no `b`) | Semantic match to corresponding section, before `---` |
| Variant | `*-v2`, `*-alt`, `NNb-*` | Immediately after same-numbered main image |

Semantic matching: compare image filename keywords with section headings to find the best fit.

### Step 3 [Claude] Insert References + Verify

- Insert using archived full filename: `![[{prefix}-{original-filename}]]`
- After insertion, confirm: total `![[]]` count in article ≥ this batch's image count

## Common Issues

**Article filename has no date prefix** → script errors out. Manually provide date and project name, then rerun.

**imgs-spec/ contains files from other batches** → clean unrelated files before archiving.
