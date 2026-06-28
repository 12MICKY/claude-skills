#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

log_info()    { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"; }
log_error()   { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

printf "${BLUE}${BOLD}===================================================\n"
printf "        CLAUDE SKILLS ENVIRONMENT BOOTSTRAP        \n"
printf "===================================================\n${NC}\n"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DST="$HOME/.claude"

log_info "Synchronizing custom skills to Claude Code..."
if [ -f "$REPO_DIR/skills.tar.gz" ]; then
    mkdir -p "$CLAUDE_DST"
    rm -rf "$CLAUDE_DST/skills"
    tar -xzf "$REPO_DIR/skills.tar.gz" -C "$CLAUDE_DST/"
    log_success "Skills successfully unpacked to $CLAUDE_DST/skills"
else
    log_error "skills.tar.gz not found!"
    exit 1
fi

printf "\n${GREEN}${BOLD}Setup completed successfully!${NC}\n"
