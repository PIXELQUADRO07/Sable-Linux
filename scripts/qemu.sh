#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — QEMU launcher
# Default: live ISO, UEFI. Also supports BIOS, serial, and the dev disk image.
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"

MODE="iso"
FIRMWARE="uefi"
SERIAL=false
MEMORY=4096
SMP=2
EXTRA_QEMU=()
ISO_PATH=""
IMAGE="${BUILD_DIR}/sable.img"

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [-- extra qemu args]

Options:
  --iso [PATH]     Boot a live ISO (default). PATH defaults to build/sable-*-live-amd64.iso
  --image [PATH]   Boot the development raw image (build/sable.img)
  --uefi           Use OVMF UEFI firmware (default)
  --bios           Use legacy SeaBIOS (needed if you skip OVMF)
  --serial         Serial console on stdio (console=ttyS0 for ISO via GRUB serial menu)
  --nographic      Implies --serial and disables the graphical window
  --memory MB      RAM in MiB (default: 4096)
  --smp N          vCPU count (default: 2)
  -h, --help       Show this help

OVMF is searched in Fedora, Debian/Ubuntu (OVMF_CODE_4M.fd), and Arch paths.
EOF
}

find_ovmf() {
    local code vars
    local -a codes=(
        /usr/share/edk2/ovmf/OVMF_CODE.fd
        /usr/share/edk2/ovmf/OVMF_CODE_4M.fd
        /usr/share/OVMF/OVMF_CODE_4M.fd
        /usr/share/OVMF/OVMF_CODE.fd
        /usr/share/qemu/OVMF_CODE_4M.fd
        /usr/share/qemu/OVMF.fd
        /usr/share/edk2-ovmf/x64/OVMF_CODE.fd
        /usr/share/edk2/x64/OVMF_CODE.fd
        /usr/share/ovmf/OVMF.fd
    )
    for code in "${codes[@]}"; do
        [[ -f "${code}" ]] || continue
        vars=""
        case "${code}" in
            *4M*)
                for cand in \
                    "$(dirname "${code}")/OVMF_VARS_4M.fd" \
                    "$(dirname "${code}")/OVMF_VARS.fd" \
                    /usr/share/OVMF/OVMF_VARS_4M.fd \
                    /usr/share/OVMF/OVMF_VARS.fd
                do
                    [[ -f "${cand}" ]] && { vars="${cand}"; break; }
                done
                ;;
            *)
                for cand in \
                    "$(dirname "${code}")/OVMF_VARS.fd" \
                    /usr/share/edk2/ovmf/OVMF_VARS.fd \
                    /usr/share/OVMF/OVMF_VARS.fd
                do
                    [[ -f "${cand}" ]] && { vars="${cand}"; break; }
                done
                ;;
        esac
        OVMF_CODE="${code}"
        OVMF_VARS="${vars}"
        return 0
    done
    return 1
}

resolve_iso() {
    if [[ -n "${ISO_PATH}" && -f "${ISO_PATH}" ]]; then
        return 0
    fi
    local found
    found="$(ls -1t "${BUILD_DIR}"/sable-*-live-amd64.iso 2>/dev/null | head -n1 || true)"
    if [[ -n "${found}" && -f "${found}" ]]; then
        ISO_PATH="${found}"
        return 0
    fi
    echo "Error: live ISO not found. Build it with: sudo ./build.sh"
    echo "Or pass --iso /path/to/sable.iso"
    exit 1
}

NOGRAPHIC=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --iso)
            MODE="iso"
            if [[ "${2:-}" != "" && "${2:-}" != --* ]]; then
                ISO_PATH="$2"
                shift 2
            else
                shift
            fi
            ;;
        --image)
            MODE="image"
            if [[ "${2:-}" != "" && "${2:-}" != --* && -f "${2:-}" ]]; then
                IMAGE="$2"
                shift 2
            else
                shift
            fi
            ;;
        --uefi) FIRMWARE="uefi"; shift ;;
        --bios) FIRMWARE="bios"; shift ;;
        --serial) SERIAL=true; shift ;;
        --nographic) SERIAL=true; NOGRAPHIC=true; shift ;;
        --memory) MEMORY="$2"; shift 2 ;;
        --smp) SMP="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        --) shift; EXTRA_QEMU+=("$@"); break ;;
        *) EXTRA_QEMU+=("$1"); shift ;;
    esac
