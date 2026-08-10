#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "kubectl major.minor resolves to a patch release" sh -c "kubectl version --client -o json | grep -Eq '\"gitVersion\": \"v1\\.35\\.[0-9]+'"
check "Helm can be omitted" sh -c "! command -v helm"
check "Minikube can be omitted" sh -c "! command -v minikube"

reportResults
