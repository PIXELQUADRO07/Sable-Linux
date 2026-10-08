# 🛠️ Sable Linux — Guida allo Sviluppo

Questa guida descrive i prerequisiti, il flusso di lavoro e le istruzioni operative per sviluppare Sable Linux sul sistema host.

---

## 1. Prerequisiti Host

Il sistema di sviluppo consigliato è Linux (es. Fedora, Debian o Ubuntu).

### Fedora
```bash
sudo dnf install debootstrap qemu-system-x86 podman
```

### Debian / Ubuntu
```bash
sudo apt install debootstrap qemu-system-x86 podman
```

---

## 2. Flusso Operativo Iniziale

### Milestone 0 & 1: Configurazione e Struttura
Tutti i parametri centrali del sistema risiedono in `config/sable.conf`:
- `SABLE_NAME`
- `SABLE_VERSION`
- `SABLE_CODENAME`
- `DEBIAN_SUITE` (predefinito: `trixie`)
- `DEBIAN_ARCH` (predefinito: `amd64`)
- `DEBIAN_MIRROR` (predefinito: `https://deb.debian.org/debian`)

### Milestone 2: Esecuzione Bootstrap
Lo script `./scripts/bootstrap.sh` si occupa di inizializzare il filesystem di base minimale tramite `debootstrap --variant=minbase`.

```bash
sudo ./scripts/bootstrap.sh
```

### Milestone 4 & 5: Gestione Chroot
Per accedere alla shell dell'ambiente Sable isolato:

1. **Montare i filesystem virtuali e DNS:**
   ```bash
   sudo ./scripts/mount.sh
   ```

2. **Entrare nel chroot:**
   ```bash
   sudo ./scripts/chroot.sh
   ```

3. **Operare all'interno del chroot:**
   ```bash
   export HOME=/root
   export LC_ALL=C
   apt update
   apt upgrade
   ```

4. **Uscita e smontaggio pulito:**
   ```bash
   exit
   sudo ./scripts/mount.sh -u
   ```

---

## 3. Convenzioni Git
- Ogni modifica o avanzamento di milestone deve avere un proprio commit atomico e descrittivo.
- Non eseguire push non verificati sulla cronologia remota principale.
