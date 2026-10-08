#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — Chroot Configuration Script (M3.5 & M7 - M13)
# To be executed INSIDE the chroot (or via: sudo ./scripts/chroot.sh /root/configure.sh)
# ==============================================================================
set -Eeuo pipefail

export HOME=/root
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

# Find configuration directory
CONFIG_DIR="/root/config"
if [[ ! -d "${CONFIG_DIR}" ]]; then
    if [[ -d "/etc/sable/config" ]]; then
        CONFIG_DIR="/etc/sable/config"
    else
        echo "Error: Configuration directory not found at /root/config or /etc/sable/config"
        exit 1
    fi
fi

# Source global configuration
# shellcheck source=/dev/null
source "${CONFIG_DIR}/sable.conf"

if [[ -f "${CONFIG_DIR}/base/system.conf" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_DIR}/base/system.conf"
fi

if [[ -f "${CONFIG_DIR}/base/services.conf" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_DIR}/base/services.conf"
fi

echo "=========================================================="
echo " Configuring ${SABLE_NAME} (${SABLE_VERSION} '${SABLE_CODENAME}')"
echo " Profile: ${SABLE_PROFILE}"
echo "=========================================================="

echo "--> [Step 1] Updating Debian base repository index..."
apt-get update
apt-get upgrade -y

echo "--> [Step 2] Reading package lists and installing software..."
BASE_PKGS=()
if [[ -f "${CONFIG_DIR}/base/packages.list" ]]; then
    while IFS= read -r pkg || [[ -n "$pkg" ]]; do
        # Ignore comments and blank lines
        pkg="$(echo "$pkg" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        if [[ -n "$pkg" ]]; then
            BASE_PKGS+=("$pkg")
        fi
    done < "${CONFIG_DIR}/base/packages.list"
fi

if [[ ${#BASE_PKGS[@]} -gt 0 ]]; then
    echo "Installing base packages: ${BASE_PKGS[*]}"
    apt-get install -y --no-install-recommends "${BASE_PKGS[@]}"
fi

echo "--> [Step 3] Configuring Hostname and Network Hosts..."
HOSTNAME="${SABLE_DEFAULT_HOSTNAME:-sable}"
echo "${HOSTNAME}" > /etc/hostname

cat << EOF > /etc/hosts
127.0.0.1       localhost
127.0.1.1       ${HOSTNAME}

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

echo "--> [Step 4] Applying Sable Identity to /etc/os-release..."
cat << EOF > /etc/os-release
NAME="${SABLE_NAME}"
PRETTY_NAME="${SABLE_NAME} ${SABLE_VERSION} (${SABLE_CODENAME})"
ID=${SABLE_ID}
ID_LIKE=debian
VERSION_ID="${SABLE_VERSION}"
VERSION_CODENAME="${SABLE_CODENAME}"
HOME_URL="${SABLE_URL}"
SUPPORT_URL="${SABLE_SUPPORT_URL}"
BUG_REPORT_URL="${SABLE_BUG_REPORT_URL}"
EOF

echo "--> [Step 5] Setting up /etc/sable/ dedicated namespace..."
mkdir -p /etc/sable
echo "${SABLE_NAME}" > /etc/sable/release
echo "${SABLE_VERSION}" > /etc/sable/version
echo "${SABLE_CODENAME}" > /etc/sable/codename

cat << EOF > /etc/sable/build-info
BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
BUILD_HOST="$(hostname)"
BUILD_PROFILE="${SABLE_PROFILE}"
UPSTREAM_SUITE="${DEBIAN_SUITE}"
ARCH="${DEBIAN_ARCH}"
EOF

# Copy installed system configuration into /etc/sable/
cp -a "${CONFIG_DIR}/." /etc/sable/config/ 2>/dev/null || true

echo "--> [Step 6] Configuring Sable MOTD..."
cat << 'EOF' > /etc/motd

   _____     _     _      
  / ____|   | |   | |     
 | (___  ___| |__ | | ___ 
  \___ \/ __| '_ \| |/ _ \
  ____) \__ \ |_) | |  __/
 |_____/|___/_.__/|_|\___|

 Sable Linux 0.1.0 "Nightfall"

 Welcome to Sable.

EOF

echo "--> [Step 7] Managing Services..."
if [[ -n "${ENABLED_SERVICES:-}" ]]; then
    for srv in "${ENABLED_SERVICES[@]}"; do
        if systemctl list-unit-files "${srv}.service" >/dev/null 2>&1; then
            echo "  Enabling service: ${srv}"
            systemctl enable "${srv}" || true
        fi
    done
fi

if [[ -n "${DISABLED_SERVICES:-}" ]]; then
    for srv in "${DISABLED_SERVICES[@]}"; do
        if systemctl list-unit-files "${srv}.service" >/dev/null 2>&1; then
            echo "  Disabling service: ${srv}"
            systemctl disable "${srv}" || true
        fi
    done
fi

echo "--> [Step 8] Configuring Default User..."
USER_NAME="${SABLE_DEFAULT_USER:-sable}"
if ! id "${USER_NAME}" >/dev/null 2>&1; then
    useradd -m -s "${SABLE_SHELL:-/bin/bash}" "${USER_NAME}"
    echo "${USER_NAME}:${USER_NAME}" | chpasswd
    usermod -aG sudo "${USER_NAME}"
    echo "User '${USER_NAME}' created with password '${USER_NAME}' and sudo privileges."
else
    echo "User '${USER_NAME}' already exists."
fi

echo "=========================================================="
echo " Sable Linux configuration completed successfully!"
echo "=========================================================="
