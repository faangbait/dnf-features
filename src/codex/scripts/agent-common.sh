#!/usr/bin/env bash
#
# Shared helpers for agent-CLI dnf-features. Published Features are
# standalone OCI artifacts, so this file is copied into each agent feature's
# own directory rather than referenced across them; keep copies in sync by
# hand when editing.
#
# Callers must run under `set -euo pipefail`: the helpers below rely on
# errexit to abort on a failed npm, curl or install rather than checking each
# one, so a caller without it gets a half-installed binary instead of a
# failure. Asserted at source time.
#
# Sourcing this file installs an EXIT trap that removes every scratch
# directory the helpers created, so a caller must not install its own EXIT
# trap. Register additional scratch directories with new_scratch_dir.
#
# Test idiom: [[ ]] only where bash pattern or regex matching requires it,
# [ ] for every file, string and arithmetic test.

log() {
    echo "(*) $*"
}

fatal() {
    echo "(!) $*" >&2
    exit 1
}

# The interactive case is exempt so that sourcing this file by hand to poke at
# a helper does not kill the shell.
[[ $- == *e* || $- == *i* ]] || fatal "agent-common.sh requires 'set -e'; source it from an installer that sets 'set -euo pipefail'."

# $$ is the sourcing shell's pid and stays the same inside command
# substitutions, so subshells resolve the same scratch root the parent
# registered for cleanup.
_SCRATCH_DIRS=("/tmp/.dnf-features-npm.$$")

_remove_scratch_dirs() {
    if [ "${#_SCRATCH_DIRS[@]}" -gt 0 ]; then
        rm -rf "${_SCRATCH_DIRS[@]}" 2>/dev/null || true
    fi
}

trap _remove_scratch_dirs EXIT

# Creates a scratch directory, registers it for removal at exit, and returns
# it in SCRATCH_DIR. Not a command substitution: the registry has to be
# mutated in the caller's shell, not in a subshell that discards it.
SCRATCH_DIR=""
new_scratch_dir() {
    SCRATCH_DIR="$(mktemp -d)"
    _SCRATCH_DIRS+=("${SCRATCH_DIR}")
}

require_rhel_root() {
    if [ "$(id -u)" -ne 0 ]; then
        fatal "This Feature must be installed as root."
    fi

    [ -r /etc/os-release ] || fatal "/etc/os-release is not readable; cannot identify the base image."

    # Read in subshells so os-release does not leak ID, NAME, VERSION and
    # friends into the calling installer's scope.
    local id id_like
    id="$(. /etc/os-release && printf '%s' "${ID:-}")"
    id_like="$(. /etc/os-release && printf '%s' "${ID_LIKE:-}")"

    if [[ "${id}" != "rhel" && "${id}" != "ubi" && "${id_like}" != *"rhel"* && "${id_like}" != *"fedora"* ]]; then
        fatal "This RHEL edition supports RHEL-compatible images only (detected ID=${id:-unknown})."
    fi
}

# Package manager, resolved on first use. Private: Feature options arrive as
# environment variables, so an inherited value must never be trusted as a
# command name.
_PACKAGE_MANAGER=""

detect_package_manager() {
    [ -z "${_PACKAGE_MANAGER}" ] || return 0

    local candidate
    for candidate in dnf microdnf tdnf yum; do
        if command -v "${candidate}" >/dev/null 2>&1; then
            _PACKAGE_MANAGER="${candidate}"
            return 0
        fi
    done

    fatal "Unable to find a dnf, microdnf, tdnf, or yum package manager."
}

# Installs the named rpms. No pre-filter for what is already present: the
# package managers are idempotent, so a satisfied list is a no-op, and an
# `rpm -q` filter would report any package satisfied by a provide rather than
# a literal name (coreutils via coreutils-single, for one) as permanently
# missing. Call clean_package_cache once at the end of the installer to keep
# the metadata out of the image layer.
install_redhat_packages() {
    [ "$#" -ge 1 ] || fatal "install_redhat_packages requires at least one package name."
    detect_package_manager

    log "Installing with ${_PACKAGE_MANAGER}: $*"
    if [ "${_PACKAGE_MANAGER}" = "dnf" ]; then
        dnf -y install --allowerasing "$@"
    else
        "${_PACKAGE_MANAGER}" -y install "$@"
    fi
}

# Drops the package manager's metadata cache so it does not land in the
# Feature's image layer. Call once, after the last install_redhat_packages:
# cleaning between transactions only forces a refetch. Best-effort, because a
# read-only or otherwise unremovable cache must not fail an install that
# already succeeded.
clean_package_cache() {
    detect_package_manager

    "${_PACKAGE_MANAGER}" clean all >/dev/null 2>&1 || true
    rm -rf /var/cache/dnf /var/cache/yum 2>/dev/null || true
}

# Every npm invocation goes through here. npm's tarball cache and config
# otherwise land in root's $HOME and stay in the Feature's image layer; a
# throwaway HOME also keeps the build from reading a pre-existing .npmrc.
run_npm() {
    local npm_home="/tmp/.dnf-features-npm.$$"
    mkdir -p "${npm_home}/home" "${npm_home}/cache"
    env HOME="${npm_home}/home" npm_config_cache="${npm_home}/cache" npm "$@"
}

