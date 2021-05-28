terraform {
  source = "../../modules//vm"
}

include {
  path = find_in_parent_folders()
}

dependency "linode" {
  config_path = "../linode"
  mock_outputs_allowed_terraform_commands = ["init", "plan"]
  mock_outputs = {
    nomad_server_ip_address = "1"
    nginx_node_ip_address = "1"
    mariadb_node_ip_address = "1"
    rails_web_node_ip_address = "1"
    nomad_agent_ip_addresses = ["1", "2"]
    path_to_certs = "1"
  }
}

inputs = {
  nomad_server_ip_address = dependency.linode.outputs.nomad_server_ip_address
  nginx_node_ip_address = dependency.linode.outputs.nginx_node_ip_address
  mariadb_node_ip_address = dependency.linode.outputs.mariadb_node_ip_address
  rails_web_node_ip_address = dependency.linode.outputs.rails_web_node_ip_address
  nomad_agent_ip_addresses = dependency.linode.outputs.nomad_agent_ip_addresses
  path_to_certs = abspath("./certs")
}