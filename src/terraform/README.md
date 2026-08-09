
# Terraform Tooling (RHEL) (terraform)

Installs Terraform, TFLint, and the Terraform MCP Server from their official release archives.

## Example Usage

```json
"features": {
    "ghcr.io/faangbait/dnf-features/terraform:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| terraform | Terraform CLI version to install. | string | 1.15.8 |
| tflint | TFLint version to install. | string | 0.64.0 |
| mcpServer | Terraform MCP Server version to install. | string | 1.1.0 |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/faangbait/dnf-features/blob/main/src/terraform/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
