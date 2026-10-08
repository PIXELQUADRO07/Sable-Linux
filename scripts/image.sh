#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — Disk Image Generator (Milestones 10 & 11)
# Generates a bootable raw disk image: build/sable.img (4GB) with GRUB and ext4
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ROOTFS="${PROJECT_ROOT}/rootfs"
BUILD_DIR="${PROJECT_ROOT}/build"
IMAGE="${BUILD_DIR}/sable.img"
MNT_DIR="${BUILD_DIR}/mnt"
IMAGE_SIZE="4G"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Error: This script must be run with sudo:"
    echo "  sudo $0"
    exit 1
fi

if [[ ! -e "${ROOTFS}/boot/vmlinuz"* ]]; then
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
echo " Building bootable disk image: ${IMAGE} (${IMAGE_SIZE})"
echo "=========================================================="

mkdir -p "${BUILD_DIR}" "${MNT_DIR}"

# 1. Clean up previous mount if present
if mountpoint -q "${MNT_DIR}" 2>/dev/null; then
    echo "Unmounting leftover mountpoint ${MNT_DIR}..."
    umount -R "${MNT_DIR}" || true
fi

# 2. Allocate image file
echo "Allocating 4GB image file..."
rm -f "${IMAGE}"
truncate -s "${IMAGE_SIZE}" "${IMAGE}"

# 3. Create MBR partition table with 1 bootable primary partition
echo "Creating partition table..."
parted -s "${IMAGE}" mklabel msdos
parted -s -a optimal "${IMAGE}" mkpart primary ext4 1MiB 100%
parted -s "${IMAGE}" set 1 boot on

# 4. Attach loop device
LOOP_DEV="$(losetup --show -fP "${IMAGE}")"
PART_DEV="${LOOP_DEV}p1"

cleanup() {
    echo "Cleaning up temporary mounts..."
    if mountpoint -q "${MNT_DIR}/dev" 2>/dev/null; then umount "${MNT_DIR}/dev" || true; fi
    if mountpoint -q "${MNT_DIR}/proc" 2>/dev/null; then umount "${MNT_DIR}/proc" || true; fi
    if mountpoint -q "${MNT_DIR}/sys" 2>/dev/null; then umount "${MNT_DIR}/sys" || true; fi
    if mountpoint -q "${MNT_DIR}" 2>/dev/null; then umount "${MNT_DIR}" || true; fi
    if [[ -n "${LOOP_DEV:-}" ]]; then losetup -d "${LOOP_DEV}" 2>/dev/null || true; fi
}
trap cleanup EXIT

# 5. Format partition as ext4
echo "Formatting partition as ext4..."
mkfs.ext4 -F -L "SABLE_ROOT" "${PART_DEV}"

PART_UUID="$(blkid -s UUID -o value "${PART_DEV}")"
echo "Root partition UUID: ${PART_UUID}"

# 6. Copy rootfs contents to image partition
echo "Mounting partition and copying rootfs..."
mount "${PART_DEV}" "${MNT_DIR}"
cp -a "${ROOTFS}/." "${MNT_DIR}/"

# 7. Generate /etc/fstab
echo "Configuring /etc/fstab..."
cat << EOF > "${MNT_DIR}/etc/fstab"
# /etc/fstab: static file system information for Sable Linux
UUID=${PART_UUID}   /   ext4   errors=remount-ro   0   1
EOF

# 8. Mount virtual filesystems and install GRUB into MBR of loop device
echo "Installing GRUB to ${LOOP_DEV}..."
mkdir -p "${MNT_DIR}/dev" "${MNT_DIR}/proc" "${MNT_DIR}/sys"
mount --bind /dev "${MNT_DIR}/dev"
mount -t proc /proc "${MNT_DIR}/proc"
mount -t sysfs /sys "${MNT_DIR}/sys"

chroot "${MNT_DIR}" grub-install --target=i386-pc "${LOOP_DEV}"
chroot "${MNT_DIR}" update-grub

echo
echo "=========================================================="
echo " Bootable disk image created successfully!"
echo " Output: ${IMAGE}"
echo " Test with QEMU: ./scripts/qemu.sh"
echo "=========================================================="
