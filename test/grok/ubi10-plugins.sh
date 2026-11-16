#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

# Exercises the pluginMarketplaces/plugins options. install.sh must hand them
# to postcreate.sh via options.env, and install git for grok to clone with.
# The plugin side effects are deliberately not asserted: both loops in
# postcreate.sh are best-effort, so the contract under test is that the
# container still comes up and the CLI still works whether or not the plugin
# installs succeeded.
check "postCreate script is persisted and executable" test -x /usr/local/lib/dnf-features/grok/postcreate.sh
check "pluginMarketplaces option is persisted for postCreate" grep -qxF "PLUGINMARKETPLACES=anthropics/claude-plugins-official" /usr/local/lib/dnf-features/grok/options.env
check "plugins option is persisted for postCreate" grep -qxF "PLUGINS=chrome-devtools-mcp@claude-plugins-official" /usr/local/lib/dnf-features/grok/options.env
check "git is installed for plugin fetches" git --version
check "workspace .grok is a mounted volume" sh -c "awk '\$2 ~ /\\/\\.grok\$/ {found=1} END {exit !found}' /proc/mounts"
check "Grok CLI is installed" sh -c "command -v grok"
check "Grok CLI runs" grok --version

reportResults
