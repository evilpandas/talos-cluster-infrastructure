# Talos Cluster Infrastructure

GitOps repository for managing the `evilpandas-talos` Kubernetes cluster infrastructure.

## Overview

This repository contains all cluster-wide infrastructure components managed via FluxCD:

- **Operators**: cert-manager, ingress-nginx, CloudNativePG, external-secrets
- **Monitoring**: Prometheus, Grafana, Loki, Alertmanager
- **Security**: Network policies, Pod Security Admission
- **Tenants**: GitOps links to application repositories

## Cluster Information

- **Cluster Name**: evilpandas-talos
- **Kubernetes Version**: 1.35.3
- **OS**: Talos Linux (immutable)
- **Storage**: Longhorn
- **GitOps**: FluxCD

## Repository Structure

```
.
├── clusters/
│   └── evilpandas-talos/        # Cluster-specific configs
│       ├── flux-system/          # Flux bootstrap (auto-generated)
│       ├── infrastructure.yaml   # Infrastructure kustomizations
│       └── tenants.yaml          # Tenant app kustomizations
│
├── infrastructure/
│   ├── controllers/              # Operators and controllers
│   │   ├── cert-manager/         # TLS certificate management
│   │   ├── ingress-nginx/        # Ingress controller
│   │   ├── cloudnative-pg/       # PostgreSQL operator
│   │   └── external-secrets/     # External secrets sync
│   │
│   ├── monitoring/               # Observability stack
│   │   ├── prometheus-stack/     # Prometheus + Grafana
│   │   └── loki-stack/           # Log aggregation
│   │
│   ├── security/                 # Security policies
│   │   ├── network-policies/
│   │   └── pod-security/
│   │
│   └── configs/                  # Cluster-wide configs
│       ├── cluster-issuer.yaml
│       └── resource-quotas.yaml
│
├── tenants/                      # Links to tenant repos
│   ├── evil-downloader.yaml
│   ├── homepage.yaml
│   ├── uptime-kuma.yaml
│   └── README.md
│
└── scripts/                      # Helper scripts
    ├── bootstrap-flux.sh
    └── README.md
```

## Bootstrap Process

### Prerequisites

```bash
# Install required tools
brew install fluxcd/tap/flux kubectl age sops

# Generate Age key for SOPS
age-keygen -o ~/.config/sops/age/keys.txt

# Get your cluster kubeconfig
# Via Omni: Download from UI
# Via talosctl: talosctl kubeconfig
export KUBECONFIG=~/.kube/config
```

### Initial Bootstrap

```bash
# Set GitHub credentials
export GITHUB_TOKEN=<your-github-token>
export GITHUB_USER=<your-username>

# Bootstrap Flux
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=talos-cluster-infrastructure \
  --branch=main \
  --path=clusters/evilpandas-talos \
  --personal \
  --components-extra=image-reflector-controller,image-automation-controller
```

### Configure SOPS Decryption

```bash
# Store Age private key in cluster
cat ~/.config/sops/age/keys.txt | \
  kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=/dev/stdin
```

## Adding New Tenants

1. Create tenant configuration in `tenants/<app-name>.yaml`
2. Add GitRepository pointing to app repo
3. Add Kustomization for app deployment
4. Commit and push

Example:
```yaml
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
  path: ./kubernetes/production
  prune: true
```

## Day-to-Day Operations

### Check Status
```bash
# Overall status
flux get all

# Check specific component
flux get kustomizations
flux get helmreleases -A

# View logs
flux logs -f
```

### Force Reconciliation
```bash
# Reconcile everything
flux reconcile source git flux-system

# Reconcile specific kustomization
flux reconcile kustomization infrastructure-controllers
```

### Suspend/Resume
```bash
# Suspend (for maintenance)
flux suspend kustomization <name>

# Resume
flux resume kustomization <name>
```

## Monitoring

- **Grafana**: https://grafana.evilpandas.com (via ingress)
- **Prometheus**: https://prometheus.evilpandas.com
- **Alertmanager**: https://alertmanager.evilpandas.com

## Secrets Management

This repository uses **SOPS** with **Age** for encrypting secrets.

### Encrypt a Secret
```bash
# Create secret
kubectl create secret generic my-secret \
  --from-literal=key=value \
  --dry-run=client -o yaml > secret.yaml

# Encrypt with SOPS
sops --encrypt secret.yaml > secret.enc.yaml

# Commit encrypted version
git add secret.enc.yaml
git commit -m "Add secret"
git push
```

### Configuration
Create `.sops.yaml` in repo root:
```yaml
creation_rules:
  - path_regex: .*\.enc\.yaml$
    age: age1234... # Your public key
```

## Troubleshooting

### Flux Not Syncing
```bash
# Check Flux system
kubectl get pods -n flux-system

# Check reconciliation
flux get sources git
flux get kustomizations

# View logs
flux logs --all-namespaces --follow
```

### SOPS Decryption Failing
```bash
# Verify Age key exists
kubectl get secret sops-age -n flux-system

# Check decryption
kubectl logs -n flux-system -l app=kustomize-controller -f | grep -i sops
```

### Infrastructure Not Deploying
```bash
# Check dependencies
kubectl describe kustomization -n flux-system

# Validate locally
flux build kustomization infrastructure-controllers \
  --path infrastructure/controllers
```

## Documentation

- [FluxCD Documentation](https://fluxcd.io/docs/)
- [CloudNativePG](https://cloudnative-pg.io/documentation/)
- [Talos Linux](https://www.talos.dev/)

## Support

For issues with this infrastructure, check the FluxCD logs and Kubernetes events.
