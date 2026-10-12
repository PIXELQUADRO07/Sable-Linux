#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — Hybrid Live ISO & Calamares Installer Generator
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/sable.conf"
if [[ -f "${CONFIG_FILE}" ]]; then
    source "${CONFIG_FILE}"
fi

ROOTFS="${PROJECT_ROOT}/rootfs"
BUILD_DIR="${PROJECT_ROOT}/build"
ISO_BUILD_DIR="${BUILD_DIR}/iso_root"
OUTPUT_ISO="${BUILD_DIR}/sable-${SABLE_VERSION:-0.3.0}-live-amd64.iso"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Error: This script must be run with sudo:"
    echo "  sudo $0"
    exit 1
fi

if [[ ! -d "${ROOTFS}" ]]; then
    echo "Error: Rootfs not found at ${ROOTFS}. Build it first with sudo ./build.sh"
    exit 1
fi

REQUIRED_TOOLS=(mksquashfs xorriso grub-mkrescue mformat mcopy)
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: Required tool '$tool' is not installed on host."
        echo "Install it with: sudo apt install squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools"
        exit 1
    fi
done

echo "=========================================================="
echo " Building Sable Linux Hybrid Live ISO with Calamares..."
echo " Output: ${OUTPUT_ISO}"
echo "=========================================================="

mkdir -p "${ISO_BUILD_DIR}/live" "${ISO_BUILD_DIR}/boot/grub"

echo "1. Installing Calamares into rootfs for live installer support..."
"${PROJECT_ROOT}/scripts/mount.sh" >> "${BUILD_LOG:-/dev/null}" 2>&1 || true
chroot "${ROOTFS}" apt-get update || true
chroot "${ROOTFS}" apt-get install -y --no-install-recommends calamares qtbase5-dev qml-module-qtquick-controls2 || true
"${PROJECT_ROOT}/scripts/mount.sh" -u >> "${BUILD_LOG:-/dev/null}" 2>&1 || true

echo "2. Compressing rootfs into squashfs..."
rm -f "${ISO_BUILD_DIR}/live/filesystem.squashfs"
mksquashfs "${ROOTFS}" "${ISO_BUILD_DIR}/live/filesystem.squashfs" -comp xz -e boot

echo "3. Copying kernel and initramfs to ISO boot directory..."
KERNEL_VER="$(basename "$(find "${ROOTFS}/boot" -maxdepth 1 -name "vmlinuz*" | head -n1)")"
INITRD_VER="$(basename "$(find "${ROOTFS}/boot" -maxdepth 1 -name "initrd.img*" | head -n1)")"

cp "${ROOTFS}/boot/${KERNEL_VER}" "${ISO_BUILD_DIR}/vmlinuz"
cp "${ROOTFS}/boot/${INITRD_VER}" "${ISO_BUILD_DIR}/initrd.img"

echo "4. Configuring ISO GRUB bootloader..."
cat << 'EOF' > "${ISO_BUILD_DIR}/boot/grub/grub.cfg"
set timeout=5
set default=0

menuentry "Sable Linux Live (KDE Plasma + Calamares)" {
    linux /vmlinuz boot=live quiet splash
    initrd /initrd.img
}

menuentry "Sable Linux Live (Safe Mode / Failsafe)" {
    linux /vmlinuz boot=live nomodeset xorgdriver=vesa
    initrd /initrd.img
}
EOF

echo "5. Generating bootable hybrid ISO..."
grub-mkrescue -o "${OUTPUT_ISO}" "${ISO_BUILD_DIR}"

if [[ -n "${SUDO_USER:-}" && -f "${OUTPUT_ISO}" ]]; then
    chown "${SUDO_USER}:${SUDO_USER}" "${OUTPUT_ISO}" 2>/dev/null || true
    chmod 664 "${OUTPUT_ISO}" 2>/dev/null || true
fi

echo "=========================================================="
echo " Hybrid Live ISO generated successfully!"
echo " Output: ${OUTPUT_ISO}"
echo "=========================================================="
