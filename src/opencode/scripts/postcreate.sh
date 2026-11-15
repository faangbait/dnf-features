#!/usr/bin/env bash
#
# Installed by install.sh to /usr/local/lib/dnf-features/opencode/ and run as
# this feature's postCreateCommand, since the build-time scripts/ directory
# this file ships from does not survive into the running container.

set -euo pipefail

# Deliberately standalone. agent-common.sh is a build-time, root-only library
# -- require_rhel_root and install_redhat_packages both fail as the container
# user -- so this script carries its own log rather than sourcing it.
log() {
    echo "(*) $*"
}

# Written by install.sh: Feature options are not in this script's environment.
# shellcheck disable=SC1091
. /usr/local/lib/dnf-features/opencode/options.env

# Best-effort. Installing a plugin needs network, and may need credentials,
# neither of which is guaranteed at container creation; a transient failure
# must not fail the create. opencode plugins are npm packages with no
# marketplace step; --global records each one in the user's opencode.json.
for plugin in ${PLUGINS:-}; do
    log "Installing opencode plugin: ${plugin}"
    opencode plugin "${plugin}" --global </dev/null \
        || log "Could not install plugin ${plugin}; continuing."
done
