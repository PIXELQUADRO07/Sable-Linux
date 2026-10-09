#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — KDE Plasma Desktop Installation (Milestone 14)
# Can be run from host: sudo ./scripts/desktop.sh
# Or inside chroot:     /root/desktop.sh
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ROOTFS="${PROJECT_ROOT}/rootfs"

install_desktop_in_chroot() {
    export HOME=/root
    export LC_ALL=C
    export DEBIAN_FRONTEND=noninteractive

    echo "=========================================================="
    echo " [Milestone 14] Installing KDE Plasma & SDDM Desktop Suite"
    echo "=========================================================="

    CONFIG_DIR="/root/config"
    if [[ ! -d "${CONFIG_DIR}" ]]; then
        if [[ -d "/etc/sable/config" ]]; then
            CONFIG_DIR="/etc/sable/config"
        else
            CONFIG_DIR=""
        fi
    fi

    DESKTOP_LIST="${CONFIG_DIR}/desktop/packages.list"
    PKGS=()
    if [[ -n "${CONFIG_DIR}" && -f "${DESKTOP_LIST}" ]]; then
        while IFS= read -r pkg || [[ -n "$pkg" ]]; do
            pkg="$(echo "$pkg" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            if [[ -n "$pkg" ]]; then
                PKGS+=("$pkg")
            fi
        done < "${DESKTOP_LIST}"
    else
        PKGS=(kde-standard sddm pipewire pipewire-audio wireplumber xwayland libgl1-mesa-dri fonts-dejavu-core fonts-noto-core)
    fi

    echo "--> Updating APT package index..."
    apt-get update

    echo "--> Installing desktop packages: ${PKGS[*]}..."
    apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" "${PKGS[@]}"

    echo "--> Enabling SDDM display manager service..."
    systemctl enable sddm.service || true

    echo "--> Configuring SDDM defaults..."
    mkdir -p /etc/sddm.conf.d
    cat << 'EOF' > /etc/sddm.conf.d/sable.conf
[Theme]
Current=breeze

[Users]
MaximumUid=60000
MinimumUid=1000
EOF

    echo "=========================================================="
    echo " KDE Plasma & SDDM installation completed successfully!"
    echo "=========================================================="
}

if [[ -f "/etc/sable/release" ]]; then
    # Running inside chroot
    install_desktop_in_chroot
else
    # Running on host
    if [[ "${EUID}" -ne 0 ]]; then
        echo "Error: This script must be run with sudo:"
        echo "  sudo $0"
        exit 1
    fi

    echo "Invoking Desktop installation inside Sable chroot..."
    mkdir -p "${ROOTFS}/root"
    cp "${BASH_SOURCE[0]}" "${ROOTFS}/root/desktop.sh"
    chmod +x "${ROOTFS}/root/desktop.sh"

    "${SCRIPT_DIR}/chroot.sh" /root/desktop.sh
fi
