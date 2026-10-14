# 🐾 Sable Linux — Full Development Roadmap

## Target Architecture

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
            sable-0.5.0.iso         sable.img
            (Release Live ISO)      (Dev Disk)
                    │                   │
             QEMU / Hardware         QEMU Dev
```

Automated build workflow:

```bash
git clone <Sable repository>
cd Sable-linux
sudo ./build.sh --iso
# -> build/sable-0.5.0-live-amd64.iso
```

---

## Project Philosophy

Sable is not simply:
`Debian + wallpaper + logo`

It is a Debian-based distribution with its own build system, configuration, branding, software selection, Calamares installer, repository, and release system:

- **Upstream base:** Debian 13 (Trixie) with Linux kernel, systemd, glibc, dpkg, APT.
- **Sable layer:** Configuration, branding, Calamares installer (with custom modules and optional netinstall), release system.

---

## Complete Roadmap

| # | Milestone | Description | Status |
|---|---|---|---|
| **0** | **Project definition** | Initial configuration in `config/sable.conf` | 🟢 Completed |
| **1** | **Repository** | Directory structure, `.gitignore`, core docs | 🟢 Completed |
| **2** | **Debian bootstrap** | Minimal bootstrap via `debootstrap` (Debian 13 Trixie) | 🟢 Completed |
| **3** | **Rootfs verification** | Filesystem check and `/etc/os-release`, `/etc/debian_version` | 🟢 Completed |
| **3.5** | **Architecture & Configuration** | SSOT `sable.conf`, `.list` files, base/desktop profiles, branding | 🟢 Completed |
| **4** | **CHROOT environment** | Virtual mount setup (`/dev`, `/proc`, `/sys`, `/run`) and DNS | 🟢 Completed |
| **5** | **Debian configuration** | APT base package upgrades (`export LC_ALL=C`) | 🟢 Completed |
| **6** | **Sable identity** | Customization of `/etc/os-release`, `/etc/hostname`, `/etc/sable` | 🟢 Completed |
| **7** | **User + sudo** | Default user `sable` creation and sudoers setup | 🟢 Completed |
| **8** | **Initial CLI system** | Core shell packages and basic networking | 🟢 Completed |
| **9** | **Kernel** | `linux-image-amd64` installation | 🟢 Completed |
| **10** | **GRUB** | GRUB package setup (`grub-pc-bin`, `grub-efi-amd64-bin`, `grub-efi-amd64-signed`, `shim-signed`, `os-prober`) | 🟢 Completed |
| **11** | **First QEMU boot** | `sable.img` disk creation and QEMU boot testing | 🟢 Completed |
| **12** | **Networking** | Active NetworkManager configuration | 🟢 Completed |
| **13** | **SSH** | OpenSSH server (disabled by default in `sable.conf`) | 🟡 Optional |
| **14** | **KDE Plasma** | `kde-plasma-desktop` and `sddm` display manager installation | 🟢 Completed |
| **15** | **Sable Desktop** | KDE themes, wallpaper, icons, Zsh/Konsole profile, look & feel | 🟢 Completed |
| **16** | **Complete branding** | Official SVG logos, MOTD ASCII paw, fastfetch | 🟢 Completed |
| **17** | **Sable packages** | Skeleton for dedicated `.deb` packages (`sable-base`, `sable-branding`, `sable-settings`) | 🟡 In progress |
| **18** | **Sable tools** | Custom CLI utilities (`sable-info`, `sable-update`, `sable-config`) | ⬜ To do |
| **19** | **Automated build** | Stage-integrated `./build.sh` orchestrator | 🟢 Completed |
| **20** | **Podman build environment** | Containerfile for reproducible and isolated builds | ⬜ To do |
| **21** | **ISO Live** | Hybrid BIOS/UEFI bootable ISO generation | 🟢 Completed |
| **22** | **Live environment** | Live mode with `live` user, Plymouth splash, and "Install Sable" launcher | 🟢 Completed |
| **23** | **Calamares** | Graphical Calamares installer with custom modules and netinstall YAML | 🟢 Completed |
| **24** | **Sable repository** | Dedicated APT repository for downstream updates | ⬜ To do |
| **25** | **Updates system** | Maintenance flow for upstream Debian + Sable repo packages | ⬜ To do |
| **26** | **Automated tests** | Automated test scripts (`test-static.sh`, `test-iso.sh`) | 🟢 Completed |
| **27** | **Hardware testing** | Bare-metal tests (Wi-Fi, Intel Arc GPU, Audio, Sleep, Touchpad) | ⬜ To do |
| **28** | **Release candidate** | Semantic versioning `0.9.x` RC | ⬜ To do |
| **29** | **Sable 1.0** | Sable Linux 1.0 "Nightfall" stable release | ⬜ To do |
