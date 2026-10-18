# ⚙️ Sable Linux — Configuration Guide

## 1. Single Source of Truth (`config/sable.conf`)

All global parameters for Sable Linux are centralized in `config/sable.conf`. Build and provisioning scripts rely solely on this file as their primary source.

```text
                 config/
                    │
              sable.conf (Master)
                    │
        ┌───────────┼───────────┐
        ↓           ↓           ↓
      base/      desktop/    branding/
        │           │           │
        └───────────┼───────────┘
                    ↓
                 scripts/
                    ↓
                 rootfs/
```

---

## 2. Directory Structure of `config/`

```text
config/
├── sable.conf               # Global variables and system identity
│
├── base/
│   ├── packages.list        # Base CLI package list
│   ├── services.conf        # Enabled/disabled services for Base
│   └── system.conf          # Default parameters (locale, timezone, user)
│
├── desktop/
│   ├── packages.list        # Graphical KDE Plasma + SDDM packages
│   ├── plasma.conf          # Desktop session and display manager configuration
│   └── defaults.conf        # Desktop settings (bluetooth, autologin, etc.)
│
└── branding/
    ├── branding.conf        # Names, accent colors, and asset specifications
    └── assets/              # Reserved directory for logos, icons, and ASCII art
```

---

## 3. `.list` File Convention

Unlike shell configuration files, package lists use plain text `.list` files (`config/base/packages.list`, `config/desktop/packages.list`):
- Comments start with `#` and are ignored.
- Blank lines are ignored.
- No arbitrary shell code is executed during parsing.

---

## 4. Key Variable Reference (`sable.conf`)

| Variable | Example | Description |
|---|---|---|
| `SABLE_NAME` | `"Sable Linux"` | Official operating system name |
| `SABLE_ID` | `"sable"` | FHS-compliant identifier for `/etc/os-release` |
| `SABLE_VERSION` | `"0.6.0"` | Current semantic version |
| `SABLE_CODENAME` | `"Nightfall"` | Release codename |
| `SABLE_URL` | `"https://github.com/..."` | Project repository URL |
| `DEBIAN_SUITE` | `"trixie"` | Upstream Debian suite (13) |
| `DEBIAN_ARCH` | `"amd64"` | Target architecture |
| `SABLE_PROFILE` | `"desktop"` | Profile to build (`base` or `desktop`) |
| `SABLE_DESKTOP` | `"kde"` | Default desktop environment |
| `SABLE_ENABLE_SSH` | `"false"` | SSH disabled by default for security |
| `SABLE_ALLOW_ROOT_LOGIN` | `"false"` | Disables direct root login |
| `SABLE_CREATE_DEV_USER` | `"false"` | Disables default credentials in release base; installer sets end-user credentials |
