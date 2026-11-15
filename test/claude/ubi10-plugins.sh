#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

# Exercises the pluginMarketplaces/plugins options. Their side effects are
# deliberately not asserted: both loops in postcreate.sh are best-effort, so
# the contract under test is that the container still comes up and the CLI
# still works whether or not the plugin installs succeeded.
check "postCreate script is persisted and executable" test -x /usr/local/lib/dnf-features/claude/postcreate.sh
check "Claude Code CLI is installed" sh -c "command -v claude"
check "Claude Code CLI runs" claude --version

reportResults
