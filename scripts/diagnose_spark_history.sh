#!/bin/bash

echo "=== Spark History Pod Status ==="
kubectl get pods -n spark-history

echo -e "\n=== Spark History Pod Description ==="
kubectl describe pod -n spark-history -l app=spark-history

echo -e "\n=== Spark History Deployment ==="
kubectl get deployment -n spark-history spark-history -o yaml

echo -e "\n=== Spark History Pod Logs ==="
kubectl logs -n spark-history -l app=spark-history --tail=100 2>&1 || echo "No logs available yet"

echo -e "\n=== Spark History ConfigMap ==="
kubectl get configmap -n spark-history spark-history-config -o yaml

echo -e "\n=== Spark History Events ==="
kubectl get events -n spark-history --sort-by='.lastTimestamp' | tail -20

echo -e "\n=== Check MinIO Connectivity ==="
kubectl get svc -n minio
