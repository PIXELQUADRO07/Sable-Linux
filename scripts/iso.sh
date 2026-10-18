#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — Live ISO builder (hybrid BIOS + UEFI, KDE live + Calamares netinstall)
# ==============================================================================
# Key improvements:
#  - Works on a COPY of the rootfs (build/live-rootfs): the .img image is not modified
#  - No "|| true" on critical steps: halts if live-boot fails to include in initrd
#  - /boot stays inside squashfs (needed by installed system)
#  - 'sable' user removed from squashfs and created at runtime by live-config
#  - Checks host GRUB modules for both BIOS and UEFI
#  - Kernel/initrd = latest version selection
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/sable.conf"
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

ROOTFS="${PROJECT_ROOT}/rootfs"
BUILD_DIR="${PROJECT_ROOT}/build"
LIVE_ROOT="${BUILD_DIR}/live-rootfs"
ISO_DIR="${BUILD_DIR}/iso_root"
VERSION="${SABLE_VERSION:-0.6.0}"
OUTPUT_ISO="${BUILD_DIR}/sable-${VERSION}-live-amd64.iso"
SQUASHFS_COMP="${SABLE_SQUASHFS_COMP:-zstd}"     # zstd (fast) or xz (smaller)
LIVE_USER="${SABLE_LIVE_USER:-live}"
LIVE_HOSTNAME="${SABLE_DEFAULT_HOSTNAME:-sable}"
VOLID="SABLE_LIVE"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Error: run with sudo: sudo $0"
    exit 1
fi

if [[ ! -e "${ROOTFS}/etc/sable/release" ]]; then
    echo "Error: rootfs not found or incomplete in ${ROOTFS}. Run first: sudo ./build.sh"
    exit 1
fi
if ! find "${ROOTFS}/boot" -maxdepth 1 -name 'vmlinuz-*' -print -quit | grep -q .; then
    echo "Error: no kernel found in ${ROOTFS}/boot. Run first: sudo ./scripts/kernel.sh"
    exit 1
fi

# --- Host tools ---------------------------------------------------------------
GRUB_RESCUE_CMD=""
if command -v grub2-mkrescue >/dev/null 2>&1; then
    GRUB_RESCUE_CMD="grub2-mkrescue"
elif command -v grub-mkrescue >/dev/null 2>&1; then
    GRUB_RESCUE_CMD="grub-mkrescue"
fi

MISSING=()
for tool in mksquashfs xorriso mformat rsync; do
    command -v "$tool" >/dev/null 2>&1 || MISSING+=("$tool")
done
[[ -n "${GRUB_RESCUE_CMD}" ]] || MISSING+=("grub-mkrescue/grub2-mkrescue")
for d in /usr/lib/grub/i386-pc /usr/lib/grub/x86_64-efi; do
    [[ -d "$d" ]] || MISSING+=("GRUB modules: $d")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "Error: missing required components on host: ${MISSING[*]}"
    echo "  Fedora: sudo dnf install squashfs-tools xorriso mtools rsync grub2-tools-extra grub2-pc-modules grub2-efi-x64-modules"
    echo "  Debian: sudo apt install squashfs-tools xorriso mtools rsync grub-pc-bin grub-efi-amd64-bin"
    exit 1
fi

# --- Mount helpers ------------------------------------------------------------
mounts_active() { findmnt -rn -o TARGET | grep -q "^${LIVE_ROOT}/"; }

umount_live() {
    local m
    for m in run sys dev/pts dev proc; do
        if mountpoint -q "${LIVE_ROOT}/${m}" 2>/dev/null; then
            umount "${LIVE_ROOT}/${m}" 2>/dev/null || umount -l "${LIVE_ROOT}/${m}" 2>/dev/null || true
        fi
    done
}

mount_live() {
    mkdir -p "${LIVE_ROOT}"/{dev,proc,sys,run}
    mount --bind /dev "${LIVE_ROOT}/dev"
    mount --bind /dev/pts "${LIVE_ROOT}/dev/pts"
    mount -t proc proc "${LIVE_ROOT}/proc"
    mount -t sysfs sysfs "${LIVE_ROOT}/sys"
    mount -t tmpfs tmpfs "${LIVE_ROOT}/run"
}

setup_dns() {
    rm -f "${LIVE_ROOT}/etc/resolv.conf"
    if grep -q '127.0.0.53' /etc/resolv.conf 2>/dev/null && [[ -f /run/systemd/resolve/resolv.conf ]]; then
        cp -L /run/systemd/resolve/resolv.conf "${LIVE_ROOT}/etc/resolv.conf"
    else
        cp -L /etc/resolv.conf "${LIVE_ROOT}/etc/resolv.conf" 2>/dev/null || echo "nameserver 9.9.9.9" > "${LIVE_ROOT}/etc/resolv.conf"
    fi
}

