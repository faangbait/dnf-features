#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

# Exercises the pluginMarketplaces/plugins options. install.sh must hand them
# to postcreate.sh via options.env. The plugin side effects are deliberately
# not asserted: both loops in postcreate.sh are best-effort, so the contract
# under test is that the container still comes up and the CLI still works
# whether or not the plugin installs succeeded.
check "postCreate script is persisted and executable" test -x /usr/local/lib/dnf-features/claude/postcreate.sh
check "pluginMarketplaces option is persisted for postCreate" grep -qxF "PLUGINMARKETPLACES=anthropics/claude-plugins-official" /usr/local/lib/dnf-features/claude/options.env
check "plugins option is persisted for postCreate" grep -qxF "PLUGINS=chrome-devtools-mcp@claude-plugins-official" /usr/local/lib/dnf-features/claude/options.env
check "Claude Code CLI is installed" sh -c "command -v claude"
check "Claude Code CLI runs" claude --version

reportResults
