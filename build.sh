#!/usr/bin/env bash
# ==============================================================================
# 🐾 Sable Linux — Master Build System
# ==============================================================================
# Orchestrates the complete build pipeline:
# Host check -> Bootstrap -> Configure -> Kernel -> GRUB -> Bootable Image
# Includes visual progress bar, centralized logging, and error tracking.
# ==============================================================================
set -Eeuo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/sable.conf"
BUILD_DIR="${PROJECT_ROOT}/build"
ROOTFS="${PROJECT_ROOT}/rootfs"
SCRIPTS_DIR="${PROJECT_ROOT}/scripts"

BUILD_LOG="${BUILD_DIR}/build.log"
ERROR_LOG="${BUILD_DIR}/build-error.log"

# Colors for terminal output
BOLD="\033[1m"
RESET="\033[0m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
DIM="\033[2m"

# Total pipeline stages (ISO is the default deliverable; image is optional)
TOTAL_STAGES=7
CURRENT_STAGE=0

# Ensure running as root
if [[ "${EUID}" -ne 0 ]]; then
    echo -e "${RED}${BOLD}Error:${RESET} The build system must be run as root:"
    echo "  sudo $0 [options]"
    exit 1
fi

mkdir -p "${BUILD_DIR}"
# Truncate / prepare log files
: > "${BUILD_LOG}"
: > "${ERROR_LOG}"

# Source central configuration
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=config/sable.conf
    source "${CONFIG_FILE}"
fi

# ------------------------------------------------------------------------------
# Progress Bar & UI Functions
# ------------------------------------------------------------------------------
draw_progress_bar() {
    local stage="$1"
    local total="$2"
    local desc="$3"
    local width=30
    local percent=$(( stage * 100 / total ))
    local filled=$(( stage * width / total ))
    local empty=$(( width - filled ))

    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    echo -e "\n${BOLD}${CYAN}----------------------------------------------------------------------${RESET}"
    echo -e "${BOLD}${CYAN}[Stage ${stage}/${total}]${RESET} ${BOLD}${desc}${RESET}"
    echo -e "Progress: [${GREEN}${bar}${RESET}] ${BOLD}${percent}%${RESET}"
    echo -e "${BOLD}${CYAN}----------------------------------------------------------------------${RESET}"
}

log_info() {
    local msg="$1"
    echo -e "  ${GREEN}✓${RESET} ${msg}" | tee -a "${BUILD_LOG}"
}

log_step() {
    local msg="$1"
    echo -e "  ${YELLOW}→${RESET} ${msg}" | tee -a "${BUILD_LOG}"
}

cleanup_on_exit() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo -e "\n${RED}${BOLD}======================================================================${RESET}"
        echo -e "${RED}${BOLD}❌ BUILD FAILED at Stage ${CURRENT_STAGE}/${TOTAL_STAGES}${RESET}"
        echo -e "${RED}${BOLD}======================================================================${RESET}"
        if [[ -s "${ERROR_LOG}" ]]; then
            echo -e "${YELLOW}Last error log entries (${ERROR_LOG}):${RESET}"
            tail -n 25 "${ERROR_LOG}"
        fi
        echo -e "\nFull build log available at: ${BOLD}${BUILD_LOG}${RESET}"
        # Cleanup temporary mounts if any
        if [[ -d "${BUILD_DIR}/mnt" ]]; then
            umount -R "${BUILD_DIR}/mnt" 2>/dev/null || true
        fi
    fi
}
trap cleanup_on_exit EXIT

# ------------------------------------------------------------------------------
# Command Line Argument Parsing
# ------------------------------------------------------------------------------
CLEAN_BUILD=false
IMAGE_ONLY=false
BUILD_ISO="${SABLE_BUILD_ISO:-true}"
BUILD_IMAGE="${SABLE_BUILD_IMAGE:-false}"

for arg in "$@"; do
    case "$arg" in
        --clean|--rebuild)
            CLEAN_BUILD=true
            ;;
        --image-only)
            IMAGE_ONLY=true
            BUILD_IMAGE=true
            if [[ "${BUILD_ISO}" == "true" && " $* " != *" --iso "* ]]; then
                BUILD_ISO=false
            fi
            ;;
        --image)
            BUILD_IMAGE=true
            ;;
        --iso)
            BUILD_ISO=true
            ;;
        --skip-iso)
            BUILD_ISO=false
            ;;
        --help|-h)
            echo "Usage: sudo $0 [OPTIONS]"
            echo
            echo "The live ISO is the release artifact. sable.img is a development disk."
            echo
            echo "Options:"
            echo "  --clean, --rebuild   Wipe rootfs and rebuild from zero"
            echo "  --iso                Build the hybrid live ISO (default)"
            echo "  --skip-iso           Do not build the ISO"
            echo "  --image              Also create build/sable.img (GPT+UEFI, development)"
            echo "  --image-only         Skip base build and recreate only sable.img"
            echo "  --help, -h           Show this help message"
            exit 0
            ;;
    esac
