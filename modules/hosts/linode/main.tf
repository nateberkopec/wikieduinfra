terraform {
  required_providers {
    linode = {
      source = "linode/linode"
      version = "1.16.0"
    }
    local = {
      source = "hashicorp/local"
      version = "2.1.0"
    }
  }
}

provider "linode" {
  token = var.linode_token
}

data "local_file" "ssh_pubkey" {
  filename = var.ssh_pubkey
}

# Small node solely for running the nomad server
# and the consul server.
# We cannot schedule workloads here because they might
# steal resources from the nomad server.
resource "linode_instance" "nomad_server" {
  label = "nomad"
  image = "linode/debian10"
  region = "us-west"
  type = "g6-standard-1"
  authorized_keys = [chomp(data.local_file.ssh_pubkey.content)]
  root_pass = var.root_pass
  backups_enabled = true
  watchdog_enabled= true
}

resource "linode_instance" "mariadb_node" {
  label = "nomad-mariadb-node"
  image = "linode/debian10"
  region = "us-west"
  type = "g6-standard-4"
  authorized_keys = [chomp(data.local_file.ssh_pubkey.content)]
  root_pass = var.root_pass
  backups_enabled = true
  watchdog_enabled= true
}

resource "linode_instance" "rails_web_node" {
  label = "nomad-rails-web-node"
  image = "linode/debian10"
  region = "us-west"
  type = "g6-standard-4"
  authorized_keys = [chomp(data.local_file.ssh_pubkey.content)]
  root_pass = var.root_pass
  backups_enabled = true
  watchdog_enabled= true
}

resource "linode_instance" "nginx_node" {
  label = "nomad-nginx-node"
  image = "linode/debian10"
  region = "us-west"
  type = "g6-standard-1"
  authorized_keys = [chomp(data.local_file.ssh_pubkey.content)]
  root_pass = var.root_pass
  backups_enabled = true
  watchdog_enabled= true
}

resource "linode_instance" "nomad_node" {
  count = 2

  label = "nomad-agent-${count.index}"
  image = "linode/debian10"
  region = "us-west"
  type = "g6-standard-4"
  authorized_keys = [chomp(data.local_file.ssh_pubkey.content)]
  root_pass = var.root_pass
  backups_enabled = true
  watchdog_enabled= true
}