#!/usr/bin/env bash
set -euo pipefail

TOKEN_FILE="${HOME}/.secrets/pve-token.json"

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "Proxmox API token file not found: $TOKEN_FILE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required. Install it with: sudo apt install jq" >&2
  exit 1
fi

TOKEN_NAME="$(jq -r '.token_id // empty' "$TOKEN_FILE")"
TOKEN_SECRET="$(jq -r '.token_secret // empty' "$TOKEN_FILE")"

if [[ -z "$TOKEN_NAME" ]]; then
  echo "Token file does not contain a valid 'token-id' field." >&2
  exit 1
fi

if [[ -z "$TOKEN_SECRET" ]]; then
  echo "Token file does not contain a valid 'token-secret' field." >&2
  exit 1
fi

export PROXMOX_VE_API_TOKEN="${TOKEN_NAME}=${TOKEN_SECRET}"

unset TOKEN_NAME
unset TOKEN_SECRET

echo "PROXMOX_VE_API_TOKEN loaded."
