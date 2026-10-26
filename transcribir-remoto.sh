#!/usr/bin/env bash
# Manda un audio a GitHub Actions para transcribirlo con whisper (tiempos por palabra) y baja palabras.json.
# Uso: ./transcribir-remoto.sh audio.wav salida.json [modelo=medium] [idioma=es]
# El repo es público: solo audio propio (voces TTS, música con licencia). Uno por vez (comparte el clon con los otros scripts).
set -euo pipefail
REPO=consultora1700/colmen-render
AQUI=$(cd "$(dirname "$0")" && pwd)
TOKEN=$(cat /root/.config/colmen-render/token)
AUDIO=$(realpath "$1"); SALIDA=$(realpath -m "$2"); MODELO=${3:-medium}; IDIOMA=${4:-es}
api() { curl -fsSL -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

cd "$AQUI"
rm -rf transcribir/in; mkdir -p transcribir/in
EXT="${AUDIO##*.}"
# a mp3 mono para que el commit sea liviano
/root/reels-colmen/node_modules/ffmpeg-static/ffmpeg -v error -y -i "$AUDIO" -ac 1 -ar 16000 -b:a 64k transcribir/in/audio.mp3
printf '{ "modelo": "%s", "idioma": "%s", "pedido": "%s" }\n' "$MODELO" "$IDIOMA" "$(date -u +%FT%TZ)" > transcribir/pedido.json
git add -A transcribir
git -c user.name="Colmen render" -c user.email="consultora1700@users.noreply.github.com" commit -q -m "transcribir: $(basename "$AUDIO")"
SHA=$(git rev-parse HEAD)
GIT_CONFIG_GLOBAL=/dev/null git push -q "https://x-access-token:$TOKEN@github.com/$REPO.git" HEAD:main
echo "push $SHA — esperando el workflow…"

RUN=""
for _ in $(seq 60); do
  RUN=$(api "https://api.github.com/repos/$REPO/actions/runs?head_sha=$SHA" | python3 -c 'import sys,json; r=[x for x in json.load(sys.stdin)["workflow_runs"] if x["name"]=="transcribir"]; print(r[0]["id"] if r else "")')
  [ -n "$RUN" ] && break; sleep 5
done
[ -n "$RUN" ] || { echo "no arrancó el workflow transcribir"; exit 1; }
echo "https://github.com/$REPO/actions/runs/$RUN"
while :; do
  read -r EST CON < <(api "https://api.github.com/repos/$REPO/actions/runs/$RUN" | python3 -c 'import sys,json; r=json.load(sys.stdin); print(r["status"], r["conclusion"])')
  [ "$EST" = completed ] && break; sleep 15
done
[ "$CON" = success ] || { echo "el workflow terminó en: $CON"; exit 1; }

URL=$(api "https://api.github.com/repos/$REPO/actions/runs/$RUN/artifacts" | python3 -c 'import sys,json; print([a for a in json.load(sys.stdin)["artifacts"] if a["name"]=="palabras"][0]["archive_download_url"])')
TMP=$(mktemp -d); api -o "$TMP/p.zip" "$URL"
python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$TMP/p.zip" "$TMP"
cp "$TMP/palabras.json" "$SALIDA"; rm -rf "$TMP"
python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))),'palabras')" "$SALIDA"; echo "listo"
