---
name: create-branch
description: Create and switch to a new git branch with proper naming convention. Trigger for: /create-branch, new branch, create branch, checkout new branch, branch off. Infers branch type from context, names it correctly, and pushes if requested.
---

# Create Branch

Create and switch to a new git branch with consistent naming. After this, use `/open-pr` when ready.

## Invocation Forms
- `/create-branch` — infer type+name from context
- `/create-branch <name>` — apply correct prefix automatically
- `/create-branch <type> <description>` — fully explicit

## Branch Naming Convention

Format: `<type>/<short-description>`
- Lowercase, hyphen-separated words
- Max 50 chars total
- ASCII only — no spaces, special chars, or accents

| Type | When |
|------|------|
| `feat/` | new feature |
| `fix/` | bug fix |
| `chore/` | tooling, deps, CI, config |
| `refactor/` | restructure, no behavior change |
| `docs/` | documentation only |
| `hotfix/` | urgent production fix |
| `release/` | release preparation |

**Examples:**
- `feat/user-auth-jwt`
- `fix/login-redirect-loop`
- `chore/update-dependencies`
- `hotfix/null-pointer-checkout`
- `release/v1.2.0`

## Workflow

### 1. Check repo state
```bash
git status                  # must not be in detached HEAD
git branch --show-current   # current branch
git log --oneline -5        # recent context to infer intent
```

If detached HEAD → STOP: "Check out a branch first before branching off."

### 2. Fetch remote state
```bash
git fetch origin --prune 2>/dev/null || true
```
Always fetch before checking remote conflicts — avoids false "no conflict" on stale data.

### 3. Determine base branch
```bash
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|.*/||'
# fallback: git branch -r | grep -E 'origin/(main|master)' | head -1 | sed 's|.*/||'
```

### 4. Infer branch name (if not given)
- Read recent git log, staged/unstaged changes, conversation context
- Propose exactly one name — not a list
- Example: `Creating branch feat/user-auth-jwt from main — confirm?`

### 5. Check for name conflicts
```bash
git branch --list "<type>/<name>"
git ls-remote --heads origin "<type>/<name>" | grep -q . && echo "EXISTS"
```
If exists locally or remotely → append `-v2` or propose alternative.

### 6. Create and switch
```bash
# From current branch (most common)
git checkout -b <type>/<name>

# From a specific base
git checkout -b <type>/<name> <base>
```

### 7. Push to remote
Ask: "Push to remote now?" (skip if user already said push or implied PR readiness)

```bash
git push -u origin <type>/<name>
```

### 8. Output
One line only:
```
feat/user-auth-jwt created from main — ready to code.
```

## Edge Cases
- **Dirty working tree**: warn but do not block — uncommitted changes carry over to new branch
- **No remote**: skip remote conflict check and push offer
- **On a feature branch**: offer to branch from `main` or from current branch — one clear question
