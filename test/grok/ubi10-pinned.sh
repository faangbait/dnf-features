#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

# Exercises the agentVersion branch: a supplied version is passed through to
# the vendor installer instead of resolving the newest stable release.
check "Grok CLI is installed" sh -c "command -v grok"
check "Grok CLI is pinned to the requested version" sh -c "grok --version | grep -q '1\.0\.72'"

reportResults
