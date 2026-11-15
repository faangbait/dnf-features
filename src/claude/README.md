
# Claude Code CLI (RHEL) (claude)

Installs the Claude Code CLI (Anthropic) from npm.

## Example Usage

```json
"features": {
    "ghcr.io/faangbait/dnf-features/claude:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| agentVersion | @anthropic-ai/claude-code version to install. Leave empty to resolve the newest published npm version at install time and pin that exact version; it does not float on later rebuilds of the same layer. | string | - |
| pluginMarketplaces | Space-separated list of Claude Code plugin marketplaces (owner/repo) to add on container creation, e.g. 'anthropics/claude-plugins-official'. Best-effort: a marketplace that cannot be added is logged and skipped rather than failing container creation. Leave empty to add none. | string | - |
| plugins | Space-separated list of Claude Code plugins to install on container creation, as plugin@marketplace, e.g. 'chrome-devtools-mcp@claude-plugins-official'. Each marketplace referenced here must also appear in pluginMarketplaces. Best-effort: a plugin that cannot be installed is logged and skipped rather than failing container creation. Leave empty to install none. | string | - |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/faangbait/dnf-features/blob/main/src/claude/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
