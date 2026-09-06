#!/usr/bin/env bash
set -euo pipefail

ROOT="${HOME}/src/homelab-infra"
TOFU_DIR="${ROOT}/tofu/environments/home"
ANSIBLE_DIR="${ROOT}/ansible"

cd "${TOFU_DIR}"

echo "==> Planning infrastructure"
tofu-pve plan -out=tfplan

echo
read -rp "Apply this plan? [y/N] " answer

case "${answer}" in
    y|Y|yes|YES)
        ;;
    *)
        rm -f tfplan
        echo "Deployment cancelled."
        exit 0
        ;;
esac

echo
echo "==> Applying infrastructure"
tofu-pve apply tfplan
rm -f tfplan

echo
echo "==> Bootstrapping SSH trust"
"${ROOT}/scripts/bootstrap-known-hosts.sh"

echo
echo "==> Running Ansible"
cd "${ANSIBLE_DIR}"
ansible-playbook playbooks/site.yml

echo
echo "Deployment complete."
