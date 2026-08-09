#!/usr/bin/env bash
#-------------------------------------------------------------------------------------------------------------
# Portions of this code are Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#-------------------------------------------------------------------------------------------------------------

set -euo pipefail

DOCKER_VERSION="${VERSION:-latest}"
USE_MOBY="${MOBY:-false}"
COMPOSE_VERSION="${DOCKERDASHCOMPOSEVERSION:-latest}"
INSTALL_BUILDX="${INSTALLDOCKERBUILDX:-true}"
BUILDX_VERSION="${MOBYBUILDXVERSION:-latest}"
INSTALL_COMPOSE_SWITCH="${INSTALLDOCKERCOMPOSESWITCH:-false}"
AZURE_DNS_AUTO_DETECTION="${AZUREDNSAUTODETECTION:-true}"
DOCKER_DEFAULT_ADDRESS_POOL="${DOCKERDEFAULTADDRESSPOOL:-}"
DISABLE_IP6TABLES="${DISABLEIP6TABLES:-false}"
USERNAME="${USERNAME:-${_REMOTE_USER:-automatic}}"

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

if [ "${USE_MOBY}" = "true" ]; then
    fatal "The moby option is not supported on UBI/RHEL 10 because Moby RPMs are unavailable. Use the default Docker CE packages."
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

install_packages() {
    log "Installing packages with ${PACKAGE_MANAGER}: $*"
    "${PACKAGE_MANAGER}" -y install "$@"
}

clean_packages() {
    "${PACKAGE_MANAGER}" clean all >/dev/null 2>&1 || true
    rm -rf /var/cache/dnf /var/cache/yum
}

resolve_user() {
    if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
        local candidate
        for candidate in vscode node codespace; do
            if id "${candidate}" >/dev/null 2>&1; then
                USERNAME="${candidate}"
                return
            fi
        done
        USERNAME="$(awk -F: '$3 == 1000 { print $1; exit }' /etc/passwd)"
        USERNAME="${USERNAME:-root}"
    elif [ "${USERNAME}" = "none" ] || ! id "${USERNAME}" >/dev/null 2>&1; then
        USERNAME="root"
    fi
}

resolve_architecture() {
    case "$(uname -m)" in
        x86_64 | amd64)
            DOCKER_ARCH="x86_64"
            BUILDX_ARCH="amd64"
            COMPOSE_ARCH="x86_64"
            ;;
        aarch64 | arm64)
            DOCKER_ARCH="aarch64"
            BUILDX_ARCH="arm64"
            COMPOSE_ARCH="aarch64"
            ;;
        *)
            fatal "Docker static binaries are not supported on architecture $(uname -m) by this Feature."
            ;;
    esac
}

resolve_docker_version() {
    local index_url="https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/"
    local versions requested
    versions="$(curl -fsSL "${index_url}" | grep -oE 'docker-[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?\.tgz' | sed -E 's/^docker-//; s/\.tgz$//' | sort -Vu)"
    [ -n "${versions}" ] || fatal "Could not discover Docker versions from ${index_url}."

    requested="${DOCKER_VERSION#v}"
    if [ "${requested}" = "latest" ]; then
        RESOLVED_DOCKER_VERSION="$(printf '%s\n' "${versions}" | tail -n 1)"
    elif [[ "${requested}" =~ ^[0-9]+(\.[0-9]+){0,2}(-[0-9]+)?$ ]]; then
        RESOLVED_DOCKER_VERSION="$(printf '%s\n' "${versions}" | grep -E "^${requested}([.-]|$)" | tail -n 1 || true)"
        [ -n "${RESOLVED_DOCKER_VERSION}" ] || fatal "No Docker static release matches ${DOCKER_VERSION}."
    else
        fatal "Invalid Docker version: ${DOCKER_VERSION}. Use latest or a numeric version such as 29.7.2."
    fi
}

latest_release_tag() {
    local repository="$1"
    local effective_url
    effective_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/${repository}/releases/latest")"
    basename "${effective_url}"
}

verify_release_checksum() {
    local downloaded_file="$1"
    local checksum_url="$2"
    local asset_name="$3"
    local checksum_file="${TEMP_DIR}/checksums.txt"
    local checksum

    curl -fsSL "${checksum_url}" -o "${checksum_file}"
    checksum="$(awk -v asset="${asset_name}" '{ name=$2; sub(/^\*/, "", name); if (name == asset) { print $1; exit } }' "${checksum_file}")"
    [[ "${checksum}" =~ ^[0-9a-fA-F]{64}$ ]] || fatal "No SHA-256 checksum was published for ${asset_name}."
    printf '%s  %s\n' "${checksum}" "${downloaded_file}" | sha256sum --check --status - || fatal "SHA-256 verification failed for ${asset_name}."
}

install_docker_binaries() {
    local archive="${TEMP_DIR}/docker.tgz"
    local url="https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-${RESOLVED_DOCKER_VERSION}.tgz"
    log "Installing Docker ${RESOLVED_DOCKER_VERSION} static binaries from ${url}"
    curl -fsSL "${url}" -o "${archive}"
    tar -xzf "${archive}" --strip-components=1 -C /usr/local/bin
}

