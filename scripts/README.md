# Scripts

Helper scripts for managing the cluster infrastructure.

## bootstrap-flux.sh

Initial setup script to bootstrap FluxCD to the cluster.

**Usage:**
```bash
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
export GITHUB_USER=your-username
./scripts/bootstrap-flux.sh
```

This script will:
1. Check prerequisites (flux, kubectl)
2. Verify cluster connectivity
3. Bootstrap Flux to `clusters/evilpandas-talos`
4. Install image automation controllers

**Run this once** when setting up a new cluster.

## Manual Commands

### Check Flux Status
```bash
flux check
flux get all
```

### Force Reconciliation
```bash
# Reconcile everything
flux reconcile source git flux-system

# Reconcile specific kustomization
flux reconcile kustomization infrastructure-controllers
```

### View Logs
```bash
# All Flux logs
flux logs --all-namespaces --follow

# Specific controller
kubectl logs -n flux-system deployment/kustomize-controller -f
```

### Suspend/Resume
```bash
# Suspend (for maintenance)
flux suspend kustomization <name>

# Resume
flux resume kustomization <name>
```
