#!/usr/bin/env bash
# Dice dónde vive un corte: su archivo, su hito, su spec y su evidencia. Es el
# único lugar del kit que sabe la estructura de carpetas; build, ship, goal,
# check, passes.sh, el revisor y el evaluador lo llaman en vez de armar rutas.
# Compatible con el bash 3.2 de macOS.
# Uso: slice.sh <id> [--ref <commit>]
# Busca primero <apps_dir>/<aplicativo>/<modulo>/<hito>/slices/<id>.json
# (apps_dir de .city.json; sin él, docs/apps), con la evidencia en
# <hito>/evidence/<id>.md y la spec en <hito>/spec.md. <aplicativo> es la
# carpeta del aplicativo dueño del módulo, no la clave app de .city.json (esa
# es el nombre del repo). Un id m<NN>-h<NN>-s<NN> lleva el módulo y el hito:
# tiene que vivir en mod-<NN>-<slug>/h<NN>-<slug>/, y si no, falla. Si no está
# ahí, busca <features>/<id>.json con la evidencia en <evidence_dir>/<id>.md y
# la spec en su clave spec (el formato de city 2.x, que sigue valiendo; lee
# también evidencia_dir, el nombre de 2.x). Con --ref busca en ese commit
# (origin/main, una rama) en vez del árbol de trabajo; .city.json se lee
# también de ahí.
# Imprime cuatro líneas clave=valor: file, milestone (vacío en el formato 2.x),
# spec (vacía si no tiene) y evidence. Sale con 0 si lo encontró una sola vez
# y con 1 si no existe, está repetido o el id no es válido.
set -euo pipefail
cr=$(printf '\r') # jq de Windows termina cada línea con \r

salir() { echo "slice: $1" >&2; exit 1; }

id=""; ref=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) [ $# -ge 2 ] || salir "--ref pide un commit"; ref=$2; shift 2 ;;
    -*) salir "opción desconocida: $1" ;;
    *) [ -z "$id" ] || salir "uso: slice.sh <id> [--ref <commit>]"; id=$1; shift ;;
  esac
done
[ -n "$id" ] || salir "uso: slice.sh <id> [--ref <commit>]"
case "$id" in .*|*[!A-Za-z0-9._-]*) salir "id inválido: '$id'" ;; esac
command -v jq >/dev/null 2>&1 || salir "necesito jq"
raiz=$(git rev-parse --show-toplevel 2>/dev/null) || salir "no es un repo git"
cd "$raiz"

if [ -n "$ref" ]; then
  # El sha y no el nombre: en Git Bash de Windows, "origin/x:ruta" se toma por
  # una lista de rutas y se reescribe.
  sha=$(git rev-parse -q --verify "$ref^{commit}") || salir "no existe el commit $ref"
  config=$(git show "$sha:.city.json" 2>/dev/null) || salir "no hay .city.json en $ref"
  lista() { git ls-tree -r --name-only "$sha" -- "$1" 2>/dev/null; }
  lee() { git show "$sha:$1"; }
else
  [ -f .city.json ] || salir "no hay .city.json en la raíz del repo"
  config=$(cat .city.json)
  lista() { [ -e "$1" ] || return 0; find "$1" -type f 2>/dev/null | sed 's|^\./||'; }
  lee() { cat "$1"; }
fi
printf '%s' "$config" | jq -e 'type == "object"' >/dev/null 2>&1 || salir ".city.json no es JSON válido"
campo() { printf '%s' "$config" | jq -r "$1" | tr -d "$cr"; }
apps_dir=$(campo '.apps_dir // "docs/apps"'); apps_dir=${apps_dir%/}
features=$(campo '.features // empty'); features=${features%/}
evidence_dir=$(campo '.evidence_dir // .evidencia_dir // empty'); evidence_dir=${evidence_dir%/}

encontrados=$(lista "$apps_dir" | grep -E "/slices/$(printf '%s' "$id" | sed 's/\./\\./g')\.json$" || true)
n=$(printf '%s' "$encontrados" | grep -c . || true)
if [ "$n" -gt 1 ]; then
  salir "el id $id está en más de un hito: $(printf '%s' "$encontrados" | tr '\n' ' ')"
elif [ "$n" -eq 1 ]; then
  archivo=$encontrados
  hito=$(dirname "$(dirname "$archivo")")
  # m28-h01-s01 vive en mod-28-<slug>/h01-<slug>/: el id dice dónde.
  if printf '%s' "$id" | grep -qE '^m[0-9]+-h[0-9]+-s[0-9]+$'; then
    m=$(printf '%s' "$id" | sed -E 's/^m([0-9]+)-h([0-9]+)-s[0-9]+$/\1/')
    h=$(printf '%s' "$id" | sed -E 's/^m([0-9]+)-h([0-9]+)-s[0-9]+$/\2/')
    printf '%s' "$archivo" | grep -qE "/mod-$m-[^/]+/h$h-[^/]+/slices/[^/]+$" \
      || salir "el id $id dice mod-$m-<slug>/h$h-<slug>/ pero vive en $hito"
  fi
  spec="$hito/spec.md"
  evidencia="$hito/evidence/$id.md"
elif [ -n "$features" ] && lista "$features" | grep -qx "$features/$id.json"; then
  archivo="$features/$id.json"
  hito=""
  spec=$(lee "$archivo" | jq -r '.spec // empty' 2>/dev/null | tr -d "$cr" || true)
  [ -n "$evidence_dir" ] || salir ".city.json no tiene evidence_dir para $archivo"
  evidencia="$evidence_dir/$id.md"
else
  salir "no existe el corte $id: ni $apps_dir/**/slices/$id.json ni ${features:-<features>}/$id.json${ref:+ en $ref}"
fi

dentro=$(lee "$archivo" | jq -r '.id // empty' 2>/dev/null | tr -d "$cr" || true)
[ "$dentro" = "$id" ] || salir "el id de $archivo no es $id sino '${dentro:-ninguno}'"

printf 'file=%s\nmilestone=%s\nspec=%s\nevidence=%s\n' "$archivo" "$hito" "$spec" "$evidencia"
