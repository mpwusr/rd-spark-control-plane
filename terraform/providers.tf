variable "kubeconfig_path" {
  type        = string
  description = "Path to kubeconfig file used by kubectl (merged config)."
  default     = "~/.kube/config"
}

variable "kube_context" {
  type        = string
  description = "Kubeconfig context name for Rancher Desktop cluster."
  default     = "rd"
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

provider "helm" {
  kubernetes = {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}

