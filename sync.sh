#!/usr/bin/env bash
# Sync skills from this repo's skills/ directory into ~/.claude/skills/
# Only syncs skills that exist in this repo — does not touch other installed skills.
set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_ok()    { printf "${GREEN}[OK]${NC}   %s\n" "$1"; }
log_info()  { printf "${BLUE}[--]${NC}   %s\n" "$1"; }
log_error() { printf "${RED}[ERR]${NC}  %s\n" "$1" >&2; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
CLAUDE_DST="$HOME/.claude/skills"

if [ ! -d "$SKILLS_SRC" ]; then
  log_error "skills/ directory not found"
  exit 1
fi

mkdir -p "$CLAUDE_DST"

synced=0
for skill_dir in "$SKILLS_SRC"/*/; do
  name="$(basename "$skill_dir")"
  if [ -f "$skill_dir/SKILL.md" ]; then
    rm -rf "$CLAUDE_DST/$name"
    cp -r "$skill_dir" "$CLAUDE_DST/$name"
    log_ok "$name"
    synced=$((synced + 1))
  fi
done

printf "\n${GREEN}Synced $synced skills to $CLAUDE_DST${NC}\n"
