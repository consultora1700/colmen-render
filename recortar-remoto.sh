#!/usr/bin/env bash
# Manda fotos a GitHub Actions para quitarles el fondo y baja los PNG transparentes. Nada pesado corre en el server.
# Uso: ./recortar-remoto.sh carpeta-salida foto1.jpg [foto2.jpg ...]
#   - cada foto sale como carpeta-salida/<nombre>.png
#   - el repo es público: solo fotos con licencia (Unsplash, Commons, propias autorizadas)
# Va en rama propia: puede correr a la vez que otros trabajos.
set -euo pipefail
AQUI=$(cd "$(dirname "$0")" && pwd)
source "$AQUI/lib-trabajo.sh"
SALIDA=$(realpath -m "$1"); shift
FOTOS=(); for f in "$@"; do FOTOS+=("$(realpath "$f")"); done
cd "$AQUI"
trabajo_nuevo recortar
trabajo_vaciar recortes/in
for f in "${FOTOS[@]}"; do trabajo_poner "recortes/in/$(basename "$f")" "$f"; done
P=$(mktemp); printf '{ "fotos": %s, "pedido": "%s" }\n' "${#FOTOS[@]}" "$(date -u +%FT%TZ)" > "$P"
trabajo_poner recortes/pedido.json "$P"; rm -f "$P"
trabajo_subir "recortar: ${#FOTOS[@]} fotos"
trabajo_esperar recortar 15
trabajo_bajar recortes "$SALIDA"
ls "$SALIDA"; echo "listo"
