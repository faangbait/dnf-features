## Minikube runtime

This Feature installs the Minikube client, but it does not install or configure a Minikube driver. Add a container-engine Feature when you intend to start a cluster. The `secure-containers` Feature in this collection is the recommended Docker option.

## Calicoctl version

Calico recommends using a `calicoctl` version that matches the Calico version running in the target cluster. Set the `calicoctl` option to that version, or use `none` when Calicoctl is not needed.

## Use the host kubeconfig

To initialize the container from the host's kubeconfig, stage the host `.kube` directory with a read-only bind mount:

```jsonc
"mounts": [
    "source=${localEnv:HOME}${localEnv:USERPROFILE}/.kube,target=/usr/local/share/kube-localhost,type=bind,readonly"
]
```

When the container is first created, the Feature copies the staged directory to the remote user's `$HOME/.kube` and restricts its permissions. If `$HOME/.kube/config` already exists, it is left unchanged. Rebuilding the container creates a new container and therefore initializes it again; restarting an existing container does not.

The host `.kube` directory must exist before the container is created. This mount is optional because a missing bind-mount source prevents the container from starting. It is not supported by GitHub Codespaces, which ignores host bind mounts other than the Docker socket.

Some local clusters publish a Kubernetes API address such as `localhost` or `127.0.0.1`. From inside a dev container those addresses refer to the dev container itself, so the copied configuration may need a host-reachable API address.

## Ingress and port forwarding

Kubernetes commonly binds services to the node interface rather than localhost. Use the Minikube node IP when the client supports forwarding `<ip>:<port>`, or use `kubectl port-forward` to expose a service on localhost.

## OS support

This RHEL edition supports RHEL-compatible images with `dnf` or `microdnf`. `bash` is required to execute the installer.
