<p align="center">
  <img src="https://github.com/user-attachments/assets/b0e42e6c-5611-487b-9ecc-e7ff10914800" alt="Sable Linux logo" width="280" />
</p>

# Sable Linux

> An independent Debian-based operating system distribution with a custom build system, identity, branding, package ecosystem, and KDE Plasma desktop environment.

Sable Linux is designed to offer a clean, curated Linux experience based on Debian while keeping the entire system build process tailored to a unique project structure and workflow.

## Overview

Sable Linux combines:

- Debian 13 (Trixie) as the base system
- `systemd` as the init system
- `APT` as the package manager
- `KDE Plasma` as the desktop environment
- a custom build flow for creating ISO and image artifacts

## Architecture

```text
                 SABLE LINUX
                         │
         ┌───────────────┴───────────────┐
         │                               │
  Sable Base                     Sable Desktop
         │                               │
    Debian 13 (Trixie)             KDE Plasma
         │                               │
  Sable packages                 Sable packages
         │                               │
         └───────────────┬───────────────┘
                         │
                    Sable Build
                         │
              ┌──────────┴──────────┐
              │                     │
            sable.iso            sable.img
              │                     │
           QEMU / Virtualized     Hardware
```

## Project identity

- Name: `Sable Linux`
- Version: `0.1.0`
- Codename: `Nightfall`
- Architecture: `amd64`
- Base: `Debian 13 (Trixie)`
- Init: `systemd`
- Package manager: `APT`
- Desktop: `KDE Plasma`

## Quick start

Make sure the required build dependencies are installed on your host system:

```bash
sudo dnf install debootstrap   # Fedora
# or
sudo apt install debootstrap   # Debian / Ubuntu
```

### 1. Bootstrap the base system

```bash
sudo ./scripts/bootstrap.sh
```

### 2. Enter the Sable chroot environment

```bash
sudo ./scripts/mount.sh
sudo ./scripts/chroot.sh
```

### 3. Clean up mounts

```bash
sudo ./scripts/mount.sh -u
```

## Repository structure

```text
Sable-Linux/
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

## Documentation

- [Architecture Guide](docs/architecture.md)
- [Configuration Reference](docs/configuration.md)
- [Branding Guidelines](docs/branding.md)
- [Development Workflow](docs/development.md)
- [Full Development Roadmap](docs/roadmap.md)

---

Built with passion for a clean, tailored Linux experience.
