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
SOCKET_PATH="${SOCKETPATH:-/var/run/docker-host.sock}"
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

install_docker_cli() {
    local archive="${TEMP_DIR}/docker.tgz"
    local url="https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-${RESOLVED_DOCKER_VERSION}.tgz"
    log "Installing Docker CLI ${RESOLVED_DOCKER_VERSION} from ${url}"
    curl -fsSL "${url}" -o "${archive}"
    tar -xzf "${archive}" -C "${TEMP_DIR}" docker/docker
    install -m 0755 "${TEMP_DIR}/docker/docker" /usr/local/bin/docker
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
install_packages ca-certificates curl gzip shadow-utils socat sudo tar
resolve_architecture
resolve_docker_version
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT
install_docker_cli
if [ "${INSTALL_BUILDX}" = "true" ]; then
    install_buildx
fi
if [ "${COMPOSE_VERSION}" != "none" ]; then
    install_compose
fi

if ! command -v docker >/dev/null 2>&1; then
    fatal "The Docker CLI was not installed from the Docker static archive."
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

SOURCE_SOCKET="${SOCKET_PATH}"
TARGET_SOCKET="/var/run/docker.sock"
REMOTE_USERNAME="${USERNAME}"
SOCAT_PID_FILE="/tmp/devcontainer-docker-socat.pid"
SOCAT_LOG_FILE="/tmp/devcontainer-docker-socat.log"

run_as_root() {
    if [ "\$(id -u)" -eq 0 ]; then
        "\$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "\$@"
    else
        echo "(!) Root access is required to configure the forwarded Docker socket." >&2
        return 1
    fi
}

if [ ! -S "\${SOURCE_SOCKET}" ]; then
    echo "(!) Host Docker socket not found at \${SOURCE_SOCKET}. Docker CLI commands will not connect." >&2
    exec "\$@"
fi

run_as_root mkdir -p "\$(dirname "\${TARGET_SOCKET}")"
if [ "\${SOURCE_SOCKET}" = "\${TARGET_SOCKET}" ] || [ "\${REMOTE_USERNAME}" = "root" ]; then
    if [ "\${SOURCE_SOCKET}" != "\${TARGET_SOCKET}" ]; then
        run_as_root rm -f "\${TARGET_SOCKET}"
        run_as_root ln -s "\${SOURCE_SOCKET}" "\${TARGET_SOCKET}"
    fi
else
    socket_gid="\$(stat -c '%g' "\${SOURCE_SOCKET}")"
    socket_group="\$(getent group "\${socket_gid}" | cut -d: -f1 || true)"

    if [ "\${socket_gid}" != "0" ]; then
        if [ -n "\${socket_group}" ]; then
            run_as_root usermod -aG "\${socket_group}" "\${REMOTE_USERNAME}"
        else
            run_as_root groupmod --gid "\${socket_gid}" docker
        fi
        run_as_root rm -f "\${TARGET_SOCKET}"
        run_as_root ln -s "\${SOURCE_SOCKET}" "\${TARGET_SOCKET}"
    else
        run_as_root rm -f "\${TARGET_SOCKET}"
        if [ -f "\${SOCAT_PID_FILE}" ] && run_as_root kill -0 "\$(cat "\${SOCAT_PID_FILE}")" >/dev/null 2>&1; then
            :
        else
            run_as_root sh -c "nohup socat UNIX-LISTEN:'\${TARGET_SOCKET}',fork,mode=660,user='\${REMOTE_USERNAME}',group=docker,backlog=128 UNIX-CONNECT:'\${SOURCE_SOCKET}' >>'\${SOCAT_LOG_FILE}' 2>&1 & echo \$! >'\${SOCAT_PID_FILE}'"
        fi
    fi
fi

exec "\$@"
EOF

chmod +x /usr/local/share/docker-init.sh
clean_packages
log "Docker-outside-of-Docker installation complete."
