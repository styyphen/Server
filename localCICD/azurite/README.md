# Azurite Starter

Azurite emulates Azure Blob, Queue, and Table Storage locally.

Default endpoints:

```text
Blob:  http://localhost:10000
Queue: http://localhost:10001
Table: http://localhost:10002
```

Development storage connection string:

```text
UseDevelopmentStorage=true
```

Standalone start:

```powershell
docker compose -f azurite/docker-compose.azurite.yml up -d
```
