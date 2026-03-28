# Quick Start Guide

Get your evilpandas-talos cluster up and running with GitOps and Gateway API.

## Overview

This infrastructure uses:
- ✅ **Gateway API** (modern networking, not old Ingress API)
- ✅ **FluxCD** for GitOps
- ✅ **Cloudflare Tunnel** for internet exposure (no port forwarding!)
- ✅ **CloudNativePG** for PostgreSQL
- ✅ **Flannel CNI** (already installed on Talos)
- ✅ **Longhorn** for storage

## Prerequisites

```bash
# Install required tools
brew install fluxcd/tap/flux kubectl age sops cloudflare/cloudflare/cloudflared

# Verify cluster access
export KUBECONFIG=~/.kube/config
kubectl get nodes
```

## Step 1: Bootstrap Flux

```bash
# Set GitHub credentials
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
export GITHUB_USER=your-username

# Run bootstrap script
cd ~/code/talos-cluster-infrastructure
./scripts/bootstrap-flux.sh
```

This installs Flux and configures it to watch this repo.

## Step 2: Setup SOPS Encryption

```bash
# Generate Age key (if you haven't already)
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# Get your public key
grep "public key:" ~/.config/sops/age/keys.txt

# Update .sops.yaml with your public key
# Replace age1xxxxxxxxx... with your actual key

# Store private key in cluster (for Flux to decrypt secrets)
cat ~/.config/sops/age/keys.txt | \
  kubectl create secret generic sops-age \
    --namespace=flux-system \
    --from-file=age.agekey=/dev/stdin
```

## Step 3: Setup Cloudflare Tunnel

### Create Tunnel
```bash
# Login to Cloudflare
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create evilpandas-talos

# Note the tunnel ID from output
# Example: Created tunnel evilpandas-talos with id abc123-def456-...
```

### Configure Tunnel
```bash
# Get tunnel ID (from previous step)
TUNNEL_ID="abc123-def456-..."

# Create secret in cluster
kubectl create secret generic cloudflared-credentials \
  --namespace=cloudflare-tunnel \
  --from-file=credentials.json=$HOME/.cloudflared/${TUNNEL_ID}.json

# Update config file
# Edit: infrastructure/controllers/cloudflare-tunnel/config.yaml
# Replace <your-tunnel-id> with your actual tunnel ID
```

### Route DNS
```bash
# Route each domain to tunnel
cloudflared tunnel route dns evilpandas-talos dlp.evilpandas.com
cloudflared tunnel route dns evilpandas-talos home.evilpandas.com
cloudflared tunnel route dns evilpandas-talos status.evilpandas.com
cloudflared tunnel route dns evilpandas-talos grafana.evilpandas.com
```

## Step 4: Commit and Push

```bash
git add .
git commit -m "feat: configure cluster infrastructure"
git push
```

Flux will automatically sync and deploy everything!

## Step 5: Watch Deployment

```bash
# Watch Flux reconciliation
flux get all --watch

# Check pods
kubectl get pods -A

# View logs
flux logs --all-namespaces --follow
```

## Architecture

```
Internet (users)
    ↓
Cloudflare Edge (DDoS protection, TLS termination)
    ↓
Cloudflare Tunnel (encrypted connection to cluster)
    ↓
ingress-nginx (Gateway API implementation)
    ↓
HTTPRoute resources (per-app routing)
    ↓
Your Services (evil-downloader, homepage, etc)
```

## Adding New Apps

### 1. Create HTTPRoute in App Repo

```yaml
# In your app repo: kubernetes/httproute.yaml
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

### 2. Add Tenant Config

```bash
# In infrastructure repo: tenants/my-app.yaml
cat > tenants/my-app.yaml <<EOF
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/your-username/my-app
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
EOF

git add tenants/my-app.yaml
git commit -m "feat: add my-app tenant"
git push
```

### 3. Update Cloudflare Tunnel

```bash
# Add to infrastructure/controllers/cloudflare-tunnel/config.yaml
# Under ingress: section, add:
- hostname: my-app.evilpandas.com
  service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80

# Route DNS
cloudflared tunnel route dns evilpandas-talos my-app.evilpandas.com

# Commit and push
git add infrastructure/controllers/cloudflare-tunnel/config.yaml
git commit -m "feat: add my-app to tunnel"
git push
```

## Useful Commands

### Flux
```bash
# Status
flux get all

# Force sync
flux reconcile source git flux-system

# Logs
flux logs -f
```

### Gateway API
```bash
# View Gateway
kubectl get gateway -n ingress-nginx

# View all routes
kubectl get httproute -A

# Describe route
kubectl describe httproute my-app -n my-app
```

### Cloudflare Tunnel
```bash
# List tunnels
cloudflared tunnel list

# Check tunnel logs
kubectl logs -n cloudflare-tunnel -l app=cloudflared -f
```

### PostgreSQL
```bash
# Check clusters
kubectl get cluster -n evil-downloader

# Status
kubectl cnpg status evil-downloader-pg -n evil-downloader

# Connect
kubectl cnpg psql evil-downloader-pg -n evil-downloader
```

## Troubleshooting

### Flux Not Syncing
```bash
kubectl get pods -n flux-system
flux get sources git
kubectl logs -n flux-system deployment/source-controller -f
```

### Gateway API Routes Not Working
```bash
# Check Gateway status
kubectl get gateway evilpandas-gateway -n ingress-nginx -o yaml

# Check HTTPRoute status
kubectl describe httproute my-app -n my-app

# Check ingress-nginx logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f
```

### Cloudflare Tunnel Issues
```bash
# Check tunnel pods
kubectl get pods -n cloudflare-tunnel

# View logs
kubectl logs -n cloudflare-tunnel -l app=cloudflared -f

# Test connectivity
kubectl exec -n cloudflare-tunnel deployment/cloudflared -- \
  wget -O- http://ingress-nginx-controller.ingress-nginx.svc.cluster.local
```

## Next Steps

1. ✅ Bootstrap infrastructure (Flux, Gateway API, Cloudflare Tunnel)
2. ✅ Setup PostgreSQL with CloudNativePG
3. ✅ Deploy your first app (evil-downloader)
4. ✅ Add monitoring (Prometheus + Grafana)
5. ✅ Add more apps (homepage, uptime-kuma, etc)

## Documentation

- [Gateway API Guide](infrastructure/configs/GATEWAY_API_GUIDE.md)
- [Cloudflare Tunnel Setup](infrastructure/controllers/cloudflare-tunnel/README.md)
- [Tenant Management](tenants/README.md)
- [GitOps Guide](../evil-yt-dlp/docs/GITOPS_SETUP_GUIDE.md)

## Support

Check Flux status and logs first:
```bash
flux check
flux get all
flux logs -f
```

For infrastructure issues, examine the affected namespace/controller.
