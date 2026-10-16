#!/usr/bin/env bash
# Manda una escena a renderizar a GitHub Actions (en paralelo), espera, baja el MP4 mudo y le mezcla la voz acá.
# Uso: ./render-remoto.sh /ruta/escena.html salida.mp4 [audio.wav] [partes]
#   - copia la escena (y su carpeta img/) a escenas/, hace commit de pedido.json y push → dispara el workflow
#   - el audio (voz + música) nunca se sube: se mezcla en el servidor
# Token: /root/.config/colmen-render/token (fine-grained, SOLO este repo: Contents read/write + Actions read)
set -euo pipefail
REPO=consultora1700/colmen-render
AQUI=$(cd "$(dirname "$0")" && pwd)
TOKEN=$(cat /root/.config/colmen-render/token)
FF=/root/reels-colmen/node_modules/ffmpeg-static/ffmpeg
ESCENA=$1; SALIDA=$(realpath -m "$2"); AUDIO=${3:-}; PARTES=${4:-12}
NOMBRE=$(basename "$ESCENA")
api() { curl -fsSL -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

cd "$AQUI"
cp "$ESCENA" "escenas/$NOMBRE"
# solo las imágenes que la escena carga (el repo es público: nada que no se use)
for f in $(grep -oE "img/[A-Za-z0-9_./-]+\.(png|jpg|webp|glb)" "$ESCENA" | sort -u); do mkdir -p "escenas/$(dirname "$f")"; cp "$(dirname "$ESCENA")/$f" "escenas/$f"; done
printf '{ "escena": "%s", "partes": %s, "pedido": "%s" }\n' "$NOMBRE" "$PARTES" "$(date -u +%FT%TZ)" > pedido.json
git add -A escenas pedido.json
git -c user.name="Colmen render" -c user.email="consultora1700@users.noreply.github.com" commit -q -m "render: $NOMBRE en $PARTES partes"
SHA=$(git rev-parse HEAD)
GIT_CONFIG_GLOBAL=/dev/null git push -q "https://x-access-token:$TOKEN@github.com/$REPO.git" HEAD:main
echo "push $SHA — esperando el workflow…"

RUN=""
for _ in $(seq 60); do
  RUN=$(api "https://api.github.com/repos/$REPO/actions/runs?head_sha=$SHA" | python3 -c 'import sys,json; r=json.load(sys.stdin)["workflow_runs"]; print(r[0]["id"] if r else "")')
  [ -n "$RUN" ] && break; sleep 5
done
[ -n "$RUN" ] || { echo "no arrancó ningún workflow"; exit 1; }
echo "https://github.com/$REPO/actions/runs/$RUN"
while :; do
  read -r EST CON < <(api "https://api.github.com/repos/$REPO/actions/runs/$RUN" | python3 -c 'import sys,json; r=json.load(sys.stdin); print(r["status"], r["conclusion"])')
  [ "$EST" = completed ] && break; sleep 30
done
[ "$CON" = success ] || { echo "el workflow terminó en: $CON"; exit 1; }

URL=$(api "https://api.github.com/repos/$REPO/actions/runs/$RUN/artifacts" | python3 -c 'import sys,json; print([a for a in json.load(sys.stdin)["artifacts"] if a["name"]=="video"][0]["archive_download_url"])')
TMP=$(mktemp -d); api -o "$TMP/video.zip" "$URL"; python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$TMP/video.zip" "$TMP"
MUDO=$(ls "$TMP"/video-mudo-*.mp4)
if [ -n "$AUDIO" ]; then
  "$FF" -v error -y -i "$MUDO" -i "$AUDIO" -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -ar 48000 -shortest -movflags +faststart "$SALIDA"
else
  cp "$MUDO" "$SALIDA"
fi
rm -rf "$TMP"
echo "listo: $SALIDA"
