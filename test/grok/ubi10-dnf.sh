#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "dnf base image is in use" dnf --version
check "Grok CLI is installed" sh -c "command -v grok"
check "Grok CLI runs" grok --version
check "agent alias runs grok" sh -c "test \"\$(readlink /usr/local/bin/agent)\" = grok && agent --version"
# The vendor installer symlinks into /usr/local/bin when its own directory is
# not on PATH; none of those links may point into the discarded scratch tree.
check "no dangling symlinks in /usr/local/bin" bash -c 'for l in /usr/local/bin/*; do [ ! -L "$l" ] || [ -e "$l" ] || exit 1; done'

reportResults
