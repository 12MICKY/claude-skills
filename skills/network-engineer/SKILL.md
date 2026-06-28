---
name: network-engineer
description: Use this skill for enterprise network engineering — OSI-layer troubleshooting methodology, BGP/OSPF configuration and diagnostics, Cisco IOS patterns, interface health counters, VLAN design, WireGuard best practices, and Python/Netmiko automation. Activate when diagnosing network issues, designing topology, or writing network automation scripts.
---

# Network Engineering

## Troubleshooting Methodology (OSI Layer-by-Layer)

**Map symptom to layer first:**
| Symptom | Start at |
|---|---|
| Link down, no light | L1 Physical |
| Link up, no traffic | L2 (VLAN, STP, duplex) |
| Can't ping gateway | L3 (routing, ACL) |
| BGP session down | L3 + BGP state machine |
| DNS failing | L7 (isolate: `dig @8.8.8.8` vs local resolver) |
| Slow / packet loss | L1-L3 (errors, congestion, QoS) |

**Layer 1:** CRC errors → bad cable/SFP/duplex mismatch. CRCs appear on the receive side of the fault, not the transmit.

**Layer 2:** duplex mismatch = CRC + collisions + poor throughput. Never mix auto-negotiate on one side with hard-coded speed/duplex on the other. STP blocking causes silent L2 black holes.

**Layer 3:** `show ip route <dst>` → missing route, wrong next-hop, unreachable gateway. Always source the ping from the correct interface: `ping X source Y`.

**ACL debugging:** add `deny ip any any log` explicitly at the end to count drops. Never remove ACL to test — add a temp `permit ip any any log` before the deny.

## BGP State Machine

| State | Meaning | Fix |
|---|---|---|
| Idle | Not attempting | Check `shutdown`, AS number mismatch |
| Active | TCP failing | Check reachability, `update-source`, ACL blocking TCP 179 |
| Connect | SYN sent, no reply | Firewall, peer not configured |
| OpenSent/Confirm | Negotiating | MTU mismatch, timer mismatch |
| Established | Working | Check prefix count |

**Always soft-reset:** `clear ip bgp X soft in/out` — hard reset drops session and causes route flap.

```
show bgp summary                    # all sessions + prefix counts
show bgp neighbors X advertised-routes
show bgp neighbors X received-routes  # requires soft-reconfiguration inbound
debug ip bgp X events               # last resort, production risk
```

## Cisco IOS Patterns

**Mode hierarchy:** `>` → `enable` → `#` → `conf t` → `(config)#` → sub-modes → `end` returns to `#`

**Save config:** `write memory` or `copy run start`. Running-config is RAM — lost on reload.

```
show interfaces <intf>            # counters, speed/duplex, errors
show ip interface brief           # quick status all interfaces
show ip route <dst>               # routing table lookup
show ip ospf neighbor             # OSPF adjacencies
show bgp summary                  # BGP sessions
show vlan brief                   # VLAN table (switches)
show spanning-tree                # STP state
show ip access-lists              # ACL + hit counters
show logging                      # syslog buffer
show running-config | section bgp # filter to section
```

**Wildcard masks** = inverse of subnet mask (`255.255.255.255 − mask`):
- /24 → `0.0.0.255`
- /30 → `0.0.0.3`
- /32 → `0.0.0.0`

**OSPF gotcha:** `network` statement uses wildcard mask, NOT subnet mask:
```
network 10.0.0.0 0.0.0.255 area 0   ← correct
network 10.0.0.0 255.255.255.0 area 0 ← wrong
```

## Interface Health — Counter Reference

| Counter | Root Cause |
|---|---|
| CRC | Bad cable, duplex mismatch, failing SFP |
| Runts (<64B) | Duplex mismatch, collisions |
| Giants (>MTU) | Jumbo frames without support |
| Input drops | Inbound oversubscription |
| Output drops | Egress congestion (needs QoS) |
| Interface resets | Flapping, keepalive failure |
| Collisions | Half-duplex operation |

