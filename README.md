# claude-skills

> 21 production-grade Claude Code skills — GitHub workflow automation + self-hosted infrastructure patterns.

[![CI](https://github.com/12MICKY/claude-skills/actions/workflows/validate.yml/badge.svg)](https://github.com/12MICKY/claude-skills/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/12MICKY/claude-skills)](https://github.com/12MICKY/claude-skills/releases/latest)

---

## GitHub Workflow Skills

Six skills that cover the full development lifecycle — from project init to release.

```
/open-project → /create-branch → (code) → /open-pr → /pr-review → /merge-pr → /create-release
```

| Skill | Command | What it does |
|-------|---------|-------------|
| **open-project** | `/open-project <name> <stack>` | Bootstrap project: directory structure, Dockerfile, `.env.example`, git init, GitHub repo |
| **create-branch** | `/create-branch [type] [desc]` | Create `feat/fix/chore/hotfix` branch with conflict detection and optional remote push |
| **open-pr** | `/open-pr [--draft] [--reviewer]` | Push branch, generate structured PR title + body, open via `gh pr create` |
| **pr-review** | `/pr-review [PR#]` | Review diff with 🔴 BLOCKER / 🟡 SUGGESTION / 🟢 NIT findings — posts inline comments |
| **merge-pr** | `/merge-pr [PR#] [--squash\|--merge\|--rebase]` | Gate-check CI + draft state + approvals, then merge with strategy by branch type |
| **create-release** | `/create-release [version] [--pre\|--dry-run]` | Semver bump, version file update, CHANGELOG.md, tag, GitHub Release, optional artifacts |

### Stacks supported by `open-project`

`python` · `node` · `go` · `nextjs` · `docker` · `bare`

### Merge strategy (auto-selected by branch prefix)

| Branch | Strategy |
|--------|----------|
| `feat/*` `fix/*` `chore/*` `refactor/*` | squash |
| `hotfix/*` `release/*` | merge commit |

---

## Infrastructure Skills

| Skill | Command | Domain |
|-------|---------|--------|
| **k3s-kubernetes** | `/k3s-kubernetes` | K3s Deployments, Traefik IngressRoute, PVC, RBAC, namespace patterns |
| **docker-swarm** | `/docker-swarm` | Stack deploy, config/secret immutability workarounds, rolling updates |
| **cloudflare-tunnel** | `/cloudflare-tunnel` | Zero-trust tunnel — ConfigMap-based K3s config, DNS routing, HA replicas |
| **proxmox-homelab** | `/proxmox-homelab` | VM/LXC lifecycle, cluster management, Ceph, PBS backup, cloud-init templates |
| **mikrotik-routeros** | `/mikrotik-routeros` | Firewall chains, WireGuard, VLAN bridge-filter, CAPsMAN, Queue Tree/PCQ |
| **wireguard-vpn** | `/wireguard-vpn` | Server + client config, hub-and-spoke, multi-WAN, MTU/DNS troubleshooting |
| **linux-server-admin** | `/linux-server-admin` | systemd, LVM, UFW, fail2ban, SSH hardening, cron, log rotation |
| **grafana-prometheus** | `/grafana-prometheus` | PromQL, dashboard design, alerting, recording rules, Loki log queries |
| **nextjs-deployment** | `/nextjs-deployment` | Standalone output, Docker multi-stage, K3s IngressRoute, env injection |
| **python-fastapi** | `/python-fastapi` | Async routes, Pydantic v2, SQLAlchemy 2.0, JWT auth, Docker deploy |
| **network-engineer** | `/network-engineer` | OSI troubleshooting, Cisco IOS, OSPF/BGP, VRF, Netmiko automation |
| **thai-dev-workflow** | `/thai-dev-workflow` | Self-hosted infra workflow — K3s-first deploy, Cloudflare tunnel, `.34`/`.32` policy |
| **context-engineering** | `/context-engineering` | AI agent context design, memory systems, multi-agent isolation, LLM evaluation |
| **cad-design** | `/cad-design` | Fusion 360 / Onshape parametric modeling, CAM toolpaths, STL/STEP export |
| **digital-fabrication** | `/digital-fabrication` | FDM 3D printing, LightBurn laser, CNC — slicer settings, toolpath optimization |

---

## Install

### All skills (recommended)
```bash
git clone https://github.com/12MICKY/claude-skills.git ~/claude-skills
for skill in ~/claude-skills/skills/*/; do
  cp -r "$skill" ~/.claude/skills/"$(basename "$skill")"
done
```

### Single skill
```bash
# Example: just the GitHub workflow skills
for s in open-project create-branch open-pr pr-review merge-pr create-release; do
  cp -r ~/claude-skills/skills/$s ~/.claude/skills/
done
```

### Stay up to date
```bash
cd ~/claude-skills && git pull
for skill in skills/*/; do
  cp -r "$skill" ~/.claude/skills/"$(basename "$skill")"
done
```

---

## Requirements

- [Claude Code](https://claude.ai/code) — any recent version
- [GitHub CLI](https://cli.github.com) (`gh`) — authenticated via `gh auth login`
- `git` 2.30+

---

## Usage examples

```
# Start a new Go service
/open-project payment-service go

# Branch off for a feature
/create-branch feat payment-webhook

# Open a PR when done
/open-pr

# Review it
/pr-review

# Merge it
/merge-pr

# Ship v1.1.0
/create-release v1.1.0
```

---

## CHANGELOG

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

[MIT](LICENSE)
