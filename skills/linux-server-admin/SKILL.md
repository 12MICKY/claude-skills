---
name: linux-server-admin
description: Use this skill for Linux server administration — systemd service/timer management, disk and filesystem operations, network configuration with netplan/nmcli, firewall rules with ufw/iptables, fail2ban, log analysis, and OS-level diagnostics. Activate when configuring or troubleshooting Ubuntu/Debian servers.
---

# Linux Server Administration

## systemd — Services and Timers

**Service unit:**
```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=myapp
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/bin/server
Restart=on-failure
RestartSec=5s
Environment=NODE_ENV=production
EnvironmentFile=/opt/myapp/.env

# Resource limits
MemoryLimit=512M
CPUQuota=50%

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable --now myapp
systemctl status myapp
journalctl -u myapp -f              # live logs
journalctl -u myapp --since "1h ago"
journalctl -u myapp -n 100 --no-pager
```

**Timer unit (cron replacement):**
```ini
# /etc/systemd/system/backup.timer
[Unit]
Description=Daily Backup Timer

[Timer]
OnCalendar=*-*-* 19:00:00
Persistent=true   # run missed jobs after downtime
Unit=backup.service

[Install]
WantedBy=timers.target
```

```bash
systemctl enable --now backup.timer
systemctl list-timers --all
```

**`Type=` values:**
- `simple` — ExecStart is the main process
- `forking` — process forks (old-style daemons), needs `PIDFile=`
- `oneshot` — runs once and exits (good for scripts)
- `notify` — process signals readiness via `sd_notify()`

## Disk Management

```bash
# List block devices
lsblk -f
fdisk -l

# Partition (interactive)
fdisk /dev/sdb
# or for scripts:
parted /dev/sdb --script mklabel gpt mkpart primary ext4 0% 100%

# Format
mkfs.ext4 /dev/sdb1
mkfs.xfs /dev/sdb1   # better for large files

# Mount
mount /dev/sdb1 /data

# Persistent mount (/etc/fstab)
UUID=$(blkid /dev/sdb1 -s UUID -o value)
echo "UUID=$UUID /data ext4 defaults,nofail 0 2" >> /etc/fstab
mount -a   # test fstab without reboot

# Check disk health
smartctl -a /dev/sdb
smartctl -t short /dev/sdb   # run self-test

# Disk usage
df -h
du -sh /var/log/*   # find large dirs
ncdu /              # interactive (apt install ncdu)

# LVM
pvcreate /dev/sdb
vgcreate data-vg /dev/sdb
lvcreate -L 50G -n data-lv data-vg
mkfs.ext4 /dev/data-vg/data-lv

# Extend LVM (no unmount)
lvextend -L +20G /dev/data-vg/data-lv
resize2fs /dev/data-vg/data-lv    # ext4
xfs_growfs /data                   # xfs
```

## Network Configuration

**Netplan (Ubuntu 20.04+):**
```yaml
# /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses: [10.0.0.10/24]
      routes:
        - to: default
          via: 10.0.0.1
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
  vlans:
    eth0.10:
      id: 10
      link: eth0
      addresses: [192.168.10.1/24]
```

```bash
netplan try      # test with 120s rollback
netplan apply    # apply permanently
```

**nmcli (NetworkManager):**
```bash
nmcli con show
nmcli con up "connection-name"
nmcli con add type ethernet con-name eth1 ifname eth1 ip4 10.0.0.11/24 gw4 10.0.0.1
nmcli con mod eth1 ipv4.dns "1.1.1.1 8.8.8.8"
nmcli con up eth1

# WireGuard via nmcli
nmcli con import type wireguard file /etc/wireguard/wg0.conf
```

**Useful commands:**
```bash
ip a                       # interfaces + IPs
ip r                       # routing table
ip route get 8.8.8.8       # which interface/gateway for this dst
ss -tlnp                   # listening TCP ports + process
ss -unp                    # listening UDP
nmap -sn 10.0.0.0/24       # ping sweep (find active hosts)
```

