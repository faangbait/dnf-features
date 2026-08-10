## Minikube runtime

This Feature installs the Minikube client, but it does not install or configure a Minikube driver. Add a container-engine Feature when you intend to start a cluster. The `secure-containers` Feature in this collection is the recommended Docker option.

## Ingress and port forwarding

Kubernetes commonly binds services to the node interface rather than localhost. Use the Minikube node IP when the client supports forwarding `<ip>:<port>`, or use `kubectl port-forward` to expose a service on localhost.

## OS support

This RHEL edition supports RHEL-compatible images with `dnf` or `microdnf`. `bash` is required to execute the installer.
