SHELL := /bin/bash

# Always target Rancher Desktop kubeconfig unless explicitly overridden
KUBECONFIG ?= $(HOME)/.kube/config
KUBE_CONTEXT ?= rd

export KUBECONFIG

.PHONY: help perm kubeconfig ctx tf-init tf-apply tf-destroy up down status validate clean-lock

help:
	@echo "Targets:"
	@echo "  make perm        - chmod +x scripts/*.sh"
	@echo "  make kubeconfig  - refresh kubeconfig from Rancher Desktop VM"
	@echo "  make ctx         - set kubectl context to $(KUBE_CONTEXT)"
	@echo "  make tf-init     - terraform init (upgrade providers)"
	@echo "  make tf-apply    - terraform apply"
	@echo "  make tf-destroy  - terraform destroy"
	@echo "  make up          - start RD + kubeconfig + terraform apply"
	@echo "  make down        - terraform destroy + stop RD"
	@echo "  make status      - show nodes/namespaces/pods"
	@echo "  make validate    - verify Spark Operator, MinIO, Spark History, Ingress"
	@echo "  make clean-lock  - remove .terraform and lockfile (forces fresh init)"

perm:
	@chmod +x scripts/*.sh || true
	@echo "[*] scripts are executable"

kubeconfig:
	@./scripts/rd-kubeconfig.sh

ctx:
	@kubectl config use-context $(KUBE_CONTEXT) >/dev/null 2>&1 || true
	@echo "[*] Context: $$(kubectl config current-context)"

tf-init:
	@cd terraform && terraform init -upgrade

tf-apply: tf-init
	@cd terraform && terraform apply -auto-approve

tf-destroy: tf-init
	@cd terraform && terraform destroy -auto-approve || true

up: perm kubeconfig ctx tf-apply
	@echo "[*] up complete"

down: perm ctx tf-destroy
	@echo "[*] Stopping Rancher Desktop..."
	@./scripts/rd-down.sh
	@echo "[*] down complete"

status: ctx
	@kubectl get nodes -o wide
	@kubectl get ns
	@kubectl get pods -A

validate: ctx
	@echo "==> Spark Operator:"
	@kubectl get ns spark-operator >/dev/null 2>&1 && echo "  - namespace: OK" || (echo "  - namespace: MISSING" && exit 1)
	@kubectl -n spark-operator get pods
	@kubectl get crd | egrep -i 'sparkapplications|scheduledsparkapplications|sparkconnects' || true

	@echo ""
	@echo "==> MinIO:"
	@kubectl get ns minio >/dev/null 2>&1 && echo "  - namespace: OK" || (echo "  - namespace: MISSING" && exit 1)
	@kubectl -n minio get deploy,po,svc -o wide
	@kubectl -n minio get ingress || true

	@echo ""
	@echo "==> Spark History:"
	@kubectl get ns spark-history >/dev/null 2>&1 && echo "  - namespace: OK" || (echo "  - namespace: MISSING" && exit 1)
	@kubectl -n spark-history get deploy,po,svc -o wide
	@kubectl -n spark-history get ingress || true

	@echo ""
	@echo "==> IngressClass:"
	@kubectl get ingressclass || true
	@echo ""
	@echo "[*] validate complete"

clean-lock:
	@rm -rf terraform/.terraform terraform/.terraform.lock.hcl
	@echo "[*] removed terraform .terraform and lockfile"
