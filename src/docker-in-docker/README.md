
# Docker (Docker-in-Docker, RHEL) (docker-in-docker)

Creates child containers using a dedicated Docker daemon inside the dev container. Installs Docker from the official static Linux binaries.

## Example Usage

```json
"features": {
    "ghcr.io/faangbait/dnf-features/docker-in-docker:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Select a Docker CE Engine and CLI version, or use latest. | string | latest |
| moby | Install Moby instead of Docker CE. Moby RPMs are not available for UBI 10, so true is unsupported. | boolean | false |
| mobyBuildxVersion | Install a specific Docker Buildx version, or use latest. | string | latest |
| dockerDashComposeVersion | Install the Docker Compose v2 CLI plugin, or disable it with none. | string | latest |
| installDockerBuildx | Install the Docker Buildx CLI plugin. | boolean | true |
| installDockerComposeSwitch | Install a docker-compose compatibility wrapper that invokes Docker Compose v2. | boolean | false |
| azureDnsAutoDetection | Automatically configure the Docker daemon DNS server when Azure DNS is detected. | boolean | true |
| dockerDefaultAddressPool | Set Docker's default address pool, for example base=192.168.0.0/16,size=24. | string | - |
| disableIp6tables | Start dockerd with ip6tables disabled. | boolean | false |

## Customizations

### VS Code Extensions

- `ms-azuretools.vscode-containers`

## Recommendation

**Do not use this Feature unless privileged Docker-in-Docker is an explicit requirement.** For normal image builds and child-container workflows, use [`secure-containers`](../secure-containers) instead. It provides a dedicated rootless Docker daemon without granting the dev container host-root-equivalent privilege.

## UBI/RHEL support

This Feature is derived from `ghcr.io/devcontainers/features/docker-in-docker` but installs Docker from Docker's official static Linux archive. It supports both the `dnf` package manager in `registry.access.redhat.com/ubi10/ubi` and `microdnf` in `registry.access.redhat.com/ubi10/ubi-minimal`.

The static archive avoids Docker CE's RPM dependency on `iptables-nft` or `iptables`, neither of which is available from an unregistered UBI 10 image. Docker 29 or newer is required, and the daemon uses Docker's nftables firewall backend with the UBI-provided `nftables` package.

The Feature starts its own Docker daemon and therefore requires a privileged dev container. Its Docker and containerd state is stored in named volumes scoped to `${devcontainerId}` and survives a rebuild. Removing the dev container does not automatically remove those volumes.

## Security Posture

The default configuration has **very high host privilege**. The Feature declares `"privileged": true`, which gives the dev container all Linux capabilities, access to host devices, and substantially disables the container runtime's normal seccomp, AppArmor, and SELinux confinement. The configured remote user is also added to the `docker` group, so that user and any process running as it can control the inner daemon with effectively root-level authority inside the already-privileged dev container.

The dedicated daemon isolates Docker objects: its containers, images, networks, and volumes are separate from the host Docker daemon, and the host Docker socket is not mounted. This reduces accidental interference with host Docker workloads, but it is **logical isolation, not a security boundary**. A privileged dev container can potentially escape its container boundary or modify the host, and workloads launched through its daemon inherit that risk.

Use this Feature only with trusted source code, dependencies, editor extensions, and build steps, and only when `secure-containers` cannot satisfy the workload. It is not suitable for untrusted repositories, multi-tenant environments, or situations where the dev container must be securely isolated from its host. Environments that cannot accept host-level privilege should use `secure-containers` instead.

Moby packages are not available for UBI 10, so the upstream `moby` option is retained for configuration compatibility but must remain `false`.

Docker Compose v1 is end-of-life and is not provided. `dockerDashComposeVersion` accepts `latest`, `v2`, or `none`.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/faangbait/dnf-features/blob/main/src/docker-in-docker/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
