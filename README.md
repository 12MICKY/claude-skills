# claude-skills

Custom Claude Code skills for the GitHub workflow.

## Skills

| Skill | Command | Description |
|-------|---------|-------------|
| **open-project** | `/open-project <name> <stack>` | Bootstrap a new project — creates directory structure, git init, optional GitHub repo |
| **create-branch** | `/create-branch <type> <desc>` | Create a git branch with correct `feat/fix/chore/hotfix` naming |
| **open-pr** | `/open-pr` | Push current branch and open a GitHub PR with structured title + body |
| **pr-review** | `/pr-review [PR#]` | Review a PR or local diff — posts findings as 🔴 BLOCKER / 🟡 SUGGESTION / 🟢 NIT |
| **merge-pr** | `/merge-pr [PR#]` | Merge a PR after verifying CI, draft state, and approvals |
| **create-release** | `/create-release [version]` | Bump semver, generate changelog from commits, tag and publish a GitHub Release |

## Install

Copy any skill folder into `~/.claude/skills/`:

```bash
cp -r skills/open-pr ~/.claude/skills/
```

Or clone and symlink the whole set:

```bash
git clone https://github.com/12MICKY/claude-skills.git ~/claude-skills
for skill in ~/claude-skills/skills/*/; do
  ln -sf "$skill" ~/.claude/skills/"$(basename "$skill")"
done
```

## Workflow order

```
open-project → create-branch → (code) → open-pr → pr-review → merge-pr → create-release
```
