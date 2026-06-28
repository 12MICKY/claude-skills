---
name: k3s-kubernetes
description: Use this skill for K3s cluster operations — deploying workloads with kubectl/manifests, Traefik IngressRoute, Helm charts, persistent volumes, ConfigMaps/Secrets, namespaces, and private registry configuration. Activate when managing K3s on bare-metal or homelab nodes.
---

# K3s Kubernetes

## Cluster Setup

```bash
# Control-plane node
curl -sfL https://get.k3s.io | sh -

# Get join token
cat /var/lib/rancher/k3s/server/node-token

# Worker node
curl -sfL https://get.k3s.io | K3S_URL=https://<server-ip>:6443 K3S_TOKEN=<token> sh -

# Kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
# or copy to ~/.kube/config
```

**Private registry** (`/etc/rancher/k3s/registries.yaml` on every node):
```yaml
mirrors:
  "registry.example.com:5000":
    endpoint:
      - "http://registry.example.com:5000"
```
Restart k3s after changes: `systemctl restart k3s` (server) / `k3s-agent` (worker).

## Namespace + RBAC

```bash
kubectl create namespace apps
kubectl config set-context --current --namespace=apps
```

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deploy-bot
  namespace: apps
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deploy-bot-binding
  namespace: apps
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
subjects:
  - kind: ServiceAccount
    name: deploy-bot
    namespace: apps
```

## Deployment Pattern

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: apps
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: registry.example.com:5000/myapp:latest
          ports:
            - containerPort: 3000
          envFrom:
            - secretRef:
                name: myapp-secret
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "256Mi"
              cpu: "500m"
      imagePullSecrets:
        - name: registry-creds
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: apps
spec:
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 3000
```

## Traefik IngressRoute (K3s default ingress)

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: myapp
  namespace: apps
spec:
  entryPoints:
    - web
    - websecure
  routes:
    - match: Host(`myapp.example.com`)
      kind: Rule
      services:
        - name: myapp
          port: 80
  tls:
    certResolver: letsencrypt
```

**Cloudflare tunnel instead of Traefik TLS:** use ClusterIP service + cloudflared pointing to `http://myapp.apps.svc.cluster.local:80` — no cert management needed.

## ConfigMap and Secret

```bash
# Create from literal
kubectl create secret generic myapp-secret \
  --from-literal=DATABASE_URL=postgresql://... \
  --from-literal=API_KEY=... \
  -n apps

# Create from file
kubectl create configmap app-config --from-file=config.yaml -n apps

# Update secret (patch)
kubectl patch secret myapp-secret -n apps \
  -p '{"stringData":{"NEW_KEY":"value"}}'
```

## Persistent Volume (local-path, K3s default)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myapp-data
  namespace: apps
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 5Gi
```

Mount in pod:
```yaml
volumes:
  - name: data
    persistentVolumeClaim:
      claimName: myapp-data
volumeMounts:
  - name: data
    mountPath: /data
```

**local-path** stores data on whichever node the pod runs — pod is pinned to that node. For shared storage use NFS or Longhorn.

## Private Registry Image Pull Secret

```bash
kubectl create secret docker-registry registry-creds \
  --docker-server=registry.example.com:5000 \
  --docker-username=user \
  --docker-password=pass \
  -n apps
```

## Rolling Restart and Rollout

```bash
# Force re-pull image (same tag)
kubectl rollout restart deployment/myapp -n apps

# Watch rollout
kubectl rollout status deployment/myapp -n apps

# Rollback
kubectl rollout undo deployment/myapp -n apps
```

## Debugging

```bash
# Pod logs
kubectl logs -f deployment/myapp -n apps
kubectl logs <pod-name> --previous -n apps   # crashed pod

# Exec into running pod
kubectl exec -it <pod-name> -n apps -- bash

# Describe (events, resource issues)
kubectl describe pod <pod-name> -n apps
kubectl describe deployment myapp -n apps

# Node resource usage
kubectl top nodes
kubectl top pods -n apps

# Port-forward for local testing
kubectl port-forward svc/myapp 8080:80 -n apps
```

## Common Patterns

**DaemonSet** (run on every node — useful for monitoring agents, log collectors):
```yaml
kind: DaemonSet
spec:
  selector:
    matchLabels:
      app: node-agent
  template:
    spec:
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          effect: NoSchedule
```

**CronJob:**
```yaml
kind: CronJob
spec:
  schedule: "0 19 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: alpine
              command: ["/bin/sh", "-c", "echo backup"]
```

## Common Issues

| Symptom | Fix |
|---|---|
| ImagePullBackOff | Check `imagePullSecrets`, registry reachable, `registries.yaml` on worker nodes |
| Pod stuck Pending | `kubectl describe pod` → check events for resource constraints or PVC binding |
| IngressRoute not routing | Check `kubectl get ingressroute -n apps`, Traefik logs `kubectl logs -n kube-system -l app=traefik` |
| Node NotReady | Check `kubectl describe node`, `journalctl -u k3s-agent` on worker |
| Secret not updating | Pods cache secrets at start — rollout restart after secret change |
