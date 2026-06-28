---
name: wireguard-vpn
description: Use this skill for WireGuard VPN setup and management — server configuration, peer management, split tunnel vs full tunnel, multi-WAN setup, hub-and-spoke topology, road-warrior clients, and diagnosing handshake/routing issues.
---

# WireGuard VPN

## Core Concepts

- **Interface:** virtual NIC (`wg0`) with a keypair. One interface per WireGuard instance.
- **Peer:** remote endpoint identified by public key. Each peer has `AllowedIPs` = what traffic to route through it.
- **Handshake:** initiated by either side (unlike OpenVPN client-only). No connection state — stateless.
- **No PKI:** key exchange is manual (copy public key, no CA needed).

## Server Setup (Linux)

```bash
# Generate keypair
wg genkey | tee server.key | wg pubkey > server.pub

# /etc/wireguard/wg0.conf
[Interface]
PrivateKey = <server-private-key>
Address = 10.9.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = <client-public-key>
AllowedIPs = 10.9.0.2/32
```

```bash
# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Start
wg-quick up wg0
systemctl enable wg-quick@wg0
```

## Client Config

**Split tunnel** (route only VPN subnet, not all traffic):
```ini
[Interface]
PrivateKey = <client-private-key>
Address = 10.9.0.2/32
DNS = 10.9.0.1

[Peer]
PublicKey = <server-public-key>
Endpoint = server.example.com:51820
AllowedIPs = 10.9.0.0/24, 192.168.1.0/24   # only these subnets via VPN
PersistentKeepalive = 25
```

**Full tunnel** (all traffic via VPN):
```ini
AllowedIPs = 0.0.0.0/0, ::/0
```

**Rule:** use split tunnel for mobile clients — full tunnel burns upload on the server side.

## Hub-and-Spoke Topology

All peers connect to a central server. Peer-to-peer traffic routes via hub.

```
Mobile → [hub wg0 10.9.0.1] ← Server A
                             ← Server B
```

Hub config — add each spoke as a peer:
```ini
[Peer]
PublicKey = <server-a-pubkey>
AllowedIPs = 10.9.0.10/32, 192.168.10.0/24   # server A + its LAN
```

For spoke-to-spoke traffic, hub must have `net.ipv4.ip_forward = 1` and masquerade rules.

## Road-Warrior (Dynamic IP Clients)

Clients behind NAT don't need a fixed IP — `Endpoint` on server side is auto-discovered from handshake. Set `PersistentKeepalive = 25` on clients to keep NAT mapping alive.

```ini
# Server peer entry for dynamic client
[Peer]
PublicKey = <mobile-pubkey>
AllowedIPs = 10.9.0.50/32
# No Endpoint line — server learns it from incoming handshake
```

## MTU Tuning

WireGuard adds 60 bytes overhead (IPv4) or 80 bytes (IPv6) on top of UDP.

```
Default MTU: 1420 (1500 - 80)
Over PPPoE: 1412
Double tunnel (WG inside WG): 1340
```

Fix TLS stalls caused by MTU issues (MSS clamp):
```bash
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
```

## Multi-WAN (Asymmetric Routing Fix)

When server has multiple WAN interfaces, reply must go out the same interface the handshake came in on:

```bash
# Mark connections by incoming interface
iptables -t mangle -A PREROUTING -i eth0 -j MARK --set-mark 1
iptables -t mangle -A PREROUTING -i eth1 -j MARK --set-mark 2

# Policy routing
ip rule add fwmark 1 table 101
ip rule add fwmark 2 table 102
ip route add default via <gw1> table 101
ip route add default via <gw2> table 102
```

## Peer Management

```bash
# Add peer without restarting (live)
wg set wg0 peer <pubkey> allowed-ips 10.9.0.5/32

# Remove peer
wg set wg0 peer <pubkey> remove

# Show status
wg show wg0

# Check last handshake (health check)
wg show wg0 latest-handshakes
# If last-handshake > 180s → peer is likely offline
```

## VPS UDP Forwarder (for NAT traversal)

When clients can't reach server directly (CGNAT, firewall), use VPS as UDP forwarder:

```bash
# On VPS — forward UDP :51822 to home server
iptables -t nat -A PREROUTING -p udp --dport 51822 -j DNAT --to-destination <home-ip>:51820
iptables -A FORWARD -p udp -d <home-ip> --dport 51820 -j ACCEPT
```

Clients set `Endpoint = <vps-ip>:51822`.

## Diagnostics

```bash
# Handshake check (no handshake = routing/firewall issue, not WG itself)
wg show wg0 latest-handshakes

# Packet trace
tcpdump -i eth0 udp port 51820 -n

# Route check — where does traffic to peer go?
ip route get 10.9.0.2

# DNS leak test (split tunnel)
dig @8.8.8.8 example.com   # should resolve from client's ISP DNS
dig @10.9.0.1 example.com  # should resolve from VPN DNS
```

| Problem | Cause | Fix |
|---|---|---|
| No handshake | Firewall blocking UDP port | Open UDP port on server firewall |
| Handshake ok, no traffic | Missing `AllowedIPs` or `ip_forward` | Check AllowedIPs covers destination, enable ip_forward |
| TLS stalls, ping works | MTU too large | Lower MTU or add MSS clamp iptables rule |
| Asymmetric routing drops | Multi-WAN, wrong reply path | Add policy routing by incoming interface mark |
| Client stuck after IP change | Stale endpoint cache | `wg show` → endpoint auto-updates on next handshake |
