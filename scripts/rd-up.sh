#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/terraform"

"$ROOT_DIR/scripts/rd-kubeconfig.sh"

cd "$TF_DIR"
terraform init
terraform apply -auto-approve
