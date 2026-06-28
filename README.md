# claude-skills

![Skills](https://img.shields.io/badge/skills-13-blue)
![Version](https://img.shields.io/badge/version-1.1.0-green)
![Validate](https://github.com/12MICKY/claude-skills/actions/workflows/validate.yml/badge.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

Production-grade Claude Code skills for infrastructure engineers. Built from real homelab and production deployments — not tutorials.

**No IPs, passwords, or environment-specific credentials.** All patterns are generic and reusable.

---

## Skills

### Infrastructure

| Skill | Description |
|---|---|
| [proxmox-homelab](skills/proxmox-homelab/) | PVE cluster, VM/LXC, Ceph, HA manager, PBS backup, SDN, pvesh automation |
| [k3s-kubernetes](skills/k3s-kubernetes/) | Deployments, Traefik IngressRoute, ConfigMaps/Secrets, PVCs, private registry |
| [docker-swarm](skills/docker-swarm/) | Stack deploy, immutable config versioning, placement, rolling updates |
| [linux-server-admin](skills/linux-server-admin/) | systemd, disk/LVM, netplan/nmcli, ufw/iptables, fail2ban, log analysis |

### Networking

| Skill | Description |
|---|---|
| [mikrotik-routeros](skills/mikrotik-routeros/) | Firewall chains, Queue Tree/PCQ, VLAN bridge-filter, WireGuard, CAPsMAN, OSPF/BGP |
| [wireguard-vpn](skills/wireguard-vpn/) | Server/client, hub-and-spoke, road-warrior, multi-WAN, MTU tuning |
| [cloudflare-tunnel](skills/cloudflare-tunnel/) | Zero-trust exposure, K3s HA deploy, DNS automation, no open ports |
| [network-engineer](skills/network-engineer/) | OSI troubleshooting, BGP/OSPF, Cisco IOS, interface counters, Netmiko automation |

### Observability

| Skill | Description |
|---|---|
| [grafana-prometheus](skills/grafana-prometheus/) | PromQL, dashboard design, alerting, exporters, WireGuard peer metrics |

### Backend / Frontend

| Skill | Description |
|---|---|
| [python-fastapi](skills/python-fastapi/) | Async routes, Pydantic v2, asyncpg/SQLAlchemy, JWT, background tasks, Docker |
| [nextjs-deployment](skills/nextjs-deployment/) | Standalone output, Docker, K3s deploy, static asset gotchas, PM2, CI/CD |

### AI / Workflow

| Skill | Description |
|---|---|
| [context-engineering](skills/context-engineering/) | Context mechanics, compression, degradation patterns, multi-agent, tool design |
| [thai-dev-workflow](skills/thai-dev-workflow/) | K3s-first policy, Git workflow, stack selection, monitoring, backup strategy |

---

## Install

**All skills:**
```bash
git clone https://github.com/12MICKY/claude-skills.git
cp -r claude-skills/skills/* ~/.claude/skills/
```

**Single skill:**
```bash
git clone https://github.com/12MICKY/claude-skills.git
cp -r claude-skills/skills/mikrotik-routeros ~/.claude/skills/
```

**One-liner:**
```bash
git clone https://github.com/12MICKY/claude-skills.git && cp -r claude-skills/skills/* ~/.claude/skills/
```

---

## Skill Format

```
skills/
└── skill-name/
    └── SKILL.md      # frontmatter (name, description) + skill body
```

The `description` field controls when Claude Code auto-activates the skill. Write it as "Use this skill when..." to make activation precise.

---

## Design Principles

- **No secrets** — all examples use `<placeholder>` values
- **Production patterns** — validated in real deployments, not copied from docs
- **Opinionated** — known pitfalls and anti-patterns included, not just happy path
- **Generic** — no hardcoded hostnames, subnets, or org-specific config
- **CI validated** — frontmatter and credential checks on every push

---

## License

MIT
