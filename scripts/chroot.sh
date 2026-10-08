#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ROOTFS="${PROJECT_ROOT}/rootfs"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Error: This script must be run with sudo:"
    echo "  sudo $0"
    exit 1
fi

if [[ ! -e "${ROOTFS}/bin/bash" ]]; then
    echo "Error: Root filesystem does not contain /bin/bash."
    echo "Run ./scripts/bootstrap.sh first."
    exit 1
fi

if ! mountpoint -q "${ROOTFS}/proc" 2>/dev/null; then
    echo "Warning: /proc is not mounted in ${ROOTFS}."
    echo "Mounting virtual filesystems now..."
    "${SCRIPT_DIR}/mount.sh"
fi

echo "=========================================================="
echo " Entering Sable Linux CHROOT environment"
echo " Type 'exit' to leave."
echo " Remember to run 'sudo ./scripts/mount.sh -u' after exiting."
echo "=========================================================="

chroot "${ROOTFS}" /bin/bash
