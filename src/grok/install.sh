#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/scripts/agent-common.sh"

INSTALLER_URL="https://x.ai/cli/install.sh"

require_rhel_root

# The vendor installer validates the version too, but only after it has been
# fetched and started; reject a bad option before running any remote code.
# Empty or latest means the installer resolves the newest stable release.
AGENTVERSION="${AGENTVERSION:-}"
AGENTVERSION="${AGENTVERSION#v}"
[ "${AGENTVERSION}" != "latest" ] || AGENTVERSION=""
if [ -n "${AGENTVERSION}" ] && [[ ! "${AGENTVERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9._]+)?$ ]]; then
    fatal "Invalid version: ${AGENTVERSION}. Use a version such as 1.0.77, or leave empty for the newest stable release."
fi

case "$(uname -m)" in
    x86_64 | amd64) ARCH=x86_64 ;;
    aarch64 | arm64) ARCH=aarch64 ;;
    *) fatal "Unsupported architecture: $(uname -m)." ;;
esac

log "Pinning grok to ${AGENTVERSION:-the newest stable release}."

installer_args=()
[ -z "${AGENTVERSION}" ] || installer_args=("${AGENTVERSION}")

# The installer's bin directory holds symlinks; the real binary is the
# download it points at.
install_curl_binary "${INSTALLER_URL}" GROK_BIN_DIR \
    ".grok/downloads/grok-linux-${ARCH}:grok" \
    -- "${installer_args[@]}"

# The vendor installer also exposes grok as `agent`; keep that name.
ln -sf grok "${INSTALL_DIR:-/usr/local/bin}/agent"

clean_package_cache
