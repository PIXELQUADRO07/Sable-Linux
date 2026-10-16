<p align="center">
  <img src="https://github.com/user-attachments/assets/b0e42e6c-5611-487b-9ecc-e7ff10914800" alt="Sable Linux logo" width="280" />
</p>

# Sable Linux

> An independent Debian-based operating system distribution with a custom build system, identity, branding, package ecosystem, Calamares installer, and KDE Plasma desktop environment.

Sable Linux is designed to offer a clean, curated Linux experience based on Debian while keeping the entire system build process tailored to a unique project structure and workflow.

## Overview

Sable Linux combines:

- Debian 13 (Trixie) as the base system
- `systemd` as the init system
- `APT` as the package manager
- `KDE Plasma` as the desktop environment
- `Calamares` as the graphical system installer with optional netinstall groups
- A staged build pipeline generating hybrid live ISO release artifacts

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
      sable-0.6.0.iso           sable.img
      (Release Live ISO)         (Dev Disk)
              │                     │
           QEMU / Hardware       QEMU Dev
```

## Project identity

- Name: `Sable Linux`
- Version: `0.6.0`
- Codename: `Nightfall`
- Architecture: `amd64`
- Base: `Debian 13 (Trixie)`
- Init: `systemd`
- Package manager: `APT`
- Desktop: `KDE Plasma`

## Quick start

Make sure the required build dependencies are installed on your host system:

```bash
# On Fedora
sudo dnf install debootstrap squashfs-tools xorriso grub2-tools-extra grub2-pc-modules grub2-efi-x64-modules mtools dosfstools qemu-system-x86 edk2-ovmf

# On Debian / Ubuntu
sudo apt install debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools dosfstools qemu-system-x86 ovmf
```

### 1. Build the complete system and Hybrid Live ISO

Run the staged build orchestrator:

```bash
sudo ./build.sh --iso
```

Command options:
- `--iso`: Build the hybrid live ISO (`build/sable-0.6.0-live-amd64.iso`, default release artifact).
- `--image`: Optionally generate the raw development disk image (`build/sable.img`).
- `--clean`: Wipe rootfs and rebuild from scratch.

### 2. Test in QEMU

Launch the live ISO in QEMU:

```bash
./scripts/qemu.sh --iso
```

Or run automated static and ISO smoke tests:

```bash
bash ./scripts/test-static.sh
bash ./scripts/test-iso.sh
```

### 3. Manual chroot access

```bash
sudo ./scripts/mount.sh
sudo ./scripts/chroot.sh
sudo ./scripts/mount.sh -u
```

## Repository structure

```text
Sable-Linux/
├── README.md
├── LICENSE
├── .gitignore
├── build.sh
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
│   ├── calamares/
│   │   ├── settings.conf
│   │   ├── modules/
│   │   └── branding/
│   ├── live/
│   └── branding/
│       ├── branding.conf
│       └── assets/
├── scripts/
│   ├── bootstrap.sh
│   ├── mount.sh
│   ├── chroot.sh
│   ├── configure.sh
│   ├── desktop.sh
│   ├── grub.sh
│   ├── image.sh
│   ├── iso.sh
│   ├── qemu.sh
│   ├── test-static.sh
│   └── test-iso.sh
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
