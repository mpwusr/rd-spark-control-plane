########################
# Namespaces
########################
resource "kubernetes_namespace" "spark_operator" {
  metadata { name = "spark-operator" }
}

resource "kubernetes_namespace" "minio" {
  metadata { name = "minio" }
}

resource "kubernetes_namespace" "spark_history" {
  metadata { name = "spark-history" }
}

########################
# Spark Operator (Helm)
########################
resource "helm_release" "spark_operator" {
  name       = "spark-operator"
  namespace  = kubernetes_namespace.spark_operator.metadata[0].name

  # You can swap these if you use a different chart source.
  repository = "https://kubeflow.github.io/spark-operator"
  chart      = "spark-operator"
  # version  = "..."  # optionally pin

  set {
    name  = "webhook.enable"
    value = "true"
  }

  # common chart values vary; adjust as needed
}

########################
# MinIO (Helm)
########################
resource "helm_release" "minio" {
  name       = "minio"
  namespace  = kubernetes_namespace.minio.metadata[0].name

  repository = "https://charts.min.io/"
  chart      = "minio"
  # version  = "..."  # optionally pin

  set {
    name  = "rootUser"
    value = var.minio_root_user
  }

  set {
    name  = "rootPassword"
    value = var.minio_root_password
  }

  # Keep it simple (single instance)
  set {
    name  = "replicas"
    value = "1"
  }
}

########################
# MinIO Console Ingress (Traefik)
########################
resource "kubernetes_ingress_v1" "minio_console" {
  metadata {
    name      = "minio-console"
    namespace = kubernetes_namespace.minio.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "minio-console.${var.rd_ingress_ip}.sslip.io"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "minio-console"
              port { number = 9001 }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.minio]
}

########################
# Bucket bootstrap Job (mc)
########################
resource "kubernetes_job_v1" "minio_bucket_bootstrap" {
  metadata {
    name      = "minio-bucket-bootstrap"
    namespace = kubernetes_namespace.minio.metadata[0].name
  }

  spec {
    backoff_limit = 3

    template {
      metadata {}
      spec {
        restart_policy = "OnFailure"

        container {
          name  = "mc"
          image = "minio/mc:latest"

          command = ["/bin/sh", "-lc"]
          args = [
            join("\n", [
              "set -e",
              "mc alias set rdminio http://minio.minio.svc.cluster.local:9000 ${var.minio_root_user} ${var.minio_root_password}",
              "mc mb -p rdminio/${var.spark_logs_bucket} || true",
              "mc anonymous set download rdminio/${var.spark_logs_bucket} || true",
              "echo done"
            ])
          ]
        }
      }
    }
  }

  depends_on = [helm_release.minio]
}

########################
# Spark History Config (spark-defaults.conf)
########################
resource "kubernetes_config_map" "spark_history_config" {
  metadata {
    name      = "spark-history-config"
    namespace = kubernetes_namespace.spark_history.metadata[0].name
  }

  data = {
    "spark-defaults.conf" = <<-EOT
      spark.eventLog.enabled true
      spark.eventLog.dir s3a://${var.spark_logs_bucket}/
      spark.history.fs.logDirectory s3a://${var.spark_logs_bucket}/

      spark.hadoop.fs.s3a.endpoint http://minio.minio.svc.cluster.local:9000
      spark.hadoop.fs.s3a.access.key ${var.minio_root_user}
      spark.hadoop.fs.s3a.secret.key ${var.minio_root_password}
      spark.hadoop.fs.s3a.path.style.access true
      spark.hadoop.fs.s3a.connection.ssl.enabled false
    EOT
  }

  depends_on = [kubernetes_job_v1.minio_bucket_bootstrap]
}

########################
# Spark History Server Deployment
########################
resource "kubernetes_deployment_v1" "spark_history" {
  metadata {
    name      = "spark-history"
    namespace = kubernetes_namespace.spark_history.metadata[0].name
    labels = {
      app = "spark-history"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "spark-history" }
    }

    template {
      metadata {
        labels = { app = "spark-history" }
      }

      spec {
        container {
          name  = "spark-history"
          image = var.spark_history_image

          port {
            container_port = 18080
          }

          command = ["/opt/spark/bin/spark-class"]
          args    = ["org.apache.spark.deploy.history.HistoryServer"]

          # Spark reads /opt/spark/conf/spark-defaults.conf by default
          volume_mount {
            name       = "spark-conf"
            mount_path = "/opt/spark/conf"
          }
        }

        volume {
          name = "spark-conf"
          config_map {
            name = kubernetes_config_map.spark_history_config.metadata[0].name
            items {
              key  = "spark-defaults.conf"
              path = "spark-defaults.conf"
            }
          }
        }
      }
    }
  }
}

########################
# Service + Ingress
########################
resource "kubernetes_service_v1" "spark_history" {
  metadata {
    name      = "spark-history"
    namespace = kubernetes_namespace.spark_history.metadata[0].name
    labels    = { app = "spark-history" }
  }

  spec {
    selector = { app = "spark-history" }

    port {
      name        = "http"
      port        = 18080
      target_port = 18080
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment_v1.spark_history]
}

resource "kubernetes_ingress_v1" "spark_history" {
  metadata {
    name      = "spark-history"
    namespace = kubernetes_namespace.spark_history.metadata[0].name
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "spark-history.${var.rd_ingress_ip}.sslip.io"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.spark_history.metadata[0].name
              port { number = 18080 }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service_v1.spark_history]
}
