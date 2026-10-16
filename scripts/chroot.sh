#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ROOTFS="${SABLE_ROOTFS:-${PROJECT_ROOT}/rootfs}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Error: This script must be run with sudo:"
    echo "  sudo $0 [command]"
    exit 1
fi

if [[ ! -e "${ROOTFS}/bin/bash" ]]; then
    echo "Error: Root filesystem does not contain /bin/bash."
    echo "Run ./scripts/bootstrap.sh first."
    exit 1
fi

if ! mountpoint -q "${ROOTFS}/proc" 2>/dev/null; then
    echo "Notice: Virtual filesystems not mounted. Mounting now..."
    "${SCRIPT_DIR}/mount.sh"
fi

# Sync scripts and config into chroot /root/
mkdir -p "${ROOTFS}/root/config"
if [[ -f "${SCRIPT_DIR}/configure.sh" ]]; then
    cp "${SCRIPT_DIR}/configure.sh" "${ROOTFS}/root/configure.sh"
    chmod +x "${ROOTFS}/root/configure.sh"
fi

if [[ -d "${PROJECT_ROOT}/config" ]]; then
    cp -a "${PROJECT_ROOT}/config/." "${ROOTFS}/root/config/"
fi

if [[ -d "${PROJECT_ROOT}/packages" ]]; then
    mkdir -p "${ROOTFS}/root/packages"
    cp -a "${PROJECT_ROOT}/packages/." "${ROOTFS}/root/packages/"
fi

if [[ $# -gt 0 ]]; then
    trap '"${SCRIPT_DIR}/mount.sh" -u >/dev/null 2>&1 || true' EXIT
    chroot "${ROOTFS}" "$@"
else
    echo "=========================================================="
    echo " Entering Sable Linux CHROOT environment"
    echo " To configure the system, run: /root/configure.sh"
    echo " Type 'exit' to leave."
    echo " Remember to run 'sudo ./scripts/mount.sh -u' after exiting."
    echo "=========================================================="
    chroot "${ROOTFS}" /bin/bash
fi
