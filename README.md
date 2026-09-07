# Homelab Infrastructure

Infrastructure-as-code and configuration management for a Proxmox-based homelab.

This repository manages the lifecycle of virtual machines, baseline operating-system configuration, management tooling, and selected services using:

- **Proxmox VE** for virtualization
- **OpenTofu** for infrastructure provisioning
- **Ansible** for configuration management
- **Cloudflare R2** for remote OpenTofu state
- **Tailscale** for secure remote management access
- **Debian 13** as the default VM base image

The goal is to keep the homelab **reproducible, recoverable, and easy to rebuild** without making the Proxmox host itself the control plane.

---

## Architecture

```text
                         Remote access
                             │
                             │ Tailscale
                             ▼
                        ┌───────────┐
                        │  mgmt-01  │
                        │-----------│
                        │ OpenTofu  │
                        │ Ansible   │
                        │ Git       │
                        │ SSH       │
                        └─────┬─────┘
                              │
              ┌───────────────┴────────────────┐
              │                                │
              │ Proxmox API                    │ SSH / Ansible
              ▼                                ▼
        ┌─────────────┐                ┌─────────────────┐
        │ Proxmox VE  │                │ Managed VMs     │
        │ 192.168.10.2│                │                 │
        └──────┬──────┘                │ ai-gateway-01   │
               │                       │ hermes-01       │
               │                       │ future nodes    │
               ▼                       └─────────────────┘
        ┌─────────────┐
        │ Debian 13   │
        │ template    │
        │ VM 9000     │
        └─────────────┘

Remote state:
mgmt-01 ───────► Cloudflare R2
```

`mgmt-01` is the primary controller. A local workstation or WSL environment can be used as a bootstrap/recovery controller if `mgmt-01` needs to be rebuilt.

---

## Design Principles

### Infrastructure should be disposable

VMs should be recreatable from:

1. OpenTofu configuration
2. the Debian golden image
3. Ansible roles
4. external state and credentials

`mgmt-01` is therefore important, but not irreplaceable.

### Proxmox is the hypervisor, not the automation workstation

Routine infrastructure operations are performed from `mgmt-01`.

Direct Proxmox shell access is reserved for:

- hypervisor maintenance
- troubleshooting
- recovery
- bootstrap operations

### State must live outside the infrastructure it describes

OpenTofu state is stored in **Cloudflare R2**, rather than relying on the local disk of `mgmt-01`.

This avoids a circular recovery dependency:

```text
mgmt-01 lost
    │
    ▼
rebuild from template
    │
    ▼
clone repository
    │
    ▼
restore credentials
    │
    ▼
tofu init
    │
    ▼
recover state from R2
```

### Separate credentials by trust domain

Different credentials are used for different purposes:

```text
~/.ssh/github_ed25519
    └── GitHub

~/.ssh/ansible_ed25519
    └── Managed VMs

~/.config/homelab/pve-token.json
    └── Proxmox API

~/.config/homelab/r2-state.json
    └── Cloudflare R2 state backend
```

Private keys and secrets must never be committed to Git.

---

## Repository Structure

```text
.
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── tofu_inventory.py
│   │   ├── group_vars/
│   │   │   └── all.yml
│   │   └── host_vars/
│   │       └── mgmt-01.yml
│   ├── playbooks/
│   │   └── site.yml
│   └── roles/
│       ├── common/
│       ├── management/
│       ├── ai_gateway/
│       └── hermes/
│
├── tofu/
│   ├── modules/
│   │   └── debian-vm/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── versions.tf
│   └── environments/
│       └── home/
│           ├── backend.tf
│           ├── main.tf
│           ├── providers.tf
│           ├── variables.tf
│           └── outputs.tf
│
├── scripts/
│   ├── init-pve.sh
│   ├── init-r2.sh
│   ├── bootstrap-known-hosts.sh
│   └── deploy.sh
│
├── keys/
│   ├── admin_ed25519.pub
│   └── ansible_ed25519.pub
│
└── README.md
```

---

## Current Infrastructure

### Proxmox

- Proxmox management address: `192.168.10.2`
- Default LAN: `192.168.10.0/24`
- Gateway: `192.168.10.254`
- Proxmox node remains directly reachable independently of experimental routing/firewall VMs

### Storage

| Storage | Device | Purpose |
|---|---|---|
| Proxmox system storage | Crucial P3 Plus 1 TB | Hypervisor + lower-value workloads |
| `fast-vm` | ZHITAI TiPlus 7100 4 TB | Primary VM storage |

