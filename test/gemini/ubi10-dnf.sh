#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "dnf base image is in use" dnf --version
check "Antigravity CLI is installed" sh -c "command -v agy"
check "Antigravity CLI runs" agy --version

reportResults
