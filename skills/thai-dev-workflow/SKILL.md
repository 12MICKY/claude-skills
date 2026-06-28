---
name: thai-dev-workflow
description: Use this skill for Thai developer workflow patterns — self-hosted homelab infrastructure, Cloudflare zero-trust for public services, K3s-first deployment policy, Git branching for solo projects, and pragmatic tool selection for resource-constrained environments. Activate when making architecture or deployment decisions for personal or small-team projects.
---

# Thai Dev Workflow

Pragmatic patterns for solo or small-team developers running self-hosted infrastructure with limited budget and full control of the stack.

## Infrastructure Philosophy

**Two-tier server policy:**
- **Production node:** user-facing services only. No experiments, no untested code. All services in K3s (not raw Docker). Manifests in git.
- **Dev node:** same cluster but experiments, throwaway builds, untested code OK.

**Cloudflare Tunnel over port forwarding:** zero open ports on production server. Tunnel outbound connection handles everything. Works behind CGNAT and ISP restrictions.

**K3s over full Kubernetes:** single binary, < 512MB RAM overhead, works on 2-core VMs. Good enough for personal/small-team workloads. Traefik included, CoreDNS included.

## Deployment Decision Tree

```
New service to deploy?
├── User-facing (public) → K3s on prod node
│   ├── Web app → Deployment + Service + IngressRoute + Cloudflare Tunnel
│   ├── Background job → Deployment (no service needed)
│   └── Scheduled task → CronJob
└── Internal / experiment → K3s on dev node or skip K3s entirely
    ├── Stateless → Deployment
    └── Stateful → StatefulSet or bind-mount on specific node
```

**Never use raw Docker on production node once K3s is running.** Port conflicts, no restart guarantee, no resource limits enforced.

## Git Workflow (Solo)

```bash
# Feature work
git checkout -b feature/my-feature
# ... work ...
git add -p          # stage hunks, not whole files
git commit -m "feat: add X"
git checkout main && git merge --no-ff feature/my-feature
git push

# Hotfix to prod
git checkout -b hotfix/critical-fix
# ... fix ...
git checkout main && git merge --no-ff hotfix/critical-fix
git push
git tag v1.2.1
```

**Commit message convention:**
- `feat:` new feature
- `fix:` bug fix
- `chore:` maintenance, deps
- `docs:` documentation
- `refactor:` no behavior change

**No `git add .` on production configs** — always `git add -p` or named files to avoid committing secrets.

## Secrets Management

**Never commit real credentials.** Replace with placeholder in repo:
```
SSHPASS='${SERVER_PASS}'     ← in repo
SSHPASS='actualpass'         ← in local .env or memory only
```

**Secret rotation priority:**
1. Anything in a public repo → rotate immediately
2. Anything in a private repo → rotate before making repo public
3. Shared team passwords → use a password manager, not plaintext files

**Local `.env` pattern:**
```bash
# .env (gitignored)
SERVER_PASS=actualpass
DB_URL=postgresql://user:pass@localhost/db

# Load in script
source .env
```

## Stack Selection (Resource-Constrained)

| Need | Pick | Avoid |
|---|---|---|
| Web app | Next.js standalone or FastAPI | Rails, Django (heavy deps) |
| Database | Postgres (single node) | MySQL (no JSONB), MongoDB (RAM hungry) |
| Cache | Redis | Memcached |
| Reverse proxy | Traefik (K3s built-in) | Nginx (extra config), HAProxy |
| Monitoring | Prometheus + Grafana | Datadog ($$), ELK (RAM) |
| CI/CD | GitHub Actions self-hosted | Jenkins (Java overhead) |
| Container runtime | K3s/containerd | Docker Swarm (deprecated), full K8s (too heavy) |

## Local Development → Production Parity

```bash
# docker-compose.yml for local dev matching prod
services:
  app:
    build: .
    environment:
      - DATABASE_URL=postgresql://app:app@db:5432/appdb
    depends_on:
      db:
        condition: service_healthy
  db:
    image: postgres:16
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "app"]
```

**Match prod Postgres version exactly.** Version mismatch causes subtle behavior differences in JSON, array operators, and generated columns.

## Monitoring on a Budget

**Minimal stack (3 containers, < 512MB):**
```yaml
# Prometheus + Grafana + node_exporter
services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
  grafana:
    image: grafana/grafana
    ports: ["3000:3000"]
  node-exporter:
    image: prom/node-exporter
    network_mode: host
    pid: host
```

**Essential dashboards:** node overview (CPU/RAM/disk/network) + per-service uptime blackbox_exporter.

**Alert rules that actually matter:**
- Disk > 80% used
- RAM > 90% used for > 5 minutes
- Service down for > 1 minute
- SSL cert expiry < 14 days

## Backup Strategy

| Data | Where | Frequency |
|---|---|---|
| K3s manifests | GitHub (private) | On every change |
| Database | PBS or S3-compatible | Daily |
| Config files | GitHub (private, credentials masked) | On every change |
| VM/LXC snapshots | Proxmox Backup Server | Weekly |

**3-2-1 rule:** 3 copies, 2 different media, 1 offsite (GitHub counts as offsite for config).

## Common Pitfalls

- **Static IP assignment conflicts:** always check IPs in use with `arp-scan` or `nmap -sn <subnet>` before assigning a new static IP.
- **K3s local-path PVC node pinning:** pod is pinned to the node where PVC was created. Either use NFS or add `nodeSelector` to prevent scheduling elsewhere.
- **Cloudflare tunnel config not applied:** restart cloudflared after ConfigMap/config change — `kubectl rollout restart deployment/cloudflared`.
- **Self-signed cert browser warnings on internal tools:** use Cloudflare tunnel (valid cert) for anything you access from browser. Reserve self-signed for API-to-API internal only.
- **Cron running at wrong time:** always specify timezone. K3s CronJob uses UTC. Add `timeZone: Asia/Bangkok` in spec.
