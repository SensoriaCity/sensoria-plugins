#!/usr/bin/env bash
# Cambia el passes de UNA funcionalidad, y solo según la evidencia del
# evaluador. Es el único camino a passes: el evaluador lo corre después de
# escribir su evidencia. Compatible con el bash 3.2 de macOS.
# Uso: passes.sh <id>                           pone passes en true
#      passes.sh <id> --check [--ref <commit>]  dice si un passes true sigue vigente; no escribe
#      passes.sh <id> --reset                   devuelve passes a false si ya no está vigente
#      En los tres, --base <ref> cambia la base de la comparación (un corte apilado).
# Encuentra el corte y su evidencia con slice.sh (<hito>/slices/<id>.json y
# <hito>/evidence/<id>.md, o <features>/<id>.json y <evidence_dir>/<id>.md)
# y exige la evidencia con el encabezado "# Evidencia · <id> · <fecha> ·
# <commit>", la última línea "VEREDICTO: pasa" y ninguna línea "VENCIDA:".
# Cambia el passes con jq y solo guarda si el archivo difiere del original en
# esa única línea, sin contar los fines de línea (en Windows git deja CRLF y
# jq escribe LF).
# Vigente: el commit del encabezado es HEAD, o el cambio del corte contra la
# base es el mismo en los dos, sin contar docs/, el archivo del corte, su
# evidencia ni PROGRESO.md. Así un rebase o un merge de la base sin conflictos
# no lo vence, y un commit de código sí. La base es origin/main (si no existe,
# main) o la de --base: en un corte apilado, la rama del corte de abajo; sin
# ella, un commit nuevo del corte de abajo cuenta como código de este.
# Corte ya mezclado: cuando el commit que trajo la evidencia ya es parte de la
# base (el merge del corte, por squash o no), la evidencia vale sobre la
# principal y sobre cualquier rama que no traiga código propio contra la base.
# Lo que la vence es código nuevo en la rama que se comprueba (la del corte o
# una -fix, que pide su propia pasada), no la historia posterior de la
# principal: otro corte que después cambia esos archivos entra con su propia
# evidencia y no vence esta.
# Límites: da por hecho que la evidencia estaba vigente al mezclar (lo
# comprueban ship, el revisor y el job evidencia antes del merge). Un cambio
# al código de un corte ya mezclado que llega a la principal por otro camino
# (otro corte, un hotfix, un push directo) no se nota aquí: lo cubren los
# checks de ese PR, y corregir el comportamiento de un corte va por su rama
# -fix. Y en una rama con código propio, --check de un corte mezclado que no
# es el de la rama sale con 1: de ese se pregunta con --ref origin/main.
# Sin opciones: sale con 0 si lo cambió o ya estaba en true, y con 1 en
# cualquier otro caso, también si la evidencia es de un commit vencido (si no
# encuentra ese commit, avisa y sigue). Con --check: 0 si passes es false o
# es true con evidencia vigente, 1 si es true y la evidencia falta, no dice
# "VEREDICTO: pasa" o está vencida, y 2 si no pudo comprobarlo. Con --ref lee
# el corte y la evidencia de ese commit (una rama) en vez del árbol de
# trabajo. Con --reset: como --check, pero en el caso 1 deja passes en false
# y sale con 0; si la evidencia decía "VEREDICTO: pasa" y venció, le agrega al
# final "VENCIDA: evaluó <commit>; el código cambió en <commit>", para que no
# siga diciendo que pasa. Una evidencia con esa marca no vale: la reemplaza la
# pasada siguiente del evaluador.
set -euo pipefail

salir() { echo "passes: $1" >&2; exit "${2:-1}"; }
uso="uso: passes.sh <id> [--base <ref>] [--check [--ref <commit>] | --reset]"

