---
name: cloudflare-tunnel
description: Use this skill for Cloudflare Tunnel (cloudflared) setup and management — creating tunnels, routing services via ingress rules, DNS record automation, K3s/Docker deployment, ConfigMap-based config, and zero-trust access. Activate when exposing local services to the internet without open ports.
---

# Cloudflare Tunnel

## How It Works

Cloudflared creates an outbound-only connection from your server to Cloudflare's edge — no inbound ports needed. Traffic flows: user → Cloudflare edge → tunnel → local service.

**Zero open ports required.** Works behind NAT, CGNAT, and restrictive firewalls.

## Create Tunnel

```bash
# Authenticate
cloudflared tunnel login

# Create tunnel (generates credentials file)
cloudflared tunnel create my-tunnel

# List tunnels
cloudflared tunnel list

# Route DNS (creates CNAME in Cloudflare)
cloudflared tunnel route dns my-tunnel app.example.com
```

## Config File (`~/.cloudflared/config.yml`)

```yaml
tunnel: <tunnel-id>
credentials-file: /home/user/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: app.example.com
    service: http://localhost:3000
  - hostname: api.example.com
    service: http://localhost:8000
  - hostname: grafana.example.com
    service: http://localhost:3001
  - service: http_status:404   # catch-all (required)
```

Run: `cloudflared tunnel run my-tunnel`

## K3s Deployment (HA, 2 replicas)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflared-config
  namespace: apps
data:
  config.yaml: |
    tunnel: <tunnel-id>
    credentials-file: /etc/cloudflared/creds.json
    ingress:
      - hostname: app.example.com
        service: http://myapp.apps.svc.cluster.local:80
      - service: http_status:404
---
apiVersion: v1
kind: Secret
metadata:
  name: cloudflared-credentials
  namespace: apps
type: Opaque
stringData:
  creds.json: |
    <contents of tunnel-id.json>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: apps
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: cloudflared
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:latest
          args:
            - tunnel
            - --config
            - /etc/cloudflared/config.yaml
            - --metrics
            - 0.0.0.0:2000
            - run
          volumeMounts:
            - name: config
              mountPath: /etc/cloudflared/config.yaml
              subPath: config.yaml
            - name: creds
              mountPath: /etc/cloudflared/creds.json
              subPath: creds.json
      volumes:
        - name: config
          configMap:
            name: cloudflared-config
        - name: creds
          secret:
            secretName: cloudflared-credentials
```

**Add new service** without restarting from scratch:
```bash
kubectl edit cm cloudflared-config -n apps
# add new ingress entry, then:
kubectl rollout restart deployment/cloudflared -n apps
```

## Docker Deployment

```bash
docker run -d --name cloudflared \
  --restart unless-stopped \
  -v /home/user/.cloudflared:/home/nonroot/.cloudflared:ro \
  cloudflare/cloudflared tunnel run my-tunnel
```

## DNS Route Automation Script

```bash
#!/bin/bash
# Add a new hostname to tunnel
TUNNEL_ID="<tunnel-id>"
HOSTNAME="$1"   # e.g. newapp.example.com
SERVICE="$2"    # e.g. http://localhost:4000

# Register DNS
docker run --rm \
  -v /home/user/.cloudflared:/home/nonroot/.cloudflared:ro \
  cloudflare/cloudflared tunnel route dns "$TUNNEL_ID" "$HOSTNAME"

echo "Add to config.yml:"
echo "  - hostname: $HOSTNAME"
echo "    service: $SERVICE"
```

## Wildcard Domain Notes

- `*.example.com` requires Cloudflare **proxied** DNS (orange cloud)
- Wildcard covers single label only: `*.example.com` matches `app.example.com` but NOT `sub.app.example.com`
- For nested subdomains, add explicit CNAME records

## Zero Trust Access (optional)

Protect internal services with Cloudflare Access (no VPN needed):
```yaml
ingress:
  - hostname: internal.example.com
    service: http://localhost:8080
    originRequest:
      access:
        required: true
        teamName: your-team
        audTag:
          - "<aud-tag>"
```

Configure policies at `one.dash.cloudflare.com` → Zero Trust → Access → Applications.

## Troubleshooting

```bash
# Check tunnel status
cloudflared tunnel info my-tunnel

# Live logs
cloudflared tunnel run --loglevel debug my-tunnel

# Test connectivity from tunnel host
curl -v http://localhost:3000

# Metrics endpoint (when running)
curl http://localhost:2000/metrics
```

| Problem | Fix |
|---|---|
| `connection refused` on service | Service not running or wrong port in config |
| `ERR_TOO_MANY_REDIRECTS` | Cloudflare SSL set to Flexible + app also redirects to HTTPS → set SSL to Full |
| DNS not resolving | Check `cloudflared tunnel route dns` ran, CNAME exists in Cloudflare dashboard |
| Config changes not applying | Restart cloudflared after ConfigMap edit |
| HA: one pod fails, traffic drops | Ensure `replicas: 2` and `topologySpreadConstraints` across nodes |
