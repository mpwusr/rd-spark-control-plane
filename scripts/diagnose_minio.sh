#!/bin/bash

echo "=== MinIO Pod Status ==="
kubectl get pods -n minio

echo -e "\n=== MinIO Pod Description ==="
kubectl describe pod -n minio minio-0

echo -e "\n=== MinIO Current Logs ==="
kubectl logs -n minio minio-0 --tail=100 2>&1 || echo "No current logs available"

echo -e "\n=== MinIO Previous Logs (from crash) ==="
kubectl logs -n minio minio-0 --previous --tail=100 2>&1 || echo "No previous logs available"

echo -e "\n=== MinIO PVC Status ==="
kubectl get pvc -n minio

echo -e "\n=== MinIO PVC Description ==="
kubectl describe pvc -n minio

echo -e "\n=== MinIO Events ==="
kubectl get events -n minio --sort-by='.lastTimestamp' | tail -20
