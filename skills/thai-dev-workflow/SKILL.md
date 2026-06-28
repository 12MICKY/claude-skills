---
name: thai-dev-workflow
description: Use this skill for the self-hosted infrastructure workflow — K3s-first deployment policy, Git workflow for solo and small teams, tech stack selection for homelab and small school/enterprise projects, monitoring strategy, backup policy, and service lifecycle (add/remove). Activate when planning a new service, choosing between deployment approaches, or managing the full lifecycle of a self-hosted application.
---

# Self-Hosted Infrastructure Workflow

## Deployment Policy

**K3s-first:** all user-facing services go into Kubernetes. No raw Docker containers on production nodes.

**Environment split:**
- **Production node** — K3s control-plane + user-facing services. No experiments. No untested code.
- **Dev node** — K3s worker (same cluster). Experiments, throwaway work, prototyping.

**Registry:** push all images to the private registry before deploying to K3s.

**Manifest location:** keep all K3s manifests in a version-controlled directory (`~/k3s-manifests/apps/`). Every service has its own manifest file.

## Adding a New Service — Standard Flow

```
1. Build Docker image
2. Push to private registry with versioned tag
3. Create K3s manifest (Deployment + Service + IngressRoute)
4. Apply manifest
5. Register domain via Cloudflare Tunnel
6. Verify service is accessible
```

**Step-by-step:**
```bash
# 1. Build and push
docker build -t registry.local:5000/myservice:1.0.0 .
docker push registry.local:5000/myservice:1.0.0

# 2. Create manifest
cat > ~/k3s-manifests/apps/myservice.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myservice
  namespace: apps
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myservice
  template:
    metadata:
      labels:
        app: myservice
    spec:
      containers:
      - name: myservice
        image: registry.local:5000/myservice:1.0.0
        ports:
        - containerPort: PORT
---
apiVersion: v1
kind: Service
metadata:
  name: myservice-svc
  namespace: apps
spec:
  selector:
    app: myservice
  ports:
  - port: PORT
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: myservice
  namespace: apps
spec:
  entryPoints: [web]
  routes:
  - match: Host(`myservice.example.com`)
    kind: Rule
    services:
    - name: myservice-svc
      port: PORT
EOF

# 3. Apply
kubectl apply -f ~/k3s-manifests/apps/myservice.yaml

# 4. Register Cloudflare Tunnel DNS + update ConfigMap
# Use the cloudflare-tunnel add-service script or manual edit
```

## Removing a Service — Complete Cleanup

```bash
# 1. Remove from K3s
kubectl delete -f ~/k3s-manifests/apps/myservice.yaml

# 2. Remove Cloudflare Tunnel ingress entry (edit ConfigMap)
kubectl edit cm cloudflared-config -n apps
# Remove the hostname/service block, keep catch-all at end
kubectl rollout restart deployment/cloudflared -n apps

# 3. Remove DNS record (Cloudflare dashboard or API)

# 4. Remove Docker image from registry
curl -X DELETE http://registry.local:5000/v2/myservice/manifests/DIGEST

# 5. Delete manifest file
rm ~/k3s-manifests/apps/myservice.yaml
git -C ~/k3s-manifests commit -am "remove: myservice"
```

## Git Workflow (Solo / Small Team)

**Branch strategy:**
- `main` — always deployable. CI/CD deploys from here.
- Feature branches for anything taking >1 commit to complete.
- Direct push to main for small fixes (hotfix pattern).

**Commit discipline:**
- One logical change per commit.
- Message: `type: brief description` — types: `feat`, `fix`, `chore`, `docs`, `refactor`, `security`.
- Never amend pushed commits. Create new commits instead.

**Tagging releases:**
```bash
git tag -a v1.0.0 -m "First production release"
git push origin v1.0.0
```

**GitHub Actions runners:** self-hosted runners on production node for deployments. Labels separate runners by purpose (e.g., `node-prod-web`, `node-prod-bot`).

## Tech Stack Selection Guide

**Web app (full-stack):**
- Next.js + TypeScript + PostgreSQL — best default. SSR + API routes + type safety.
- FastAPI + React — when Python ecosystem needed (ML, data processing, bots).
- Go + HTMX — when minimal JS and high performance required.

**Bot / automation:**
- Python — Telegram bots, Discord bots, data pipelines. Rich library ecosystem.
- Node.js — Discord.js, lightweight webhooks.

**Database:**
- PostgreSQL — default for relational data. Never MySQL for new projects.
- Redis — session cache, job queues, pub/sub. Not primary storage.
- SQLite — scripts, small tools, dev-only. Not production web apps.

**Containerization:**
- Docker + K3s — all production services.
- Docker Compose — local development only.

**When NOT to use K3s:**
- One-shot scripts.
- Development tools running locally.
- Simple cron jobs that run on the server (use systemd timers instead).

## Monitoring Strategy

**Three pillars:**
1. **Metrics** — Prometheus + Grafana. Node CPU/memory/disk + service-specific metrics.
2. **Logs** — journald for systemd services + Grafana Loki for container logs.
3. **Uptime** — Blackbox Exporter probing public endpoints + alert on `probe_success == 0`.

**Alert thresholds (starting points):**
- CPU > 85% for 5 min → warning.
- Disk > 90% → critical.
- Node down for 2 min → critical.
- Service HTTP 5xx rate > 5% → warning.

**Dashboard IDs for Grafana import:**
- `1860` — Node Exporter Full.
- `7587` — Blackbox Exporter.
- `13659` — WireGuard peers.

## Backup Policy

**What to back up:**
- K3s PVC data (PersistentVolumeClaims) → PVE PBS daily.
- PostgreSQL databases → `pg_dump` + upload to NAS.
- K3s manifests directory → GitHub private repo.
- Config secrets → 1Password / encrypted offline backup.

**What NOT to back up:**
- Docker images — rebuild from source.
- Node ephemeral data — stateless by design.
- Logs older than 30 days (unless compliance requires it).

**Backup schedule:**
```bash
# Daily Postgres dump (systemd timer)
pg_dump mydb | gzip > /backup/mydb-$(date +%Y%m%d).sql.gz
find /backup -name "*.sql.gz" -mtime +7 -delete   # keep 7 days
```

## Service Lifecycle Checklist

**Before deploying new service:**
- [ ] Docker image builds and runs locally.
- [ ] Environment variables documented.
- [ ] Health check endpoint exists (`/health` returning 200).
- [ ] Resource requests/limits set in K3s manifest.
- [ ] Persistent storage needed? PVC created?
- [ ] Secrets in K3s Secret, not ConfigMap.
- [ ] Domain registered in Cloudflare Tunnel config.

**Before removing a service:**
- [ ] Confirm no other service depends on it.
- [ ] Data backed up if needed.
- [ ] Users notified if public-facing.
- [ ] All 5 removal steps completed (K3s + tunnel + DNS + image + manifest).

## SSH and Remote Operations Pattern

**SSH to server:**
```bash
ssh -o StrictHostKeyChecking=no user@SERVER_IP
```

**Run command without interactive shell:**
```bash
ssh user@SERVER_IP "kubectl get pods -n apps"
```

**Copy files:**
```bash
scp -o StrictHostKeyChecking=no local-file.txt user@SERVER_IP:/remote/path/
```

**Best practice:** use SSH keys, never passwords for automation. Store runner SSH keys as GitHub Actions secrets.
