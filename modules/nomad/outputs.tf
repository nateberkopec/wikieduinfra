output "nomad_server_address" {
  value = var.nomad_server_ip_address
}

output "nomad_mgmt_token" {
  value = data.external.nomad_bootstrap_acl.result.token
}

output "consul_mgmt_token" {
  value = var.consul_mgmt_token
}
