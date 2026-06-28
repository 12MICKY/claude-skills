---
name: "open-pr"
description: "Create a GitHub Pull Request for the current branch. Trigger for: /open-pr, create PR, open pull request, push and PR, submit PR. Gathers diff summary, writes title+body, pushes branch, opens PR via gh CLI."
---

# Open PR

Create a GitHub Pull Request from the current branch with a well-structured title and body.

## Workflow

### 1. Gather context (run in parallel)
- `git status` — check for uncommitted changes (warn if dirty)
- `git branch --show-current` — current branch name
- `git log main...HEAD --oneline` (or master) — commits on this branch
- `git diff main...HEAD --stat` — files changed
- `git remote get-url origin` — repo URL

### 2. Read the diff
- `git diff main...HEAD` — full diff to understand what changed
- If diff is large (>300 lines), read `--stat` only and focus on commit messages

### 3. Determine base branch
- Default: `main`
- If `main` doesn't exist, try `master`
- If user specifies a base branch, use that

### 4. Push branch if needed
```bash
git push -u origin <branch>
```
Check if remote branch exists first with `git ls-remote --heads origin <branch>`.

### 5. Draft PR title and body
**Title rules:**
- Max 70 characters
- Format: `<type>: <what changed>` — type = feat / fix / refactor / chore / docs
- Translate any non-English branch names to an English title

**Body template:**
```markdown
## Summary
- <bullet 1>
- <bullet 2>

## Changes
- <key file or component>: <what changed>

## Test plan
- [ ] <test step 1>
- [ ] <test step 2>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### 6. Create PR
```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

### 7. Output
Return the PR URL only. No recap.

## Edge Cases
- **Uncommitted changes**: warn and ask if user wants to commit first, or proceed with existing commits
- **No commits ahead of main**: tell the user — nothing to PR
- **gh not authenticated**: suggest `gh auth login`
- **Branch already has open PR**: show existing PR URL instead of creating duplicate