trap umount_live EXIT

echo "=========================================================="
echo " Sable Linux ${VERSION} — Live ISO build (KDE + Calamares netinstall)"
echo " Output: ${OUTPUT_ISO}"
echo "=========================================================="

# --- 1. Rootfs Copy -----------------------------------------------------------
echo "1/6 Copying rootfs to ${LIVE_ROOT} ..."
"${SCRIPT_DIR}/mount.sh" -u >/dev/null 2>&1 || true
umount_live
if mounts_active; then
    echo "Error: active mounts remaining under ${LIVE_ROOT}. Unmount manually and retry."
    exit 1
fi
mkdir -p "${LIVE_ROOT}"
rsync -aHAX --numeric-ids --delete \
    --exclude='/dev/*' --exclude='/proc/*' --exclude='/sys/*' --exclude='/run/*' --exclude='/tmp/*' \
    "${ROOTFS}/" "${LIVE_ROOT}/"

# --- 2. Live-boot + Calamares setup in copy -----------------------------------
echo "2/6 Installing live-boot, live-config and Calamares ..."
mount_live
setup_dns

cat > "${LIVE_ROOT}/tmp/sable-live-setup.sh" << 'EOS'
#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C HOME=/root
apt-get update
apt-get install -y --no-install-recommends \
    live-boot live-boot-initramfs-tools live-config live-config-systemd \
    rsync squashfs-tools efibootmgr dosfstools e2fsprogs ntfs-3g zstd cpio initramfs-tools
mkdir -p /etc/initramfs-tools/conf.d
echo "BOOT=live" > /etc/initramfs-tools/conf.d/live.conf
apt-get install -y --no-install-recommends calamares
EOS
chmod +x "${LIVE_ROOT}/tmp/sable-live-setup.sh"
chroot "${LIVE_ROOT}" /tmp/sable-live-setup.sh

# --- 3. Live configuration ----------------------------------------------------
echo "3/6 Configuring live session (Calamares, SDDM autologin, launcher, dev user cleanup) ..."

# Calamares: copied AFTER package installation so it is not overwritten
if [[ -d "${PROJECT_ROOT}/config/calamares" ]]; then
    mkdir -p "${LIVE_ROOT}/etc/calamares"
    cp -a "${PROJECT_ROOT}/config/calamares/." "${LIVE_ROOT}/etc/calamares/"
fi

# SDDM autologin for live session only (removed from installed system by shellprocess_cleanup)
mkdir -p "${LIVE_ROOT}/etc/sddm.conf.d"
cat > "${LIVE_ROOT}/etc/sddm.conf.d/zz-sable-live-autologin.conf" << EOS
[Autologin]
User=${LIVE_USER}
Session=plasmax11
Relogin=false
EOS

# Live session configuration (Debian live-config)
if [[ -f "${PROJECT_ROOT}/config/live/config.conf" ]]; then
    mkdir -p "${LIVE_ROOT}/etc/live"
    cp "${PROJECT_ROOT}/config/live/config.conf" "${LIVE_ROOT}/etc/live/config.conf"
fi

# Installer launcher in launcher menu & desktop (removed from installed system)
if [[ -f "${PROJECT_ROOT}/config/live/sable-installer.desktop" ]]; then
    mkdir -p "${LIVE_ROOT}/usr/share/applications" "${LIVE_ROOT}/etc/skel/Desktop"
    cp "${PROJECT_ROOT}/config/live/sable-installer.desktop" "${LIVE_ROOT}/usr/share/applications/sable-installer.desktop"
    cp "${PROJECT_ROOT}/config/live/sable-installer.desktop" "${LIVE_ROOT}/etc/skel/Desktop/sable-installer.desktop"
    chmod +x "${LIVE_ROOT}/etc/skel/Desktop/sable-installer.desktop"
fi

cat > "${LIVE_ROOT}/tmp/sable-live-finish.sh" << 'EOS'
#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C HOME=/root

# Dev user MUST NOT persist in squashfs (Calamares would copy it with default password)
DEV_USER="${DEV_USER:-sable}"
if id "$DEV_USER" >/dev/null 2>&1; then
    userdel -rf "$DEV_USER" || true
fi

# Pre-create 'live' user with credentials (live:live) and passwordless sudo
# for reliable SDDM autologin. (Calamares removeuser will delete it on disk install)
LIVE_USER="${LIVE_USER:-live}"
LIVE_SHELL="/bin/bash"
if command -v zsh >/dev/null 2>&1; then
    LIVE_SHELL="$(command -v zsh)"
fi

