---
name: "open-pr"
description: "Create a GitHub Pull Request for the current branch. Trigger for: /open-pr, create PR, open pull request, push and PR, submit PR. Gathers diff summary, writes title+body, pushes branch, opens PR via gh CLI."
---

# Open PR

Push the current branch and open a well-structured GitHub Pull Request. After this, use `/pr-review` or `/merge-pr`.

## Invocation Forms
- `/open-pr` — PR from current branch to default base
- `/open-pr --draft` — open as draft PR
- `/open-pr --base <branch>` — override base branch
- `/open-pr --reviewer <handle>` — request a reviewer

## Workflow

### 0. Prerequisites
```bash
gh auth status    # must be authenticated
git status        # check for uncommitted changes
```
If there are uncommitted changes: warn and ask whether to commit them first or proceed with existing commits only.

### 1. Detect base branch
```bash
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|.*/||')
# If that fails, fallback:
BASE=${BASE:-$(git branch -r | grep -E 'origin/(main|master)' | head -1 | sed 's|.*/||')}
BASE=${BASE:-main}
echo "Base branch: $BASE"
```

### 2. Gather context (run in parallel)
```bash
git branch --show-current                    # current branch name
git log $BASE...HEAD --oneline               # commits on this branch
git diff $BASE...HEAD --stat                 # files changed summary
git remote get-url origin                    # repo URL (to resolve owner/repo)
```

If `git log` returns nothing → STOP: "No commits ahead of $BASE — nothing to PR."

### 3. Check for existing PR
```bash
gh pr list --head $(git branch --show-current) --json url --jq '.[0].url'
```
If a PR already exists → show its URL, do not create a duplicate.

### 4. Read the diff
```bash
git diff $BASE...HEAD
```
If diff >300 lines: read `--stat` + commit messages only to infer intent.

### 5. Draft PR title and body

**Title rules:**
- Max 70 characters
- Format: `<type>: <concise description>`
- Types: `feat` / `fix` / `refactor` / `chore` / `docs` / `hotfix`
- Infer type from branch name prefix

**Body template:**
```markdown
## Summary
- <what this PR does — 1-3 bullets>

## Changes
- `<file or module>`: <what changed and why>

## Test plan
- [ ] <manual test step>
- [ ] <edge case to verify>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### 6. Push branch
```bash
# Check if remote branch exists
git ls-remote --heads origin $(git branch --show-current) | grep -q . \
  && echo "already pushed" \
  || git push -u origin $(git branch --show-current)
```

### 7. Create PR
```bash
gh pr create \
  --title "<title>" \
  --body "$(cat <<'EOF'
<body>
EOF
)" \
  --base "$BASE" \
  ${DRAFT:+--draft} \
  ${REVIEWER:+--reviewer "$REVIEWER"}
```

### 8. Output
PR URL only. No recap.

## Edge Cases
- **Uncommitted changes**: warn — ask commit first or skip
- **No commits ahead of base**: STOP — nothing to PR
- **gh not authenticated**: suggest `gh auth login`
- **Existing open PR**: show URL, do not duplicate
- **Draft flag**: pass `--draft` to `gh pr create`
- **Force-pushed branch**: `git push -u origin <branch> --force-with-lease` (safer than --force)
