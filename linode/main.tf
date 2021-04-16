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

  provisioner "file" {
    source      = "scripts/provision_host.sh"
    destination = "~/provision_host.sh"

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x provision_host.sh",
      "./provision_host.sh ${var.consul_mgmt_token} ${var.consul_gossip_token} ${var.new_relic_license_key}"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "local-exec" {
    command = "ssh-keyscan ${self.ip_address} >> ~/.ssh/known_hosts"
  }

  provisioner "local-exec" {
    command = "mkdir -p ${abspath(path.root)}/../certs/consul-agent-certs/"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -r ${abspath(path.root)}/../certs"
  }

  provisioner "local-exec" {
    command = "scp -i ${data.local_file.ssh_privkey.filename} -r root@${self.ip_address}:/root/consul-agent-certs ${abspath(path.root)}/../certs"
  }

  provisioner "local-exec" {
    command = "scp -i ${data.local_file.ssh_privkey.filename} -r root@${self.ip_address}:/root/nomad-agent-certs ${abspath(path.root)}/../certs"
  }
}

# Node which contains the host volume for MariaDB
resource "linode_instance" "mariadb_node" {
  label = "nomad-mariadb-node"
  image = "linode/debian10"
  region = "us-west"
  type = "g6-standard-4"
  authorized_keys = [chomp(data.local_file.ssh_pubkey.content)]
  root_pass = var.root_pass
  backups_enabled = true
  watchdog_enabled= true

  provisioner "file" {
    source      = "scripts/provision_agent.sh"
    destination = "~/provision_agent.sh"

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "file" {
    source      = "${abspath(path.root)}/../certs/consul-agent-certs"
    destination = "/root"

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "file" {
    source      = "${abspath(path.root)}/../certs/nomad-agent-certs"
    destination = "/root"

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "file" {
    source      = "scripts/provision_agent_mariadb.sh"
    destination = "~/provision_agent_mariadb.sh"

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x provision_agent.sh",
      "./provision_agent.sh mariadb ${var.consul_mgmt_token} ${var.consul_gossip_token} ${linode_instance.nomad_server.ip_address} ${var.new_relic_license_key}",
      "chmod +x provision_agent_mariadb.sh",
      "./provision_agent_mariadb.sh mariadb ${var.consul_mgmt_token}"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "local-exec" {
    command = "ssh-keyscan ${self.ip_address} >> ~/.ssh/known_hosts"
  }
}

# Special ingress node. Don't scale this one, we want it to just run NGINX.
# Why? It's easier this way to manage IP addresses. We want this to be the one
# public ingress to the cluster, and it's easiest if the IP address for this
# particular node stays the same no matter what. On Linode, that's easiest
# if we just keep the linode instance the same, forever. So, we put NGINX
# on its own node just so that we never have to worry about moving it.
resource "linode_instance" "nginx_node" {
  label = "nomad-nginx-node"
  image = "linode/debian10"
  region = "us-west"
  type = "g6-standard-1"
  authorized_keys = [chomp(data.local_file.ssh_pubkey.content)]
  root_pass = var.root_pass
  backups_enabled = true
  watchdog_enabled= true

  provisioner "file" {
    source      = "${abspath(path.root)}/../certs/consul-agent-certs"
    destination = "/root"

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "file" {
    source      = "scripts/provision_agent.sh"
    destination = "~/provision_agent.sh"

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "file" {
    source      = "${abspath(path.root)}/../certs/nomad-agent-certs"
    destination = "/root"

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "file" {
    source      = "scripts/provision_agent_nginx.sh"
    destination = "~/provision_agent_nginx.sh"

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x provision_agent.sh",
      "./provision_agent.sh nginx ${var.consul_mgmt_token} ${var.consul_gossip_token} ${linode_instance.nomad_server.ip_address} ${var.new_relic_license_key} ${var.new_relic_license_key}",
      "chmod +x provision_agent_nginx.sh",
      "./provision_agent_nginx.sh nginx ${var.consul_mgmt_token} ${var.rails_domain} ${var.docker_domain} ${var.letsencrypt_email}"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "local-exec" {
    command = "ssh-keyscan ${self.ip_address} >> ~/.ssh/known_hosts"
  }
}

# Generic node with no particular host volumes. Suitable for web, sidekiq, or
# "stateless" DB like memcached/redis
#
# Scale this node up with count if you need more Sidekiq or Rails processes
resource "linode_instance" "nomad_node" {
  count = 3

  label = "nomad-agent-${count.index}"
  image = "linode/debian10"
  region = "us-west"
  type = "g6-standard-4"
  authorized_keys = [chomp(data.local_file.ssh_pubkey.content)]
  root_pass = var.root_pass
  backups_enabled = true
  watchdog_enabled= true

  provisioner "file" {
    source      = "${abspath(path.root)}/../certs/consul-agent-certs"
    destination = "/root"

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "file" {
    source      = "scripts/provision_agent.sh"
    destination = "~/provision_agent.sh"

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "file" {
    source      = "${abspath(path.root)}/../certs/nomad-agent-certs"
    destination = "/root"

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "file" {
    source      = "scripts/provision_agent_novol.sh"
    destination = "~/provision_agent_novol.sh"

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x provision_agent.sh",
      "./provision_agent.sh ${count.index} ${var.consul_mgmt_token} ${var.consul_gossip_token} ${linode_instance.nomad_server.ip_address} ${var.new_relic_license_key}",
      "chmod +x provision_agent_novol.sh",
      "./provision_agent_novol.sh ${count.index} ${var.consul_mgmt_token}"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = self.ip_address
    }
  }

  provisioner "local-exec" {
    command = "ssh-keyscan ${self.ip_address} >> ~/.ssh/known_hosts"
  }
}

# Note this means that the server must have jq installed during the provision step
data "external" "nomad_bootstrap_acl" {
  program = ["sh", "scripts/get_bootstrap.sh", data.local_file.ssh_privkey.filename]
  query = { "ip_address": linode_instance.nomad_server.ip_address }
}