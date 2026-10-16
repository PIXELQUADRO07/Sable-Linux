#!/usr/bin/env bash
# Static checks that do not need a built rootfs or QEMU.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
FAIL=0

check() {
    local desc="$1"
    shift
    if "$@"; then
        echo "PASS  ${desc}"
    else
        echo "FAIL  ${desc}"
        FAIL=1
    fi
}

VERSION="$(sed -n 's/^SABLE_VERSION="\(.*\)"/\1/p' "${ROOT}/config/sable.conf")"
check "sable.conf version is 0.6.x" bash -c "[[ '${VERSION}' == 0.6.* ]]"
check "README mentions ${VERSION}" grep -q "${VERSION}" "${ROOT}/README.md"
check "README documents --iso" grep -q -- "--iso" "${ROOT}/README.md"
check "roadmap mentions Calamares modules" grep -q "Calamares" "${ROOT}/docs/roadmap.md"

SETTINGS="${ROOT}/config/calamares/settings.conf"
check "modules-search is local" grep -q 'modules-search: \[ local \]' "${SETTINGS}"
check "exec uses unpackfs" grep -q "unpackfs" "${SETTINGS}"
check "finished is not in exec" bash -c "! awk '/exec:/{p=1} /show:/{if(p&&seen) exit} p && /finished/{exit 1}' '${SETTINGS}'"
check "mount/umount/initramfs listed" bash -c "grep -Eq '^[[:space:]]*- mount' '${SETTINGS}' && grep -Eq '^[[:space:]]*- umount' '${SETTINGS}' && grep -Eq '^[[:space:]]*- initramfs' '${SETTINGS}'"
check "branding is sable" grep -q "branding: sable" "${SETTINGS}"
check "welcome module config exists" test -f "${ROOT}/config/calamares/modules/welcome.conf"
check "unpackfs module config exists" test -f "${ROOT}/config/calamares/modules/unpackfs.conf"
check "netinstall yaml exists" test -f "${ROOT}/config/calamares/modules/netinstall.yaml"
check "branding.desc exists" test -f "${ROOT}/config/calamares/branding/sable/branding.desc"
check "iso.sh does not swallow apt failures" bash -c "! grep -E 'apt-get .*\\|\\| true' '${ROOT}/scripts/iso.sh'"
check "iso.sh does not install qtbase5-dev" bash -c "! grep -q qtbase5-dev '${ROOT}/scripts/iso.sh'"
check "iso.sh does not exclude /boot from squashfs" bash -c "! grep -qE 'mksquashfs.*-e boot' '${ROOT}/scripts/iso.sh'"
check "live user defined" grep -q 'LIVE_USERNAME="live"' "${ROOT}/config/live/config.conf"
check "Install Sable launcher exists" test -f "${ROOT}/config/live/sable-installer.desktop"
check "desktop list uses kde-plasma-desktop" grep -q "kde-plasma-desktop" "${ROOT}/config/desktop/packages.list"
check "desktop list has firefox-esr" grep -q "firefox-esr" "${ROOT}/config/desktop/packages.list"
check "grub list has shim-signed" grep -q "shim-signed" "${ROOT}/scripts/grub.sh"
check "configure.sh does not install pentest suite" bash -c "! grep -q packages-pentest.list '${ROOT}/scripts/configure.sh'"

if [[ "${FAIL}" -ne 0 ]]; then
    echo "static tests FAILED"
    exit 1
fi
echo "static tests PASSED"
