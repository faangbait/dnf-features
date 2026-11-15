#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "microdnf base image is in use" sh -c "command -v microdnf"
check "Antigravity CLI is installed" sh -c "command -v agy"
check "Antigravity CLI runs" agy --version

reportResults