### Golden Image

| Setting | Value |
|---|---|
| Template | `debian-13-base` |
| VM ID | `9000` |
| OS | Debian 13 generic cloud image |
| CPU | host |
| vCPU | 2 |
| RAM | 1 GB |
| Disk | 15 GB |
| Network | DHCP on `vmbr0` |
| Guest Agent | Enabled |
| Cloud-init | Enabled |

The template is sanitized before conversion and generates unique machine IDs, SSH host keys, DHCP leases, and hostnames.

---

## Managed VMs

The environment uses a `for_each` VM map in OpenTofu.

Example:

```hcl
vms = {
  mgmt-01 = {
    vm_id          = 190
    cores          = 2
    memory         = 4096
    ansible_groups = ["management"]
  }

  ai-gateway-01 = {
    vm_id          = 201
    cores          = 4
    memory         = 8192
    ansible_groups = ["ai_gateway"]
  }

  hermes-01 = {
    vm_id          = 202
    cores          = 4
    memory         = 8192
    ansible_groups = ["agents"]
  }
}
```

### Current roles

| VM / Group | Purpose |
|---|---|
| `mgmt-01` / `management` | OpenTofu, Ansible, Git, SSH, management tooling |
| `ai-gateway-01` / `ai_gateway` | AI model gateway and Ollama backend |
| `hermes-01` / `agents` | Hermes agent runtime |

---

## OpenTofu

The repository uses the `bpg/proxmox` provider.

```hcl
terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}
```

The provider endpoint is:

```hcl
provider "proxmox" {
  endpoint = "https://192.168.10.2:8006/"
  insecure = true
}
```

`insecure = true` is currently required because the Proxmox endpoint uses a self-signed certificate. Replacing this with proper certificate trust is planned.

---

## Remote State

OpenTofu state is stored in a private **Cloudflare R2** bucket using the S3-compatible backend.

Example:

```hcl
terraform {
  backend "s3" {
    bucket = "YOUR-R2-BUCKET"
    key    = "proxmox/home/terraform.tfstate"
    region = "auto"

    endpoints = {
      s3 = "https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com"
    }

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true

    use_path_style = true
    use_lockfile   = true
  }
}
```

Credentials are loaded from:

```text
~/.config/homelab/r2-state.json
```

and exported as:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
```

State locking should be validated using a two-client contention test before relying on it for concurrent operations.

---

## Proxmox API Authentication

OpenTofu uses a dedicated Proxmox API token.

Credential file:

```text
~/.config/homelab/pve-token.json
```

Example structure:

```json
{
  "name": "terraform@pve!homelab",
  "token": "REDACTED"
}
```

The token is loaded by `scripts/init-pve.sh` and exposed only to the `tofu-pve` wrapper process.

---

## Ansible

Ansible inventory is generated dynamically from OpenTofu outputs.

```text
OpenTofu state
     │
     ▼
ansible_inventory output
     │
     ▼
tofu_inventory.py
     │
     ▼
Ansible groups + ansible_host
```

Example output definition:

```hcl
output "ansible_inventory" {
  value = {
    for name, vm in module.vm :
    name => {
      vm_id          = vm.vm_id
      ipv4_addresses = vm.ipv4_addresses
      groups          = var.vms[name].ansible_groups
    }
  }
}
```

SSH defaults:

```yaml
ansible_user: homelab
ansible_ssh_private_key_file: ~/.ssh/ansible_ed25519
```

`mgmt-01` configures itself locally:

```yaml
ansible_connection: local
```

---

## SSH Trust

SSH host-key verification is enabled.

New VM host keys are bootstrapped using:

```bash
./scripts/bootstrap-known-hosts.sh
```

The script reads hosts from the dynamic inventory, waits for SSH, collects ED25519 host keys, displays the fingerprint, adds the key to `known_hosts`, and refuses to silently replace changed keys.

If an IP is reused after rebuilding a VM:

```bash
ssh-keygen -R <IP>
```

Verify that the rebuild was expected before trusting the replacement key.

---

## Deployment Workflow

Normal deployment:

```bash
./scripts/deploy.sh
```

Flow:

```text
tofu plan
    │
    ▼
manual approval
    │
    ▼
tofu apply
    │
    ▼
bootstrap SSH trust
    │
    ▼
ansible-playbook
```

Equivalent manual commands:

```bash
cd tofu/environments/home
tofu-pve plan
tofu-pve apply

