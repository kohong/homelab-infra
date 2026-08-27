$TokenFile = ".secrets\pve-token.json"

if (-not (Test-Path $TokenFile)) {
    throw "Proxmox API token file not found: $TokenFile"
}

try {
    $Credential = Get-Content $TokenFile -Raw | ConvertFrom-Json
}
catch {
    throw "Unable to parse Proxmox token JSON: $_"
}

if ([string]::IsNullOrWhiteSpace($Credential.token_id)) {
    throw "Token file does not contain a 'name' value."
}

if ([string]::IsNullOrWhiteSpace($Credential.token_secret)) {
    throw "Token file does not contain a 'token' value."
}

# Format expected by bpg/proxmox:
# terraform@pve!homelab=<token-secret>
$env:PROXMOX_VE_API_TOKEN = "$($Credential.token_id)=$($Credential.token_secret)"

Remove-Variable Credential

Write-Host "Proxmox API token loaded for this PowerShell session."
