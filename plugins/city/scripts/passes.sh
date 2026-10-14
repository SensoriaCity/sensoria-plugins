#!/usr/bin/env bash
# Pone passes: true en UNA funcionalidad, y solo con evidencia del evaluador.
# Es el único camino a passes: /city:build lo corre después de guardar la
# salida del evaluador. Compatible con el bash 3.2 de macOS.
# Uso: passes.sh <id>
# Lee features y evidencia_dir de .city.json en la raíz del repo y exige
# <evidencia_dir>/<id>.md con el encabezado "# Evidencia · <id> · …" y la
# última línea "VEREDICTO: pasa". features es una carpeta con un archivo
# <id>.json por funcionalidad, para que dos ramas no toquen el mismo archivo.
# Cambia el passes con jq y solo guarda si el archivo difiere del original en
# esa única línea. Sale con 0 si lo cambió o ya estaba en true, y con 1 en
# cualquier otro caso.
set -euo pipefail

salir() { echo "passes: $1" >&2; exit 1; }

[ $# -eq 1 ] && [ -n "$1" ] || salir "uso: passes.sh <id>"
id=$1
case "$id" in .*|*[!A-Za-z0-9._-]*) salir "id inválido: '$id'" ;; esac
command -v jq >/dev/null 2>&1 || salir "necesito jq"
raiz=$(git rev-parse --show-toplevel 2>/dev/null) || salir "no es un repo git"
cd "$raiz"
[ -f .city.json ] || salir "no hay .city.json en la raíz del repo"

features=$(jq -r '.features // empty' .city.json) || salir ".city.json no es JSON válido"
evidencia_dir=$(jq -r '.evidencia_dir // empty' .city.json)
[ -n "$features" ] || salir ".city.json no tiene features"
[ -n "$evidencia_dir" ] || salir ".city.json no tiene evidencia_dir"
evidencia="${evidencia_dir%/}/$id.md"

[ -f "$evidencia" ] || salir "no existe $evidencia: guarda primero la salida del evaluador"
encabezado=$(head -n 1 "$evidencia" | tr -d '\r')
prefijo="# Evidencia · $id · "
[ "${encabezado#"$prefijo"}" != "$encabezado" ] \
  || salir "el encabezado de $evidencia no es de $id: '$encabezado'"
ultima=$(awk 'NF { l = $0 } END { print l }' "$evidencia" | tr -d '\r')
[ "$ultima" = "VEREDICTO: pasa" ] \
  || salir "$evidencia no termina en 'VEREDICTO: pasa' (última línea: '${ultima:-vacía}')"

[ ! -f "$features" ] \
  || salir "$features es un archivo: features es una carpeta con un <id>.json por funcionalidad (docs/adopcion.md del kit dice cómo pasarlo)"
[ -d "$features" ] || salir "no existe la carpeta $features"
archivo="${features%/}/$id.json"
[ -f "$archivo" ] || salir "no existe $archivo"
jq -e 'type == "object"' "$archivo" >/dev/null 2>&1 || salir "$archivo no es una funcionalidad"
dentro=$(jq -r '.id' "$archivo")
[ "$dentro" = "$id" ] || salir "el id de $archivo no es $id sino '$dentro'"
actual=$(jq -r '.passes' "$archivo")
case "$actual" in
  true) echo "$id: passes ya estaba en true en $archivo"; exit 0 ;;
  false) ;;
  *) salir "el passes de $archivo no es false sino '$actual'" ;;
esac

# Misma sangría que el original, para que el diff sea una sola línea.
sangria=$(awk 'NR > 1 && /^[ \t]/ { match($0, /^[ \t]+/); print substr($0, 1, RLENGTH); exit }' "$archivo")
case "$sangria" in
  *"	"*) formato="--tab" ;;
  *) formato="--indent ${#sangria}" ;;
esac
[ -n "$sangria" ] || formato="--indent 2"

tmp=$(mktemp "${TMPDIR:-/tmp}/passes.XXXXXX")
trap 'rm -f "$tmp"' EXIT
# shellcheck disable=SC2086 # $formato son dos palabras a propósito
jq $formato '.passes = true' "$archivo" > "$tmp"

cambios=$(diff "$archivo" "$tmp" | grep -c '^[<>]' || true)
[ "$cambios" -eq 2 ] \
  || salir "jq cambiaría más que el passes de $archivo ($cambios líneas): dale formato con jq en un commit aparte"
cat "$tmp" > "$archivo"
echo "$id: passes true en $archivo"
