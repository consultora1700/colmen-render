#!/usr/bin/env bash
# Manda fotos a GitHub Actions para quitarles el fondo y baja los PNG transparentes. Nada pesado corre en el server.
# Uso: ./recortar-remoto.sh carpeta-salida foto1.jpg [foto2.jpg ...]
#   - cada foto sale como carpeta-salida/<nombre>.png
#   - el repo es público: solo fotos con licencia (Unsplash, Commons, propias autorizadas)
# Corre uno por vez: comparte el clon con render-remoto.sh, así que no lanzar los dos al mismo tiempo.
set -euo pipefail
REPO=consultora1700/colmen-render
AQUI=$(cd "$(dirname "$0")" && pwd)
TOKEN=$(cat /root/.config/colmen-render/token)
SALIDA=$(realpath -m "$1"); shift
FOTOS=(); for f in "$@"; do FOTOS+=("$(realpath "$f")"); done
api() { curl -fsSL -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

cd "$AQUI"
rm -rf recortes/in; mkdir -p recortes/in
for f in "${FOTOS[@]}"; do cp "$f" recortes/in/; done
printf '{ "fotos": %s, "pedido": "%s" }\n' "$#" "$(date -u +%FT%TZ)" > recortes/pedido.json
git add -A recortes
git -c user.name="Colmen render" -c user.email="consultora1700@users.noreply.github.com" commit -q -m "recortar: $# fotos"
SHA=$(git rev-parse HEAD)
GIT_CONFIG_GLOBAL=/dev/null git push -q "https://x-access-token:$TOKEN@github.com/$REPO.git" HEAD:main
echo "push $SHA — esperando el workflow…"

RUN=""
for _ in $(seq 60); do
  RUN=$(api "https://api.github.com/repos/$REPO/actions/runs?head_sha=$SHA" | python3 -c 'import sys,json; r=[x for x in json.load(sys.stdin)["workflow_runs"] if x["name"]=="recortar"]; print(r[0]["id"] if r else "")')
  [ -n "$RUN" ] && break; sleep 5
done
[ -n "$RUN" ] || { echo "no arrancó el workflow recortar"; exit 1; }
echo "https://github.com/$REPO/actions/runs/$RUN"
while :; do
  read -r EST CON < <(api "https://api.github.com/repos/$REPO/actions/runs/$RUN" | python3 -c 'import sys,json; r=json.load(sys.stdin); print(r["status"], r["conclusion"])')
  [ "$EST" = completed ] && break; sleep 15
done
[ "$CON" = success ] || { echo "el workflow terminó en: $CON"; exit 1; }

URL=$(api "https://api.github.com/repos/$REPO/actions/runs/$RUN/artifacts" | python3 -c 'import sys,json; print([a for a in json.load(sys.stdin)["artifacts"] if a["name"]=="recortes"][0]["archive_download_url"])')
TMP=$(mktemp -d); api -o "$TMP/r.zip" "$URL"; mkdir -p "$SALIDA"
python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$TMP/r.zip" "$SALIDA"
rm -rf "$TMP"
ls "$SALIDA"; echo "listo"
