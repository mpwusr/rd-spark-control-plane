# Rancher Desktop Spark Control Plane (macOS)

This repository provisions a **local Apache Spark control plane** on **macOS** using **Rancher Desktop (k3s)**.  
It is designed for **local development, experimentation, demos, and architecture validation** of Spark-on-Kubernetes workflows — **not** for production use.

The stack includes:

- Rancher Desktop (k3s)
- Spark Operator
- Spark History Server
- MinIO (S3-compatible object storage)
- Traefik Ingress
- Local DNS via `/etc/hosts` or `sslip.io`

---

## Architecture Overview

**Purpose:**  
Provide a **Spark-native Kubernetes control plane** where:

- Spark jobs are submitted via the Spark Operator
- Event logs are written to MinIO (S3-compatible)
- Spark History Server reads logs from MinIO
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
- Reads logs from MinIO via `s3a://`
- Namespace: `spark-history`
- Exposes UI on port `18080`

### Ingress
- Controller: **Traefik** (default with k3s)
- Exposes:
    - MinIO Console
    - Spark History Server

---

## Prerequisites

### macOS
- macOS (Apple Silicon or Intel)
- Admin privileges (required for `/etc/hosts`)

### Required Tools

Install using Homebrew:

```bash
brew install kubectl helm terraform
```
## Rancher Desktop

- Installed manually (assumed)
- Kubernetes **enabled**
- Runtime: **containerd**
- Kubernetes distribution: **k3s**

---

## Cluster Validation

### Verify Node

```bash
kubectl get nodes
```
Expected output:

lima-rancher-desktop   Ready   control-plane

## Spark Operator Verification
```bash
kubectl get ns spark-operator
kubectl get pods -n spark-operator
kubectl get crd | grep spark
```

Expected CRDs:

sparkapplications.sparkoperator.k8s.io

scheduledsparkapplications.sparkoperator.k8s.io

##MinIO Verification
```bash
kubectl get ns minio
kubectl -n minio get pods,svc
```
##Ingress verification
```bash
kubectl -n minio get ingress
```
##MinIO Console URL (after DNS setup):

http://minio-console.192.168.64.3.sslip.io

##Spark History Server
```bash
kubectl get pods -n spark-history
kubectl get svc -n spark-history
```
##Access UI
Via Ingress
http://spark-history.192.168.64.3.sslip.io

Via Port Forward
```bash
kubectl -n spark-history port-forward svc/spark-history 18080:18080
```
##Local DNS Configuration (macOS)

Rancher Desktop runs Kubernetes inside a VM.
macOS does not automatically resolve ingress hostnames.

Recommended: /etc/hosts
```bash
sudo sh -c 'echo "192.168.64.3 spark-history.192.168.64.3.sslip.io" >> /etc/hosts'
sudo sh -c 'echo "192.168.64.3 minio-console.192.168.64.3.sslip.io" >> /etc/hosts'
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```