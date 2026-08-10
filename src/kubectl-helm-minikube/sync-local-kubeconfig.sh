#!/usr/bin/env bash

set -euo pipefail

SOURCE_DIR="${KUBECONFIG_SOURCE_DIR:-/usr/local/share/kube-localhost}"
TARGET_DIR="${KUBECONFIG_TARGET_DIR:-${HOME}/.kube}"
SOURCE_CONFIG="${SOURCE_DIR}/config"
TARGET_CONFIG="${TARGET_DIR}/config"

if [ ! -f "${SOURCE_CONFIG}" ]; then
    echo "(*) No staged host kubeconfig found at ${SOURCE_CONFIG}; skipping sync."
    exit 0
fi

if [ -e "${TARGET_CONFIG}" ] || [ -L "${TARGET_CONFIG}" ]; then
    echo "(*) Container kubeconfig already exists at ${TARGET_CONFIG}; leaving it unchanged."
    exit 0
fi

umask 077
mkdir -p "${TARGET_DIR}"
cp -R "${SOURCE_DIR}/." "${TARGET_DIR}/"
chmod -R u+rwX,go-rwx "${TARGET_DIR}"

echo "(*) Copied the staged host kubeconfig to ${TARGET_CONFIG}."
