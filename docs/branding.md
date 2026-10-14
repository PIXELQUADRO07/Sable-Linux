# 🎨 Sable Linux — Branding Guidelines

## 1. Identity and Naming Significance

- **Name:** Sable Linux
- **Mascot:** Sable (*Martes zibellina*) — an elegant, agile animal resilient to severe environments, symbolizing precision and speed.
- **Main Motif:** Sable Paw (paw print / paw icon).
- **Codename (v0.1):** *Nightfall* (the transition towards refined nocturnal shades).

---

## 2. Color Palette (Concept)

| Role | Color Name | Hex Code | Usage |
|---|---|---|---|
| Dark Base | Nightfall Charcoal | `#1e1e2e` | Terminal, system bars, Plymouth |
| Primary Accent | Cool Ice Blue | `#7aa2f7` | Buttons, sliders, active highlights |
| Secondary Accent | Twilight Violet | `#bb9af7` | Badges, graphs, contrast elements |

---

## 3. Official Graphic Assets

Official vector assets and ASCII artwork are stored in `config/branding/assets/`:

- **Primary Logo (`sable-linux-logo.svg` / `logo.svg`):**
  Full high-resolution logo featuring the sable paw and stylized `SABLE LINUX` wordmark. Used for Plymouth boot splash, SDDM display manager, Calamares welcome screen, and documentation.
- **Light Paw Symbol (`sable-paw-symbol.svg`):**
  Light background symbol variant for paper, light documentation, and light banners.
- **Inverted Dark Paw Symbol (`sable-paw-symbol-inverted.svg`):**
  Dark background symbol variant. Used as main application icon, system launcher icon (`/usr/share/icons/hicolor/scalable/apps/sable-logo.svg`), and KDE menu icon.
- **Official ASCII Art (`ascii-paw.txt`):**
  Stylized ASCII sable paw print used in `/etc/motd` on shell login and in the `fastfetch` banner (`/etc/fastfetch/config.jsonc`).

Visual variables and path specifications reside in `config/branding/branding.conf`.
