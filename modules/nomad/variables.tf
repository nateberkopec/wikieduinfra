variable "docker_pass_encrypted" {
  type = string
  description = <<EOF
A hashed password for HTTP basic auth on Docker Registry. Use:
htpasswd -Bbn docker testpass
where testpass is the password you want. Exclude the `docker:` prefix.
Retain the original password to use via `docker login <DOCKER URL>`
EOF
  default = ""
}

variable "docker_pass" {
  type = string
  description = <<EOF
    Prior password, unencrypted. This password will also have to be
    provided to waypoint.
  EOF
  default = ""
}

## Remaining variables here are set by the dependent module

variable "nomad_server_ip_address" {
  type = string
}

variable "nginx_node_ip_address" {
  type = string
}

variable "consul_mgmt_token" {
  type = string
}

variable "db_cpu_hertz" {
  type = string
}

variable "db_memory" {
  type = string
}

variable "redis_cpu_hertz" {
  type = string
}

variable "redis_memory" {
  type = string
}

variable "memcache_cpu_hertz" {
  type = string
}

variable "memcache_memory" {
  type = string
}

variable "docker_domain" {
  type = string
}

variable "rails_domain" {
  type = string
}

variable "path_to_certs" {
  type = string
}

variable "ssh_privkey" {
  type = string
}

variable "ssh_user" {
  type = string
}

variable "bastion_host" {
  type = string
}

variable "nomad_server_external_address" {
  type = string
}

variable "mariadb" {
  type = bool
}

variable "waypoint_domain" {
  type = string
}