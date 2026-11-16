## Workspace `.claude` volume

The feature mounts a per-container volume (`claude-workspace-${devcontainerId}`)
at `${containerWorkspaceFolder}/.claude`. It survives rebuilds of the same
dev container and is not shared with any other. With the default
`pluginScope` of `local`, plugin enablement is written there rather than into
the host project or into a config volume shared between containers.
