# Fuente única para mandar un trabajo a GitHub Actions (se incluye con `source`, no se ejecuta).
# Cada trabajo va en SU rama (trabajo/<tipo>-<fecha>-<pid>) armada con un índice temporal a partir de main:
# no toca el directorio de trabajo del clon, así que varios trabajos pueden salir a la vez sin pisarse.
# La rama se borra sola al terminar (bien o mal); el artifact queda en el run.
# Uso:
#   trabajo_nuevo render            → arranca el índice desde main
#   trabajo_vaciar escenas/in       → saca una carpeta heredada de main (opcional)
#   trabajo_poner ruta/en/repo archivo-local
#   trabajo_subir "mensaje"         → commit + push de la rama, deja SHA
#   trabajo_esperar render 30       → espera el run de ese workflow, deja RUN
#   trabajo_bajar video carpeta     → baja y descomprime el artifact
REPO=consultora1700/colmen-render
TOKEN=$(cat /root/.config/colmen-render/token)
FF=/root/reels-colmen/node_modules/ffmpeg-static/ffmpeg
# lo poco que corre en el server con CPU (ffmpeg) va de a uno y con prioridad mínima: Colmen primero
liviano() { flock /tmp/colmen-ffmpeg.lock nice -n 19 "$@"; }
api() { curl -fsSL -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"; }
# GitHub a veces rechaza un push cuando llegan dos casi juntos ("remote rejected … (failed)"): reintenta
_push1() { GIT_CONFIG_GLOBAL=/dev/null git push -q "https://x-access-token:$TOKEN@github.com/$REPO.git" "$@" 2>&1 | { grep -v "^remote:" || true; } >&2; }
_push() { local i; for i in 1 2 3 4; do _push1 "$@" && return 0; echo "push falló (intento $i), reintento…" >&2; sleep $((i * 4)); done; return 1; }

trabajo_nuevo() {
  RAMA="trabajo/$1-$(date -u +%Y%m%d-%H%M%S)-$$"
  IDX=$(mktemp)
  GIT_INDEX_FILE=$IDX git read-tree main
  trap trabajo_borrar EXIT
}
trabajo_vaciar() { GIT_INDEX_FILE=$IDX git rm -r -q --cached --ignore-unmatch -- "$1" >/dev/null; }
trabajo_poner() {
  local h; h=$(git hash-object -w -- "$2")
  GIT_INDEX_FILE=$IDX git update-index --add --cacheinfo "100644,$h,$1"
}
trabajo_subir() {
  local arbol
  arbol=$(GIT_INDEX_FILE=$IDX git write-tree); rm -f "$IDX"
  SHA=$(GIT_AUTHOR_NAME="Colmen render" GIT_AUTHOR_EMAIL="consultora1700@users.noreply.github.com" \
        GIT_COMMITTER_NAME="Colmen render" GIT_COMMITTER_EMAIL="consultora1700@users.noreply.github.com" \
        git commit-tree "$arbol" -p main -m "$1")
  _push "$SHA:refs/heads/$RAMA"
  SUBIDA=1
  echo "push $SHA ($RAMA) — esperando el workflow…"
}
trabajo_esperar() {
  local wf=$1 cada=${2:-15} est con
  RUN=""
  for _ in $(seq 60); do
    RUN=$(api "https://api.github.com/repos/$REPO/actions/runs?head_sha=$SHA" | python3 -c 'import sys,json; r=[x for x in json.load(sys.stdin)["workflow_runs"] if x["name"]==sys.argv[1]]; print(r[0]["id"] if r else "")' "$wf")
    [ -n "$RUN" ] && break; sleep 5
  done
  [ -n "$RUN" ] || { echo "no arrancó el workflow $wf"; return 1; }
  echo "https://github.com/$REPO/actions/runs/$RUN"
  while :; do
    read -r est con < <(api "https://api.github.com/repos/$REPO/actions/runs/$RUN" | python3 -c 'import sys,json; r=json.load(sys.stdin); print(r["status"], r["conclusion"])')
    [ "$est" = completed ] && break; sleep "$cada"
  done
  [ "$con" = success ] || { echo "el workflow terminó en: $con"; return 1; }
}
trabajo_bajar() {
  local url zip
  url=$(api "https://api.github.com/repos/$REPO/actions/runs/$RUN/artifacts" | python3 -c 'import sys,json; print([a for a in json.load(sys.stdin)["artifacts"] if a["name"]==sys.argv[1]][0]["archive_download_url"])' "$1")
  mkdir -p "$2"; zip=$(mktemp --suffix=.zip)
  api -o "$zip" "$url"
  python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$zip" "$2"
  rm -f "$zip"
}
trabajo_borrar() {
  rm -f "${IDX:-}"
  [ -n "${SUBIDA:-}" ] && _push --delete "refs/heads/$RAMA" 2>/dev/null || true
}
