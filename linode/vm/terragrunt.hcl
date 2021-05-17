terraform {
  source = "../../modules//vm"
}

inputs = {
  path_to_certs = abspath("./certs")
}