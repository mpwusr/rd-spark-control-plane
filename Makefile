SHELL := /bin/bash

.PHONY: help up down status tf-init tf-apply tf-destroy kubeconfig

help:
	@echo "Available targets:"
	@echo "  make up        - Start Rancher Desktop + apply Terraform"
	@echo "  make down      - Destroy Terraform + stop RD"
	@echo "  make status    - Show cluster + workloads"
	@echo "  make tf-init   - Terraform init"
	@echo "  make tf-apply  - Terraform apply"
	@echo "  make tf-destroy- Terraform destroy"

up:
	./scripts/rd-up.sh
	make kubeconfig
	make tf-apply

down:
	make tf-destroy
	./scripts/rd-down.sh

status:
	kubectl get nodes
	kubectl get ns
	kubectl get pods -A

kubeconfig:
	./scripts/rd-kubeconfig.sh

tf-init:
	cd terraform && terraform init

tf-apply:
	cd terraform && terraform apply -auto-approve

tf-destroy:
	cd terraform && terraform destroy -auto-approve
git status