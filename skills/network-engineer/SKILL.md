---
name: network-engineer
description: Use this skill for enterprise network engineering — OSI-layer troubleshooting methodology, BGP state machine diagnosis, Cisco IOS/IOS-XE configuration and show commands, interface health counters, VLAN design, spine-leaf DC fabric, OSPF/BGP routing, config validation pre-deploy checklist, and Python/Netmiko automation. Activate for any network device config, routing protocol issue, or infrastructure design question.
---

# Network Engineering

## OSI-Layer Troubleshooting Methodology

**Start diagnosis by symptom:**

| Symptom | Start layer | First command |
|---|---|---|
| No link light / port down | L1 Physical | Check cable, SFP, `show interfaces` |
| Link up, no traffic | L2 Data Link | Check VLAN, STP, duplex `show interfaces` |
| Can't ping gateway | L3 Network | `show ip route`, check ACL |
| BGP/OSPF neighbor down | L3 + routing | `show bgp summary`, `show ip ospf neighbor` |
| DNS failing | L7 Application | `dig @8.8.8.8 domain` vs `dig domain` |
| Slow / packet loss | L1–L3 | Interface error counters, QoS drops |

**L1 — Physical:**
```
CRC errors → bad cable, bad SFP, duplex mismatch (CRC is on receive side of fault)
```

**L2 — Data Link:**
```
Duplex mismatch = CRC + collisions + 30-50% throughput loss
Never mix auto-negotiation on one side and fixed on other
STP blocking state = silent L2 black hole — check with show spanning-tree
```

**L3 — Network:**
```
Source ping from right interface: ping 8.8.8.8 source Gi0/0
ACL hit counting: show ip access-lists (add log keyword for new hits)
```

## Cisco IOS / IOS-XE

**Mode hierarchy:**
```
Router>          # user exec
Router# enable   # privileged exec
Router(config)#  # global config
Router(config-if)# interface sub-mode
Router(config-router)# routing protocol sub-mode
end              # jump back to privileged exec from any sub-mode
```

**Essential show commands:**
```ios
show interfaces Gi0/0                   ! counters, speed/duplex, errors
show ip interface brief                 ! all interfaces — up/down/IP
show ip route 8.8.8.8                  ! routing table lookup
show ip ospf neighbor                   ! OSPF adjacency table
show bgp summary                        ! BGP session table
show vlan brief                         ! VLAN database
show spanning-tree                      ! STP state per VLAN
show ip access-lists                    ! ACL + hit counters
show logging                            ! syslog buffer
show running-config | section ospf      ! filter config
```

**Save config (running-config is RAM only, lost on reload):**
```ios
write memory
! or:
copy running-config startup-config
```

**Wildcard masks (inverse of subnet mask):**
```
/24  → 0.0.0.255
/30  → 0.0.0.3
/32  → 0.0.0.0    (single host)
any  → 255.255.255.255
```

**Common gotchas:**
- OSPF `network` uses wildcard, not subnet mask: `network 10.0.0.0 0.0.0.255 area 0` ✓
- `enable password` = weak MD5; use `enable secret` (SHA-256) instead.
- `no ip domain-lookup` prevents CLI hangs when typing typos that look like hostnames.
- `exec-timeout 15 0` on VTY lines prevents idle admin lockout.

## Interface Health — Counter Reference

```
show interfaces Gi0/0
```

| Counter | Root Cause |
|---|---|
| CRC | Bad cable, duplex mismatch, failing SFP |
| Runts (<64B) | Duplex mismatch, collisions |
| Giants (>MTU) | Jumbo frames not supported end-to-end |
| Input drops | Inbound oversubscription; increase hold-queue |
| Output drops | Egress congestion; needs QoS |
| Interface resets | Flapping link, keepalive failure |
| Collisions | Half-duplex operation |

**Flapping diagnosis:**
```ios
show logging | include Gi0/0|changed state
```

## BGP

**State machine:**

| State | Meaning | Fix |
|---|---|---|
| Idle | Not trying | Check `neighbor X shutdown`, AS mismatch |
| Active | TCP SYN failing | Check reachability, `update-source`, ACL blocking 179 |
| Connect | SYN sent, no SYN-ACK | Firewall, peer not configured |
| OpenSent/Confirm | Negotiating | MTU, capability mismatch |
| Established | Working | Check prefix count |

**Always use soft reset — hard reset drops the session:**
```ios
clear ip bgp 203.0.113.1 soft in
clear ip bgp 203.0.113.1 soft out
```

**BGP config (eBGP):**
```ios
router bgp 65001
 neighbor 203.0.113.1 remote-as 64500
 neighbor 203.0.113.1 update-source Loopback0
 neighbor 203.0.113.1 ebgp-multihop 2
 neighbor 203.0.113.1 soft-reconfiguration inbound  ! to see received-routes
 !
 address-family ipv4 unicast
  neighbor 203.0.113.1 activate
  neighbor 203.0.113.1 prefix-list FILTER-IN in
```

