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

# The following are all connected to the Linode sizes you chose for the various
# nodes.
output "db_cpu_hertz" {
  value = "7500"
}

output "db_memory" {
  value = "7500"
}

output "redis_cpu_hertz" {
  value = "500"
}

output "redis_memory" {
  value = "256"
}

output "memcache_cpu_hertz" {
  value = "1500"
}

output "memcache_memory" {
  value = "1000"
}