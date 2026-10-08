# 🎨 Sable Linux — Linee Guida di Branding

## 1. Identità e Significato del Nome

- **Nome:** Sable Linux
- **Mascotte:** Lo Zibellino (*Martes zibellina* / Sable) — animale elegante, agile, resistente agli ambienti freddi e severi, simbolo di precisione e dinamicità.
- **Motif Principale:** Zampa dello zibellino (impronta/paw icon).
- **Codename della v0.1:** *Nightfall* (l'imbrunire, transizione verso tonalità notturne raffinate).

---

## 2. Tavolozza Colori (Concept)

| Ruolo | Colore | Codice Esadecimale | Utilizzo |
|---|---|---|---|
| Base Scura | Nightfall Charcoal | `#1e1e2e` | Terminale, barre di sistema, Plymouth |
| Accento Primario | Cool Ice Blue | `#7aa2f7` | Pulsanti, cursori, evidenziazioni attive |
| Accento Secondario | Twilight Violet | `#bb9af7` | Badge, grafici, elementi di contrasto |

---

## 3. Risorse Grafiche e Integrazione

I file grafici e l'ASCII art sono attualmente in fase di ideazione e disegno da parte dell'autore. Una volta finalizzati, verranno inseriti in:

- `config/branding/assets/logo.png` — Logo vettoriale / PNG ad alta risoluzione (Plymouth, SDDM, Installer)
- `config/branding/assets/paw_icon.svg` — Icona launcher e applicazione
- `config/branding/assets/ascii_face.txt` — Arte ASCII del volto dello zibellino per `/etc/motd` e `fastfetch`
- `config/branding/assets/wallpaper/` — Sfondi ufficiali KDE Plasma

La configurazione delle variabili visive risiede in `config/branding/branding.conf`.
