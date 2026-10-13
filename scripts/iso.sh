#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — Live ISO builder (ibrida BIOS + UEFI, KDE live + Calamares netinstall)
# ==============================================================================
# Differenze rispetto alla versione precedente:
#  - lavora su una COPIA del rootfs (build/live-rootfs): l'immagine .img non viene
#    più contaminata da live-boot/calamares
#  - nessun "|| true" sugli step critici: se live-boot non entra nell'initrd, si ferma
#  - /boot resta dentro lo squashfs (serve al sistema installato)
#  - l'utente 'sable' viene rimosso dallo squashfs e ricreato a runtime da live-config
#  - controlla che l'host abbia i moduli GRUB sia BIOS che UEFI
#  - kernel/initrd = versione più recente, non il primo risultato di find
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
VERSION="${SABLE_VERSION:-0.5.0}"
OUTPUT_ISO="${BUILD_DIR}/sable-${VERSION}-live-amd64.iso"
SQUASHFS_COMP="${SABLE_SQUASHFS_COMP:-zstd}"     # zstd (veloce) oppure xz (più piccolo)
LIVE_USER="${SABLE_DEFAULT_USER:-sable}"
LIVE_HOSTNAME="${SABLE_DEFAULT_HOSTNAME:-sable}"
VOLID="SABLE_LIVE"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Errore: esegui con sudo: sudo $0"
    exit 1
fi

if [[ ! -e "${ROOTFS}/etc/sable/release" ]]; then
    echo "Errore: rootfs non trovato o incompleto in ${ROOTFS}. Esegui prima: sudo ./build.sh"
    exit 1
fi
if ! find "${ROOTFS}/boot" -maxdepth 1 -name 'vmlinuz-*' -print -quit | grep -q .; then
    echo "Errore: nessun kernel in ${ROOTFS}/boot. Esegui prima: sudo ./scripts/kernel.sh"
    exit 1
fi

# --- Tool host ----------------------------------------------------------------
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
    [[ -d "$d" ]] || MISSING+=("moduli GRUB: $d")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "Errore: mancano questi componenti sull'host: ${MISSING[*]}"
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
echo " Sable Linux ${VERSION} — build ISO live (KDE + Calamares netinstall)"
echo " Output: ${OUTPUT_ISO}"
echo "=========================================================="

# --- 1. Copia del rootfs ------------------------------------------------------
echo "1/6 Copia del rootfs in ${LIVE_ROOT} ..."
"${SCRIPT_DIR}/mount.sh" -u >/dev/null 2>&1 || true
umount_live
if mounts_active; then
    echo "Errore: ci sono ancora mount sotto ${LIVE_ROOT}. Smontali a mano e riprova."
    exit 1
fi
mkdir -p "${LIVE_ROOT}"
rsync -aHAX --numeric-ids --delete \
    --exclude='/dev/*' --exclude='/proc/*' --exclude='/sys/*' --exclude='/run/*' --exclude='/tmp/*' \
    "${ROOTFS}/" "${LIVE_ROOT}/"

# --- 2. Installazione live-boot + Calamares nella copia -----------------------
echo "2/6 Installazione live-boot, live-config e Calamares (nessun errore viene ignorato) ..."
mount_live
setup_dns

cat > "${LIVE_ROOT}/tmp/sable-live-setup.sh" << 'EOS'
#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C HOME=/root
apt-get update
apt-get install -y --no-install-recommends \
    live-boot live-config live-config-systemd \
    rsync squashfs-tools efibootmgr dosfstools e2fsprogs ntfs-3g
apt-get install -y calamares
EOS
chmod +x "${LIVE_ROOT}/tmp/sable-live-setup.sh"
chroot "${LIVE_ROOT}" /tmp/sable-live-setup.sh

# --- 3. Configurazione live ---------------------------------------------------
echo "3/6 Configurazione live (Calamares, autologin SDDM, launcher, rimozione utente di sviluppo) ..."

# Calamares: copiato DOPO l'installazione del pacchetto (così non viene sovrascritto)
if [[ -d "${PROJECT_ROOT}/config/calamares" ]]; then
    mkdir -p "${LIVE_ROOT}/etc/calamares"
    cp -a "${PROJECT_ROOT}/config/calamares/." "${LIVE_ROOT}/etc/calamares/"
fi

# Autologin SDDM solo nella sessione live (rimosso dal sistema installato da shellprocess_cleanup)
mkdir -p "${LIVE_ROOT}/etc/sddm.conf.d"
cat > "${LIVE_ROOT}/etc/sddm.conf.d/zz-sable-live-autologin.conf" << EOS
[Autologin]
User=${LIVE_USER}
Session=plasma
Relogin=false
EOS

# Launcher dell'installer nel menu (rimosso dal sistema installato)
cat > "${LIVE_ROOT}/usr/share/applications/sable-install.desktop" << 'EOS'
[Desktop Entry]
Type=Application
Name=Install Sable Linux
Comment=Install Sable Linux on this computer
Exec=sudo -E calamares
Icon=system-software-install
Terminal=false
Categories=System;
EOS

cat > "${LIVE_ROOT}/tmp/sable-live-finish.sh" << 'EOS'
#!/bin/bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C HOME=/root

