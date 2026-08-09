# Terraform Tooling (RHEL) (terraform)

Installs Terraform, TFLint, and the Terraform MCP Server from their official release archives.

## Example Usage

```json
"features": {
    "ghcr.io/faangbait/dnf-features/terraform:1": {
        "terraform": "1.15.8",
        "tflint": "0.64.0",
        "mcpServer": "1.1.0"
    }
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| terraform | Terraform CLI version to install. | string | 1.15.8 |
| tflint | TFLint version to install. | string | 0.64.0 |
| mcpServer | Terraform MCP Server version to install. | string | 1.1.0 |

## Installation

Terraform and the Terraform MCP Server are downloaded from `releases.hashicorp.com`. TFLint is downloaded from the `terraform-linters/tflint` GitHub releases. The Feature verifies every archive against the SHA-256 checksum published with its release and supports AMD64 and ARM64 UBI/RHEL images using either `dnf` or `microdnf`.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/faangbait/dnf-features/blob/main/src/terraform/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
