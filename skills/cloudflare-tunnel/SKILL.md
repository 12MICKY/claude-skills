---
name: cloudflare-tunnel
description: Use this skill for Cloudflare Tunnel (cloudflared) — zero-trust public exposure without open ports, K3s/Kubernetes HA deployment, ConfigMap-based config management, DNS automation, adding/removing service routes, and Traefik IngressRoute integration. Activate for any cloudflared setup, tunnel routing, or *.yourdomain.com exposure work.
---

# Cloudflare Tunnel

## Core Concept

Cloudflare Tunnel (`cloudflared`) creates an outbound-only connection from your server to Cloudflare's edge — no inbound ports needed. Traffic flows:

```
User → Cloudflare Edge → cloudflared daemon → your service
```

No open firewall ports. No public IP needed. Wildcard domains covered by Cloudflare Universal SSL (single-label only: `*.example.com` ✓, `*.sub.example.com` ✗).

## Initial Setup

```bash
# Install cloudflared
curl -L https://pkg.cloudflare.com/cloudflare-main.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloudflare-main.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt update && sudo apt install cloudflared

# Authenticate (browser login)
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create my-tunnel
# Saves credentials to ~/.cloudflared/<TUNNEL_ID>.json

# Create DNS CNAME pointing to tunnel
cloudflared tunnel route dns my-tunnel service.example.com
```

## Config File Structure

```yaml
# ~/.cloudflared/config.yml (or ConfigMap in K3s)
tunnel: TUNNEL_ID
credentials-file: /home/nonroot/.cloudflared/TUNNEL_ID.json

ingress:
  - hostname: app1.example.com
    service: http://localhost:3000
  - hostname: app2.example.com
    service: http://localhost:8080
  - hostname: ssh.example.com
    service: ssh://localhost:22
  - service: http_status:404   # catch-all — required at end
```

## K3s Kubernetes HA Deployment

**ConfigMap-based config (preferred over hostPath):**

```yaml
# cloudflared-config ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflared-config
  namespace: apps
data:
  config.yml: |
    tunnel: TUNNEL_ID
    credentials-file: /etc/cloudflared/creds/credentials.json
    ingress:
      - hostname: app.example.com
        service: http://app-service.apps.svc.cluster.local:3000
      - service: http_status:404
---
# Credentials Secret
apiVersion: v1
kind: Secret
metadata:
  name: cloudflared-credentials
  namespace: apps
type: Opaque
stringData:
  credentials.json: |
    {"AccountTag":"...","TunnelSecret":"...","TunnelID":"TUNNEL_ID"}
---
# Deployment — 2 replicas for HA
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
      containers:
      - name: cloudflared
        image: cloudflare/cloudflared:latest
        args: ["tunnel", "--config", "/etc/cloudflared/config/config.yml", "run"]
        volumeMounts:
        - name: config
          mountPath: /etc/cloudflared/config
        - name: creds
          mountPath: /etc/cloudflared/creds
      volumes:
      - name: config
        configMap:
          name: cloudflared-config
      - name: creds
        secret:
          secretName: cloudflared-credentials
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: cloudflared
```

**Add a new service route (K3s pattern):**
```bash
# 1. Register DNS
cloudflared tunnel route dns TUNNEL_ID newservice.example.com

# 2. Edit ConfigMap
kubectl edit cm cloudflared-config -n apps
# Add under ingress (before catch-all):
#   - hostname: newservice.example.com
#     service: http://newservice-svc.apps.svc.cluster.local:PORT

# 3. Rollout
kubectl rollout restart deployment/cloudflared -n apps
kubectl rollout status deployment/cloudflared -n apps
```

**Create K3s IngressRoute for the new service:**
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: newservice
  namespace: apps
spec:
  entryPoints: [web]
  routes:
  - match: Host(`newservice.example.com`)
    kind: Rule
    services:
    - name: newservice-svc
      port: PORT
```

## Remove a Service

```bash
# 1. Remove from ConfigMap ingress
kubectl edit cm cloudflared-config -n apps

# 2. Rollout
kubectl rollout restart deployment/cloudflared -n apps

# 3. Remove DNS record (via Cloudflare API or dashboard)
# cloudflared does not auto-delete DNS on removal
```

## DNS Automation

```bash
# Add DNS CNAME via cloudflared CLI
cloudflared tunnel route dns TUNNEL_ID subdomain.example.com

# Via Docker (no local cloudflared install)
docker run --rm \
  -v ~/.cloudflared:/home/nonroot/.cloudflared:ro \
  cloudflare/cloudflared tunnel route dns TUNNEL_ID subdomain.example.com
```

## Metrics & Health

```bash
# cloudflared metrics endpoint (port 2000 by default)
curl http://localhost:2000/metrics

# Check tunnel status
cloudflared tunnel info TUNNEL_ID
cloudflared tunnel list

# K3s — check pod status
kubectl get pods -n apps -l app=cloudflared
kubectl logs -n apps deploy/cloudflared --tail=50
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `502 Bad Gateway` | Service not running on target port | Check upstream service health |
| `1033 - Tunnel not found` | Wrong tunnel ID in credentials | Re-run `cloudflared tunnel login` + recreate |
| DNS not resolving | CNAME not propagated | Check `cloudflared tunnel route dns` output; allow 5 min TTL |
| Pod crash loop | Wrong credentials path | Verify Secret mount path matches `credentials-file` in config |
| Config changes not applied | Deployment not restarted | `kubectl rollout restart deployment/cloudflared -n apps` |

## Security Notes

- Tunnel credentials JSON contains the tunnel secret — store as Kubernetes Secret, never in ConfigMap.
- Wildcard `*.example.com` covers only single-label subdomains; multi-level like `a.b.example.com` requires explicit DNS entry.
- Use Cloudflare Zero Trust Access policies to add auth (SSO, email OTP) in front of any tunnel service.
- No inbound firewall rules needed — all traffic is outbound from your server to Cloudflare.
