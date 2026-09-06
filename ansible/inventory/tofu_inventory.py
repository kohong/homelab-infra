#!/usr/bin/env python3

import json
import subprocess
import sys
from pathlib import Path


TOFU_DIR = (
    Path.home()
    / "src"
    / "homelab-infra"
    / "tofu"
    / "environments"
    / "home"
)

def get_tofu_inventory():
    result = subprocess.run(
        ["tofu-pve", "output", "-json", "ansible_inventory"],
        cwd=TOFU_DIR,
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        print(
            f"OpenTofu failed:\n{result.stderr}",
            file=sys.stderr,
        )
        sys.exit(result.returncode)

    output = result.stdout.strip()

    if not output:
        print(
            "OpenTofu returned empty output for ansible_inventory",
            file=sys.stderr,
        )
        sys.exit(1)

    try:
        return json.loads(output)
    except json.JSONDecodeError as exc:
        print(
            f"OpenTofu returned invalid JSON: {exc}\n"
            f"Output was:\n{output}",
            file=sys.stderr,
        )
        sys.exit(1)

def get_primary_ipv4(addresses):
    if not addresses:
        return None

    for address_group in addresses:
        if not address_group:
            continue

        if isinstance(address_group, str):
            address_group = [address_group]

        for address in address_group:
            if not address:
                continue

            if address.startswith("127."):
                continue

            if address.startswith("169.254."):
                continue

            return address

    return None

def build_inventory():
    tofu_vms = get_tofu_inventory()

    inventory = {
        "_meta": {
            "hostvars": {}
        },
        "all": {
            "children": []
        },
    }

    for hostname, vm in tofu_vms.items():
        ip = get_primary_ipv4(vm.get("ipv4_addresses") or [])

        if not ip:
            continue

        inventory["_meta"]["hostvars"][hostname] = {
            "ansible_host": ip,
            "ansible_user": "homelab",
        }

        for group in vm.get("groups", []):
            if group not in inventory:
                inventory[group] = {
                    "hosts": []
                }

            inventory[group]["hosts"].append(hostname)

            if group not in inventory["all"]["children"]:
                inventory["all"]["children"].append(group)

    return inventory


if __name__ == "__main__":
    if "--list" in sys.argv:
        print(json.dumps(build_inventory(), indent=2))
    elif "--host" in sys.argv:
        print("{}")
    else:
        print(json.dumps(build_inventory(), indent=2))
