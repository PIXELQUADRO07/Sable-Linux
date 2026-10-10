#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — Disk Image Generator (GPT + UEFI)
# Generates a bootable raw disk image: build/sable.img with GPT, ESP (FAT32), and Root (ext4)
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
IMAGE="${BUILD_DIR}/sable.img"
MNT_DIR="${BUILD_DIR}/mnt"
IMAGE_SIZE="${SABLE_IMAGE_SIZE:-8G}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Error: This script must be run with sudo:"
    echo "  sudo $0"
    exit 1
fi

if ! find "${ROOTFS}/boot" -maxdepth 1 -name "vmlinuz*" -print -quit 2>/dev/null | grep -q .; then
    echo "Error: Linux kernel not found in ${ROOTFS}/boot."
    echo "Run 'sudo ./scripts/kernel.sh' first."
    exit 1
fi

if [[ ! -d "${ROOTFS}/usr/lib/grub" ]]; then
    echo "Error: GRUB packages not found in ${ROOTFS}."
    echo "Run 'sudo ./scripts/grub.sh' first."
    exit 1
fi

echo "=========================================================="
echo " Building GPT UEFI bootable disk image: ${IMAGE} (${IMAGE_SIZE})"
echo "=========================================================="

mkdir -p "${BUILD_DIR}" "${MNT_DIR}"

# 1. Clean up previous mount if present and unmount rootfs virtual filesystems
"${PROJECT_ROOT}/scripts/mount.sh" -u >/dev/null 2>&1 || true
if mountpoint -q "${MNT_DIR}/boot/efi" 2>/dev/null; then
    umount "${MNT_DIR}/boot/efi" || true
fi
if mountpoint -q "${MNT_DIR}" 2>/dev/null; then
    umount -R "${MNT_DIR}" || true
fi

# 2. Allocate image file
echo "Allocating image file..."
rm -f "${IMAGE}"
truncate -s "${IMAGE_SIZE}" "${IMAGE}"

# 3. Create GPT partition table with ESP (FAT32) and Root (ext4)
echo "Creating GPT partition table..."
parted -s "${IMAGE}" mklabel gpt
parted -s -a optimal "${IMAGE}" mkpart ESP fat32 1MiB 512MiB
parted -s "${IMAGE}" set 1 esp on
parted -s -a optimal "${IMAGE}" mkpart primary ext4 512MiB 100%

# 4. Attach loop device & settle
LOOP_DEV="$(losetup --show -fP "${IMAGE}")"
PART_ESP="${LOOP_DEV}p1"
PART_ROOT="${LOOP_DEV}p2"

partprobe "${LOOP_DEV}" || true
udevadm settle || sleep 2

cleanup() {
    echo "Cleaning up temporary mounts..."
    if mountpoint -q "${MNT_DIR}/boot/efi" 2>/dev/null; then umount "${MNT_DIR}/boot/efi" || true; fi
    if mountpoint -q "${MNT_DIR}/dev" 2>/dev/null; then umount "${MNT_DIR}/dev" || true; fi
    if mountpoint -q "${MNT_DIR}/proc" 2>/dev/null; then umount "${MNT_DIR}/proc" || true; fi
    if mountpoint -q "${MNT_DIR}/sys" 2>/dev/null; then umount "${MNT_DIR}/sys" || true; fi
    if mountpoint -q "${MNT_DIR}/run" 2>/dev/null; then umount "${MNT_DIR}/run" || true; fi
    if mountpoint -q "${MNT_DIR}" 2>/dev/null; then umount "${MNT_DIR}" || true; fi
    if [[ -n "${LOOP_DEV:-}" ]]; then losetup -d "${LOOP_DEV}" 2>/dev/null || true; fi
}
trap cleanup EXIT

# 5. Format partitions
echo "Formatting ESP (FAT32) and Root (ext4)..."
mkfs.fat -F32 -n "ESP" "${PART_ESP}"
mkfs.ext4 -F -L "SABLE_ROOT" "${PART_ROOT}"

ESP_UUID="$(blkid -s UUID -o value "${PART_ESP}")"
ROOT_UUID="$(blkid -s UUID -o value "${PART_ROOT}")"
echo "ESP UUID:  ${ESP_UUID}"
echo "Root UUID: ${ROOT_UUID}"

# 6. Mount root and ESP, then copy rootfs
echo "Mounting partitions and copying rootfs..."
mount "${PART_ROOT}" "${MNT_DIR}"
mkdir -p "${MNT_DIR}/boot/efi"
mount "${PART_ESP}" "${MNT_DIR}/boot/efi"

rsync -aHAX --exclude={'/dev/*','/proc/*','/sys/*','/run/*','/tmp/*','/mnt/*','/media/*'} "${ROOTFS}/" "${MNT_DIR}/"
mkdir -p "${MNT_DIR}/dev" "${MNT_DIR}/proc" "${MNT_DIR}/sys" "${MNT_DIR}/run" "${MNT_DIR}/tmp" "${MNT_DIR}/mnt" "${MNT_DIR}/media"
chmod 1777 "${MNT_DIR}/tmp"

# 7. Generate /etc/fstab
echo "Configuring /etc/fstab..."
cat << EOF > "${MNT_DIR}/etc/fstab"
# /etc/fstab: static file system information for Sable Linux
UUID=${ROOT_UUID}   /       ext4   errors=remount-ro   0   1
UUID=${ESP_UUID}    /boot/efi   vfat   defaults          0   2
EOF

# 8. Mount virtual filesystems and install UEFI GRUB
echo "Installing UEFI GRUB to ${LOOP_DEV}..."
mount --bind /dev "${MNT_DIR}/dev"
mount --bind /dev/pts "${MNT_DIR}/dev/pts"
mount -t proc /proc "${MNT_DIR}/proc"
mount -t sysfs /sys "${MNT_DIR}/sys"
mount --bind /run "${MNT_DIR}/run"

chroot "${MNT_DIR}" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=sable --removable
chroot "${MNT_DIR}" update-grub

if [[ -n "${SUDO_USER:-}" && -f "${IMAGE}" ]]; then
    chown "${SUDO_USER}:${SUDO_USER}" "${IMAGE}" 2>/dev/null || true
    chmod 664 "${IMAGE}" 2>/dev/null || true
fi

echo
echo "=========================================================="
echo " GPT UEFI Bootable disk image created successfully!"
echo " Output: ${IMAGE}"
echo " Test with QEMU (UEFI): ./scripts/qemu.sh"
echo "=========================================================="
