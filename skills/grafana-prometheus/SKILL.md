---
name: grafana-prometheus
description: Use this skill for Grafana and Prometheus monitoring — writing PromQL queries, designing dashboards, configuring alerting rules, setting up exporters (node, blackbox, snmp, wireguard), and diagnosing scrape or alert issues. Activate when building observability for homelab or production infrastructure.
---

# Grafana + Prometheus

## Stack Architecture

```
Targets (node_exporter, blackbox, snmp, custom)
    ↓ scrape (pull model, every 15s)
Prometheus (TSDB, PromQL engine)
    ↓ datasource
Grafana (dashboards, alerting)
    ↓ notify
Alertmanager / webhook / Telegram
```

**Pull model:** Prometheus scrapes targets. Targets don't push. Exception: use Pushgateway for batch jobs that can't be scraped.

## Prometheus Config

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["localhost:9093"]

rule_files:
  - "alerts/*.yml"

scrape_configs:
  - job_name: node
    static_configs:
      - targets:
          - "10.0.0.10:9100"
          - "10.0.0.11:9100"
        labels:
          env: prod

  - job_name: blackbox-http
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - https://example.com
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: localhost:9115   # blackbox exporter

  - job_name: snmp
    static_configs:
      - targets: ["10.0.0.1"]   # SNMP device (router/switch)
    metrics_path: /snmp
    params:
      module: [if_mib]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - target_label: __address__
        replacement: localhost:9116   # snmp exporter
```

## PromQL Essentials

**Selectors:**
```promql
node_cpu_seconds_total                          # all series
node_cpu_seconds_total{job="node"}              # filter by label
node_cpu_seconds_total{mode!="idle"}            # exclude
node_cpu_seconds_total{instance=~"10.0.0.*"}   # regex match
```

**Rate vs irate:**
```promql
rate(node_network_receive_bytes_total[5m])    # avg rate over 5m window (smoothed)
irate(node_network_receive_bytes_total[5m])   # instantaneous rate (spiky, last 2 points)
```
Use `rate()` for dashboards, `irate()` for alerts.

**Common queries:**
```promql
# CPU usage %
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory available %
(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# Disk usage %
100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)

# Network throughput (Mbps)
rate(node_network_receive_bytes_total{device="eth0"}[5m]) * 8 / 1e6

# HTTP probe success
probe_success{job="blackbox-http"}

# SNMP interface throughput
rate(ifHCInOctets{ifName="ether1"}[5m]) * 8   # bits/s in
rate(ifHCOutOctets{ifName="ether1"}[5m]) * 8  # bits/s out
```

**Aggregation:**
```promql
sum(rate(...)[5m])                     # total across all instances
avg by(instance)(...)                  # per-instance average
max by(job)(...)                       # highest per job
sum without(cpu)(...)                  # sum, keep all labels except "cpu"
```

## WireGuard Peer Metrics (Custom Exporter)

Script to generate metrics from `wg show` output:

```bash
#!/bin/bash
# /usr/local/bin/wg-peers-metrics.sh
# Run via systemd timer or cron, writes to node_exporter textfile dir

WG_IFACE="wg-clients"
TEXTFILE_DIR="/var/lib/node_exporter/textfile_collector"
STALE_THRESHOLD=180   # seconds — peer considered offline

echo "# HELP wireguard_peer_up 1 if last handshake within ${STALE_THRESHOLD}s" > "$TEXTFILE_DIR/wg_peers.prom.$$"
echo "# TYPE wireguard_peer_up gauge" >> "$TEXTFILE_DIR/wg_peers.prom.$$"

wg show "$WG_IFACE" dump | tail -n +2 | while IFS=$'\t' read -r pubkey preshared endpoint allowed_ips latest_handshake transfer_rx transfer_tx persistent_keepalive; do
  now=$(date +%s)
  if [ "$latest_handshake" = "0" ] || [ $((now - latest_handshake)) -gt "$STALE_THRESHOLD" ]; then
    up=0
  else
    up=1
  fi
  # Use allowed_ips as peer identifier
  echo "wireguard_peer_up{interface=\"$WG_IFACE\",allowed_ips=\"$allowed_ips\"} $up" >> "$TEXTFILE_DIR/wg_peers.prom.$$"
