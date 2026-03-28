# Cloudflare Tunnel Setup

Exposes cluster services to the internet via Cloudflare Tunnel (no port forwarding needed).

## Prerequisites

1. Cloudflare account with domain configured
2. `cloudflared` CLI installed locally

## Initial Setup

### Step 1: Install cloudflared locally

```bash
# macOS/Linux
brew install cloudflare/cloudflare/cloudflared

# Or download binary
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/
```

### Step 2: Login to Cloudflare

```bash
cloudflared tunnel login
```

This opens a browser for authentication and downloads credentials to `~/.cloudflared/cert.pem`.

### Step 3: Create Tunnel

```bash
# Create tunnel
cloudflared tunnel create evilpandas-talos

# Output will show:
# Tunnel credentials written to /Users/you/.cloudflared/<tunnel-id>.json
# Created tunnel evilpandas-talos with id <tunnel-id>
```

Save the **tunnel ID** - you'll need it!

### Step 4: Create Kubernetes Secret

```bash
# Get the tunnel credentials path from previous step
TUNNEL_ID="<your-tunnel-id>"
CREDS_PATH="$HOME/.cloudflared/${TUNNEL_ID}.json"

# Create secret in cluster
kubectl create secret generic cloudflared-credentials \
  --namespace=cloudflare-tunnel \
  --from-file=credentials.json=$CREDS_PATH
```

### Step 5: Update ConfigMap

Edit `config.yaml` and replace `<your-tunnel-id>` with your actual tunnel ID:

```yaml
tunnel: abc123def456  # Your actual tunnel ID
```

### Step 6: Configure DNS Routes

Route your domains to the tunnel:

```bash
# Route each hostname to tunnel
cloudflared tunnel route dns evilpandas-talos dlp.evilpandas.com
cloudflared tunnel route dns evilpandas-talos home.evilpandas.com
cloudflared tunnel route dns evilpandas-talos status.evilpandas.com
cloudflared tunnel route dns evilpandas-talos grafana.evilpandas.com
cloudflared tunnel route dns evilpandas-talos prometheus.evilpandas.com
```

**Alternative:** Add CNAME records manually in Cloudflare dashboard:

```
dlp.evilpandas.com      → <tunnel-id>.cfargotunnel.com
home.evilpandas.com     → <tunnel-id>.cfargotunnel.com
status.evilpandas.com   → <tunnel-id>.cfargotunnel.com
grafana.evilpandas.com  → <tunnel-id>.cfargotunnel.com
prometheus.evilpandas.com → <tunnel-id>.cfargotunnel.com
```

### Step 7: Deploy to Cluster

```bash
# Apply via kubectl (or let Flux sync)
kubectl apply -k infrastructure/controllers/cloudflare-tunnel/

# Check status
kubectl get pods -n cloudflare-tunnel
kubectl logs -n cloudflare-tunnel -l app=cloudflared -f
```

## Adding New Services

To expose a new service:

1. **Add to ConfigMap** (`config.yaml`):
   ```yaml
   - hostname: newapp.evilpandas.com
     service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
   ```

2. **Route DNS**:
   ```bash
   cloudflared tunnel route dns evilpandas-talos newapp.evilpandas.com
   ```

3. **Create Ingress** in app namespace:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: newapp
     namespace: newapp
   spec:
     ingressClassName: nginx
     rules:
       - host: newapp.evilpandas.com
         http:
           paths:
             - path: /
               pathType: Prefix
               backend:
                 service:
                   name: newapp
                   port:
                     number: 80
   ```

## Monitoring

Cloudflared exposes metrics on port 2000:

```bash
# Port-forward to access metrics
kubectl port-forward -n cloudflare-tunnel deployment/cloudflared 2000:2000

# View metrics
curl http://localhost:2000/metrics
```

## Troubleshooting

### Check tunnel status
```bash
# List tunnels
cloudflared tunnel list

# Get tunnel info
cloudflared tunnel info evilpandas-talos

# Check DNS routes
cloudflared tunnel route dns list
```

### Check pod logs
```bash
kubectl logs -n cloudflare-tunnel -l app=cloudflared -f
```

### Test connectivity
```bash
# Test from outside cluster
curl -v https://dlp.evilpandas.com

# Check tunnel connection
kubectl exec -n cloudflare-tunnel deployment/cloudflared -- \
  wget -O- http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
```

### Common issues

**"no such tunnel"**: Update tunnel ID in config.yaml
**"authentication failed"**: Recreate credentials secret
**"connection refused"**: Check ingress-nginx is running
**"404 not found"**: Create Ingress resource for your app

## Cloudflare Dashboard

View tunnel status and traffic:
- https://dash.cloudflare.com/ → Zero Trust → Access → Tunnels

## Security

### Enable Access Policies (Optional)

Add authentication to services via Cloudflare Access:

```yaml
# In Cloudflare dashboard: Access → Applications → Add
# Protect specific hostnames with email/SSO authentication
```

### Disable Cloudflare Proxy (Not Recommended)

If you want direct IP exposure (bypasses DDoS protection):
- In Cloudflare DNS, click orange cloud icon to turn gray

## References

- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [cloudflared GitHub](https://github.com/cloudflare/cloudflared)
