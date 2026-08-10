#!/usr/bin/env bash
#-------------------------------------------------------------------------------------------------------------
# Portions of this code are Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#-------------------------------------------------------------------------------------------------------------

set -e

VERSION=${VERSION:-"latest"}
VERBOSE=${VERBOSE:-"true"}
SESSIONMAN=${SESSIONMAN:-"false"}

AWSCLI_GPG_KEY_MATERIAL="-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBF2Cr7UBEADJZHcgusOJl7ENSyumXh85z0TRV0xJorM2B/JL0kHOyigQluUG
ZMLhENaG0bYatdrKP+3H91lvK050pXwnO/R7fB/FSTouki4ciIx5OuLlnJZIxSzx
PqGl0mkxImLNbGWoi6Lto0LYxqHN2iQtzlwTVmq9733zd3XfcXrZ3+LblHAgEt5G
TfNxEKJ8soPLyWmwDH6HWCnjZ/aIQRBTIQ05uVeEoYxSh6wOai7ss/KveoSNBbYz
gbdzoqI2Y8cgH2nbfgp3DSasaLZEdCSsIsK1u05CinE7k2qZ7KgKAUIcT/cR/grk
C6VwsnDU0OUCideXcQ8WeHutqvgZH1JgKDbznoIzeQHJD238GEu+eKhRHcz8/jeG
94zkcgJOz3KbZGYMiTh277Fvj9zzvZsbMBCedV1BTg3TqgvdX4bdkhf5cH+7NtWO
lrFj6UwAsGukBTAOxC0l/dnSmZhJ7Z1KmEWilro/gOrjtOxqRQutlIqG22TaqoPG
fYVN+en3Zwbt97kcgZDwqbuykNt64oZWc4XKCa3mprEGC3IbJTBFqglXmZ7l9ywG
EEUJYOlb2XrSuPWml39beWdKM8kzr1OjnlOm6+lpTRCBfo0wa9F8YZRhHPAkwKkX
XDeOGpWRj4ohOx0d2GWkyV5xyN14p2tQOCdOODmz80yUTgRpPVQUtOEhXQARAQAB
tCFBV1MgQ0xJIFRlYW0gPGF3cy1jbGlAYW1hem9uLmNvbT6JAlQEEwEIAD4CGwMF
CwkIBwIGFQoJCAsCBBYCAwECHgECF4AWIQT7Xbd/1cEYuAURraimMQrMRnJHXAUC
akV0ygUJDqP4lQAKCRCmMQrMRnJHXFHjD/9eyZLYcKuQOlLvtqSDtUBiEZf6ZZjM
i3ygYH8rJNtuToUH+HvSpe819urJCquXhDrlK6N+aqW0hCLtNABJG/vsafIgvIYJ
hSGgpgtNnQyMV1jViRWqPjbouw8OkYKBThUfT1i2Y+wn58ifs6ODBCmTexWtXspA
Si+Gt49xDOW0APmbOPnI+a4HJW6tVEo6MWS0WjzpiBayR3d1A4pt4YrPfSdDgpLo
h2SLQqlRqvvVZJaWBjhkErNFpfsBA06sDcPEOb0G8LBUbR4WOcdvhe5LubJbZuxC
AG9kNPCVeQP1ixwjgjXKysaxeQ6rv0VzIQgRp6tLVLWhy6AKDNvLjFSsmXZ1Wl08
Y/RlOHXlzLuQMRE6sR1wOdRxc9TsrNWTGiBK65cvSWOy03JeBkQQ8pesqltiyxI9
U21kkgiXtTSKNGfKK8pO27D81YANhRqPK7iTp6kuFiY2WtOg90KTMNlIT+Ff85Y2
b1rHj6Z0SrCkJujhWk3IBPic/wJgz01LEc/OAdUPlby90RJZcIBhSlWhT7mXnXIO
c0HWlNQrns2s3CTyYwZSiSlYe9ApeLwhjDo8NhbFuCAy61l6O5UsR4AfZxx/rGKv
2wFb1/RN/P4gNe6vmxZAPjR0AQcwD3tc2McimOLr/22kmPz8IH3I0X7WoSFr0Biz
E91G7bb0hOb/cA==
=knv7
-----END PGP PUBLIC KEY BLOCK-----"

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi


