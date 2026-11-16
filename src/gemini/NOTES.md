## Workspace `_agent` volume

The feature mounts a per-container volume (`gemini-workspace-${devcontainerId}`)
at `${containerWorkspaceFolder}/_agent`. It survives rebuilds of the same
dev container and is not shared with any other, so project-level agy state is
kept out of the host project and out of any config volume shared between
containers.
