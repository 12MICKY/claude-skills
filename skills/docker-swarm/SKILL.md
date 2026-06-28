---
name: docker-swarm
description: Use this skill for Docker Swarm stack management — service deployment with compose files, config and secret management (immutability workaround), rolling updates, constraint-based placement, overlay networks, and registry authentication. Activate when deploying stacks to a Swarm cluster.
---

# Docker Swarm

## Cluster Setup

```bash
# Init swarm on manager
docker swarm init --advertise-addr <manager-ip>

# Get worker join token
docker swarm join-token worker

# List nodes
docker node ls

# Promote node to manager (for HA)
docker node promote <node-id>
```

## Stack Deploy

```bash
docker stack deploy -c docker-compose.yml mystack --with-registry-auth
docker stack ls
docker stack services mystack
docker stack ps mystack --no-trunc
docker stack rm mystack
```

**`--with-registry-auth`** is required when pulling from private registry — passes current node's Docker credentials to all workers.

## Compose File (Swarm mode)

```yaml
version: "3.8"
services:
  app:
    image: registry.example.com:5000/myapp:1.2.0
    deploy:
      replicas: 2
      placement:
        constraints:
          - node.labels.role == worker
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
        order: start-first        # zero-downtime: new container starts before old stops
    environment:
      - NODE_ENV=production
    configs:
      - source: app-config-v3
        target: /app/config.yaml
    secrets:
      - app-secret
    networks:
      - backend
    ports:
      - "3000:3000"

configs:
  app-config-v3:
    external: true

secrets:
  app-secret:
    external: true

networks:
  backend:
    driver: overlay
    attachable: true
```

## Configs and Secrets (Immutability Workaround)

Swarm configs and secrets are **immutable** — you cannot update them in place. Use versioned names:

```bash
# Create new version
docker config create app-config-v4 ./config.yaml
docker secret create app-secret-v2 ./secret.env

# Update compose file to reference new version, then redeploy
docker stack deploy -c docker-compose.yml mystack

# Remove old version after deploy succeeds
docker config rm app-config-v3
docker secret rm app-secret-v1
```

**Pattern:** suffix with `-v<N>` or date (`-20260628`). Automate with:
```bash
VERSION=$(date +%Y%m%d)
docker config create "app-config-$VERSION" ./config.yaml
sed -i "s/app-config-.*/app-config-$VERSION/" docker-compose.yml
docker stack deploy -c docker-compose.yml mystack
```

## Placement Constraints

```yaml
deploy:
  placement:
    constraints:
      - node.role == manager          # manager nodes only
      - node.role == worker           # worker nodes only
      - node.hostname == node-34      # specific host
      - node.labels.zone == prod      # custom label
```

Add labels to nodes:
```bash
docker node update --label-add role=worker --label-add zone=prod <node-id>
```

## Rolling Update

```bash
# Force update (re-pull same tag)
docker service update --force mystack_app

# Update image
docker service update --image registry.example.com:5000/myapp:1.3.0 mystack_app

# Scale
docker service scale mystack_app=4

# Rollback
docker service rollback mystack_app
```

## Service Logs and Debugging

```bash
# Service logs (all replicas)
docker service logs -f mystack_app

# Which node is each task on?
docker service ps mystack_app

# Inspect running container (on the specific node)
docker ps | grep myapp
docker exec -it <container-id> sh

# Check overlay network connectivity
docker run --rm --network mystack_backend alpine ping app
```

## Private Registry Auth

```bash
# Login on ALL nodes (manager + workers)
docker login registry.example.com:5000

# Or use --with-registry-auth on deploy
docker stack deploy -c docker-compose.yml mystack --with-registry-auth
```

**Credential distribution:** `--with-registry-auth` passes the manager's login token to workers via Swarm encrypted store. Still best to `docker login` on each node independently.

## Overlay Network

```bash
# Create external network (shared across stacks)
docker network create --driver overlay --attachable shared-net

# Reference in compose
networks:
  shared-net:
    external: true
```

Services on different stacks can communicate via shared overlay network using service name as DNS.

## Common Patterns

**Health check:**
```yaml
healthcheck:
  test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
  interval: 30s
  timeout: 5s
  retries: 3
  start_period: 10s
```

**Volume for persistent data:**
```yaml
volumes:
  data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /data/myapp
```

Bind mounts in Swarm are node-local — ensure service is pinned to the node with the data, or use NFS/shared volume driver.

## Common Issues

| Problem | Fix |
|---|---|
| `config already exists` | Use versioned name, create new config |
| Workers can't pull image | `docker login` on each worker or `--with-registry-auth` |
| Service stuck in `Preparing` | Node can't reach registry — check DNS, registry port |
| `no suitable node (scheduling constraints)` | Node label missing or node drained |
| `update out of sequence` | Config/secret version mismatch — check compose references latest version |
| `port already allocated` | Another service or process using the port — `docker ps`, `ss -tlnp` |
