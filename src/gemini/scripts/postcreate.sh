#!/usr/bin/env bash
#
# Installed by install.sh to /usr/local/lib/dnf-features/gemini/ and run as
# this feature's postCreateCommand, since the build-time scripts/ directory
# this file ships from does not survive into the running container.

set -euo pipefail

# Deliberately standalone. agent-common.sh is a build-time, root-only library
# -- require_rhel_root and install_redhat_packages both fail as the container
# user -- so this script carries its own log rather than sourcing it.
log() {
    echo "(*) $*"
}

# The workspace _agent directory is a per-container volume (see "mounts" in
# devcontainer-feature.json), so state agy writes there neither lands in the
# host project nor reaches other containers. A new volume mounts root-owned;
# claim it so agy can write without sudo.
workspace_dir="${PWD}/_agent"
if [ -d "${workspace_dir}" ] && [ "$(stat -c %u "${workspace_dir}")" != "$(id -u)" ]; then
    sudo chown "$(id -u):$(id -g)" "${workspace_dir}" \
        || log "Could not take ownership of ${workspace_dir}; continuing."
fi
