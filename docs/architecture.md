# 🏛️ Sable Linux — Architettura di Sistema

## 1. Panoramica
Sable Linux è una distribuzione GNU/Linux indipendente costruita su base Debian (Trixie), ingegnerizzata con un sistema di build proprio, configurazione modulare, identità visiva distinta e ambiente desktop KDE Plasma.

---

## 2. Architettura a Livelli

```text
+-------------------------------------------------------------+
|                     Sable Applications                       |
|          (sable-info, sable-update, sable-config)           |
+-------------------------------------------------------------+
|                     Sable Desktop Profile                   |
|         (KDE Plasma, SDDM, Wayland, Audio Pipewire)         |
+-------------------------------------------------------------+
|                      Sable Base Profile                      |
|       (systemd, NetworkManager, user management, sudo)      |
+-------------------------------------------------------------+
|                      Debian 13 Upstream                      |
|          (Linux Kernel, glibc, dpkg, APT, coreutils)        |
+-------------------------------------------------------------+
```

---

## 3. Separazione dei Profili (Profile Architecture)

Sable adotta un'architettura a profili configurabile tramite `SABLE_PROFILE`:

1. **Profilo `base` (CLI Minimal):**
   - Destinato a installazioni server, container o diagnostica.
   - Fornisce esclusivamente il set fondamentale di pacchetti, networking (`NetworkManager`) e sicurezza.
   - Nessun server grafico o display manager caricato.

2. **Profilo `desktop` (KDE Plasma):**
   - Costruito come estensione pulita del profilo `base`.
   - Include KDE Plasma standard, display manager SDDM, stack audio Pipewire e integrazione Wayland.

---

## 4. Spazio dei Nomi del Sistema Installato (`/etc/sable/`)

Per rispettare le convenzioni FHS e Debian senza disperdere le informazioni di personalizzazione:
- **Configurazioni standard Debian/Upstream:** rimangono nei percorsi canonici (`/etc/systemd/`, `/etc/network/`, `/etc/apt/`).
- **Namespace dedicato Sable (`/etc/sable/`):**
  - `/etc/sable/release`: Nome della release (`Sable Linux`).
  - `/etc/sable/version`: Versione semantica (`0.1.0`).
  - `/etc/sable/codename`: Codename del rilascio (`Nightfall`).
  - `/etc/sable/build-info`: Timestamp, host di build e profilo compilato.
  - `/etc/sable/config/`: Snapshot della configurazione di sistema utilizzata durante la build.

---

## 5. Separazione tra Build Configuration e System Configuration

- **Build Configuration (`config/` nel repository host):**
  Definisce *come costruire* il sistema (mirror Debian, suite, architettura, profili da abilitare, pacchetti da scaricare).
- **System Configuration (`/etc/` e `/etc/sable/` nel rootfs):**
  Definisce *come si comporta* il sistema a runtime una volta avviato dall'utente (servizi attivi, utenti, hostname, temi).
