# Vili's Whisp

Dettatura vocale personale per macOS, nello stile di [Wispr Flow](https://wisprflow.ai): tieni premuto un tasto, parla, rilascia. Il testo pulito e formattato compare al cursore in qualsiasi app.

- **Push-to-talk** con `fn` (o Option/Command destro, F13, F18). Doppio tocco → **mani libere**, `Esc` annulla.
- **Pill flottante** in basso con onda audio e stato (ascolto → trascrivo → formatto → fatto).
- **Trascrizione cloud** con la tua chiave: Groq (`whisper-large-v3-turbo`, default) o OpenAI (`gpt-4o-mini-transcribe`).
- **Pulizia con Claude**: filler rimossi, punteggiatura, paragrafi, liste, auto-correzioni ("no anzi…"), numeri/email/URL scritti come si digitano.
- **Tono per app**: chat → informale, email → formale, editor/terminale → letterale, documenti → neutro. Override per singola app.
- **Dizionario personale** (nomi, prodotti) e **snippet** (es. "firma email" → testo).
- **Modalità comando**: seleziona del testo, tieni premuto il tasto e di' "rendilo più formale" / "traduci in inglese": la selezione viene sostituita.
- **Italiano + inglese** con rilevamento automatico (o lingua fissa).
- **Cronologia** locale, chiavi nel Portachiavi, nessun server intermedio: il tuo audio va solo al provider che scegli.

## Requisiti

- macOS 14 o successivo.
- Xcode Command Line Tools (`xcode-select --install`). Non serve Xcode completo.
- Una chiave API Groq (gratuita su console.groq.com) **oppure** OpenAI, e una chiave Anthropic (console.anthropic.com).

## Build

```bash
make app
```

Produce `build/VilisWhisp.app`. Per avviarla subito:

```bash
make run
```

Facoltativo: `cp -r build/VilisWhisp.app /Applications/` per tenerla stabile e abilitare "Avvia al login".

## Primo avvio

1. L'app compare nella barra dei menu (icona a forma d'onda) e chiede il **Microfono**.
2. Compare un avviso per **Accessibilità**: apri Impostazioni di Sistema → Privacy e sicurezza → Accessibilità e attiva **VilisWhisp**. Su alcune versioni serve anche **Monitoraggio input**. L'app si attiva da sola appena il permesso viene concesso.
3. Menu → **Impostazioni… → Provider**: incolla le chiavi e premi "Testa connessione".
4. Apri Note, tieni premuto `fn`, parla, rilascia.

Se ricompili l'app, macOS può chiedere di nuovo i permessi: rimuovi e riaggiungi VilisWhisp nel pannello Accessibilità.

## Come funziona

```
fn giù ──► AVAudioEngine (16 kHz mono) ──► fn su
                                            │
                       cattura app attiva, finestra, testo selezionato
                                            │
                                            ▼
                        STT (Groq / OpenAI, multipart WAV)
                                            │
                                            ▼
            Claude Messages API (claude-haiku-5-5, effort low)
            system prompt stile Wispr + contesto app + dizionario + snippet
                                            │
                                            ▼
          Accessibility (campi nativi) oppure ⌘V con ripristino clipboard
                                            │
                                            ▼
                                       cronologia
```

Se Claude non è raggiungibile (o la chiave manca), il testo grezzo viene inserito dopo una pulizia locale dei filler e la pill mostra un avviso.

## Impostazioni

| Sezione | Cosa controlla |
|---|---|
| Generale | tasto, doppio tocco mani libere, lingua, tono predefinito, durata minima, metodo di inserimento, suoni, avvio al login, stato permessi |
| Provider | provider STT e modello, chiave Anthropic e modello Claude, toggle "salta formattazione" |
| Dizionario | termini con la grafia corretta (inviati anche allo STT come prompt) |
| Snippet | trigger → testo |
| Toni per app | bundle id → tono |

Modello Claude: `claude-haiku-5-5` è il più veloce ed è il default per la dettatura; `claude-opus-5-5` dà la qualità massima con più latenza.

## Script utili

- `scripts/smoke_api.sh`: verifica chiavi e connettività senza aprire l'app (`GROQ_API_KEY=… ANTHROPIC_API_KEY=… bash scripts/smoke_api.sh`).
- `scripts/make_icon.sh`: rigenera l'icona.
- `scripts/bundle.sh`: assembla il bundle `.app` (chiamato da `make app`).

## Privacy

Audio e testo vengono inviati solo al provider STT scelto e ad Anthropic. Niente analytics, niente account. Le chiavi stanno nel Portachiavi, la cronologia in `~/Library/Application Support/VilisWhisp/history.jsonl`.
