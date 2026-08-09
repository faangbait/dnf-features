ARG BASE_IMAGE=registry.access.redhat.com/ubi10/ubi:latest
FROM ${BASE_IMAGE}

ARG EXPECTED_PACKAGE_MANAGER

COPY src/secure-containers /tmp/secure-containers

RUN bash /tmp/secure-containers/install.sh

RUN command -v "${EXPECTED_PACKAGE_MANAGER}" \
    && docker --version \
    && dockerd --version \
    && rootlesskit --version \
    && slirp4netns --version \
    && docker buildx version \
    && docker compose version \
    && test -x /usr/local/share/secure-containers-init.sh \
    && grep -Fq 'ROOTLESS_UID="$(id -u "${ROOTLESS_USER}")"' /usr/local/share/secure-containers-init.sh \
    && grep -q '^securecontainers:' /etc/subuid \
    && grep -q '^securecontainers:' /etc/subgid