**Flapping:** `show logging | include <intf>|changed state` — timestamp reveals what changed.

## Enterprise Design Principles

**DC fabric:** spine-leaf (Clos) for >4 ToR switches. BGP unnumbered spine-leaf links. VXLAN/EVPN overlay replaces STP-dependent L2 stretching. Dual-attach every server to two ToR (MLAG/LACP).

**Routing protocol selection:**
- OSPF: campus/DC, single area simple, multi-area for >50 routers
- IS-IS: preferred in large DC fabric
- BGP: all WAN edge, SD-WAN, and internal large-scale

**Segmentation zones:** CORP, SERVERS, DMZ, MGMT (OOB), GUEST, OT/IoT. Never route between zones without stateful firewall. VRF-Lite for hardware-enforced separation.

**Redundancy:** dual ISP + BGP multihoming. BFD for fast BGP failure detection. Loop-free L3 design over STP.

## VLAN Design

**Standard zone mapping:**
```
VLAN 10 — Trusted (workstations, laptops)
VLAN 20 — IoT devices
VLAN 30 — Servers / services
VLAN 40 — Guest / untrusted
VLAN 99 — Management (OOB)
```

**Port types:**
- **Trunk:** tagged multi-VLAN → switch↔switch, switch↔router, switch↔AP
- **Access:** untagged single VLAN → end devices

**Firewall rule order (first-match):** allow specific services → block cross-zone → allow DNS/DHCP → default deny. Put DNS allow BEFORE RFC1918 block or IoT devices lose DNS.

**Anti-patterns:** native VLAN = management VLAN → VLAN hopping vulnerability. Never VLAN 1 for production. VLANs without firewall rules provide no security.

## Network Automation (Python + Netmiko)

```python
from netmiko import ConnectHandler
from concurrent.futures import ThreadPoolExecutor

device = {
    "device_type": "cisco_ios",   # or mikrotik_routeros, juniper_junos, arista_eos
    "host": "192.168.1.1",
    "username": "admin",
    "password": "pass",
}

with ConnectHandler(**device) as conn:
    conn.enable()
    output = conn.send_command("show version", use_textfsm=True)  # returns list[dict]
    conn.send_config_set(["interface Gi0/1", "description UPLINK"])
    conn.save_config()  # write memory
```

**Batch parallel (10-20 concurrent max):**
```python
def configure_device(host):
    try:
        with ConnectHandler(**{**base_config, "host": host}) as conn:
            return conn.send_command("show version")
    except Exception as e:
        return f"ERROR: {e}"

with ThreadPoolExecutor(max_workers=10) as pool:
    results = list(pool.map(configure_device, hosts))
```

**Supported device types:** `cisco_ios`, `cisco_nxos`, `cisco_xr`, `juniper_junos`, `arista_eos`, `mikrotik_routeros`, `paloalto_panos`, `fortinet`, `linux`

**TextFSM:** `use_textfsm=True` on supported commands returns structured `list[dict]` instead of raw string.

## Security Audit Checklist

```
[ ] SNMP community "public"/"private" → replace or disable
[ ] Telnet enabled → disable, SSH v2 only
[ ] "enable password" → replace with "enable secret"
[ ] VTY lines without access-class → add IP restriction
[ ] No exec-timeout → set exec-timeout 15 0
[ ] No NTP → add ntp server (accurate log timestamps)
[ ] No logging host → add syslog
[ ] No banner login → add (legal protection)
[ ] ip domain-lookup enabled → add "no ip domain-lookup"
```

**Dangerous commands (confirm before running):** `reload`, `erase startup-config`, `no router bgp`, `aaa new-model` (can lock out all access).

## Config Validation

```python
import ipaddress

def overlaps(net1: str, net2: str) -> bool:
    return ipaddress.ip_network(net1).overlaps(ipaddress.ip_network(net2))

# Check before adding interface
assert not overlaps("10.0.1.0/24", "10.0.0.0/16"), "Subnet overlap!"
```
