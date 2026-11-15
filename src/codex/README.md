
# Codex CLI (RHEL) (codex)

Installs the Codex CLI (OpenAI) from npm.

## Example Usage

```json
"features": {
    "ghcr.io/faangbait/dnf-features/codex:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| agentVersion | @openai/codex version to install. Leave empty to resolve the newest published npm version at install time and pin that exact version; it does not float on later rebuilds of the same layer. | string |  |
| pluginMarketplaces | Space-separated list of Codex plugin marketplaces (owner/repo, git URL, or local path) to add on container creation, e.g. 'anthropics/claude-plugins-official'. Setting this or plugins also installs git. Best-effort: a marketplace that cannot be added is logged and skipped rather than failing container creation. Leave empty to add none. | string |  |
| plugins | Space-separated list of Codex plugins to install on container creation, as plugin@marketplace, e.g. 'frontend-design@claude-plugins-official'. Each marketplace referenced here must also appear in pluginMarketplaces. Best-effort: a plugin that cannot be installed is logged and skipped rather than failing container creation. Leave empty to install none. | string |  |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/faangbait/dnf-features/blob/main/src/codex/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