install_buildx() {
    local version="${BUILDX_VERSION#v}"
    local asset_name
    local destination="/usr/local/lib/docker/cli-plugins/docker-buildx"
    if [ "${version}" = "latest" ]; then
        version="$(latest_release_tag docker/buildx)"
        version="${version#v}"
    fi
    [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] || fatal "Invalid Buildx version: ${BUILDX_VERSION}."
    asset_name="buildx-v${version}.linux-${BUILDX_ARCH}"
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fsSL "https://github.com/docker/buildx/releases/download/v${version}/${asset_name}" -o "${destination}"
    verify_release_checksum "${destination}" "https://github.com/docker/buildx/releases/download/v${version}/checksums.txt" "${asset_name}"
    chmod +x "${destination}"
}

install_compose() {
    local tag version asset_name
    local destination="/usr/local/lib/docker/cli-plugins/docker-compose"
    tag="$(latest_release_tag docker/compose)"
    version="${tag#v}"
    asset_name="docker-compose-linux-${COMPOSE_ARCH}"
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fsSL "https://github.com/docker/compose/releases/download/v${version}/${asset_name}" -o "${destination}"
    verify_release_checksum "${destination}" "https://github.com/docker/compose/releases/download/v${version}/${asset_name}.sha256" "${asset_name}"
    chmod +x "${destination}"
}

resolve_user
install_packages ca-certificates curl gzip nftables procps-ng shadow-utils sudo tar
resolve_architecture
resolve_docker_version

if [ "${RESOLVED_DOCKER_VERSION%%.*}" -lt 29 ]; then
    fatal "Docker-in-Docker on UBI 10 requires Docker 29 or newer for the nftables firewall backend."
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT
install_docker_binaries
if [ "${INSTALL_BUILDX}" = "true" ]; then
    install_buildx
fi
if [ "${COMPOSE_VERSION}" != "none" ]; then
    install_compose
fi

if ! command -v dockerd >/dev/null 2>&1; then
    fatal "dockerd was not installed from the Docker static archive."
fi

if ! getent group docker >/dev/null 2>&1; then
    groupadd --system docker
fi
if [ "${USERNAME}" != "root" ]; then
    usermod -aG docker "${USERNAME}"
fi

if [ "${INSTALL_COMPOSE_SWITCH}" = "true" ] && [ "${COMPOSE_VERSION}" != "none" ]; then
    cat > /usr/local/bin/docker-compose <<'EOF'
#!/usr/bin/env bash
exec docker compose "$@"
EOF
    chmod +x /usr/local/bin/docker-compose
fi

cat > /usr/local/share/docker-init.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail

AZURE_DNS_AUTO_DETECTION="${AZURE_DNS_AUTO_DETECTION}"
DOCKER_DEFAULT_ADDRESS_POOL="${DOCKER_DEFAULT_ADDRESS_POOL}"
DISABLE_IP6TABLES="${DISABLE_IP6TABLES}"

run_as_root() {
    if [ "\$(id -u)" -eq 0 ]; then
        "\$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "\$@"
    else
        echo "(!) docker-in-docker needs root privileges to start dockerd." >&2
        return 1
    fi
}

daemon_args=(dockerd)
daemon_args+=(--firewall-backend=nftables)
if [ -n "\${DOCKER_DEFAULT_ADDRESS_POOL}" ]; then
    daemon_args+=(--default-address-pool "\${DOCKER_DEFAULT_ADDRESS_POOL}")
fi
if [ "\${DISABLE_IP6TABLES}" = "true" ]; then
    daemon_args+=(--ip6tables=false)
fi
if [ "\${AZURE_DNS_AUTO_DETECTION}" = "true" ] && grep -qi 'internal.cloudapp.net' /etc/resolv.conf; then
    daemon_args+=(--dns 168.63.129.16)
fi

run_as_root rm -f /run/docker.pid /var/run/docker.pid /run/containerd/containerd.pid
run_as_root mkdir -p /run/containerd /var/lib/docker /var/lib/containerd
run_as_root sysctl -w net.ipv4.ip_forward=1 >/dev/null

if [ "\$(id -u)" -eq 0 ]; then
    nohup "\${daemon_args[@]}" >/tmp/dockerd.log 2>&1 &
else
    sudo nohup "\${daemon_args[@]}" >/tmp/dockerd.log 2>&1 &
fi
dockerd_pid=\$!

docker_ready=false
for _ in {1..60}; do
    if docker info >/dev/null 2>&1; then
        docker_ready=true
        break
    fi
    if ! kill -0 "\${dockerd_pid}" >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

if [ "\${docker_ready}" != "true" ]; then
    echo "(!) Docker daemon did not become ready. /tmp/dockerd.log follows:" >&2
    tail -n 100 /tmp/dockerd.log >&2 || true
    exit 1
fi

exec "\$@"
EOF

chmod +x /usr/local/share/docker-init.sh
clean_packages
log "Docker-in-Docker installation complete."
