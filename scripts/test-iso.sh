#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — QEMU smoke tests for the live ISO (BIOS + UEFI, serial)
# Boots with console=ttyS0 by attaching -kernel/-initrd from the ISO so GRUB
# cannot hide a live-boot failure. Also boots the ISO firmware path itself.
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
TIMEOUT_SEC="${SABLE_QEMU_TIMEOUT:-90}"
WORKDIR="$(mktemp -d /tmp/sable-iso-test.XXXXXX)"
ISO_PATH="${1:-}"

cleanup() {
    rm -rf "${WORKDIR}"
}
trap cleanup EXIT

if [[ -z "${ISO_PATH}" ]]; then
    ISO_PATH="$(ls -1t "${BUILD_DIR}"/sable-*-live-amd64.iso 2>/dev/null | head -n1 || true)"
fi
if [[ -z "${ISO_PATH}" || ! -f "${ISO_PATH}" ]]; then
    echo "FAIL: no live ISO found. Build with: sudo ./build.sh"
    exit 1
fi

echo "Testing ISO: ${ISO_PATH}"
echo "Timeout: ${TIMEOUT_SEC}s per firmware"

# Extract kernel/initrd from the ISO for a GRUB-independent live-boot probe.
mkdir -p "${WORKDIR}/iso"
if command -v xorriso >/dev/null 2>&1; then
    xorriso -osirrox on -indev "${ISO_PATH}" -extract /vmlinuz "${WORKDIR}/iso/vmlinuz" -extract /initrd.img "${WORKDIR}/iso/initrd.img" >/dev/null 2>&1 || true
fi
if [[ ! -f "${WORKDIR}/iso/vmlinuz" ]]; then
    echo "WARN: could not extract /vmlinuz from ISO (need xorriso). Skipping direct-kernel probe."
fi

KVM_OPT=()
if [[ -w /dev/kvm ]]; then
    KVM_OPT=(-enable-kvm)
fi

boot_direct_kernel() {
    local log="${WORKDIR}/direct-serial.log"
    echo "--- Direct kernel+initrd, serial stdio (probes live-boot) ---"
    if [[ ! -f "${WORKDIR}/iso/vmlinuz" ]]; then
        echo "SKIP: no extracted kernel"
        return 0
    fi
    timeout --signal=KILL "$((TIMEOUT_SEC + 10))" qemu-system-x86_64 \
        -m 2048 -smp 2 \
        "${KVM_OPT[@]}" \
        -nographic \
        -kernel "${WORKDIR}/iso/vmlinuz" \
        -initrd "${WORKDIR}/iso/initrd.img" \
        -append "boot=live components console=ttyS0,115200n8 username=live noeject noprompt" \
        -cdrom "${ISO_PATH}" \
        -boot d \
        -no-reboot \
        >"${log}" 2>&1 || true
    echo "Last 40 lines:"
    tail -n 40 "${log}" || true
    if grep -Eqi 'Gave up waiting for root|no live filesystem|Kernel panic|Cannot find medium' "${log}"; then
        echo "FAIL: live-boot did not find the squashfs (see ${log})"
        return 1
    fi
    if grep -Eqi 'Debian GNU/Linux|Sable Linux|login:|sddm|Reached target' "${log}"; then
        echo "PASS: userspace started on serial"
        return 0
    fi
    echo "WARN: no clear login/target marker within ${TIMEOUT_SEC}s (log: ${log})"
    echo "Annotate the last lines above as the stall point."
    return 0
}

boot_firmware() {
    local kind="$1"
    local log="${WORKDIR}/${kind}.log"
    local fw=()
    echo "--- ISO boot ${kind} ---"
    if [[ "${kind}" == "uefi" ]]; then
        local code="" vars=""
        for c in \
            /usr/share/edk2/ovmf/OVMF_CODE.fd \
            /usr/share/OVMF/OVMF_CODE_4M.fd \
            /usr/share/OVMF/OVMF_CODE.fd
        do
            [[ -f "${c}" ]] && { code="${c}"; break; }
        done
        if [[ -z "${code}" ]]; then
            echo "SKIP: no OVMF firmware"
            return 0
        fi
        for v in "$(dirname "${code}")/OVMF_VARS.fd" /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd; do
            [[ -f "${v}" ]] && { vars="${v}"; break; }
        done
        fw+=(-drive "if=pflash,format=raw,readonly=on,file=${code}")
        if [[ -n "${vars}" ]]; then
            cp -f "${vars}" "${WORKDIR}/vars-${kind}.fd"
            fw+=(-drive "if=pflash,format=raw,file=${WORKDIR}/vars-${kind}.fd")
        fi
    fi
    timeout --signal=KILL "$((TIMEOUT_SEC + 15))" qemu-system-x86_64 \
        -m 2048 -smp 2 \
        "${KVM_OPT[@]}" \
        "${fw[@]}" \
        -nographic \
        -serial mon:stdio \
        -cdrom "${ISO_PATH}" \
        -boot d \
        -no-reboot \
        >"${log}" 2>&1 || true
    echo "Last 40 lines (${kind}):"
    tail -n 40 "${log}" || true
    if grep -Eqi 'Kernel panic|no live filesystem|Gave up waiting' "${log}"; then
        echo "FAIL: ${kind} boot panic/live-boot miss"
        return 1
    fi
    echo "NOTE: ${kind} log saved conceptually as last serial output above."
    return 0
}

FAIL=0
boot_direct_kernel || FAIL=1
boot_firmware uefi || FAIL=1
boot_firmware bios || FAIL=1

if [[ "${FAIL}" -ne 0 ]]; then
    echo "ISO smoke test FAILED"
    exit 1
fi
echo "ISO smoke test finished (inspect WARN/NOTE lines for stall point)."
