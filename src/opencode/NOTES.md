## Workspace `.opencode` volume

The feature mounts a per-container volume (`opencode-workspace-${devcontainerId}`)
at `${containerWorkspaceFolder}/.opencode`. It survives rebuilds of the same
dev container and is not shared with any other, so project-level opencode state is
kept out of the host project and out of any config volume shared between
containers.