# L'utente di sviluppo NON deve finire nello squashfs: Calamares lo copierebbe
# nel sistema installato con password nota. Lo crea live-config al boot.
if id "$LIVE_USER" >/dev/null 2>&1; then
    userdel -rf "$LIVE_USER" || true
fi
if id "$LIVE_USER" >/dev/null 2>&1; then
    echo "ERRORE: impossibile rimuovere l'utente $LIVE_USER" >&2
    exit 1
fi

update-initramfs -u -k all

KVER="$(ls -1 /boot/vmlinuz-* | sed 's|/boot/vmlinuz-||' | sort -V | tail -n1)"
if ! lsinitramfs "/boot/initrd.img-${KVER}" | grep -q 'scripts/live'; then
    echo "ERRORE: live-boot NON è presente nell'initrd di ${KVER}: l'ISO non può avviarsi." >&2
    exit 1
fi
echo "OK: live-boot presente nell'initrd (${KVER})"

apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb /tmp/sable-live-*.sh /root/.bash_history
: > /etc/machine-id
: > /etc/resolv.conf
find /var/log -type f -exec truncate -s 0 {} +
EOS
chmod +x "${LIVE_ROOT}/tmp/sable-live-finish.sh"
chroot "${LIVE_ROOT}" env LIVE_USER="${LIVE_USER}" /tmp/sable-live-finish.sh

umount_live
if mounts_active; then
    echo "Errore: mount residui sotto ${LIVE_ROOT}, interrompo prima di creare lo squashfs."
    exit 1
fi

# --- 4. Squashfs --------------------------------------------------------------
echo "4/6 Creazione squashfs (${SQUASHFS_COMP}) ..."
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
    echo "Attenzione: lo squashfs supera 4 GiB ($((SQ_SIZE / 1048576)) MiB). Funziona, ma per una netinstall conviene alleggerire la base."
fi

# --- 5. Kernel, initrd e GRUB -------------------------------------------------
echo "5/6 Kernel, initrd e configurazione GRUB ..."
KVER="$(ls -1 "${LIVE_ROOT}"/boot/vmlinuz-* | sed "s|.*/vmlinuz-||" | sort -V | tail -n1)"
[[ -f "${LIVE_ROOT}/boot/initrd.img-${KVER}" ]] || { echo "Errore: initrd per ${KVER} mancante"; exit 1; }
cp "${LIVE_ROOT}/boot/vmlinuz-${KVER}" "${ISO_DIR}/live/vmlinuz"
cp "${LIVE_ROOT}/boot/initrd.img-${KVER}" "${ISO_DIR}/live/initrd.img"
echo "    kernel: ${KVER}"

cat > "${ISO_DIR}/boot/grub/grub.cfg" << GRUBEOF
set default=0
set timeout=5

menuentry "Sable Linux Live (KDE Plasma)" {
    linux /live/vmlinuz boot=live components username=${LIVE_USER} hostname=${LIVE_HOSTNAME} quiet
    initrd /live/initrd.img
}

menuentry "Sable Linux Live (grafica sicura / nomodeset)" {
    linux /live/vmlinuz boot=live components username=${LIVE_USER} hostname=${LIVE_HOSTNAME} nomodeset
    initrd /live/initrd.img
}

menuentry "Sable Linux Live (carica in RAM)" {
    linux /live/vmlinuz boot=live components username=${LIVE_USER} hostname=${LIVE_HOSTNAME} toram quiet
    initrd /live/initrd.img
}

menuentry "Sable Linux Live (DEBUG: verboso + seriale)" {
    linux /live/vmlinuz boot=live components username=${LIVE_USER} hostname=${LIVE_HOSTNAME} debug earlyprintk=vga console=tty0 console=ttyS0,115200
    initrd /live/initrd.img
}
GRUBEOF

# --- 6. ISO ibrida ------------------------------------------------------------
echo "6/6 Generazione ISO con ${GRUB_RESCUE_CMD} ..."
"${GRUB_RESCUE_CMD}" -o "${OUTPUT_ISO}" "${ISO_DIR}" -- -volid "${VOLID}"

EL_TORITO="$(xorriso -indev "${OUTPUT_ISO}" -report_el_torito plain 2>/dev/null || true)"
if grep -q 'BIOS' <<<"${EL_TORITO}"; then echo "  ✓ entry di boot BIOS presente"; else echo "  ⚠ entry BIOS NON trovata"; fi
if grep -q 'UEFI' <<<"${EL_TORITO}"; then echo "  ✓ entry di boot UEFI presente"; else echo "  ⚠ entry UEFI NON trovata"; fi

if [[ -n "${SUDO_USER:-}" && -f "${OUTPUT_ISO}" ]]; then
    chown "${SUDO_USER}:${SUDO_USER}" "${OUTPUT_ISO}" 2>/dev/null || true
    chmod 664 "${OUTPUT_ISO}" 2>/dev/null || true
fi

echo "=========================================================="
echo " ISO pronta: ${OUTPUT_ISO} ($(du -h "${OUTPUT_ISO}" | cut -f1))"
echo " Utente live: ${LIVE_USER} (password: live)"
echo "=========================================================="
