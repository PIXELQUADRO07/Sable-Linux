#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — GRUB Bootloader Packages Installation (Milestone 10)
# Can be run from host: sudo ./scripts/grub.sh
# Or inside chroot:     /root/grub.sh
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ROOTFS="${PROJECT_ROOT}/rootfs"

install_grub_in_chroot() {
    export HOME=/root
    export LC_ALL=C
    export DEBIAN_FRONTEND=noninteractive

    echo "=========================================================="
    echo " [Milestone 10] Installing GRUB Bootloader Packages"
    echo "=========================================================="
    apt-get update

    # Pre-seed debconf so grub-pc does not prompt interactively for install device
    echo "grub-pc grub-pc/install_devices select " | debconf-set-selections || true
    echo "grub-pc grub-pc/install_devices_empty boolean true" | debconf-set-selections || true

    apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
        grub-pc \
        grub-efi-amd64-bin \
        grub2-common \
        dosfstools

    echo
    echo "GRUB packages successfully installed."
    echo "=========================================================="
}

if [[ -f "/etc/sable/release" ]]; then
    # Running inside chroot
    install_grub_in_chroot
else
    # Running on host
    if [[ "${EUID}" -ne 0 ]]; then
        echo "Error: This script must be run with sudo:"
        echo "  sudo $0"
        exit 1
    fi

    echo "Invoking GRUB installation inside Sable chroot..."
    mkdir -p "${ROOTFS}/root"
    cp "${BASH_SOURCE[0]}" "${ROOTFS}/root/grub.sh"
    chmod +x "${ROOTFS}/root/grub.sh"

    "${SCRIPT_DIR}/chroot.sh" /root/grub.sh
fi
