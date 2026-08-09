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
    fatal "The moby option is not supported on UBI/RHEL 10 because Moby RPMs are unavailable. Use the default static Docker release."
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
                break
            fi
        done
        if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
            USERNAME="$(awk -F: '$3 == 1000 { print $1; exit }' /etc/passwd)"
            USERNAME="${USERNAME:-root}"
        fi
    elif [ "${USERNAME}" = "none" ] || ! id "${USERNAME}" >/dev/null 2>&1; then
        USERNAME="root"
    fi

    # Rootless Docker cannot run as root. Root-based images therefore get a dedicated daemon user.
    if [ "${USERNAME}" = "root" ]; then
        USERNAME="securecontainers"
        if ! id "${USERNAME}" >/dev/null 2>&1; then
            useradd --create-home --shell /bin/bash "${USERNAME}"
        fi
    fi

    ROOTLESS_UID="$(id -u "${USERNAME}")"
    ROOTLESS_GID="$(id -g "${USERNAME}")"
    ROOTLESS_HOME="$(getent passwd "${USERNAME}" | cut -d: -f6)"
    [ -n "${ROOTLESS_HOME}" ] || fatal "Could not resolve the home directory for ${USERNAME}."
}

ensure_subordinate_ids() {
    touch /etc/subuid /etc/subgid
    if ! grep -qE "^${USERNAME}:" /etc/subuid; then
        echo "${USERNAME}:100000:65536" >> /etc/subuid
    fi
    if ! grep -qE "^${USERNAME}:" /etc/subgid; then
        echo "${USERNAME}:100000:65536" >> /etc/subgid
    fi
}

resolve_architecture() {
    case "$(uname -m)" in
        x86_64 | amd64)
            DOCKER_ARCH="x86_64"
            BUILDX_ARCH="amd64"
            COMPOSE_ARCH="x86_64"
            SLIRP_ARCH="x86_64"
            ;;
        aarch64 | arm64)
            DOCKER_ARCH="aarch64"
            BUILDX_ARCH="arm64"
            COMPOSE_ARCH="aarch64"
            SLIRP_ARCH="aarch64"
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

install_docker_binaries() {
    local archive="${TEMP_DIR}/docker.tgz"
    local url="https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-${RESOLVED_DOCKER_VERSION}.tgz"
    log "Installing Docker ${RESOLVED_DOCKER_VERSION} static binaries from ${url}"
    curl -fsSL "${url}" -o "${archive}"
    tar -xzf "${archive}" --strip-components=1 -C /usr/local/bin
}

install_rootless_extras() {
    local archive="${TEMP_DIR}/docker-rootless-extras.tgz"
    local url="https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-rootless-extras-${RESOLVED_DOCKER_VERSION}.tgz"
    log "Installing Docker rootless extras ${RESOLVED_DOCKER_VERSION} from ${url}"
    curl -fsSL "${url}" -o "${archive}"
    tar -xzf "${archive}" --strip-components=1 -C /usr/local/bin
}

install_slirp4netns() {
    local tag version
    tag="$(latest_release_tag rootless-containers/slirp4netns)"
    version="${tag#v}"
    log "Installing slirp4netns ${version} static binary"
    curl -fsSL "https://github.com/rootless-containers/slirp4netns/releases/download/v${version}/slirp4netns-${SLIRP_ARCH}" -o /usr/local/bin/slirp4netns
    chmod +x /usr/local/bin/slirp4netns
}

install_buildx() {
    local version="${BUILDX_VERSION#v}"
    if [ "${version}" = "latest" ]; then
        version="$(latest_release_tag docker/buildx)"
        version="${version#v}"
    fi
    [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] || fatal "Invalid Buildx version: ${BUILDX_VERSION}."
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fsSL "https://github.com/docker/buildx/releases/download/v${version}/buildx-v${version}.linux-${BUILDX_ARCH}" -o /usr/local/lib/docker/cli-plugins/docker-buildx
    chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx
}

install_compose() {
    local tag version
    tag="$(latest_release_tag docker/compose)"
    version="${tag#v}"
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fsSL "https://github.com/docker/compose/releases/download/v${version}/docker-compose-linux-${COMPOSE_ARCH}" -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
}

install_packages ca-certificates curl gzip iproute nftables procps-ng shadow-utils sudo tar util-linux
resolve_user
ensure_subordinate_ids
resolve_architecture
resolve_docker_version

