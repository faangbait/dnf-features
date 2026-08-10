#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "latest kubectl is installed" sh -c "kubectl version --client -o json | grep -Eq '\"gitVersion\": \"v[0-9]+\\.[0-9]+\\.[0-9]+'"
check "latest Helm is installed" sh -c "helm version --short | grep -Eq '^v[0-9]+\\.[0-9]+\\.[0-9]+'"
check "latest Minikube is installed" sh -c "minikube version --short | grep -Eq '^v[0-9]+\\.[0-9]+\\.[0-9]+'"
check "latest Calicoctl is installed" sh -c "calicoctl version --client | grep -Eq 'Client Version: *v[0-9]+\\.[0-9]+\\.[0-9]+'"

reportResults
