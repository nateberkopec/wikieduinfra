terraform {
  required_providers {
    null = {
      source = "hashicorp/null"
      version = "3.1.0"
    }
  }
}

data "local_file" "ssh_privkey" {
  filename = var.ssh_privkey
}

# Small node solely for running the nomad server
# and the consul server.
# We cannot schedule workloads here because they might
# steal resources from the nomad server.
resource "null_resource" "nomad_server" {
  provisioner "remote-exec" {
    inline = [
      "echo 'successful connection'"
    ]

    connection {
      type     = "ssh"
      user     = var.wikimedia_username
      private_key = chomp(data.local_file.ssh_privkey.content)
      host     = var.nomad_server_ip_address
      bastion_host = var.bastion_host
    }
  }
}