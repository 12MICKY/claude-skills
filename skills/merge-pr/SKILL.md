---
name: "merge-pr"
description: "Merge a GitHub PR after all checks pass. Trigger for: /merge-pr, merge PR, approve and merge, squash merge, ship PR. Verifies CI, draft state, and approvals, then merges with the correct strategy based on branch type."
---

# Merge PR

Merge a GitHub PR safely after verifying CI, draft state, and approvals.

## Invocation Forms
- `/merge-pr` — merge current branch's open PR
- `/merge-pr <PR#>` — merge specific PR
- `/merge-pr <PR#> --squash` — force squash regardless of branch type
- `/merge-pr <PR#> --merge` — force merge commit regardless of branch type

## Merge Strategy

Default strategy is chosen by branch type. Use `--squash` or `--merge` to override.

| Branch type | Default strategy |
|-------------|-----------------|
| `feat/*` | squash |
| `fix/*` | squash |
| `chore/*` | squash |
| `refactor/*` | squash |
| `hotfix/*` | merge commit (preserve history) |
| `release/*` | merge commit |

## Workflow

### 1. Get PR info
```bash
gh pr view <PR#> --json state,isDraft,mergeable,statusCheckRollup,reviews,headRefName,title
```

### 2. Check gates (stop on any failure)

**Gate 1 — Not a draft:**
```bash
gh pr view <PR#> --json isDraft --jq '.isDraft'
# if true → STOP: "PR is still a draft — mark it ready first"
```

**Gate 2 — CI passing:**
```bash
gh pr view <PR#> --json statusCheckRollup \
  --jq '.statusCheckRollup // [] | .[] | select(.conclusion != "SUCCESS") | .name'
# if any result → STOP and list the failing checks
```

**Gate 3 — At least one approval:**
```bash
gh pr view <PR#> --json reviews --jq '[.reviews[] | select(.state=="APPROVED")] | length'
# if 0 → STOP: "No approvals yet"
```

**Gate 4 — No merge conflicts:**
```bash
gh pr view <PR#> --json mergeable --jq '.mergeable'
# if "CONFLICTING" → STOP: "PR has merge conflicts — resolve first"
```

### 3. Determine strategy
- If `--squash` flag given → squash
- If `--merge` flag given → merge commit
- Otherwise → use table above based on branch name

### 4. Merge
```bash
# Squash
gh pr merge <PR#> --squash --delete-branch

# Merge commit
gh pr merge <PR#> --merge --delete-branch
```

### 5. Output
One line: PR #N merged into `main` via squash/merge — branch deleted.
