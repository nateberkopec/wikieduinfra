terraform {
  required_providers {
    null = {
      source = "hashicorp/null"
      version = "3.1.0"
    }
  }
}

locals {
  scp_cmd_consul = var.bastion_host != null ? "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${data.local_file.ssh_privkey.filename} -o ProxyCommand='ssh -a -W %h:%p ${var.ssh_user}@${var.bastion_host}' -r ${var.ssh_user}@${var.nomad_server_ip_address}:/etc/clusterconfig/consul-agent-certs ${var.path_to_certs}/" : "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${data.local_file.ssh_privkey.filename} -r ${var.ssh_user}@${var.nomad_server_ip_address}:/etc/clusterconfig/consul-agent-certs ${var.path_to_certs}/"
  scp_cmd_nomad = var.bastion_host != null ? "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${data.local_file.ssh_privkey.filename} -o ProxyCommand='ssh -a -W %h:%p ${var.ssh_user}@${var.bastion_host}' -r ${var.ssh_user}@${var.nomad_server_ip_address}:/etc/clusterconfig/nomad-agent-certs ${var.path_to_certs}/" : "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${data.local_file.ssh_privkey.filename} -r ${var.ssh_user}@${var.nomad_server_ip_address}:/etc/clusterconfig/nomad-agent-certs ${var.path_to_certs}/"
  db_node_count = var.mariadb_node_ip_address == null ? 0 : 1
}

# Small node solely for running the nomad server
# and the consul server.
# We cannot schedule workloads here because they might
# steal resources from the nomad server.
resource "null_resource" "nomad_server" {

  provisioner "file" {
    source      = "scripts/provision_host.sh"
    destination = "~/provision_host.sh"

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.nomad_server_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x provision_host.sh",
      "./provision_host.sh ${var.consul_mgmt_token} ${var.consul_gossip_token} ${var.new_relic_license_key} ${var.nomad_server_external_ip_address}"
    ]

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.nomad_server_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "local-exec" {
    command = "mkdir -p ${var.path_to_certs}/consul-agent-certs/"
  }

  provisioner "local-exec" {
    command = local.scp_cmd_consul
  }

  provisioner "local-exec" {
    command = local.scp_cmd_nomad
  }
}

# Node which contains the host volume for MariaDB
resource "null_resource" "mariadb_node" {
  count = local.db_node_count

  depends_on = [ null_resource.nomad_server ]

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/clusterconfig",
      "sudo chown -R $USER /etc/clusterconfig"
    ]

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.mariadb_node_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "file" {
    source      = "${var.path_to_certs}/"
    destination = "/etc/clusterconfig"

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.mariadb_node_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "file" {
    source      = "scripts/provision_agent.sh"
    destination = "~/provision_agent.sh"

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.mariadb_node_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x provision_agent.sh",
      "./provision_agent.sh mariadb ${var.consul_mgmt_token} ${var.consul_gossip_token} ${var.nomad_server_ip_address} ${var.new_relic_license_key}"
    ]

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.mariadb_node_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "file" {
    source      = "scripts/provision_agent_mariadb.sh"
    destination = "~/provision_agent_mariadb.sh"

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.mariadb_node_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x provision_agent_mariadb.sh",
      "./provision_agent_mariadb.sh mariadb ${var.consul_mgmt_token}"
    ]

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.mariadb_node_ip_address
      bastion_host = var.bastion_host
    }
  }
}

# Node which contains the host volume for Rails web
resource "null_resource" "rails_web_node" {
  depends_on = [ null_resource.nomad_server ]

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/clusterconfig",
      "sudo chown -R $USER /etc/clusterconfig"
    ]

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.rails_web_node_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "file" {
    source      = "${var.path_to_certs}/"
    destination = "/etc/clusterconfig"

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.rails_web_node_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "file" {
    source      = "scripts/provision_agent.sh"
    destination = "~/provision_agent.sh"

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.rails_web_node_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x provision_agent.sh",
      "./provision_agent.sh railsweb ${var.consul_mgmt_token} ${var.consul_gossip_token} ${var.nomad_server_ip_address} ${var.new_relic_license_key}"
    ]

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.rails_web_node_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "file" {
    source      = "scripts/provision_agent_railsweb.sh"
    destination = "~/provision_agent_railsweb.sh"

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.rails_web_node_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x provision_agent_railsweb.sh",
      "./provision_agent_railsweb.sh railsweb ${var.consul_mgmt_token}"
    ]

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.rails_web_node_ip_address
      bastion_host = var.bastion_host
    }
  }
}

