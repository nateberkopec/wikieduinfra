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

data "local_file" "ssh_privkey" {
  filename = var.ssh_privkey
}

locals {
  nomad_server_external_address = var.nomad_server_external_address != null ? var.nomad_server_external_address : var.nomad_server_ip_address
  db_node_count = var.mariadb == false ? 0 : 1
  bastion_host = var.bastion_host == null ? " " : var.bastion_host
  nginx_template = var.mariadb == true ?"${path.module}/jobs/nginx.hcl.tmpl" : "${path.module}/jobs/nginx_nossl.hcl.tmpl"
}

data "external" "nomad_bootstrap_acl" {
  program = ["sh", "scripts/get_bootstrap.sh", data.local_file.ssh_privkey.filename, var.ssh_user, local.bastion_host]
  query = { "ip_address" = var.nomad_server_ip_address }
}

# Nomad

provider "nomad" {
  address = "https://${local.nomad_server_external_address}:4646"
  secret_id = data.external.nomad_bootstrap_acl.result.token
  ca_file = "${var.path_to_certs}/nomad-agent-certs/nomad-agent-ca.pem"
  cert_file = "${var.path_to_certs}/nomad-agent-certs/global-client-nomad-0.pem"
  key_file = "${var.path_to_certs}/nomad-agent-certs/global-client-nomad-0-key.pem"
}

# Consul, for creating intentions

provider "consul" {
  address = "${local.nomad_server_external_address}:8501"
  scheme = "https"
  token = var.consul_mgmt_token
  ca_file = "${var.path_to_certs}/consul-agent-certs/consul-agent-ca.pem"
  cert_file = "${var.path_to_certs}/consul-agent-certs/dc1-client-consul-0.pem"
  key_file = "${var.path_to_certs}/consul-agent-certs/dc1-client-consul-0-key.pem"
  insecure_https = true
}

resource "nomad_job" "redis" {
  jobspec = templatefile(
              "${path.module}/jobs/redis.hcl.tmpl",
              {
                "redis_cpu_hertz" = var.redis_cpu_hertz
                "redis_memory" = var.redis_memory
              }
            )
}

resource "consul_config_entry" "redis" {
  name = "redis-sidekiq" # destination service
  kind = "service-intentions"

  config_json = jsonencode({
    Sources = [
      {
        Action     = "allow"
        Name       = "puma" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-constant" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-daily" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-default" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-long" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-medium" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-short" # originating service
        Precedence = 9
        Type       = "consul"
      }
    ]
  })
}

resource "nomad_job" "memcache" {
  jobspec = templatefile(
              "${path.module}/jobs/memcache.hcl.tmpl",
              {
                "memcache_cpu_hertz" = var.memcache_cpu_hertz
                "memcache_memory" = var.memcache_memory
                "memcache_maxmemory" = tonumber(var.memcache_memory) * 0.8
              }
            )
}

resource "consul_config_entry" "memcache" {
  name = "memcache" # destination service
  kind = "service-intentions"

  config_json = jsonencode({
    Sources = [
      {
        Action     = "allow"
        Name       = "puma" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-constant" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-daily" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-default" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-long" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-medium" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-short" # originating service
        Precedence = 9
        Type       = "consul"
      }
    ]
  })
}

resource "nomad_job" "mariadb" {
  count = local.db_node_count

  jobspec = templatefile(
              "${path.module}/jobs/mariadb.hcl.tmpl",
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
    Sources = [
      {
        Action     = "allow"
        Name       = "puma" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-constant" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-daily" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-default" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-long" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-medium" # originating service
        Precedence = 9
        Type       = "consul"
      },
      {
        Action     = "allow"
        Name       = "sidekiq-short" # originating service
        Precedence = 9
        Type       = "consul"
      }
    ]
  })
}

resource "nomad_job" "docker_registry" {
  jobspec = templatefile(
              "${path.module}/jobs/docker_registry.hcl.tmpl",
              {
                "docker_pass_encrypted" = var.docker_pass_encrypted
              }
            )
}

resource "nomad_job" "nginx" {
  jobspec = templatefile(
              local.nginx_template,
              {
                "docker_domain" = var.docker_domain
                "rails_domain" = var.rails_domain
                "waypoint_domain" = var.waypoint_domain
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

resource "consul_config_entry" "puma" {
  name = "puma" # destination service
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

resource "null_resource" "nomad_shell" {
  provisioner "local-exec" {
    command = <<EOF
    echo "
      export NOMAD_ADDR="https://${local.nomad_server_external_address}:4646"
      export NOMAD_TOKEN=${data.external.nomad_bootstrap_acl.result.token}
      export NOMAD_CA_PATH="${var.path_to_certs}/nomad-agent-certs/nomad-agent-ca.pem"
      export NOMAD_CLIENT_CERT="${var.path_to_certs}/nomad-agent-certs/global-client-nomad-0.pem"
      export NOMAD_CLIENT_KEY="${var.path_to_certs}/nomad-agent-certs/global-client-nomad-0-key.pem"
      export NOMAD_SKIP_VERIFY="true"
      export DATABASE_URL="mysql2://wiki:wikiedu@127.0.0.1:3306/dashboard?pool=5"
    " >> ${var.path_to_certs}/../nomad.sh
    EOF
  }
}

resource "null_resource" "waypoint" {
  provisioner "local-exec" {
    command = "waypoint install -platform=nomad -nomad-dc=dc1 -accept-tos -docker-server-image=hashicorp/waypoint:0.3.1"
    environment = {
      NOMAD_ADDR="https://${local.nomad_server_external_address}:4646"
      NOMAD_TOKEN=data.external.nomad_bootstrap_acl.result.token
      NOMAD_CA_PATH="${var.path_to_certs}/nomad-agent-certs/nomad-agent-ca.pem"
      NOMAD_CLIENT_CERT="${var.path_to_certs}/nomad-agent-certs/global-client-nomad-0.pem"
      NOMAD_CLIENT_KEY="${var.path_to_certs}/nomad-agent-certs/global-client-nomad-0-key.pem"
      NOMAD_SKIP_VERIFY="true"
    }
  }
}
