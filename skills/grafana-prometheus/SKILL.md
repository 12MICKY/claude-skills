---
name: grafana-prometheus
description: Use this skill for Grafana and Prometheus — PromQL query writing, dashboard design, alerting rules, exporter configuration (node_exporter, blackbox_exporter, snmp_exporter), WireGuard peer health metrics, and textfile collector patterns. Activate for any monitoring, observability, or metrics work.
---

# Grafana + Prometheus

## Prometheus Setup

**docker-compose:**
```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml
    - prometheus-data:/prometheus
    command:
    - --config.file=/etc/prometheus/prometheus.yml
    - --storage.tsdb.retention.time=30d
    ports:
    - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    environment:
      GF_SECURITY_ADMIN_PASSWORD: YOUR_ADMIN_PASSWORD
    volumes:
    - grafana-data:/var/lib/grafana
    ports:
    - "3000:3000"

volumes:
  prometheus-data:
  grafana-data:
```

**prometheus.yml:**
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
  - static_configs:
    - targets: [alertmanager:9093]

rule_files:
  - /etc/prometheus/alerts/*.yml

scrape_configs:
  - job_name: prometheus
    static_configs:
    - targets: [localhost:9090]

  - job_name: node
    static_configs:
    - targets:
      - server1:9100
      - server2:9100

  - job_name: blackbox
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
    - targets:
      - https://myapp.example.com
    relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: blackbox:9115
```

## PromQL — Query Patterns

**Rate and increase:**
```promql
# Requests per second (use rate for counters)
rate(http_requests_total[5m])

# Total increase over time window
increase(http_requests_total[1h])

# Average rate by instance
avg by (instance) (rate(node_cpu_seconds_total{mode!="idle"}[5m]))
```

**CPU utilization:**
```promql
# Per-node CPU usage %
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Memory:**
```promql
# Available memory in GB
node_memory_MemAvailable_bytes / 1024 / 1024 / 1024

# Memory usage %
100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)
```

**Disk:**
```promql
# Disk usage % per mount
100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs"} / node_filesystem_size_bytes{fstype!~"tmpfs|fuse.lxcfs"})

# Disk I/O rate
rate(node_disk_read_bytes_total[5m])
rate(node_disk_written_bytes_total[5m])
```

**Network:**
```promql
# Bytes in/out per interface
rate(node_network_receive_bytes_total{device!~"lo|veth.*"}[5m])
rate(node_network_transmit_bytes_total{device!~"lo|veth.*"}[5m])
```

**HTTP error rate:**
```promql
# 5xx error rate
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))

# p95 latency
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))
```

**WireGuard peer up/down:**
```promql
# Peer health (1 = up, 0 = down)
wireguard_peer_up

# Count of down peers
count(wireguard_peer_up == 0)

# Alert: peer down > 5 min
wireguard_peer_up == 0
```

## Exporters

**node_exporter (system metrics):**
```bash
# Install
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.0/node_exporter-1.8.0.linux-amd64.tar.gz
tar xzf node_exporter-*.tar.gz
sudo cp node_exporter-*/node_exporter /usr/local/bin/

# systemd service
cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter \
  --collector.textfile.directory=/var/lib/node_exporter/textfile
Restart=always

[Install]
WantedBy=multi-user.target
EOF

useradd --system --no-create-home node_exporter
systemctl enable --now node_exporter
```

**Textfile collector (custom metrics):**
```bash
# Any script that writes to .prom file gets scraped automatically
mkdir -p /var/lib/node_exporter/textfile
chown node_exporter:node_exporter /var/lib/node_exporter/textfile
chmod 755 /var/lib/node_exporter/textfile

# Example: WireGuard peer health exporter
cat > /usr/local/bin/wg-exporter.sh << 'EOF'
#!/bin/bash
THRESHOLD=180
OUTPUT=/var/lib/node_exporter/textfile/wg_peers.prom

