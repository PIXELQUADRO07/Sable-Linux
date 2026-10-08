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
               sable.iso          sable.img
                    │                   │
                 QEMU              Hardware
```

Il processo di build automatizzato finale sarà:

```bash
git clone <Sable repository>
cd Sable-linux
./build.sh
# -> build/sable-1.0-amd64.iso
```

---

## Filosofia del Progetto

Sable non è semplicemente:
`Debian + wallpaper + logo`

È una distribuzione Debian-based con un proprio sistema di build, configurazione, branding, selezione software, repository e strumenti propri:

- **Base upstream:** Debian 13 (Trixie) con Linux kernel, systemd, glibc, dpkg, APT.
- **Sable layer:** configurazione, branding, pacchetti propri, installer Calamares, repository APT dedicato e release system.

---

## Roadmap Completa

| # | Milestone | Descrizione | Stato |
|---|---|---|---|
| **0** | **Definizione progetto** | Configurazione iniziale `config/sable.conf` | 🟢 Completato |
| **1** | **Repository** | Struttura directory, `.gitignore`, documentazione di base | 🟢 Completato |
| **2** | **Debian bootstrap** | Bootstrap minimale con `debootstrap` (Debian 13 Trixie) | 🟢 Completato |
| **3** | **Verifica rootfs** | Controllo filesystem e `/etc/os-release`, `/etc/debian_version` | 🟢 Completato |
| **4** | **CHROOT environment** | Setup mount virtuali (`/dev`, `/proc`, `/sys`, `/run`) e DNS | 🟡 In corso |
| **5** | **Configurazione Debian** | Aggiornamento pacchetti base APT (`export LC_ALL=C`) | ⬜ Da fare |
| **6** | **Sable identity** | Personalizzazione `/etc/os-release`, `/etc/hostname`, `/etc/sable` | ⬜ Da fare |
| **7** | **Utente + sudo** | Creazione utente predefinito `sable` e sudoers | ⬜ Da fare |
| **8** | **Primo sistema CLI** | Pacchetti essenziali per shell e networking base | ⬜ Da fare |
| **9** | **Kernel** | Installazione `linux-image-amd64` | ⬜ Da fare |
| **10** | **GRUB** | Configurazione GRUB per BIOS e UEFI | ⬜ Da fare |
| **11** | **Primo boot QEMU** | Creazione disco `sable.img` e test boot su QEMU | ⬜ Da fare |
| **12** | **Networking** | NetworkManager attivo e configurato | ⬜ Da fare |
| **13** | **SSH** | Server OpenSSH abilitato per sviluppo | ⬜ Da fare |
| **14** | **KDE Plasma** | Installazione `kde-standard` e display manager `sddm` | ⬜ Da fare |
| **15** | **Sable Desktop** | Temi KDE, wallpaper, icone, look & feel | ⬜ Da fare |
| **16** | **Branding completo** | Plymouth boot splash, SDDM theme, about screen | ⬜ Da fare |
| **17** | **Sable packages** | Creazione pacchetti `.deb` dedicati (`sable-base`, `sable-branding`) | ⬜ Da fare |
| **18** | **Sable tools** | Utility CLI proprie (`sable-info`, `sable-update`, `sable-config`) | ⬜ Da fare |
| **19** | **Automated build** | Orchestratore `./build.sh` integrato | ⬜ Da fare |
| **20** | **Podman build environment** | Containerfile per build riproducibili e isolate | ⬜ Da fare |
| **21** | **ISO Live** | Generazione ISO avviabile ibrida BIOS/UEFI | ⬜ Da fare |
| **22** | **Live environment** | Modalità live ("Try Sable" / "Install Sable") | ⬜ Da fare |
| **23** | **Calamares** | Installer grafico Calamares con moduli personalizzati | ⬜ Da fare |
| **24** | **Sable repository** | Repository APT dedicato per aggiornamenti downstream | ⬜ Da fare |
| **25** | **Updates system** | Flusso di manutenzione pacchetti upstream Debian + Sable repo | ⬜ Da fare |
| **26** | **Automated tests** | Test automatici (`test-boot.sh`, `test-os-release.sh`) | ⬜ Da fare |
| **27** | **Hardware testing** | Test bare-metal (Wi-Fi, GPU Intel Arc, Audio, Sleep, Touchpad) | ⬜ Da fare |
| **28** | **Release candidate** | Versioning semantico `0.9.x` RC | ⬜ Da fare |
| **29** | **Sable 1.0** | Rilascio stabile Sable Linux 1.0 "Nightfall" | ⬜ Da fare |
