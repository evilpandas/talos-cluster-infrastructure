# Tenants

This directory contains GitOps configurations for tenant applications.

## What Goes Here

Each tenant application gets its own file with:
1. **GitRepository** - Points to the app's Git repository
2. **Kustomization(s)** - Deploys the app's Kubernetes manifests

## Structure

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/username/my-app
  ref:
    branch: main

---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: my-app
  path: ./kubernetes
  prune: true
```

## Current Tenants

- **evil-downloader** - YouTube downloader app (dlp.evilpandas.com)

## Adding New Tenant

1. Create new file: `tenants/my-app.yaml`
2. Add GitRepository pointing to app repo
3. Add Kustomization for deployment
4. Update Cloudflare Tunnel config to route traffic
5. Commit and push - Flux will automatically deploy

## Gateway API Routes

Tenant apps should use HTTPRoute resources (not Ingress):

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
  namespace: my-app
spec:
  parentRefs:
    - name: evilpandas-gateway
      namespace: ingress-nginx
  hostnames:
    - my-app.evilpandas.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: my-app
          port: 80
```

## Dependencies

Apps can depend on infrastructure being ready:

```yaml
spec:
  dependsOn:
    - name: infrastructure-controllers  # Wait for operators
    - name: infrastructure-configs      # Wait for Gateway
```
