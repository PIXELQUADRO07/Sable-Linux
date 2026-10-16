# 🐾 Sable Linux — Comprehensive Development Roadmap

## Architecture Overview

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
                sable-0.6.0.iso         sable.img
                (Release Live ISO)      (Dev Disk Image)
                        │                   │
                 QEMU / Hardware         QEMU Dev
```

Standard automated build workflow:

```bash
git clone https://github.com/PIXELQUADRO07/Sable-Linux.git
cd Sable-Linux
sudo ./build.sh
# Generates release artifact: build/sable-0.6.0-live-amd64.iso
```

---

## Project Philosophy

Sable Linux is not merely `Debian + wallpaper + logo`.

It is an independent distribution built upon Debian 13 (Trixie), featuring:
- Dedicated **Single Source of Truth** (`config/sable.conf`) and modular config hierarchy.
- Custom visual identity: sable mascot (*Martes zibellina*), paw motif, dark Nightfall palette (`#1e1e2e`), and handcrafted ASCII banners.
- Custom desktop: KDE Plasma with Sweet dark theme, candy-icons, eye-tracking plasmoid, and customized Zsh terminal environment.
- Calamares graphical installer with live autologin, welcome slideshow, branding, and optional network installation profiles.
- Integrated master build orchestrator (`build.sh`) producing both live hybrid ISOs and raw dev images.

---

## Milestone Progress Summary

| Phase | Description | Milestones | Status |
|---|---|---|---|
| **Phase 1** | Foundation, Identity & Base System | M0 – M8 | 🟢 **100% Completed** |
| **Phase 2** | Kernel, Bootloader & First Boot | M9 – M11 | 🟢 **100% Completed** |
| **Phase 3** | Networking & Connectivity | M12 – M13 | 🟢 **100% Completed** |
| **Phase 4** | Desktop Environment & Customizations | M14 – M16 | 🟢 **100% Completed** |
| **Phase 5** | Dedicated Debian Packages & Tools | M17 – M18 | 🟡 **In Progress** |
| **Phase 6** | Build Automation & Containerization | M19 – M20 | 🟡 **Partially Completed** |
| **Phase 7** | Live ISO & Calamares Installer | M21 – M23 | 🟢 **100% Completed** |
| **Phase 8** | Testing, Infrastructure & 1.0 Release | M24 – M29 | 🟡 **In Progress** |

---

## Detailed Milestone Status

| # | Milestone | Scope & Deliverables | Status | Notes |
|---|---|---|---|---|
| **0** | **Project Definition** | Centralized configuration in `config/sable.conf` (SSOT) | 🟢 Completed | Sourced by all build scripts |
| **1** | **Repository Structure** | Directory tree, `.gitignore`, documentation files | 🟢 Completed | Rootfs ignored, structure defined |
| **2** | **Debian Bootstrap** | Minimal debootstrap using Debian 13 (Trixie) `minbase` | 🟢 Completed | `scripts/bootstrap.sh` |
| **3** | **Rootfs Verification** | Verification of `/etc/os-release` and Debian version | 🟢 Completed | Base rootfs validated |
| **3.5** | **Modular Configuration** | Config split into `base/`, `desktop/`, `branding/` | 🟢 Completed | Plain-text `.list` package files |
| **4** | **Chroot Environment** | Virtual mounts (`/proc`, `/sys`, `/dev`, `/run`) & DNS resolver | 🟢 Completed | `scripts/mount.sh`, `scripts/chroot.sh` |
| **5** | **Base Configuration** | APT updates, locale (`en_US.UTF-8`), timezone (`UTC`) | 🟢 Completed | `scripts/configure.sh` |
| **6** | **Sable Identity** | `/etc/os-release`, `/etc/sable/`, `/etc/hostname` setup | 🟢 Completed | System branded as Sable Linux |
| **7** | **User Management** | Default user `sable` with sudo permissions | 🟢 Completed | Passwordless sudo configured |
| **8** | **Initial CLI System** | Core packages (`fastfetch`, `curl`, `wget`, `network-manager`) | 🟢 Completed | Verified in chroot |
| **9** | **Linux Kernel** | Kernel `linux-image-amd64` and `initramfs-tools` | 🟢 Completed | `scripts/kernel.sh` |
| **10** | **GRUB Bootloader** | `grub-pc-bin`, `grub-efi-amd64-bin`, `shim-signed` packages | 🟢 Completed | `scripts/grub.sh` |
| **11** | **First QEMU Boot** | 8GB raw disk image generation (`build/sable.img`) | 🟢 Completed | Successfully booted in QEMU |
| **12** | **Networking** | NetworkManager active and operational at boot | 🟢 Completed | Confirmed with ping and nmcli |
| **13** | **OpenSSH Server** | Remote access for development | 🟡 Optional | Disabled by default in policy |
| **14** | **KDE Plasma Desktop** | Complete `kde-standard`, `sddm`, PipeWire, Wayland, Mesa | 🟢 Completed | `scripts/desktop.sh` |
| **15** | **Sable Desktop Styling** | Sweet dark theme, Candy icons, mouse-tracking eye plasmoid, Zsh terminal with matrix green palette, git commit counter, and right-aligned clock | 🟢 Completed | `config/desktop/` and `scripts/desktop.sh` |
| **16** | **Complete Branding** | Official high-res SVG logos, paw icons, small ASCII art for `fastfetch` and login banners | 🟢 Completed | `config/branding/assets/` |
| **17** | **Sable Debian Packages** | Native `.deb` packages (`sable-base`, `sable-branding`, `sable-settings`) | 🟡 In Progress | Directory skeletons created in `packages/` |
| **18** | **Sable CLI Utilities** | Custom system tools: `sable-info`, `sable-update`, `sable-config` | ⬜ To do | Scheduled for Milestone 18 |
| **19** | **Automated Master Build** | 7-stage master orchestrator `./build.sh` with visual progress bar and centralized logging | 🟢 Completed | `build.sh` |
| **20** | **Podman Container Environment** | `Containerfile` for rootless, reproducible builds on any host | ⬜ To do | Container isolation workflow |
| **21** | **Live Hybrid ISO** | Bootable BIOS + UEFI live ISO with zstd/xz squashfs | 🟢 Completed | `scripts/iso.sh` |
| **22** | **Live Session & Plymouth** | Autologin for `live` user, splash screen, launcher icon | 🟢 Completed | `config/live/` and `scripts/iso.sh` |
| **23** | **Calamares Installer** | Full graphical installer with branded slides and optional netinstall software packages | 🟢 Completed | `config/calamares/` |
| **24** | **Sable APT Repository** | Dedicated Debian package repository (reprepro / aptly) | ⬜ To do | Infrastructure for updates |
| **25** | **Update System** | Upstream Debian synchronization and downstream package maintenance | ⬜ To do | Package lifecycle management |
| **26** | **Automated Smoke Tests** | Test suite verifying ISO boot in UEFI and BIOS mode headless | 🟢 Completed | `scripts/test-static.sh`, `scripts/test-iso.sh` |
| **27** | **Hardware Testing** | Bare-metal tests on real hardware (Lenovo Yoga Slim 7, Intel Arc, Wi-Fi, audio) | ⬜ To do | Hardware validation matrix |
| **28** | **Release Candidate** | Version 0.9.x RC freeze and stabilization | ⬜ To do | Quality assurance release |
| **29** | **Sable Linux 1.0 Release** | Stable public release of Sable Linux "Nightfall" | ⬜ To do | Public distribution |