if ! id "$LIVE_USER" >/dev/null 2>&1; then
    useradd -m -s "${LIVE_SHELL}" -G sudo,audio,video,plugdev,netdev,input,cdrom "$LIVE_USER"
else
    usermod -s "${LIVE_SHELL}" -a -G sudo,audio,video,plugdev,netdev,input,cdrom "$LIVE_USER"
fi
echo "${LIVE_USER}:live" | chpasswd 2>/dev/null
mkdir -p /etc/sudoers.d
echo "${LIVE_USER} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/00-${LIVE_USER}"
chmod 0440 "/etc/sudoers.d/00-${LIVE_USER}"

# Ensure skel configurations are pre-populated in /home/live
mkdir -p "/home/${LIVE_USER}"
cp -a /etc/skel/. "/home/${LIVE_USER}/" 2>/dev/null || true
chown -R "${LIVE_USER}:${LIVE_USER}" "/home/${LIVE_USER}"

update-initramfs -u -k all

KVER="$(ls -1 /boot/vmlinuz-* | sed 's|/boot/vmlinuz-||' | sort -V | tail -n1)"

# Validate live-boot is included in initrd.
# Debian uses microcode-prepended initrds (concatenated CPIO archives).
# We check via unmkinitramfs --list and lsinitramfs to inspect the actual archive.
LIVE_FOUND=false
if command -v unmkinitramfs >/dev/null 2>&1; then
    if unmkinitramfs --list "/boot/initrd.img-${KVER}" 2>/dev/null | grep -Eq 'scripts/live|usr/lib/live|bin/live-boot'; then
        LIVE_FOUND=true
    fi
fi
if [[ "${LIVE_FOUND}" == "false" ]] && command -v lsinitramfs >/dev/null 2>&1; then
    if lsinitramfs "/boot/initrd.img-${KVER}" 2>/dev/null | grep -Eq 'scripts/live|usr/lib/live|bin/live-boot'; then
        LIVE_FOUND=true
    fi
fi

if [[ "${LIVE_FOUND}" == "false" ]]; then
    echo "Warning: live-boot not detected in initrd on first pass. Attempting explicit regeneration..."
    update-initramfs -u -k "${KVER}"
    if command -v unmkinitramfs >/dev/null 2>&1 && unmkinitramfs --list "/boot/initrd.img-${KVER}" 2>/dev/null | grep -Eq 'scripts/live|usr/lib/live|bin/live-boot'; then
        LIVE_FOUND=true
    elif command -v lsinitramfs >/dev/null 2>&1 && lsinitramfs "/boot/initrd.img-${KVER}" 2>/dev/null | grep -Eq 'scripts/live|usr/lib/live|bin/live-boot'; then
        LIVE_FOUND=true
    fi
fi

if [[ "${LIVE_FOUND}" == "false" ]]; then
    echo "ERROR: live-boot NOT verified inside /boot/initrd.img-${KVER}. ISO live-boot will fail." >&2
    exit 1
fi
echo "OK: live-boot verified inside initrd (${KVER})"

apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb /tmp/sable-live-*.sh /root/.bash_history
: > /etc/machine-id
: > /etc/resolv.conf
find /var/log -type f -exec truncate -s 0 {} +
EOS
chmod +x "${LIVE_ROOT}/tmp/sable-live-finish.sh"
chroot "${LIVE_ROOT}" env LIVE_USER="${LIVE_USER}" DEV_USER="${SABLE_DEFAULT_USER:-sable}" /tmp/sable-live-finish.sh

umount_live
if mounts_active; then
    echo "Error: active mounts remaining under ${LIVE_ROOT}, stopping before creating squashfs."
    exit 1
fi

# --- 4. Squashfs creation -----------------------------------------------------
echo "4/6 Creating squashfs (${SQUASHFS_COMP}) ..."
rm -rf "${ISO_DIR}"
mkdir -p "${ISO_DIR}/live" "${ISO_DIR}/boot/grub"

SQ_OPTS=(-noappend -comp "${SQUASHFS_COMP}")
if [[ "${SQUASHFS_COMP}" == "zstd" ]]; then
    SQ_OPTS+=(-Xcompression-level 15 -b 1M)
elif [[ "${SQUASHFS_COMP}" == "xz" ]]; then
    SQ_OPTS+=(-b 1M)
fi
mksquashfs "${LIVE_ROOT}" "${ISO_DIR}/live/filesystem.squashfs" "${SQ_OPTS[@]}"

SQ_SIZE="$(stat -c %s "${ISO_DIR}/live/filesystem.squashfs")"
if (( SQ_SIZE > 4294967295 )); then
    echo "Warning: squashfs exceeds 4 GiB ($((SQ_SIZE / 1048576)) MiB). Works, but netinstall base should be slimmed down."