id=""; modo=pone; ref=""; base_pedida=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) modo=comprueba; shift ;;
    --reset) modo=devuelve; shift ;;
    --ref) [ $# -ge 2 ] || salir "--ref pide un commit"; ref=$2; shift 2 ;;
    --base) [ $# -ge 2 ] || salir "--base pide una rama o un commit"; base_pedida=$2; shift 2 ;;
    -h|--help) echo "$uso"; exit 0 ;;
    -*) salir "opción desconocida: $1" ;;
    *) [ -z "$id" ] || salir "$uso"; id=$1; shift ;;
  esac
done
[ -n "$id" ] || salir "$uso"
[ -z "$ref" ] || [ "$modo" = comprueba ] || salir "--ref solo va con --check"
case "$id" in .*|*[!A-Za-z0-9._-]*) salir "id inválido: '$id'" ;; esac
command -v jq >/dev/null 2>&1 || salir "necesito jq"
raiz=$(git rev-parse --show-toplevel 2>/dev/null) || salir "no es un repo git"
cd "$raiz"
cr=$(printf '\r')
[ -z "$base_pedida" ] || git rev-parse -q --verify "$base_pedida^{commit}" >/dev/null 2>&1 \
  || salir "no existe la base $base_pedida de --base" 2

if [ -n "$ref" ]; then
  # El sha y no el nombre: Git Bash reescribe "origin/x:ruta" (ver slice.sh).
  cabeza=$(git rev-parse -q --verify "$ref^{commit}") || salir "no existe el commit $ref" 2
  config=$(git show "$cabeza:.city.json" 2>/dev/null) || salir "no hay .city.json en $ref" 2
  existe() { git cat-file -e "$cabeza:$1" 2>/dev/null; }
  lee() { git show "$cabeza:$1"; }
  donde=$(bash "$(dirname "$0")/slice.sh" "$id" --ref "$ref") || exit 1
else
  [ -f .city.json ] || salir "no hay .city.json en la raíz del repo"
  cabeza=$(git rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null || true)
  config=$(cat .city.json)
  existe() { [ -f "$1" ]; }
  lee() { cat "$1"; }
  features=$(printf '%s' "$config" | jq -r '.features // empty' | tr -d "$cr") || salir ".city.json no es JSON válido"
  [ -z "$features" ] || [ ! -f "$features" ] \
    || salir "$features es un archivo: features es una carpeta con un <id>.json por funcionalidad (docs/adopcion.md del kit dice cómo pasarlo)"
  donde=$(bash "$(dirname "$0")/slice.sh" "$id") || exit 1
fi
archivo=$(printf '%s\n' "$donde" | tr -d "$cr" | sed -n 's/^file=//p')
evidencia=$(printf '%s\n' "$donde" | tr -d "$cr" | sed -n 's/^evidence=//p')
evidence_dir=$(printf '%s' "$config" | jq -r '.evidence_dir // .evidencia_dir // empty' 2>/dev/null | tr -d "$cr" || true)
evidence_dir=${evidence_dir%/}
prefijo="# Evidencia · $id · "
motivo=""; evaluado=""; encabezado=""; base=""; tmp=""; sin_cr=""

