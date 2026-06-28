---
name: "merge-pr"
description: "Merge a GitHub PR after checks pass. Trigger for: /merge-pr, merge PR, รวม PR, approve and merge, squash merge. Checks CI status, reviews approvals, then merges with correct strategy."
---

# Merge PR

Merge a GitHub PR safely after verifying CI and approvals.

## Invocation Forms
- `/merge-pr` — merge current branch's open PR
- `/merge-pr <PR#>` — merge specific PR
- `/merge-pr <PR#> --squash` — force squash merge

## Merge Strategy

| Branch type | Default strategy |
|-------------|-----------------|
| `feat/*` | squash |
| `fix/*` | squash |
| `hotfix/*` | merge commit (preserve history) |
| `release/*` | merge commit |
| `chore/*` | squash |

## Workflow

### 1. Get PR status
```bash
gh pr view <PR#> --json state,mergeable,statusCheckRollup,reviews,title
```

### 2. Check gates
- CI: all required checks must be ✅ — if any ❌ STOP and report
- Approvals: at least 1 approval required
- Merge conflicts: `mergeable` must be `MERGEABLE`

### 3. Merge
```bash
# squash (default for feat/fix/chore)
gh pr merge <PR#> --squash --delete-branch

# merge commit (hotfix/release)
gh pr merge <PR#> --merge --delete-branch
```

### 4. Output
One line: PR #N merged → `main` via squash. Branch deleted.
