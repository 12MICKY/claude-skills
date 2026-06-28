#!/usr/bin/env bash
set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

log_ok()    { printf "${GREEN}[OK]${NC}   %s\n" "$1"; }
log_error() { printf "${RED}[ERR]${NC}  %s\n" "$1" >&2; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
CLAUDE_DST="$HOME/.claude/skills"

printf "${BLUE}${BOLD}================================\n"
printf "  Claude Skills — Install\n"
printf "================================${NC}\n\n"

if [ ! -d "$SKILLS_SRC" ]; then
  log_error "skills/ directory not found in $REPO_DIR"
  exit 1
fi

mkdir -p "$CLAUDE_DST"

shopt -s nullglob
installed=0
for skill_dir in "$SKILLS_SRC"/*/; do
  name="$(basename "$skill_dir")"
  if [ -f "$skill_dir/SKILL.md" ]; then
    rm -rf "${CLAUDE_DST:?}/$name"
    cp -r "$skill_dir" "$CLAUDE_DST/$name"
    log_ok "$name"
    installed=$((installed + 1))
  fi
done
shopt -u nullglob

printf "\n${GREEN}${BOLD}Installed %d skills to %s${NC}\n" "$installed" "$CLAUDE_DST"
printf "Skills are active immediately — no Claude Code restart needed.\n"
