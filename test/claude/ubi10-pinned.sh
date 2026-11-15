#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

# Exercises the agentVersion branch: a supplied version skips npm resolution
# and must survive normalize_npm_version unchanged.
check "Claude Code CLI is installed" sh -c "command -v claude"
check "Claude Code CLI is pinned to the requested version" sh -c "claude --version | grep -q '2\.0\.0'"

reportResults
