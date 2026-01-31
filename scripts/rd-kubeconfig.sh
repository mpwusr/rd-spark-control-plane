#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.kube"

echo "[*] Extracting kubeconfig from Rancher Desktop VM..."
rdctl shell -- sudo cat /etc/rancher/k3s/k3s.yaml > "$HOME/.kube/rd.yaml"
chmod 600 "$HOME/.kube/rd.yaml"

# Rename context/cluster/user from "default" -> "rd"
perl -pi -e '
s/\bname:\s*default\b/name: rd/g;
s/\bcluster:\s*default\b/cluster: rd/g;
s/\buser:\s*default\b/user: rd/g;
s/\bcurrent-context:\s*default\b/current-context: rd/g;
' "$HOME/.kube/rd.yaml"

# Optionally make rd.yaml your default kubeconfig:
cp "$HOME/.kube/rd.yaml" "$HOME/.kube/config"

echo "[*] Contexts:"
kubectl config get-contexts
echo "[*] Using context rd"
kubectl config use-context rd >/dev/null

echo "[*] Cluster check:"
kubectl get nodes -o wide
