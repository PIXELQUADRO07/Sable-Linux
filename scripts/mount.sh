#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ROOTFS="${PROJECT_ROOT}/rootfs"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Error: This script must be run with sudo:"
    echo "  sudo $0 [umount|-u]"
    exit 1
fi

if [[ ! -d "${ROOTFS}" ]]; then
    echo "Error: Root filesystem directory does not exist: ${ROOTFS}"
    exit 1
fi

unmount_all() {
    echo "Unmounting virtual filesystems from ${ROOTFS}..."
    local mounts=(
        "${ROOTFS}/run"
        "${ROOTFS}/sys"
        "${ROOTFS}/proc"
        "${ROOTFS}/dev/pts"
        "${ROOTFS}/dev"
    )

    for m in "${mounts[@]}"; do
        if mountpoint -q "$m" 2>/dev/null; then
            echo "  Unmounting $m"
            umount "$m" || true
        fi
    done
    echo "All mounts unmounted."
}

mount_all() {
    echo "Mounting virtual filesystems into ${ROOTFS}..."
    mkdir -p "${ROOTFS}/dev" "${ROOTFS}/dev/pts" "${ROOTFS}/proc" "${ROOTFS}/sys" "${ROOTFS}/run"

    if ! mountpoint -q "${ROOTFS}/dev"; then
        mount --bind /dev "${ROOTFS}/dev"
    fi

    if ! mountpoint -q "${ROOTFS}/dev/pts"; then
        mount --bind /dev/pts "${ROOTFS}/dev/pts"
    fi

    if ! mountpoint -q "${ROOTFS}/proc"; then
        mount -t proc /proc "${ROOTFS}/proc"
    fi

    if ! mountpoint -q "${ROOTFS}/sys"; then
        mount -t sysfs /sys "${ROOTFS}/sys"
    fi

    if ! mountpoint -q "${ROOTFS}/run"; then
        mount --bind /run "${ROOTFS}/run"
    fi

    if [[ -f /etc/resolv.conf ]]; then
        echo "Copying /etc/resolv.conf for DNS resolution..."
        cp -L /etc/resolv.conf "${ROOTFS}/etc/resolv.conf" 2>/dev/null || cp /etc/resolv.conf "${ROOTFS}/etc/resolv.conf"
    fi

    echo "Filesystems successfully mounted."
}

if [[ "${1:-}" == "umount" || "${1:-}" == "-u" || "${1:-}" == "--unmount" ]]; then
    unmount_all
else
    mount_all
fi
