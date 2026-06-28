# Proxmox VE Cluster & Backups Advanced Guide

This guide serves as a comprehensive reference for managing Proxmox VE (PVE) clusters, Proxmox Backup Server (PBS) integrations, and container automations.

---

## 1. Proxmox VE Cluster Management
The Proxmox VE cluster (`10.33.1.44`) is a multi-node deployment that requires strict quorum mapping.

### A. Quorum & Corosync
Cluster communication is managed via Corosync on port 5405/udp. Ensure network configurations are low-latency and do not suffer from congestion.
```bash
# Check cluster connection and voting quorum status
pvecm status

# Check status of cluster nodes
pvecm nodes
```

### B. High Availability (HA) & Watchdog
HA ensures that if a node goes offline, its active VMs/LXCs are migrated to surviving nodes automatically.
- **Config Path**: `/etc/pve/ha/resources.cfg`
- **Fencing Watchdog**: Hardware watchdog cards or the software `softdog` module should be active to automatically restart nodes that lose connection, preventing concurrent writes to shared storage.
```bash
# Check HA manager daemon status
ha-manager status
```

---

## 2. Proxmox Backup Server (PBS) Integration
Backups are critical to prevent data loss. Integrate PVE cluster nodes with the PBS running inside **CT 104** on node 3.

### A. Storage Definitions (`/etc/pve/storage.cfg`)
Add the PBS datastore manually or via CLI:
```ini
pbs: pbs-node3
        server 10.33.1.104
        datastore pbs-node3
        username backup-user@pbs
        password BACKUP_USER_PASSWORD
        fingerprint FINGERPRINT_HEX
        prune-backups keep-daily=7,keep-weekly=4,keep-monthly=12
```

### B. Backup Policies & Maintenance (CLI)
Automated backup jobs run daily at **19:00**.
```bash
# Trigger manual snapshot backup to PBS
vzdump <vmid> --storage pbs-node3 --mode snapshot --remove 0

# Run garbage collection on the PBS container (CT 104) to reclaim pruned disk space
proxmox-backup-manager garbage-collection start pbs-node3
```

---

## 3. Host CLI Operations (LXC / VM)

### A. Container Control (`pct`)
```bash
# List containers and stats
pct list

# Create a new container using cloud-init template
pct create <vmid> local:vztmpl/ubuntu-24.04-default_amd64.tar.zst \
  -cores 2 -memory 1024 -net0 name=eth0,bridge=vmbr0,ip=10.33.1.20/24,gw=10.33.1.1

# Mount persistent folders
pct set <vmid> -mp0 /mnt/pve/storage-pool/data,mp=/opt/data
```

### B. Virtual Machine Control (`qm`)
```bash
# List Qemu virtual machines
qm list

# Assign serial redirect (vital for cloud-init console redirection)
qm set <vmid> --serial0 socket --vga serial0

# Start/Stop VMs
qm start <vmid>
qm shutdown <vmid> --timeout 30
```
