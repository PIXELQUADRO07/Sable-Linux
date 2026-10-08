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

# Total pipeline stages
TOTAL_STAGES=6
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
        if [[ -d "${BUILD_DIR}/mnt" ]] && mountpoint -q "${BUILD_DIR}/mnt" 2>/dev/null; then
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

for arg in "$@"; do
    case "$arg" in
        --clean|--rebuild)
            CLEAN_BUILD=true
            ;;
        --image-only)
            IMAGE_ONLY=true
            ;;
        --help|-h)
            echo "Usage: sudo $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --clean, --rebuild   Wipe rootfs and rebuild from zero"
            echo "  --image-only         Skip base build and recreate only sable.img"
            echo "  --help, -h           Show this help message"
            exit 0
            ;;
    esac
done

echo -e "${BOLD}${CYAN}"
cat << "EOF"
  ____       _     _        _     _                  
 / ___| __ _| |__ | | ___  | |   (_)_ __  _   ___  __
 \___ \ / _` | '_ \| |/ _ \ | |   | | '_ \| | | \ \/ /
  ___) | (_| | |_) | |  __/ | |___| | | | | |_| |>  < 
 |____/ \__,_|_.__/|_|\___| |_____|_|_| |_|\__,_/_/\_\
EOF
echo -e "${RESET}"
echo -e "${BOLD}Target System:${RESET}  ${SABLE_NAME:-Sable Linux} ${SABLE_VERSION:-0.1.0} (${SABLE_CODENAME:-Nightfall})"
echo -e "${BOLD}Profile:${RESET}        ${SABLE_PROFILE:-desktop} | Arch: ${DEBIAN_ARCH:-amd64} | Suite: ${DEBIAN_SUITE:-trixie}"
echo -e "${BOLD}Logs:${RESET}           ${BUILD_LOG}"

# ------------------------------------------------------------------------------
# Stage 1: Dependency Check
# ------------------------------------------------------------------------------
CURRENT_STAGE=1
draw_progress_bar 1 ${TOTAL_STAGES} "Verifying host build dependencies"

REQUIRED_TOOLS=(debootstrap parted mkfs.ext4 losetup truncate blkid)
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    echo -e "${RED}Error: Missing required host tools: ${MISSING_TOOLS[*]}${RESET}" | tee -a "${ERROR_LOG}"
    echo "Install them using:"
    echo "  sudo dnf install debootstrap parted e2fsprogs util-linux"
    exit 1
fi
log_info "All required host tools are available."

if [[ "${CLEAN_BUILD}" == "true" ]]; then
    log_step "Cleaning previous rootfs and disk image as requested (--clean)..."
    if mountpoint -q "${ROOTFS}/proc" 2>/dev/null; then
        "${SCRIPTS_DIR}/mount.sh" -u >> "${BUILD_LOG}" 2>&1 || true
    fi
    rm -rf "${ROOTFS}" "${BUILD_DIR}/sable.img"
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
# Stage 3: Sable Configuration & Base Setup
# ------------------------------------------------------------------------------
CURRENT_STAGE=3
draw_progress_bar 3 ${TOTAL_STAGES} "Configuring Sable Identity & Base System"

if [[ -f "${ROOTFS}/etc/sable/release" && "${CLEAN_BUILD}" == "false" && "${IMAGE_ONLY}" == "true" ]]; then
    log_info "Sable identity already configured. Skipping configuration."
else
    log_step "Running configuration and provisioning inside chroot..."
    if ! "${SCRIPTS_DIR}/chroot.sh" /root/configure.sh >> "${BUILD_LOG}" 2> >(tee -a "${ERROR_LOG}" >> "${BUILD_LOG}"); then
        echo -e "${RED}System configuration failed.${RESET}"
        exit 1
    fi
    log_info "Sable configuration applied successfully."
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
# Stage 6: Disk Image Generation
# ------------------------------------------------------------------------------
CURRENT_STAGE=6
draw_progress_bar 6 ${TOTAL_STAGES} "Generating Bootable Raw Image (build/sable.img)"

log_step "Creating partitioned 4GB raw image, formatting, and installing GRUB..."
if ! "${SCRIPTS_DIR}/image.sh" >> "${BUILD_LOG}" 2> >(tee -a "${ERROR_LOG}" >> "${BUILD_LOG}"); then
    echo -e "${RED}Image generation failed.${RESET}"
    exit 1
fi
log_info "Bootable image build/sable.img successfully generated."

# ------------------------------------------------------------------------------
# Build Completed Summary
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${GREEN}======================================================================${RESET}"
echo -e "${BOLD}${GREEN} 🎉 SABLE LINUX BUILD COMPLETED SUCCESSFULLY!${RESET}"
echo -e "${BOLD}${GREEN}======================================================================${RESET}"
echo -e "${BOLD}Artifact:${RESET}      ${BUILD_DIR}/sable.img"
if [[ -f "${BUILD_DIR}/sable.img" ]]; then
    IMAGE_ACTUAL_SIZE="$(du -h "${BUILD_DIR}/sable.img" | cut -f1)"
    echo -e "${BOLD}Image Size:${RESET}    ${IMAGE_ACTUAL_SIZE}"
fi
echo -e "${BOLD}Log File:${RESET}      ${BUILD_LOG}"
echo
echo -e "You can now test Sable Linux directly in QEMU:"
echo -e "  ${BOLD}${CYAN}./scripts/qemu.sh${RESET}"
echo -e "Default login: ${BOLD}sable${RESET} / password: ${BOLD}sable${RESET}"
echo -e "${BOLD}${GREEN}======================================================================${RESET}"
