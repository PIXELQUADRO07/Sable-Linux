#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — QEMU Test Launcher (GPT + UEFI OVMF)
# Launches build/sable.img in QEMU with UEFI firmware if available
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

BIOS_OPT=()
if [[ -f /usr/share/edk2/ovmf/OVMF_CODE.fd ]]; then
    OVMF_VARS_SRC="/usr/share/edk2/ovmf/OVMF_VARS.fd"
    if [[ -f "${OVMF_VARS_SRC}" ]]; then
        TEMP_VARS="/tmp/sable_ovmf_vars.fd"
        cp -f "${OVMF_VARS_SRC}" "${TEMP_VARS}"
        BIOS_OPT=(
            "-drive" "if=pflash,format=raw,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE.fd"
            "-drive" "if=pflash,format=raw,file=${TEMP_VARS}"
        )
    else
        BIOS_OPT=("-drive" "if=pflash,format=raw,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE.fd")
    fi
elif [[ -f /usr/share/OVMF/OVMF_CODE.fd ]]; then
    BIOS_OPT=("-drive" "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd")
fi

if [[ ${#BIOS_OPT[@]} -eq 0 ]]; then
    echo "Error: UEFI firmware (OVMF) not found on host."
    echo "Sable Linux requires UEFI (GPT) to boot."
    echo "Please install OVMF package on your host system:"
    echo "  sudo dnf install edk2-ovmf   # on Fedora"
    echo "  sudo apt install ovmf        # on Debian/Ubuntu"
    exit 1
fi

echo "=========================================================="
echo " Launching Sable Linux in QEMU (GPT + UEFI)..."
echo " Memory: 4096MB | Cores: 2"
echo " Image:  ${IMAGE}"
echo " Default user: sable (password change required on first login)"
echo "=========================================================="

qemu-system-x86_64 \
    -m 4096 \
    -smp 2 \
    "${KVM_OPT[@]}" \
    "${BIOS_OPT[@]}" \
    -drive file="${IMAGE}",format=raw,index=0,media=disk \
    -net nic,model=virtio \
    -net user \
    -vga std \
    "$@"
