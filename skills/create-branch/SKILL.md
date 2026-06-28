---
name: "create-branch"
description: "Create and switch to a new git branch with proper naming convention. Trigger for: /create-branch, new branch, create branch, checkout new branch, branch off. Infers branch type from context, names it correctly, and pushes if requested."
---

# Create Branch

Create and switch to a new git branch with consistent naming.

## Invocation Forms
- `/create-branch` — infer type+name from current context (recent changes, task description)
- `/create-branch <name>` — use given name (still apply prefix)
- `/create-branch <type> <description>` — explicit type + description

## Branch Naming Convention

Format: `<type>/<short-description>`
- Words separated by `-`, lowercase only
- Max 50 chars total
- No spaces, no non-ASCII characters in branch name

| Type | When |
|------|------|
| `feat/` | new feature |
| `fix/` | bug fix |
| `chore/` | tooling, deps, config |
| `refactor/` | code restructure, no behavior change |
| `docs/` | documentation only |
| `hotfix/` | urgent prod fix |
| `release/` | release prep |

**Examples:**
- `feat/user-auth-jwt`
- `fix/login-redirect-loop`
- `chore/update-dependencies`
- `hotfix/null-pointer-checkout`

## Workflow

### 1. Determine base branch
```bash
git branch --show-current   # where we are now
git log --oneline -5        # recent context
```
Default base: `main` (or `master` if `main` doesn't exist).
If user is already on a feature branch and wants a sub-branch, use current branch as base.

### 2. Infer name (if not given)
- Read recent git log and any uncommitted changes
- Infer intent from task/conversation context
- Propose one name, e.g. `feat/user-auth-jwt` — not a list

### 3. Check for conflicts
```bash
git branch --list "<name>"
git ls-remote --heads origin "<name>"
```
If name exists locally or remotely → append `-v2` or suggest alternative.

### 4. Create and switch
```bash
git checkout -b <type>/<name>
```
Or if base branch is not current:
```bash
git checkout -b <type>/<name> <base>
```

### 5. Push (ask unless user said "push" or implied ready for PR)
Ask: "Push to remote?"

If yes:
```bash
git push -u origin <type>/<name>
```

### 6. Output
One line: branch name created + current status. No recap.
Example: `feat/payment-webhook` created from `main` — ready to code.
