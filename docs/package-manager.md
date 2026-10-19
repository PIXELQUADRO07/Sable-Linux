# Sable Package Manager

`sable-pkg` è l'interfaccia a riga di comando per la gestione dei
pacchetti in Sable Linux.

## Requisiti

- Bash
- APT
- dpkg
- sudo per le operazioni amministrative

## Comandi

| Comando | Descrizione |
|---|---|
| `sable-pkg help` | Mostra l'aiuto |
| `sable-pkg version` | Mostra la versione |
| `sable-pkg update` | Aggiorna gli indici APT |
| `sable-pkg search TERMINE` | Cerca pacchetti |
| `sable-pkg info PACCHETTO` | Mostra i metadati |
| `sable-pkg install PACCHETTO` | Installa pacchetti |
| `sable-pkg remove PACCHETTO` | Rimuove pacchetti |
| `sable-pkg upgrade` | Aggiorna i pacchetti installati |
| `sable-pkg list-installed` | Elenca i pacchetti installati |

## Architettura

`sable-pkg` è un'interfaccia personalizzata. APT gestisce i repository,
il download e la risoluzione delle dipendenze; dpkg gestisce
l'installazione e lo stato dei pacchetti `.deb`.

## Sviluppo

La prima versione è sperimentale. Provare le operazioni amministrative
in una macchina virtuale prima di usarle su un sistema reale.
