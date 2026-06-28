---
name: mikrotik-routeros
description: Use this skill for MikroTik RouterOS v7 — firewall chains (RAW/filter/mangle/NAT), Queue Tree and PCQ bandwidth management, bridge VLAN filtering with hardware offload, WireGuard VPN configuration, CAPsMAN wireless controller, OSPF/BGP routing, and RouterOS scripting. Activate for CRS switch config, CHR router VM setup, or any /ip /interface /routing command work.
---

# MikroTik RouterOS v7

## Firewall Architecture

**Chain selection by use case:**
- `raw` (prerouting/output) — fastest drop, bypasses conntrack. Use for DoS/flood mitigation at high PPS.
- `filter` input — protect the router itself (management access, SSH, WinBox).
- `filter` forward — filter routed traffic between networks.
- `mangle` — mark packets/connections for QoS, policy routing, MSS clamp.
- `nat` srcnat/dstnat — masquerade, port forwarding.

**Hardened stateful firewall blueprint:**
```routeros
/ip firewall filter
add action=accept chain=input connection-state=established,related,untracked
add action=drop   chain=input connection-state=invalid
add action=accept chain=input protocol=icmp
add action=accept chain=input src-address-list=admin-subnets
add action=drop   chain=input comment="drop all other input"

add action=fasttrack-connection chain=forward connection-state=established,related
add action=accept chain=forward connection-state=established,related,untracked
add action=drop   chain=forward connection-state=invalid
add action=accept chain=forward out-interface-list=WAN
add action=drop   chain=forward comment="drop all other forward"
```

**RAW table for DoS mitigation (before conntrack):**
```routeros
/ip firewall raw
add action=drop chain=prerouting src-address-list=blacklist
add action=drop chain=prerouting protocol=tcp tcp-flags=fin,syn
```

**Address-list dynamic blocking:**
```routeros
/ip firewall filter
add action=add-src-to-address-list address-list=blacklist address-list-timeout=1h \
  chain=input dst-port=22 protocol=tcp connection-limit=5,32
```

## Bridge VLAN Filtering (Hardware Offloaded)

Modern method — replaces legacy `/interface vlan` on separate interfaces.

```routeros
/interface bridge
add name=bridge-lan vlan-filtering=yes hw=yes

# Trunk port (switch-to-switch, switch-to-hypervisor)
/interface bridge port
add bridge=bridge-lan interface=sfp-sfpplus1 comment="Trunk to upstream"

# Access ports
add bridge=bridge-lan interface=ether1 pvid=10 comment="VLAN 10 access"
add bridge=bridge-lan interface=ether2 pvid=20 comment="VLAN 20 access"

# VLAN membership
/interface bridge vlan
add bridge=bridge-lan tagged=bridge-lan,sfp-sfpplus1 untagged=ether1 vlan-ids=10
add bridge=bridge-lan tagged=bridge-lan,sfp-sfpplus1 untagged=ether2 vlan-ids=20

# L3 interfaces on bridge
/interface vlan
add interface=bridge-lan name=vlan10 vlan-id=10
add interface=bridge-lan name=vlan20 vlan-id=20

/ip address
add address=192.168.10.1/24 interface=vlan10
add address=192.168.20.1/24 interface=vlan20
```

**Rules:**
- Enable `vlan-filtering=yes` only AFTER assigning ports — enabling first drops all L2 traffic.
- Trunk port frame-type: `admit-only-vlan-tagged`; access port: `admit-only-untagged-and-priority-tagged`.
- Never use VLAN 1 for production; never use native VLAN = management VLAN (VLAN hopping).

## Queue Tree — Bandwidth Management

**PCQ (Per-Connection Queue) for fair sharing:**
```routeros
/queue type
add kind=pcq name=pcq-download pcq-classifier=dst-address pcq-rate=0
add kind=pcq name=pcq-upload   pcq-classifier=src-address pcq-rate=0

/queue tree
add name=download parent=global packet-mark=download-marked queue=pcq-download max-limit=100M
add name=upload   parent=global packet-mark=upload-marked   queue=pcq-upload   max-limit=50M
```

**Mangle marks for Queue Tree:**
```routeros
/ip firewall mangle
add action=mark-connection chain=forward connection-state=new in-interface=WAN \
  new-connection-mark=download-conn passthrough=yes
add action=mark-packet chain=forward connection-mark=download-conn \
  new-packet-mark=download-marked passthrough=no
```

**Per-peer VPN limit (Queue Tree, not PCQ):**
```routeros
# Mangle: mark per peer
/ip firewall mangle
add action=mark-packet chain=forward src-address=10.9.0.2 new-packet-mark=peer-02 passthrough=no

# Queue Tree: per peer child queue
/queue tree
add name=wg-clients parent=global
add name=peer-02 parent=wg-clients packet-mark=peer-02 max-limit=20M
```

**Burst config (short spikes above limit):**
```routeros
add name=peer-02 parent=wg-clients packet-mark=peer-02 max-limit=20M \
  burst-limit=40M burst-threshold=15M burst-time=10s
```

## Multi-WAN Failover (Recursive Routing)

