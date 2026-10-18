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
| **Phase 5** | Dedicated Debian Packages & Tools | M17 – M18 | 🟢 **100% Completed** |
| **Phase 6** | Build Automation & Containerization | M19 – M20 | 🟢 **100% Completed** |
| **Phase 7** | Live ISO & Calamares Installer | M21 – M23 | 🟢 **100% Completed** |
| **Phase 8** | Testing, Infrastructure & 1.0 Release | M24 – M29 | 🟢 **95% Completed** |

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
| **7** | **User Management** | Secure user lifecycle: no default credentials in release base; installer sets credentials | 🟢 Completed | Scoped live sudoers with post-install cleanup |
| **8** | **Initial CLI System** | Core packages (`fastfetch`, `curl`, `wget`, `network-manager`) | 🟢 Completed | Verified in chroot |
| **9** | **Linux Kernel** | Kernel `linux-image-amd64` and `initramfs-tools` | 🟢 Completed | `scripts/kernel.sh` |
| **10** | **GRUB Bootloader** | `grub-pc-bin`, `grub-efi-amd64-bin`, `shim-signed` packages | 🟢 Completed | `scripts/grub.sh` |
| **11** | **First QEMU Boot** | 16GB raw disk image generation (`build/sable.img`) | 🟢 Completed | Successfully booted in QEMU |
| **12** | **Networking** | NetworkManager active and operational at boot | 🟢 Completed | Confirmed with ping and nmcli |
| **13** | **OpenSSH Server** | Remote access for development | 🟡 Optional | Disabled by default in policy |
| **14** | **KDE Plasma Desktop** | Complete `kde-standard`, `sddm`, PipeWire, Wayland, Mesa | 🟢 Completed | `scripts/desktop.sh` |
| **15** | **Sable Desktop Styling** | Breeze Dark theme, Breeze-dark icons, Breeze cursors, lightweight system monitor applets, custom Zsh with matrix green palette, git commit counter, and right-aligned clock | 🟢 Completed | `config/desktop/` and `scripts/desktop.sh` |
| **16** | **Complete Branding** | Official high-res SVG logos, paw icons, small ASCII art for `fastfetch` and login banners | 🟢 Completed | `config/branding/assets/` |
| **17** | **Sable Debian Packages** | Native `.deb` packages (`sable-base`, `sable-branding`, `sable-settings`) | 🟢 Completed | Full Debian source package definitions in `packages/` |
| **18** | **Sable CLI Utilities** | Custom system tools: `sable-info`, `sable-update`, `sable-config`, `sable-probe` | 🟢 Completed | Installed in `/usr/bin/` via `packages/sable-base` |
| **19** | **Automated Master Build** | 7-stage master orchestrator `./build.sh` with visual progress bar and centralized logging | 🟢 Completed | `build.sh` |
| **20** | **Podman Container Environment** | `Containerfile` for rootless, reproducible builds on any host | 🟢 Completed | `containers/Containerfile` |
| **21** | **Live Hybrid ISO** | Bootable BIOS + UEFI live ISO with zstd/xz squashfs | 🟢 Completed | `scripts/iso.sh` |
| **22** | **Live Session & Boot Theme** | Autologin for `live` user (password: `live`), official graphical GRUB theme (Nightfall) with centered logo, clean quiet boot | 🟢 Completed | `config/live/`, `config/branding/grub/`, and `scripts/iso.sh` |
| **23** | **Calamares Installer** | Full graphical installer with branded slides, cleanup sequencing, and optional netinstall software packages | 🟢 Completed | `config/calamares/` |
| **24** | **Sable APT Repository** | Dedicated Debian package repository generator (`Packages`, `Packages.gz`, `Release`) with GPG signing | 🟢 Completed | `scripts/build-repo.sh` |
| **25** | **Package Build System** | Automated builder producing native `.deb` binaries | 🟢 Completed | `scripts/build-packages.sh` |
| **26** | **Automated Smoke Tests** | Test suite verifying ISO boot in UEFI and BIOS mode headless | 🟢 Completed | `scripts/test-static.sh`, `scripts/test-iso.sh` |
| **27** | **Hardware Testing & Probe** | Hardware validation tool (`sable-probe`) detecting Intel Arc, AMD, Wi-Fi, audio | 🟢 Completed | `packages/sable-base/usr/bin/sable-probe` |
| **28** | **Release Verification Suite** | Complete automated QA check verifying 22 release integrity constraints | 🟢 Completed | `scripts/release-check.sh` |
| **29** | **Sable Linux 1.0 Release** | Stable public release of Sable Linux "Nightfall" | 🟡 RC Stage | Multi-tier tests passed; awaiting bare-metal install confirmation |

