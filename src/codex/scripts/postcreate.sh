#!/usr/bin/env bash
#
# Installed by install.sh to /usr/local/lib/dnf-features/codex/ and run as
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
. /usr/local/lib/dnf-features/codex/options.env

# The workspace .codex directory is a per-container volume (see "mounts" in
# devcontainer-feature.json), so state codex writes there neither lands in the
# host project nor reaches other containers. A new volume mounts root-owned;
# claim it so codex can write without sudo.
workspace_dir="${PWD}/.codex"
if [ -d "${workspace_dir}" ] && [ "$(stat -c %u "${workspace_dir}")" != "$(id -u)" ]; then
    sudo chown "$(id -u):$(id -g)" "${workspace_dir}" \
        || log "Could not take ownership of ${workspace_dir}; continuing."
fi

# Both loops are best-effort. Adding a marketplace and installing a plugin
# need network, and may need credentials, neither of which is guaranteed at
# container creation; a transient failure must not fail the create.
for marketplace in ${PLUGINMARKETPLACES:-}; do
    log "Adding Codex plugin marketplace: ${marketplace}"
    codex plugin marketplace add "${marketplace}" </dev/null \
        || log "Could not add marketplace ${marketplace}; continuing."
done

for plugin in ${PLUGINS:-}; do
    log "Installing Codex plugin: ${plugin}"
    codex plugin add "${plugin}" </dev/null \
        || log "Could not install plugin ${plugin}; continuing."
done
