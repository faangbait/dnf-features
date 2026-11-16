#!/usr/bin/env bash
#
# Installed by install.sh to /usr/local/lib/dnf-features/grok/ and run as
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
. /usr/local/lib/dnf-features/grok/options.env

# The workspace .grok directory is a per-container volume (see "mounts" in
# devcontainer-feature.json), so state grok writes there neither lands in the
# host project nor reaches other containers. A new volume mounts root-owned;
# claim it so grok can write without sudo.
workspace_dir="${PWD}/.grok"
if [ -d "${workspace_dir}" ] && [ "$(stat -c %u "${workspace_dir}")" != "$(id -u)" ]; then
    sudo chown "$(id -u):$(id -g)" "${workspace_dir}" \
        || log "Could not take ownership of ${workspace_dir}; continuing."
fi

# Both loops are best-effort. Adding a marketplace and installing a plugin
# need network, and may need credentials, neither of which is guaranteed at
# container creation; a transient failure must not fail the create. grok
# also gives up on a marketplace clone after 15 seconds, which a large
# marketplace can exceed on a slow link.
for marketplace in ${PLUGINMARKETPLACES:-}; do
    log "Adding Grok plugin marketplace: ${marketplace}"
    grok plugin marketplace add "${marketplace}" </dev/null \
        || log "Could not add marketplace ${marketplace}; continuing."
done

# Listing a plugin in the option is the trust decision. Without --trust grok
# refuses to install instead of prompting; with it the plugin is also enabled
# in config.toml.
for plugin in ${PLUGINS:-}; do
    log "Installing Grok plugin: ${plugin}"
    grok plugin install "${plugin}" --trust </dev/null \
        || log "Could not install plugin ${plugin}; continuing."
done