---

## What is Done vs What is Missing

### ✅ Completed Work (Ready & Operational)
1. **Debian 13 (Trixie) Base Engine**: Complete bootstrap, chroot management, kernel, and GRUB.
2. **System Branding**: Full identity registered (`/etc/sable/`), official vector SVGs (`sable-linux-logo.svg`, `sable-paw-symbol.svg`, `sable-paw-symbol-inverted.svg`), and compact ASCII paw art tested and formatted for `fastfetch`.
3. **KDE Plasma & Custom Environment**:
   - KDE Plasma desktop suite with SDDM display manager, defaulting to QEMU-safe X11 session (`plasmax11`) with full Wayland support available.
   - Breeze Dark color scheme, Breeze window decorations, Breeze-dark icon theme, and Breeze cursor theme.
   - Fixed GTK3/GTK4 style integration via `kde-config-gtk-style` and complete window decoration SVG assets.
   - Stable system monitor applets (CPU core and memory usage) arranged in logical panel order.
   - Custom Zsh environment with matrix green colorscheme, git commit counter, real-time typing animation (`zsh-syntax-highlighting` + `zsh-autosuggestions`), and right-hand clock.
4. **Live System & Installer**:
   - Hybrid BIOS/UEFI bootable ISO generator using `grub2-mkrescue` and `mksquashfs`.
   - Calamares installer configured with `sable` branding, system installation stages (`removeuser`, cleanup), and optional netinstall software categories (Office, Development, Cybersecurity tools).
   - Official graphical GRUB theme (Nightfall) featuring centered Sable logo, modern selection highlights, and quiet boot.
   - Reliable SDDM autologin with pre-created `live` user account (password: `live`) and passwordless sudo.
5. **Master Orchestrator & Containerization**:
   - `./build.sh` master pipeline with incremental execution, progress tracking, and error logging.
   - Containerized build workflow via `containers/Containerfile` (M20).
6. **Native Packaging, APT Repository & CLI Suite**:
   - Debian packaging layout for `sable-base`, `sable-branding`, and `sable-settings` (M17).
   - Automated `.deb` package builder (`scripts/build-packages.sh`) (M25).
   - Automated APT repository metadata generator (`scripts/build-repo.sh`) (M24).
   - Official CLI suite: `sable-info`, `sable-update`, `sable-config`, `sable-probe` (M18 & M27).
7. **Quality Assurance & Release Automation**:
   - Comprehensive release verification suite (`scripts/release-check.sh`) checking 22 distinct build, security, and packaging invariants (M28).

---

## Verification Levels & Assurance Matrix

To maintain rigorous engineering honesty between development prototypes and production releases, all deliverables are categorized across five verification tiers:

| Tier | Verification Level | Scope & Criteria | Status |
|---|---|---|---|
| **Tier 1** | **Implemented** | Source code, build scripts, packaging rules, and Calamares configs exist in tree. | 🟢 100% |
| **Tier 2** | **Statically Verified** | Shell syntax (`bash -n`), YAML compliance (`PyYAML`), and 32 static security/policy assertions (`scripts/test-static.sh`). | 🟢 100% |
| **Tier 3** | **Build Tested** | Complete debootstrap, chroot execution, native `.deb` builds, and APT repo indexing completed without errors. | 🟢 100% |
| **Tier 4** | **QEMU Smoke-Tested** | Automated headless QEMU serial probe boots live kernel and firmware paths (`scripts/test-iso.sh`). | 🟢 100% |
| **Tier 5** | **Bare-Metal Tested** | Live session and end-to-end disk installation verified on physical target hardware. | 🟡 In Progress |

### 📋 Next Action for 1.0 Release (Milestone 29)
1. **Bare-Metal Boot Run**:
   - Flash the generated ISO `build/sable-0.6.0-live-amd64.iso` to a USB drive with `dd` or BalenaEtcher and test live boot on physical target hardware (Lenovo Yoga Slim 7 / Intel Arc).
2. **Repository Mirror**:
   - Deploy `build/repo/` to public hosting (GitHub Pages or object storage) to enable over-the-air updates.
3. **1.0 Version Tag**:
   - Bump version from `0.6.0` to `1.0.0` when bare-metal confirmation is completed.

