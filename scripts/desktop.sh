#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — KDE Plasma Desktop & Custom Environment (Milestones 14 & 15)
# Can be run from host: sudo ./scripts/desktop.sh
# Or inside chroot:     /root/desktop.sh
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ROOTFS="${PROJECT_ROOT}/rootfs"

install_desktop_in_chroot() {
    export HOME=/root
    export LC_ALL=C
    export DEBIAN_FRONTEND=noninteractive

    echo "=========================================================="
    echo " [Milestone 14] Installing KDE Plasma & SDDM Desktop Suite"
    echo "=========================================================="

    CONFIG_DIR="/root/config"
    if [[ ! -d "${CONFIG_DIR}" ]]; then
        if [[ -d "/etc/sable/config" ]]; then
            CONFIG_DIR="/etc/sable/config"
        else
            CONFIG_DIR=""
        fi
    fi

    DESKTOP_LIST="${CONFIG_DIR}/desktop/packages.list"
    PKGS=()
    if [[ -n "${CONFIG_DIR}" && -f "${DESKTOP_LIST}" ]]; then
        while IFS= read -r pkg || [[ -n "$pkg" ]]; do
            pkg="$(echo "$pkg" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            if [[ -n "$pkg" ]]; then
                PKGS+=("$pkg")
            fi
        done < "${DESKTOP_LIST}"
    else
        PKGS=(kde-plasma-desktop sddm plasma-nm dolphin konsole firefox-esr partitionmanager zsh pipewire pipewire-audio wireplumber xwayland libgl1-mesa-dri fonts-dejavu-core fonts-noto-core)
    fi

    echo "--> Updating APT package index..."
    apt-get update

    if [[ -f "${CONFIG_DIR}/desktop/plasma.conf" ]]; then
        # shellcheck source=/dev/null
        source "${CONFIG_DIR}/desktop/plasma.conf"
    fi
    if [[ -f "${CONFIG_DIR}/desktop/defaults.conf" ]]; then
        # shellcheck source=/dev/null
        source "${CONFIG_DIR}/desktop/defaults.conf"
    fi
    if [[ -f "${CONFIG_DIR}/sable.conf" ]]; then
        # shellcheck source=/dev/null
        source "${CONFIG_DIR}/sable.conf"
    fi

    if [[ "${SABLE_DESKTOP:-kde}" != "kde" ]]; then
        echo "SABLE_DESKTOP=${SABLE_DESKTOP}: skipping KDE package set."
        return 0
    fi

    if [[ "${ENABLE_PRINTING_CUPS:-false}" == "true" ]]; then
        PKGS+=(cups print-manager)
    fi
    if [[ -n "${DEFAULT_BROWSER:-}" ]]; then
        case " ${PKGS[*]} " in
            *" ${DEFAULT_BROWSER} "*) ;;
            *) PKGS+=("${DEFAULT_BROWSER}") ;;
        esac
    fi

    echo "--> Installing desktop packages (--no-install-recommends): ${PKGS[*]}..."
    apt-get install -y --no-install-recommends \
        -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
        "${PKGS[@]}"

    echo "--> Enabling ${DISPLAY_MANAGER:-sddm} display manager..."
    if [[ "${ENABLE_SDDM_SERVICE:-true}" == "true" ]]; then
        systemctl enable sddm.service || true
    fi

    echo "--> Configuring SDDM defaults..."
    mkdir -p /etc/sddm.conf.d
    {
        echo "[Theme]"
        echo "Current=breeze"
        echo
        echo "[Users]"
        echo "MaximumUid=60000"
        echo "MinimumUid=1000"
        echo
        echo "[General]"
        echo "DisplayServer=x11"
        if [[ -n "${DEFAULT_SESSION:-}" ]]; then
            echo
            echo "[Autologin]"
            echo "Session=${DEFAULT_SESSION}"
            if [[ "${AUTOLOGIN:-false}" == "true" ]]; then
                echo "User=${SABLE_DEFAULT_USER:-sable}"
            fi
        fi
    } > /etc/sddm.conf.d/sable.conf

    echo "=========================================================="
    echo " [Milestone 15] Applying Sable Desktop Customizations & Zsh"
    echo "=========================================================="

    # 2. Install Konsole profiles and color schemes
    mkdir -p /usr/share/konsole /etc/skel/.local/share/konsole
    if [[ -f "${CONFIG_DIR}/desktop/zsh/SableGreen.colorscheme" ]]; then
        cp "${CONFIG_DIR}/desktop/zsh/SableGreen.colorscheme" /usr/share/konsole/
        cp "${CONFIG_DIR}/desktop/zsh/SableGreen.colorscheme" /etc/skel/.local/share/konsole/
    fi
    if [[ -f "${CONFIG_DIR}/desktop/zsh/SableGreen.profile" ]]; then
        cp "${CONFIG_DIR}/desktop/zsh/SableGreen.profile" /usr/share/konsole/
        cp "${CONFIG_DIR}/desktop/zsh/SableGreen.profile" /etc/skel/.local/share/konsole/
    fi

    # 3. Install Zsh configuration into skel
    if [[ -f "${CONFIG_DIR}/desktop/zsh/zshrc" ]]; then
        cp "${CONFIG_DIR}/desktop/zsh/zshrc" /etc/skel/.zshrc
        cp "${CONFIG_DIR}/desktop/zsh/zshrc" /root/.zshrc
    fi

    # 4. Install KDE plasma desktop configurations into skel
    mkdir -p /etc/skel/.config
    if [[ -d "${CONFIG_DIR}/desktop/kde" ]]; then
        cp -a "${CONFIG_DIR}/desktop/kde/." /etc/skel/.config/
    fi

    # 5. Apply configurations to user 'sable'
    if id sable >/dev/null 2>&1; then
        echo "--> Applying desktop configurations to user 'sable'..."
        mkdir -p /home/sable/.config /home/sable/.local/share/konsole /home/sable/.local/share/plasma/plasmoids
        
        if [[ -d "${CONFIG_DIR}/desktop/kde" ]]; then
            cp -a "${CONFIG_DIR}/desktop/kde/." /home/sable/.config/
        fi
        if [[ -f "${CONFIG_DIR}/desktop/zsh/zshrc" ]]; then
            cp "${CONFIG_DIR}/desktop/zsh/zshrc" /home/sable/.zshrc
        fi
        if [[ -f "${CONFIG_DIR}/desktop/zsh/SableGreen.colorscheme" ]]; then
            cp "${CONFIG_DIR}/desktop/zsh/SableGreen.colorscheme" /home/sable/.local/share/konsole/
        fi
        if [[ -f "${CONFIG_DIR}/desktop/zsh/SableGreen.profile" ]]; then
            cp "${CONFIG_DIR}/desktop/zsh/SableGreen.profile" /home/sable/.local/share/konsole/
        fi
        if [[ "${SABLE_INSTALL_THIRD_PARTY_THEMES:-false}" == "true" && -d "${CONFIG_DIR}/desktop/share/plasma/plasmoids/luisbocanegra.cursor.eyes" ]]; then
            cp -a "${CONFIG_DIR}/desktop/share/plasma/plasmoids/luisbocanegra.cursor.eyes" /home/sable/.local/share/plasma/plasmoids/
        fi

        # Change default shell to zsh
        if command -v zsh >/dev/null 2>&1; then
            chsh -s "$(which zsh)" sable 2>/dev/null || true
            chsh -s "$(which zsh)" root 2>/dev/null || true
        fi

        chown -R sable:sable /home/sable
    fi

    echo "=========================================================="
    echo " Sable Desktop & Custom Environment applied successfully!"
    echo "=========================================================="
}

if [[ -f "/etc/sable/release" ]]; then
    # Running inside chroot
    install_desktop_in_chroot
else
    # Running on host
    if [[ "${EUID}" -ne 0 ]]; then
        echo "Error: This script must be run with sudo:"
        echo "  sudo $0"
        exit 1
    fi

    echo "Invoking Desktop installation inside Sable chroot..."
    mkdir -p "${ROOTFS}/root"
    cp "${BASH_SOURCE[0]}" "${ROOTFS}/root/desktop.sh"
    chmod +x "${ROOTFS}/root/desktop.sh"

    "${SCRIPT_DIR}/chroot.sh" /root/desktop.sh
fi