../../../scripts/bootstrap-known-hosts.sh

cd ../../../ansible
ansible-playbook playbooks/site.yml
```

---

## AI Gateway

`ai-gateway-01` currently hosts Ollama.

Intended architecture:

```text
Hermes
   │
   ▼
AI gateway endpoint
   │
   ▼
Caddy
   │
   ▼
127.0.0.1:11434
   │
   ▼
Ollama
```

Ollama should eventually listen only on localhost:

```text
OLLAMA_HOST=127.0.0.1:11434
```

Caddy becomes the externally reachable service boundary.

Future work:

- authentication
- provider routing
- model selection
- request policy
- logging and metrics
- access controls

---

## Tailscale

Tailscale is installed on `mgmt-01` for secure remote management.

```text
Laptop / Desktop
       │
       │ Tailscale
       ▼
    mgmt-01
       │
       ├── OpenTofu → Proxmox
       └── Ansible  → managed VMs
```

`mgmt-01` is currently a management endpoint, not a subnet router.

---

## Security Model

Trust hierarchy:

```text
Highest trust
    │
    ├── Proxmox host
    ├── mgmt-01
    ├── ai-gateway-01
    └── agent / sandbox workloads
Lowest trust
```

Autonomous agents and coding sandboxes should eventually be prevented from reaching Proxmox management, `mgmt-01`, network infrastructure, and hypervisor APIs.

Planned trust-zone networks:

| Zone | Network |
|---|---|
| Management | `10.10.10.0/24` |
| Servers | `10.10.20.0/24` |
| Lab / Kubernetes | `10.10.30.0/24` |
| Sandbox | `10.10.40.0/24` |
| Media | `10.10.50.0/24` |

---

## Recovery

If `mgmt-01` is lost:

1. Use WSL or another trusted controller.
2. Recreate `mgmt-01` from OpenTofu.
3. Restore the management SSH key.
4. Restore the Proxmox API credential.
5. Restore the R2 state credential.
6. Clone this repository.
7. Run:

```bash
tofu init
tofu-pve plan
```

8. Confirm the plan matches the existing infrastructure.
9. Run Ansible to restore management tooling.

Because state is stored externally, rebuilding `mgmt-01` does not require reconstructing infrastructure state manually.

---

## Prerequisites

The controller requires:

- OpenTofu
- Ansible
- Git
- Python 3
- `jq`
- OpenSSH client
- Proxmox API access
- R2 credentials
- SSH private key for managed hosts

Optional:

- Tailscale for remote access

---

## Useful Commands

### OpenTofu

```bash
tofu-pve plan
tofu-pve apply
tofu-pve state list
tofu-pve output
```

### Ansible

```bash
ansible-inventory --graph
ansible all -m ping
ansible all -m command -a "uptime"
ansible-playbook playbooks/site.yml
```

AI gateway only:

```bash
ansible-playbook playbooks/site.yml --limit ai-gateway-01
```

### SSH

```bash
ssh -G <host> | grep -i identityfile
ssh -v <host>
```

### Tailscale

```bash
tailscale status
tailscale ip -4
```

---

## Roadmap

### Near term

- [x] Proxmox golden image
- [x] Reusable OpenTofu VM module
- [x] Dynamic VM map with `for_each`
- [x] Dynamic Ansible inventory
- [x] SSH host-key bootstrap
- [x] Management VM
- [x] Tailscale on `mgmt-01`
- [x] Ollama on `ai-gateway-01`
- [ ] Complete Cloudflare R2 migration and locking test
- [ ] Put Caddy in front of Ollama
- [ ] Bind Ollama to localhost
- [ ] Implement Hermes Ansible role
- [ ] Deploy `hermes-01`

### Later

- [ ] Internal DNS
- [ ] Proper internal PKI / trusted TLS
- [ ] Network segmentation
- [ ] OPNsense lab
- [ ] K3s cluster
- [ ] Cilium / eBPF experimentation
- [ ] Monitoring and observability
- [ ] AI gateway provider routing
- [ ] Coding sandbox
- [ ] Media services
- [ ] Automated backups
- [ ] Secrets-management improvement
- [ ] CI validation for OpenTofu and Ansible

---

## Non-Goals

This repository is currently intended for a **single-user homelab**, not a production multi-tenant environment.

It deliberately prioritizes reproducibility, learning, recoverability, sensible security boundaries, and incremental complexity over building a production-grade platform prematurely.

---

## License

Add a license if this repository will be made public or reused by others.