# Writes the newest published version of a package into the named variable.
# `npm view <pkg> version` emits one line per match when the spec resolves to
# a range, so the spec is pinned to @latest and the result trimmed to one line.
#
# Takes a variable name rather than printing, so a fatal inside runs in the
# caller's shell instead of dying quietly in a command substitution.
resolve_npm_version() {
    local package="$1"
    local -n _resolved_ref="$2"

    local resolved
    resolved="$(run_npm view "${package}@latest" version | tail -n 1)"
    [ -n "${resolved}" ] || fatal "Could not resolve the newest published ${package} version from npm."

    _resolved_ref="${resolved}"
}

# Dev Container Feature options are strings, so reject anything that could
# turn an npm spec into an arbitrary install source (@file:, @git+ssh://,
# @npm:other-package). A leading v is accepted for convenience. Rewrites the
# named variable in place, for the same reason as resolve_npm_version.
normalize_npm_version() {
    local -n _version_ref="$1"

    local version="${_version_ref#v}"
    [[ "${version}" == "latest" || "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] \
        || fatal "Invalid version: ${_version_ref}. Use a semantic version such as 1.0.0, or latest."

    _version_ref="${version}"
}

_verify_binary() {
    local binary="$1"
    command -v "${binary}" >/dev/null 2>&1 \
        || fatal "Installation completed but the ${binary} command was not found on PATH."
    "${binary}" --version
}

# Installs the package and its dependency tree into npm's global prefix. Use
# this for any CLI whose bin entry point is a wrapper or needs sibling files
# from node_modules at runtime, which is most of them.
install_npm_global() {
    local package="$1" binary="$2" version="$3"

    run_npm install --global "${package}@${version}"

    _verify_binary "${binary}"
}

# npm install pulls in the package's full dependency tree. A self-contained
# bin entry point means only that one file is kept; the surrounding
# node_modules tree is discarded with the scratch prefix. Only safe for
# packages verified to ship a bundled, single-file bin with no sibling assets
# -- otherwise use install_npm_global.
install_npm_binary() {
    local package="$1" binary="$2" version="$3"
    new_scratch_dir
    local build_prefix="${SCRATCH_DIR}"

    run_npm install --global --prefix "${build_prefix}" "${package}@${version}"

    [ -f "${build_prefix}/bin/${binary}" ] || fatal "npm install did not produce ${build_prefix}/bin/${binary}."
    install -D -m 0755 "${build_prefix}/bin/${binary}" "${INSTALL_DIR:-/usr/local/bin}/${binary}"

    _verify_binary "${binary}"
}

# Some agent CLIs ship a vendor install.sh instead of an npm package. That
# installer is usually pointed at a directory via its own env var, but its
# output there is often a wrapper rather than the real standalone binary, so
# each resolved binary is read from under a scratch $HOME instead and the
# installer's own output directory is discarded along with everything else.
#
# Each mapping is "relative/path/under/HOME:finalBinaryName"; pass one per
# binary the installer produces (e.g. codex also needs codex-code-mode-host).
# The --version smoke test only runs against the first mapping, since
# companion binaries aren't necessarily user-facing CLIs. Arguments after a
# literal -- go to the vendor installer itself, e.g. a version to pin.
install_curl_binary() {
    local install_script_url="$1" install_env_var="$2"
    shift 2
    [ -n "${install_script_url}" ] || fatal "install_curl_binary requires an installer URL."
    [ -n "${install_env_var}" ] || fatal "install_curl_binary requires the installer's output-directory env var name."

    local mappings=()
    while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
        mappings+=("$1")
        shift
    done
    [ "$#" -eq 0 ] || shift
    [ "${#mappings[@]}" -ge 1 ] || fatal "install_curl_binary requires at least one relative_path:binary mapping."

    # Validate every mapping before installing packages or fetching and
    # running a remote installer, so a malformed call fails with no side
    # effects.
    local mapping
    for mapping in "${mappings[@]}"; do
        # ?*:?* demands a colon with at least one character on either side.
        [[ "${mapping}" == ?*:?* ]] \
            || fatal "Malformed mapping '${mapping}'; expected relative/path/under/HOME:finalBinaryName."
    done

    # ubi-minimal ships neither curl nor tar, and vendor installers assume both.
    install_redhat_packages curl tar gzip

    new_scratch_dir
    local build_prefix="${SCRATCH_DIR}"

    local installer="${build_prefix}/install.sh"
    curl -fsSL "${install_script_url}" -o "${installer}"
    chmod 0755 "${installer}"

    # The installer's output directory goes on PATH: a vendor installer that
    # finds its directory missing from PATH may symlink itself into a writable
    # PATH directory instead -- /usr/local/bin, as root -- leaving links into
    # this scratch tree that dangle once it is removed.
    env HOME="${build_prefix}/home" "${install_env_var}=${build_prefix}/bin" \
        PATH="${build_prefix}/bin:${PATH}" "${installer}" "$@"

    local primary_binary="" relative_path binary resolved_source
    for mapping in "${mappings[@]}"; do
        relative_path="${mapping%%:*}"
        binary="${mapping#*:}"
        resolved_source="${build_prefix}/home/${relative_path}"
        [ -f "${resolved_source}" ] || fatal "Installer did not produce ${resolved_source}."
        install -D -m 0755 "${resolved_source}" "${INSTALL_DIR:-/usr/local/bin}/${binary}"
        [ -n "${primary_binary}" ] || primary_binary="${binary}"
    done

    _verify_binary "${primary_binary}"
}
