#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "microdnf base image is in use" sh -c "command -v microdnf"
check "docker CLI is installed" docker --version
check "buildx is installed" docker buildx version
check "compose plugin is installed" docker compose version
check "rootless daemon is reachable" docker info
check "daemon reports rootless security mode" sh -c "docker info --format '{{json .SecurityOptions}}' | grep -q rootless"
check "Docker endpoint is internal" sh -c 'test "${DOCKER_HOST}" = unix:///run/secure-containers/docker.sock'
check "child container can run with networking" docker run --rm registry.access.redhat.com/ubi10/ubi-minimal:latest sh -c "curl -fsSL https://example.com >/dev/null"

reportResults
