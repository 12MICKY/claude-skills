---
name: "open-project"
description: "Initialize a new code project with proper structure, git, and GitHub repo. Trigger for: /open-project, init project, new project, bootstrap project, create project, start project. Creates directory structure, git init, optional GitHub repo."
---

# Open Project

Bootstrap a new project with the right structure for the chosen stack (Python / Node.js / Go / Next.js / Docker).

## Invocation Forms
- `/open-project` — interactive: ask name + stack
- `/open-project <name>` — infer stack from context or ask
- `/open-project <name> <stack>` — go directly

## Supported Stacks

| Stack | Structure created |
|-------|------------------|
| `python` | `src/`, `tests/`, `requirements.txt`, `.env.example`, `Dockerfile` |
| `node` | `src/`, `package.json`, `.env.example`, `Dockerfile` |
| `go` | `cmd/`, `internal/`, `go.mod`, `Dockerfile` |
| `nextjs` | `npx create-next-app` with app router |
| `docker` | `docker-compose.yml` + service skeleton |
| `bare` | Just `git init` + `.gitignore` |

## Workflow

### 1. Clarify (one question max)
If stack is unknown, ask: "Stack? (python / node / go / nextjs / docker / bare)"
If name is unknown, ask for name. Never ask both at once — name first.

### 2. Create directory & files

**All stacks — base files:**
```bash
mkdir <name> && cd <name>
git init
```

`.gitignore` — use GitHub's standard template for the stack + always add:
```
.env
*.env.local
__pycache__/
node_modules/
dist/
.DS_Store
```

**Python:**
```
<name>/
├── src/<name>/
│   └── __init__.py
├── tests/
│   └── __init__.py
├── requirements.txt
├── .env.example
├── Dockerfile
└── .gitignore
```

**Node.js:**
```bash
npm init -y
mkdir src
```
Files: `src/index.js`, `.env.example`, `Dockerfile` (node:24-alpine base)

**Go:**
```bash
go mod init github.com/12MICKY/<name>
mkdir -p cmd internal
```
Files: `cmd/main.go`, `Dockerfile` (golang:1.24-alpine builder + scratch final)

**Next.js:**
```bash
npx create-next-app@latest <name> --typescript --tailwind --app --no-src-dir
```

**Docker:**
```yaml
# docker-compose.yml skeleton with service + volume + network
```

### 3. Initial commit
```bash
git add .
git commit -m "chore: init <name> project"
```

### 4. GitHub repo (ask unless already specified)
Ask: "Create a GitHub repo? (yes/no)"

If yes:
```bash
gh repo create 12MICKY/<name> --private --source=. --push
```
Default: **private**. Ask if public is needed.

### 5. Output
- List of files created
- GitHub repo URL (if created)
- One-line next step hint: e.g. `cd <name> && npm install`

## Rules
- Never create `README.md` unless user asks
- Never add Docker config for K3s/Swarm by default — that is a deploy step, not init
- Dockerfile always uses non-root user
- `.env.example` has placeholder values, never real secrets
- Go module path always uses `github.com/12MICKY/<name>`
