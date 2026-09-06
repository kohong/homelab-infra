locals {
  ansible_public_key = trimspace(
    file("${path.root}/../../../keys/ansible_ed25519.pub")
  )
}
