# 🐾 Sable Linux

> **Sable Linux** is an independent Debian-based operating system distribution featuring its own build system, identity, branding, package ecosystem, and KDE Plasma desktop environment.

---

## 🎯 Target Architecture

```text
                         SABLE LINUX
                              │
              ┌───────────────┴───────────────┐
              │                               │
          Sable Base                     Sable Desktop
              │                               │
         Debian base                       KDE Plasma
              │                               │
        Sable packages                  Sable packages
              │                               │
              └───────────────┬───────────────┘
                              │
                         Sable Build
                              │
                    ┌─────────┴─────────┐
                    │                   │
               sable.iso          sable.img
                    │                   │
                 QEMU              Hardware
```

## 📋 Project Identity

- **Name:** Sable Linux
- **Version:** `0.1.0`
- **Codename:** Nightfall
- **Architecture:** `amd64`
- **Base:** Debian 13 (Trixie)
- **Init:** systemd
- **Package Manager:** APT
- **Desktop:** KDE Plasma

## 🚀 Quick Start

Ensure build prerequisites are installed on your host system:
```bash
sudo dnf install debootstrap  # Fedora
# or: sudo apt install debootstrap  # Debian/Ubuntu
```

### 1. Bootstrap Debian Base
```bash
sudo ./scripts/bootstrap.sh
```

### 2. Enter Sable Chroot Environment
```bash
sudo ./scripts/mount.sh
sudo ./scripts/chroot.sh
```

### 3. Cleanup Mounts
```bash
sudo ./scripts/mount.sh -u
```

## 📁 Repository Structure

```text
Sable-linux/
├── README.md
├── LICENSE
├── .gitignore
├── config/
│   ├── sable.conf
│   ├── base/
│   │   ├── packages.list
│   │   ├── services.conf
│   │   └── system.conf
│   ├── desktop/
│   │   ├── packages.list
│   │   ├── plasma.conf
│   │   └── defaults.conf
│   └── branding/
│       ├── branding.conf
│       └── assets/
├── scripts/
│   ├── bootstrap.sh
│   ├── mount.sh
│   ├── chroot.sh
│   └── configure.sh
├── packages/
│   ├── sable-base/
│   ├── sable-branding/
│   └── sable-settings/
├── rootfs/
├── build/
├── iso/
└── docs/
    ├── architecture.md
    ├── configuration.md
    ├── branding.md
    ├── development.md
    └── roadmap.md
```

## 📖 Documentation

- [Architecture Guide](docs/architecture.md)
- [Configuration Reference](docs/configuration.md)
- [Branding Guidelines](docs/branding.md)
- [Development Workflow](docs/development.md)
- [Full Development Roadmap](docs/roadmap.md)

---
*Built with passion for a clean, tailored Linux experience.*
