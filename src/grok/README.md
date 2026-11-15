
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
| pluginMarketplaces | Space-separated list of Grok plugin marketplaces (owner/repo, git URL) to add on container creation, e.g. 'anthropics/claude-plugins-official'. Setting this or plugins also installs git. Best-effort: a marketplace that cannot be added is logged and skipped rather than failing container creation. Leave empty to add none. | string |  |
| plugins | Space-separated list of Grok plugins to install and trust on container creation, as plugin@marketplace, e.g. 'chrome-devtools-mcp@claude-plugins-official'. Each marketplace referenced here must also appear in pluginMarketplaces. Best-effort: a plugin that cannot be installed is logged and skipped rather than failing container creation. Leave empty to install none. | string |  |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/faangbait/dnf-features/blob/main/src/grok/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
