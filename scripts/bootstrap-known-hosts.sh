#!/usr/bin/env bash
set -euo pipefail

ROOT="${HOME}/src/homelab-infra"
ANSIBLE_DIR="${ROOT}/ansible"
KNOWN_HOSTS="${HOME}/.ssh/known_hosts"

SSH_WAIT_ATTEMPTS=30
SSH_WAIT_DELAY=2
SSH_KEYSCAN_TIMEOUT=5

mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

touch "${KNOWN_HOSTS}"
chmod 600 "${KNOWN_HOSTS}"

wait_for_ssh() {
    local host="$1"

    for ((attempt=1; attempt<=SSH_WAIT_ATTEMPTS; attempt++)); do
        if timeout 2 bash -c "</dev/tcp/${host}/22" 2>/dev/null; then
            return 0
        fi

        echo "  Waiting for SSH on ${host} (${attempt}/${SSH_WAIT_ATTEMPTS})..."
        sleep "${SSH_WAIT_DELAY}"
    done

    return 1
}

get_remote_hosts() {
    cd "${ANSIBLE_DIR}"

    ansible-inventory --list |
        jq -r '
            ._meta.hostvars
            | to_entries[]
            | select(.value.ansible_connection != "local")
            | select(.value.ansible_host != null)
            | .value.ansible_host
        ' |
        sort -u
}

add_host_key() {
    local host="$1"

    echo "Checking ${host}..."

    # Already known: leave it alone.
    if ssh-keygen -F "${host}" -f "${KNOWN_HOSTS}" >/dev/null 2>&1; then
        echo "  Existing host key found. Leaving unchanged."
        return 0
    fi

    if ! wait_for_ssh "${host}"; then
        echo "  ERROR: SSH did not become available on ${host}" >&2
        return 1
    fi

    local scanned_key

    scanned_key="$(
        ssh-keyscan \
            -T "${SSH_KEYSCAN_TIMEOUT}" \
            -t ed25519 \
            "${host}" 2>/dev/null
    )"

    if [[ -z "${scanned_key}" ]]; then
        echo "  ERROR: Could not retrieve ED25519 host key from ${host}" >&2
        return 1
    fi

    echo "  New host key fingerprint:"
    printf '%s\n' "${scanned_key}" | ssh-keygen -lf -

    # Hash hostnames/IPs in known_hosts.
    ssh-keyscan \
        -H \
        -T "${SSH_KEYSCAN_TIMEOUT}" \
        -t ed25519 \
        "${host}" 2>/dev/null >> "${KNOWN_HOSTS}"

    echo "  Added ${host} to known_hosts."
}

main() {
    local hosts

    echo "Reading remote hosts from Ansible inventory..."

    hosts="$(get_remote_hosts)"

    if [[ -z "${hosts}" ]]; then
        echo "No remote hosts found."
        exit 0
    fi

    local failures=0

    while IFS= read -r host; do
        [[ -z "${host}" ]] && continue

        if ! add_host_key "${host}"; then
            failures=$((failures + 1))
        fi
    done <<< "${hosts}"

    echo

    if (( failures > 0 )); then
        echo "Bootstrap completed with ${failures} failure(s)." >&2
        exit 1
    fi

    echo "SSH known_hosts bootstrap complete."
}

main "$@"
