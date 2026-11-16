## Workspace `.grok` volume

The feature mounts a per-container volume (`grok-workspace-${devcontainerId}`)
at `${containerWorkspaceFolder}/.grok`. It survives rebuilds of the same
dev container and is not shared with any other, so project-level grok state is
kept out of the host project and out of any config volume shared between
containers.
