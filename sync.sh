#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"; }
log_error()   { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SRC="$HOME/.claude/skills"

if [ ! -d "$REPO_DIR" ]; then
    log_error "Repository directory not found!"
    exit 1
fi

if [ -d "$CLAUDE_SRC" ]; then
    log_info "Archiving Claude Code skills to skills.tar.gz..."
    tar -czf "$REPO_DIR/skills.tar.gz" -C "$HOME/.claude" skills
    log_success "Synchronized Claude Code skills to skills.tar.gz"
else
    log_error "Local Claude Code skills directory not found at $CLAUDE_SRC"
    exit 1
fi

cd "$REPO_DIR"
git add -A

if git diff --staged --quiet; then
    log_info "No changes detected. Repository is already up-to-date."
    exit 0
fi

COMMIT_MSG="auto-sync: $(date '+%Y-%m-%d %H:%M')"
log_info "Committing changes..."
git commit -m "$COMMIT_MSG"

log_info "Pushing updates to GitHub..."
if git push; then
    log_success "Successfully synchronized claude-skills to GitHub!"
else
    log_error "Failed to push updates to GitHub."
    exit 1
fi