evidencia_pasa() { # 0 si la evidencia existe, es de <id> y termina en VEREDICTO: pasa; si no, el porqué queda en $motivo
  local ultima resto vencida
  existe "$evidencia" || { motivo="no existe $evidencia: guarda primero la salida del evaluador"; return 1; }
  encabezado=$(lee "$evidencia" | head -n 1 | tr -d "$cr")
  [ "${encabezado#"$prefijo"}" != "$encabezado" ] \
    || { motivo="el encabezado de $evidencia no es de $id: '$encabezado'"; return 1; }
  # awk lee todo: con pipefail, un grep -q que corta la tubería daría falso.
  vencida=$(lee "$evidencia" | awk '/^VENCIDA:/ && v == "" { v = $0 } END { print v }' | tr -d "$cr")
  if [ -n "$vencida" ]; then
    motivo="$evidencia está vencida ($vencida): pide otra pasada al evaluador"; return 1
  fi
  ultima=$(lee "$evidencia" | awk 'NF { l = $0 } END { print l }' | tr -d "$cr")
  [ "$ultima" = "VEREDICTO: pasa" ] \
    || { motivo="$evidencia no termina en 'VEREDICTO: pasa' (última línea: '${ultima:-vacía}')"; return 1; }
  # "# Evidencia · <id> · <fecha> · <commit>[ · sin repo: …]": el commit es el segundo campo del resto.
  resto=${encabezado#"$prefijo"}
  case "$resto" in *" · "*) resto=${resto#* · }; evaluado=${resto%% *} ;; *) evaluado="" ;; esac
  return 0
}

huella() { # huella <commit>: el cambio del corte contra la base, sin números de línea
  local mb
  mb=$(git merge-base "$base" "$1" 2>/dev/null) || return 1
  git diff "$mb" "$1" -- . "${excluir[@]}" | git patch-id --stable | cut -d' ' -f1
}

mezclada() { # la evidencia ya entró a la base con el merge del corte: 0 vigente, 1 la rama trae código propio, 3 no es el caso
  local m propio
  m=$(git log -1 --format=%H "$cabeza" -- "$evidencia" 2>/dev/null) || return 3
  [ -n "$m" ] || return 3
  git merge-base --is-ancestor "$m" "$base" 2>/dev/null || return 3
  [ "$(git show "$m:$evidencia" 2>/dev/null | head -n 1 | tr -d "$cr")" = "$encabezado" ] || return 3
  propio=$(git merge-base "$base" "$cabeza" 2>/dev/null) || return 3
  if ! git diff --quiet "$propio" "$cabeza" -- . "${excluir[@]}"; then
    motivo="la evidencia es de $evaluado, que ya entró a $base en $(git rev-parse --short "$m"), y esta rama cambia código: corregir un corte ya mezclado pide otra pasada del evaluador en este mismo PR"
    return 1
  fi
  # Sin código propio, vale: lo que otros cortes cambien después en la base
  # entra con su propia evidencia y no vence esta.
  return 0
}

vigencia() { # 0 vigente, 1 el código cambió después de evaluar, 2 no se puede saber; el porqué queda en $motivo
  local sha b h1 h2 estado sin_huella=""
  case "$evaluado" in
    ''|*[!0-9a-f]*) motivo="el encabezado de $evidencia no trae el commit que probó el evaluador"; return 2 ;;
  esac
  [ -n "$cabeza" ] || { motivo="la rama no tiene commits"; return 2; }
  sha=$(git rev-parse -q --verify "$evaluado^{commit}" 2>/dev/null || true)
  [ "$sha" != "$cabeza" ] || return 0
  if [ -n "$base_pedida" ]; then
    base=$base_pedida
  else
    for b in origin/main main; do
      if git rev-parse -q --verify "$b^{commit}" >/dev/null 2>&1; then base=$b; break; fi
    done
  fi
  excluir=(':!docs/*' ':!PROGRESO.md' ":!$archivo" ":!$evidencia")
  if [ -n "$evidence_dir" ]; then excluir+=(":!$evidence_dir/*"); fi
  if [ -n "$sha" ] && [ -n "$base" ]; then
    if h1=$(huella "$sha") && h2=$(huella "$cabeza"); then
      [ "$h1" != "$h2" ] || return 0
    else
      sin_huella=1
    fi
  fi
  # Corte ya mezclado: tras un squash-merge el commit evaluado no es ancestro
  # de la cabeza, o ya no está en el clon, y la huella contra la base no dice
  # nada. Entonces cuenta el commit que trajo la evidencia a la base.
  if [ -n "$base" ]; then
    estado=0; mezclada || estado=$?
    [ "$estado" -eq 3 ] || return "$estado"
  fi
  [ -n "$sha" ] \
    || { motivo="no encuentro el commit $evaluado que probó el evaluador (git fetch origin, o pide otra pasada)"; return 2; }
  [ -n "$base" ] || { motivo="no encuentro la base (origin/main ni main) para comparar $evaluado con la cabeza"; return 2; }
  [ -z "$sin_huella" ] || { motivo="no pude comparar $evaluado con la cabeza contra $base"; return 2; }
  motivo="el evaluador probó $evaluado y el código cambió después (cabeza $(git rev-parse --short "$cabeza")): pide otra pasada al evaluador"
  return 1
}

