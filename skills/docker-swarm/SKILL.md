---
name: docker-swarm
description: Use this skill for Docker Swarm — stack deployment with docker-compose files, immutable config/secret versioning pattern for rolling updates, service constraints and placement, overlay networks, and Swarm maintenance. Activate for docker stack, docker service, or docker swarm commands.
---

# Docker Swarm

## Stack Deployment

```bash
# Deploy or update stack
docker stack deploy -c stack.yml mystack --with-registry-auth

# List stacks and services
docker stack ls
docker stack services mystack
docker stack ps mystack              # tasks (containers) per service

# Remove stack
docker stack rm mystack
```

## Compose File for Swarm

```yaml
version: "3.8"

services:
  app:
    image: registry.local:5000/myapp:1.0.0
    deploy:
      replicas: 2
      placement:
        constraints:
        - node.role == worker
        - node.hostname == prod-server
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
      restart_policy:
        condition: on-failure
        max_attempts: 3
    ports:
    - target: 3000
      published: 3000
      mode: ingress          # Swarm load-balanced ingress
    networks:
    - mynet
    environment:
    - APP_ENV=production
    configs:
    - source: app-config-v1
      target: /app/config.json
    secrets:
    - source: db-password-v1
      target: /run/secrets/db_password

configs:
  app-config-v1:
    external: true

secrets:
  db-password-v1:
    external: true

networks:
  mynet:
    driver: overlay
    attachable: true
```

## Immutable Config/Secret Versioning Pattern

**Problem:** Swarm configs and secrets are immutable — you can't update the content. Changing the stack file to reference a new version forces a rolling update.

**Pattern — always version with a suffix:**

```bash
# Create new config version
docker config create app-config-v2 ./config.json

# Update stack file to reference v2
sed -i 's/app-config-v1/app-config-v2/' stack.yml

# Redeploy (rolling update triggered automatically)
docker stack deploy -c stack.yml mystack

# Clean up old version after all tasks updated
docker config rm app-config-v1
```

**Secrets (same pattern):**
```bash
echo "new-secret-value" | docker secret create db-password-v2 -
# Update stack.yml: db-password-v1 → db-password-v2
docker stack deploy -c stack.yml mystack
docker secret rm db-password-v1
```

**Automation helper:**
```bash
#!/bin/bash
CONFIG_NAME="app-config"
VERSION=$(date +%Y%m%d%H%M%S)
NEW_NAME="${CONFIG_NAME}-${VERSION}"

docker config create "$NEW_NAME" ./config.json
sed -i "s|${CONFIG_NAME}-[0-9]*|${NEW_NAME}|g" stack.yml
docker stack deploy -c stack.yml mystack
echo "Deployed with $NEW_NAME"
```

## Service Management

```bash
# Force update (trigger rolling restart without image change)
docker service update --force mystack_app

# Scale a service
docker service scale mystack_app=4

# Update image
docker service update --image registry.local:5000/myapp:1.1.0 mystack_app

# Rollback a service
docker service rollback mystack_app

# Get service logs
docker service logs mystack_app --tail=100 -f

# Inspect task failures
docker service ps mystack_app --no-trunc   # shows error messages
```

## Placement Constraints

```yaml
deploy:
  placement:
    constraints:
    - node.role == manager          # only on manager nodes
    - node.role == worker           # only on worker nodes
    - node.hostname == prod-server  # specific host
    - node.labels.gpu == true       # custom node label
```

**Add custom label to node:**
```bash
docker node update --label-add gpu=true NODE_ID
docker node ls                               # get NODE_ID
```

## Overlay Networks

```bash
# Create overlay network manually
docker network create --driver overlay --attachable mynet

# Inspect network
docker network inspect mynet

# Services on same overlay network can reach each other by service name
# e.g., http://mystack_db:5432 from mystack_app
```

## Configs and Secrets Management

```bash
# Create
docker config create myconfig ./config.json
echo "secret-value" | docker secret create mypassword -

# List
docker config ls
docker secret ls

# Inspect (content only visible at creation time for secrets)
docker config inspect --pretty myconfig

# Remove (only if not used by any service)
docker config rm myconfig
docker secret rm mypassword
```

**Secret file in container:** mounted at `/run/secrets/SECRET_NAME`. Read via:
```python
with open("/run/secrets/db_password") as f:
    password = f.read().strip()
```

## Swarm Cluster Management

```bash
# Initialize swarm
docker swarm init --advertise-addr NODE_IP

# Get join tokens
docker swarm join-token worker    # for worker nodes
docker swarm join-token manager   # for manager nodes (add carefully)

# List nodes
docker node ls

# Remove a node
docker node update --availability drain NODE_ID   # gracefully drain tasks
docker swarm leave --force                         # run on the node itself
docker node rm NODE_ID                             # run on manager

# Promote/demote manager
docker node promote NODE_ID
docker node demote NODE_ID
```

**Manager quorum:** always maintain odd number of managers (1, 3, 5). Losing majority = cluster freezes. For homelab: 1 manager is fine; for HA: 3 managers minimum.

## Registry Authentication

```bash
# Login to private registry
docker login registry.local:5000

# Deploy with registry auth (reads from ~/.docker/config.json)
docker stack deploy -c stack.yml mystack --with-registry-auth
```

## Troubleshooting

```bash
# Why is a service not running?
docker service ps mystack_app --no-trunc

# Task inspect (failed task detail)
docker inspect TASK_ID

# Node resource availability
docker node inspect NODE_ID --pretty

# Service didn't update after config change
docker service update --force mystack_app   # force re-pull + restart

# Container won't start (config/secret not found)
docker config ls  # verify config name matches stack.yml exactly
```

**Common mistakes:**

| Problem | Cause | Fix |
|---|---|---|
| Config update has no effect | Configs are immutable | Create new version, update stack.yml, redeploy |
| Service stuck at `Preparing` | Image not found in registry | `docker pull` on node manually, check auth |
| Overlay network unreachable | Firewall blocking VXLAN 4789/udp | Allow UDP 4789 between all Swarm nodes |
| Task constantly fails | Bad config/secret mount | `docker service ps --no-trunc` for error message |
| Port not accessible | Swarm routing mesh only works on published ports | Verify `mode: ingress` and host firewall |

## Production Checklist

- Image tags are never `latest` — use versioned tags for rollback.
- Configs and secrets follow versioning pattern (never edit in place).
- `update_config.failure_action: rollback` on all production services.
- `restart_policy.max_attempts: 3` to avoid infinite crash loops.
- Deploy node labels for placement; never rely on hostname alone (hostnames change).
- Overlay networks use `attachable: true` only if you need manual container attachment.
