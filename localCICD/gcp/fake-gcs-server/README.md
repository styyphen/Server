# fake-gcs-server Starter

`fake-gcs-server` provides a local Google Cloud Storage compatible API for development and integration tests.

Default endpoint:

```text
http://localhost:4443
```

Standalone start:

```powershell
docker compose -f gcp/fake-gcs-server/docker-compose.fake-gcs.yml up -d
```

Applications should configure their storage client to use the emulator endpoint and avoid real GCP credentials in local development.
