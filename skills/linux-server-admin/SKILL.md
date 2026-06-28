---
name: linux-server-admin
description: Use this skill for Linux server administration — systemd services and timers, LVM disk management, network configuration with netplan/nmcli, firewall with ufw/iptables, fail2ban, log analysis, performance diagnostics, and user/permission management. Activate for any Ubuntu/Debian server setup, service management, or system troubleshooting task.
---

# Linux Server Administration

## systemd Services

**Create a custom service:**
```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application
After=network.target
Wants=network.target

[Service]
Type=simple
User=myapp
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/bin/server
Restart=on-failure
RestartSec=5
EnvironmentFile=/opt/myapp/.env

# Hardening
NoNewPrivileges=yes
ProtectSystem=strict
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable --now myapp
systemctl status myapp
journalctl -u myapp -f          # follow logs
journalctl -u myapp --since "1h ago"
```

**systemd Timers (cron replacement):**
```ini
# /etc/systemd/system/backup.timer
[Unit]
Description=Daily backup

[Timer]
OnCalendar=daily
Persistent=true               # run immediately if missed

[Install]
WantedBy=timers.target
```

```ini
# /etc/systemd/system/backup.service
[Unit]
Description=Run backup

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup.sh
```

```bash
systemctl enable --now backup.timer
systemctl list-timers
```

## LVM Disk Management

```bash
# Show current LVM layout
pvs           # physical volumes
vgs           # volume groups
lvs           # logical volumes
lsblk         # block device tree

# Add new disk to existing VG
pvcreate /dev/sdb
vgextend ubuntu-vg /dev/sdb

# Extend LV and filesystem
lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
resize2fs /dev/ubuntu-vg/ubuntu-lv      # ext4
xfs_growfs /                            # xfs

# Create new LV
lvcreate -L 50G -n data ubuntu-vg
mkfs.ext4 /dev/ubuntu-vg/data
mkdir /opt/data
echo "/dev/ubuntu-vg/data /opt/data ext4 defaults 0 2" >> /etc/fstab
mount -a
```

**LVM snapshot (for safe backup):**
```bash
lvcreate -L 5G -s -n snap /dev/ubuntu-vg/ubuntu-lv
mount -o ro /dev/ubuntu-vg/snap /mnt/snap
# ... backup from /mnt/snap ...
umount /mnt/snap
lvremove /dev/ubuntu-vg/snap
```

## Network Configuration

**netplan (Ubuntu 20.04+):**
```yaml
# /etc/netplan/00-config.yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses: [192.0.2.100/24]
      gateway4: 192.0.2.1
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
  bonds:
    bond0:
      interfaces: [eth1, eth2]
      parameters:
        mode: active-backup
      dhcp4: true
```

```bash
netplan try      # test with 120s auto-rollback
netplan apply
```

**nmcli (NetworkManager — CentOS/Rocky/some Ubuntu):**
```bash
nmcli con show
nmcli con mod "Wired connection 1" ipv4.addresses 192.0.2.100/24 ipv4.gateway 192.0.2.1 ipv4.method manual
nmcli con up "Wired connection 1"
```

## Firewall

**ufw (simple, Ubuntu default):**
```bash
ufw status verbose
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow from 192.0.2.0/24 to any port 5432   # restrict postgres to LAN
ufw deny 8080/tcp
ufw enable
ufw reload
```

**iptables (advanced, persistent via netfilter-persistent):**
```bash
# View rules with line numbers
iptables -L INPUT -n -v --line-numbers

# Allow established connections first (performance)
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow specific source
iptables -A INPUT -s 192.0.2.0/24 -p tcp --dport 22 -j ACCEPT

# Block and log
iptables -A INPUT -p tcp --dport 8080 -j LOG --log-prefix "BLOCKED: "
iptables -A INPUT -p tcp --dport 8080 -j DROP

# Save rules
apt install netfilter-persistent
netfilter-persistent save
```

## fail2ban

