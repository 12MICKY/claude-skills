---
name: nextjs-deployment
description: Use this skill for Next.js deployment — standalone output mode, Docker multi-stage builds, static asset directory gotcha (critical: static/static nesting), K3s deployment, PM2 process management, CI/CD with GitHub Actions, and environment variable handling. Activate for any Next.js build, deploy, or production server configuration.
---

# Next.js Deployment

## Standalone Output Mode

Add to `next.config.js`:
```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",
};

module.exports = nextConfig;
```

**Build output structure:**
```
.next/
  standalone/          ← self-contained Node.js server (includes node_modules)
    server.js          ← entry point
    node_modules/
  static/              ← static assets (CSS, JS chunks, images)
public/                ← public assets (favicon, robots.txt, etc.)
```

## Critical: Static Asset Directory Issue

**Problem:** When copying `standalone/` to a deploy target, you must manually copy `.next/static` and `public/` into the right locations. If you copy naively, Next.js looks for static files at `.next/static` but they land at `.next/static/static` — all JS/CSS returns 404.

**Wrong (creates static/static nesting):**
```bash
cp -r .next/standalone /deploy/
cp -r .next/static /deploy/.next/    # puts static inside .next/static/static!
```

**Correct:**
```bash
# Clean deploy first (avoid stale files from previous build)
rm -rf /deploy/.next/static /deploy/public

cp -r .next/standalone/. /deploy/
cp -r .next/static /deploy/.next/static     # exactly here
cp -r public /deploy/public
```

**Or use rsync for incremental deploys:**
```bash
rsync -av --delete .next/standalone/ /deploy/
rsync -av --delete .next/static/ /deploy/.next/static/
rsync -av --delete public/ /deploy/public/
```

## Docker Multi-Stage Build

```dockerfile
# Dockerfile
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --only=production

FROM node:22-alpine AS builder
WORKDIR /app
COPY . .
COPY --from=deps /app/node_modules ./node_modules
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# Copy standalone output
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

EXPOSE 3000
CMD ["node", "server.js"]
```

**.dockerignore:**
```
node_modules
.next
.git
*.env.local
```

**Build and push:**
```bash
docker build -t registry.local:5000/myapp:1.0.0 .
docker push registry.local:5000/myapp:1.0.0
```

## PM2 (Direct Server Deployment)

```bash
# Install PM2
npm install -g pm2

# Start
pm2 start .next/standalone/server.js --name myapp \
  --env production \
  -- --port 3000

# Or with ecosystem file:
```

```js
// ecosystem.config.js
module.exports = {
  apps: [{
    name: "myapp",
    script: ".next/standalone/server.js",
    env_production: {
      NODE_ENV: "production",
      PORT: 3000,
      HOSTNAME: "0.0.0.0",
    },
  }]
};
```

```bash
pm2 start ecosystem.config.js --env production
pm2 save
pm2 startup              # generate systemd unit for auto-start

# Operations
pm2 status
pm2 logs myapp --lines 100
pm2 reload myapp         # zero-downtime restart
pm2 restart myapp
```

## K3s Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: apps
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: registry.local:5000/myapp:1.0.0
        ports: [{containerPort: 3000}]
        env:
        - name: NODE_ENV
          value: production
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: myapp-secret
              key: DATABASE_URL
        - name: NEXTAUTH_SECRET
          valueFrom:
            secretKeyRef:
              name: myapp-secret
              key: NEXTAUTH_SECRET
        - name: NEXTAUTH_URL
          value: https://myapp.example.com
        readinessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-svc
  namespace: apps
spec:
  selector:
    app: myapp
  ports:
  - port: 3000
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: myapp
  namespace: apps
spec:
  entryPoints: [web]
  routes:
  - match: Host(`myapp.example.com`)
    kind: Rule
    services:
    - name: myapp-svc
      port: 3000
```

## Environment Variables

**Build-time (baked in):** `NEXT_PUBLIC_` prefix — exposed to browser. Set during `docker build`.

**Runtime (server-side only):** no prefix — read by `process.env` in server components/API routes. Set as container env vars, not at build time.

**`.env` hierarchy:**
```
.env                  # always loaded (default)
.env.local            # overrides .env, git-ignored
.env.production       # loaded in production only
.env.production.local # git-ignored production overrides
```

**Docker build-time ARGS:**
```dockerfile
ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
```
```bash
docker build --build-arg NEXT_PUBLIC_API_URL=https://api.example.com .
```

## GitHub Actions CI/CD

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: self-hosted    # your GitHub Actions runner
    steps:
    - uses: actions/checkout@v4

    - uses: actions/setup-node@v4
      with:
        node-version: 22
        cache: npm

    - run: npm ci
    - run: npm run build

    - name: Deploy to server
      run: |
        rsync -av --delete .next/standalone/ /deploy/myapp/
        rsync -av --delete .next/static/ /deploy/myapp/.next/static/
        rsync -av --delete public/ /deploy/myapp/public/
        pm2 reload myapp
```

**K3s deploy via kubectl:**
```yaml
    - name: Update image and rollout
      run: |
        docker build -t registry.local:5000/myapp:${{ github.sha }} .
        docker push registry.local:5000/myapp:${{ github.sha }}
        kubectl set image deployment/myapp myapp=registry.local:5000/myapp:${{ github.sha }} -n apps
        kubectl rollout status deployment/myapp -n apps
```

## Common Issues

| Problem | Cause | Fix |
|---|---|---|
| JS/CSS returns 404 | Static dir nesting (static/static) | Delete and re-copy `.next/static` to correct path |
| `NEXT_PUBLIC_*` is undefined at runtime | Set at runtime, not build time | Must be set during `npm run build` |
| `Module not found` in standalone | Dependency not in production deps | Move to `dependencies`, not `devDependencies` |
| `NEXTAUTH_URL` mismatch | Env var not set or wrong domain | Set to exact public URL including scheme |
| Image build slow | No build cache | Use `--cache-from` or GitHub Actions cache |
| PM2 restarts on deploy | Full restart not reload | Use `pm2 reload` for zero-downtime |
