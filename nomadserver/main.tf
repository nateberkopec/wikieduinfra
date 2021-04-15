terraform {
  required_providers {
    nomad = {
      source = "hashicorp/nomad"
      version = "1.4.13"
    }
    null = {
      source = "hashicorp/null"
      version = "3.1.0"
    }
    consul = {
      source = "hashicorp/consul"
      version = "2.11.0"
    }
  }
}

# Nomad

provider "nomad" {
  address = "https://${var.nomad_server_ip_address}:4646"
  secret_id = var.nomad_mgmt_token
  ca_file = "../certs/nomad-agent-certs/nomad-agent-ca.pem"
  cert_file = "../certs/nomad-agent-certs/global-client-nomad-0.pem"
  key_file = "../certs/nomad-agent-certs/global-client-nomad-0-key.pem"
}

# Consul, for creating intentions

provider "consul" {
  address = "${var.nomad_server_ip_address}:8501"
  scheme = "https"
  token = var.consul_mgmt_token
  ca_file = "../certs/consul-agent-certs/consul-agent-ca.pem"
  cert_file = "../certs/consul-agent-certs/dc1-client-consul-0.pem"
  key_file = "../certs/consul-agent-certs/dc1-client-consul-0-key.pem"
  insecure_https = true
}

resource "nomad_job" "redis" {
  jobspec = templatefile(
              "${path.module}/nomad/jobs/redis.hcl.tmpl",
              {
                "redis_cpu_hertz" = var.redis_cpu_hertz
                "redis_memory" = var.redis_memory
                "redis_maxmemory" = tonumber(var.redis_memory) * 1048576 * 0.8
              }
            )
}

resource "consul_config_entry" "redis" {
  name = "redis-sidekiq" # destination service
  kind = "service-intentions"

  config_json = jsonencode({
    Sources = [{
      Action     = "allow"
      Name       = "rails" # originating service
      Precedence = 9
      Type       = "consul"
    }]
  })
}

resource "nomad_job" "memcache" {
  jobspec = templatefile(
              "${path.module}/nomad/jobs/memcache.hcl.tmpl",
              {
                "memcache_cpu_hertz" = var.memcache_cpu_hertz
                "memcache_memory" = var.memcache_memory
                "memcache_maxmemory" = tonumber(var.memcache_memory) * 0.8
              }
            )
}

resource "consul_config_entry" "memcahe" {
  name = "memcache" # destination service
  kind = "service-intentions"

  config_json = jsonencode({
    Sources = [{
      Action     = "allow"
      Name       = "rails" # originating service
      Precedence = 9
      Type       = "consul"
    }]
  })
}

resource "nomad_job" "mariadb" {
  jobspec = templatefile(
              "${path.module}/nomad/jobs/mariadb.hcl.tmpl",
              {
                "db_cpu_hertz" = var.db_cpu_hertz
                "db_memory" = var.db_memory
                "db_buffer_pool_size" = tonumber(var.db_memory) * 1048576 * 0.8
              }
            )
}

resource "consul_config_entry" "mariadb" {
  name = "mariadb" # destination service
  kind = "service-intentions"

  config_json = jsonencode({
    Sources = [{
      Action     = "allow"
      Name       = "rails" # originating service
      Precedence = 9
      Type       = "consul"
    }]
  })
}

resource "nomad_job" "docker_registry" {
  jobspec = templatefile(
              "${path.module}/nomad/jobs/docker_registry.hcl.tmpl",
              {
                "docker_pass_encrypted" = var.docker_pass_encrypted
              }
            )
}

resource "nomad_job" "nginx" {
  jobspec = templatefile(
              "${path.module}/nomad/jobs/nginx.hcl.tmpl",
              {
                "docker_domain" = var.docker_domain
                "rails_domain" = var.rails_domain
              }
            )
}

resource "consul_config_entry" "nginx" {
  name = "docker-registry" # destination service
  kind = "service-intentions"

  config_json = jsonencode({
    Sources = [{
      Action     = "allow"
      Name       = "nginx" # originating service
      Precedence = 9
      Type       = "consul"
    }]
  })
}

resource "consul_config_entry" "rails" {
  name = "rails" # destination service
  kind = "service-intentions"

  config_json = jsonencode({
    Sources = [{
      Action     = "allow"
      Name       = "nginx" # originating service
      Precedence = 9
      Type       = "consul"
    }]
  })
}

resource "null_resource" "waypoint" {
  provisioner "local-exec" {
    command = "waypoint install -platform=nomad -nomad-dc=dc1 -accept-tos"
    environment = {
      NOMAD_ADDR="https://${var.nomad_server_ip_address}:4646"
      NOMAD_TOKEN=var.nomad_mgmt_token
      NOMAD_CA_PATH="${abspath(path.root)}/../certs/nomad-agent-certs/nomad-agent-ca.pem"
      NOMAD_CLIENT_CERT="${abspath(path.root)}/../certs/nomad-agent-certs/global-client-nomad-0.pem"
      NOMAD_CLIENT_KEY="${abspath(path.root)}/../certs/nomad-agent-certs/global-client-nomad-0-key.pem"
      NOMAD_SKIP_VERIFY="true"
    }
  }
}