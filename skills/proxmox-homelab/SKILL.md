---
name: proxmox-homelab
description: Use this skill for Proxmox VE cluster operations — VM/LXC creation and management, Ceph RBD/CephFS storage, HA manager, SDN/VXLAN, Proxmox Backup Server (PBS), cluster networking, and automation via pvesh/qm/pct CLI. Activate when working on PVE nodes, managing containers, or diagnosing cluster issues.
---

# Proxmox Homelab

## Cluster Architecture

**Multi-node PVE cluster:** nodes joined via `pvecm add <existing-node-ip>`. Quorum requires majority (3 of 5 nodes). Corosync uses dedicated link — separate NIC or VLAN from production traffic.

**Storage types:**
| Type | Use | Notes |
|---|---|---|
| local-lvm | VM disks (thin provisioned) | Fast, node-local, no HA |
| ceph-rbd | VM disks with HA | Requires Ceph, 3-replica |
| cephfs | Shared ISOs, backups, snippets | POSIX, all nodes see same files |
| NFS/SMB | Backups, ISO storage | External NAS |

**Ceph basics:**
```bash
# Check cluster health
ceph -s
ceph osd tree
ceph df

# Pool usage
rados df

# Fix stuck operations
ceph osd unset noout
ceph osd unset norebalance
```

## VM Management (qm)

```bash
# Create VM from template (cloud-init)
qm create 200 --name myvm --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 200 ubuntu-24.04-cloud.img local-lvm
qm set 200 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-200-disk-0
qm set 200 --ide2 local-lvm:cloudinit --boot c --bootdisk scsi0
qm set 200 --ipconfig0 ip=dhcp --ciuser ubuntu --cipassword '<pass>'
qm start 200

# Clone template
qm clone 9001 200 --name new-vm --full --storage ceph-rbd

# Snapshots
qm snapshot 200 snap1 --description "before update"
qm rollback 200 snap1

# QMP console (when SSH locked out)
qm monitor 200
# then type: sendkey ctrl-alt-f2
# or send raw command:
qm guest exec 200 -- bash -c "whoami"
```

**Cloud-init templates:** create once, clone many. Requires `cloud-init` package + `qemu-guest-agent` inside the image.

## LXC Container Management (pct)

```bash
# Create unprivileged container
pct create 100 local:vztmpl/ubuntu-24.04-standard.tar.zst \
  --hostname myct --memory 512 --cores 1 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --rootfs local-lvm:8 --unprivileged 1 --onboot 1

# Start / exec
pct start 100
pct exec 100 -- bash -c "apt update && apt install -y nginx"

# Multi-line script (avoids quoting hell)
SCRIPT=$(echo 'apt update; apt install -y curl' | base64)
pct exec 100 -- bash -c "echo $SCRIPT | base64 -d | bash"

# Enter shell
pct enter 100
```

**Privileged vs unprivileged:** unprivileged = safer (UID mapping), but some features (NFS mount, certain kernel modules) require privileged.

**Nesting (Docker inside LXC):**
```bash
pct set 100 --features nesting=1,keyctl=1
```

## HA Manager

```bash
# Add resource to HA
ha-manager add vm:200 --state started --group ha-group

# Status
ha-manager status
ha-manager status | grep vm:200

# Groups (which nodes can run the resource)
ha-manager groupadd ha-group --nodes node1,node2,node3 --restricted 1
```

**HA requires:** Ceph or shared storage (can't HA a local-lvm disk), quorum, working Corosync.

## Proxmox Backup Server (PBS)

```bash
# On PVE node — add PBS as storage
pvesm add pbs pbs-backup --server <pbs-ip> --datastore <store-name> \
  --username root@pam --password '<pass>' --fingerprint <fp>

# Manual backup
vzdump 200 --storage pbs-backup --mode snapshot --compress zstd

# List backups
proxmox-backup-client list --repository root@pam@<pbs-ip>:<store>

# Prune (keep last 7 daily, 4 weekly)
proxmox-backup-client prune --repository ... --keep-daily 7 --keep-weekly 4
```

**PBS datastore GC:**
```bash
# Run on PBS node
proxmox-backup-manager garbage-collect <store>
```

## Networking (SDN / VXLAN)

```bash
# SDN zones (PVE 8+)
# Configure via UI: Datacenter → SDN → Zones → Add VXLAN
# Then: Datacenter → SDN → VNets → Add
# Apply: pvesh create /cluster/sdn

# Manual bridge with VLAN
# /etc/network/interfaces on each node:
auto vmbr1
iface vmbr1 inet manual
  bridge-ports eno2
  bridge-stp off
  bridge-fd 0
  bridge-vlan-aware yes
  bridge-vids 2-4094
```

## Storage Migration

```bash
# Move disk between storages (online)
qm move-disk 200 scsi0 ceph-rbd --delete 1

# Move rootfs of LXC
pct move-volume 100 rootfs ceph-rbd --delete 1
```

**GOTCHA:** `pct create --rootfs ceph-rbd:8` can hang (rbd map slow). Prefer `local-lvm` for creation, then migrate.

## Automation (pvesh / API)

```bash
# REST API via pvesh
pvesh get /nodes
pvesh get /nodes/node1/qemu
pvesh create /nodes/node1/qemu/200/status/start

# Token-based API auth
curl -H "Authorization: PVEAPIToken=root@pam!mytoken=<secret>" \
  https://<pve-ip>:8006/api2/json/nodes

# Check storage
pvesh get /storage/pbs-backup
pvesh get /nodes/node1/storage/local-lvm/content
```

## Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| VM won't start (HA) | No shared storage | Move disk to Ceph first |
| Ceph HEALTH_WARN `noout` | Maintenance flag left on | `ceph osd unset noout` |
| LXC network missing after reboot | Bridge not persistent | Add to `/etc/network/interfaces` |
| `pct create` hangs | Ceph rbd map slow | Use local-lvm, then `pct move-volume` |
| Backup fails fingerprint | PBS cert changed | Update fingerprint in storage config |
| Quorum lost | Node unreachable | `pvecm expected 1` (emergency single-node) |
