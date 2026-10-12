# ⚙️ Sable Linux — Guida alla Configurazione

## 1. Single Source of Truth (`config/sable.conf`)

Tutti i parametri globali di Sable Linux sono accentrati in `config/sable.conf`. Gli script di compilazione e provisioning leggono unicamente questo file come sorgente primaria.

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

## 2. Struttura della directory `config/`

```text
config/
├── sable.conf               # Variabili globali e identità
│
├── base/
│   ├── packages.list        # Elenco pacchetti CLI di base
│   ├── services.conf        # Servizi abilitati e disabilitati per Base
│   └── system.conf          # Parametri di default (locale, timezone, utente)
│
├── desktop/
│   ├── packages.list        # Pacchetti grafici KDE Plasma + SDDM
│   ├── plasma.conf          # Configurazione desktop session e display manager
│   └── defaults.conf        # Impostazioni desktop (bluetooth, autologin, ecc.)
│
└── branding/
    ├── branding.conf        # Nomi, colori d'accento e specifiche grafiche
    └── assets/              # Directory riservata per loghi, icone e ASCII art
```

---

## 3. Convenzione dei File `.list`

A differenza dei file di configurazione shell, le liste dei pacchetti utilizzano file di testo piano `.list` (`config/base/packages.list`, `config/desktop/packages.list`):
- I commenti iniziano con `#` e vengono ignorati.
- Le righe vuote vengono ignorate.
- Nessun codice shell arbitrario può essere eseguito durante il parsing.

---

## 4. Riferimento Variabili Chiave (`sable.conf`)

| Variabile | Esempio | Descrizione |
|---|---|---|
| `SABLE_NAME` | `"Sable Linux"` | Nome ufficiale del sistema operativo |
| `SABLE_ID` | `"sable"` | Identificativo FHS conforme a `/etc/os-release` |
| `SABLE_VERSION` | `"0.4.0"` | Versione semantica corrente |
| `SABLE_CODENAME` | `"Nightfall"` | Nome in codice della versione |
| `SABLE_URL` | `"https://github.com/..."` | URL del progetto |
| `DEBIAN_SUITE` | `"trixie"` | Suite upstream Debian (13) |
| `DEBIAN_ARCH` | `"amd64"` | Architettura di destinazione |
| `SABLE_PROFILE` | `"desktop"` | Profilo da compilare (`base` o `desktop`) |
| `SABLE_DESKTOP` | `"kde"` | Ambiente desktop predefinito |
| `SABLE_ENABLE_SSH` | `"false"` | SSH disabilitato di default per sicurezza |
| `SABLE_ALLOW_ROOT_LOGIN` | `"false"` | Disabilita il login diretto di root |
