
# Antigravity CLI (RHEL) (gemini)

Installs Google's Antigravity CLI (agy), verified against its release checksum.

## Example Usage

```json
"features": {
    "ghcr.io/faangbait/dnf-features/gemini:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| agentVersion | Antigravity CLI build to install. Leave empty to install the newest release; the build log names it as <version>-<build> (e.g. 1.5.9-4515810895593472), and setting that value pins that exact build. A bare version (e.g. 1.5.9) is only accepted while it is still the newest release. agy updates itself in the background whenever its install directory is writable by the user. | string | - |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/faangbait/dnf-features/blob/main/src/gemini/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
