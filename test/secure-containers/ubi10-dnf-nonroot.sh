#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "test runs as the remote user" sh -c '[ "$(id -u)" -ne 0 ]'
check "rootless daemon is reachable by the remote user" sh -c 'docker info || { echo "--- rootless daemon log ---" >&2; tail -n 200 /tmp/secure-containers-dockerd.log >&2 || true; exit 1; }'
check "daemon reports rootless security mode" sh -c "docker info --format '{{json .SecurityOptions}}' | grep -q rootless"
check "runtime directory follows the current remote-user UID" sh -c 'test "$(readlink /run/secure-containers/docker.sock)" = "/run/user/$(id -u)/docker.sock"'

reportResults
