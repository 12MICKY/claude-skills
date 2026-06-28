---
name: "pr-review"
description: "Review a GitHub PR or local diff and write structured review comments. Trigger for: /pr-review, review PR, review this diff, write review, code review PR #N. Reads changes, finds bugs/issues, posts inline comments via gh CLI or prints review."
---

# PR Review

Write a structured code review for a GitHub PR or the current branch diff. After this, use `/merge-pr` to ship.

## Invocation Forms
- `/pr-review` — review current branch diff vs base
- `/pr-review <PR#>` — review a specific GitHub PR
- `/pr-review <PR URL>` — review by full URL

## Severity Levels

| Icon | Label | Meaning | Blocks merge? |
|------|-------|---------|---------------|
| 🔴 | **BLOCKER** | Bug, security hole, data loss risk | Yes |
| 🟡 | **SUGGESTION** | Cleaner/safer approach | No |
| 🟢 | **NIT** | Style, naming, minor polish | No |

## Workflow

### 1. Get the diff

**GitHub PR:**
```bash
gh pr view <PR#> --json title,body,headRefName,baseRefName,author,isDraft
gh pr diff <PR#>
gh pr view <PR#> --json files --jq '[.files[].path]'
```
If PR is a draft: note it in the summary but still review.

**Local diff (no PR#):**
```bash
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|.*/||' || echo main)
git diff $BASE...HEAD
git log $BASE...HEAD --oneline
```

### 2. Read changed files in full
For each changed file, read the complete file — not just the diff hunk.
Context outside the hunk often reveals the real impact of a change.

Prioritize full reads for:
- Auth, session, permission logic
- Database queries and migrations
- Public API handlers
- Config and environment loading

### 3. Write findings

**Review structure:**
```markdown
## Review Summary
<1-2 sentence overall assessment>

**Verdict:** ✅ Approve / ⚠️ Request changes / 🔴 Block

---

### <file>:<line>
🔴 BLOCKER / 🟡 SUGGESTION / 🟢 NIT

**Issue:** <what is wrong>
**Why:** <why it matters>
**Fix:**
```lang
<corrected snippet>
```

---
```

### 4. Post or print

**GitHub PR — post comment:**
```bash
gh pr review <PR#> --comment --body "$(cat <<'EOF'
<full review>
EOF
)"
```

**Inline comment on a specific line:**
```bash
gh api repos/{owner}/{repo}/pulls/<PR#>/comments \
  -f body="<comment>" \
  -f path="<file>" \
  -f line=<N> \
  -f side=RIGHT \
  -f commit_id=$(gh pr view <PR#> --json headRefOid --jq '.headRefOid')
```

**Local diff — print only** (no GitHub post).

### 5. Output
- GitHub PR: PR URL + review URL
- Local: full review printed, then one-line verdict

---

## What to Check

### Security (always — every PR)
- User input used in SQL queries without parameterization
- User input used in shell commands (`exec`, `subprocess`, `os.system`)
- Hardcoded secrets, API keys, passwords in any file including tests
- Missing authentication/authorization checks on new routes or handlers
- File path traversal (`../` in user-controlled paths)
- XSS: unsanitized output in HTML templates
- CORS/CSRF misconfiguration on new endpoints
- Insecure deserialization (pickle, eval, JSON with prototype pollution)

### Correctness
- Off-by-one in loops, slice indices, pagination
- Null / nil / undefined not handled before use
- Async bugs: missing `await`, race condition on shared state
- Wrong HTTP status codes (e.g. 200 on error, 404 vs 400)
- Error swallowed silently (`catch {}`, `_ = err`)
- Wrong comparison operator (`=` vs `==`, `==` vs `===`)

### Language-specific

**JavaScript / TypeScript:**
- `== null` vs `=== null` (use `== null` to catch both null and undefined)
- `any` type that bypasses TypeScript safety
- Unhandled promise rejections
- `console.log` left in production code

**Python:**
- Mutable default argument `def f(x=[]):`
- Bare `except:` that swallows all errors
- `assert` used for input validation (stripped by `-O` flag)
- `eval()` / `exec()` on any external input

**Go:**
- `err` returned but not checked
- `defer` inside a loop (runs at function exit, not loop iteration)
- Nil pointer dereference on pointer receivers
- Goroutine leak (goroutine started but never stops)

### Maintainability (suggest, not block)
- Function longer than ~50 lines with multiple responsibilities
- Magic numbers/strings without a named constant
- Copy-pasted logic that could be a shared function
- Variable name that requires reading the whole function to understand

### Skip
- Style issues covered by the project linter
- Hypothetical future requirements not in scope
- Code outside the diff
