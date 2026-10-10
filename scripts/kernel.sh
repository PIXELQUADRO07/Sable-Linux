#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — Kernel Installation (Milestone 9)
# Can be run from host: sudo ./scripts/kernel.sh
# Or inside chroot:     /root/kernel.sh
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ROOTFS="${PROJECT_ROOT}/rootfs"

install_kernel_in_chroot() {
    export HOME=/root
    export LC_ALL=C
    export DEBIAN_FRONTEND=noninteractive

    echo "=========================================================="
    echo " [Cybersecurity/Performance] Installing Liquorix Kernel..."
    echo "=========================================================="
    apt-get update
    apt-get install -y --no-install-recommends curl wget gnupg ca-certificates || true

    if curl -s 'https://liquorix.net/install-liquorix.sh' | bash -s -- --yes; then
        echo "Liquorix kernel installed successfully."
    else
        echo "Warning: Liquorix install script failed or offline. Falling back to standard Debian kernel..."
        apt-get install -y --no-install-recommends linux-image-amd64 initramfs-tools
    fi

    echo
    echo "Kernel successfully installed in /boot:"
    ls -lh /boot/vmlinuz* /boot/initrd.img* 2>/dev/null || true
    echo "=========================================================="
}

if [[ -f "/etc/sable/release" ]]; then
    # We are already inside the chroot
    install_kernel_in_chroot
else
    # We are on the host system
    if [[ "${EUID}" -ne 0 ]]; then
        echo "Error: This script must be run with sudo:"
        echo "  sudo $0"
        exit 1
    fi

    echo "Invoking kernel installation inside Sable chroot..."
    mkdir -p "${ROOTFS}/root"
    cp "${BASH_SOURCE[0]}" "${ROOTFS}/root/kernel.sh"
    chmod +x "${ROOTFS}/root/kernel.sh"

    "${SCRIPT_DIR}/chroot.sh" /root/kernel.sh
fi
