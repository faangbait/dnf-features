#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "dnf base image is in use" dnf --version
check "docker CLI is installed" docker --version
check "host docker daemon is reachable" docker info
check "buildx is installed" docker buildx version
check "compose v2 is installed" docker compose version

reportResults
