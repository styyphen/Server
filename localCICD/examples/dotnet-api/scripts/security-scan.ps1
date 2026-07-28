$ErrorActionPreference = "Stop"
if (Get-Command gitleaks -ErrorAction SilentlyContinue) {
    gitleaks detect --source . --config .gitleaks.toml --redact
}
else {
    Write-Warning "gitleaks not found; skipping secret scan."
}

dotnet list package --vulnerable --include-transitive

