#!/usr/bin/env bash
# ==============================================================================
# Sable Linux — Chroot Configuration Script (Milestones 7 - 13)
# To be executed INSIDE the chroot (or invoked via scripts/chroot.sh)
# ==============================================================================
set -Eeuo pipefail

export HOME=/root
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

echo "=========================================================="
echo " [Milestone 7] Updating Debian Base System..."
echo "=========================================================="
apt-get update
apt-get upgrade -y

echo "=========================================================="
echo " [Milestone 8] Installing Core CLI Packages..."
echo "=========================================================="
apt-get install -y --no-install-recommends \
    systemd \
    systemd-sysv \
    sudo \
    bash \
    coreutils \
    util-linux \
    iproute2 \
    iputils-ping \
    curl \
    wget \
    ca-certificates \
    nano \
    vim-tiny \
    less \
    procps \
    psmisc

echo "=========================================================="
echo " [Milestone 9] Configuring Hostname & Hosts..."
echo "=========================================================="
echo "sable" > /etc/hostname

cat << 'EOF' > /etc/hosts
127.0.0.1       localhost
127.0.1.1       sable

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

echo "=========================================================="
echo " [Milestone 10] Applying Sable Linux Identity (/etc/os-release)..."
echo "=========================================================="
cat << 'EOF' > /etc/os-release
NAME="Sable Linux"
PRETTY_NAME="Sable Linux 0.1.0 Nightfall"
ID=sable
ID_LIKE=debian
VERSION_ID="0.1.0"
VERSION_CODENAME="nightfall"
HOME_URL="https://github.com/PIXELQUADRO07/Sable-Linux"
BUG_REPORT_URL="https://github.com/PIXELQUADRO07/Sable-Linux/issues"
EOF

echo "=========================================================="
echo " [Milestone 11] Creating /etc/sable Release Metadata..."
echo "=========================================================="
mkdir -p /etc/sable
echo "Sable Linux" > /etc/sable/release
echo "0.1.0" > /etc/sable/version
echo "Nightfall" > /etc/sable/codename

echo "=========================================================="
echo " [Milestone 12] Creating Sable MOTD..."
echo "=========================================================="
cat << 'EOF' > /etc/motd

   _____     _     _      
  / ____|   | |   | |     
 | (___  ___| |__ | | ___ 
  \___ \/ __| '_ \| |/ _ \
  ____) \__ \ |_) | |  __/
 |_____/|___/_.__/|_|\___|

 Sable Linux 0.1.0 "Nightfall"

 Welcome to Sable.

EOF

echo "=========================================================="
echo " [Milestone 13] Creating Default User 'sable'..."
echo "=========================================================="
if ! id sable >/dev/null 2>&1; then
    useradd -m -s /bin/bash sable
    echo "sable:sable" | chpasswd
    usermod -aG sudo sable
    echo "User 'sable' created with password 'sable' and sudo privileges."
else
    echo "User 'sable' already exists."
fi

echo "=========================================================="
echo " Sable base CLI environment successfully configured!"
echo "=========================================================="
