# Rancher Desktop Spark Operator Control Plane (on macOS)

This repository provisions a **local Apache Spark control plane** on **macOS** using **Rancher Desktop (k3s)**.  
It is designed for **local development, experimentation, demos, and architecture validation** of Spark-on-Kubernetes workflows — **not** for production use.

The stack includes:

- Rancher Desktop (k3s)
- Spark Operator
- Spark History Server (with S3A support)
- MinIO (S3-compatible object storage)
- Traefik Ingress
- Local DNS via `/etc/hosts` or `sslip.io`
- Custom Spark image with S3A libraries (hosted on Quay.io)

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Cluster Components](#cluster-components)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Building Custom Spark S3A Image](#building-custom-spark-s3a-image)
- [Deployment](#deployment)
- [Validation](#validation)
- [Troubleshooting](#troubleshooting)
- [Makefile Commands](#makefile-commands)

---

## Architecture Overview

**Purpose:**  
Provide a **Spark-native Kubernetes control plane** where:

- Spark jobs are submitted via the Spark Operator
- Event logs are written to MinIO (S3-compatible)
- Spark History Server reads logs from MinIO using S3A
- UIs are accessible from macOS via browser

### High-Level Flow

1. Developer submits `SparkApplication` CRDs
2. Spark Operator launches driver/executor pods
3. Spark event logs are written to MinIO using S3A
4. Spark History Server reads logs from MinIO
5. Traefik routes browser traffic to Spark and MinIO UIs

---

## Cluster Components

### Kubernetes Runtime
- **Rancher Desktop**
- Kubernetes distribution: **k3s**
- Container runtime: **containerd**

### Spark Operator
- Manages Spark workloads using CRDs:
    - `SparkApplication`
    - `ScheduledSparkApplication`
- Namespace: `spark-operator`

### MinIO
- Acts as **S3-compatible object storage**
- Stores Spark event logs
- Namespace: `minio`
- Services:
    - `minio` (API – port `9000`)
    - `minio-console` (UI – port `9001`)

### Spark History Server
- Runs as a Kubernetes Deployment
- Uses **custom Spark image** with S3A support
- Reads logs from MinIO via `s3a://`
- Namespace: `spark-history`
- Exposes UI on port `18080`
- Image: `quay.io/mpwbaruk/spark-s3a:3.5.4`

### Ingress
- Controller: **Traefik** (default with k3s)
- Exposes:
    - MinIO Console: `http://minio-console.192.168.64.3.sslip.io`
    - Spark History Server: `http://spark-history.192.168.64.3.sslip.io`

---
## Platform Scope & Non-Goals

This repository intentionally focuses on **platform enablement**, not application or data pipeline development.

### In Scope
- Kubernetes-native **compute orchestration** for analytics workloads
- Declarative workload submission via **CRDs** (SparkOperator)
- **Auditability and observability** of compute execution (Spark History)
- **Object storage abstraction** using S3-compatible APIs
- Ingress, DNS, and UI exposure patterns consistent with enterprise platforms
- Infrastructure-as-Code with Terraform for repeatability and control

### Explicitly Out of Scope
- ETL pipelines, DAGs, or business logic
- Data modeling or schema design
- Notebook authoring or interactive analytics
- End-user Spark application code

## Enterprise & Regulated Environment Considerations

Although this deployment targets local development, the architecture and patterns
are intentionally aligned with **regulated enterprise environments** such as
financial services.

Key considerations reflected in this design:

- **Clear trust boundaries**
    - Dedicated namespaces per platform service
    - Ingress explicitly defined per UI
- **Auditability**
    - Spark event logs persisted to object storage
    - History Server provides immutable execution visibility
- **Deterministic infrastructure**
    - Terraform-managed lifecycle
    - No imperative `kubectl apply` workflows
- **Security-first defaults**
    - No implicit cluster-wide access for workloads
    - Separation between control plane and user workloads

These patterns map directly to controls commonly required for
SOX, PCI-DSS, and internal risk governance reviews.

## Multi-Tenancy & Platform Evolution

This control plane is designed to evolve into a **multi-tenant data platform**
without architectural refactoring.

Planned and supported extensions include:

- **Namespace-per-tenant isolation**
  - Resource quotas
  - LimitRanges
  - RBAC boundaries
- **Advanced scheduling**
  - YuniKorn or Volcano for batch and AI workloads
- **Security & Identity**
  - OIDC integration (Keycloak / enterprise IdP)
  - Fine-grained authorization (Ranger / OPA)
- **GitOps workflows**
  - ArgoCD or Flux managing Terraform and manifests
  - Promotion via Git instead of imperative changes
- **Observability**
  - Prometheus metrics for Spark workloads
  - OpenSearch for log aggregation and audit search

The current implementation serves as a **validated control-plane prototype**
for these capabilities.

## Prerequisites

### macOS
- macOS (Apple Silicon or Intel)
- Admin privileges (required for `/etc/hosts`)

### Required Tools

Install using Homebrew:

```bash
brew install kubectl helm terraform docker
```

### Rancher Desktop

- Installed manually (assumed)
- Kubernetes **enabled**
- Runtime: **containerd**
- Kubernetes distribution: **k3s**

### Quay.io Account

- Account: `mpwbaruk`
- Robot account: `mpwbaruk+mpwrobot` (with Write permissions)
- Repository: `quay.io/mpwbaruk/spark-s3a` (Public)

---

## Quick Start

### 1. Clone and Setup

```bash
cd rd-spark-control-plane
make perm  # Make scripts executable
```

### 2. Build Custom Spark Image (First Time Only)

The default Apache Spark image lacks S3A libraries. Build a custom image:

```bash
# Login to Quay.io
docker login quay.io -u "mpwbaruk+mpwrobot"
# Enter your robot token when prompted

# Build and push image
make docker-all
```

This creates `quay.io/mpwbaruk/spark-s3a:3.5.4` with Hadoop AWS and S3A support.

### 3. Deploy Infrastructure

```bash
make up
```

This will:
- Refresh kubeconfig
- Set kubectl context
- Run `terraform apply`

### 4. Verify Deployment

```bash
make validate
```

### 5. Access UIs

- **MinIO Console**: http://minio-console.192.168.64.3.sslip.io
  - Username: `minioadmin`
  - Password: (from your terraform vars)

- **Spark History**: http://spark-history.192.168.64.3.sslip.io

---

## Building Custom Spark S3A Image

### Why a Custom Image?

The official `apache/spark:3.5.4` image doesn't include Hadoop AWS libraries needed for S3A filesystem support. Without these, Spark History Server crashes with:

```
ClassNotFoundException: Class org.apache.hadoop.fs.s3a.S3AFileSystem not found
```

### What's Included

The custom image adds:
- `hadoop-aws-3.3.4.jar` - Hadoop AWS support
- `aws-java-sdk-bundle-1.12.262.jar` - AWS SDK

### Build Process

#### Files Required

- `Dockerfile` - Builds Spark with S3A support
- `Makefile` - Build automation

#### Project Structure

```
rd-spark-control-plane/
├── Makefile                # Build and deployment automation
├── Dockerfile             # Custom Spark image with S3A
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── ...
└── scripts/
    ├── rd-kubeconfig.sh
    ├── rd-down.sh
    └── ...
```

#### Build Commands

**Option 1: All-in-one (recommended)**
```bash
make docker-all
```

**Option 2: Step-by-step**
```bash
make docker-build    # Build the image locally
make docker-test     # Verify S3A JARs are present
make docker-login    # Login to Quay.io
make docker-push     # Push to Quay.io
```

#### Verify on Quay.io

Go to: https://quay.io/repository/mpwbaruk/spark-s3a

You should see tags:
- `3.5.4`
- `latest`

### Using the Image in Terraform

The Spark History Server deployment uses this image:

```hcl
resource "kubernetes_deployment_v1" "spark_history" {
  # ... other config ...
  
  spec {
    template {
      spec {
        container {
          name  = "spark-history"
          image = "quay.io/mpwbaruk/spark-s3a:3.5.4"
          # ... rest of config ...
        }
      }
    }
  }
}
```

---

## Deployment

### Using Makefile (Recommended)

```bash
# Full deployment
make up

# Or step-by-step:
make kubeconfig    # Refresh kubeconfig
make ctx           # Set kubectl context
make tf-init       # Initialize Terraform
make tf-plan       # Preview changes
make tf-apply      # Deploy
```

### Manual Deployment

```bash
cd terraform
terraform init
terraform apply
```

### Teardown

```bash
make down          # Destroy infrastructure and stop Rancher Desktop
```

Or just destroy infrastructure:
```bash
make tf-destroy
```

---

## Validation

### Quick Validation

```bash
make validate
```

This checks:
- Spark Operator namespace and pods
- MinIO namespace and pods
- Spark History namespace and pods
- Ingress configuration

### Manual Validation

#### Verify Node

```bash
kubectl get nodes
```

Expected output:
```
NAME                  STATUS   ROLE           AGE   VERSION
lima-rancher-desktop  Ready    control-plane  1h    v1.28.x
```

#### Spark Operator

```bash
kubectl get ns spark-operator
kubectl get pods -n spark-operator
kubectl get crd | grep spark
```

Expected CRDs:
- `sparkapplications.sparkoperator.k8s.io`
- `scheduledsparkapplications.sparkoperator.k8s.io`

#### MinIO

```bash
kubectl get ns minio
kubectl -n minio get pods,svc
kubectl -n minio get ingress
```

Expected:
- Pod: `minio-0` (Running)
- Service: `minio` (ClusterIP, port 9000)
- Service: `minio-console` (ClusterIP, port 9001)

#### Spark History Server

```bash
kubectl get pods -n spark-history
kubectl get svc -n spark-history
kubectl logs -n spark-history -l app=spark-history
```

Expected:
- Pod: `spark-history-xxxxx` (Running, 1/1 Ready)
- No `CrashLoopBackOff` errors
- Logs show: "HistoryServer started"

### Access UIs

#### Via Ingress (Recommended)

- MinIO Console: http://minio-console.192.168.64.3.sslip.io
- Spark History: http://spark-history.192.168.64.3.sslip.io

#### Via Port Forward

```bash
# MinIO Console
kubectl -n minio port-forward svc/minio-console 9001:9001

# Spark History
kubectl -n spark-history port-forward svc/spark-history 18080:18080
```

Then access:
- MinIO: http://localhost:9001
- Spark History: http://localhost:18080

---

## Troubleshooting

### Spark History Server - CrashLoopBackOff

**Symptom:**
```bash
kubectl get pods -n spark-history
NAME                            READY   STATUS             RESTARTS   AGE
spark-history-xxxxx-xxxxx       0/1     CrashLoopBackOff   5          3m
```

**Cause:** Missing S3A libraries in the Spark image.

**Solution:**
1. Build and push custom image: `make docker-all`
2. Verify image exists on Quay.io
3. Redeploy: `make tf-apply`

### MinIO - CrashLoopBackOff

**Symptom:**
```bash
kubectl get pods -n minio
NAME      READY   STATUS             RESTARTS   AGE
minio-0   0/1     CrashLoopBackOff   3          2m
```

**Cause:** Missing `mode: standalone` configuration for single-replica deployment.

**Solution:** Check `terraform/main.tf` includes:
```hcl
resource "helm_release" "minio" {
  set = [
    {
      name  = "mode"
      value = "standalone"
    },
    # ... other config
  ]
}
```

### DNS Not Resolving

**Symptom:** Browser can't reach `http://spark-history.192.168.64.3.sslip.io`

**Solution 1: Use sslip.io (automatic)**

sslip.io should work automatically. Test:
```bash
nslookup spark-history.192.168.64.3.sslip.io
```

**Solution 2: Add to /etc/hosts (manual)**

```bash
sudo sh -c 'echo "192.168.64.3 spark-history.192.168.64.3.sslip.io" >> /etc/hosts'
sudo sh -c 'echo "192.168.64.3 minio-console.192.168.64.3.sslip.io" >> /etc/hosts'
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Docker Login Issues

**Symptom:** `unauthorized: access to the requested resource is not authorized`

**Solution:**
```bash
docker logout quay.io
docker login quay.io -u "mpwbaruk+mpwrobot"
# Enter robot token when prompted
```

Verify robot account has **Write** permissions to `spark-s3a` repository.

### Image Pull Errors in Kubernetes

**Symptom:** `ImagePullBackOff` or `ErrImagePull`

**Solution:**
1. Verify repository is **Public** in Quay.io:
   - Go to https://quay.io/repository/mpwbaruk/spark-s3a?tab=settings
   - Set "Repository Visibility" to "Public"

2. Verify image exists:
   ```bash
   docker pull quay.io/mpwbaruk/spark-s3a:3.5.4
   ```

### Terraform State Issues

**Symptom:** Terraform errors about state lock or inconsistencies

**Solution:**
```bash
make clean-lock    # Remove .terraform and lockfile
make tf-init       # Reinitialize
```

---

## Makefile Commands

### Kubernetes / Deployment

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make perm` | Make scripts executable |
| `make kubeconfig` | Refresh kubeconfig from Rancher Desktop |
| `make ctx` | Set kubectl context to `rd` |
| `make tf-init` | Initialize Terraform |
| `make tf-plan` | Preview Terraform changes |
| `make tf-apply` | Deploy infrastructure |
| `make tf-destroy` | Destroy infrastructure |
| `make up` | Full deployment (kubeconfig + terraform apply) |
| `make down` | Teardown (destroy + stop Rancher Desktop) |
| `make status` | Show cluster status (nodes, namespaces, pods) |
| `make validate` | Verify all components are running |
| `make clean-lock` | Remove Terraform lock files |

### Docker Image Build

| Command | Description |
|---------|-------------|
| `make docker-build` | Build Spark S3A image |
| `make docker-test` | Test image locally (verify S3A JARs) |
| `make docker-login` | Login to Quay.io |
| `make docker-push` | Build and push to Quay.io |
| `make docker-all` | Login, build, test, and push (full workflow) |

### Typical Workflows

**First time setup:**
```bash
make docker-all    # Build and push custom image
make up            # Deploy everything
make validate      # Verify it works
```

**Daily development:**
```bash
make status        # Check cluster
make validate      # Verify components
```

**Teardown:**
```bash
make down          # Stop everything
```

**Rebuild image after changes:**
```bash
make docker-build
make docker-push
make tf-apply      # Redeploy with new image
```

---

## Local DNS Configuration (macOS)

Rancher Desktop runs Kubernetes inside a VM (lima). macOS does not automatically resolve ingress hostnames.

### Option 1: sslip.io (Automatic)

The ingress hostnames use `sslip.io` which automatically resolves to the IP embedded in the hostname:
- `spark-history.192.168.64.3.sslip.io` → `192.168.64.3`
- `minio-console.192.168.64.3.sslip.io` → `192.168.64.3`

This should work without configuration.

### Option 2: /etc/hosts (Manual)

If sslip.io doesn't work on your network:

```bash
sudo sh -c 'echo "192.168.64.3 spark-history.192.168.64.3.sslip.io" >> /etc/hosts'
sudo sh -c 'echo "192.168.64.3 minio-console.192.168.64.3.sslip.io" >> /etc/hosts'
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Finding Your Cluster IP

If `192.168.64.3` doesn't work, find your actual cluster IP:

```bash
kubectl get nodes -o wide
```

Look for the `INTERNAL-IP` column and update the DNS configuration accordingly.

---

## Project Structure

```
rd-spark-control-plane/
├── Makefile                      # Build and deployment automation
├── Dockerfile                   # Custom Spark image with S3A support
├── README.md                    # This file
├── terraform/
│   ├── main.tf                  # Main Terraform configuration
│   ├── variables.tf             # Variable definitions
│   ├── outputs.tf               # Output definitions
│   └── versions.tf              # Provider versions
└── scripts/
    ├── rd-kubeconfig.sh         # Refresh kubeconfig script
    └── rd-down.sh               # Stop Rancher Desktop script
```

---

## Architecture Decisions

### Why Custom Spark Image?

The official Apache Spark Docker images don't include Hadoop AWS libraries by default. These are required for S3A filesystem support to connect to MinIO. Building a custom image ensures:
- Consistent S3A support across all Spark components
- No runtime JAR downloads (faster startup)
- Version compatibility between Hadoop AWS and Spark

### Why MinIO Instead of Cloud S3?

MinIO provides:
- **Local development** without cloud costs
- **Offline development** capability
- **S3-compatible API** for easy cloud migration
- **Fast iteration** without network latency

### Why Rancher Desktop?

- **Native macOS integration** (better than Docker Desktop for K8s)
- **k3s distribution** (lightweight, fast)
- **Built-in Traefik** ingress controller
- **Easy to reset** and rebuild

---

## Next Steps

1. **Submit Spark Jobs:** Create `SparkApplication` CRDs and submit to the cluster
2. **Monitor in History Server:** View completed jobs in Spark History UI
3. **Explore MinIO:** Check event logs in MinIO console
4. **Scale Up:** Adjust resources in `terraform/main.tf` as needed

---

## Contributing

This is a local development environment. Contributions welcome:
- Bug fixes
- Documentation improvements
- Additional automation scripts
- Alternative deployment methods

---

## License

MIT License - see LICENSE file for details

---

## Support

For issues:
1. Check [Troubleshooting](#troubleshooting) section
2. Run `make validate` to verify component status
3. Check pod logs: `kubectl logs -n <namespace> <pod-name>`
4. Review Terraform state: `cd terraform && terraform show`