```routeros
# 1. Test routes via each ISP gateway
/ip route
add dst-address=8.8.8.8/32 gateway=ISP1_GW scope=10 check-gateway=ping comment="WAN1 probe"
add dst-address=1.1.1.1/32 gateway=ISP2_GW scope=10 check-gateway=ping comment="WAN2 probe"

# 2. Default routes using probe hosts as virtual hops
add dst-address=0.0.0.0/0 gateway=8.8.8.8 distance=1 target-scope=30 check-gateway=ping
add dst-address=0.0.0.0/0 gateway=1.1.1.1 distance=2 target-scope=30 check-gateway=ping
```

## WireGuard VPN

```routeros
/interface wireguard
add name=wg0 listen-port=51820 mtu=1420

# Generate and display keypair
/interface wireguard print

/ip address
add address=10.9.0.1/24 interface=wg0

# Add peer (road-warrior client)
/interface wireguard peers
add interface=wg0 public-key="CLIENT_PUBKEY" \
  allowed-address=10.9.0.2/32 \
  comment="laptop"

# Firewall: allow WireGuard input
/ip firewall filter
add action=accept chain=input protocol=udp dst-port=51820 comment="WireGuard"
```

**MTU for double-tunnel (VPS relay):** set `mtu=1340` to avoid MSS issues.

**MSS clamp when MTU bug suspected (ping works, TCP stalls):**
```routeros
/ip firewall mangle
add action=change-mss chain=forward protocol=tcp tcp-flags=syn \
  new-mss=clamp-to-pmtu passthrough=yes
```

**WireGuard QR export (ROS 7.21+):**
```routeros
/interface wireguard peers export-config [find comment="laptop"] qr-code
```

## CAPsMAN Wireless Controller

```routeros
# Enable CAPsMAN
/caps-man manager
set enabled=yes

# Security profile
/caps-man security
add name=wpa3-psk authentication-types=wpa3-psk passphrase="YOUR_PASSPHRASE"

# Channel
/caps-man channel
add name=ch-5ghz band=5ghz-n/ac/ax control-channel-width=20mhz

# Configuration profile
/caps-man configuration
add name=cfg-main ssid="MyNetwork" security=wpa3-psk channel=ch-5ghz

# Provisioning rule: match all APs, assign config
/caps-man provisioning
add action=create-dynamic-enabled master-configuration=cfg-main comment="all APs"
```

**Two forwarding modes:**
- `local` — AP routes data itself (lower latency, AP needs DHCP).
- `manager` — all traffic tunneled to CAPsMAN (central control, adds latency).

## OSPF / BGP

**OSPF (single area):**
```routeros
/routing ospf instance
add name=ospf-main router-id=192.168.1.1 version=2

/routing ospf area
add instance=ospf-main name=backbone area-id=0.0.0.0

/routing ospf interface-template
add networks=192.168.10.0/24 area=backbone
```

**BGP (eBGP peering):**
```routeros
/routing bgp connection
add name=isp-peer remote.address=203.0.113.1/32 remote.as=64500 \
  local.role=ebgp output.default-originate=always

/routing filter rule
add chain=bgp-in rule="if (dst in 0.0.0.0/0) { accept }"
```

**BGP soft reset (never hard reset in production):**
```routeros
/routing bgp session reset [find] soft
```

## Scripting

**Error handling + iteration:**
```routeros
:onerror e in={
  /tool fetch url="https://api.example.com/update" output=none
} do={
  :log error "fetch failed: $e"
}

:foreach peer in=[/interface wireguard peers find] do={
  :local pk [/interface wireguard peers get $peer public-key]
  :log info "peer: $pk"
}
```

**Cloudflare DDNS:**
```routeros
:local CFToken "CLOUDFLARE_API_TOKEN"
:local CFZone  "CLOUDFLARE_ZONE_ID"
:local CFRecord "CLOUDFLARE_RECORD_ID"
:local Domain  "home.example.com"
:local WAN     "ether1"

:local CurrentIP [:pick [/ip address get [find interface=$WAN] address] 0 \
  [:find [/ip address get [find interface=$WAN] address] "/"]]
:local ResolvedIP [:resolve $Domain]

:if ($CurrentIP != $ResolvedIP) do={
  /tool fetch http-method=put \
    url="https://api.cloudflare.com/client/v4/zones/$CFZone/dns_records/$CFRecord" \
    http-header-field="Authorization: Bearer $CFToken,Content-Type: application/json" \
    http-data="{\"type\":\"A\",\"name\":\"$Domain\",\"content\":\"$CurrentIP\",\"ttl\":120}" \
    output=none
}
```

## Common Gotchas

- Enable `vlan-filtering` only AFTER assigning bridge ports — early enable drops all traffic.
- `Layer-7` matcher is CPU-expensive — applies to first 10 packets only; use sparingly.
- `FastTrack` bypasses mangle and queue rules; put QoS mangle before FastTrack, or disable FastTrack on QoS traffic.
- OSPF `network` statement uses wildcard masks like Cisco — NOT subnet masks.
- MTU mismatch signature: `ping` works, `curl`/`ssh` hangs → MSS clamp needed.
- `write memory` equivalent in ROS: config is always live, use `/system backup save` for file backup.
