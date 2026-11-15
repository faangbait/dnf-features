
# Grok CLI (RHEL) (grok)

Installs the Grok CLI (xAI) with the vendor installer, as grok and agent.

## Example Usage

```json
"features": {
    "ghcr.io/faangbait/dnf-features/grok:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| agentVersion | Grok CLI version to install, e.g. 1.0.77. Leave empty to install the newest stable release at install time; that exact version is pinned and does not float on later rebuilds of the same layer. | string |  |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/faangbait/dnf-features/blob/main/src/grok/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
