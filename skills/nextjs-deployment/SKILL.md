---
name: nextjs-deployment
description: Use this skill for Next.js deployment — standalone output mode, Docker containerization, K3s/Kubernetes deploy, static asset directory structure gotchas, environment variables at build vs runtime, PM2 process management, and GitHub Actions CI/CD. Activate when deploying Next.js apps to self-hosted infrastructure.
---

# Next.js Deployment

## Standalone Output Mode

Enable in `next.config.js` to produce a self-contained build:

```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",
};
module.exports = nextConfig;
```

`next build` produces:
```
.next/
├── standalone/          # self-contained Node.js server
│   ├── server.js        # entry point
│   ├── node_modules/    # only production deps
│   └── .next/           # server-side bundle
└── static/              # public static assets (NOT inside standalone)
```

**Critical:** `.next/static/` and `public/` are NOT included in `standalone/`. You must copy them manually.

## Dockerfile (Standalone)

```dockerfile
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

# Copy standalone server
COPY --from=builder /app/.next/standalone ./

# Copy static assets (REQUIRED — not included in standalone)
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

EXPOSE 3000
CMD ["node", "server.js"]
```

## Static Asset Gotcha (CT/VM Deploy Without Docker)

When copying build output manually, the nesting structure must be exact:

```bash
# WRONG — creates .next/static/static/ (double nesting → JS 404)
cp -r .next/static /app/.next/

# CORRECT — clean copy
rm -rf /app/.next/static /app/public
cp -r .next/static /app/.next/static
cp -r public /app/public
```

**Script for clean deploy to remote server:**
```bash
#!/bin/bash
SERVER="user@10.0.0.10"
APP_DIR="/opt/myapp"
NEXT_DIR="$APP_DIR/.next"

npm run build

# Clear old static assets first
ssh "$SERVER" "rm -rf $NEXT_DIR/static $APP_DIR/public"

# Copy standalone (rsync preserves structure)
rsync -a --delete .next/standalone/ "$SERVER:$APP_DIR/"

# Copy static assets to correct positions
rsync -a .next/static/ "$SERVER:$NEXT_DIR/static/"
rsync -a public/ "$SERVER:$APP_DIR/public/"

ssh "$SERVER" "cd $APP_DIR && pm2 restart myapp"
```

## Environment Variables

**Build-time vs runtime:**
- `NEXT_PUBLIC_*` — embedded at build time (visible in browser bundle). Must be set during `npm run build`.
- Server-only env vars — read at runtime from `process.env`. Set in `.env.production` or container env.

```bash
# .env.production (on server, gitignored)
DATABASE_URL=postgresql://...
API_SECRET=...

# .env.local (local dev, gitignored)
NEXT_PUBLIC_API_URL=http://localhost:3000
```

**In Docker/K3s:** pass via Secret, not build args:
```yaml
envFrom:
  - secretRef:
      name: myapp-secret
```

`NEXT_PUBLIC_*` vars in K3s must be baked into the image at build time — they can't be injected at runtime. Build the image with the correct public URL.

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
          image: registry.example.com:5000/myapp:latest
          ports:
            - containerPort: 3000
          env:
            - name: PORT
              value: "3000"
            - name: HOSTNAME
              value: "0.0.0.0"
          envFrom:
            - secretRef:
                name: myapp-secret
          readinessProbe:
            httpGet:
              path: /api/health
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: apps
spec:
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 3000
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: myapp
  namespace: apps
spec:
  entryPoints: [web, websecure]
  routes:
    - match: Host(`myapp.example.com`)
      kind: Rule
      services:
        - name: myapp
          port: 80
```

## PM2 (Direct Node.js on Server)

```bash
# Install
npm install -g pm2

# Start (standalone mode)
pm2 start /opt/myapp/server.js --name myapp \
  --env production \
  --max-memory-restart 512M

# ecosystem.config.js (preferred)
module.exports = {
  apps: [{
    name: "myapp",
    script: "/opt/myapp/server.js",
    env_production: {
      NODE_ENV: "production",
      PORT: 3000,
    },
    max_memory_restart: "512M",
    instances: 1,     # or "max" for cluster mode
    exec_mode: "fork",
  }]
}

pm2 start ecosystem.config.js --env production
pm2 save              # persist across reboots
pm2 startup           # generate systemd unit
```

**Restart after deploy:**
```bash
pm2 reload myapp      # zero-downtime reload (cluster mode)
pm2 restart myapp     # hard restart (brief downtime)
```

## GitHub Actions CI/CD

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  build-and-push:
    runs-on: self-hosted   # or ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build and push Docker image
        run: |
          docker build \
            --build-arg NEXT_PUBLIC_API_URL=${{ vars.API_URL }} \
            -t registry.example.com:5000/myapp:${{ github.sha }} \
            -t registry.example.com:5000/myapp:latest .
          docker push registry.example.com:5000/myapp:${{ github.sha }}
          docker push registry.example.com:5000/myapp:latest

  deploy:
    needs: build-and-push
    runs-on: self-hosted
    steps:
      - name: Deploy to K3s
        run: |
          kubectl set image deployment/myapp \
            myapp=registry.example.com:5000/myapp:${{ github.sha }} \
            -n apps
          kubectl rollout status deployment/myapp -n apps
```

## Performance

**Image optimization:** use `next/image` with proper `sizes` attribute. Set `unoptimized: true` only for static export.

**Bundle analysis:**
```bash
ANALYZE=true npm run build
# requires @next/bundle-analyzer in next.config.js
```

**Caching headers for static assets** (via Traefik middleware or nginx in front):
```yaml
# Traefik middleware
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: static-cache
spec:
  headers:
    customResponseHeaders:
      Cache-Control: "public, max-age=31536000, immutable"
```
Apply to `/_next/static/*` routes only — Next.js content-hashes these files so immutable cache is safe.

## Common Issues

| Problem | Fix |
|---|---|
| JS 404 (`/_next/static/chunks/...`) | Static assets not copied or double-nested — check `.next/static/` path |
| `NEXT_PUBLIC_*` wrong in production | Rebuild image with correct env — these are baked at build time |
| Pod `CrashLoopBackOff` | `HOSTNAME=0.0.0.0` missing in env — Next.js standalone binds to localhost by default |
| Images not loading | `next/image` domains not in `next.config.js` `images.remotePatterns` |
| Memory OOM in K8s | Set `limits.memory`, enable `--max-old-space-size` in NODE_OPTIONS |
| Build slow in CI | Cache `node_modules` and `.next/cache` between runs (actions/cache) |
| Auth cookies missing cross-domain | `sameSite: none; secure` required for cross-origin cookies |
