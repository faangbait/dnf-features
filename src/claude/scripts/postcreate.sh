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

# The workspace .claude directory is a per-container volume (see "mounts" in
# devcontainer-feature.json), so plugin enablement written there with local
# scope neither lands in the host project nor reaches other containers. A new
# volume mounts root-owned; claim it so claude can write without sudo.
workspace_claude="${PWD}/.claude"
if [ -d "${workspace_claude}" ] && [ "$(stat -c %u "${workspace_claude}")" != "$(id -u)" ]; then
    sudo chown "$(id -u):$(id -g)" "${workspace_claude}" \
        || log "Could not take ownership of ${workspace_claude}; continuing."
fi

# Both loops are best-effort. Adding a marketplace and installing a plugin
# need network, and may need credentials, neither of which is guaranteed at
# container creation; a transient failure must not fail the create.
for marketplace in ${PLUGINMARKETPLACES:-}; do
    log "Adding Claude Code plugin marketplace: ${marketplace}"
    claude plugin marketplace add "${marketplace}" --scope user \
        || log "Could not add marketplace ${marketplace}; continuing."
done

# Plugins default to local scope: user scope writes enablement into the config
# directory, which containers sharing a volume (/var/llms) all read. Marketplaces
# stay at user scope; they are catalogs, not enablement.
for plugin in ${PLUGINS:-}; do
    log "Installing Claude Code plugin: ${plugin}"
    claude plugin install "${plugin}" --scope "${PLUGINSCOPE:-local}" \
        || log "Could not install plugin ${plugin}; continuing."
done
