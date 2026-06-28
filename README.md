<div align="center">

<img src="https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcS0UJWFdcQLHBB7xw_hLJGnKDGV7Za50Ic4Qzp-iFnSbO6SPT0YRfEklFay&s=10" width="160" alt="Claude" />

# claude-skills

**Production-grade Claude Code skills for infrastructure engineers.**

Built from real homelab and production deployments — not tutorials.

[![Skills](https://img.shields.io/badge/skills-13-0969da?style=flat-square)](skills/)
[![Version](https://img.shields.io/badge/version-1.1.0-2da44e?style=flat-square)](https://github.com/12MICKY/claude-skills/releases)
[![Validate](https://img.shields.io/github/actions/workflow/status/12MICKY/claude-skills/validate.yml?label=validate&style=flat-square)](https://github.com/12MICKY/claude-skills/actions)
[![License](https://img.shields.io/badge/license-MIT-6e7781?style=flat-square)](LICENSE)

</div>

---

Each skill is a focused, self-contained knowledge module that Claude Code loads when relevant. The content comes from operating real systems — every pattern has been run in production, every gotcha has been hit.

No IPs, passwords, or environment-specific config. Drop in and use.

---

## Skills

### Networking

| Skill | Covers |
|---|---|
| [mikrotik-routeros](skills/mikrotik-routeros/) | Firewall chains (RAW/filter/mangle/NAT), Queue Tree & PCQ bandwidth limiting, VLAN bridge-filtering, WireGuard, CAPsMAN, OSPF/BGP, scripting |
| [wireguard-vpn](skills/wireguard-vpn/) | Server/client config, hub-and-spoke topology, road-warrior clients, multi-WAN asymmetric routing fix, MTU tuning |
| [cloudflare-tunnel](skills/cloudflare-tunnel/) | Zero-trust public exposure without open ports, K3s HA deployment, DNS automation, ConfigMap-based config management |
| [network-engineer](skills/network-engineer/) | OSI-layer troubleshooting methodology, BGP state machine, Cisco IOS patterns, interface health counters, VLAN design, Netmiko automation |

### Infrastructure

| Skill | Covers |
|---|---|
| [proxmox-homelab](skills/proxmox-homelab/) | PVE cluster, VM/LXC lifecycle, Ceph RBD/CephFS, HA manager, PBS backup, SDN/VXLAN, pvesh API |
| [k3s-kubernetes](skills/k3s-kubernetes/) | Deployments, Traefik IngressRoute, ConfigMaps/Secrets, PVCs, private registry, rolling updates, debugging |
| [docker-swarm](skills/docker-swarm/) | Stack deploy, immutable config/secret versioning pattern, placement constraints, overlay networks |
| [linux-server-admin](skills/linux-server-admin/) | systemd services/timers, LVM, netplan/nmcli, ufw/iptables, fail2ban, log analysis, performance diagnostics |

### Observability

| Skill | Covers |
|---|---|
| [grafana-prometheus](skills/grafana-prometheus/) | PromQL queries, dashboard design, alerting rules, exporters (node/blackbox/snmp), WireGuard peer health metrics |

### Development

| Skill | Covers |
|---|---|
| [python-fastapi](skills/python-fastapi/) | Async routes, Pydantic v2, SQLAlchemy 2.0 + asyncpg, JWT auth, background tasks, Docker + K3s deployment |
| [nextjs-deployment](skills/nextjs-deployment/) | Standalone output mode, static asset directory gotcha, Docker multi-stage, K3s deploy, PM2, CI/CD |

### AI & Workflow

| Skill | Covers |
|---|---|
| [context-engineering](skills/context-engineering/) | Context window mechanics, compression strategies, degradation patterns, multi-agent coordination, tool design, harness engineering |
| [thai-dev-workflow](skills/thai-dev-workflow/) | K3s-first deployment policy, Git workflow for solo/small teams, stack selection, monitoring, backup strategy |

---

## Install

To bootstrap or restore all 13 skills, run the setup script:

```bash
gh repo clone 12MICKY/claude-skills ~/claude-skills
cd ~/claude-skills
./setup.sh
```

**Upgrade & Synchronization:**
Run the sync script manually to package local changes and push back to GitHub:
```bash
./sync.sh
```

Skills are picked up immediately — no Claude Code restart needed.

---

## How It Works

Claude Code reads `~/.claude/skills/<name>/SKILL.md` on startup. The `description` field in the frontmatter tells Claude when to load the skill:

```markdown
---
name: mikrotik-routeros
description: Use this skill for MikroTik RouterOS configuration — firewall rules,
             Queue Tree, VLAN bridge-filtering, WireGuard, CAPsMAN, OSPF/BGP...
---
```

When your message matches the description, Claude loads the full skill body into context automatically.

---

## Design Principles

**No credentials.** Every example uses `<placeholder>` values. Safe to share, fork, and PR.

**Opinionated.** Each skill includes the happy path, known pitfalls, and anti-patterns. If something will burn you in production, it's in there.

**Production-validated.** Patterns come from running actual infrastructure — not rewritten from documentation.

**CI-gated.** Every push validates frontmatter structure and scans for accidentally committed credentials.

---

## Contributing

1. Fork the repo
2. Create `skills/<your-skill>/SKILL.md` — frontmatter + body following the existing format
3. Push and let CI validate, or run the workflow script locally
4. Open a PR

Skill body should cover: when to use it, core patterns with working examples, and common failure modes.

---

## Reference Materials & Learning Logs

This setup is grounded in official, enterprise-grade networking and system administration training materials:

| Document / Training Guide | Core Implementations & Blueprints | Associated Skills |
|---|---|---|
| [MikroTik RouterOS Documentation](https://manual.mikrotik.com/) | <ul><li>Zero-Script Recursive Routing Failover via virtual target hops</li><li>Cloudflare Dynamic DNS API PUT updates using `/tool fetch`</li><li>Automated Discord webhook alerts</li><li>Bridge VLAN Filtering (Hardware Offloaded)</li></ul> | `mikrotik-routeros`, `network-engineer` |
| [Ubiquiti UEWA Training Guide](https://dl.ubnt.com/guides/training/courses/UEWA_Training_Guide_V2.1.pdf) | <ul><li>Layer-3 AP Adoption via DHCP Option 43 and DNS `unifi` resolution</li><li>Manual SSH `set-inform` binding flow</li><li>Minimum RSSI `-75 dBm` soft-kick threshold for client roaming</li><li>Airtime Fairness and Band Steering optimization</li></ul> | `wireguard-vpn`, `network-engineer` |
| [Proxmox VE Admin Guide](https://pve.proxmox.com/pve-docs/pve-admin-guide.html) | <ul><li>PBS backup target scheduling and prune policies</li><li>Watchdog High Availability group definitions</li><li>LXC unprivileged mapping and mount points</li></ul> | `proxmox-homelab` |

---

## License

[MIT](LICENSE) — Thiraphat Srichit
