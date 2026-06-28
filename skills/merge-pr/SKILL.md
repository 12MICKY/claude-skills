---
name: "merge-pr"
description: "Merge a GitHub PR after all checks pass. Trigger for: /merge-pr, merge PR, approve and merge, squash merge, ship PR. Verifies CI, draft state, and approvals, then merges with the correct strategy based on branch type."
---

# Merge PR

Safely merge a GitHub PR after verifying all gates. After this, use `/create-release` to ship a version.

## Invocation Forms
- `/merge-pr` — merge current branch's open PR
- `/merge-pr <PR#>` — merge a specific PR
- `/merge-pr <PR#> --squash` — force squash (overrides strategy table)
- `/merge-pr <PR#> --merge` — force merge commit (overrides strategy table)
- `/merge-pr <PR#> --rebase` — force rebase merge

## Merge Strategy

Default chosen by branch prefix. Flags override the table.

| Branch type | Default |
|-------------|---------|
| `feat/*` | squash |
| `fix/*` | squash |
| `chore/*` | squash |
| `refactor/*` | squash |
| `docs/*` | squash |
| `hotfix/*` | merge commit — preserve history for incident RCA |
| `release/*` | merge commit — keep release boundary visible |

## Workflow

### 1. Resolve PR number
```bash
# If no PR# given, find open PR for current branch
gh pr list --head $(git branch --show-current) --json number --jq '.[0].number'
```
If no PR found → STOP: "No open PR for this branch."

### 2. Fetch full PR state
```bash
gh pr view <PR#> --json \
  state,isDraft,mergeable,mergeStateStatus,\
  statusCheckRollup,reviews,headRefName,baseRefName,title
```

### 3. Run gates in order — stop on first failure

**Gate 1 — Not merged/closed:**
```bash
# state must be "OPEN"
# if MERGED → "Already merged."
# if CLOSED → "PR is closed — reopen it first."
```

**Gate 2 — Not a draft:**
```bash
gh pr view <PR#> --json isDraft --jq '.isDraft'
# if true → STOP: "PR is still a draft — mark it ready first."
```

**Gate 3 — CI passing:**
```bash
gh pr view <PR#> --json statusCheckRollup \
  --jq '.statusCheckRollup // [] | .[] | select(.conclusion != "SUCCESS") | "\(.name): \(.conclusion)"'
# if any output → STOP: list failing checks by name
# if statusCheckRollup is empty → no CI configured, proceed (warn once)
```

**Gate 4 — At least one approval:**
```bash
gh pr view <PR#> --json reviews \
  --jq '[.reviews[] | select(.state=="APPROVED")] | length'
# if 0 → STOP: "No approvals yet."
```

**Gate 5 — No merge conflicts:**
```bash
gh pr view <PR#> --json mergeable --jq '.mergeable'
# if "CONFLICTING" → STOP: "PR has merge conflicts — resolve and push."
# if "UNKNOWN" → wait a few seconds and retry once
```

### 4. Determine strategy
1. If `--squash` flag → squash
2. If `--merge` flag → merge commit
3. If `--rebase` flag → rebase
4. Else → look up branch prefix in strategy table

### 5. Merge
```bash
# Squash
gh pr merge <PR#> --squash --delete-branch

# Merge commit
gh pr merge <PR#> --merge --delete-branch

# Rebase
gh pr merge <PR#> --rebase --delete-branch
```

### 6. Verify
```bash
gh pr view <PR#> --json state --jq '.state'
# must return "MERGED"
```

### 7. Output
```
PR #<N> "<title>" merged into <base> via squash — branch deleted.
```
One line only.

## Post-merge hints
- If this was the last feature for a release → suggest `/create-release`
- If `hotfix/*` → remind to also merge into `develop` if it exists