## Firewall (ufw / iptables)

**ufw (simple):**
```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow from 10.0.0.0/24 to any port 9100   # node_exporter, LAN only
ufw enable
ufw status numbered
ufw delete 3   # delete rule #3
```

**iptables (advanced):**
```bash
# List rules with line numbers
iptables -L -n -v --line-numbers

# Allow established
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Port forward (NAT)
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.10:80
iptables -A FORWARD -p tcp -d 10.0.0.10 --dport 80 -j ACCEPT
iptables -t nat -A POSTROUTING -j MASQUERADE

# Save (Debian/Ubuntu)
apt install iptables-persistent
netfilter-persistent save
```

## fail2ban

```bash
# Status
fail2ban-client status
fail2ban-client status sshd

# Unban IP
fail2ban-client set sshd unbanip <ip>

# Custom jail (/etc/fail2ban/jail.local)
[sshd]
enabled = true
maxretry = 5
findtime = 10m
bantime = 1h
```

**Log patterns for custom jails:**
```ini
[myapp]
enabled = true
logpath = /var/log/myapp/access.log
filter = myapp-auth-fail   # /etc/fail2ban/filter.d/myapp-auth-fail.conf
maxretry = 10
bantime = 30m
```

## Log Analysis

```bash
# journald
journalctl -u nginx --since "2026-06-28 00:00" --until "2026-06-28 12:00"
journalctl -p err -n 50        # last 50 errors
journalctl --disk-usage         # how much space logs use
journalctl --vacuum-time=7d     # keep only last 7 days

# Find errors across all logs
grep -r "ERROR\|FATAL\|OOM" /var/log/ --include="*.log"

# Auth failures
grep "Failed password" /var/log/auth.log | awk '{print $11}' | sort | uniq -c | sort -rn

# Top resource consumers
ps aux --sort=-%mem | head -10
ps aux --sort=-%cpu | head -10
```

## Performance Diagnostics

```bash
# System overview
htop        # interactive process viewer
vmstat 1 5  # CPU/memory/IO every 1s, 5 times
iostat -x 1 # disk IO stats

# Load average interpretation
# 1.0 on 1 core = 100% utilized
# On 4-core: load > 4.0 = overloaded
uptime

# Memory
free -h
cat /proc/meminfo | grep -E "MemTotal|MemAvailable|SwapTotal|SwapFree"

# Open files / connections
lsof -i :80            # what's on port 80
lsof -p <pid>          # files opened by process
ss -s                  # socket summary

# Disk IO
iotop -a               # cumulative IO per process
dstat                  # combined CPU/disk/net stats
```

## Common Operations

```bash
# Update + upgrade (non-interactive)
DEBIAN_FRONTEND=noninteractive apt-get update -qq && apt-get upgrade -yq

# unattended-upgrades (security patches auto)
apt install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# User management
useradd -m -s /bin/bash -G sudo deploy
passwd deploy
# or lock password (SSH key only)
passwd -l deploy

# SSH hardening (/etc/ssh/sshd_config)
PasswordAuthentication no     # key only
PermitRootLogin no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2

# crontab
crontab -e
# m h dom mon dow command
0 2 * * * /opt/backup.sh >> /var/log/backup.log 2>&1
```

## Common Issues

| Symptom | Diagnosis | Fix |
|---|---|---|
| Service won't start | `journalctl -u svc -n 50` | Fix config/permissions per error |
| Disk 100% | `du -sh /*` recursive | Clear logs, `/tmp`, old backups |
| OOM kills | `dmesg | grep -i oom` | Increase RAM, add swap, tune app |
| Network unreachable after reboot | netplan/fstab syntax error | Boot to recovery, fix config |
| SSH locked out | OOB/console access needed | VNC/KVM console, fix auth |
| High load, low CPU usage | IO wait | `iostat -x 1`, check disk health |
| Port not reachable | `ss -tlnp`, `ufw status` | Service not running or firewall blocking |
