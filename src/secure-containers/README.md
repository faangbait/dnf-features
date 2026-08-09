
# Secure Containers (Rootless Docker, RHEL) (secure-containers)

Runs a dedicated rootless Docker daemon inside the dev container without mounting a host engine socket or enabling privileged mode.

## Example Usage

```json
"features": {
    "ghcr.io/faangbait/dnf-features/secure-containers:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Select a Docker Engine and CLI version, or use latest. Docker 29 or newer is required. | string | latest |
| moby | Install Moby instead of Docker. Moby RPMs are not available for UBI 10, so true is unsupported. | boolean | false |
| mobyBuildxVersion | Install a specific Docker Buildx version, or use latest. | string | latest |
| dockerDashComposeVersion | Install the Docker Compose CLI plugin, or disable it with none. | string | latest |
| installDockerBuildx | Install the Docker Buildx CLI plugin. | boolean | true |
| installDockerComposeSwitch | Install a docker-compose compatibility wrapper that invokes the Docker Compose plugin. | boolean | false |
| username | Non-root user that owns the rootless daemon. A dedicated securecontainers user is created when the remote user is root. | string | automatic |

## Customizations

### VS Code Extensions

- `ms-azuretools.vscode-containers`

## Rootless Docker behavior

This Feature starts a dedicated Docker daemon as the selected non-root user inside the dev container. The Docker CLI connects to its internal Unix socket at `/run/secure-containers/docker.sock`. It does not connect to a daemon on the physical host, mount `/var/run/docker.sock` from outside the dev container, or use SSH.

The daemon uses RootlessKit and `slirp4netns`. Its child containers run in subordinate user and group ID ranges assigned to the daemon user. When the configured dev-container user is root, the Feature creates a dedicated `securecontainers` user for the daemon. Docker data is retained in a named volume mounted at `/var/lib/secure-containers`.

The daemon user's UID, GID, and home directory are resolved at container startup rather than image build time. This is required because Dev Container tooling can remap the remote user's UID to match the host. For non-root container users, the Feature installs a narrowly scoped `sudoers` rule that permits only the fixed runtime-preparation operation: creating the private TUN node and setting ownership on the daemon's runtime and data paths. The normal container command and daemon still run as the selected non-root user.

RootlessKit disables access to the outer container's loopback interface from child containers. UBI base images also do not provide a systemd user session for cgroup delegation, so the rootless daemon runs without cgroup-based resource control. Do not rely on child-container CPU, memory, or process limits as a security boundary in this configuration.

## Security Posture

The default settings do **not** grant host-root-equivalent Docker access. The dev container is not privileged, receives no additional Linux capabilities, mounts no host container-engine socket, and mounts no host device. A local `/dev/net/tun` node is created inside the dev container's private `/dev` at startup for userspace networking; it is not passed through from the physical host.

Rootless does not mean sandboxed or harmless. Anyone who can access the internal Docker socket fully controls this daemon and its child containers. Those processes have the authority of the rootless daemon user and can access files that user can access. Root inside a child container maps into the daemon user's subordinate ID range rather than physical-host root.

Two outer-runtime protections are relaxed so nested user namespaces and child container filesystems work: `seccomp=unconfined` and `systempaths=unconfined`. Removing the default seccomp filter increases the kernel attack surface available to processes in the dev container. Unconfined system paths remove Docker's extra masking/read-only treatment of sensitive virtual-filesystem paths inside the dev container. The processes remain non-root on the physical host, retain the dev container's normal capability boundary, and receive no host namespace or socket, but these settings are a meaningful reduction in defense in depth. Do not use this Feature for hostile multi-tenant workloads, and keep the host kernel and container runtime patched.

This Feature cannot neutralize authority supplied elsewhere. Another Feature, the base image, workspace mounts, `DOCKER_HOST`, or the surrounding `devcontainer.json` can independently expose host files, credentials, capabilities, devices, namespaces, or a container-engine socket. Review the complete resolved dev-container configuration when security boundaries matter.

## UBI/RHEL support

Docker Engine, the CLI, containerd, runc, and RootlessKit are extracted from Docker's official static Linux archives, avoiding Docker CE RPM dependencies unavailable in an unregistered UBI 10 image. UBI 10 supplies `newuidmap`, `newgidmap`, nftables, and the remaining runtime dependencies through its standard repositories. Because UBI 10 does not publish `slirp4netns`, its official static release is installed from the rootless-containers project. Both `dnf` and `microdnf` are supported.

Buildx, Compose, and `slirp4netns` downloads are verified against the SHA-256 files published with their GitHub releases. Docker does not publish adjacent checksum files for its static Linux archives, so the Docker and rootless-extras archives are obtained directly from `download.docker.com` over HTTPS without independent checksums.

The physical host must enable unprivileged user namespaces (`kernel.unprivileged_userns_clone=1`, where that sysctl exists, and a nonzero `user.max_user_namespaces`).

An outer AppArmor profile that denies RootlessKit's mount-propagation operations is not supported. This Feature intentionally does not set `apparmor=unconfined` to work around such a host policy. Use a compatible host or a narrowly scoped host-local AppArmor profile rather than disabling AppArmor for the entire dev container.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/faangbait/dnf-features/blob/main/src/secure-containers/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
