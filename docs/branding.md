# 🎨 Sable Linux — Linee Guida di Branding

## 1. Identità e Significato del Nome

- **Nome:** Sable Linux
- **Mascotte:** Lo Zibellino (*Martes zibellina* / Sable) — animale elegante, agile, resistente agli ambienti freddi e severi, simbolo di precisione e dinamicità.
- **Motif Principale:** Zampa dello zibellino (impronta / paw icon).
- **Codename della v0.1:** *Nightfall* (l'imbrunire, transizione verso tonalità notturne raffinate).

---

## 2. Tavolozza Colori (Concept)

| Ruolo | Colore | Codice Esadecimale | Utilizzo |
|---|---|---|---|
| Base Scura | Nightfall Charcoal | `#1e1e2e` | Terminale, barre di sistema, Plymouth |
| Accento Primario | Cool Ice Blue | `#7aa2f7` | Pulsanti, cursori, evidenziazioni attive |
| Accento Secondario | Twilight Violet | `#bb9af7` | Badge, grafici, elementi di contrasto |

---

## 3. Risorse Grafiche Ufficiali Registrate

Le risorse vettoriali ufficiali e l'arte ASCII sono archiviate in `config/branding/assets/`:

- **Logo Primario (`sable-linux-logo.svg` / `logo.svg`):**
  Logo completo ad alta risoluzione con la zampa dello zibellino e la dicitura stilizzata `SABLE LINUX`. Ideale per Plymouth boot splash, SDDM display manager, benvenuto nell'installer Calamares e documentazione.
- **Simbolo Zampa Chiara (`sable-paw-symbol.svg`):**
  Rappresentazione del simbolo su sfondo bianco/chiaro per contesti cartacei, documentazione chiara o banner chiari.
- **Simbolo Zampa Scura Invertita (`sable-paw-symbol-inverted.svg`):**
  Rappresentazione del simbolo su sfondo scuro. Utilizzata come icona applicazione principale, icona launcher di sistema (`/usr/share/icons/hicolor/scalable/apps/sable-logo.svg`) e icona del menu KDE.
- **ASCII Art Ufficiale (`ascii-paw.txt`):**
  Disegno ASCII stilizzato dell'impronta dello zibellino utilizzato nel `/etc/motd` all'accesso alla shell e nel banner informativo di `fastfetch` (`/etc/fastfetch/config.jsonc`).

La configurazione delle variabili visive e dei percorsi risiede in `config/branding/branding.conf`.
