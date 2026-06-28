---
name: mikrotik-routeros
description: Use this skill for MikroTik RouterOS configuration — firewall rules (filter/mangle/RAW/NAT), Queue Tree and PCQ bandwidth management, VLAN bridge-filtering, WireGuard VPN, CAPsMAN wireless, OSPF/BGP routing, and RouterOS scripting. Activate when working on CHR, CRS, hAP, or any RouterOS 7.x device.
---

# MikroTik RouterOS

## Firewall Architecture

**Table priority:** RAW (pre-conntrack) → filter → mangle → NAT

- **RAW table:** drop volumetric attacks before conntrack overhead. Use `/ip firewall raw add chain=prerouting action=drop` for known bad sources.
- **filter/forward:** stateful rules. Always have `connection-state=established,related accept` first, then specific allows, then drop.
- **mangle:** mark packets/connections for Queue Tree QoS or policy routing. Never use for filtering.
- **NAT:** `srcnat masquerade` on WAN out-interface only. Use `dstnat` for port forwarding.

```routeros
/ip firewall filter
add chain=input connection-state=established,related action=accept
add chain=input connection-state=invalid action=drop
add chain=input in-interface=ether1 action=drop comment="drop all WAN input"
add chain=forward connection-state=established,related action=accept
add chain=forward connection-state=invalid action=drop
add chain=forward in-interface=ether1 out-interface=!ether1 action=drop
```

**Layer-7 matcher:** regex on first 10 packets only — CPU-expensive, use sparingly for protocol identification only.

**Address-list + Netwatch:** dynamic block/unblock pattern:
```routeros
/tool netwatch add host=<target> up-script="/ip firewall address-list remove [find list=blocked where address=<target>]" down-script="/ip firewall address-list add list=blocked address=<target>"
```

## Queue Tree (Per-Peer Bandwidth)

Queue Tree is **unidirectional** — requires mangle packet marks to classify.

**PCQ (fairest approach — one rule handles all peers):**
```routeros
/queue type add name=pcq-download kind=pcq pcq-classifier=dst-address pcq-rate=10M
/queue type add name=pcq-upload kind=pcq pcq-classifier=src-address pcq-rate=5M
/queue tree add name=download parent=ether2 queue=pcq-download
/queue tree add name=upload parent=ether1 queue=pcq-upload
```

**Per-peer Queue Tree (explicit limit per IP):**
```routeros
# Step 1: mangle mark per peer connection
/ip firewall mangle add chain=forward src-address=10.9.0.2 action=mark-connection new-connection-mark=peer-2
/ip firewall mangle add chain=forward connection-mark=peer-2 action=mark-packet new-packet-mark=pkt-peer-2

# Step 2: Queue Tree child per peer
/queue tree add name=peer-2-up parent=wg-clients packet-mark=pkt-peer-2 max-limit=20M
```

**Burst:** allow short spikes above limit without sustained overuse:
```routeros
/queue tree add name=web-burst parent=global max-limit=10M burst-limit=30M burst-threshold=8M burst-time=8s
```

## VLAN — Bridge VLAN Filtering (Recommended)

Legacy `/interface vlan` on router port = deprecated. Use bridge VLAN filtering:

```routeros
/interface bridge add name=br0 vlan-filtering=yes

# Trunk port (switch uplink or AP)
/interface bridge port add bridge=br0 interface=ether2 frame-types=admit-only-vlan-tagged
/interface bridge vlan add bridge=br0 vlan-ids=10,20,30 tagged=ether2

# Access port (end device, VLAN 10)
/interface bridge port add bridge=br0 interface=ether3 pvid=10 frame-types=admit-only-untagged-and-priority-tagged
/interface bridge vlan add bridge=br0 vlan-ids=10 untagged=ether3

# VLAN interface for routing/DHCP
/interface vlan add name=vlan10 interface=br0 vlan-id=10
/ip address add address=192.168.10.1/24 interface=vlan10
```

