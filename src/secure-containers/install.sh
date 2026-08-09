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

}

ensure_subordinate_ids() {
    touch /etc/subuid /etc/subgid
    ensure_subordinate_id_file /etc/subuid
    ensure_subordinate_id_file /etc/subgid
}

ensure_subordinate_id_file() {
    local file="$1"
    local candidate=100000
    local candidate_end existing_start existing_count existing_end
    local overlap

    awk -F: -v username="${USERNAME}" '$1 == username { found=1 } END { exit !found }' "${file}" && return

    while true; do
        candidate_end=$((candidate + 65536 - 1))
        overlap="false"
        while IFS=: read -r _ existing_start existing_count _; do
            [[ "${existing_start}" =~ ^[0-9]+$ && "${existing_count}" =~ ^[0-9]+$ ]] || continue
            existing_end=$((existing_start + existing_count - 1))
            if [ "${candidate}" -le "${existing_end}" ] && [ "${candidate_end}" -ge "${existing_start}" ]; then
                candidate=$((existing_end + 1))
                overlap="true"
                break
            fi
        done < "${file}"
        [ "${overlap}" = "true" ] || break
    done

    printf '%s:%s:65536\n' "${USERNAME}" "${candidate}" >> "${file}"
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
    local index engine_versions rootless_versions versions requested version
    index="$(curl -fsSL "${index_url}")"
    engine_versions="$(printf '%s' "${index}" | grep -oE 'docker-[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?\.tgz' | sed -E 's/^docker-//; s/\.tgz$//' | sort -Vu)"
    rootless_versions="$(printf '%s' "${index}" | grep -oE 'docker-rootless-extras-[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?\.tgz' | sed -E 's/^docker-rootless-extras-//; s/\.tgz$//' | sort -Vu)"
    versions="$(
        while IFS= read -r version; do
            grep -Fxq "${version}" <<< "${rootless_versions}" && printf '%s\n' "${version}"
        done <<< "${engine_versions}"
    )"
    [ -n "${versions}" ] || fatal "Could not discover matching Docker Engine and rootless-extras versions from ${index_url}."

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

install_rootless_extras() {
    local archive="${TEMP_DIR}/docker-rootless-extras.tgz"
    local url="https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-rootless-extras-${RESOLVED_DOCKER_VERSION}.tgz"
    log "Installing Docker rootless extras ${RESOLVED_DOCKER_VERSION} from ${url}"
    curl -fsSL "${url}" -o "${archive}"
    tar -xzf "${archive}" --strip-components=1 -C /usr/local/bin
}

install_slirp4netns() {
    local tag version asset_name
    local destination="/usr/local/bin/slirp4netns"
    tag="$(latest_release_tag rootless-containers/slirp4netns)"
    version="${tag#v}"
    asset_name="slirp4netns-${SLIRP_ARCH}"
    log "Installing slirp4netns ${version} static binary"
    curl -fsSL "https://github.com/rootless-containers/slirp4netns/releases/download/v${version}/${asset_name}" -o "${destination}"
    verify_release_checksum "${destination}" "https://github.com/rootless-containers/slirp4netns/releases/download/v${version}/SHA256SUMS" "${asset_name}"
    chmod +x "${destination}"
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
ROOTLESS_UID="\$(id -u "\${ROOTLESS_USER}")"
ROOTLESS_GID="\$(id -g "\${ROOTLESS_USER}")"
ROOTLESS_HOME="\$(getent passwd "\${ROOTLESS_USER}" | cut -d: -f6)"
[ -n "\${ROOTLESS_HOME}" ] || {
    echo "(!) Could not resolve the home directory for \${ROOTLESS_USER}." >&2
    exit 1
}
RUNTIME_DIR="/run/user/\${ROOTLESS_UID}"
DATA_ROOT="/var/lib/secure-containers"
SOCKET="\${RUNTIME_DIR}/docker.sock"
PUBLIC_SOCKET="/run/secure-containers/docker.sock"
LOG_FILE="/tmp/secure-containers-dockerd.log"
PREPARE_ARGUMENT="__secure_containers_prepare"

prepare_runtime() {
    mkdir -p /dev/net "\${RUNTIME_DIR}" "\${DATA_ROOT}" /run/secure-containers
    if [ ! -e /dev/net/tun ]; then
        mknod /dev/net/tun c 10 200
    fi
    chmod 0666 /dev/net/tun
    chown "\${ROOTLESS_UID}:\${ROOTLESS_GID}" "\${RUNTIME_DIR}" "\${DATA_ROOT}"
    chmod 0700 "\${RUNTIME_DIR}"
    rm -f "\${SOCKET}" "\${PUBLIC_SOCKET}"
    ln -s "\${SOCKET}" "\${PUBLIC_SOCKET}"
}

if [ "\${1:-}" = "\${PREPARE_ARGUMENT}" ]; then
    if [ "\$(id -u)" -ne 0 ]; then
        echo "(!) secure-containers runtime preparation must run as root." >&2
        exit 1
    fi
    prepare_runtime
    exit 0
fi

if [ -f /proc/sys/kernel/unprivileged_userns_clone ] && [ "\$(cat /proc/sys/kernel/unprivileged_userns_clone)" != "1" ]; then
    echo "(!) Rootless Docker requires kernel.unprivileged_userns_clone=1 on the container host." >&2
    exit 1
fi
if [ -f /proc/sys/user/max_user_namespaces ] && [ "\$(cat /proc/sys/user/max_user_namespaces)" = "0" ]; then
    echo "(!) Rootless Docker requires user.max_user_namespaces to be greater than zero on the container host." >&2
    exit 1
fi

if [ "\$(id -u)" -eq 0 ]; then
    prepare_runtime
elif [ "\$(id -u)" -eq "\${ROOTLESS_UID}" ] && command -v sudo >/dev/null 2>&1; then
    sudo -n /usr/local/share/secure-containers-init.sh "\${PREPARE_ARGUMENT}"
else
    echo "(!) secure-containers must start as root or as \${ROOTLESS_USER} with permission to prepare its private runtime paths." >&2
    exit 1
fi

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

if [ "\$(id -u)" -eq 0 ]; then
    nohup runuser -u "\${ROOTLESS_USER}" -- env \
        HOME="\${ROOTLESS_HOME}" \
        XDG_RUNTIME_DIR="\${RUNTIME_DIR}" \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        "\${daemon_args[@]}" >"\${LOG_FILE}" 2>&1 &
else
    nohup env \
        HOME="\${ROOTLESS_HOME}" \
        XDG_RUNTIME_DIR="\${RUNTIME_DIR}" \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        "\${daemon_args[@]}" >"\${LOG_FILE}" 2>&1 &
fi
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
cat > /etc/sudoers.d/secure-containers <<EOF
${USERNAME} ALL=(root) NOPASSWD: /usr/local/share/secure-containers-init.sh __secure_containers_prepare
EOF
chmod 0440 /etc/sudoers.d/secure-containers
visudo -cf /etc/sudoers.d/secure-containers >/dev/null
clean_packages
log "Secure rootless Docker installation complete for user ${USERNAME}."
