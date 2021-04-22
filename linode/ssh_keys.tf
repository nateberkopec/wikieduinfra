# Point this to wherever the SSH key you want to use to manage your
# infra lives
data "local_file" "ssh_pubkey" {
  filename = "/home/sage/.ssh/terraform_ed25519.pub"
}

data "local_file" "ssh_privkey" {
  filename = "/home/sage/.ssh/terraform_ed25519"
}
