#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check_kubeconfig_sync() {
    local test_dir source_dir target_dir
    test_dir="$(mktemp -d)"
    source_dir="${test_dir}/source"
    target_dir="${test_dir}/target"
    trap 'rm -rf "${test_dir}"' RETURN

    mkdir -p "${source_dir}/cache"
    printf '%s\n' 'host-config' > "${source_dir}/config"
    printf '%s\n' 'cached-data' > "${source_dir}/cache/discovery"

    KUBECONFIG_SOURCE_DIR="${source_dir}" KUBECONFIG_TARGET_DIR="${target_dir}" \
        /usr/local/share/sync-local-kubeconfig.sh

    [ "$(cat "${target_dir}/config")" = "host-config" ]
    [ "$(cat "${target_dir}/cache/discovery")" = "cached-data" ]
    [ "$(stat -c '%a' "${target_dir}")" = "700" ]
    [ "$(stat -c '%a' "${target_dir}/config")" = "600" ]
}

check_kubeconfig_not_overwritten() {
    local test_dir source_dir target_dir
    test_dir="$(mktemp -d)"
    source_dir="${test_dir}/source"
    target_dir="${test_dir}/target"
    trap 'rm -rf "${test_dir}"' RETURN

    mkdir -p "${source_dir}" "${target_dir}"
    printf '%s\n' 'host-config' > "${source_dir}/config"
    printf '%s\n' 'container-config' > "${target_dir}/config"

    KUBECONFIG_SOURCE_DIR="${source_dir}" KUBECONFIG_TARGET_DIR="${target_dir}" \
        /usr/local/share/sync-local-kubeconfig.sh

    [ "$(cat "${target_dir}/config")" = "container-config" ]
}

check_missing_kubeconfig_is_optional() {
    local test_dir
    test_dir="$(mktemp -d)"
    trap 'rm -rf "${test_dir}"' RETURN

    KUBECONFIG_SOURCE_DIR="${test_dir}/missing" KUBECONFIG_TARGET_DIR="${test_dir}/target" \
        /usr/local/share/sync-local-kubeconfig.sh

    [ ! -e "${test_dir}/target/config" ]
}

check "kubectl major.minor resolves to a patch release" sh -c "kubectl version --client -o json | grep -Eq '\"gitVersion\": \"v1\\.35\\.[0-9]+'"
check "Helm can be omitted" sh -c "! command -v helm"
check "Minikube can be omitted" sh -c "! command -v minikube"
check "kubeconfig sync helper is installed" test -x /usr/local/share/sync-local-kubeconfig.sh
check "staged kubeconfig is copied with private permissions" check_kubeconfig_sync
check "existing container kubeconfig is not overwritten" check_kubeconfig_not_overwritten
check "missing staged kubeconfig is ignored" check_missing_kubeconfig_is_optional

reportResults
