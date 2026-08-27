# Homelab

Infrastructure-as-code and configuration management for my Proxmox homelab.

## Architecture

- Proxmox VE
- OpenTofu
- `bpg/proxmox`
- Debian 13 golden template (VM 9000)
- Ansible (planned)

## Structure

- `tofu/modules/debian-vm` — reusable Debian VM module
- `tofu/environments/home` — home Proxmox environment

## OpenTofu

From `tofu/environments/home`:

    tofu init
    tofu fmt -check -recursive
    tofu validate
    tofu plan

Proxmox credentials are supplied externally and are not stored in this repository.
