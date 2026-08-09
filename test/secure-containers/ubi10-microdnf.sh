#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

build_and_run_image() {
    local tag="dnf-features-rootless-smoke-$$"
    local result=0
    printf 'FROM registry.access.redhat.com/ubi10/ubi-minimal:latest\n' | docker build --tag "${tag}" - \
        && docker run --rm "${tag}" /bin/true \
        || result=$?
    docker image rm --force "${tag}" >/dev/null 2>&1 || true
    return "${result}"
}

check "microdnf base image is in use" sh -c "command -v microdnf"
check "docker CLI is installed" docker --version
check "buildx is installed" docker buildx version
check "compose plugin is installed" docker compose version
check "rootless daemon is reachable" sh -c 'docker info || { echo "--- rootless daemon log ---" >&2; tail -n 200 /tmp/secure-containers-dockerd.log >&2 || true; exit 1; }'
check "daemon reports rootless security mode" sh -c "docker info --format '{{json .SecurityOptions}}' | grep -q rootless"
check "nftables firewall backend is active" sh -c "docker info --format '{{.FirewallBackend}}' | grep -q nftables"
check "Docker endpoint is internal" sh -c 'test "${DOCKER_HOST}" = unix:///run/secure-containers/docker.sock'
check "image can be built and run" build_and_run_image
check "child container can run with networking" docker run --rm registry.access.redhat.com/ubi10/ubi-minimal:latest sh -c "curl -fsSL https://example.com >/dev/null"

reportResults
