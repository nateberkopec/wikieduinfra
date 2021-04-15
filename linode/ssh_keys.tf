# Point this to wherever the SSH key you want to use to manage your
# infra lives
data "local_file" "ssh_pubkey" {
  filename = "/Users/nateberkopec/.ssh/wikied_linode_rsa.pub"
}

data "local_file" "ssh_privkey" {
  filename = "/Users/nateberkopec/.ssh/wikied_linode_rsa"
}