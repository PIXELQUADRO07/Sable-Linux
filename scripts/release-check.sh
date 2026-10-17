#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — Comprehensive Release Verification Suite (Milestone 28)
# ==============================================================================
# Checks version consistency, shell syntax, static integrity tests,
# Debian package builds, and GRUB theme completeness.
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

BOLD="\033[1m"
RESET="\033[0m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"

if [[ ! -t 1 ]]; then
    BOLD=""
    RESET=""
    GREEN=""
    YELLOW=""
    CYAN=""
    RED=""
fi

source "${PROJECT_ROOT}/config/sable.conf"
EXPECTED_VER="${SABLE_VERSION}"

echo -e "${CYAN}${BOLD}==========================================================${RESET}"
echo -e "${CYAN}${BOLD} 🐾 Sable Linux — Release Verification Suite${RESET}"
echo -e "${CYAN}${BOLD} Target Release: ${SABLE_NAME} ${EXPECTED_VER} (${SABLE_CODENAME})${RESET}"
echo -e "${CYAN}${BOLD}==========================================================${RESET}"

TOTAL=0
PASSED=0
FAILED=0

check() {
    local name="$1"
    shift
    TOTAL=$(( TOTAL + 1 ))
    if "$@"; then
        echo -e " ${GREEN}✓ PASS${RESET}  ${name}"
        PASSED=$(( PASSED + 1 ))
    else
        echo -e " ${RED}✗ FAIL${RESET}  ${name}"
        FAILED=$(( FAILED + 1 ))
    fi
}

echo -e "\n${BOLD}[1/5] Checking Version Consistency (Target: ${EXPECTED_VER})...${RESET}"
check "sable.conf version is ${EXPECTED_VER}" grep -q "SABLE_VERSION=\"${EXPECTED_VER}\"" "${PROJECT_ROOT}/config/sable.conf"
check "branding.desc version is ${EXPECTED_VER}" grep -q "version:[[:space:]]*${EXPECTED_VER}" "${PROJECT_ROOT}/config/calamares/branding/sable/branding.desc"
check "README.md mentions ${EXPECTED_VER}" grep -q "${EXPECTED_VER}" "${PROJECT_ROOT}/README.md"
check "sable-base changelog is ${EXPECTED_VER}" grep -q "sable-base (${EXPECTED_VER}" "${PROJECT_ROOT}/packages/sable-base/debian/changelog"
check "sable-branding changelog is ${EXPECTED_VER}" grep -q "sable-branding (${EXPECTED_VER}" "${PROJECT_ROOT}/packages/sable-branding/debian/changelog"
check "sable-settings changelog is ${EXPECTED_VER}" grep -q "sable-settings (${EXPECTED_VER}" "${PROJECT_ROOT}/packages/sable-settings/debian/changelog"

echo -e "\n${BOLD}[2/5] Validating Shell Scripts Syntax...${RESET}"
check "build.sh syntax" bash -n "${PROJECT_ROOT}/build.sh"
check "scripts/*.sh syntax" bash -n "${PROJECT_ROOT}/scripts"/*.sh
check "packages CLI tools syntax" bash -n "${PROJECT_ROOT}/packages/sable-base/usr/bin"/*

echo -e "\n${BOLD}[3/5] Running Core Static Integrity Suite...${RESET}"
check "test-static.sh execution" "${PROJECT_ROOT}/scripts/test-static.sh"

echo -e "\n${BOLD}[4/5] Checking GRUB Theme Integrity...${RESET}"
check "GRUB theme.txt exists" test -f "${PROJECT_ROOT}/config/branding/grub/themes/sable/theme.txt"
check "GRUB background.png exists" test -f "${PROJECT_ROOT}/config/branding/grub/themes/sable/background.png"
check "GRUB logo.png exists" test -f "${PROJECT_ROOT}/config/branding/grub/themes/sable/logo.png"
check "GRUB selection slices exist" test -f "${PROJECT_ROOT}/config/branding/grub/themes/sable/select_c.png"
check "GRUB unicode.pf2 font exists" test -f "${PROJECT_ROOT}/config/branding/grub/themes/sable/unicode.pf2"

echo -e "\n${BOLD}[5/5] Testing Native Debian Packages & APT Repository Build...${RESET}"
check "build-packages.sh execution" "${PROJECT_ROOT}/scripts/build-packages.sh"
check "build-repo.sh execution" "${PROJECT_ROOT}/scripts/build-repo.sh"

echo -e "\n${CYAN}${BOLD}==========================================================${RESET}"
if (( FAILED == 0 )); then
    echo -e "${GREEN}${BOLD} ✓ ALL ${TOTAL} RELEASE CHECKS PASSED SUCCESSFULLY!${RESET}"
    echo -e "${GREEN} System is ready for Release Candidate / 1.0 distribution.${RESET}"
    echo -e "${CYAN}${BOLD}==========================================================${RESET}"
    exit 0
else
    echo -e "${RED}${BOLD} ✗ ${FAILED} CHECKS FAILED (out of ${TOTAL})${RESET}"
    echo -e "${CYAN}${BOLD}==========================================================${RESET}"
    exit 1
fi