# Debian / Ubuntu packages
install_debian_packages() {
    # Ensure apt is in non-interactive to avoid prompts
    export DEBIAN_FRONTEND=noninteractive

    local package_list=(curl ca-certificates gpg dirmngr unzip bash-completion less)
    if [ "${SESSIONMAN}" = "true" ]; then
        package_list+=(cpio rpm2cpio)
    fi
    local missing_packages=()
    local package
    for package in "${package_list[@]}"; do
        if ! dpkg-query -W -f='${db:Status-Abbrev}\n' "${package}" 2>/dev/null | grep -q '^ii'; then
            missing_packages+=("${package}")
        fi
    done

    # Install the list of missing packages
    if [ "${#missing_packages[@]}" -gt 0 ]; then
        echo "Packages to verify are installed: ${missing_packages[*]}"
        rm -rf /var/lib/apt/lists/*
        apt-get update -y
        apt-get -y install --no-install-recommends "${missing_packages[@]}" 2> >(grep -v 'debconf: delaying package configuration, since apt-utils is not installed' >&2)
    fi

    # Clean up
    apt-get -y clean
    rm -rf /var/lib/apt/lists/*
}

# RedHat / RockyLinux / CentOS / Fedora packages
install_redhat_packages() {
    local install_cmd=microdnf
    if type microdnf > /dev/null 2>&1; then
       install_cmd=microdnf
    elif type tdnf > /dev/null 2>&1; then
       install_cmd=tdnf
    elif type dnf > /dev/null 2>&1; then
       install_cmd=dnf
    elif type yum > /dev/null 2>&1; then
       install_cmd=yum
    else
       echo "Unable to find 'tdnf', 'dnf', or 'yum' package manager. Exiting."
       exit 1
    fi
    
    local package_list=(curl ca-certificates gpg dirmngr unzip bash-completion less)
    if [ "${SESSIONMAN}" = "true" ]; then
        package_list+=(cpio rpm)
    fi
    local missing_packages=()
    local package
    for package in "${package_list[@]}"; do
        if ! rpm -q "${package}" >/dev/null 2>&1; then
            missing_packages+=("${package}")
        fi
    done

    if [ "${#missing_packages[@]}" -gt 0 ]; then
        echo "Packages to verify are installed: ${missing_packages[*]}"
        echo "Running ${install_cmd} install..."
        if [ "${install_cmd}" = "dnf" ]; then
            "${install_cmd}" -y install --allowerasing "${missing_packages[@]}"
        else
            "${install_cmd}" -y install "${missing_packages[@]}"
        fi
    fi


}

# Alpine Linux packages
install_alpine_packages() {
    apk update
    local package_list=(curl ca-certificates gnupg unzip bash-completion less)
    if [ "${SESSIONMAN}" = "true" ]; then
        package_list+=(cpio rpm)
    fi
    local missing_packages=()
    local package
    for package in "${package_list[@]}"; do
        if ! apk info -e "${package}" >/dev/null 2>&1; then
            missing_packages+=("${package}")
        fi
    done
    if [ "${#missing_packages[@]}" -gt 0 ]; then
        apk add --no-cache "${missing_packages[@]}"
    fi
}

(
    # Bring in ID, ID_LIKE, VERSION_ID, VERSION_CODENAME
    . /etc/os-release
    # Get an adjusted ID independent of distro variants
    if [ "${ID}" = "debian" ] || [ "${ID_LIKE}" = "debian" ]; then
        ADJUSTED_ID="debian"
    elif [[ "${ID}" = "rhel" || "${ID}" = "fedora" || "${ID}" = "azurelinux" || "${ID}" = "mariner" || "${ID_LIKE}" = *"rhel"* || "${ID_LIKE}" = *"fedora"* || "${ID_LIKE}" = *"mariner"* ]]; then
        ADJUSTED_ID="rhel"
        VERSION_CODENAME="${ID}${VERSION_ID}"
    elif [ "${ID}" = "alpine" ]; then
        ADJUSTED_ID="alpine"
    else
        echo "Linux distro ${ID} not supported."
        exit 1
    fi

    if [ "${ADJUSTED_ID}" = "rhel" ] && [ "${VERSION_CODENAME-}" = "centos7" ]; then
        # As of 1 July 2024, mirrorlist.centos.org no longer exists.
        # Update the repo files to reference vault.centos.org.
        sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
        sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo
        sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo
    fi

    # Install packages for appropriate OS
    case "${ADJUSTED_ID}" in
        "debian")
            install_debian_packages
            ;;
        "rhel")
            install_redhat_packages
            ;;
        "alpine")
            install_alpine_packages
            ;;
    esac
)

verify_aws_cli_gpg_signature() {
    local filePath=$1
    local sigFilePath=$2
    local awsGpgKeyring=aws-cli-public-key.gpg

    echo "${AWSCLI_GPG_KEY_MATERIAL}" | gpg --dearmor > "./${awsGpgKeyring}"
    gpg --batch --quiet --no-default-keyring --keyring "./${awsGpgKeyring}" --verify "${sigFilePath}" "${filePath}"
    local status=$?

    rm "./${awsGpgKeyring}"

    return ${status}
}

install() {
    local scriptZipFile=awscli.zip
    local scriptSigFile=awscli.sig

    # See Linux install docs at https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
    if [ "${VERSION}" != "latest" ]; then
        local versionStr=-${VERSION}
    fi
    # Detect architecture without relying on dpkg (works on Alpine and non-debian systems)
    arch=$(uname -m)
    case "${arch}" in
        x86_64|amd64) architectureStr=x86_64 ;;
        aarch64|arm64) architectureStr=aarch64 ;;
        *)
            echo "AWS CLI does not support machine architecture '${arch}'. Please use an x86-64 or ARM64 machine."
            exit 1
    esac
    local scriptUrl=https://awscli.amazonaws.com/awscli-exe-linux-${architectureStr}${versionStr}.zip
    curl -fsSL "${scriptUrl}" -o "${scriptZipFile}"
    curl -fsSL "${scriptUrl}.sig" -o "${scriptSigFile}"

    if ! verify_aws_cli_gpg_signature "$scriptZipFile" "$scriptSigFile"; then
        echo "Could not verify GPG signature of AWS CLI install script. Make sure you provided a valid version."
        exit 1
    fi

    if [ "${VERBOSE}" = "false" ]; then
        unzip -q "${scriptZipFile}"
    else
        unzip "${scriptZipFile}"
    fi
    
    ./aws/install

    # AWS bash completion
    mkdir -p /etc/bash_completion.d
    cp ./scripts/vendor/aws_bash_completer /etc/bash_completion.d/aws

    # AWS zsh completion
    mkdir -p /usr/local/share/zsh/site-functions/
    cp ./scripts/vendor/aws_zsh_completer.sh /usr/local/share/zsh/site-functions/_aws
    sed -i '1s/^/#compdef aws\n/' /usr/local/share/zsh/site-functions/_aws

    rm -rf ./aws
}

install_session_manager_plugin() {
    local pluginRpm="session-manager-plugin.rpm"
    local extractDir
    extractDir=$(mktemp -d)

    curl -fsSL \
        https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm \
        -o "${pluginRpm}"

    rpm2cpio "${pluginRpm}" | (cd "${extractDir}" && cpio -id --quiet)
    command install -m 0755 \
        "${extractDir}/usr/local/sessionmanagerplugin/bin/session-manager-plugin" \
        /usr/local/bin/session-manager-plugin

    rm -rf "${extractDir}" "${pluginRpm}"
}

echo "(*) Installing AWS CLI..."

install

if [ "${SESSIONMAN}" = "true" ]; then
    echo "(*) Installing AWS Session Manager plugin..."
    install_session_manager_plugin
fi

echo "Done!"
