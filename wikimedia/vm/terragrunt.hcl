include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../modules//vm"
}

inputs = {
  path_to_certs = abspath("./certs")
}