#!/usr/bin/env bash

set -euo pipefail

KUBECTL_VERSION="${VERSION:-latest}"
HELM_VERSION="${HELM:-latest}"
MINIKUBE_VERSION="${MINIKUBE:-latest}"
CALICOCTL_VERSION="${CALICOCTL:-latest}"
KUBECTL_FALLBACK_VERSION="${KUBECTLFALLBACKVERSION:-v1.35.1}"
USERNAME="${USERNAME:-${_REMOTE_USER:-automatic}}"
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
        fatal "kubectl, Helm, Calicoctl, and Minikube are not supported on architecture $(uname -m) by this Feature."
        ;;
esac

log "Installing prerequisites with ${PACKAGE_MANAGER}."
"${PACKAGE_MANAGER}" -y install bash-completion ca-certificates curl gzip tar
mkdir -p /etc/bash_completion.d

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT

is_latest_alias() {
    case "$1" in
        latest | current | lts | stable) return 0 ;;
        *) return 1 ;;
    esac
}

require_full_version() {
    local product="$1"
    local requested="${2#v}"
    [[ "${requested}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] \
        || fatal "Invalid ${product} version: $2. Use latest, none, or a full semantic version."
    printf 'v%s' "${requested}"
}

checksum_file() {
    local file="$1"
    local checksum_url="$2"
    local checksum_file="${TEMP_DIR}/$(basename "${file}").sha256"
    local checksum

    curl -fsSL "${checksum_url}" -o "${checksum_file}"
    checksum="$(awk 'NR == 1 { print $1 }' "${checksum_file}")"
    [[ "${checksum}" =~ ^[0-9a-fA-F]{64}$ ]] \
        || fatal "No valid SHA-256 checksum was published at ${checksum_url}."
    printf '%s  %s\n' "${checksum}" "${file}" | sha256sum --check --status - \
        || fatal "SHA-256 verification failed for $(basename "${file}")."
}

checksum_manifest_file() {
    local file="$1"
    local checksum_url="$2"
    local asset="$3"
    local manifest_file="${TEMP_DIR}/SHA256SUMS"
    local checksum

    curl -fsSL "${checksum_url}" -o "${manifest_file}"
    checksum="$(awk -v asset="${asset}" '$2 == asset { print $1; exit }' "${manifest_file}")"
    [[ "${checksum}" =~ ^[0-9a-fA-F]{64}$ ]] \
        || fatal "No valid SHA-256 checksum for ${asset} was published at ${checksum_url}."
    printf '%s  %s\n' "${checksum}" "${file}" | sha256sum --check --status - \
        || fatal "SHA-256 verification failed for ${asset}."
}

resolve_kubectl_version() {
    local requested="$1"
    local version_url
    local resolved

    if is_latest_alias "${requested}"; then
        version_url="https://dl.k8s.io/release/stable.txt"
    elif [[ "${requested#v}" =~ ^[0-9]+\.[0-9]+$ ]]; then
        version_url="https://dl.k8s.io/release/stable-${requested#v}.txt"
    else
        require_full_version "kubectl" "${requested}"
        return
    fi

    resolved="$(curl -fsSL --connect-timeout 10 --max-time 30 "${version_url}" 2>/dev/null || true)"
    if [[ ! "${resolved}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
        if is_latest_alias "${requested}"; then
            log "Could not resolve the stable kubectl version; using fallback ${KUBECTL_FALLBACK_VERSION}." >&2
            require_full_version "kubectl fallback" "${KUBECTL_FALLBACK_VERSION}"
            return
        fi
        fatal "Could not resolve a kubectl release for ${requested}."
    fi
    printf '%s' "${resolved}"
}

resolve_latest_github_release() {
    local product="$1"
    local repository="$2"
    local effective_url
    local version

    effective_url="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/${repository}/releases/latest")"
    version="${effective_url##*/}"
    [[ "${version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] \
        || fatal "Could not resolve the latest ${product} release."
    printf '%s' "${version}"
}

resolve_release_version() {
    local product="$1"
    local repository="$2"
    local requested="$3"

    if is_latest_alias "${requested}"; then
        resolve_latest_github_release "${product}" "${repository}"
    else
        require_full_version "${product}" "${requested}"
    fi
}

if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    for candidate in vscode node codespace "$(awk -F: '$3 == 1000 { print $1; exit }' /etc/passwd)"; do
        if [ -n "${candidate}" ] && id -u "${candidate}" >/dev/null 2>&1; then
            USERNAME="${candidate}"
            break
        fi
    done
    USERNAME="${USERNAME:-root}"
elif [ "${USERNAME}" = "none" ] || ! id -u "${USERNAME}" >/dev/null 2>&1; then
    USERNAME="root"
fi

if [ "${USERNAME}" = "root" ]; then
    USER_HOME="/root"
else
    USER_HOME="$(awk -F: -v user="${USERNAME}" '$1 == user { print $6; exit }' /etc/passwd)"
    USER_HOME="${USER_HOME:-/home/${USERNAME}}"
fi

if [ "${KUBECTL_VERSION}" != "none" ]; then
    KUBECTL_VERSION="$(resolve_kubectl_version "${KUBECTL_VERSION}")"
    KUBECTL_BINARY="${TEMP_DIR}/kubectl"
    KUBECTL_URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${RELEASE_ARCH}/kubectl"

    log "Installing kubectl ${KUBECTL_VERSION}."
    curl -fsSL "${KUBECTL_URL}" -o "${KUBECTL_BINARY}"
    checksum_file "${KUBECTL_BINARY}" "${KUBECTL_URL}.sha256"
    install -m 0755 "${KUBECTL_BINARY}" /usr/local/bin/kubectl
    kubectl completion bash > /etc/bash_completion.d/kubectl
fi

if [ "${HELM_VERSION}" != "none" ]; then
    HELM_VERSION="$(resolve_release_version "Helm" "helm/helm" "${HELM_VERSION}")"
    HELM_ASSET="helm-${HELM_VERSION}-linux-${RELEASE_ARCH}.tar.gz"
    HELM_ARCHIVE="${TEMP_DIR}/${HELM_ASSET}"
    HELM_URL="https://get.helm.sh/${HELM_ASSET}"

    log "Installing Helm ${HELM_VERSION}."
    curl -fsSL "${HELM_URL}" -o "${HELM_ARCHIVE}"
    checksum_file "${HELM_ARCHIVE}" "${HELM_URL}.sha256"
    tar -xzf "${HELM_ARCHIVE}" -C "${TEMP_DIR}"
    [ -f "${TEMP_DIR}/linux-${RELEASE_ARCH}/helm" ] \
        || fatal "${HELM_ASSET} did not contain the Helm binary."
    install -m 0755 "${TEMP_DIR}/linux-${RELEASE_ARCH}/helm" /usr/local/bin/helm
    helm completion bash > /etc/bash_completion.d/helm
fi

if [ "${MINIKUBE_VERSION}" != "none" ]; then
    if is_latest_alias "${MINIKUBE_VERSION}"; then
        MINIKUBE_VERSION="latest"
    else
        MINIKUBE_VERSION="$(require_full_version "Minikube" "${MINIKUBE_VERSION}")"
    fi
    MINIKUBE_BINARY="${TEMP_DIR}/minikube"
    MINIKUBE_URL="https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-${RELEASE_ARCH}"

    log "Installing Minikube ${MINIKUBE_VERSION}."
    curl -fsSL "${MINIKUBE_URL}" -o "${MINIKUBE_BINARY}"
    checksum_file "${MINIKUBE_BINARY}" "${MINIKUBE_URL}.sha256"
    install -m 0755 "${MINIKUBE_BINARY}" /usr/local/bin/minikube
    mkdir -p "${USER_HOME}/.minikube"
    chown -R "${USERNAME}" "${USER_HOME}/.minikube"
    chmod u+rwx "${USER_HOME}/.minikube"
fi

if [ "${CALICOCTL_VERSION}" != "none" ]; then
    CALICOCTL_VERSION="$(resolve_release_version "Calicoctl" "projectcalico/calico" "${CALICOCTL_VERSION}")"
    CALICOCTL_ASSET="calicoctl-linux-${RELEASE_ARCH}"
    CALICOCTL_BINARY="${TEMP_DIR}/${CALICOCTL_ASSET}"
    CALICOCTL_RELEASE_URL="https://github.com/projectcalico/calico/releases/download/${CALICOCTL_VERSION}"

    log "Installing Calicoctl ${CALICOCTL_VERSION}."
    curl -fsSL "${CALICOCTL_RELEASE_URL}/${CALICOCTL_ASSET}" -o "${CALICOCTL_BINARY}"
    checksum_manifest_file "${CALICOCTL_BINARY}" "${CALICOCTL_RELEASE_URL}/SHA256SUMS" "${CALICOCTL_ASSET}"
    install -m 0755 "${CALICOCTL_BINARY}" /usr/local/bin/calicoctl
fi

install -m 0755 "${FEATURE_DIR}/sync-local-kubeconfig.sh" /usr/local/share/sync-local-kubeconfig.sh

"${PACKAGE_MANAGER}" clean all >/dev/null 2>&1 || true
rm -rf /var/cache/dnf /var/cache/yum

if [ "${MINIKUBE_VERSION}" != "none" ] && ! command -v docker >/dev/null 2>&1; then
    log "Docker was not found. Minikube requires a supported driver before it can start a cluster."
fi

log "kubectl, Helm, Calicoctl, and Minikube installation complete."
