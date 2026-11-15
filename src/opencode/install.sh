#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/scripts/agent-common.sh"

PACKAGE="opencode-ai"

require_rhel_root
install_redhat_packages nodejs npm

[ -n "${AGENTVERSION:-}" ] || resolve_npm_version "${PACKAGE}" AGENTVERSION
normalize_npm_version AGENTVERSION

log "Pinning ${PACKAGE} to ${AGENTVERSION}."

# postinstall swaps bin/opencode.exe for the self-contained platform binary,
# so that one file is all that is kept.
install_npm_binary "${PACKAGE}" opencode "${AGENTVERSION}"

# postCreateCommand runs against the running container, long after this
# build-time scripts/ directory is gone, so its script needs a permanent home.
PERSIST_DIR=/usr/local/lib/dnf-features/opencode
mkdir -p "${PERSIST_DIR}"
install -m 0755 "${SCRIPT_DIR}/scripts/postcreate.sh" "${PERSIST_DIR}/postcreate.sh"

# Feature options exist only in this script's environment, not in the
# postCreateCommand's, so hand them over in a file postcreate.sh sources.
printf 'PLUGINS=%q\n' "${PLUGINS:-}" > "${PERSIST_DIR}/options.env"
chmod 0644 "${PERSIST_DIR}/options.env"

clean_package_cache
