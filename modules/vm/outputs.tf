output "nomad_server_ip_address" {
  value = var.nomad_server_ip_address
}

output "nginx_node_ip_address" {
  value = var.nginx_node_ip_address
}

output "consul_mgmt_token" {
  value = var.consul_mgmt_token
  sensitive = true
}

output "docker_domain" {
  value = var.docker_domain
}
output "rails_domain" {
  value = var.rails_domain
}