escribe() { # escribe <true|false>: cambia solo esa línea del archivo del corte
  local sangria formato cambios
  # Misma sangría que el original, para que el diff sea una sola línea.
  sangria=$(awk 'NR > 1 && /^[ \t]/ { match($0, /^[ \t]+/); print substr($0, 1, RLENGTH); exit }' "$archivo")
  case "$sangria" in
    *"	"*) formato="--tab" ;;
    *) formato="--indent ${#sangria}" ;;
  esac
  [ -n "$sangria" ] || formato="--indent 2"

  tmp=$(mktemp "${TMPDIR:-/tmp}/passes.XXXXXX")
  sin_cr=$(mktemp "${TMPDIR:-/tmp}/passes.XXXXXX")
  trap 'rm -f "$tmp" "$sin_cr"' EXIT
  # shellcheck disable=SC2086 # $formato son dos palabras a propósito
  jq $formato --argjson v "$1" '.passes = $v' "$archivo" > "$tmp"

  tr -d "$cr" < "$archivo" > "$sin_cr"
  cambios=$(tr -d "$cr" < "$tmp" | diff "$sin_cr" - | grep -c '^[<>]' || true)
  [ "$cambios" -eq 2 ] \
    || salir "jq cambiaría más que el passes de $archivo ($cambios líneas): dale formato con jq en un commit aparte"
  cat "$tmp" > "$archivo"
}

lee "$archivo" | jq -e 'type == "object"' >/dev/null 2>&1 || salir "$archivo no es una funcionalidad"
actual=$(lee "$archivo" | jq -r '.passes' | tr -d "$cr")

if [ "$modo" != pone ]; then
  case "$actual" in
    false) echo "$id: passes en false en $archivo: nada que comprobar"; exit 0 ;;
    true) ;;
    *) salir "el passes de $archivo no es true ni false sino '$actual'" 2 ;;
  esac
  estado=0; decia_pasa=""
  if evidencia_pasa; then decia_pasa=1; vigencia || estado=$?; else estado=1; fi
  case "$estado" in
    0) echo "$id: passes true con evidencia vigente ($evaluado)"; exit 0 ;;
    2) salir "no pude comprobar el passes de $id: $motivo" 2 ;;
  esac
  [ "$modo" = devuelve ] || salir "el passes true de $id ya no vale: $motivo"
  escribe false
  marca=""
  if [ -n "$decia_pasa" ]; then
    # La evidencia decía "pasa" de un código que ya no es el de la cabeza: que
    # no lo siga diciendo. Con el fin de línea que ya trae el archivo.
    fin=""; if grep -q "$cr" "$evidencia"; then fin=$cr; fi
    [ -z "$(tail -c 1 "$evidencia")" ] || printf '%s\n' "$fin" >> "$evidencia"
    printf 'VENCIDA: evaluó %s; el código cambió en %s%s\n' "$evaluado" "$(git rev-parse --short "$cabeza")" "$fin" >> "$evidencia"
    marca=" y $evidencia marcada como VENCIDA"
  fi
  echo "$id: passes devuelto a false en $archivo$marca: $motivo"
  exit 0
fi

evidencia_pasa || salir "$motivo"
case "$actual" in
  true) echo "$id: passes ya estaba en true en $archivo"; exit 0 ;;
  false) ;;
  *) salir "el passes de $archivo no es false sino '$actual'" ;;
esac
estado=0; vigencia || estado=$?
case "$estado" in
  1) salir "$motivo" ;;
  2) echo "passes: aviso: no comprobé que la evidencia sea del commit vigente: $motivo" >&2 ;;
esac
escribe true
echo "$id: passes true en $archivo"
