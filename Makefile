SHELL := /bin/bash

# Always target Rancher Desktop kubeconfig unless explicitly overridden
KUBECONFIG ?= $(HOME)/.kube/config
KUBE_CONTEXT ?= rd

export KUBECONFIG

# Docker image configuration
QUAY_USERNAME = mpwbaruk
SPARK_S3A_REPO = quay.io/$(QUAY_USERNAME)/spark-s3a
SPARK_S3A_TAG = 3.5.4

.PHONY: help perm kubeconfig ctx tf-init tf-apply tf-destroy up down status validate clean-lock
.PHONY: docker-build docker-push docker-test docker-login docker-all

help:
	@echo "Kubernetes Targets:"
	@echo "  make perm        - chmod +x scripts/*.sh"
	@echo "  make kubeconfig  - refresh kubeconfig from Rancher Desktop VM"
	@echo "  make ctx         - set kubectl context to $(KUBE_CONTEXT)"
	@echo "  make tf-init     - terraform init (upgrade providers)"
	@echo "  make tf-plan     - terraform plan"
	@echo "  make tf-apply    - terraform apply"
	@echo "  make tf-destroy  - terraform destroy"
	@echo "  make up          - start RD + kubeconfig + terraform apply"
	@echo "  make down        - terraform destroy + stop RD"
	@echo "  make status      - show nodes/namespaces/pods"
	@echo "  make validate    - verify Spark Operator, MinIO, Spark History, Ingress"
	@echo "  make clean-lock  - remove .terraform and lockfile (forces fresh init)"
	@echo ""
	@echo "Docker Image Targets:"
	@echo "  make docker-build  - Build Spark S3A Docker image"
	@echo "  make docker-test   - Test Spark S3A image locally"
	@echo "  make docker-login  - Login to Quay.io"
	@echo "  make docker-push   - Build and push to Quay.io"
	@echo "  make docker-all    - Login, build, test, and push"

# ============================================================================
# Kubernetes / Terraform Targets
# ============================================================================

perm:
	@chmod +x scripts/*.sh || true
	@echo "[*] scripts are executable"

kubeconfig:
	@./scripts/rd-kubeconfig.sh

ctx:
	@kubectl config use-context $(KUBE_CONTEXT) >/dev/null 2>&1 || true
	@echo "[*] Context: $$(kubectl config current-context)"

tf-init:
	cd terraform && terraform init -upgrade

tf-validate: tf-init
	cd terraform && terraform validate

tf-plan: tf-init
	cd terraform && terraform plan

tf-apply: tf-init
	cd terraform && terraform apply -auto-approve

tf-destroy: tf-init
	cd terraform && terraform destroy -auto-approve

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

# ============================================================================
# Docker Image Build Targets
# ============================================================================

docker-build:
	@echo "Building Spark S3A image..."
	docker build -t $(SPARK_S3A_REPO):$(SPARK_S3A_TAG) -f docker/Dockerfile .
	docker tag $(SPARK_S3A_REPO):$(SPARK_S3A_TAG) $(SPARK_S3A_REPO):latest
	@echo ""
	@echo "✓ Image built: $(SPARK_S3A_REPO):$(SPARK_S3A_TAG)"

docker-test:
	@echo "Testing Spark S3A image..."
	docker run --rm $(SPARK_S3A_REPO):$(SPARK_S3A_TAG) /opt/spark/bin/spark-submit --version
	@echo ""
	@echo "Checking S3A JARs:"
	docker run --rm $(SPARK_S3A_REPO):$(SPARK_S3A_TAG) ls -lh /opt/spark/jars/hadoop-aws-*.jar
	docker run --rm $(SPARK_S3A_REPO):$(SPARK_S3A_TAG) ls -lh /opt/spark/jars/aws-java-sdk-bundle-*.jar
	@echo ""
	@echo "✓ Image test passed!"

docker-login:
	@echo "Logging in to Quay.io..."
	docker login quay.io

docker-push: docker-build
	@echo "Pushing to Quay.io..."
	docker push $(SPARK_S3A_REPO):$(SPARK_S3A_TAG)
	docker push $(SPARK_S3A_REPO):latest
	@echo ""
	@echo "✓ Pushed to $(SPARK_S3A_REPO):$(SPARK_S3A_TAG)"
	@echo "✓ Pushed to $(SPARK_S3A_REPO):latest"
	@echo ""
	@echo "Make repository public (if needed):"
	@echo "https://quay.io/repository/$(QUAY_USERNAME)/spark-s3a?tab=settings"

docker-all: docker-login docker-build docker-test docker-push
	@echo ""
	@echo "✓ All Docker operations complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Make repository public in Quay.io (if needed)"
	@echo "  2. Update terraform to use: $(SPARK_S3A_REPO):$(SPARK_S3A_TAG)"
	@echo "  3. Run: make tf-apply"