```bash
# Status
fail2ban-client status
fail2ban-client status sshd

# Unban an IP
fail2ban-client set sshd unbanip 1.2.3.4

# 1. Create filter (defines what a failed attempt looks like)
cat > /etc/fail2ban/filter.d/myapp.conf << 'EOF'
[Definition]
failregex = ^<HOST> .* "(GET|POST) .*" 401
            ^.*Failed login from <HOST>
ignoreregex =
EOF

# 2. Create jail (references the filter above)
cat > /etc/fail2ban/jail.d/myapp.conf << 'EOF'
[myapp]
enabled  = true
port     = 3000
filter   = myapp
logpath  = /var/log/myapp/access.log
maxretry = 5
bantime  = 3600
findtime = 600
EOF

systemctl restart fail2ban
fail2ban-client status myapp   # verify jail is active
```

## Log Analysis

```bash
# Follow live logs
journalctl -f
journalctl -u nginx -f

# Filter by time
journalctl --since "2026-01-01 10:00" --until "2026-01-01 11:00"

# Filter by priority
journalctl -p err -b    # errors since last boot

# Application logs (not journald)
tail -f /var/log/nginx/access.log
grep -E "error|failed|refused" /var/log/syslog | tail -50

# Parse nginx access log for top IPs
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20

# Find large files
find /var/log -size +100M -ls
du -sh /var/log/* | sort -rh | head -20
```

## Performance Diagnostics

```bash
# CPU
top -b -n 1 | head -20
mpstat 1 5          # per-CPU utilization
ps aux --sort=-%cpu | head -10

# Memory
free -h
vmstat 1 5
ps aux --sort=-%mem | head -10

# Disk I/O
iostat -x 1 5       # I/O wait, utilization per device
iotop               # real-time I/O per process

# Network
ss -tulnp           # listening ports + process
ss -s               # socket summary
iftop               # interface bandwidth
nethogs             # per-process bandwidth

# Load average interpretation
uptime
# 1m / 5m / 15m — values above core count = system overwhelmed
nproc               # get core count for reference
```

## User and Permission Management

```bash
# Create system user (no login shell, no home for services)
useradd --system --no-create-home --shell /usr/sbin/nologin myapp

# Add user to group
usermod -aG sudo myuser
usermod -aG docker myuser

# SSH key setup
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "ssh-ed25519 AAAA... user@host" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Sudo without password for specific command
echo "myuser ALL=(ALL) NOPASSWD: /usr/bin/docker, /bin/systemctl" > /etc/sudoers.d/myuser
chmod 440 /etc/sudoers.d/myuser

# File permissions
chown -R myapp:myapp /opt/myapp
chmod 750 /opt/myapp/bin/server     # owner execute, group read
chmod 640 /opt/myapp/.env           # owner read/write only
```

## SSH Hardening

```ini
# /etc/ssh/sshd_config additions
PermitRootLogin no
PasswordAuthentication no           # key-only after adding your key
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
AllowUsers myuser deploy
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
```

```bash
sshd -t                             # test config before restart
systemctl reload sshd
```

## Cron vs systemd Timers

| Feature | cron | systemd timer |
|---|---|---|
| Logging | syslog only | Full journald integration |
| Catch-up missed runs | No | Yes (`Persistent=true`) |
| Dependencies | No | `After=`, `Wants=` |
| Randomized delay | No | `RandomizedDelaySec=` |
| Status | `crontab -l` | `systemctl list-timers` |

Prefer systemd timers for new services. Keep crontab for one-liners.

## Common Fixes

```bash
# Disk full — find culprit
df -h && du -sh /* 2>/dev/null | sort -rh | head -10

# "Too many open files" error
ulimit -n                           # current limit
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# NTP sync
timedatectl status
timedatectl set-ntp true
chronyc tracking                    # chrony status

# Timezone
timedatectl set-timezone Asia/Bangkok

# Package manager stuck
sudo rm /var/lib/apt/lists/lock
sudo rm /var/cache/apt/archives/lock
sudo dpkg --configure -a
sudo apt update
```
