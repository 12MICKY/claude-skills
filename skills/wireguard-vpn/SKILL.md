---
name: wireguard-vpn
description: Use this skill for WireGuard VPN — server and client configuration, hub-and-spoke topology, road-warrior remote access, multi-WAN asymmetric routing fix, MTU tuning, key management, iptables forwarding rules, and Prometheus peer health metrics. Activate for any wg0 config, wg-quick, or peer troubleshooting.
---

# WireGuard VPN

## Core Concepts

- **Interface-based:** each peer is a network interface; routing is handled by the OS.
- **Stateless tunnel:** no concept of "connected" — peers are routes, not sessions.
- **Handshake:** initiates when there is traffic to send + a `Endpoint` configured. Server-only roles set no `Endpoint` and never initiate.
- **AllowedIPs = routing table:** inbound packets are verified against sender's `AllowedIPs`; outbound packets are routed into the tunnel if dst matches `AllowedIPs`.

## Server Setup (Linux)

```ini
# /etc/wireguard/wg0.conf
[Interface]
Address    = 10.9.0.1/24
ListenPort = 51820
PrivateKey = SERVER_PRIVATE_KEY

# Enable forwarding for routed traffic
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
# road-warrior laptop
PublicKey  = LAPTOP_PUBLIC_KEY
AllowedIPs = 10.9.0.2/32

[Peer]
# road-warrior phone
PublicKey  = PHONE_PUBLIC_KEY
AllowedIPs = 10.9.0.3/32

[Peer]
# site-to-site branch
PublicKey  = BRANCH_PUBLIC_KEY
AllowedIPs = 10.9.0.4/32, 192.168.100.0/24
```

**Enable and start:**
```bash
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

systemctl enable --now wg-quick@wg0
```

## Client Config — Split Tunnel (recommended for mobile)

```ini
[Interface]
Address    = 10.9.0.2/32
PrivateKey = CLIENT_PRIVATE_KEY
DNS        = 10.9.0.1

[Peer]
PublicKey           = SERVER_PUBLIC_KEY
Endpoint            = SERVER_IP:51820
AllowedIPs          = 10.9.0.0/24, 192.168.1.0/24   # only home network
PersistentKeepalive = 25
```

**Full tunnel (route all traffic through VPN):**
```ini
AllowedIPs = 0.0.0.0/0, ::/0
```

**PersistentKeepalive = 25** — required for all NAT/mobile clients. Without it, NAT entries expire and handshakes fail silently.

## Key Generation

```bash
# Generate server keypair
wg genkey | tee server.key | wg pubkey > server.pub

# Generate client keypair
wg genkey | tee client.key | wg pubkey > client.pub

# Pre-shared key (optional, quantum-resistant layer)
wg genpsk > psk.key
```

**Never reuse keypairs across devices.** Rotate server keypair periodically:
```bash
NEW_KEY=$(wg genkey)
NEW_PUB=$(echo "$NEW_KEY" | wg pubkey)
wg set wg0 private-key <(echo "$NEW_KEY")
# update /etc/wireguard/wg0.conf + inform all peers of new server pubkey
```

## Hub-and-Spoke Topology

All peers connect only to the hub. Peer-to-peer traffic routes through hub.

```
Laptop (10.9.0.2) ──┐
Phone  (10.9.0.3) ──┤── Hub (10.9.0.1) ──── Home LAN (192.168.1.0/24)
Branch (10.9.0.4) ──┘
```

Hub config: each peer's `AllowedIPs` = only that peer's IP. Hub routes between peers via normal IP forwarding.

## VPS Relay (when hub is behind NAT)

When the WireGuard hub (home server) has no public IP, relay via a VPS:

```
Client ──── VPS (public IP) ──[UDP forward]──── Home server
```

VPS forwards UDP port to home:
```bash
# iptables UDP forward on VPS
iptables -t nat -A PREROUTING -p udp --dport 51821 -j DNAT --to HOME_WG_IP:51820
iptables -A FORWARD -p udp -d HOME_WG_IP --dport 51820 -j ACCEPT
```

Client connects to `VPS_IP:51821`; home server keepalive maintains the NAT hole.

## MTU Tuning

Default WireGuard overhead: **32 bytes** (20 IPv4 + 8 UDP + 4 WG header) per packet.

| Outer MTU | WireGuard MTU |
|---|---|
| 1500 (Ethernet) | 1420 |
| 1480 (PPPoE) | 1400 |
| 1420 (WG over WG) | 1340 |

**Symptom of MTU mismatch:** `ping` works, `ssh`/`curl` hangs. Fix with MSS clamp:
```bash
# On Linux WireGuard server
PostUp = iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN \
  -j TCPMSS --clamp-mss-to-pmtu
```

**On MikroTik:**
```routeros
/ip firewall mangle
add action=change-mss chain=forward protocol=tcp tcp-flags=syn \
  new-mss=clamp-to-pmtu passthrough=yes
```

## Asymmetric Routing Fix (Multi-WAN)

When server has two WAN interfaces and reply packets egress wrong interface, handshake breaks.

**Linux (ip rule + fwmark):**
```bash
# Mark WireGuard UDP replies with fwmark 51820
ip rule add fwmark 51820 table 51820
ip route add default via WAN1_GW table 51820
iptables -t mangle -A OUTPUT -p udp --sport 51820 -j MARK --set-mark 51820
```

**MikroTik:** use routing marks in mangle — mark reply traffic with the mark of the incoming WAN interface, then route by mark.

## Peer Health Monitoring (Prometheus)

Generate `wireguard_peer_up` metric from last handshake:

```bash
#!/bin/bash
# /usr/local/bin/wg-exporter.sh — run via cron every 60s
THRESHOLD=180  # seconds — peer is "up" if handshake within threshold

wg show all latest-handshakes | while read iface pubkey ts; do
  now=$(date +%s)
  age=$(( now - ts ))
  up=$(( age <= THRESHOLD ? 1 : 0 ))
  echo "wireguard_peer_up{interface=\"$iface\",peer=\"${pubkey:0:16}\"} $up"
done > /var/lib/node_exporter/textfile/wg_peers.prom
```

**Do not use ICMP ping** to test peer health — peers that are "up" (handshake recent) may not respond to ping if their `AllowedIPs` doesn't include the source. Use last-handshake age as the authoritative liveness signal.

## Operational Commands

```bash
wg show                        # all interface status + peers
wg show wg0 latest-handshakes  # timestamp per peer (0 = never)
wg show wg0 transfer           # bytes sent/received per peer
wg show wg0 endpoints          # current peer endpoints (dynamic)

# Add peer live (no restart)
wg set wg0 peer PUBKEY allowed-ips 10.9.0.5/32 endpoint PEER_IP:51820

# Remove peer live
wg set wg0 peer PUBKEY remove
```

## Security Checklist

- Unique keypair per device — never copy private keys.
- `PersistentKeepalive` only on clients behind NAT, never on servers (wastes bandwidth).
- Scoped iptables rules: `-i wg0 -o eth0` not blanket `FORWARD ACCEPT`.
- Store private keys in files with `chmod 600`, not inline in shell scripts.
- Pre-shared keys add a quantum-resistant layer — worth adding for sensitive tunnels.
- Split tunnel for mobile clients — full tunnel routes all traffic and burns mobile data.
