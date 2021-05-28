terraform {
  source = "../../modules/hosts//linode"
}

include {
  path = find_in_parent_folders()
}