if [ "${RESOLVED_DOCKER_VERSION%%.*}" -lt 29 ]; then
    fatal "Secure rootless Docker on UBI 10 requires Docker 29 or newer for the nftables firewall backend."
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT
install_docker_binaries
install_rootless_extras
install_slirp4netns

if [ "${INSTALL_BUILDX}" = "true" ]; then
    install_buildx
fi
if [ "${COMPOSE_VERSION}" != "none" ]; then
    install_compose
fi

if [ "${INSTALL_COMPOSE_SWITCH}" = "true" ] && [ "${COMPOSE_VERSION}" != "none" ]; then
    cat > /usr/local/bin/docker-compose <<'EOF'
#!/usr/bin/env bash
exec docker compose "$@"
EOF
    chmod +x /usr/local/bin/docker-compose
fi

for command_name in docker dockerd rootlesskit slirp4netns newuidmap newgidmap; do
    command -v "${command_name}" >/dev/null 2>&1 || fatal "Required rootless command ${command_name} was not installed."
done

mkdir -p /usr/local/share /run/secure-containers

cat > /usr/local/share/secure-containers-init.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail

ROOTLESS_USER="${USERNAME}"
ROOTLESS_UID="${ROOTLESS_UID}"
ROOTLESS_GID="${ROOTLESS_GID}"
ROOTLESS_HOME="${ROOTLESS_HOME}"
RUNTIME_DIR="/run/user/${ROOTLESS_UID}"
DATA_ROOT="/var/lib/secure-containers"
SOCKET="\${RUNTIME_DIR}/docker.sock"
PUBLIC_SOCKET="/run/secure-containers/docker.sock"
LOG_FILE="/tmp/secure-containers-dockerd.log"

if [ "\$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
        exec sudo -E /usr/local/share/secure-containers-init.sh "\$@"
    fi
    echo "(!) secure-containers must initialize as root so it can create its private TUN node and then drop privileges." >&2
    exit 1
fi

if [ -f /proc/sys/kernel/unprivileged_userns_clone ] && [ "\$(cat /proc/sys/kernel/unprivileged_userns_clone)" != "1" ]; then
    echo "(!) Rootless Docker requires kernel.unprivileged_userns_clone=1 on the container host." >&2
    exit 1
fi
if [ -f /proc/sys/user/max_user_namespaces ] && [ "\$(cat /proc/sys/user/max_user_namespaces)" = "0" ]; then
    echo "(!) Rootless Docker requires user.max_user_namespaces to be greater than zero on the container host." >&2
    exit 1
fi

mkdir -p /dev/net "\${RUNTIME_DIR}" "\${DATA_ROOT}" /run/secure-containers
if [ ! -e /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi
chmod 0666 /dev/net/tun
chown "\${ROOTLESS_UID}:\${ROOTLESS_GID}" "\${RUNTIME_DIR}" "\${DATA_ROOT}"
chmod 0700 "\${RUNTIME_DIR}"
rm -f "\${SOCKET}" "\${PUBLIC_SOCKET}"
ln -s "\${SOCKET}" "\${PUBLIC_SOCKET}"

daemon_args=(
    rootlesskit
    --net=slirp4netns
    --mtu=1500
    --disable-host-loopback
    --port-driver=builtin
    --copy-up=/etc
    --copy-up=/run
    dockerd
    --host="unix://\${SOCKET}"
    --data-root="\${DATA_ROOT}"
    --firewall-backend=nftables
)

nohup runuser -u "\${ROOTLESS_USER}" -- env \
    HOME="\${ROOTLESS_HOME}" \
    XDG_RUNTIME_DIR="\${RUNTIME_DIR}" \
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    "\${daemon_args[@]}" >"\${LOG_FILE}" 2>&1 &
daemon_pid=\$!

docker_ready=false
for _ in {1..120}; do
    if DOCKER_HOST="unix://\${PUBLIC_SOCKET}" docker info >/dev/null 2>&1; then
        docker_ready=true
        break
    fi
    if ! kill -0 "\${daemon_pid}" >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

if [ "\${docker_ready}" != "true" ]; then
    echo "(!) Rootless Docker daemon did not become ready. \${LOG_FILE} follows:" >&2
    tail -n 100 "\${LOG_FILE}" >&2 || true
    exit 1
fi

exec "\$@"
EOF

chmod +x /usr/local/share/secure-containers-init.sh
clean_packages
log "Secure rootless Docker installation complete for user ${USERNAME}."
