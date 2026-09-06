#!/usr/bin/env bash

TOKEN_FILE="${HOME}/.secrets/pve-token.json"

if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "Proxmox token file not found: $TOKEN_FILE" >&2
    return 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required." >&2
    return 1
fi

TOKEN_NAME="$(jq -r '.token_id // empty' "$TOKEN_FILE")"
TOKEN_SECRET="$(jq -r '.token_secret // empty' "$TOKEN_FILE")"

if [[ -z "$TOKEN_NAME" || -z "$TOKEN_SECRET" ]]; then
    unset TOKEN_NAME TOKEN_SECRET
    echo "Invalid Proxmox token file." >&2
    return 1
fi

export PROXMOX_VE_API_TOKEN="${TOKEN_NAME}=${TOKEN_SECRET}"

unset TOKEN_NAME TOKEN_SECRET