done

KVM_OPT=()
if [[ -w /dev/kvm ]]; then
    KVM_OPT=("-enable-kvm" "-cpu" "host")
fi

BIOS_OPT=()
if [[ "${FIRMWARE}" == "uefi" ]]; then
    if ! find_ovmf; then
        echo "Error: UEFI firmware (OVMF) not found on host."
        echo "Install:"
        echo "  sudo dnf install edk2-ovmf     # Fedora"
        echo "  sudo apt install ovmf          # Debian/Ubuntu (OVMF_CODE_4M.fd)"
        echo "Or boot with --bios (SeaBIOS; the GPT disk image has no BIOS boot partition)."
        exit 1
    fi
    if [[ -n "${OVMF_VARS}" ]]; then
        TEMP_VARS="$(mktemp /tmp/sable_ovmf_vars.XXXXXX.fd)"
        cp -f "${OVMF_VARS}" "${TEMP_VARS}"
        BIOS_OPT=(
            "-drive" "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}"
            "-drive" "if=pflash,format=raw,file=${TEMP_VARS}"
        )
    else
        BIOS_OPT=("-drive" "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}")
    fi
fi

DISPLAY_OPT=()
SERIAL_OPT=()
if [[ "${NOGRAPHIC}" == "true" ]]; then
    DISPLAY_OPT=("-nographic")
elif [[ "${SERIAL}" == "true" ]]; then
    SERIAL_OPT=("-serial" "mon:stdio")
    DISPLAY_OPT=("-vga" "virtio")
else
    if qemu-system-x86_64 -display help 2>&1 | grep -qE "gtk|sdl"; then
        DISPLAY_OPT=("-vga" "virtio")
    else
        echo "Notice: QEMU GTK/SDL UI missing. Install qemu-ui-gtk, or use --nographic."
        DISPLAY_OPT=("-vga" "virtio" "-display" "none" "-serial" "mon:stdio")
        SERIAL=true
    fi
fi

DRIVE_OPT=()
BOOT_MSG=""
if [[ "${MODE}" == "iso" ]]; then
    resolve_iso
    if [[ ! -r "${ISO_PATH}" ]]; then
        echo "Error: cannot read ${ISO_PATH}"
        exit 1
    fi
    DRIVE_OPT=("-cdrom" "${ISO_PATH}" "-boot" "d")
    BOOT_MSG="ISO ${ISO_PATH} (${FIRMWARE})"
else
    if [[ ! -f "${IMAGE}" ]]; then
        echo "Error: disk image not found at ${IMAGE}"
        echo "The ISO is the release artifact. The raw image is optional:"
        echo "  sudo ./build.sh --image-only"
        exit 1
    fi
    if [[ ! -w "${IMAGE}" ]]; then
        echo "Error: disk image is not writable: ${IMAGE}"
        echo "  sudo chown $USER:$USER ${IMAGE}"
        exit 1
    fi
    DRIVE_OPT=("-drive" "file=${IMAGE},format=raw,if=virtio")
    BOOT_MSG="image ${IMAGE} (${FIRMWARE})"
    if [[ "${FIRMWARE}" == "bios" ]]; then
        echo "Warning: sable.img is GPT+ESP only. SeaBIOS will not find a BIOS boot partition."
    fi
fi

echo "=========================================================="
echo " Launching Sable Linux in QEMU"
echo " Target: ${BOOT_MSG}"
echo " Memory: ${MEMORY}MB | Cores: ${SMP} | Serial: ${SERIAL}"
if [[ "${FIRMWARE}" == "uefi" ]]; then
    echo " OVMF:   ${OVMF_CODE}"
fi
echo " Live ISO credentials:   username 'live'  | password 'live' (passwordless sudo)"
echo " Dev image credentials:  username 'sable' | password 'sable'"
echo "=========================================================="

exec qemu-system-x86_64 \
    -m "${MEMORY}" \
    -smp "${SMP}" \
    "${KVM_OPT[@]}" \
    "${BIOS_OPT[@]}" \
    "${DRIVE_OPT[@]}" \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0 \
    "${DISPLAY_OPT[@]}" \
    "${SERIAL_OPT[@]}" \
    "${EXTRA_QEMU[@]}"
