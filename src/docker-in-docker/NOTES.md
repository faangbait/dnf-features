## Recommendation

**Do not use this Feature unless privileged Docker-in-Docker is an explicit requirement.** For normal image builds and child-container workflows, use [`secure-containers`](../secure-containers) instead. It provides a dedicated rootless Docker daemon without granting the dev container host-root-equivalent privilege.

## UBI/RHEL support

This Feature is derived from `ghcr.io/devcontainers/features/docker-in-docker` but installs Docker from Docker's official static Linux archive. It supports both the `dnf` package manager in `registry.access.redhat.com/ubi10/ubi` and `microdnf` in `registry.access.redhat.com/ubi10/ubi-minimal`.

The static archive avoids Docker CE's RPM dependency on `iptables-nft` or `iptables`, neither of which is available from an unregistered UBI 10 image. Docker 29 or newer is required, and the daemon uses Docker's nftables firewall backend with the UBI-provided `nftables` package.

Buildx and Compose downloads are verified against the SHA-256 files published with their GitHub releases. Docker does not publish adjacent checksum files for its static Linux archives, so the Docker archive itself is obtained directly from `download.docker.com` over HTTPS without an independent checksum.

The Feature starts its own Docker daemon and therefore requires a privileged dev container. Its Docker and containerd state is stored in named volumes scoped to `${devcontainerId}` and survives a rebuild. Removing the dev container does not automatically remove those volumes.

## Security Posture

The default configuration has **very high host privilege**. The Feature declares `"privileged": true`, which gives the dev container all Linux capabilities, access to host devices, and substantially disables the container runtime's normal seccomp, AppArmor, and SELinux confinement. The configured remote user is also added to the `docker` group, so that user and any process running as it can control the inner daemon with effectively root-level authority inside the already-privileged dev container.

The dedicated daemon isolates Docker objects: its containers, images, networks, and volumes are separate from the host Docker daemon, and the host Docker socket is not mounted. This reduces accidental interference with host Docker workloads, but it is **logical isolation, not a security boundary**. A privileged dev container can potentially escape its container boundary or modify the host, and workloads launched through its daemon inherit that risk.

Use this Feature only with trusted source code, dependencies, editor extensions, and build steps, and only when `secure-containers` cannot satisfy the workload. It is not suitable for untrusted repositories, multi-tenant environments, or situations where the dev container must be securely isolated from its host. Environments that cannot accept host-level privilege should use `secure-containers` instead.

Moby packages are not available for UBI 10, so the upstream `moby` option is retained for configuration compatibility but must remain `false`.

Docker Compose v1 is end-of-life and is not provided. `dockerDashComposeVersion` accepts `latest`, `v2`, or `none`.