{
  echo "# HELP wireguard_peer_up WireGuard peer liveness (1=up, 0=down)"
  echo "# TYPE wireguard_peer_up gauge"
  wg show all latest-handshakes | while read iface pubkey ts; do
    now=$(date +%s)
    age=$(( now - ts ))
    up=$(( age <= THRESHOLD ? 1 : 0 ))
    short="${pubkey:0:16}"
    echo "wireguard_peer_up{interface=\"$iface\",peer=\"$short\"} $up"
  done
} > "$OUTPUT"
EOF
chmod +x /usr/local/bin/wg-exporter.sh

# Run every 60s via cron
echo "* * * * * root /usr/local/bin/wg-exporter.sh" > /etc/cron.d/wg-exporter
```

**blackbox_exporter (HTTP/TCP/ICMP probing):**
```yaml
# blackbox.yml
modules:
  http_2xx:
    prober: http
    timeout: 10s
    http:
      valid_status_codes: []    # empty = 2xx only
      method: GET
      follow_redirects: true
      tls_config:
        insecure_skip_verify: false

  tcp_connect:
    prober: tcp
    timeout: 5s
```

**snmp_exporter (network devices):**
```yaml
# prometheus.yml
- job_name: snmp-mikrotik
  static_configs:
  - targets: [ROUTER_IP]
  metrics_path: /snmp
  params:
    module: [mikrotik]
  relabel_configs:
  - source_labels: [__address__]
    target_label: __param_target
  - target_label: __address__
    replacement: snmp-exporter:9116
```

## Alerting Rules

```yaml
# /etc/prometheus/alerts/infra.yml
groups:
- name: infra
  rules:
  - alert: NodeDown
    expr: up == 0
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Node {{ $labels.instance }} is down"

  - alert: HighCPU
    expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU on {{ $labels.instance }}: {{ $value | printf \"%.0f\" }}%"

  - alert: DiskFull
    expr: 100 * (1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) > 90
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Disk {{ $labels.mountpoint }} on {{ $labels.instance }} is {{ $value | printf \"%.0f\" }}% full"

  - alert: WireGuardPeerDown
    expr: wireguard_peer_up == 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "WireGuard peer {{ $labels.peer }} on {{ $labels.interface }} is down"
```

## Grafana Dashboard Design

**Dashboard JSON import:** use Grafana's import feature with community dashboard IDs:
- `1860` — Node Exporter Full
- `7587` — Blackbox Exporter
- `13659` — WireGuard

**Key panel types:**
- **Time series:** rate/counter metrics over time. Use `rate()` not raw counters.
- **Gauge:** current single value (CPU %, disk %). Set thresholds: green <70%, yellow <85%, red >85%.
- **Table:** multi-row data. Use `sort by` transformation.
- **Stat:** big single number with background color by threshold.

**Variable for multi-host dashboards:**
```
Type: Query
Query: label_values(node_uname_info, instance)
Refresh: On dashboard load
```

Then use `{instance=~"$instance"}` in queries.

**Useful transformations:**
- `Calculate field`: compute derived columns (e.g., % from two metrics).
- `Filter by value`: hide rows below threshold.
- `Rename by regex`: clean up label names for display.

## Alertmanager

```yaml
# alertmanager.yml
global:
  resolve_timeout: 5m

route:
  receiver: default
  group_by: [alertname, instance]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
  - match:
      severity: critical
    receiver: pagerduty
  - match:
      severity: warning
    receiver: slack

receivers:
- name: default
  slack_configs:
  - api_url: SLACK_WEBHOOK_URL
    channel: '#alerts'
    text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'

- name: pagerduty
  pagerduty_configs:
  - routing_key: PAGERDUTY_KEY
```

## Common Mistakes

- Using `rate()` on gauge metrics — `rate()` is for counters only. Use `delta()` or plain value for gauges.
- Not using `[5m]` window — too short = spiky graphs; too long = slow to react to changes.
- Alerting on `up == 0` without `for: 2m` — one missed scrape fires false alert.
- Textfile `.prom` syntax errors silently drop the file — validate with `promtool check metrics < file.prom`.