**Rules:** never use VLAN ID 0, 1, or 4095 in production. Native VLAN ≠ management VLAN.

## WireGuard

```routeros
# Server interface
/interface wireguard add name=wg-clients listen-port=51820 mtu=1420

# Peer
/interface wireguard peers add interface=wg-clients public-key="<pubkey>" allowed-address=10.9.0.2/32 persistent-keepalive=25s

# Routes
/ip address add address=10.9.0.1/24 interface=wg-clients
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade
```

**Double-tunnel MTU fix:** set MTU=1340 when tunneling inside another tunnel (WireGuard over VPN). Add MSS clamp to fix TLS stalls:
```routeros
/ip firewall mangle add chain=forward protocol=tcp tcp-flags=syn action=change-mss new-mss=clamp-to-pmtu
```

**Multi-WAN symmetry:** mangle to force reply via same WAN interface as incoming handshake:
```routeros
/ip firewall mangle add chain=prerouting in-interface=ether1 action=mark-connection new-connection-mark=wan1
/ip firewall mangle add chain=output connection-mark=wan1 action=mark-routing new-routing-mark=via-wan1
```

**QR export (ROS 7.21+):**
```routeros
/interface wireguard peers export-config numbers=0
```

## CAPsMAN

```routeros
# Manager (on CRS/main router)
/caps-man manager set enabled=yes

# Security profile
/caps-man security add name=corp authentication-types=wpa2-psk encryption=aes-ccm passphrase="<pass>"

# Channel
/caps-man channel add name=ch-5ghz frequency=5180 width=20mhz band=5ghz-n/ac

# Configuration
/caps-man configuration add name=corp-5g ssid=Corp channel=ch-5ghz security=corp

# Provisioning rule (match all APs, create dynamic interfaces)
/caps-man provisioning add action=create-dynamic-enabled master-configuration=corp-5g
```

**Forwarding modes:**
- `local` — AP routes data itself (lower latency, less control)
- `manager` — all frames forwarded to CRS (centralized policy, higher latency)

**Force roam on weak signal:**
```routeros
/caps-man access-list add signal-range=-90..-75 action=reject
```

## OSPF / BGP

**OSPF area types:** backbone(0.0.0.0) → stub → totally-stubby → NSSA → standard
- Set point-to-point on direct links to skip DR/BDR election
- Metric type 1 (internal + external cost) preferred over type 2

```routeros
/routing ospf instance add name=default router-id=10.0.0.1
/routing ospf area add name=backbone area-id=0.0.0.0 instance=default
/routing ospf interface-template add interfaces=ether2 area=backbone network-type=point-to-point
```

**BGP best-path order:** WEIGHT → LOCAL_PREF → AS_PATH length → ORIGIN → MED → eBGP>iBGP → IGP metric → Router-ID

```routeros
/routing bgp connection add name=upstream remote.address=203.0.113.1 remote.as=65000 local.role=ebgp
```

## Scripting

```routeros
# Error handling
:onerror e in={
  /tool fetch url="https://example.com" dst-path=result.txt
} do={
  :log error "fetch failed: $e"
}

# Iterate WireGuard peers
:foreach peer in=[/interface wireguard peers find interface=wg-clients] do={
  :local pubkey [/interface wireguard peers get $peer public-key]
  :local handshake [/interface wireguard peers get $peer last-handshake]
  :log info "peer=$pubkey last=$handshake"
}

# Scheduler (cron-equivalent)
/system scheduler add name=daily-backup interval=1d on-event="/system backup save name=auto"
```

## Common Pitfalls

- `connection-state=new` before established/related rule = everything drops (established must be first)
- Forgetting `frame-types` on bridge port = untagged frames leak across VLANs
- WireGuard peer `allowed-address` must include the peer's tunnel IP or traffic won't route
- CAPsMAN provisioning fires on connect — changing config requires `caps-man remote-cap disconnect` to reprovision
