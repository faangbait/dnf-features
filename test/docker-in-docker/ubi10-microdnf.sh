#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "microdnf base image is in use" sh -c "command -v microdnf"
check "docker CLI is installed" docker --version
check "docker daemon is running" docker info
check "nftables firewall backend is active" sh -c "docker info --format '{{.FirewallBackend}}' | grep -q nftables"
check "child container can run" docker run --rm registry.access.redhat.com/ubi10/ubi-minimal:latest /bin/true
check "buildx is installed" docker buildx version
check "compose v2 is installed" docker compose version

reportResults
