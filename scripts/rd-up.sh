#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/terraform"

"$ROOT_DIR/scripts/rd-kubeconfig.sh"
helm -n minio status minio
helm -n minio get all minio | sed -n '1,220p'
kubectl -n minio get pods,pvc,svc
kubectl -n minio describe pod -l app=minio | sed -n '1,220p'
kubectl -n minio get events --sort-by=.lastTimestamp | tail -n 80

cd "$TF_DIR"
terraform init
terraform apply -auto-approve
kubectl get crd | egrep -i "strimzi|kafka.strimzi|kafkatopic|kafkauser|kafkaconnect|kafkanodepool|kafkabridge"
