variable "consul_mgmt_token" {
  type        = string
  description = <<EOT
    Token used to secure Consul - this token grants global permissions to bearer.
    Use `openssl rand -hex 24` to generate a sufficiently random value.
  EOT
  # sensitive   = true
}

variable "consul_gossip_token" {
  type    = string
  description = <<EOT
    Token used to secure Consul gossip protocol.
    Use `openssl rand -hex 24` to generate.
  EOT
  # sensitive = true
}

variable "new_relic_license_key" {
  type    = string
  description = "Your New Relic License Key. Used to stand up the Infra Agent."
  # sensitive = true
}

variable "docker_domain" {
  type = string
  description = "FQDN where the docker registry will be hosted"
  default = "docker.wikiedu.org"
}

variable "rails_domain" {
  type = string
  description = "FQDN where the Rails app will be hosted"
  default = "www.wikiedu.org"
}

variable "letsencrypt_email" {
  type = string
  description = "Email address for LE certs"
  default = "sage@wikiedu.org"
}

variable "ssh_privkey" {
  type = string
  description = "Local path to the SSH private key for accessing the cluster"
}

variable "ssh_user" {
  type = string
}

variable "bastion_host" {
  type = string
}

variable "path_to_certs" {
  type = string
}

variable "nomad_server_ip_address" {
  type = string
}

variable "nginx_node_ip_address" {
  type = string
}

variable "mariadb_node_ip_address" {
  type = string
}

variable "rails_web_node_ip_address" {
  type = string
}

variable "nomad_agent_ip_addresses" {
  type = list
}

variable "nomad_server_external_ip_address" {
  type = string
  default = "127.0.0.1"
}
