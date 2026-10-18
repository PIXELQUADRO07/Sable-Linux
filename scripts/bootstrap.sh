#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

# Source central configuration
CONFIG_FILE="${PROJECT_ROOT}/config/sable.conf"
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=../config/sable.conf
    source "${CONFIG_FILE}"
fi

ROOTFS="${PROJECT_ROOT}/rootfs"
SUITE="${DEBIAN_SUITE:-trixie}"
ARCH="${DEBIAN_ARCH:-amd64}"
MIRROR="${DEBIAN_MIRROR:-https://deb.debian.org/debian}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Error: This script must be run with sudo:"
    echo "  sudo $0"
    exit 1
fi

if [[ -e "${ROOTFS}/etc/debian_version" ]]; then
    echo "A Debian root filesystem already exists at ${ROOTFS}."
    echo "Refusing to overwrite it. Clear ${ROOTFS} first if you want to rebuild."
    exit 1
fi

# Clean up placeholder .gitkeep so find doesn't report non-empty
if [[ -f "${ROOTFS}/.gitkeep" ]]; then
    rm -f "${ROOTFS}/.gitkeep"
fi

if [[ -n "$(find "${ROOTFS}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    echo "The rootfs directory is not empty: ${ROOTFS}"
    echo "Inspect or clean it before continuing."
    exit 1
fi

if ! command -v debootstrap >/dev/null 2>&1; then
    echo "Error: debootstrap is not installed on the host system."
    echo "Install it with:"
    echo "  sudo dnf install debootstrap   # on Fedora"
    echo "  sudo apt install debootstrap   # on Debian/Ubuntu"
    exit 1
fi

mkdir -p "${ROOTFS}"

echo "=========================================================="
echo " Starting Bootstrap for ${SABLE_NAME:-Sable Linux} (${SABLE_VERSION:-0.6.0})"
echo " Debian suite: ${SUITE}"
echo " Architecture: ${ARCH}"
echo " Mirror:       ${MIRROR}"
echo " Destination:  ${ROOTFS}"
echo "=========================================================="

debootstrap \
    --arch="${ARCH}" \
    --variant=minbase \
    "${SUITE}" \
    "${ROOTFS}" \
    "${MIRROR}"

echo "Configuring clean apt sources.list with non-free-firmware and security..."
rm -f "${ROOTFS}/etc/apt/sources.list.d/debian.sources" 2>/dev/null || true

SECURITY_MIRROR="${DEBIAN_SECURITY_MIRROR:-https://deb.debian.org/debian-security}"

cat << EOF > "${ROOTFS}/etc/apt/sources.list"
deb ${MIRROR} ${SUITE} main non-free-firmware
deb ${MIRROR} ${SUITE}-updates main non-free-firmware
deb ${SECURITY_MIRROR} ${SUITE}-security main non-free-firmware
EOF

echo
echo "=========================================================="
echo " Bootstrap completed successfully."
echo " Root filesystem generated at: ${ROOTFS}"
echo " Next steps: verify rootfs and prepare chroot with mount.sh"
echo "=========================================================="