fi

# --- 5. Kernel, initrd and GRUB configuration --------------------------------
echo "5/6 Kernel, initrd and GRUB configuration ..."
KVER="$(ls -1 "${LIVE_ROOT}"/boot/vmlinuz-* | sed "s|.*/vmlinuz-||" | sort -V | tail -n1)"
[[ -f "${LIVE_ROOT}/boot/initrd.img-${KVER}" ]] || { echo "Error: initrd for ${KVER} missing"; exit 1; }
cp "${LIVE_ROOT}/boot/vmlinuz-${KVER}" "${ISO_DIR}/live/vmlinuz"
cp "${LIVE_ROOT}/boot/initrd.img-${KVER}" "${ISO_DIR}/live/initrd.img"
echo "    kernel: ${KVER}"

# Install Sable GRUB theme and font
mkdir -p "${ISO_DIR}/boot/grub/themes/sable" "${ISO_DIR}/boot/grub/fonts"
if [[ -d "${PROJECT_ROOT}/config/branding/grub/themes/sable" ]]; then
    cp -a "${PROJECT_ROOT}/config/branding/grub/themes/sable/." "${ISO_DIR}/boot/grub/themes/sable/"
    if [[ -f "${PROJECT_ROOT}/config/branding/grub/themes/sable/unicode.pf2" ]]; then
        cp "${PROJECT_ROOT}/config/branding/grub/themes/sable/unicode.pf2" "${ISO_DIR}/boot/grub/fonts/unicode.pf2"
    fi
fi

cat > "${ISO_DIR}/boot/grub/grub.cfg" << GRUBEOF
set default=0
set timeout=5

# Graphic mode and theme configuration
set gfxmode=auto
insmod efi_gop
insmod efi_uga
insmod all_video
insmod gfxterm
insmod font
insmod png
insmod gfxmenu

if loadfont /boot/grub/fonts/unicode.pf2; then
    set gfxterm_font=unicode
fi
terminal_output gfxterm

if [ -f /boot/grub/themes/sable/theme.txt ]; then
    set theme=/boot/grub/themes/sable/theme.txt
fi

menuentry "Sable Linux Live (KDE Plasma)" {
    linux /live/vmlinuz boot=live components username=${LIVE_USER} user-password=${LIVE_USER} hostname=${LIVE_HOSTNAME} quiet
    initrd /live/initrd.img
}

menuentry "Sable Linux Live (Safe Graphics / nomodeset)" {
    linux /live/vmlinuz boot=live components username=${LIVE_USER} user-password=${LIVE_USER} hostname=${LIVE_HOSTNAME} nomodeset
    initrd /live/initrd.img
}

menuentry "Sable Linux Live (Copy to RAM / toram)" {
    linux /live/vmlinuz boot=live components username=${LIVE_USER} user-password=${LIVE_USER} hostname=${LIVE_HOSTNAME} toram quiet
    initrd /live/initrd.img
}

menuentry "Sable Linux Live (DEBUG: Verbose + Serial)" {
    linux /live/vmlinuz boot=live components username=${LIVE_USER} user-password=${LIVE_USER} hostname=${LIVE_HOSTNAME} debug earlyprintk=vga console=tty0 console=ttyS0,115200
    initrd /live/initrd.img
}
GRUBEOF

# --- 6. Hybrid ISO creation ---------------------------------------------------
echo "6/6 Generating ISO with ${GRUB_RESCUE_CMD} ..."
"${GRUB_RESCUE_CMD}" -o "${OUTPUT_ISO}" "${ISO_DIR}" -- -volid "${VOLID}"

EL_TORITO="$(xorriso -indev "${OUTPUT_ISO}" -report_el_torito plain 2>/dev/null || true)"
if grep -q 'BIOS' <<<"${EL_TORITO}"; then echo "  ✓ BIOS boot entry present"; else echo "  ⚠ BIOS boot entry NOT found"; fi
if grep -q 'UEFI' <<<"${EL_TORITO}"; then echo "  ✓ UEFI boot entry present"; else echo "  ⚠ UEFI boot entry NOT found"; fi

if [[ -n "${SUDO_USER:-}" && -f "${OUTPUT_ISO}" ]]; then
    chown "${SUDO_USER}:${SUDO_USER}" "${OUTPUT_ISO}" 2>/dev/null || true
    chmod 664 "${OUTPUT_ISO}" 2>/dev/null || true
fi

echo "=========================================================="
echo " ISO ready: ${OUTPUT_ISO} ($(du -h "${OUTPUT_ISO}" | cut -f1))"
echo " Live user: ${LIVE_USER} (password: live)"
echo "=========================================================="
