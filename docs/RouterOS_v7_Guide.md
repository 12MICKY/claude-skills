# MikroTik RouterOS v7 Advanced Networking Reference Guide

This document compiled by Thiraphat's environment serves as a hardcore configuration and operations reference for MikroTik RouterOS v7 running on CRS switches and CHR router VMs.

---

## 1. L2 Switching & Bridge VLAN Filtering (Hardware Offloaded)
Bridge VLAN filtering is the modern, standard method in RouterOS v7 to segregate Layer 2 networks while utilizing switch chip hardware offloading (L2HW).

### Rules for L2HW Offloading:
- Always use a single bridge interface.
- Enable `vlan-filtering=yes` only after assigning ports and VLAN memberships.
- Ensure ports connecting to high-speed endpoints (e.g., hypervisors, switches) have L2 HW offloading enabled.

### Configuration Blueprint:
```routeros
# Create bridge
/interface bridge
add name=bridge-lan vlan-filtering=yes comment="Main HW offloaded bridge"

# Add member interfaces
# sfp-sfpplus1 = Trunk port connecting to PVE cluster
# ether1, ether2 = Access ports for local server interfaces
/interface bridge port
add bridge=bridge-lan interface=sfp-sfpplus1 comment="Trunk to PVE"
add bridge=bridge-lan interface=ether1 pvid=10 comment="Prod Server access"
add bridge=bridge-lan interface=ether2 pvid=20 comment="Staging Server access"

# Define VLAN tags
/interface bridge vlan
add bridge=bridge-lan tagged=bridge-lan,sfp-sfpplus1 untagged=ether1 vlan-ids=10
add bridge=bridge-lan tagged=bridge-lan,sfp-sfpplus1 untagged=ether2 vlan-ids=20

# Create L3 interfaces on top of bridge
/interface vlan
add interface=bridge-lan name=vlan10 vlan-id=10
add interface=bridge-lan name=vlan20 vlan-id=20

# Assign gateway IP addresses
/ip address
add address=10.33.1.45/24 interface=vlan10 network=10.33.1.0
add address=10.33.2.1/24 interface=vlan20 network=10.33.2.0
```

---

## 2. RouterOS v7 Hardened Stateful Firewall
A stateful firewall is critical to protect the control plane (input chain) and filter routed traffic (forward chain). RouterOS v7 optimizes performance when FastTrack is placed at the top of active rules.

### Stateful Firewall Blueprint:
```routeros
# Define management address lists
/ip firewall address-list
add address=10.33.1.0/24 list=admin-subnets

# Input Chain (Protecting the Router itself)
/ip firewall filter
add action=accept chain=input connection-state=established,related,untracked comment="Allow established/related"
add action=drop chain=input connection-state=invalid comment="Drop invalid packets"
add action=accept chain=input protocol=icmp comment="Allow ICMP ping"
add action=accept chain=input src-address-list=admin-subnets comment="Allow admin management access"
add action=drop chain=input comment="Drop all other input traffic"

# Forward Chain (Filtering routed traffic)
add action=fasttrack-connection chain=forward connection-state=established,related comment="FastTrack established/related"
add action=accept chain=forward connection-state=established,related,untracked
add action=drop chain=forward connection-state=invalid
add action=accept chain=forward out-interface-list=WAN comment="Allow LAN to WAN egress"
add action=drop chain=forward comment="Drop all other forwarding"
```

---

## 3. High Availability & Multi-WAN Failover (Recursive Routing)
Recursive routing allows the router to check upstream internet gateway reachability beyond the ISP gateway (first hop) by pinging remote hosts (e.g., Google/Cloudflare DNS). This prevents traffic blackholing when the ISP gateway is active but has no internet connectivity.

### Recursive Routing Blueprint:
```routeros
# 1. Add static route testers for remote DNS hosts via physical gateways
# ISP1 Gateway = 192.168.1.1, ISP2 Gateway = 192.168.2.1
/ip route
add dst-address=8.8.8.8/32 gateway=192.168.1.1 scope=10 check-gateway=ping comment="WAN1 recursive tester"
add dst-address=1.1.1.1/32 gateway=192.168.2.1 scope=10 check-gateway=ping comment="WAN2 recursive tester"

# 2. Add default routing paths targeting the remote host virtual hops
# target-scope must match or exceed the scope of the virtual hop route (typically 30)
add dst-address=0.0.0.0/0 gateway=8.8.8.8 distance=1 target-scope=30 check-gateway=ping comment="Primary default route via WAN1"
add dst-address=0.0.0.0/0 gateway=1.1.1.1 distance=2 target-scope=30 check-gateway=ping comment="Failover default route via WAN2"
```

---

## 4. Scripting & Automation (RouterOS v7 Syntax)
RouterOS v7 uses a modified `/tool fetch` syntax. Always verify HTTP options and format output strings carefully.

### A. Cloudflare DDNS Sync Script:
```routeros
:local CFToken "CLOUDFLARE_API_TOKEN"
:local CFZone "CLOUDFLARE_ZONE_ID"
:local CFRule "CLOUDFLARE_RECORD_ID"
:local Domain "home.thiraphat.work"

:local WANInterface "ether1"
:local CurrentIP [/ip address get [find interface=$WANInterface] address]
:set CurrentIP [:pick $CurrentIP 0 [:find $CurrentIP "/"]]

:local ResolveIP [:resolve $Domain]

:if ($CurrentIP != $ResolveIP) do={
  :log info "CF DDNS: IP mismatch. Updating $Domain from $ResolveIP to $CurrentIP..."
  /tool fetch http-method=put \
    url="https://api.cloudflare.com/client/v4/zones/$CFZone/dns_records/$CFRule" \
    http-header-field="Authorization: Bearer $CFToken,Content-Type: application/json" \
    http-data="{\"type\":\"A\",\"name\":\"$Domain\",\"content\":\"$CurrentIP\",\"ttl\":120}" \
    output=none
} else={
  :log info "CF DDNS: IP is up to date ($CurrentIP)"
}
```

### B. Discord Webhook Status Dispatcher:
```routeros
:local webhookUrl "DISCORD_WEBHOOK_URL"
:local msg ("[Mikrotik Alert] Router " . [/system identity get name] . " WAN interface changed status at " . [/system clock get date] . " " . [/system clock get time])

/tool fetch http-method=post \
  url=$webhookUrl \
  http-header-field="Content-Type: application/json" \
  http-data="{\"content\":\"$msg\"}" \
  output=none
```
