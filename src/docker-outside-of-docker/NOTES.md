## Recommendation

**Do not use this Feature unless direct control of an existing host Docker daemon is an explicit requirement.** For normal image builds and child-container workflows, use [`secure-containers`](../secure-containers) instead. It provides a dedicated rootless Docker daemon without exposing the host engine socket.

## UBI/RHEL support

This Feature is derived from `ghcr.io/devcontainers/features/docker-outside-of-docker` but installs the Docker CLI from Docker's official static Linux archive. It supports both the `dnf` package manager in `registry.access.redhat.com/ubi10/ubi` and `microdnf` in `registry.access.redhat.com/ubi10/ubi-minimal`.

The static archive avoids Docker CE's RPM dependency on `iptables-nft` or `iptables`, neither of which is available from an unregistered UBI 10 image.

Buildx and Compose downloads are verified against the SHA-256 files published with their GitHub releases. Docker does not publish an adjacent checksum file for its static Linux archive, so the Docker CLI archive itself is obtained directly from `download.docker.com` over HTTPS without an independent checksum.

The host socket is mounted at `/var/run/docker-host.sock`. At container startup the Feature maps its group into the container, or uses a `socat` proxy when the socket is owned by group 0, and exposes it at `/var/run/docker.sock`.

When setting `socketPath` to a different path, also override the Feature's socket mount in `devcontainer.json` so its target is the same path. Feature option values cannot dynamically rewrite a declared mount target.

## Security Posture

The default configuration has **effectively administrative access to the host Docker daemon**. The host socket is mounted read-write, and the Feature deliberately makes it accessible to the configured remote user through group mapping or a `socat` proxy. Any process running as that user can create privileged containers, mount host paths, inspect or alter other containers, and delete host images, networks, or volumes. On a native Linux Docker host, this capability is generally equivalent to root access to the host. With Docker Desktop, it grants control over the Docker Desktop VM, all workloads managed by that daemon, and host files made available to Docker Desktop.

This Feature does not set `"privileged": true`, but socket access should not be treated as meaningfully lower privilege: the daemon can be instructed to perform privileged operations on the caller's behalf. The default `"securityOpt": ["label=disable"]` also disables SELinux labeling for the dev container so the forwarded socket can be used on SELinux hosts.

Use this Feature only with trusted source code, dependencies, editor extensions, and build steps, and only when `secure-containers` cannot satisfy the workload. It is not suitable for untrusted repositories or multi-tenant environments. A rootless host Docker socket can reduce the daemon's host authority, but users of that socket still have full control over the rootless daemon and every resource or file it can access.

Moby packages are not available for UBI 10, so the upstream `moby` option is retained for configuration compatibility but must remain `false`.

Docker Compose v1 is end-of-life and is not provided. `dockerDashComposeVersion` accepts `latest`, `v2`, or `none`.

Docker bind-mount source paths are evaluated by the host daemon. A path that exists only inside the dev container cannot be used as a source; use the corresponding host workspace path instead.
