locals {
  ssh_public_keys = [
    trimspace(file("${path.root}/../../../keys/ansible_ed25519.pub")),
    trimspace(file("${path.root}/../../../keys/id_ed25519.pub"))
  ]
}
