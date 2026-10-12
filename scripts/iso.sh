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
OUTPUT_ISO="${BUILD_DIR}/sable-${SABLE_VERSION:-0.4.0}-live-amd64.iso"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Error: This script must be run with sudo:"
    echo "  sudo $0"
    exit 1
fi

if [[ ! -d "${ROOTFS}" ]]; then
    echo "Error: Rootfs not found at ${ROOTFS}. Build it first with sudo ./build.sh"
    exit 1
fi

GRUB_RESCUE_CMD=""
if command -v grub2-mkrescue >/dev/null 2>&1; then
    GRUB_RESCUE_CMD="grub2-mkrescue"
elif command -v grub-mkrescue >/dev/null 2>&1; then
    GRUB_RESCUE_CMD="grub-mkrescue"
fi

REQUIRED_TOOLS=(mksquashfs xorriso mformat mcopy)
MISSING_TOOLS=()
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$tool")
    fi
done
if [[ -z "${GRUB_RESCUE_CMD}" ]]; then
    MISSING_TOOLS+=("grub2-mkrescue/grub-mkrescue")
fi

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    echo "Error: Missing required ISO tools: ${MISSING_TOOLS[*]}"
    echo "Install them using:"
    echo "  sudo dnf install squashfs-tools xorriso grub2-tools-extra mtools dosfstools"
    echo "  or sudo apt install squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools dosfstools"
    exit 1
fi

echo "=========================================================="
echo " Building Sable Linux Hybrid Live ISO with Calamares..."
echo " Output: ${OUTPUT_ISO}"
echo "=========================================================="

mkdir -p "${ISO_BUILD_DIR}/live" "${ISO_BUILD_DIR}/boot/grub"

echo "1. Preparing rootfs for live environment (installing live-boot, live-config, calamares)..."
"${PROJECT_ROOT}/scripts/mount.sh" >> "${BUILD_LOG:-/dev/null}" 2>&1 || true

chroot "${ROOTFS}" apt-get update || true
chroot "${ROOTFS}" apt-get install -y --no-install-recommends live-boot live-config systemd-sysv calamares qtbase5-dev qml-module-qtquick-controls2 || true

# Ensure live user password does not expire immediately on live boot
chroot "${ROOTFS}" chage -d -1 sable 2>/dev/null || true

# Copy Calamares configuration to /etc/calamares if available
if [[ -d "${PROJECT_ROOT}/config/calamares" ]]; then
    mkdir -p "${ROOTFS}/etc/calamares"
    cp -a "${PROJECT_ROOT}/config/calamares/." "${ROOTFS}/etc/calamares/"
fi

# Clean apt caches inside rootfs before packing into squashfs
chroot "${ROOTFS}" apt-get clean || true
rm -rf "${ROOTFS}/var/lib/apt/lists/"* || true
rm -rf "${ROOTFS}/var/cache/apt/archives/"* || true
rm -f "${ROOTFS}/etc/resolv.conf"

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

echo "5. Generating bootable hybrid ISO using ${GRUB_RESCUE_CMD}..."
"${GRUB_RESCUE_CMD}" -o "${OUTPUT_ISO}" "${ISO_BUILD_DIR}"

if [[ -n "${SUDO_USER:-}" && -f "${OUTPUT_ISO}" ]]; then
    chown "${SUDO_USER}:${SUDO_USER}" "${OUTPUT_ISO}" 2>/dev/null || true
    chmod 664 "${OUTPUT_ISO}" 2>/dev/null || true
fi

echo "=========================================================="
echo " Hybrid Live ISO generated successfully!"
echo " Output: ${OUTPUT_ISO}"
echo "=========================================================="
