#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

# Exercises the agentVersion branch: a supplied version skips npm resolution
# and must survive normalize_npm_version unchanged.
check "opencode CLI is installed" sh -c "command -v opencode"
check "opencode CLI is pinned to the requested version" sh -c "opencode --version | grep -qx '1\.18\.0'"

reportResults
