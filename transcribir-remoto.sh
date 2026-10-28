#!/usr/bin/env bash
# Manda un audio a GitHub Actions para transcribirlo con whisper (tiempos por palabra) y baja palabras.json.
# Uso: ./transcribir-remoto.sh audio.wav salida.json [modelo=medium] [idioma=es]
# El repo es público: solo audio propio (voces TTS, música con licencia). Va en rama propia: puede correr a la vez que otros.
set -euo pipefail
AQUI=$(cd "$(dirname "$0")" && pwd)
source "$AQUI/lib-trabajo.sh"
AUDIO=$(realpath "$1"); SALIDA=$(realpath -m "$2"); MODELO=${3:-medium}; IDIOMA=${4:-es}
cd "$AQUI"
TMP=$(mktemp -d)
# a mp3 mono para que el commit sea liviano
liviano "$FF" -v error -y -i "$AUDIO" -ac 1 -ar 16000 -b:a 64k "$TMP/audio.mp3"
printf '{ "modelo": "%s", "idioma": "%s", "pedido": "%s" }\n' "$MODELO" "$IDIOMA" "$(date -u +%FT%TZ)" > "$TMP/pedido.json"
trabajo_nuevo transcribir
trabajo_vaciar transcribir/in
trabajo_poner transcribir/in/audio.mp3 "$TMP/audio.mp3"
trabajo_poner transcribir/pedido.json "$TMP/pedido.json"
trabajo_subir "transcribir: $(basename "$AUDIO")"
trabajo_esperar transcribir 15
trabajo_bajar palabras "$TMP/out"
cp "$TMP/out/palabras.json" "$SALIDA"; rm -rf "$TMP"
python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))),'palabras')" "$SALIDA"; echo "listo"
