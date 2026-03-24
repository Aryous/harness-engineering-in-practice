#!/usr/bin/env bash
# sync.sh — Rebuild INDEX.md + refresh todo-ai.md snapshot
# ~/.claude/memories/ is symlinked to Obsidian vault — no rsync needed

SCRIPTS_DIR="$(dirname "$0")"

python3 "$SCRIPTS_DIR/generate_index.py"
python3 "$SCRIPTS_DIR/scan_todos.py"
