#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — QEMU Test Launcher (Milestone 11 / 18)
# Launches build/sable.img in QEMU
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
IMAGE="${PROJECT_ROOT}/build/sable.img"

if [[ ! -f "${IMAGE}" ]]; then
    echo "Error: Disk image not found at ${IMAGE}"
    echo "Generate it first with: sudo ./build.sh"
    exit 1
fi

if [[ ! -w "${IMAGE}" ]]; then
    echo "Error: Disk image is not writable by current user: ${IMAGE}"
    echo "Fix permissions by running:"
    echo "  sudo chown $USER:$USER ${IMAGE}"
    exit 1
fi

if ! qemu-system-x86_64 -display help 2>&1 | grep -qE "gtk|sdl"; then
    echo "=========================================================="
    echo " Notice: Graphical UI driver (GTK/SDL) missing in QEMU."
    echo " To see the graphical window, install qemu-ui-gtk:"
    echo "   sudo dnf install qemu-ui-gtk"
    echo "=========================================================="
fi

KVM_OPT=()
if [[ -w /dev/kvm ]]; then
    KVM_OPT=("-enable-kvm")
fi

echo "=========================================================="
echo " Launching Sable Linux in QEMU..."
echo " Memory: 4096MB | Cores: 2"
echo " Image:  ${IMAGE}"
echo " Default user: sable (password: sable)"
echo "=========================================================="

qemu-system-x86_64 \
    -m 4096 \
    -smp 2 \
    "${KVM_OPT[@]}" \
    -drive file="${IMAGE}",format=raw,index=0,media=disk \
    -net nic,model=virtio \
    -net user \
    -vga std \
    "$@"
