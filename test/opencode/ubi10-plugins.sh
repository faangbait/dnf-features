#!/usr/bin/env bash

set -e
source dev-container-features-test-lib

# Exercises the plugins option: install.sh must hand it to postcreate.sh via
# options.env. The plugin side effects are deliberately not asserted: the
# loop in postcreate.sh is best-effort, so the contract under test is that
# the container still comes up and the CLI still works whether or not the
# plugin installs succeeded.
check "postCreate script is persisted and executable" test -x /usr/local/lib/dnf-features/opencode/postcreate.sh
check "plugins option is persisted for postCreate" grep -qxF "PLUGINS=opencode-gitlab-auth" /usr/local/lib/dnf-features/opencode/options.env
check "opencode CLI is installed" sh -c "command -v opencode"
check "opencode CLI runs" opencode --version

reportResults