**Best path selection order:**
```
WEIGHT → LOCAL_PREF → AS_PATH length → ORIGIN → MED → eBGP>iBGP → IGP metric → Router-ID
```

## OSPF

```ios
router ospf 1
 router-id 10.0.0.1
 network 192.168.1.0 0.0.0.255 area 0
 network 10.0.0.0 0.0.0.255 area 0
 passive-interface Gi0/1     ! suppress hellos on LAN segments
```

**DR/BDR election:** set `ip ospf network point-to-point` on routed point-to-point links to skip DR election.

**Area types:**
- Backbone (0.0.0.0) — required; all other areas must connect to it.
- Stub — no external routes (type-5 LSA blocked).
- Totally stubby — no external + no inter-area routes (default route only).
- NSSA — external routes as type-7 LSA (converts to type-5 at ABR).

## Enterprise Network Design

**Campus / branch topology:**
- Hub-and-spoke: <50 branches, central apps, simple management.
- SD-WAN overlay: multi-transport (MPLS + internet + LTE), cloud-friendly.
- Full mesh: low-latency branch-to-branch, expensive, complex.

**DC fabric (spine-leaf / Clos):**
```
[Server] ─┬─ [ToR Leaf A] ─┬─ [Spine 1] ─┬─ [ToR Leaf B] ─┬─ [Server]
           └─ [ToR Leaf A] ─┘─ [Spine 2] ─┘─ [ToR Leaf B] ─┘
```
- VXLAN/EVPN overlay — replaces STP-dependent L2 stretching.
- BGP unnumbered on spine-leaf links.
- Dual-attach every server to two ToR leaves (MLAG/LACP).
- Use IS-IS for large DC fabrics; OSPF for campus/branch.

**Segmentation zones:**
```
CORP (trusted PCs) → SERVERS → DMZ (public services) → GUEST
MGMT (OOB, never VLAN 1) → OT/IoT (isolated)
```
Never route between zones without stateful firewall. VRF-Lite for hardware-enforced separation.

**Security audit checklist:**
```ios
! CRITICAL — immediately fix:
show snmp community           ! 'public'/'private' = publicly scanned
show line vty 0 4             ! no access-class = anyone can SSH in
show running | include ^enable password  ! should be 'enable secret'

! Best practices must-haves:
ntp server NTP_SERVER_IP
logging host SYSLOG_SERVER
service timestamps log datetime msec
banner login ^AUTHORIZED ACCESS ONLY^
no ip domain-lookup
exec-timeout 15 0
ip ssh version 2
```

## Python Netmiko Automation

**Device types:** `cisco_ios`, `cisco_nxos`, `juniper_junos`, `arista_eos`, `mikrotik_routeros`, `paloalto_panos`, `fortinet`, `linux`

**Basic pattern:**
```python
from netmiko import ConnectHandler

device = {
    "device_type": "cisco_ios",
    "host": "192.0.2.1",
    "username": "admin",
    "password": "PASSWORD",
    "secret": "ENABLE_SECRET",
}

with ConnectHandler(**device) as conn:
    conn.enable()
    output = conn.send_command("show ip route", use_textfsm=True)  # returns list[dict]
    conn.send_config_set([
        "interface Gi0/1",
        "description UPDATED",
    ])
    conn.save_config()
```

**Batch with parallel execution:**
```python
from concurrent.futures import ThreadPoolExecutor
from netmiko import ConnectHandler, NetmikoAuthenticationException, NetmikoTimeoutException

def run_on_device(device):
    try:
        with ConnectHandler(**device) as conn:
            return conn.send_command("show version", use_textfsm=True)
    except (NetmikoAuthenticationException, NetmikoTimeoutException) as e:
        return {"error": str(e), "host": device["host"]}

with ThreadPoolExecutor(max_workers=10) as pool:
    results = list(pool.map(run_on_device, device_list))
```

**Rules:**
- Limit concurrent SSH to 10–20 max (most platforms have session limits).
- Always use context manager (`with`) — never leave connections open.
- `use_textfsm=True` returns structured `list[dict]`; without it returns raw string.
- Never hardcode credentials — use environment variables or a vault.

## VLAN Design Checklist

| VLAN | Purpose | Notes |
|---|---|---|
| 10 | Trusted (PCs, laptops) | Full internet, internal access |
| 20 | IoT / Smart devices | Internet only; no RFC1918 access |
| 30 | Servers / homelab | Restricted inbound from CORP |
| 40 | Guest | Internet only; client isolation |
| 99 | Management (OOB) | SSH/SNMP only; no user traffic |

**Anti-patterns:**
- VLAN 1 for anything production → VLAN hopping risk.
- Native VLAN = Management VLAN → first thing attackers try.
- VLANs without firewall rules between them → isolation theater.
- Trunk all VLANs everywhere → limit trunk allowed-vlan to only needed VLANs.
