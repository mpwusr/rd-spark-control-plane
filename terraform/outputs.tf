output "minio_console_url" {
  value = "http://minio-console.${var.rd_ingress_ip}.sslip.io/"
}

output "spark_history_url" {
  value = "http://spark-history.${var.rd_ingress_ip}.sslip.io/"
}

output "hosts_entries_if_dns_breaks" {
  value = <<-EOT
    If sslip.io doesn't resolve on your network, add:
      ${var.rd_ingress_ip} minio-console.${var.rd_ingress_ip}.sslip.io
      ${var.rd_ingress_ip} spark-history.${var.rd_ingress_ip}.sslip.io
    then:
      sudo dscacheutil -flushcache
      sudo killall -HUP mDNSResponder
  EOT
}
