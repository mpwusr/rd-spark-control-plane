resource "helm_release" "strimzi" {
  count      = var.enable_kafka ? 1 : 0
  name       = "strimzi"
  namespace  = "kafka"
  repository = "https://strimzi.io/charts/"
  chart      = "strimzi-kafka-operator"
  version    = "0.39.0"

  create_namespace = true
  wait             = true
  timeout          = 600

  values = [<<EOF
watchNamespaces:
  - kafka
EOF
  ]
}

resource "kubernetes_manifest" "kafka_cluster" {
  count      = var.enable_kafka ? 1 : 0
  depends_on = [helm_release.strimzi[0]]

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
        listeners = [{
          name = "plain"
          port = 9092
          type = "internal"
          tls  = false
        }]
        storage = { type = "ephemeral" }
      }
      zookeeper = {
        replicas = 1
        storage  = { type = "ephemeral" }
      }
      entityOperator = {
        topicOperator = {}
        userOperator  = {}
      }
    }
  }
}
