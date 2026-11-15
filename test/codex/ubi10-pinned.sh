#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

# Exercises the agentVersion branch: a supplied version skips npm resolution
# and must survive normalize_npm_version unchanged.
check "Codex CLI is installed" sh -c "command -v codex"
check "Codex CLI is pinned to the requested version" sh -c "codex --version | grep -q '0\.165\.0'"

reportResults
