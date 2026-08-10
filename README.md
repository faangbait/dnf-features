# Dev Container Features: RHEL/UBI Edition

Dev Container Features derived from [`devcontainers/features`](https://github.com/devcontainers/features), adapted for Red Hat UBI 10 images.

Every Feature in this collection must support both:

- `registry.access.redhat.com/ubi10/ubi`, using `dnf`
- `registry.access.redhat.com/ubi10/ubi-minimal`, using `microdnf`

## Docker features

**Use `secure-containers` by default.** It supports Docker image builds and child containers through a dedicated rootless daemon without exposing a host container-engine socket or making the dev container privileged. The other Docker Features are retained for compatibility with workloads that explicitly require their less secure privilege models.

### Docker-in-Docker

Runs a dedicated Docker daemon inside the dev container. It follows the upstream Feature's privileged-container, entrypoint, and persistent-volume model.

> Not recommended for general use. This Feature makes the entire dev container privileged and can expose the physical host to root-level compromise. Prefer [`secure-containers`](#secure-containers).

```jsonc
{
    "image": "registry.access.redhat.com/ubi10/ubi-minimal:latest",
    "features": {
        "ghcr.io/faangbait/dnf-features/docker-in-docker:1": {}
    }
}
```

UBI 10 does not provide the `iptables` command required by Docker CE's RHEL RPM, so this Feature installs Docker 29 or newer from Docker's official static Linux archive and starts the daemon with its nftables firewall backend.

### Docker-outside-of-Docker

Installs the Docker client and forwards the host's Docker socket into the dev container. It follows the upstream Feature's socket mount, entrypoint, non-root access, and legacy ID patterns.

> Not recommended for general use. Access to a rootful host Docker socket is normally equivalent to root access on that host. Prefer [`secure-containers`](#secure-containers).

```jsonc
{
    "image": "registry.access.redhat.com/ubi10/ubi-minimal:latest",
    "features": {
        "ghcr.io/faangbait/dnf-features/docker-outside-of-docker:1": {}
    }
}
```

The Docker CLI is extracted from Docker's official static Linux archive. Buildx and Compose are installed as Docker CLI plugins from their official GitHub releases.

### Secure Containers

**Recommended.** Runs a dedicated rootless Docker daemon as a non-root user inside the dev container. It mounts no host Docker socket, enables no privileged mode or additional capabilities, and passes through no host devices.

```jsonc
{
    "image": "registry.access.redhat.com/ubi10/ubi-minimal:latest",
    "features": {
        "ghcr.io/faangbait/dnf-features/secure-containers:1": {}
    }
}
```

By default, `docker info`, Buildx, Compose, image builds, and child containers use the internal rootless daemon. RootlessKit and `slirp4netns` provide userspace networking. The Feature relaxes the outer container's seccomp and protected-system-path policies so nested user namespaces can function; see the Feature's `NOTES.md` for the security tradeoff.

The daemon follows Dev Container UID remapping at startup, so a non-root `remoteUser` can access the socket after its UID is adjusted to match the host. UBI base images do not provide systemd user-session cgroup delegation, so child-container resource limits must not be treated as a security boundary.

The Docker and Buildx `version` options accept pins for reproducible builds. Their default `latest` values, and the Compose default, resolve from upstream at image-build time and can change without a release of this Feature collection.

## Terraform tooling

Installs Terraform 1.15.8, TFLint 0.64.0, and Terraform MCP Server 1.1.0 by default. Override them with the `terraform`, `tflint`, and `mcpServer` Feature options.

```jsonc
{
    "image": "registry.access.redhat.com/ubi10/ubi-minimal:latest",
    "features": {
        "ghcr.io/faangbait/dnf-features/terraform:1": {
            "terraform": "1.15.8",
            "tflint": "0.64.0",
            "mcpServer": "1.1.0"
        }
    }
}
```

Terraform and Terraform MCP Server are installed from HashiCorp's release service, and TFLint is installed from its official GitHub releases. Release archives are verified with their published SHA-256 checksums.

## Kubernetes tooling

Installs kubectl, Helm, and optionally Minikube from their official release artifacts. All three version options accept `latest` or `none`; kubectl also accepts a `major.minor` release line and resolves its latest patch.

```jsonc
{
    "image": "registry.access.redhat.com/ubi10/ubi-minimal:latest",
    "features": {
        "ghcr.io/faangbait/dnf-features/kubectl-helm-minikube:1": {}
    }
}
```

The Feature installs the Minikube client but not a runtime driver. Pair it with a container-engine Feature, such as `secure-containers`, before starting a Minikube cluster.

To initialize a new container with the host's kubeconfig, add a read-only staging mount. The Feature copies it once into the remote user's home directory and will not overwrite a container kubeconfig that already exists:

```jsonc
"mounts": [
    "source=${localEnv:HOME}${localEnv:USERPROFILE}/.kube,target=/usr/local/share/kube-localhost,type=bind,readonly"
]
```

## Releases

After the `CI - Test Features` workflow succeeds on `main`, the release workflow compares each Feature's package files with its current `feature_<id>_<version>` tag. Changed Features receive an automatic patch-version bump, the bump is committed to `main`, and the collection is published. Changes to generated Feature `README.md` files alone do not cause a release.

To make an intentional minor or major release, update `version` in the Feature's `devcontainer-feature.json` as part of the pull request. Because that version does not have a release tag yet, the workflow preserves it instead of applying a patch bump. The release workflow can also be rerun manually if a publish attempt fails.

## Local tests

Run all Docker scenarios:

```bash
devcontainer features test --project-folder . \
    --features docker-in-docker docker-outside-of-docker kubectl-helm-minikube secure-containers terraform \
    --skip-autogenerated
```

Run one package-manager scenario:

```bash
devcontainer features test --project-folder . \
    --features docker-in-docker \
    --filter ubi10-microdnf \
    --skip-autogenerated
```

The outside-of-Docker tests require a working host Docker socket. The Docker-in-Docker tests require the host runtime to allow privileged containers. Secure Containers requires the host kernel to enable unprivileged user namespaces and an AppArmor policy that permits RootlessKit mount propagation. Its end-to-end scenarios are intentionally excluded from GitHub-hosted runners rather than disabling AppArmor to make CI pass; hosted CI still installs and verifies its binaries on both UBI variants without starting the daemon.
