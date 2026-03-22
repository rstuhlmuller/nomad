output "consul_ui_urls" {
  description = "Consul UI URLs"
  value       = [for ip in var.server_ips : "http://${ip}:8500"]
}

output "nomad_ui_urls" {
  description = "Nomad UI URLs"
  value       = [for ip in var.server_ips : "http://${ip}:4646"]
}

output "server_ips" {
  description = "Server IP addresses"
  value       = var.server_ips
}

output "cluster_info" {
  description = "Cluster information"
  value = {
    datacenter    = var.datacenter
    region        = var.region
    consul_nodes  = length(var.server_ips)
    nomad_servers = length(var.server_ips)
    nomad_clients = length(var.server_ips)
  }
}