done

if [[ "${BUILD_IMAGE}" == "true" && "${BUILD_ISO}" == "true" && "${IMAGE_ONLY}" != "true" ]]; then
    TOTAL_STAGES=8
fi

echo -e "${BOLD}${CYAN}"
cat << "EOF"
  ____       _     _        _     _                  
 / ___| __ _| |__ | | ___  | |   (_)_ __  _   ___  __
 \___ \ / _` | '_ \| |/ _ \ | |   | | '_ \| | | \ \/ /
  ___) | (_| | |_) | |  __/ | |___| | | | | |_| |>  < 
 |____/ \__,_|_.__/|_|\___| |_____|_|_| |_|\__,_/_/\_\
EOF
echo -e "${RESET}"
echo -e "${BOLD}Target System:${RESET}  ${SABLE_NAME:-Sable Linux} ${SABLE_VERSION:-0.5.0} (${SABLE_CODENAME:-Nightfall})"
echo -e "${BOLD}Profile:${RESET}        ${SABLE_PROFILE:-desktop} | Arch: ${DEBIAN_ARCH:-amd64} | Suite: ${DEBIAN_SUITE:-trixie}"
echo -e "${BOLD}Logs:${RESET}           ${BUILD_LOG}"

# ------------------------------------------------------------------------------
# Stage 1: Dependency Check
# ------------------------------------------------------------------------------
CURRENT_STAGE=1
draw_progress_bar 1 ${TOTAL_STAGES} "Verifying host build dependencies"

REQUIRED_TOOLS=(debootstrap parted mkfs.ext4 mkfs.fat partprobe udevadm losetup truncate blkid rsync)
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    echo -e "${RED}Error: Missing required host tools: ${MISSING_TOOLS[*]}${RESET}" | tee -a "${ERROR_LOG}"
    echo "Install them using:"
    echo "  sudo dnf install debootstrap parted e2fsprogs dosfstools util-linux"
    echo "  or sudo apt install debootstrap parted dosfstools util-linux e2fsprogs"
    exit 1
fi
log_info "All required host tools are available."

if [[ "${CLEAN_BUILD}" == "true" ]]; then
    log_step "Cleaning previous rootfs and disk image as requested (--clean)..."
    "${SCRIPTS_DIR}/mount.sh" -u >> "${BUILD_LOG}" 2>&1 || true
    if findmnt -rn -o TARGET | grep -q "^${ROOTFS}/"; then
        echo -e "${RED}Error: Rootfs or sub-mounts still active on host. Aborting clean.${RESET}" | tee -a "${ERROR_LOG}"
        exit 1
    fi
    if [[ -d "${ROOTFS}" ]]; then
        rm -rf --one-file-system "${ROOTFS}"
    fi
    rm -f "${BUILD_DIR}/sable.img"
fi

# ------------------------------------------------------------------------------
# Stage 2: Debian Bootstrap
# ------------------------------------------------------------------------------
CURRENT_STAGE=2
draw_progress_bar 2 ${TOTAL_STAGES} "Debian Base Bootstrap (debootstrap)"

if [[ -e "${ROOTFS}/etc/debian_version" ]]; then
    log_info "Existing root filesystem detected in ${ROOTFS}. Skipping bootstrap."
else
    log_step "Running debootstrap for suite '${DEBIAN_SUITE:-trixie}'..."
    if ! "${SCRIPTS_DIR}/bootstrap.sh" >> "${BUILD_LOG}" 2> >(tee -a "${ERROR_LOG}" >> "${BUILD_LOG}"); then
        echo -e "${RED}Bootstrap failed.${RESET}"
        exit 1
    fi
    log_info "Debian base bootstrap completed."
fi

# ------------------------------------------------------------------------------
# Stage 3: Sable Configuration & Base Setup (Incremental Overlay Sync)
# ------------------------------------------------------------------------------
CURRENT_STAGE=3
draw_progress_bar 3 ${TOTAL_STAGES} "Configuring Sable Identity & Base System"

if [[ "${IMAGE_ONLY}" == "true" && -f "${ROOTFS}/etc/sable/release" ]]; then
    log_info "Image-only requested. Skipping base configuration."
else
    log_step "Syncing configuration overlays and running configuration inside chroot..."
    mkdir -p "${ROOTFS}/root/config"
    rsync -aHAX "${PROJECT_ROOT}/config/" "${ROOTFS}/root/config/"
    if ! "${SCRIPTS_DIR}/chroot.sh" /root/configure.sh >> "${BUILD_LOG}" 2> >(tee -a "${ERROR_LOG}" >> "${BUILD_LOG}"); then
        echo -e "${RED}System configuration failed.${RESET}"
        exit 1
    fi
    log_info "Sable configuration and overlays applied successfully."
fi

# ------------------------------------------------------------------------------
# Stage 4: Kernel Installation
# ------------------------------------------------------------------------------
CURRENT_STAGE=4
draw_progress_bar 4 ${TOTAL_STAGES} "Installing Linux Kernel & Initramfs"

if find "${ROOTFS}/boot" -maxdepth 1 -name "vmlinuz*" -print -quit 2>/dev/null | grep -q . && [[ "${CLEAN_BUILD}" == "false" ]]; then
    KERNEL_VER="$(basename "$(find "${ROOTFS}/boot" -maxdepth 1 -name "vmlinuz*" | head -n1)")"
    log_info "Linux kernel detected in /boot (${KERNEL_VER}). Skipping reinstall."
else
    log_step "Installing Debian kernel package..."
    if ! "${SCRIPTS_DIR}/kernel.sh" >> "${BUILD_LOG}" 2> >(tee -a "${ERROR_LOG}" >> "${BUILD_LOG}"); then
        echo -e "${RED}Kernel installation failed.${RESET}"
        exit 1
    fi
    log_info "Kernel installed successfully."
fi

# ------------------------------------------------------------------------------
# Stage 5: GRUB Bootloader Setup
# ------------------------------------------------------------------------------
CURRENT_STAGE=5
draw_progress_bar 5 ${TOTAL_STAGES} "Installing GRUB Bootloader Packages"

if [[ -d "${ROOTFS}/usr/lib/grub/i386-pc" && "${CLEAN_BUILD}" == "false" ]]; then
    log_info "GRUB bootloader modules already installed. Skipping package setup."
else
    log_step "Installing GRUB packages..."
    if ! "${SCRIPTS_DIR}/grub.sh" >> "${BUILD_LOG}" 2> >(tee -a "${ERROR_LOG}" >> "${BUILD_LOG}"); then
        echo -e "${RED}GRUB installation failed.${RESET}"
        exit 1
    fi
    log_info "GRUB bootloader packages installed."
fi

# ------------------------------------------------------------------------------
# Stage 6: Desktop Environment (KDE Plasma & SDDM)
# ------------------------------------------------------------------------------
CURRENT_STAGE=6
draw_progress_bar 6 ${TOTAL_STAGES} "Configuring Desktop Environment (${SABLE_PROFILE:-desktop})"

if [[ "${SABLE_PROFILE:-desktop}" == "desktop" ]]; then
    if [[ -x "${ROOTFS}/usr/bin/sddm" && "${CLEAN_BUILD}" == "false" ]]; then
        log_info "KDE Plasma and SDDM already installed. Skipping package setup."
    else
        log_step "Installing KDE Plasma and SDDM suite..."
        if ! "${SCRIPTS_DIR}/desktop.sh" >> "${BUILD_LOG}" 2> >(tee -a "${ERROR_LOG}" >> "${BUILD_LOG}"); then
            echo -e "${RED}Desktop installation failed.${RESET}"
            exit 1
        fi
        log_info "KDE Plasma and SDDM installed successfully."
    fi
else
    log_info "Profile '${SABLE_PROFILE}' selected: skipping desktop environment installation."
fi

# ------------------------------------------------------------------------------
# Final Rootfs Hygiene & Cleanup (Pre-Imaging)
# ------------------------------------------------------------------------------
log_step "Performing final rootfs hygiene and cleanup..."
"${SCRIPTS_DIR}/mount.sh" >> "${BUILD_LOG}" 2>&1 || true

chroot "${ROOTFS}" apt-get clean || true
rm -rf "${ROOTFS}/var/lib/apt/lists/"* || true
rm -rf "${ROOTFS}/var/cache/apt/archives/"* || true
rm -f "${ROOTFS}/etc/machine-id" && touch "${ROOTFS}/etc/machine-id"
rm -rf "${ROOTFS}/root/config" "${ROOTFS}/root/configure.sh" || true
rm -f "${ROOTFS}/etc/resolv.conf"

"${SCRIPTS_DIR}/mount.sh" -u >> "${BUILD_LOG}" 2>&1 || true

# Ensure any virtual filesystems on rootfs are unmounted before packaging
"${SCRIPTS_DIR}/mount.sh" -u >/dev/null 2>&1 || true

if [[ "${BUILD_IMAGE}" == "true" ]]; then
    CURRENT_STAGE=7
    draw_progress_bar "${CURRENT_STAGE}" ${TOTAL_STAGES} "Generating development disk image (build/sable.img)"
    log_step "Creating partitioned raw image, formatting ext4, and installing GRUB..."
    if ! "${SCRIPTS_DIR}/image.sh" >> "${BUILD_LOG}" 2> >(tee -a "${ERROR_LOG}" >> "${BUILD_LOG}"); then
        echo -e "${RED}Image generation failed.${RESET}"
        exit 1
    fi
    if [[ -n "${SUDO_USER:-}" && -f "${BUILD_DIR}/sable.img" ]]; then
        chown "${SUDO_USER}:${SUDO_USER}" "${BUILD_DIR}/sable.img" 2>/dev/null || true
        chmod 664 "${BUILD_DIR}/sable.img" 2>/dev/null || true
    fi
    log_info "Development image build/sable.img generated (optional artifact)."
fi

if [[ "${BUILD_ISO}" == "true" ]]; then
    CURRENT_STAGE=${TOTAL_STAGES}
    draw_progress_bar "${CURRENT_STAGE}" ${TOTAL_STAGES} "Generating hybrid live ISO (release artifact)"
    log_step "Building live overlay, Calamares, squashfs, hybrid ISO..."
    if ! "${SCRIPTS_DIR}/iso.sh" >> "${BUILD_LOG}" 2> >(tee -a "${ERROR_LOG}" >> "${BUILD_LOG}"); then
        echo -e "${RED}Live ISO generation failed.${RESET}"
        exit 1
    fi
    log_info "Hybrid live ISO generated."
fi

if [[ "${BUILD_ISO}" != "true" && "${BUILD_IMAGE}" != "true" ]]; then
    echo -e "${YELLOW}Notice: nothing to package (--skip-iso and no --image). Rootfs is ready.${RESET}"
fi

# ------------------------------------------------------------------------------
# Build Completed Summary
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${GREEN}======================================================================${RESET}"
echo -e "${BOLD}${GREEN} 🎉 SABLE LINUX BUILD COMPLETED SUCCESSFULLY!${RESET}"
echo -e "${BOLD}${GREEN}======================================================================${RESET}"
ISO_FILES=("${BUILD_DIR}"/sable-*.iso)
if [[ -f "${ISO_FILES[0]:-}" ]]; then
    ISO_PATH="${ISO_FILES[0]}"
    ISO_SIZE="$(du -h "${ISO_PATH}" | cut -f1)"
    echo -e "${BOLD}Release ISO:${RESET}   ${ISO_PATH} (${ISO_SIZE})"
fi
if [[ -f "${BUILD_DIR}/sable.img" ]]; then
    IMAGE_ACTUAL_SIZE="$(du -h "${BUILD_DIR}/sable.img" | cut -f1)"
    echo -e "${BOLD}Dev image:${RESET}     ${BUILD_DIR}/sable.img (${IMAGE_ACTUAL_SIZE})"
fi
echo -e "${BOLD}Log File:${RESET}      ${BUILD_LOG}"
echo
echo -e "Test the live ISO (UEFI, serial):"
echo -e "  ${BOLD}${CYAN}./scripts/qemu.sh --iso --nographic${RESET}"
echo -e "  ${BOLD}${CYAN}./scripts/qemu.sh --iso --bios${RESET}"
echo -e "  ${BOLD}${CYAN}./scripts/test-iso.sh${RESET}"
echo -e "Live login: ${BOLD}live${RESET}  |  Dev image login: ${BOLD}sable${RESET}"
echo -e "${BOLD}${GREEN}======================================================================${RESET}"