# Special ingress node. Don't scale this one, we want it to just run NGINX.
# Why? It's easier this way to manage IP addresses. We want this to be the one
# public ingress to the cluster, and it's easiest if the IP address for this
# particular node stays the same no matter what. On Linode, that's easiest
# if we just keep the linode instance the same, forever. So, we put NGINX
# on its own node just so that we never have to worry about moving it.
resource "null_resource" "nginx_node" {
  depends_on = [ null_resource.nomad_server ]

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/clusterconfig",
      "sudo chown -R $USER /etc/clusterconfig"
    ]

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.nginx_node_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "file" {
    source      = "${var.path_to_certs}/"
    destination = "/etc/clusterconfig"

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.nginx_node_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "file" {
    source      = "scripts/provision_agent.sh"
    destination = "~/provision_agent.sh"

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.nginx_node_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x provision_agent.sh",
      "./provision_agent.sh nginx ${var.consul_mgmt_token} ${var.consul_gossip_token} ${var.nomad_server_ip_address} ${var.new_relic_license_key} ${var.new_relic_license_key}"
    ]

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.nginx_node_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "file" {
    source      = "scripts/provision_agent_nginx.sh"
    destination = "~/provision_agent_nginx.sh"

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.nginx_node_ip_address
      bastion_host = var.bastion_host
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x provision_agent_nginx.sh",
      "./provision_agent_nginx.sh nginx ${var.consul_mgmt_token} ${var.rails_domain} ${var.docker_domain} ${var.letsencrypt_email}"
    ]

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.nginx_node_ip_address
      bastion_host = var.bastion_host
    }
  }
}

# Generic node with no particular host volumes. Suitable for web, sidekiq, or
# "stateless" DB like memcached/redis
#
# Scale this node up with count if you need more Sidekiq or Rails processes
resource "null_resource" "nomad_node" {
  depends_on = [ null_resource.nomad_server ]
  count = 2

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/clusterconfig",
      "sudo chown -R $USER /etc/clusterconfig"
    ]

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.nomad_agent_ip_addresses[count.index]
      bastion_host = var.bastion_host
    }
  }

  provisioner "file" {
    source      = "${var.path_to_certs}/"
    destination = "/etc/clusterconfig"

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.nomad_agent_ip_addresses[count.index]
      bastion_host = var.bastion_host
    }
  }

  provisioner "file" {
    source      = "scripts/provision_agent.sh"
    destination = "~/provision_agent.sh"

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.nomad_agent_ip_addresses[count.index]
      bastion_host = var.bastion_host
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x provision_agent.sh",
      "./provision_agent.sh ${count.index} ${var.consul_mgmt_token} ${var.consul_gossip_token} ${var.nomad_server_ip_address} ${var.new_relic_license_key}"
    ]

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.nomad_agent_ip_addresses[count.index]
      bastion_host = var.bastion_host
    }
  }

  provisioner "file" {
    source      = "scripts/provision_agent_novol.sh"
    destination = "~/provision_agent_novol.sh"

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.nomad_agent_ip_addresses[count.index]
      bastion_host = var.bastion_host
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x provision_agent_novol.sh",
      "./provision_agent_novol.sh ${count.index} ${var.consul_mgmt_token}"
    ]

    connection {
      type     = "ssh"
      user     = var.ssh_user
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.nomad_agent_ip_addresses[count.index]
      bastion_host = var.bastion_host
    }
  }
}

data "local_file" "ssh_privkey" {
  filename = var.ssh_privkey
}