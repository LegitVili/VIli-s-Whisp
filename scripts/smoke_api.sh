#!/usr/bin/env bash
# Verifica chiavi e connettivita' verso i provider usati dall'app, senza aprire l'app.
# Uso: GROQ_API_KEY=... ANTHROPIC_API_KEY=... [OPENAI_API_KEY=...] bash scripts/smoke_api.sh [file.wav]
set -euo pipefail

WAV="${1:-}"
if [[ -z "$WAV" ]]; then
  WAV="$(mktemp -t whisp).wav"
  if command -v say >/dev/null 2>&1; then
    AIFF="${WAV%.wav}.aiff"
    say -v Alice "Ciao, questa è una prova di dettatura, ehm, primo punto, secondo punto." -o "$AIFF"
    afconvert -f WAVE -d LEI16@16000 -c 1 "$AIFF" "$WAV"
  elif command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -loglevel error -y -f lavfi -i "sine=frequency=440:duration=1" -ar 16000 -ac 1 "$WAV"
  else
    echo "Passa un file wav come argomento (nessun generatore disponibile)." >&2; exit 1
  fi
  echo "WAV di test: $WAV"
fi

if [[ -n "${GROQ_API_KEY:-}" ]]; then
  echo "== Groq whisper-large-v3-turbo"
  curl -sS https://api.groq.com/openai/v1/audio/transcriptions \
    -H "Authorization: Bearer $GROQ_API_KEY" \
    -F "file=@$WAV" -F model=whisper-large-v3-turbo -F response_format=verbose_json \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print("lang:", d.get("language"), "| text:", d.get("text", d))'
fi

if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  echo "== OpenAI gpt-4o-mini-transcribe"
  curl -sS https://api.openai.com/v1/audio/transcriptions \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -F "file=@$WAV" -F model=gpt-4o-mini-transcribe -F response_format=json \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print("text:", d.get("text", d))'
fi

if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "== Claude ${CLAUDE_MODEL:-claude-haiku-5-5}"
  curl -sS https://api.anthropic.com/v1/messages \
    -H "Content-Type: application/json" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2026-10-21" \
    -d "{
      \"model\": \"${CLAUDE_MODEL:-claude-haiku-5-5}\",
      \"max_tokens\": 1024,
      \"output_config\": {\"effort\": \"low\"},
      \"system\": \"You clean up dictated speech. Remove filler words, add punctuation, keep the speaker's language. Output only the cleaned text.\",
      \"messages\": [{\"role\": \"user\", \"content\": \"ciao ehm questa è una prova cioè allora primo punto secondo punto\"}]
    }" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("stop:", d.get("stop_reason"), "|", "".join(b.get("text","") for b in d.get("content",[]) if b.get("type")=="text") or d)'
fi
