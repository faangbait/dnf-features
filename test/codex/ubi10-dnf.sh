#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

check "dnf base image is in use" dnf --version
check "Codex CLI is installed" sh -c "command -v codex"
check "Codex CLI runs" codex --version
# The Linux sandbox needs the bwrap bundled beside the platform binary; a
# layout that drops it panics with "bubblewrap is unavailable". Running bwrap
# itself may still be refused by the test host, so only that panic fails.
check "Codex finds its bundled bwrap" sh -c "! codex sandbox linux -- true 2>&1 | grep -q 'bubblewrap is unavailable'"

reportResults