done

mv "$TEXTFILE_DIR/wg_peers.prom.$$" "$TEXTFILE_DIR/wg_peers.prom"
```

**GOTCHA:** don't use ICMP ping to check peer health — peers behind NAT won't respond to ping from server. Use `last-handshake` timestamp only.

## Alert Rules

```yaml
# alerts/infra.yml
groups:
  - name: infra
    rules:
      - alert: DiskSpaceHigh
        expr: 100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disk {{ $labels.instance }} at {{ $value | printf \"%.0f\" }}%"

      - alert: MemoryHigh
        expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 < 10
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Memory critically low on {{ $labels.instance }}"

      - alert: ServiceDown
        expr: probe_success == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.instance }} is down"

      - alert: SSLCertExpiringSoon
        expr: (probe_ssl_earliest_cert_expiry - time()) / 86400 < 14
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "SSL cert for {{ $labels.instance }} expires in {{ $value | printf \"%.0f\" }} days"
```

## Grafana Dashboard Design

**Panel types by use case:**
| Data | Panel |
|---|---|
| Current value (CPU %, uptime) | Stat |
| Time series (bandwidth, load) | Time series |
| Distribution (request latency) | Histogram |
| Peer online/offline over time | State timeline |
| Comparison across instances | Bar gauge |
| Table of top-N | Table |

**Variable-driven dashboards:**
```
Dashboard settings → Variables → Add:
  Name: instance
  Type: Query
  Query: label_values(node_uname_info, instance)
```
Use `$instance` in panel queries to make dashboards filterable.

**Useful transformations:**
- `Organize fields` — rename/reorder columns in Table panels
- `Reduce` — convert time series to single stat (last, max, mean)
- `Join by field` — merge multiple queries into one table

## Docker Compose Stack

```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./alerts:/etc/prometheus/alerts:ro
      - prometheus_data:/prometheus
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.retention.time=30d
    ports: ["9090:9090"]

  grafana:
    image: grafana/grafana:latest
    environment:
      GF_SECURITY_ADMIN_PASSWORD: "${GRAFANA_PASSWORD}"
      GF_USERS_ALLOW_SIGN_UP: "false"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    ports: ["3000:3000"]

  node-exporter:
    image: prom/node-exporter:latest
    network_mode: host
    pid: host
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
      - /var/lib/node_exporter:/var/lib/node_exporter:ro
    command:
      - --path.procfs=/host/proc
      - --path.sysfs=/host/sys
      - --collector.textfile.directory=/var/lib/node_exporter/textfile_collector

  blackbox-exporter:
    image: prom/blackbox-exporter:latest
    volumes:
      - ./blackbox.yml:/config/blackbox.yml:ro
    command: --config.file=/config/blackbox.yml

volumes:
  prometheus_data:
  grafana_data:
```

## Grafana Provisioning (Dashboard as Code)

```yaml
# grafana/provisioning/datasources/prometheus.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    isDefault: true
    uid: prometheus
```

```yaml
# grafana/provisioning/dashboards/default.yml
apiVersion: 1
providers:
  - name: default
    folder: Infrastructure
    type: file
    options:
      path: /etc/grafana/provisioning/dashboards/json
```

Export dashboard JSON from UI → save to `provisioning/dashboards/json/` → committed to git.

## Troubleshooting

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, health, lastError}'

# Test PromQL
curl "http://localhost:9090/api/v1/query?query=up" | jq

# Grafana API — list dashboards
curl -u admin:pass http://localhost:3000/api/search

# Alert state
curl http://localhost:9090/api/v1/alerts | jq
```

| Problem | Fix |
|---|---|
| Target `DOWN` | Check exporter running, firewall port open, scrape job config |
| `no data` in panel | Query wrong, time range too short, metric not scraped yet |
| Alert never fires | Check `for` duration, rule file loaded (`curl /api/v1/rules`), Alertmanager connected |
| Grafana login locked | `sqlite3 /var/lib/grafana/grafana.db "delete from login_attempt;"` |
| SNMP no data | Check community string, OID, SNMP version (v2c vs v3), device SNMP enabled |
