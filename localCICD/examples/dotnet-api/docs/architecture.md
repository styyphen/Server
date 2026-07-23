# Architecture

`dotnet-api` is an ASP.NET Core API. Cloud integrations should be isolated behind ports and adapters so tests can target LocalStack, Azurite, and fake-gcs-server.

