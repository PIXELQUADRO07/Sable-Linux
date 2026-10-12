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

echo "--> [Step 6] Installing Sable Branding Assets, MOTD & fastfetch..."
mkdir -p /usr/share/sable/assets
if [[ -d "${CONFIG_DIR}/branding/assets" ]]; then
    cp -a "${CONFIG_DIR}/branding/assets/." /usr/share/sable/assets/
fi

# Install desktop system logos
mkdir -p /usr/share/icons/hicolor/scalable/apps /usr/share/pixmaps
if [[ -f "/usr/share/sable/assets/sable-paw-symbol-inverted.svg" ]]; then
    cp "/usr/share/sable/assets/sable-paw-symbol-inverted.svg" /usr/share/icons/hicolor/scalable/apps/distributor-logo.svg
    cp "/usr/share/sable/assets/sable-paw-symbol-inverted.svg" /usr/share/icons/hicolor/scalable/apps/sable-logo.svg
    cp "/usr/share/sable/assets/sable-paw-symbol-inverted.svg" /usr/share/pixmaps/sable-logo.svg
fi

# Configure /etc/motd
if [[ -f "${CONFIG_DIR}/branding/assets/ascii-paw.txt" ]]; then
    {
        cat "${CONFIG_DIR}/branding/assets/ascii-paw.txt"
        echo
        echo "  ${SABLE_NAME} ${SABLE_VERSION} \"${SABLE_CODENAME}\""
        echo "  Welcome to Sable Linux."
        echo
    } > /etc/motd
fi

# Configure fastfetch for all users
mkdir -p /etc/fastfetch /etc/skel/.config/fastfetch
cat << 'EOF' > /etc/fastfetch/config.jsonc
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "file",
    "source": "/usr/share/sable/assets/ascii-paw-small.txt",
    "color": {
      "1": "blue",
      "2": "cyan"
    },
    "width": 38,
    "padding": {
      "top": 1,
      "left": 1,
      "right": 2
    }
  },
  "modules": [
    "title",
    "separator",
    "os",
    "host",
    "kernel",
    "uptime",
    "packages",
    "shell",
    "display",
    "de",
    "wm",
    "terminal",
    "cpu",
    "gpu",
    "memory",
    "break",
    "colors"
  ]
}
EOF
cp /etc/fastfetch/config.jsonc /etc/skel/.config/fastfetch/config.jsonc

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
    chage -d 0 "${USER_NAME}" || true
    echo "User '${USER_NAME}' created with sudo privileges (password change required on first login)."
else
    echo "User '${USER_NAME}' already exists."
    chage -d 0 "${USER_NAME}" || true
fi

echo "--> [Step 9] Generating Locales..."
if command -v locale-gen >/dev/null 2>&1; then
    sed -i 's/# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen || true
    locale-gen || true
    update-locale LANG="${SABLE_DEFAULT_LOCALE:-en_US.UTF-8}" || true
fi

echo "--> [Step 10] Applying System Hardening & Cybersecurity Tool Suite..."
if [[ -f "${CONFIG_DIR}/base/hardening.conf" ]]; then
    mkdir -p /etc/sysctl.d
    cp "${CONFIG_DIR}/base/hardening.conf" /etc/sysctl.d/99-sable-hardening.conf
    chmod 644 /etc/sysctl.d/99-sable-hardening.conf
fi

PENTEST_PKGS=()
if [[ -f "${CONFIG_DIR}/tools/packages-pentest.list" ]]; then
    while IFS= read -r pkg || [[ -n "$pkg" ]]; do
        pkg="$(echo "$pkg" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        if [[ -n "$pkg" ]]; then
            PENTEST_PKGS+=("$pkg")
        fi
    done < "${CONFIG_DIR}/tools/packages-pentest.list"
fi

if [[ ${#PENTEST_PKGS[@]} -gt 0 ]]; then
    echo "Installing cybersecurity tool suite package by package..."
    for pkg in "${PENTEST_PKGS[@]}"; do
        if apt-cache show "$pkg" >/dev/null 2>&1; then
            echo "  Installing $pkg..."
            apt-get install -y --no-install-recommends "$pkg" || echo "Warning: Failed to install $pkg"
        else
            echo "  Skipping missing package: $pkg (not in repository)"
        fi
    done
fi

systemctl enable apparmor 2>/dev/null || true
systemctl enable auditd 2>/dev/null || true

echo "--> [Step 11] Applying Timezone & SSH / Security Policies..."
TIMEZONE="${SABLE_DEFAULT_TIMEZONE:-UTC}"
if [[ -f "/usr/share/zoneinfo/${TIMEZONE}" ]]; then
    ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
    echo "${TIMEZONE}" > /etc/timezone
fi

if [[ "${SABLE_ENABLE_SSH:-false}" == "true" ]]; then
    apt-get install -y --no-install-recommends openssh-server || true
    systemctl enable ssh 2>/dev/null || true
    if [[ "${SABLE_ALLOW_ROOT_LOGIN:-false}" == "true" ]]; then
        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config || true
    else
        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config || true
    fi
else
    systemctl disable ssh 2>/dev/null || true
fi

echo "=========================================================="
echo " Sable Linux configuration completed successfully!"
echo "=========================================================="
