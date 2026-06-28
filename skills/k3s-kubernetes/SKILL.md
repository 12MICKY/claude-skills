---
name: k3s-kubernetes
description: Use this skill for K3s Kubernetes — Deployments, Services, Traefik IngressRoute, ConfigMaps and Secrets, PersistentVolumeClaims, private registry, rolling updates, debugging pods, and namespace management. Activate for kubectl commands, K3s cluster operations, or any Kubernetes manifest work.
---

# K3s Kubernetes

## Core Resources

### Deployment
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
        image: registry.local:5000/myapp:1.0.0
        ports:
        - containerPort: 3000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: myapp-secret
              key: DATABASE_URL
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
```

### Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-svc
  namespace: apps
spec:
  selector:
    app: myapp
  ports:
  - port: 3000
    targetPort: 3000
```

### Traefik IngressRoute (K3s default ingress)
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: myapp
  namespace: apps
spec:
  entryPoints:
  - web
  routes:
  - match: Host(`myapp.example.com`)
    kind: Rule
    services:
    - name: myapp-svc
      port: 3000
```

### ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: apps
data:
  APP_ENV: production
  LOG_LEVEL: info
  config.json: |
    {
      "feature_flags": { "new_ui": true }
    }
```

### Secret
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secret
  namespace: apps
type: Opaque
stringData:
  DATABASE_URL: postgres://user:password@postgres:5432/mydb
  JWT_SECRET: your-secret-key
```

### PersistentVolumeClaim (local-path — K3s default)
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myapp-data
  namespace: apps
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  resources:
    requests:
      storage: 5Gi
```

Mount in Deployment:
```yaml
volumeMounts:
- name: data
  mountPath: /app/data
volumes:
- name: data
  persistentVolumeClaim:
    claimName: myapp-data
```

## Private Registry

**K3s registries.yaml:**
```yaml
# /etc/rancher/k3s/registries.yaml
mirrors:
  "registry.local:5000":
    endpoint:
    - "http://registry.local:5000"
```
Restart K3s after editing: `systemctl restart k3s`

**Build, tag, push:**
```bash
docker build -t myapp:1.0.0 .
docker tag myapp:1.0.0 registry.local:5000/myapp:1.0.0
docker push registry.local:5000/myapp:1.0.0
```

**imagePullPolicy:** use `Always` for `latest` tag; `IfNotPresent` for versioned tags.

## Rolling Updates

```bash
# Update image (triggers rolling update)
kubectl set image deployment/myapp myapp=registry.local:5000/myapp:1.1.0 -n apps

# Watch rollout
kubectl rollout status deployment/myapp -n apps

# Rollback
kubectl rollout undo deployment/myapp -n apps

# Rollout history
kubectl rollout history deployment/myapp -n apps
```

**Zero-downtime strategy:**
```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0    # never take a pod down before replacement is ready
      maxSurge: 1          # one extra pod during update
```

## Restart Deployments After Config Changes

```bash
kubectl rollout restart deployment/myapp -n apps
# After: ConfigMap or Secret changes don't auto-restart pods — must restart manually
```

## Debugging

```bash
# Pod status
kubectl get pods -n apps
kubectl describe pod POD_NAME -n apps   # events, image pull errors, OOMKill

# Logs
kubectl logs -n apps deploy/myapp --tail=100
kubectl logs -n apps deploy/myapp -f               # follow
kubectl logs -n apps POD_NAME -c container-name    # specific container

# Shell into running pod
kubectl exec -it POD_NAME -n apps -- /bin/sh

# Shell into debug container (if no shell in image)
kubectl debug -it POD_NAME -n apps --image=busybox --target=myapp

# Check resource usage
kubectl top pods -n apps
kubectl top nodes

# Events across namespace
kubectl get events -n apps --sort-by='.lastTimestamp'
```

**Common failure modes:**

| Status | Cause | Fix |
|---|---|---|
| `ImagePullBackOff` | Registry unreachable or wrong tag | Check `registries.yaml`, image name, push status |
| `CrashLoopBackOff` | App crashes on start | `kubectl logs` for last exit, check env/secrets |
| `Pending` | No schedulable node | `kubectl describe pod` → events: resource limits, taints |
| `OOMKilled` | Memory limit exceeded | Increase `limits.memory` or fix memory leak |
| `Error: secret not found` | Secret missing | `kubectl get secret -n apps` |

## Useful Operations

```bash
# Apply all manifests in directory
kubectl apply -f ~/k3s-manifests/apps/

# Dry run (validate without applying)
kubectl apply -f manifest.yaml --dry-run=server

# Get resource YAML
kubectl get deployment myapp -n apps -o yaml

# Port-forward for local testing
kubectl port-forward svc/myapp-svc 3000:3000 -n apps

# Copy files to/from pod
kubectl cp local-file.txt apps/POD_NAME:/app/data/

# Scale deployment
kubectl scale deployment myapp --replicas=3 -n apps

# Delete and recreate (force redeploy)
kubectl delete pod -l app=myapp -n apps   # pods restart from Deployment

# All resources in namespace
kubectl get all -n apps
```

## Namespace Management

```bash
# Create namespace
kubectl create namespace staging

# Set default namespace for context
kubectl config set-context --current --namespace=apps

# Resource quota for namespace
kubectl create quota apps-quota --hard=cpu=4,memory=8Gi -n apps
```

## K3s Cluster Operations

```bash
# K3s service control (on server/control-plane node)
systemctl status k3s
systemctl restart k3s
journalctl -u k3s -f

# K3s agent (on worker nodes)
systemctl status k3s-agent
systemctl restart k3s-agent

# Node status
kubectl get nodes -o wide

# Drain node for maintenance
kubectl drain NODE_NAME --ignore-daemonsets --delete-emptydir-data
kubectl uncordon NODE_NAME   # re-enable scheduling after maintenance

# Kubeconfig location
cat /etc/rancher/k3s/k3s.yaml
# Copy to ~/.kube/config and replace 127.0.0.1 with server IP for remote access
```

## Topology Spread (Multi-Node HA)

```yaml
# Spread pods across nodes — add to pod spec
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: kubernetes.io/hostname
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      app: myapp
```

## Anti-Patterns

- `latest` tag in production — breaks `IfNotPresent`, no rollback possible. Always use versioned tags.
- Secrets in ConfigMap — ConfigMaps are not encrypted at rest. Use Secret type.
- No resource requests/limits — pods compete unbounded; one misbehaving app OOMKills others.
- ConfigMap/Secret changes not triggering restart — add `kubectl rollout restart` to deploy pipeline.
- Storing state in pod filesystem — ephemeral; use PVC or external storage.
