#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "dnf base image is in use" dnf --version
check "postCreate script is persisted and executable" test -x /usr/local/lib/dnf-features/gemini/postcreate.sh
check "workspace _agent is a mounted volume" sh -c "awk '\$2 ~ /\\/_agent\$/ {found=1} END {exit !found}' /proc/mounts"
check "Antigravity CLI is installed" sh -c "command -v agy"
check "Antigravity CLI runs" agy --version

reportResults
