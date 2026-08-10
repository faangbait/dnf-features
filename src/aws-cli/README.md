
# AWS CLI (RHEL) (aws-cli)

Installs AWS CLI v2 and shell completion with dnf, microdnf, yum, apt, or apk support.

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
| verbose | Show verbose archive extraction output. | boolean | true |
| sessionman | Install the AWS Session Manager plugin. | boolean | true |

Available versions of the AWS CLI can be found here: https://github.com/aws/aws-cli/blob/v2/CHANGELOG.rst.

## OS Support

- microdnf/dnf/yum package managers, or
- bring your own bash/curl/gpg/unzip


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/faangbait/dnf-features/blob/main/src/aws-cli/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
