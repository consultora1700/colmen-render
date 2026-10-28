#!/usr/bin/env bash
# Manda un proyecto HyperFrames a renderizar a GitHub Actions, espera y baja el MP4.
# Uso: ./render-hf.sh /ruta/proyecto salida.mp4
#   - sube index.html, compositions/, assets/ y los json del proyecto a hf/<nombre>/ en una rama propia
#   - nada de audio ni de .hyperframes/ (capturas de prueba) sube al repo público
set -euo pipefail
AQUI=$(cd "$(dirname "$0")" && pwd)
source "$AQUI/lib-trabajo.sh"
PROY=$(realpath "$1"); SALIDA=$(realpath -m "$2"); NOMBRE=$(basename "$PROY")
cd "$AQUI"
trabajo_nuevo hf
trabajo_vaciar "hf/$NOMBRE"
for f in index.html hyperframes.json package.json meta.json compositions assets; do
  [ -e "$PROY/$f" ] || continue
  while IFS= read -r -d '' a; do trabajo_poner "hf/$NOMBRE/${a#"$PROY"/}" "$a"; done < <(find "$PROY/$f" -type f -print0)
done
P=$(mktemp); printf '{ "proyecto": "%s", "pedido": "%s" }\n' "$NOMBRE" "$(date -u +%FT%TZ)" > "$P"
trabajo_poner hf/pedido.json "$P"; rm -f "$P"
trabajo_subir "hyperframes: $NOMBRE"
trabajo_esperar hyperframes 30
TMP=$(mktemp -d); trabajo_bajar video "$TMP"
cp "$TMP/video.mp4" "$SALIDA"; rm -rf "$TMP"
echo "listo: $SALIDA"
