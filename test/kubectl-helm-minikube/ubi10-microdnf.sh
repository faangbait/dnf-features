#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "microdnf base image is in use" sh -c "command -v microdnf"
check "kubectl 1.35.1 is installed" sh -c "kubectl version --client -o json | grep -q '\"gitVersion\": \"v1.35.1\"'"
check "kubectl bash completion is installed" test -s /etc/bash_completion.d/kubectl
check "Helm 3.19.0 is installed" sh -c "helm version --short | grep -q '^v3.19.0'"
check "Helm bash completion is installed" test -s /etc/bash_completion.d/helm
check "Minikube 1.37.0 is installed" sh -c "minikube version --short | grep -q '^v1.37.0'"
check "Minikube config directory exists" test -d /root/.minikube
check "Calicoctl 3.32.1 is installed" sh -c "calicoctl version --client | grep -q 'Client Version: *v3.32.1'"

reportResults
