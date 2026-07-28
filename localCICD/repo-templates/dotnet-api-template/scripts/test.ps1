$ErrorActionPreference = "Stop"
dotnet test --configuration Release --no-build --collect:"XPlat Code Coverage"
