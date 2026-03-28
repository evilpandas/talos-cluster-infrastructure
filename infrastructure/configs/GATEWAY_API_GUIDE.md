# Gateway API Guide

This cluster uses **Gateway API** (the modern Kubernetes networking standard) instead of the legacy Ingress API.

## Why Gateway API?

- ✅ **Role-oriented** - Clear separation between infrastructure and app teams
- ✅ **More expressive** - Advanced routing (headers, query params, methods)
- ✅ **Type-safe** - Strongly typed, less error-prone
- ✅ **Portable** - Works across implementations (nginx, Cilium, Istio, etc.)
- ✅ **Modern** - Built-in support for HTTP/2, gRPC, WebSockets
- ✅ **Future-proof** - Kubernetes standard as of v1.29+

## Architecture

```
┌─────────────────────────────────────────┐
│ GatewayClass (nginx)                    │  ← Infrastructure team manages
│   Defines: k8s.io/ingress-nginx        │
└─────────────────────────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────────┐
│ Gateway (evilpandas-gateway)            │  ← Infrastructure team manages
│   Listeners: HTTP :80                   │
│   AllowedRoutes: All namespaces         │
└─────────────────────────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────────┐
│ HTTPRoute (per-app)                     │  ← App teams manage
│   Hostname: dlp.evilpandas.com          │
│   Rules: Path routing, backends         │
└─────────────────────────────────────────┘
```

## Core Resources

### GatewayClass
Defines which controller implements Gateways.
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx
spec:
  controllerName: k8s.io/ingress-nginx
```

### Gateway
The actual load balancer / entry point.
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: evilpandas-gateway
  namespace: ingress-nginx
spec:
  gatewayClassName: nginx
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
```

### HTTPRoute
Routes traffic to services (created by app teams).
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

## Creating Routes for Your App

### Basic HTTP Route

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: evil-downloader
  namespace: evil-downloader
spec:
  # Attach to the cluster Gateway
  parentRefs:
    - name: evilpandas-gateway
      namespace: ingress-nginx

  # Hostname(s) for this route
  hostnames:
    - dlp.evilpandas.com

  # Routing rules
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: evil-downloader-web
          port: 80
```

### Multiple Paths

```yaml
rules:
  # API routes
  - matches:
      - path:
          type: PathPrefix
          value: /api
    backendRefs:
      - name: api-service
        port: 8080

  # Static files
  - matches:
      - path:
          type: PathPrefix
          value: /static
    backendRefs:
      - name: cdn-service
        port: 80

  # Everything else
  - matches:
      - path:
          type: PathPrefix
          value: /
    backendRefs:
      - name: frontend-service
        port: 3000
```

### Header-Based Routing

```yaml
rules:
  # Route beta users to canary deployment
  - matches:
      - headers:
          - name: X-Beta-User
            value: "true"
    backendRefs:
      - name: app-canary
        port: 80

  # Everyone else to stable
  - backendRefs:
      - name: app-stable
        port: 80
```

### Method-Based Routing

```yaml
rules:
  # POST/PUT/DELETE to write service
  - matches:
      - method: POST
      - method: PUT
      - method: DELETE
    backendRefs:
      - name: write-service
        port: 8080

  # GET to read-only replicas
  - matches:
      - method: GET
    backendRefs:
      - name: read-service
        port: 8080
```

### Query Parameter Routing

```yaml
rules:
  # Route ?version=v2 to new backend
  - matches:
      - queryParams:
          - name: version
            value: v2
    backendRefs:
      - name: app-v2
        port: 80

  # Default to v1
  - backendRefs:
      - name: app-v1
        port: 80
```

### Traffic Splitting (Canary)

```yaml
rules:
  - backendRefs:
      # 90% to stable
      - name: app-stable
        port: 80
        weight: 90
      # 10% to canary
      - name: app-canary
        port: 80
        weight: 10
```

### Request Redirects

```yaml
rules:
  # Redirect HTTP to HTTPS (Cloudflare handles this)
  - matches:
      - path:
          type: PathPrefix
          value: /old-path
    filters:
      - type: RequestRedirect
        requestRedirect:
          scheme: https
          hostname: new-domain.com
          path:
            type: ReplaceFullPath
            replaceFullPath: /new-path
          statusCode: 301
```

### Request Header Manipulation

```yaml
rules:
  - matches:
      - path:
          type: PathPrefix
          value: /api
    filters:
      # Add headers
      - type: RequestHeaderModifier
        requestHeaderModifier:
          add:
            - name: X-Custom-Header
              value: "my-value"
          remove:
            - "X-Remove-This"
    backendRefs:
      - name: api-service
        port: 8080
```

### Multiple Hostnames

```yaml
hostnames:
  - dlp.evilpandas.com
  - download.evilpandas.com
  - www.dlp.evilpandas.com
rules:
  - backendRefs:
      - name: evil-downloader-web
        port: 80
```

## Migration from Ingress

### Old (Ingress)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: my-app.evilpandas.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

### New (Gateway API)
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
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

## Checking Status

```bash
# View Gateway status
kubectl get gateway -n ingress-nginx

# View all HTTPRoutes
kubectl get httproute -A

# Describe route for details
kubectl describe httproute my-app -n my-app

# Check Gateway API resources
kubectl api-resources | grep gateway
```

## Common Patterns

### WebSocket Support
```yaml
# Works automatically - no special config needed!
rules:
  - backendRefs:
      - name: websocket-service
        port: 8080
```

### gRPC Support
```yaml
# Works automatically - no special config needed!
rules:
  - backendRefs:
      - name: grpc-service
        port: 50051
```

## Troubleshooting

### Route Not Working

```bash
# Check HTTPRoute status
kubectl describe httproute my-app -n my-app

# Look for "Accepted: True" in status conditions
# If "Accepted: False", check:
# - Gateway exists
# - parentRefs are correct
# - hostnames are valid
```

### 404 Errors

```bash
# Check if route is attached to Gateway
kubectl get httproute my-app -n my-app -o yaml | grep -A5 status

# Check service exists
kubectl get svc -n my-app

# Check ingress-nginx logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f
```

## References

- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Gateway API vs Ingress](https://gateway-api.sigs.k8s.io/concepts/versioning/)
- [ingress-nginx Gateway API Support](https://kubernetes.github.io/ingress-nginx/user-guide/gateway-api/)
