# Pipeline Gates (LayerAxis V4 Flow)

## Gate 0

Before creative phase:
- `imgs-spec/plan.lock.yaml` exists.
- `plan.lock.yaml` only contains approved keys:
  - `density`
  - `style_guide`
  - `negative_prompt`
  - `generation.model`
  - `generation.aspect_ratio`
  - `generation.image_size`
  - `created_at`
  - `spec_version`
- `plan.lock.yaml` value domains are valid:
  - `density` is one of: `minimal` / `standard` / `full`
  - `generation.aspect_ratio` is one of: `1:1` / `3:4` / `4:3` / `9:16` / `16:9`
  - `generation.image_size` is one of: `1K` / `2K` / `4K`
  - `generation.model` is a non-empty string

## Gate A

Before compiler phase:
- `imgs-spec/creative-draft.md` exists and is non-empty.

## Gate B

Before render phase:
- `imgs-spec/plan.lock.yaml` exists.
- `imgs-spec/plan.lock.yaml` contains no unknown fields.
- `imgs-spec/outline.md` exists.
- at least one `imgs-spec/NN-*.md` exists.
- each `NN-*.md` has non-empty `## English Prompt`.

## Review Mode

If `imgs-spec/review-feedback.yaml` exists in review mode:
- send feedback back to creative phase first
- re-run compiler after creative rewrite
