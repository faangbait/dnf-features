#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/scripts/agent-common.sh"

# The vendor install.sh (https://antigravity.google/cli/install.sh) can only
# install the newest release, so this follows its recipe directly: read the
# release manifest, download the archive, verify it, keep the one binary.
MANIFEST_BASE_URL="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests"
ARCHIVE_BASE_URL="https://storage.googleapis.com/antigravity-public/antigravity-cli"

require_rhel_root
install_redhat_packages curl tar gzip

case "$(uname -m)" in
    x86_64 | amd64) MANIFEST_PLATFORM=linux_amd64 ARCHIVE_PATH=linux-x64/cli_linux_x64.tar.gz ;;
    aarch64 | arm64) MANIFEST_PLATFORM=linux_arm64 ARCHIVE_PATH=linux-arm/cli_linux_arm64.tar.gz ;;
    *) fatal "Unsupported architecture: $(uname -m)." ;;
esac

# Same key-by-key sed the vendor script uses; the manifest is a flat object.
manifest_value() {
    sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$1"
}

new_scratch_dir
BUILD_DIR="${SCRATCH_DIR}"
ARCHIVE="${BUILD_DIR}/agy.tar.gz"

AGENTVERSION="${AGENTVERSION:-}"
AGENTVERSION="${AGENTVERSION#v}"
[ "${AGENTVERSION}" != "latest" ] || AGENTVERSION=""

manifest="$(curl -fsSL "${MANIFEST_BASE_URL}/${MANIFEST_PLATFORM}.json")"
latest_version="$(manifest_value "${manifest}" version)"
latest_url="$(manifest_value "${manifest}" url)"
latest_sha512="$(manifest_value "${manifest}" sha512)"
[ -n "${latest_version}" ] && [ -n "${latest_url}" ] && [ -n "${latest_sha512}" ] \
    || fatal "Could not parse the Antigravity CLI release manifest."
# The archive URL embeds <version>-<build>, the only handle on an exact build.
latest_build="${latest_url#"${ARCHIVE_BASE_URL}/"}"
latest_build="${latest_build%%/*}"

if [ -z "${AGENTVERSION}" ] || [ "${AGENTVERSION}" = "${latest_version}" ] || [ "${AGENTVERSION}" = "${latest_build}" ]; then
    BUILD="${latest_build}"
    log "Installing Antigravity CLI ${BUILD}. Set agentVersion to ${BUILD} to pin this build."
    curl -fsSL "${latest_url}" -o "${ARCHIVE}"
    [ "$(sha512sum "${ARCHIVE}" | cut -d' ' -f1)" = "${latest_sha512}" ] \
        || fatal "Archive checksum does not match the release manifest."
elif [[ "${AGENTVERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$ ]]; then
    BUILD="${AGENTVERSION}"
    log "Installing pinned Antigravity CLI build ${BUILD}."
    url="${ARCHIVE_BASE_URL}/${BUILD}/${ARCHIVE_PATH}"
    # Only the newest release has a manifest sha512; older builds are checked
    # against the MD5 the storage server publishes for the object.
    # A missing build is a 404 here; let the empty result reach the fatal below
    # instead of dying on curl's exit status with no explanation.
    expected_md5="$({ curl -fsSI "${url}" || true; } | tr -d '\r' | sed -n 's/^x-goog-hash:[[:space:]]*md5=//Ip')"
    [ -n "${expected_md5}" ] || fatal "No Antigravity CLI build ${BUILD} for this platform (or no published MD5)."
    curl -fsSL "${url}" -o "${ARCHIVE}"
    [ "$(md5sum "${ARCHIVE}" | cut -d' ' -f1)" = "$(base64 -d <<<"${expected_md5}" | od -An -tx1 | tr -d ' \n')" ] \
        || fatal "Archive checksum does not match the storage server's MD5."
else
    fatal "Invalid agentVersion: ${AGENTVERSION}. Only the newest release (${latest_version}) can be installed by version; pin an exact build as <version>-<build>, e.g. ${latest_build}."
fi

tar -xzf "${ARCHIVE}" -C "${BUILD_DIR}" antigravity
install -D -m 0755 "${BUILD_DIR}/antigravity" "${INSTALL_DIR:-/usr/local/bin}/agy"
command -v agy >/dev/null 2>&1 || fatal "Installation completed but the agy command was not found on PATH."
agy --version

clean_package_cache
