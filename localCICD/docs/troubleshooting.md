# Troubleshooting

Start with health and ports before debugging application code.

## Platform Will Not Start

Check Docker:

```powershell
docker version
docker compose config
docker compose up -d
```

Check service status:

```powershell
docker compose ps
./scripts/health-check.ps1
```

## Port Conflict

Expected ports:

```text
3000  Git server
2222  Git SSH
5000  Registry
4566  LocalStack
10000 Azurite Blob
10001 Azurite Queue
10002 Azurite Table
4443  fake-gcs-server
9000  SonarQube
```

Find listeners:

```powershell
Get-NetTCPConnection -LocalPort 3000,2222,5000,4566,10000,10001,10002,4443,9000 -ErrorAction SilentlyContinue
```

Change the platform port mapping or stop the conflicting service.

## Local Git Push Fails

Check the remote:

```powershell
git remote -v
```

Expected HTTP pattern:

```text
http://localhost:3000/engineering/<repo-name>.git
```

Check that the repo exists in Forgejo or Gitea and that the user has write access.

## CI Fails Locally

Run the scripts directly to isolate the failing gate:

```powershell
./scripts/restore.ps1
./scripts/lint.ps1
./scripts/build.ps1
./scripts/test.ps1
./scripts/security-scan.ps1
./scripts/package.ps1
```

Then run the workflow:

```powershell
act pull_request --container-architecture linux/amd64
```

## Registry Push Fails

Check the registry:

```powershell
docker compose ps registry
docker pull localhost:5000/<image>:local
docker push localhost:5000/<image>:local
```

Use image names like:

```text
localhost:5000/orders-api:local
```

## Cloud Emulator Calls Fail

Check endpoints:

```text
LocalStack:      http://localhost:4566
Azurite Blob:    http://localhost:10000
Azurite Queue:   http://localhost:10001
Azurite Table:   http://localhost:10002
fake-gcs-server: http://localhost:4443
```

Verify the app is using local endpoints and local credentials in local mode.

## Security Scan Fails

Read the gate name first:

```text
Gitleaks: secret detection
Trivy or Grype: dependency or image vulnerability
Syft: SBOM generation
Checkov: IaC security
Conftest: policy
```

Fix the finding, suppress only with a documented reason, then rerun:

```powershell
./scripts/security-scan.ps1
```

## OpenTofu Fails

Run commands in order:

```powershell
tofu fmt -check
tofu init
tofu validate
tofu plan
```

If policy checks fail:

```powershell
conftest test opentofu/
```

Fix formatting and validation errors before changing policy.
