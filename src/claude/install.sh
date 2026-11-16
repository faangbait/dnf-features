#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/scripts/agent-common.sh"

PACKAGE="@anthropic-ai/claude-code"

require_rhel_root
install_redhat_packages nodejs npm

[ -n "${AGENTVERSION:-}" ] || resolve_npm_version "${PACKAGE}" AGENTVERSION
normalize_npm_version AGENTVERSION

log "Pinning ${PACKAGE} to ${AGENTVERSION}."

install_npm_global "${PACKAGE}" claude "${AGENTVERSION}"

# postCreateCommand runs against the running container, long after this
# build-time scripts/ directory is gone, so its script needs a permanent home.
PERSIST_DIR=/usr/local/lib/dnf-features/claude
mkdir -p "${PERSIST_DIR}"
install -m 0755 "${SCRIPT_DIR}/scripts/postcreate.sh" "${PERSIST_DIR}/postcreate.sh"

# Feature options exist only in this script's environment, not in the
# postCreateCommand's, so hand them over in a file postcreate.sh sources.
{
    printf 'PLUGINMARKETPLACES=%q\n' "${PLUGINMARKETPLACES:-}"
    printf 'PLUGINS=%q\n' "${PLUGINS:-}"
    printf 'PLUGINSCOPE=%q\n' "${PLUGINSCOPE:-local}"
} > "${PERSIST_DIR}/options.env"
chmod 0644 "${PERSIST_DIR}/options.env"

clean_package_cache
