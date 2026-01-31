resource "helm_release" "strimzi" {
  name       = "strimzi"
  namespace  = "kafka"
  repository = "https://strimzi.io/charts/"
  chart      = "strimzi-kafka-operator"
  version    = "0.39.0"

  create_namespace = true

  values = [<<EOF
watchNamespaces:
  - kafka
EOF
  ]
}

resource "kubernetes_manifest" "kafka_cluster" {
  depends_on = [helm_release.strimzi]

  manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "Kafka"
    metadata = {
      name      = "spark-kafka"
      namespace = "kafka"
    }
    spec = {
      kafka = {
        version  = "3.7.0"
        replicas = 1
        listeners = [
          {
            name = "plain"
            port = 9092
            type = "internal"
            tls  = false
          }
        ]
        storage = {
          type = "ephemeral"
        }
      }
      zookeeper = {
        replicas = 1
        storage = {
          type = "ephemeral"
        }
      }
      entityOperator = {
        topicOperator = {}
        userOperator  = {}
      }
    }
  }
}
