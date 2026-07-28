# Cloud Emulator Guide

Use cloud emulators for local integration tests and local development. Do not require real cloud accounts for the default developer loop.

## Service Endpoints

| Provider style | Tool | Endpoint |
|---|---|---|
| AWS | LocalStack Community Edition | http://localhost:4566 |
| Azure Storage | Azurite Blob | http://localhost:10000 |
| Azure Storage | Azurite Queue | http://localhost:10001 |
| Azure Storage | Azurite Table | http://localhost:10002 |
| GCP Storage | fake-gcs-server | http://localhost:4443 |

## Start and Check

```powershell
./scripts/start.ps1
./scripts/health-check.ps1
```

## AWS-Style Services

Use LocalStack for:

```text
S3-style object storage
SQS-style queues
SNS-style messaging
DynamoDB-style persistence
Lambda-style execution where supported
```

Provision local resources with scripts such as:

```text
localstack/init/create-s3.sh
localstack/init/create-sqs.sh
localstack/init/create-dynamodb.sh
```

## Azure-Style Services

Use Azurite for:

```text
Blob Storage
Queue Storage
Table Storage
```

Configure apps with local endpoints instead of real Azure endpoints during local runs.

## GCP-Style Services

Use fake-gcs-server for Google Cloud Storage style object storage.

Configure apps with the local fake-gcs-server endpoint during local runs.

## Application Design Rule

Hide provider details behind ports or interfaces:

```text
Application Service
  -> Storage Port
    -> AWS S3 Adapter
    -> Azure Blob Adapter
    -> GCP Storage Adapter
    -> Local File Adapter
```

Tests should target the port contract. Adapter tests should target the emulator.

## Minimum Emulator Test

Each onboarded app should prove:

```text
Write object.
Read object.
Delete object.
Send queue message where supported.
Receive queue message where supported.
Run without real cloud credentials.
```
