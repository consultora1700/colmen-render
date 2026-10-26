#!/usr/bin/env bash
# Corre un trabajo de efectos (trabajos/<nombre>/run.sh) en GitHub Actions y baja la carpeta out/.
# Uso: ./vfx-remoto.sh <nombre> <prueba|video> <carpeta-salida> [tiempos-de-prueba]
# Repo público: solo material propio o con licencia. Uno por vez (comparte el clon con render-remoto.sh y recortar-remoto.sh).
set -euo pipefail
REPO=consultora1700/colmen-render
AQUI=$(cd "$(dirname "$0")" && pwd)
TOKEN=$(cat /root/.config/colmen-render/token)
T=$1; MODO=$2; SALIDA=$(realpath -m "$3"); PRU=${4:-}
api() { curl -fsSL -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"; }
cd "$AQUI"
while [ "$(api "https://api.github.com/repos/$REPO/actions/runs?per_page=20" | python3 -c 'import sys,json; print(sum(r["status"]!="completed" for r in json.load(sys.stdin)["workflow_runs"]))')" != 0 ]; do echo "hay otro run en curso, espero…"; sleep 20; done
printf '{ "trabajo": "%s", "modo": "%s", "pruebas": "%s", "pedido": "%s" }\n' "$T" "$MODO" "$PRU" "$(date -u +%FT%TZ)" > trabajos/pedido.json
git add -A trabajos .github vfx-remoto.sh
git -c user.name="Colmen render" -c user.email="consultora1700@users.noreply.github.com" commit -q -m "vfx: $T ($MODO)"
SHA=$(git rev-parse HEAD)
GIT_CONFIG_GLOBAL=/dev/null git push -q "https://x-access-token:$TOKEN@github.com/$REPO.git" HEAD:main
echo "push $SHA — esperando el workflow…"
RUN=""
for _ in $(seq 60); do
  RUN=$(api "https://api.github.com/repos/$REPO/actions/runs?head_sha=$SHA" | python3 -c 'import sys,json; r=[x for x in json.load(sys.stdin)["workflow_runs"] if x["name"]=="vfx"]; print(r[0]["id"] if r else "")')
  [ -n "$RUN" ] && break; sleep 5
done
[ -n "$RUN" ] || { echo "no arrancó el workflow vfx"; exit 1; }
echo "https://github.com/$REPO/actions/runs/$RUN"
while :; do
  read -r EST CON < <(api "https://api.github.com/repos/$REPO/actions/runs/$RUN" | python3 -c 'import sys,json; r=json.load(sys.stdin); print(r["status"], r["conclusion"])')
  [ "$EST" = completed ] && break; sleep 15
done
[ "$CON" = success ] || { echo "el workflow terminó en: $CON"; exit 1; }
URL=$(api "https://api.github.com/repos/$REPO/actions/runs/$RUN/artifacts" | python3 -c 'import sys,json; print([a for a in json.load(sys.stdin)["artifacts"] if a["name"]=="vfx"][0]["archive_download_url"])')
TMP=$(mktemp -d); api -o "$TMP/r.zip" "$URL"; mkdir -p "$SALIDA"
python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$TMP/r.zip" "$SALIDA"
rm -rf "$TMP"; ls "$SALIDA"; echo "listo"
