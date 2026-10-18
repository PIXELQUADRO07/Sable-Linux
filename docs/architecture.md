# 🏛️ Sable Linux — System Architecture

## 1. Overview
Sable Linux is an independent GNU/Linux distribution built on a Debian (Trixie) base, engineered with its own build system, modular configuration, distinct visual identity, and KDE Plasma desktop environment.

---

## 2. Layered Architecture

```text
+-------------------------------------------------------------+
|                     Sable Applications                       |
|          (sable-info, sable-update, sable-config)           |
+-------------------------------------------------------------+
|                     Sable Desktop Profile                   |
|         (KDE Plasma, SDDM, Wayland, PipeWire Audio)         |
+-------------------------------------------------------------+
|                      Sable Base Profile                      |
|       (systemd, NetworkManager, user management, sudo)      |
+-------------------------------------------------------------+
|                      Debian 13 Upstream                      |
|          (Linux Kernel, glibc, dpkg, APT, coreutils)        |
+-------------------------------------------------------------+
```

---

## 3. Profile Architecture

Sable adopts a profile-based architecture configured via `SABLE_PROFILE`:

1. **`base` Profile (Minimal CLI):**
   - Designed for server, container, or diagnostic installations.
   - Provides exclusively core packages, networking (`NetworkManager`), and security hardening.
   - No display server or display manager loaded.

2. **`desktop` Profile (KDE Plasma):**
   - Built as a clean extension of the `base` profile.
   - Includes standard KDE Plasma, SDDM display manager, PipeWire audio stack, and Wayland integration.

---

## 4. Installed System Namespace (`/etc/sable/`)

To comply with FHS and Debian conventions without scattering customization settings:
- **Standard Debian/Upstream configurations:** remain in canonical paths (`/etc/systemd/`, `/etc/network/`, `/etc/apt/`).
- **Sable Dedicated Namespace (`/etc/sable/`):**
  - `/etc/sable/release`: Release name (`Sable Linux`).
  - `/etc/sable/version`: Semantic version (`0.6.0`).
  - `/etc/sable/codename`: Release codename (`Nightfall`).
  - `/etc/sable/build-info`: Timestamp, build host, and compiled profile.
  - `/etc/sable/config/`: Snapshot of the system configuration used during build.

---

## 5. Build Configuration vs System Configuration Separation

- **Build Configuration (`config/` in host repository):**
  Defines *how to build* the system (Debian mirror, suite, architecture, enabled profiles, packages to download).
- **System Configuration (`/etc/` and `/etc/sable/` in rootfs):**
  Defines *how the system behaves* at runtime when booted by the user (active services, users, hostname, themes).

---

## 6. User Lifecycle & Security Model

Sable Linux enforces strict privilege and credential separation:
- **Base Rootfs & Release Deliverable:** Built with `SABLE_CREATE_DEV_USER="false"`. No development accounts or default credentials exist in the base system or release squashfs.
- **Live ISO Session:** Boots an ephemeral `live` user. SDDM autologin and temporary sudoers rules are scoped strictly to the live media.
- **Target Installation:** The Calamares installer prompts the end user for account credentials. During execution, Calamares provisions the real user and runs a final cleanup (`shellprocess@cleanup`) that purges live autologin, live sudoers entries (`/etc/sudoers.d/00-*`), and installer shortcuts.
- **Development Disk Image (`sable.img`):** An optional raw disk image where a local development user can be provisioned for rapid iteration.

