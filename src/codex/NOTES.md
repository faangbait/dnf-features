## Workspace `.codex` volume

The feature mounts a per-container volume (`codex-workspace-${devcontainerId}`)
at `${containerWorkspaceFolder}/.codex`. It survives rebuilds of the same
dev container and is not shared with any other, so project-level codex state is
kept out of the host project and out of any config volume shared between
containers.
