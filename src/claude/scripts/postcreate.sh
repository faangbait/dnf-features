#!/usr/bin/env bash
#
# Installed by install.sh to /usr/local/lib/dnf-features/claude/ and run as
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
. /usr/local/lib/dnf-features/claude/options.env

# Both loops are best-effort. Adding a marketplace and installing a plugin
# need network, and may need credentials, neither of which is guaranteed at
# container creation; a transient failure must not fail the create.
for marketplace in ${PLUGINMARKETPLACES:-}; do
    log "Adding Claude Code plugin marketplace: ${marketplace}"
    claude plugin marketplace add "${marketplace}" --scope user \
        || log "Could not add marketplace ${marketplace}; continuing."
done

for plugin in ${PLUGINS:-}; do
    log "Installing Claude Code plugin: ${plugin}"
    claude plugin install "${plugin}" --scope user \
        || log "Could not install plugin ${plugin}; continuing."
done
