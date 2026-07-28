# OpenTofu Examples

This folder contains lightweight OpenTofu examples for validating infrastructure structure locally before connecting real cloud providers.

The local environment uses only modules, variables, locals, and outputs so `tofu init`, `tofu validate`, and `tofu plan` can run without downloading AWS, Azure, or GCP providers.

```powershell
cd opentofu/environments/local
tofu fmt -recursive ../..
tofu init
tofu validate
tofu plan
```

Cloud folders are intentionally provider-free scaffolds. Add provider blocks and real resources when a repository is ready to target an actual cloud account.
