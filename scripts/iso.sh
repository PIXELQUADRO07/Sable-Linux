#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — Hybrid Live ISO (overlay live rootfs + Calamares)
# Operates on an overlay of rootfs so the development image stays clean.
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/sable.conf"
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=../config/sable.conf
    source "${CONFIG_FILE}"
fi

ROOTFS="${PROJECT_ROOT}/rootfs"
BUILD_DIR="${PROJECT_ROOT}/build"
ISO_BUILD_DIR="${BUILD_DIR}/iso_root"
LIVE_UPPER="${BUILD_DIR}/live-upper"
LIVE_WORK="${BUILD_DIR}/live-work"
LIVE_ROOT="${BUILD_DIR}/live-root"
OUTPUT_ISO="${BUILD_DIR}/sable-${SABLE_VERSION:-0.5.0}-live-amd64.iso"
LIVE_USER="${SABLE_LIVE_USER:-live}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Error: This script must be run with sudo:"
    echo "  sudo $0"
    exit 1
fi

if [[ ! -d "${ROOTFS}" || ! -e "${ROOTFS}/etc/debian_version" ]]; then
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
    echo "  sudo dnf install squashfs-tools xorriso grub2-tools-extra grub2-pc-modules grub2-efi-x64-modules mtools dosfstools"
    echo "  or sudo apt install squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools dosfstools"
    exit 1
fi

echo "=========================================================="
echo " Building Sable Linux Hybrid Live ISO with Calamares..."
echo " Output: ${OUTPUT_ISO}"
echo " Live rootfs: overlay on ${ROOTFS} (base rootfs is not modified)"
echo "=========================================================="

cleanup_live() {
    "${PROJECT_ROOT}/scripts/mount.sh" -u >/dev/null 2>&1 || true
    if mountpoint -q "${LIVE_ROOT}" 2>/dev/null; then
        umount "${LIVE_ROOT}" 2>/dev/null || umount -l "${LIVE_ROOT}" 2>/dev/null || true
    fi
}
trap cleanup_live EXIT

"${PROJECT_ROOT}/scripts/mount.sh" -u >/dev/null 2>&1 || true

rm -rf "${LIVE_UPPER}" "${LIVE_WORK}"
mkdir -p "${LIVE_UPPER}" "${LIVE_WORK}" "${LIVE_ROOT}" "${ISO_BUILD_DIR}/live" "${ISO_BUILD_DIR}/boot/grub"

echo "1. Mounting live overlay (lowerdir=rootfs)..."
if ! mount -t overlay overlay \
    -o "lowerdir=${ROOTFS},upperdir=${LIVE_UPPER},workdir=${LIVE_WORK}" \
    "${LIVE_ROOT}"; then
    echo "Overlayfs unavailable; falling back to rsync copy of rootfs."
    rsync -aHAX --delete \
        --exclude={'/dev/*','/proc/*','/sys/*','/run/*','/tmp/*'} \
        "${ROOTFS}/" "${LIVE_ROOT}/"
    mkdir -p "${LIVE_ROOT}/dev" "${LIVE_ROOT}/proc" "${LIVE_ROOT}/sys" "${LIVE_ROOT}/run" "${LIVE_ROOT}/tmp"
fi

export SABLE_ROOTFS="${LIVE_ROOT}"
"${PROJECT_ROOT}/scripts/mount.sh"

echo "2. Installing live-boot, live-config, Plymouth, Calamares (no Qt5 -dev)..."
chroot "${LIVE_ROOT}" apt-get update
chroot "${LIVE_ROOT}" apt-get install -y --no-install-recommends \
    live-boot \
    live-config \
    live-config-systemd \
    systemd-sysv \
    calamares \
    plymouth \
    plymouth-themes \
    policykit-1 \
    rsync

echo "3. Applying live identity, Calamares branding, installer launcher, Plymouth..."
mkdir -p "${LIVE_ROOT}/etc/live/config.conf.d"
cp "${PROJECT_ROOT}/config/live/config.conf" "${LIVE_ROOT}/etc/live/config.conf.d/sable.conf"
cat >> "${LIVE_ROOT}/etc/live/config.conf.d/sable.conf" << EOF
LIVE_USERNAME="${LIVE_USER}"
EOF

mkdir -p "${LIVE_ROOT}/etc/calamares/modules"
cp -a "${PROJECT_ROOT}/config/calamares/settings.conf" "${LIVE_ROOT}/etc/calamares/settings.conf"
cp -a "${PROJECT_ROOT}/config/calamares/modules/." "${LIVE_ROOT}/etc/calamares/modules/"

mkdir -p "${LIVE_ROOT}/usr/share/calamares/branding/sable" "${LIVE_ROOT}/etc/calamares/branding/sable"
cp -a "${PROJECT_ROOT}/config/calamares/branding/sable/." "${LIVE_ROOT}/usr/share/calamares/branding/sable/"
cp -a "${PROJECT_ROOT}/config/calamares/branding/sable/." "${LIVE_ROOT}/etc/calamares/branding/sable/"

mkdir -p "${LIVE_ROOT}/usr/share/applications" "${LIVE_ROOT}/etc/skel/Desktop"
cp "${PROJECT_ROOT}/config/live/sable-installer.desktop" "${LIVE_ROOT}/usr/share/applications/sable-installer.desktop"
cp "${PROJECT_ROOT}/config/live/sable-installer.desktop" "${LIVE_ROOT}/etc/skel/Desktop/sable-installer.desktop"
chmod 644 "${LIVE_ROOT}/usr/share/applications/sable-installer.desktop"
chmod 755 "${LIVE_ROOT}/etc/skel/Desktop"

