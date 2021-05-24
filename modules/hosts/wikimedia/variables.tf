variable "ssh_privkey" {
  type = string
  description = "Local path to the SSH public key for accessing the cluster"
}

variable "wikimedia_username" {
  type = string
  description = "Username that we'll SSH with"
}

variable "nomad_server_ip_address" {
  type = string
}

variable "bastion_host" {
  type = string
}