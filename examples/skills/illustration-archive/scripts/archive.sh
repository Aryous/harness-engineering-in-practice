#!/usr/bin/env bash
# illustration-archive.sh
# Archive imgs-spec/ to Resource/illustrations/<project>/, renaming with prefix
# Usage: ./archive.sh <article_path>
# Example: ./archive.sh "posts/2026-03-18-interview-presentation.md"

set -e

ARTICLE_PATH="$1"
VAULT="$VAULT"  # Set to your Obsidian vault path
IMGS_SPEC="$VAULT/imgs-spec"
RESOURCE_BASE="$VAULT/Resource/illustrations"

if [[ -z "$ARTICLE_PATH" ]]; then
  echo "Usage: $0 <article_path>"
  exit 1
fi

# Extract date and project name from article filename
# Expected format: YYYY-MM-DD-project-name.md
FILENAME=$(basename "$ARTICLE_PATH" .md)
DATE_RAW=$(echo "$FILENAME" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')
DATE=$(echo "$DATE_RAW" | tr -d '-')           # 20260318
PROJECT=$(echo "$FILENAME" | sed "s/^${DATE_RAW}-//")  # project-name

if [[ -z "$DATE" || -z "$PROJECT" ]]; then
  echo "Error: cannot extract date and project name from: $FILENAME"
  echo "  Expected format: YYYY-MM-DD-project-name.md"
  exit 1
fi

PREFIX="${DATE}-${PROJECT}"

echo "Project: $PROJECT"
echo "Date prefix: $DATE"
echo "File prefix: $PREFIX"
echo ""

# Create archive directories
mkdir -p "$RESOURCE_BASE/$PROJECT/images"
mkdir -p "$RESOURCE_BASE/$PROJECT/prompts"

# Count source files
IMG_COUNT=$(ls "$IMGS_SPEC"/*.jpg 2>/dev/null | wc -l | tr -d ' ')
MD_COUNT=$(ls "$IMGS_SPEC"/*.md 2>/dev/null | wc -l | tr -d ' ')
YAML_COUNT=$(ls "$IMGS_SPEC"/*.yaml 2>/dev/null | wc -l | tr -d ' ')
echo "Source: $IMG_COUNT images, $MD_COUNT prompts, $YAML_COUNT yaml"
echo ""

# Archive images (add prefix)
for f in "$IMGS_SPEC"/*.jpg; do
  [[ -e "$f" ]] || continue
  ORIG=$(basename "$f")
  cp "$f" "$RESOURCE_BASE/$PROJECT/images/${PREFIX}-${ORIG}"
done

# Archive prompt .md files (add prefix)
for f in "$IMGS_SPEC"/*.md; do
  [[ -e "$f" ]] || continue
  ORIG=$(basename "$f")
  cp "$f" "$RESOURCE_BASE/$PROJECT/prompts/${PREFIX}-${ORIG}"
done

# Archive yaml files (add prefix)
for f in "$IMGS_SPEC"/*.yaml; do
  [[ -e "$f" ]] || continue
  ORIG=$(basename "$f")
  cp "$f" "$RESOURCE_BASE/$PROJECT/prompts/${PREFIX}-${ORIG}"
done

# Output archived image filename list (for Claude to insert wikilink references)
echo "=== Archived images (for ![[]] references) ==="
ARCHIVED_IMGS=()
for f in "$RESOURCE_BASE/$PROJECT/images/"*.jpg; do
  [[ -e "$f" ]] || continue
  fname=$(basename "$f")
  echo "  $fname"
  ARCHIVED_IMGS+=("$fname")
done

echo ""
echo "Archive complete: $RESOURCE_BASE/$PROJECT/"
echo ""

# Clean imgs-spec/ (only after successful archive)
echo "Cleaning imgs-spec/..."
rm -f "$IMGS_SPEC"/*.jpg "$IMGS_SPEC"/*.md "$IMGS_SPEC"/*.yaml 2>/dev/null
echo "imgs-spec/ cleared"

echo ""
echo "Archived ${#ARCHIVED_IMGS[@]} images"
