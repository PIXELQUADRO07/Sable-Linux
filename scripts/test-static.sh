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
check "sable.conf disables dev user by default" grep -q 'SABLE_CREATE_DEV_USER="false"' "${ROOT}/config/sable.conf"
check "configure.sh checks SABLE_CREATE_DEV_USER" grep -q 'SABLE_CREATE_DEV_USER' "${ROOT}/scripts/configure.sh"
check "shellprocess_cleanup purges live sudoers" grep -q '/etc/sudoers.d/00-live' "${ROOT}/config/calamares/modules/shellprocess_cleanup.conf"
check "shellprocess_cleanup purges live user" grep -q 'userdel -rf live' "${ROOT}/config/calamares/modules/shellprocess_cleanup.conf"
check "calamares locale timezone is UTC" grep -q 'zone: "UTC"' "${ROOT}/config/calamares/modules/locale.conf"
check "calamares netinstall has valid file:// fallback" grep -q 'file:///etc/calamares/modules/netinstall.yaml' "${ROOT}/config/calamares/modules/netinstall.conf"
check "calamares exec sequence has shellprocess@cleanup" grep -q 'shellprocess@cleanup' "${SETTINGS}"
check "bootstrap.sh version fallback is 0.6.0" grep -q 'SABLE_VERSION:-0.6.0' "${ROOT}/scripts/bootstrap.sh"
check "image.sh default size is 16G" grep -q 'SABLE_IMAGE_SIZE:-16G' "${ROOT}/scripts/image.sh"
check "mount.sh reports unmount failures" grep -q 'Failed to unmount active filesystem' "${ROOT}/scripts/mount.sh"

if [[ "${FAIL}" -ne 0 ]]; then
    echo "static tests FAILED"
    exit 1
fi
echo "static tests PASSED"
