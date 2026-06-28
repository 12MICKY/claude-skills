---
name: "pr-review"
description: "Review a GitHub PR or local diff and write structured review comments. Trigger for: /pr-review, review PR, review this diff, write review, code review PR #N. Reads changes, finds bugs/issues, posts inline comments via gh CLI or prints review."
---

# PR Review

Write a structured code review for a GitHub PR or the current branch diff.

## Invocation Forms
- `/pr-review` — review current branch diff vs main
- `/pr-review <PR#>` — review a specific GitHub PR
- `/pr-review <PR URL>` — review by URL

## Workflow

### 1. Get the diff
**If PR number/URL given:**
```bash
gh pr view <PR#> --json title,body,headRefName,baseRefName
gh pr diff <PR#>
gh pr view <PR#> --json files
```

**If no PR number (current branch):**
```bash
git diff main...HEAD
git log main...HEAD --oneline
```

### 2. Read changed files fully
For each changed file, read the full file (not just the diff hunk) to understand context — especially for:
- Security-sensitive code (auth, SQL, file paths, env vars)
- Public API surfaces
- Business logic

### 3. Categorize findings
Use these severity levels:

| Level | Label | Meaning |
|-------|-------|---------|
| 🔴 | **BLOCKER** | Bug, security hole, data loss risk — must fix before merge |
| 🟡 | **SUGGESTION** | Cleaner/safer approach, but not blocking |
| 🟢 | **NIT** | Style, naming, minor — optional |

### 4. Write the review

**Summary block (always first):**
```
## Review Summary
<1-2 sentence overall assessment>

**Verdict:** ✅ Approve / ⚠️ Request changes / 🔴 Block
```

**Per-finding format:**
```
### <file>:<line>
🔴 BLOCKER / 🟡 SUGGESTION / 🟢 NIT

**Issue:** <what's wrong>
**Why:** <why it matters>
**Fix:**
```<lang>
<corrected code>
```
```

### 5. Post or print
**If reviewing a GitHub PR:**
```bash
gh pr review <PR#> --comment --body "<review body>"
```
For inline comments on specific lines:
```bash
gh api repos/{owner}/{repo}/pulls/<PR#>/comments \
  -f body="<comment>" -f path="<file>" -f line=<N> -f side=RIGHT
```

**If reviewing local diff:** print the review to terminal only.

### 6. Output
- If posted: show PR URL + comment URL
- If printed: show full review, then one-line verdict
- No trailing recap

## What to look for

**Security (always check):**
- Unsanitized user input used in SQL, shell commands, file paths
- Hardcoded secrets, tokens, passwords
- Missing auth checks on new endpoints
- CORS, CSRF, XSS vectors in web code

**Correctness:**
- Off-by-one errors, null/undefined not handled
- Race conditions (async code, shared state)
- Wrong HTTP status codes
- Missing error handling at system boundaries (user input, external APIs)

**Maintainability (suggest, not block):**
- Function >50 lines that could be split
- Magic numbers without explanation
- Duplicate logic that could be shared
- Missing or misleading variable names

**Skip:**
- Style issues already handled by linter
- Hypothetical future requirements
- Commenting on code outside the diff
