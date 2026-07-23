[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CaCertificatePath,

    [string]$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
)

$ErrorActionPreference = 'Stop'
$hostsEntry = '192.168.50.10 gitea.dev.home.arpa registry.dev.home.arpa'
$hostsContent = Get-Content -LiteralPath $HostsPath

if (-not ($hostsContent -match '^\s*192\.168\.50\.10\s+.*\bgitea\.dev\.home\.arpa\b')) {
    Add-Content -LiteralPath $HostsPath -Value $hostsEntry -Encoding ascii
}

$certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
    $CaCertificatePath
)
$store = [System.Security.Cryptography.X509Certificates.X509Store]::new(
    'Root',
    'LocalMachine'
)
$store.Open(
    [System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite
)
try {
    @(
        $store.Certificates |
            Where-Object {
                $_.Subject -eq $certificate.Subject -and
                $_.Thumbprint -ne $certificate.Thumbprint
            }
    ) | ForEach-Object {
        $store.Remove($_)
    }
    if (-not ($store.Certificates | Where-Object Thumbprint -eq $certificate.Thumbprint)) {
        $store.Add($certificate)
    }
}
finally {
    $store.Close()
}

Clear-DnsClientCache
