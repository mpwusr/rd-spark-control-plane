variable "rd_ingress_ip" {
  description = "Rancher Desktop ingress/LB IP (k3s/traefik service external IP). Typically 192.168.64.3."
  type        = string
  default     = "192.168.64.3"
}

variable "minio_root_user" {
  type    = string
  default = "minioadmin"
}

variable "minio_root_password" {
  type      = string
  sensitive = true
  default   = "minio2026RootPassword"
}

variable "enable_kafka" {
  type    = bool
  default = false
}

variable "spark_history_image" {
  type    = string
  default = "quay.io/mpwbaruk/spark-s3a:3.5.4"
}

variable "spark_logs_bucket" {
  type    = string
  default = "spark-logs"
}
