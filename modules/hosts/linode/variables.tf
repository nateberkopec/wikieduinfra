variable "linode_token" {
  type    = string
  description = "Your Linode Access Token."
  # sensitive = true
}

variable "ssh_pubkey" {
  type = string
  description = "Local path to the SSH public key for accessing the cluster"
}

variable "root_pass" {
  type = string
  description = <<EOT
    All root passwords will be set to this value.
    Use `openssl rand -hex 16` to generate a sufficiently random value.
  EOT
  # sensitive = true
}