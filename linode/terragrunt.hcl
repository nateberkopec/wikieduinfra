remote_state {
  backend = "local"

  generate = {
    path      = "backend.tf"
    if_exists = "skip"
  }

  config = {
    path = "terraform.tfstate"
  }
}