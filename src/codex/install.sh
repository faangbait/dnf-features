#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/scripts/agent-common.sh"

PACKAGE="@openai/codex"

require_rhel_root
install_redhat_packages nodejs npm

[ -n "${AGENTVERSION:-}" ] || resolve_npm_version "${PACKAGE}" AGENTVERSION
normalize_npm_version AGENTVERSION

log "Pinning ${PACKAGE} to ${AGENTVERSION}."

# bin/codex.js is a node launcher for a platform binary that looks for its
# bundled bwrap (the Linux sandbox) and rg beside itself, so the whole package
# tree has to stay: install_npm_global, not install_npm_binary.
install_npm_global "${PACKAGE}" codex "${AGENTVERSION}"

# codex clones git marketplaces with the git CLI, so git is only needed when
# there is something to fetch.
if [ -n "${PLUGINMARKETPLACES:-}${PLUGINS:-}" ]; then
    install_redhat_packages git-core
fi

# postCreateCommand runs against the running container, long after this
# build-time scripts/ directory is gone, so its script needs a permanent home.
PERSIST_DIR=/usr/local/lib/dnf-features/codex
mkdir -p "${PERSIST_DIR}"
install -m 0755 "${SCRIPT_DIR}/scripts/postcreate.sh" "${PERSIST_DIR}/postcreate.sh"

# Feature options exist only in this script's environment, not in the
# postCreateCommand's, so hand them over in a file postcreate.sh sources.
{
    printf 'PLUGINMARKETPLACES=%q\n' "${PLUGINMARKETPLACES:-}"
    printf 'PLUGINS=%q\n' "${PLUGINS:-}"
} > "${PERSIST_DIR}/options.env"
chmod 0644 "${PERSIST_DIR}/options.env"

clean_package_cache
