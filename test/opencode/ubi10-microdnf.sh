#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "microdnf base image is in use" sh -c "command -v microdnf"
check "opencode CLI is installed" sh -c "command -v opencode"
check "opencode CLI runs" opencode --version
check "npm build prefix was discarded" sh -c "! test -e /usr/local/lib/node_modules/opencode-ai"

reportResults
