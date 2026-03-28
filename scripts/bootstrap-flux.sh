#!/usr/bin/env bash
set -euo pipefail

# Bootstrap Flux to the evilpandas-talos cluster
# This script should be run once to set up GitOps

echo "🚀 Bootstrapping Flux to evilpandas-talos cluster"
echo ""

# Check prerequisites
if ! command -v flux &> /dev/null; then
    echo "❌ Error: flux CLI not found"
    echo "Install with: brew install fluxcd/tap/flux"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl not found"
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Cannot connect to Kubernetes cluster"
    echo "Make sure KUBECONFIG is set correctly"
    exit 1
fi

# Get GitHub credentials
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "❌ Error: GITHUB_TOKEN not set"
    echo "Export your GitHub personal access token:"
    echo "  export GITHUB_TOKEN=ghp_xxxxxxxxxxxx"
    exit 1
fi

if [ -z "${GITHUB_USER:-}" ]; then
    read -p "GitHub username: " GITHUB_USER
    export GITHUB_USER
fi

GITHUB_REPO="${GITHUB_REPO:-talos-cluster-infrastructure}"

echo ""
echo "Configuration:"
echo "  GitHub User: $GITHUB_USER"
echo "  GitHub Repo: $GITHUB_REPO"
echo "  Cluster Path: clusters/evilpandas-talos"
echo ""

# Pre-flight check
echo "🔍 Running pre-flight checks..."
flux check --pre

echo ""
read -p "Continue with bootstrap? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Aborted"
    exit 1
fi

echo ""
echo "📦 Bootstrapping Flux..."
flux bootstrap github \
  --owner="$GITHUB_USER" \
  --repository="$GITHUB_REPO" \
  --branch=main \
  --path=clusters/evilpandas-talos \
  --personal \
  --components-extra=image-reflector-controller,image-automation-controller

echo ""
echo "✅ Flux bootstrap complete!"
echo ""
echo "Next steps:"
echo "1. Configure SOPS decryption:"
echo "   kubectl create secret generic sops-age \\"
echo "     --namespace=flux-system \\"
echo "     --from-file=age.agekey=~/.config/sops/age/keys.txt"
echo ""
echo "2. Setup Cloudflare Tunnel credentials:"
echo "   kubectl create secret generic cloudflared-credentials \\"
echo "     --namespace=cloudflare-tunnel \\"
echo "     --from-file=credentials.json=/path/to/tunnel-id.json"
echo ""
echo "3. Watch Flux reconciliation:"
echo "   flux get all --watch"
echo ""
echo "4. Check logs:"
echo "   flux logs --all-namespaces --follow"