mkdir -p "${LIVE_ROOT}/usr/share/plymouth/themes/sable"
cp "${PROJECT_ROOT}/config/live/plymouth/sable.plymouth" "${LIVE_ROOT}/usr/share/plymouth/themes/sable/"
cp "${PROJECT_ROOT}/config/live/plymouth/sable.script" "${LIVE_ROOT}/usr/share/plymouth/themes/sable/"
cp "${PROJECT_ROOT}/config/calamares/branding/sable/logo.png" "${LIVE_ROOT}/usr/share/plymouth/themes/sable/logo.png"
chroot "${LIVE_ROOT}" plymouth-set-default-theme sable || \
    chroot "${LIVE_ROOT}" sh -c 'echo "sable" > /etc/plymouth/plymouthd.conf' || true

# SDDM autologin for the live user (created at boot by live-config)
mkdir -p "${LIVE_ROOT}/etc/sddm.conf.d"
cat << EOF > "${LIVE_ROOT}/etc/sddm.conf.d/sable-live.conf"
[Autologin]
User=${LIVE_USER}
Session=plasma

[Theme]
Current=breeze

[Users]
MaximumUid=60000
MinimumUid=1000
EOF

# Drop the development 'sable' account from the live squashfs so Calamares
# does not install a second user with a well-known password.
if chroot "${LIVE_ROOT}" id "${SABLE_DEFAULT_USER:-sable}" >/dev/null 2>&1; then
    chroot "${LIVE_ROOT}" userdel -r "${SABLE_DEFAULT_USER:-sable}" || true
fi
# live-config must be allowed to expire/create the live user freely
chroot "${LIVE_ROOT}" chage -d -1 root 2>/dev/null || true

echo "4. Rebuilding initramfs with live-boot hooks..."
chroot "${LIVE_ROOT}" sh -c 'update-initramfs -u -k all'

INITRD_FILE="$(find "${LIVE_ROOT}/boot" -maxdepth 1 -name "initrd.img-*" | head -n1)"
if [[ -z "${INITRD_FILE}" ]]; then
    echo "Error: no initrd.img found in live /boot after update-initramfs"
    exit 1
fi
if ! chroot "${LIVE_ROOT}" sh -c "lsinitramfs /boot/$(basename "${INITRD_FILE}")" | grep -Eq 'live|boot=live|scripts/live'; then
    echo "Error: live-boot hooks are missing from the live initramfs."
    echo "Refusing to emit an ISO that would drop to the initramfs prompt."
    exit 1
fi

chroot "${LIVE_ROOT}" apt-get clean
rm -rf "${LIVE_ROOT}/var/lib/apt/lists/"* || true
rm -rf "${LIVE_ROOT}/var/cache/apt/archives/"* || true
rm -f "${LIVE_ROOT}/etc/resolv.conf"
"${PROJECT_ROOT}/scripts/mount.sh" -u >/dev/null 2>&1 || true

echo "5. Compressing live rootfs into squashfs (kernel/initrd included for Calamares)..."
rm -f "${ISO_BUILD_DIR}/live/filesystem.squashfs"
# Include /boot so the installed system has a kernel. Exclude runtime mounts.
mksquashfs "${LIVE_ROOT}" "${ISO_BUILD_DIR}/live/filesystem.squashfs" \
    -comp xz -Xbcj x86 -b 1M \
    -e dev proc sys run tmp

SQUASH_BYTES="$(stat -c%s "${ISO_BUILD_DIR}/live/filesystem.squashfs")"
if (( SQUASH_BYTES > 4000000000 )); then
    echo "Warning: squashfs is ${SQUASH_BYTES} bytes (>4 GiB). ISO9660 may fail; slim the image."
fi

echo "6. Copying kernel and initramfs to ISO boot directory..."
KERNEL_FILE="$(find "${LIVE_ROOT}/boot" -maxdepth 1 -name "vmlinuz-*" | head -n1)"
cp "${KERNEL_FILE}" "${ISO_BUILD_DIR}/vmlinuz"
cp "${INITRD_FILE}" "${ISO_BUILD_DIR}/initrd.img"

echo "7. Configuring ISO GRUB (graphical + serial + failsafe)..."
cat << 'EOF' > "${ISO_BUILD_DIR}/boot/grub/grub.cfg"
set timeout=8
set default=0

if [ -n "$debug" ]; then
    set pager=1
fi

insmod all_video
insmod gfxterm
terminal_output gfxterm
terminal_input --append serial
serial --unit=0 --speed=115200

menuentry "Sable Linux Live (KDE Plasma)" {
    linux /vmlinuz boot=live components quiet splash username=live
    initrd /initrd.img
}

menuentry "Sable Linux Live (serial console ttyS0)" {
    linux /vmlinuz boot=live components console=tty0 console=ttyS0,115200n8 username=live nomodeset
    initrd /initrd.img
}

menuentry "Sable Linux Live (Safe Mode)" {
    linux /vmlinuz boot=live components nomodeset username=live
    initrd /initrd.img
}
EOF

echo "8. Generating hybrid BIOS+UEFI ISO using ${GRUB_RESCUE_CMD}..."
"${GRUB_RESCUE_CMD}" -o "${OUTPUT_ISO}" "${ISO_BUILD_DIR}"

if [[ -n "${SUDO_USER:-}" && -f "${OUTPUT_ISO}" ]]; then
    chown "${SUDO_USER}:${SUDO_USER}" "${OUTPUT_ISO}" 2>/dev/null || true
    chmod 664 "${OUTPUT_ISO}" 2>/dev/null || true
fi

echo "=========================================================="
echo " Hybrid Live ISO generated successfully!"
echo " Output: ${OUTPUT_ISO}"
echo " Test:   ./scripts/qemu.sh --iso"
echo "         ./scripts/test-iso.sh"
echo "=========================================================="
