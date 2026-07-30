
# AWS CLI (RHEL) (aws-cli)

Installs the AWS CLI along with needed dependencies. Best-efforts a dnf install.

## Example Usage

```json
"features": {
    "ghcr.io/faangbait/dnf-features/aws-cli:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Select or enter an AWS CLI version. | string | latest |
| verbose | Suppress verbose output. | boolean | true |

Available versions of the AWS CLI can be found here: https://github.com/aws/aws-cli/blob/v2/CHANGELOG.rst.

## OS Support

- microdnf/dnf/yum package managers, or
- bring your own bash/curl/gpg/unzip


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/faangbait/dnf-features/blob/main/src/aws-cli/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
