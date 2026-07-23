$ErrorActionPreference = "Stop"
if (Get-Command gitleaks -ErrorAction SilentlyContinue) {
    gitleaks detect --source . --config .gitleaks.toml --redact
}
else {
    Write-Warning "gitleaks not found; skipping secret scan."
}

if (Get-Command npm -ErrorAction SilentlyContinue) {
    npm audit --audit-level=high
}
