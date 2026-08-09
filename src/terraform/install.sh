#!/usr/bin/env bash

set -euo pipefail

TERRAFORM_VERSION="${TERRAFORM:-1.15.8}"
TFLINT_VERSION="${TFLINT:-0.64.0}"
TERRAFORM_MCP_SERVER_VERSION="${MCPSERVER:-1.1.0}"

log() {
    echo "(*) $*"
}

fatal() {
    echo "(!) $*" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    fatal "This Feature must be installed as root."
fi

# Dev Container Feature options are strings, so reject characters that could
# alter a release URL or archive name. A leading v is accepted for convenience.
normalize_version() {
    local version="${1#v}"
    [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] \
        || fatal "Invalid version: $1. Use a semantic version such as 1.15.8."
    printf '%s' "${version}"
}

TERRAFORM_VERSION="$(normalize_version "${TERRAFORM_VERSION}")"
TFLINT_VERSION="$(normalize_version "${TFLINT_VERSION}")"
TERRAFORM_MCP_SERVER_VERSION="$(normalize_version "${TERRAFORM_MCP_SERVER_VERSION}")"

# shellcheck disable=SC1091
. /etc/os-release
if [[ "${ID:-}" != "rhel" && "${ID:-}" != "ubi" && "${ID_LIKE:-}" != *"rhel"* && "${ID_LIKE:-}" != *"fedora"* ]]; then
    fatal "This RHEL edition supports RHEL-compatible images only (detected ID=${ID:-unknown})."
fi

if command -v dnf >/dev/null 2>&1; then
    PACKAGE_MANAGER="dnf"
elif command -v microdnf >/dev/null 2>&1; then
    PACKAGE_MANAGER="microdnf"
else
    fatal "Neither dnf nor microdnf is installed."
fi

case "$(uname -m)" in
    x86_64 | amd64)
        RELEASE_ARCH="amd64"
        ;;
    aarch64 | arm64)
        RELEASE_ARCH="arm64"
        ;;
    *)
        fatal "Terraform tooling is not supported on architecture $(uname -m) by this Feature."
        ;;
esac

log "Installing prerequisites with ${PACKAGE_MANAGER}."
"${PACKAGE_MANAGER}" -y install ca-certificates curl unzip

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT

verify_checksum() {
    local archive="$1"
    local checksums_url="$2"
    local asset_name="$3"
    local checksums_file="${TEMP_DIR}/${asset_name}.checksums"
    local checksum

    curl -fsSL "${checksums_url}" -o "${checksums_file}"
    checksum="$(awk -v asset="${asset_name}" '{ name=$2; sub(/^\*/, "", name); if (name == asset) { print $1; exit } }' "${checksums_file}")"
    [[ "${checksum}" =~ ^[0-9a-fA-F]{64}$ ]] || fatal "No SHA-256 checksum was published for ${asset_name}."
    printf '%s  %s\n' "${checksum}" "${archive}" | sha256sum --check --status - \
        || fatal "SHA-256 verification failed for ${asset_name}."
}

install_archive_binary() {
    local product="$1"
    local version="$2"
    local url="$3"
    local checksums_url="$4"
    local asset_name="$5"
    local binary_name="$6"
    local archive="${TEMP_DIR}/${asset_name}"
    local extract_dir="${TEMP_DIR}/${product}"

    log "Installing ${product} ${version} from ${url}"
    curl -fsSL "${url}" -o "${archive}"
    verify_checksum "${archive}" "${checksums_url}" "${asset_name}"
    mkdir -p "${extract_dir}"
    unzip -q "${archive}" -d "${extract_dir}"
    [ -f "${extract_dir}/${binary_name}" ] || fatal "${asset_name} did not contain ${binary_name}."
    install -m 0755 "${extract_dir}/${binary_name}" "/usr/local/bin/${binary_name}"
}

TERRAFORM_ASSET="terraform_${TERRAFORM_VERSION}_linux_${RELEASE_ARCH}.zip"
TERRAFORM_BASE_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}"
install_archive_binary \
    "Terraform" \
    "${TERRAFORM_VERSION}" \
    "${TERRAFORM_BASE_URL}/${TERRAFORM_ASSET}" \
    "${TERRAFORM_BASE_URL}/terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
    "${TERRAFORM_ASSET}" \
    "terraform"

echo 'alias tf=terraform' > /etc/profile.d/tf-alias.sh

TFLINT_ASSET="tflint_linux_${RELEASE_ARCH}.zip"
TFLINT_BASE_URL="https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}"
install_archive_binary \
    "TFLint" \
    "${TFLINT_VERSION}" \
    "${TFLINT_BASE_URL}/${TFLINT_ASSET}" \
    "${TFLINT_BASE_URL}/checksums.txt" \
    "${TFLINT_ASSET}" \
    "tflint"

TERRAFORM_MCP_SERVER_ASSET="terraform-mcp-server_${TERRAFORM_MCP_SERVER_VERSION}_linux_${RELEASE_ARCH}.zip"
TERRAFORM_MCP_SERVER_BASE_URL="https://releases.hashicorp.com/terraform-mcp-server/${TERRAFORM_MCP_SERVER_VERSION}"
install_archive_binary \
    "Terraform MCP Server" \
    "${TERRAFORM_MCP_SERVER_VERSION}" \
    "${TERRAFORM_MCP_SERVER_BASE_URL}/${TERRAFORM_MCP_SERVER_ASSET}" \
    "${TERRAFORM_MCP_SERVER_BASE_URL}/terraform-mcp-server_${TERRAFORM_MCP_SERVER_VERSION}_SHA256SUMS" \
    "${TERRAFORM_MCP_SERVER_ASSET}" \
    "terraform-mcp-server"

"${PACKAGE_MANAGER}" clean all >/dev/null 2>&1 || true
rm -rf /var/cache/dnf /var/cache/yum

log "Terraform tooling installation complete."
