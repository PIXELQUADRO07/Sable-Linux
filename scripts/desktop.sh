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
        PKGS=(kde-standard sddm zsh zsh-autosuggestions zsh-syntax-highlighting pipewire pipewire-audio wireplumber xwayland libgl1-mesa-dri fonts-dejavu-core fonts-noto-core)
    fi

    echo "--> Updating APT package index..."
    apt-get update

    echo "--> Installing desktop packages: ${PKGS[*]}..."
    apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" "${PKGS[@]}"

    echo "--> Enabling SDDM display manager service..."
    systemctl enable sddm.service || true

    echo "--> Configuring SDDM defaults..."
    mkdir -p /etc/sddm.conf.d
    cat << 'EOF' > /etc/sddm.conf.d/sable.conf
[Theme]
Current=breeze

[Users]
MaximumUid=60000
MinimumUid=1000
EOF

    echo "=========================================================="
    echo " [Milestone 15] Applying Custom Sweet Theme, Candy Icons & ZSH"
    echo "=========================================================="

    # 1. Install system-wide shared assets
    if [[ -d "${CONFIG_DIR}/desktop/share" ]]; then
        echo "--> Installing themes, candy-icons, and eye-tracker plasmoid..."
        if [[ -d "${CONFIG_DIR}/desktop/share/color-schemes" ]]; then
            mkdir -p /usr/share/color-schemes
            cp -a "${CONFIG_DIR}/desktop/share/color-schemes/." /usr/share/color-schemes/
        fi
        if [[ -d "${CONFIG_DIR}/desktop/share/icons" ]]; then
            mkdir -p /usr/share/icons
            cp -a "${CONFIG_DIR}/desktop/share/icons/." /usr/share/icons/
        fi
        if [[ -d "${CONFIG_DIR}/desktop/share/aurorae" ]]; then
            mkdir -p /usr/share/aurorae
            cp -a "${CONFIG_DIR}/desktop/share/aurorae/." /usr/share/aurorae/
        fi
        if [[ -d "${CONFIG_DIR}/desktop/share/plasma/plasmoids" ]]; then
            mkdir -p /usr/share/plasma/plasmoids
            cp -a "${CONFIG_DIR}/desktop/share/plasma/plasmoids/." /usr/share/plasma/plasmoids/
        fi
    fi

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
        if [[ -d "${CONFIG_DIR}/desktop/share/plasma/plasmoids/luisbocanegra.cursor.eyes" ]]; then
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
