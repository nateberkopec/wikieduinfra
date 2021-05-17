terraform {
  source = "../../modules//nomad"
}

dependency "linode" {
  config_path = "../vm"
  mock_outputs_allowed_terraform_commands = ["init"]
  mock_outputs = {
    nomad_server_ip_address = "1"
    nginx_node_ip_address = "1"
    nomad_mgmt_token = "1"
    db_cpu_hertz = "1"
    db_memory = "1"
    redis_cpu_hertz = "1"
    redis_memory = "1"
    memcache_cpu_hertz = "1"
    memcache_memory = "1"
    docker_domain = "1"
    rails_domain = "1"
    consul_mgmt_token = "1"
    docker_pass_encrypted = "1"
  }
}

inputs = {
  nomad_server_ip_address = dependency.linode.outputs.nomad_server_ip_address
  nginx_node_ip_address = dependency.linode.outputs.nginx_node_ip_address
  nomad_mgmt_token = dependency.linode.outputs.nomad_mgmt_token
  consul_mgmt_token = dependency.linode.outputs.consul_mgmt_token
  db_cpu_hertz = dependency.linode.outputs.db_cpu_hertz
  db_memory = dependency.linode.outputs.db_memory
  redis_cpu_hertz = dependency.linode.outputs.redis_cpu_hertz
  redis_memory = dependency.linode.outputs.redis_memory
  memcache_cpu_hertz = dependency.linode.outputs.memcache_cpu_hertz
  memcache_memory = dependency.linode.outputs.memcache_memory
  docker_domain = dependency.linode.outputs.docker_domain
  rails_domain = dependency.linode.outputs.rails_domain
  path_to_certs = abspath("./certs")
}