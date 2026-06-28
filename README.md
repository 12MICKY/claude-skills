# claude-skills

> 13 production-grade Claude Code skills for self-hosted infrastructure engineers.

[![CI](https://github.com/12MICKY/claude-skills/actions/workflows/validate.yml/badge.svg)](https://github.com/12MICKY/claude-skills/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Distilled from real infrastructure work — not tutorials. Covers the full self-hosted stack: MikroTik RouterOS, Proxmox VE, K3s, Cloudflare Tunnel, Docker Swarm, WireGuard, Grafana/Prometheus, FastAPI, Next.js, Linux server admin, enterprise network engineering, and context engineering for AI systems.

Every skill includes production patterns, known pitfalls, and anti-patterns. No credentials or environment-specific addresses.

---

## Install

```bash
git clone https://github.com/12MICKY/claude-skills.git ~/claude-skills
cd ~/claude-skills
./setup.sh
```

Skills are picked up immediately — no Claude Code restart needed.

---

## Skills

### Networking

| Skill | What it covers |
|---|---|
| [mikrotik-routeros](skills/mikrotik-routeros/SKILL.md) | Firewall chains (RAW/filter/mangle/NAT), Queue Tree & PCQ bandwidth limiting, bridge VLAN filtering with HW offload, WireGuard, CAPsMAN, OSPF/BGP, scripting, DDNS |
| [wireguard-vpn](skills/wireguard-vpn/SKILL.md) | Server/client config, hub-and-spoke topology, VPS relay, MTU tuning, key management, scoped iptables, Prometheus peer health metrics |
| [network-engineer](skills/network-engineer/SKILL.md) | OSI-layer troubleshooting methodology, BGP state machine, Cisco IOS/IOS-XE patterns, interface health counters, enterprise design (spine-leaf/BGP/OSPF), Netmiko automation |

### Infrastructure

| Skill | What it covers |
|---|---|
| [proxmox-homelab](skills/proxmox-homelab/SKILL.md) | VM/LXC lifecycle, cluster management, Ceph RBD/CephFS, HA manager, PBS backup, SDN/VXLAN, cloud-init templates, pvesh API |
| [k3s-kubernetes](skills/k3s-kubernetes/SKILL.md) | Deployments, Traefik IngressRoute, ConfigMaps/Secrets, PVCs, private registry, rolling updates, debugging, topology spread |
| [docker-swarm](skills/docker-swarm/SKILL.md) | Stack deployment, immutable config/secret versioning pattern, placement constraints, overlay networks, registry auth |
| [linux-server-admin](skills/linux-server-admin/SKILL.md) | systemd services/timers, LVM, netplan/nmcli, ufw/iptables, fail2ban, log analysis, performance diagnostics, SSH hardening |
| [cloudflare-tunnel](skills/cloudflare-tunnel/SKILL.md) | Zero-trust public exposure, K3s HA deployment, ConfigMap-based config, DNS automation, adding/removing service routes |

### Observability

| Skill | What it covers |
|---|---|
| [grafana-prometheus](skills/grafana-prometheus/SKILL.md) | PromQL queries, dashboard design, alerting rules, node/blackbox/snmp exporters, textfile collector, WireGuard peer health |

### Development

| Skill | What it covers |
|---|---|
| [python-fastapi](skills/python-fastapi/SKILL.md) | Async routes, Pydantic v2, SQLAlchemy 2.0 + asyncpg, JWT auth, background tasks, Docker multi-stage, K3s deploy |
| [nextjs-deployment](skills/nextjs-deployment/SKILL.md) | Standalone output mode, static asset directory gotcha, Docker multi-stage, PM2, K3s deploy, GitHub Actions CI/CD |

### Workflow & AI

| Skill | What it covers |
|---|---|
| [thai-dev-workflow](skills/thai-dev-workflow/SKILL.md) | K3s-first deployment policy, service lifecycle (add/remove), Git workflow, tech stack selection, monitoring and backup strategy |
| [context-engineering](skills/context-engineering/SKILL.md) | Context window mechanics, KV cache strategy, compression techniques, degradation patterns, memory systems, multi-agent coordination, tool design, harness engineering, LLM evaluation |

---

## How It Works

Claude Code reads `~/.claude/skills/<name>/SKILL.md` and uses the `description` frontmatter to decide when to load a skill:

```markdown
---
name: mikrotik-routeros
description: Use this skill for MikroTik RouterOS v7 — firewall chains (RAW/filter/mangle/NAT),
             Queue Tree and PCQ bandwidth management, bridge VLAN filtering...
---
```

When your message matches the description, Claude loads the full skill body into context automatically.

---

## Sync Local Changes Back

If you edit a skill locally and want to push it back to the repo:

```bash
# Edit ~/.claude/skills/mikrotik-routeros/SKILL.md
# Then copy it into the repo and push

cp ~/.claude/skills/mikrotik-routeros/SKILL.md ~/claude-skills/skills/mikrotik-routeros/SKILL.md
cd ~/claude-skills
git add skills/mikrotik-routeros/SKILL.md
git commit -m "update: mikrotik-routeros — add Queue Tree pattern"
git push
```

---

## Reference Material

| Document | Skills |
|---|---|
| [MikroTik RouterOS v7 Guide](docs/RouterOS_v7_Guide.md) | `mikrotik-routeros`, `network-engineer` |
| [Proxmox VE Admin Guide](docs/Proxmox_VE_Admin_Guide.md) | `proxmox-homelab` |
| [Ubiquiti UEWA Wireless Guide](docs/Ubiquiti_UEWA_Guide.md) | `network-engineer`, `mikrotik-routeros` |

---

## Fork & Customize

1. Fork this repo.
2. Edit or add `skills/<your-skill>/SKILL.md`.
3. Keep credentials and private IPs out — use placeholders like `YOUR_SERVER_IP`.
4. Run `./setup.sh` to install locally.

---

## License

[MIT](LICENSE) — Thiraphat Srichit
