variable "docker_pass_encrypted" {
  type = string
  description = <<EOF
A password for HTTP basic auth on Docker Registry. Use:
htpasswd -bnBC 10 "" testpass | tr -d ':\n'
where testpass is the password you want.
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

variable "nomad_mgmt_token" {
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