---

## What is Done vs What is Missing

### ✅ Completed Work (Ready & Operational)
1. **Debian 13 (Trixie) Base Engine**: Complete bootstrap, chroot management, kernel, and GRUB.
2. **System Branding**: Full identity registered (`/etc/sable/`), official vector SVGs (`sable-linux-logo.svg`, `sable-paw-symbol.svg`, `sable-paw-symbol-inverted.svg`), and compact ASCII paw art tested and formatted for `fastfetch`.
3. **KDE Plasma & Custom Environment**:
   - KDE Plasma desktop suite with SDDM display manager.
   - Sweet dark color scheme, Utterly-Round-Dark window decorations.
   - Candy icon theme and cursor theme.
   - Mouse-following eyes panel widget (`luisbocanegra.cursor.eyes`) alongside memory and CPU core load indicators.
   - Custom Zsh environment with matrix green colorscheme, git commit counter, real-time typing animation (`zsh-syntax-highlighting` + `zsh-autosuggestions`), and right-hand clock.
4. **Live System & Installer**:
   - Hybrid BIOS/UEFI bootable ISO generator using `grub2-mkrescue` and `mksquashfs`.
   - Calamares installer configured with branded slides, system installation stages, and optional netinstall software categories (Office, Development, Cybersecurity tools).
5. **Master Orchestrator**:
   - `./build.sh` master pipeline with incremental execution, progress tracking, and error logging.
   - Live ISO detection bug resolved for Debian 13 microcode-prepended initrds.

### 📋 Pending Next Steps (Missing Work)

#### 1. Milestone 17 & 18 — Native Sable Packages & CLI Tools
- Package the custom configs, themes, and branding into native `.deb` packages via `dpkg-buildpackage`:
  - `sable-base`: System configuration, `/etc/os-release`, MOTD, fastfetch config.
  - `sable-branding`: Vector assets, wallpapers, themes, icons.
  - `sable-desktop-settings`: Skel configuration for KDE Plasma and Zsh.
- Develop custom CLI utilities:
  - `sable-info`: Custom system information summary.
  - `sable-update`: Streamlined system and package updater.
  - `sable-config`: System configuration manager.

#### 2. Milestone 20 — Podman Isolated Build Environment
- Provide `containers/Containerfile` allowing non-root developers to build Sable Linux without host dependencies.

#### 3. Milestone 24 & 25 — APT Repository Infrastructure
- Set up an APT repository hosting Sable packages (e.g., via GitHub Releases/Pages or dedicated server using `reprepro`).

#### 4. Milestone 27 — Bare-Metal Hardware Testing
- Test boot and hardware drivers on physical machine (Intel Arc GPU acceleration, Wi-Fi 6E/7, PipeWire Bluetooth/Speakers, Touchpad gestures, Power management).

#### 5. Milestone 28 & 29 — Stabilization & 1.0 "Nightfall" Release
- Freeze package list, run static verification checks, and cut the 1.0 stable release ISO.
