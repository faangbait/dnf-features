#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

build_and_run_image() {
    local tag="dnf-features-dood-smoke-$$"
    local result=0
    printf 'FROM registry.access.redhat.com/ubi10/ubi-minimal:latest\n' | docker build --tag "${tag}" - \
        && docker run --rm "${tag}" /bin/true \
        || result=$?
    docker image rm --force "${tag}" >/dev/null 2>&1 || true
    return "${result}"
}

check "dnf base image is in use" dnf --version
check "docker CLI is installed" docker --version
check "host docker daemon is reachable" docker info
check "image can be built and run" build_and_run_image
check "buildx is installed" docker buildx version
check "compose v2 is installed" docker compose version

reportResults
