#!/usr/bin/env bash
# Manda una escena a renderizar a GitHub Actions (en paralelo), espera, baja el MP4 mudo y le mezcla la voz acá.
# Uso: ./render-remoto.sh /ruta/escena.html salida.mp4 [audio.wav] [partes]
#   - sube la escena (y las img/ que carga) en una rama propia → dispara el workflow render
#   - el audio (voz + música) nunca se sube: se mezcla en el servidor (de a uno, nice 19)
#   - se puede correr a la vez que otros trabajos (ver lib-trabajo.sh)
# Token: /root/.config/colmen-render/token (fine-grained, SOLO este repo: Contents read/write + Actions read)
set -euo pipefail
AQUI=$(cd "$(dirname "$0")" && pwd)
source "$AQUI/lib-trabajo.sh"
ESCENA=$(realpath "$1"); SALIDA=$(realpath -m "$2"); AUDIO=${3:+$(realpath "$3")}; PARTES=${4:-12}
NOMBRE=$(basename "$ESCENA")
cd "$AQUI"
trabajo_nuevo render
trabajo_poner "escenas/$NOMBRE" "$ESCENA"
# solo las imágenes que la escena carga (el repo es público: nada que no se use)
for f in $(grep -oE "img/[A-Za-z0-9_./-]+\.(png|jpg|webp|glb)" "$ESCENA" | sort -u); do trabajo_poner "escenas/$f" "$(dirname "$ESCENA")/$f"; done
P=$(mktemp); printf '{ "escena": "%s", "partes": %s, "pedido": "%s" }\n' "$NOMBRE" "$PARTES" "$(date -u +%FT%TZ)" > "$P"
trabajo_poner pedido.json "$P"; rm -f "$P"
trabajo_subir "render: $NOMBRE en $PARTES partes"
trabajo_esperar render 30

TMP=$(mktemp -d); trabajo_bajar video "$TMP"
MUDO=$(ls "$TMP"/video-mudo-*.mp4)
if [ -n "$AUDIO" ]; then
  liviano "$FF" -v error -y -i "$MUDO" -i "$AUDIO" -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -ar 48000 -shortest -movflags +faststart "$SALIDA"
else
  cp "$MUDO" "$SALIDA"
fi
rm -rf "$TMP"
echo "listo: $SALIDA"
