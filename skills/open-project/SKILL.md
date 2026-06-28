---
name: open-project
description: Initialize a new code project with proper structure, git, and GitHub repo. Trigger for: /open-project, init project, new project, bootstrap project, create project, start project. Creates directory structure, git init, optional GitHub repo.
---

# Open Project

Bootstrap a new project with production-ready structure. After this, use `/create-branch` to start work.

## Invocation Forms
- `/open-project` — ask name then stack
- `/open-project <name>` — ask stack only
- `/open-project <name> <stack>` — go directly

## Supported Stacks

| Stack | Creates |
|-------|---------|
| `python` | `src/`, `tests/`, `requirements.txt`, `.env.example`, `Dockerfile` |
| `node` | `src/index.js`, `package.json`, `.env.example`, `Dockerfile` |
| `go` | `cmd/main.go`, `internal/`, `go.mod`, `Dockerfile` |
| `nextjs` | full Next.js app via `create-next-app` |
| `docker` | `docker-compose.yml` skeleton |
| `bare` | `git init` + `.gitignore` only |

## Workflow

### 0. Prerequisites
```bash
gh auth status          # must be logged in if creating GitHub repo
git config user.name    # must be set
git config user.email   # must be set
```

### 1. Clarify (one question max)
- If name unknown: ask name first
- If stack unknown: ask "Stack? (python / node / go / nextjs / docker / bare)"
- Never ask both at once

### 2. Create base structure
```bash
mkdir <name>
cd <name>
git init
```

**Universal `.gitignore`:**
```
.env
.env.local
.env.*.local
*.log
.DS_Store
Thumbs.db
```

Stack-specific additions to `.gitignore`:

| Stack | Add |
|-------|-----|
| python | `__pycache__/` `*.pyc` `.venv/` `dist/` `*.egg-info/` |
| node | `node_modules/` `dist/` `.next/` `coverage/` |
| go | `bin/` `dist/` `vendor/` |

### 3. Stack-specific files

**Python:**
```
src/<name>/__init__.py   (empty)
tests/__init__.py        (empty)
tests/test_main.py       (empty)
requirements.txt
.env.example
Dockerfile
```

`requirements.txt`:
```
# Add dependencies here
# Example: fastapi==0.115.0
```

`Dockerfile`:
```dockerfile
FROM python:3.13-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/ ./src/
RUN useradd -m appuser && chown -R appuser /app
USER appuser
CMD ["python", "-m", "src.<name>"]
```

---

**Node.js:**
```
src/index.js
package.json  (via npm init -y)
.env.example
Dockerfile
```

`src/index.js`:
```js
'use strict'

async function main() {
  console.log('<name> started')
}

main().catch(err => { console.error(err); process.exit(1) })
```

`Dockerfile`:
```dockerfile
FROM node:24-alpine
WORKDIR /app
COPY package*.json .
RUN npm ci --omit=dev
COPY src/ ./src/
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
CMD ["node", "src/index.js"]
```

---

**Go:**
```
cmd/<name>/main.go
internal/          (empty dir — add .gitkeep)
go.mod             (via go mod init)
Dockerfile
```

`cmd/<name>/main.go`:
```go
package main

import (
	"fmt"
	"os"
)

func main() {
	fmt.Println("<name> started")
	os.Exit(0)
}
```

`Dockerfile`:
```dockerfile
FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /bin/app ./cmd/<name>

FROM scratch
COPY --from=builder /bin/app /app
USER 65534
ENTRYPOINT ["/app"]
```

`go.mod`:
```
module github.com/12MICKY/<name>

go 1.24
```

---

**Next.js:**
```bash
npx create-next-app@latest <name> \
  --typescript --tailwind --app --no-src-dir --eslint
cd <name>
```
No manual files needed — `create-next-app` handles everything.

---

**Docker:**
```yaml
# docker-compose.yml
services:
  <name>:
    image: <name>:latest
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    volumes:
      - data:/app/data

volumes:
  data:

networks:
  default:
    name: <name>-network
```

---

**Bare:**
```bash
git init
# .gitignore with universal entries only
```

### 4. `.env.example`
```
# Copy to .env and fill in values
APP_PORT=3000
APP_ENV=development
# DATABASE_URL=postgres://user:pass@localhost:5432/dbname
# SECRET_KEY=changeme
```

### 5. Initial commit
```bash
git add .
git commit -m "chore: init <name> project"
```

### 6. GitHub repo
Ask: "Create a GitHub repo? (yes/no)"

If yes:
```bash
gh repo create 12MICKY/<name> --private --source=. --push
```
Default: **private**. Ask only if public is needed.

### 7. Output
```
Project: <name>  Stack: <stack>
Files:   <list of files created>
Repo:    https://github.com/12MICKY/<name>  (if created)
Next:    /create-branch feat/<first-feature>
```

## Hard Rules
- Never create `README.md` unless user asks
- Never add K3s/Swarm config — that is a deploy step
- Dockerfile always uses non-root user
- `.env.example` never contains real secrets
- Go module path always `github.com/12MICKY/<name>`
