
# opencode CLI (RHEL) (opencode)

Installs the opencode CLI from npm.

## Example Usage

```json
"features": {
    "ghcr.io/faangbait/dnf-features/opencode:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| agentVersion | opencode-ai version to install. Leave empty to resolve the newest published npm version at install time and pin that exact version; it does not float on later rebuilds of the same layer. | string | - |
| plugins | Space-separated list of opencode plugins (npm packages, optionally @version) to install on container creation, e.g. 'opencode-gitlab-auth'. Best-effort: a plugin that cannot be installed is logged and skipped rather than failing container creation. Leave empty to install none. | string | - |

## Customizations

### VS Code Extensions

- `ankurmathur.opencode-provider-bridge`

## Workspace `.opencode` volume

The feature mounts a per-container volume (`opencode-workspace-${devcontainerId}`)
at `${containerWorkspaceFolder}/.opencode`. It survives rebuilds of the same
dev container and is not shared with any other, so project-level opencode state is
kept out of the host project and out of any config volume shared between
containers.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/faangbait/dnf-features/blob/main/src/opencode/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
