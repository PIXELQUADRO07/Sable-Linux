# 🐾 Sable Linux — Full Development Roadmap

## Obiettivo finale

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

Il processo di build automatizzato finale è:

```bash
git clone <Sable repository>
cd Sable-linux
sudo ./build.sh --iso
# -> build/sable-0.5.0-live-amd64.iso
```

---

## Filosofia del Progetto

Sable non è semplicemente:
`Debian + wallpaper + logo`

È una distribuzione Debian-based con un proprio sistema di build, configurazione, branding, selezione software, installer Calamares, repository e release system:

- **Base upstream:** Debian 13 (Trixie) con Linux kernel, systemd, glibc, dpkg, APT.
- **Sable layer:** configurazione, branding, installer Calamares (con moduli personalizzati e netinstall opzionale), release system.

---

## Roadmap Completa

| # | Milestone | Descrizione | Stato |
|---|---|---|---|
| **0** | **Definizione progetto** | Configurazione iniziale `config/sable.conf` | 🟢 Completato |
| **1** | **Repository** | Struttura directory, `.gitignore`, documentazione di base | 🟢 Completato |
| **2** | **Debian bootstrap** | Bootstrap minimale con `debootstrap` (Debian 13 Trixie) | 🟢 Completato |
| **3** | **Verifica rootfs** | Controllo filesystem e `/etc/os-release`, `/etc/debian_version` | 🟢 Completato |
| **3.5** | **Architettura & Configurazione** | SSOT `sable.conf`, liste `.list`, profili base/desktop, branding | 🟢 Completato |
| **4** | **CHROOT environment** | Setup mount virtuali (`/dev`, `/proc`, `/sys`, `/run`) e DNS | 🟢 Completato |
| **5** | **Configurazione Debian** | Aggiornamento pacchetti base APT (`export LC_ALL=C`) | 🟢 Completato |
| **6** | **Sable identity** | Personalizzazione `/etc/os-release`, `/etc/hostname`, `/etc/sable` | 🟢 Completato |
| **7** | **Utente + sudo** | Creazione utente predefinito `sable` e sudoers | 🟢 Completato |
| **8** | **Primo sistema CLI** | Pacchetti essenziali per shell e networking base | 🟢 Completato |
| **9** | **Kernel** | Installazione `linux-image-amd64` | 🟢 Completato |
| **10** | **GRUB** | Configurazione pacchetti GRUB (`grub-pc-bin`, `grub-efi-amd64-bin`, `grub-efi-amd64-signed`, `shim-signed`, `os-prober`) | 🟢 Completato |
| **11** | **Primo boot QEMU** | Creazione disco `sable.img` e test boot su QEMU | 🟢 Completato |
| **12** | **Networking** | NetworkManager attivo e configurato | 🟢 Completato |
| **13** | **SSH** | Server OpenSSH (disabilitato di default in `sable.conf`) | 🟡 Opzionale |
| **14** | **KDE Plasma** | Installazione `kde-plasma-desktop` e display manager `sddm` | 🟢 Completato |
| **15** | **Sable Desktop** | Temi KDE, wallpaper, icone, Zsh/Konsole profile, look & feel | 🟢 Completato |
| **16** | **Branding completo** | Loghi ufficiali SVG, MOTD con ASCII paw, fastfetch | 🟢 Completato |
| **17** | **Sable packages** | Scheletro pacchetti `.deb` dedicati (`sable-base`, `sable-branding`, `sable-settings`) | 🟡 In corso |
| **18** | **Sable tools** | Utility CLI proprie (`sable-info`, `sable-update`, `sable-config`) | ⬜ Da fare |
| **19** | **Automated build** | Orchestratore `./build.sh` integrato a stadi | 🟢 Completato |
| **20** | **Podman build environment** | Containerfile per build riproducibili e isolate | ⬜ Da fare |
| **21** | **ISO Live** | Generazione ISO avviabile ibrida BIOS/UEFI | 🟢 Completato |
| **22** | **Live environment** | Modalità live con utente `live`, Plymouth splash, e launcher "Install Sable" | 🟢 Completato |
| **23** | **Calamares** | Installer grafico Calamares con moduli personalizzati e netinstall YAML | 🟢 Completato |
| **24** | **Sable repository** | Repository APT dedicato per aggiornamenti downstream | ⬜ Da fare |
| **25** | **Updates system** | Flusso di manutenzione pacchetti upstream Debian + Sable repo | ⬜ Da fare |
| **26** | **Automated tests** | Test automatici (`test-static.sh`, `test-iso.sh`) | 🟢 Completato |
| **27** | **Hardware testing** | Test bare-metal (Wi-Fi, GPU Intel Arc, Audio, Sleep, Touchpad) | ⬜ Da fare |
| **28** | **Release candidate** | Versioning semantico `0.9.x` RC | ⬜ Da fare |
| **29** | **Sable 1.0** | Rilascio stabile Sable Linux 1.0 "Nightfall" | ⬜ Da fare |
