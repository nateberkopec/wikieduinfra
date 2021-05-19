output "nomad_server_ip_address" {
  value = linode_instance.nomad_server.ip_address
}

output "mariadb_node_ip_address" {
  value = linode_instance.mariadb_node.ip_address
}

output "rails_web_node_ip_address" {
  value = linode_instance.rails_web_node.ip_address
}

output "nomad_agent_ip_addresses" {
  value = linode_instance.nomad_node.*.ip_address
}

output "nginx_node_ip_address" {
  value = linode_instance.nginx_node.ip_address
}