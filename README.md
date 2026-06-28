# claude-skills

A collection of production-grade Claude Code skills built from real homelab and infrastructure experience.

No IP addresses, passwords, or environment-specific credentials. All skills are generic and reusable.

---

## Skills

| Skill | Description |
|---|---|
| [mikrotik-routeros](skills/mikrotik-routeros/) | Firewall chains, Queue Tree/PCQ, VLAN bridge-filtering, WireGuard, CAPsMAN, OSPF/BGP, scripting |
| [proxmox-homelab](skills/proxmox-homelab/) | PVE cluster, VM/LXC management, Ceph, HA manager, PBS backup, SDN, pvesh automation |
| [k3s-kubernetes](skills/k3s-kubernetes/) | Deployments, Traefik IngressRoute, ConfigMaps/Secrets, PVCs, private registry, debugging |
| [cloudflare-tunnel](skills/cloudflare-tunnel/) | Zero-trust tunnel, K3s HA deployment, DNS automation, config management |
| [wireguard-vpn](skills/wireguard-vpn/) | Server/client config, hub-and-spoke, road-warrior, multi-WAN, MTU tuning, diagnostics |
| [docker-swarm](skills/docker-swarm/) | Stack deploy, immutable config/secret versioning, placement constraints, rolling updates |
| [network-engineer](skills/network-engineer/) | OSI troubleshooting, BGP/OSPF, Cisco IOS, interface counters, VLAN design, Netmiko automation |
| [context-engineering](skills/context-engineering/) | Context window mechanics, compression, degradation patterns, multi-agent, tool design, harness |
| [thai-dev-workflow](skills/thai-dev-workflow/) | Homelab deployment philosophy, Git workflow, stack selection, monitoring, backup strategy |

---

## Installation

### Option A — Clone and copy

```bash
git clone https://github.com/12MICKY/claude-skills.git
cp -r claude-skills/skills/* ~/.claude/skills/
```

### Option B — Install specific skills only

```bash
git clone https://github.com/12MICKY/claude-skills.git
mkdir -p ~/.claude/skills/mikrotik-routeros
cp claude-skills/skills/mikrotik-routeros/SKILL.md ~/.claude/skills/mikrotik-routeros/
```

### Option C — Install all with one command

```bash
git clone https://github.com/12MICKY/claude-skills.git && cp -r claude-skills/skills/* ~/.claude/skills/
```

---

## Skill Format

Each skill follows the Claude Code skill format:

```
skills/
└── skill-name/
    └── SKILL.md      # frontmatter (name, description) + skill body
```

The `description` field in frontmatter controls when Claude Code auto-activates the skill based on context.

---

## Design Principles

- **No secrets:** all examples use placeholder values (`<your-ip>`, `<pubkey>`, `<pass>`)
- **Production patterns only:** patterns validated in real deployments, not tutorials
- **Generic:** no hardcoded hostnames, subnets, or org-specific config
- **Opinionated:** each skill includes known pitfalls and anti-patterns, not just happy path
