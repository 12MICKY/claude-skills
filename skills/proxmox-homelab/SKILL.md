---
name: proxmox-homelab
description: Use this skill for Proxmox VE — VM and LXC lifecycle, cluster management, Ceph RBD/CephFS storage, High Availability manager, Proxmox Backup Server (PBS) integration, SDN/VXLAN networking, pvesh API automation, and cloud-init templates. Activate for pct, qm, pvecm, pvesm commands or any Proxmox administration task.
---

# Proxmox VE Homelab

## Cluster Management

```bash
# Cluster status and quorum
pvecm status
pvecm nodes

# Join existing cluster (run on new node)
pvecm add CLUSTER_NODE_IP

# Check corosync ring health
corosync-cfgtool -s

# Force quorum (DANGER: only when network split, not disk split)
pvecm expected 1
```

**Quorum rule:** N/2 + 1 nodes required. A 3-node cluster survives 1 failure; a 2-node cluster needs a QDevice or corosync votes=1 + noquorum action=ignore (homelab only).

## LXC Containers (`pct`)

```bash
# List containers
pct list

# Create container from template
pct create 200 local:vztmpl/ubuntu-24.04-default_amd64.tar.zst \
  --hostname myapp \
  --cores 2 --memory 2048 --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip=192.0.2.100/24,gw=192.0.2.1 \
  --storage local-lvm --rootfs local-lvm:8 \
  --password ROOT_PASSWORD --unprivileged 1

# Start/stop/status
pct start 200
pct stop 200
pct status 200

# Enter shell
pct enter 200

# Mount persistent storage
pct set 200 -mp0 /mnt/pve/storage/data,mp=/opt/data

# Resize disk
pct resize 200 rootfs +10G
```

**Unprivileged containers:** `--unprivileged 1` is default and recommended. UIDs inside are mapped to high UIDs on host (UID 0 inside = UID 100000 on host).

## Virtual Machines (`qm`)

```bash
# List VMs
qm list

# Create from cloud-init template
qm clone 9000 120 --name ubuntu-server --full

# Configure cloud-init
qm set 120 --ciuser myuser --cipassword MY_PASSWORD
qm set 120 --sshkeys ~/.ssh/authorized_keys
qm set 120 --ipconfig0 ip=192.0.2.120/24,gw=192.0.2.1

# Start/stop
qm start 120
qm shutdown 120 --timeout 30
qm stop 120     # force off

# Resize disk
qm resize 120 scsi0 +10G

# Serial console (required for cloud-init console access)
qm set 120 --serial0 socket --vga serial0
```

**Cloud-init template creation:**
```bash
# Download image
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# Create template VM
qm create 9000 --name ubuntu-24-template --memory 2048 --net0 virtio,bridge=vmbr0
qm importdisk 9000 noble-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm template 9000
```

## Storage Management (`pvesm`)

```bash
# List storage
pvesm status

# Add NFS storage
pvesm add nfs nfs-share --server NAS_IP --export /volume1/pve --content backup,images

# Add PBS storage target
pvesm add pbs pbs-node3 \
  --server PBS_IP \
  --datastore pbs-datastore \
  --username backup-user@pbs \
  --password BACKUP_PASSWORD \
  --fingerprint CERT_FINGERPRINT

# List available templates
pveam list local
pveam update
```

## High Availability Manager

```bash
# HA resource management
ha-manager status
ha-manager add vm:120 --group production --max-restart 3
ha-manager set vm:120 --state started

# HA groups (define which nodes host resources)
# Edit /etc/pve/ha/groups.cfg or via web UI
```

**HA fencing:** requires watchdog. For homelab without hardware watchdog:
```bash
# Load software watchdog
echo "softdog" >> /etc/modules
modprobe softdog
```

## Proxmox Backup Server (PBS) Integration

```bash
# Trigger manual backup
vzdump 120 --storage pbs-node3 --mode snapshot --remove 0

# List backups
pvesm list pbs-node3 --vmid 120

# Restore backup
qmrestore pbs-node3:backup/vm/120/2026-01-01T00:00:00Z 121 --storage local-lvm

# PBS maintenance
# On PBS node:
proxmox-backup-manager garbage-collection start pbs-datastore
proxmox-backup-manager verify start pbs-datastore
```

**Prune policy example:**
```
keep-daily=7, keep-weekly=4, keep-monthly=12, keep-yearly=1
```

## Ceph Storage

```bash
# Ceph cluster health
ceph status
ceph osd status
ceph df

# Create pool for VM images
ceph osd pool create vm-images 128
pvesm add rbd ceph-rbd --pool vm-images --krbd 0 --content images

# RBD (block) vs CephFS:
# RBD: VM disks, single-writer, higher performance
# CephFS: shared read-write, container bind mounts, ISO/template storage
```

## SDN / VXLAN

```bash
# Add SDN zone (VXLAN overlay)
# Via web UI: Datacenter → SDN → Zones → Add VXLAN
# Or API:
pvesh create /cluster/sdn/zones --zone vxlan-zone --type vxlan \
  --peers "NODE1_IP NODE2_IP NODE3_IP"

pvesh create /cluster/sdn/vnets --vnet vnet100 --zone vxlan-zone --tag 100
pvesh set /cluster/sdn --apply 1
```

## pvesh API Automation

```bash
# List all VMs across cluster
pvesh get /cluster/resources --type vm

# Get VM config
pvesh get /nodes/NODE/qemu/120/config

# Take snapshot
pvesh create /nodes/NODE/qemu/120/snapshot --snapname pre-upgrade

# Trigger HA migration
pvesh set /cluster/ha/resources/vm:120 --node TARGET_NODE
```

## Useful One-Liners

```bash
# Find which node a VM is on
pvesh get /cluster/resources --type vm --output-format json | python3 -c \
  "import sys,json; [print(v['node'], v['vmid'], v['name']) for v in json.load(sys.stdin) if v['type']=='qemu']"

# List all containers with IP addresses
pct list | awk 'NR>1{print $1}' | xargs -I{} pct config {} | grep -E "^(hostname|net)"

# Check disk usage per VM
pvesm list local-lvm

# Migrate VM live to another node
qm migrate 120 node2 --live --targetstorage local-lvm
```

## Troubleshooting

| Issue | Command | Fix |
|---|---|---|
| Cluster quorum lost | `pvecm status` | Check network, restore majority nodes |
| VM won't start | `qm start 120` error | Check `journalctl -u pve-manager` + storage health |
| Container network down | `pct enter 200; ip a` | Check bridge config `brctl show` on host |
| PBS fingerprint mismatch | `pvesm add pbs` fails | Get fingerprint: `proxmox-backup-manager cert info` on PBS |
| Ceph degraded | `ceph status` | `ceph health detail` → check OSD down count |
