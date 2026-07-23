$ErrorActionPreference = "Stop"
if (Test-Path package-lock.json) {
    npm ci
}
else {
    npm install --package-lock-only
    npm ci
}
