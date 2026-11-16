
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
| pluginScope | Claude Code scope to install plugins into. 'local' records enablement in the workspace's .claude/settings.local.json, so containers that share a config volume (e.g. /var/llms) do not inherit each other's plugins. 'user' writes enablement into the shared config directory and crosses over between those containers; 'project' writes to the workspace's .claude/settings.json. Marketplaces are always added at user scope. | string | local |

## Workspace `.claude` volume

The feature mounts a per-container volume (`claude-workspace-${devcontainerId}`)
at `${containerWorkspaceFolder}/.claude`. It survives rebuilds of the same
dev container and is not shared with any other. With the default
`pluginScope` of `local`, plugin enablement is written there rather than into
the host project or into a config volume shared between containers.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/faangbait/dnf-features/blob/main/src/claude/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
