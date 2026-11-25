#!/usr/bin/env bash
# Rutas con dueño de un repo: la unión de codeowners_paths de .city.json y de
# los patrones del archivo de dueños del repo. Los dos pueden divergir, y no
# dicen lo mismo: codeowners_paths son las rutas compartidas, las que piden
# ADR; el archivo de dueños dice quién debe aprobar (un equipo, un panel) y
# solo retiene el merge. Un PR que toca una ruta de cualquiera de los dos lo
# lee una persona. ship, build, check, goal.sh y el revisor lo llaman en vez
# de leer solo codeowners_paths. Compatible con el bash 3.2 de macOS.
# Uso: owners.sh [--ref <commit>]           lista la unión y la divergencia
#      owners.sh [--ref <commit>] --check   igual, y sale con 1 si divergen
#      owners.sh [--ref <commit>] --match [shared|owned]
#                                           lee rutas por la entrada estándar e
#                                           imprime las que tienen dueño: sin
#                                           más, las de la unión (retienen el
#                                           merge); con shared, solo las de
#                                           codeowners_paths (piden ADR); con
#                                           owned, solo las del archivo de
#                                           dueños (alguien debe aprobar)
# El archivo de dueños es codeowners_file de .city.json; sin la clave, el
# primero que exista de .github/CODEOWNERS, CODEOWNERS y docs/CODEOWNERS. Con
# --ref lee .city.json y el archivo de ese commit (origin/main), no del árbol.
# Sin --match imprime, una por línea: file=<archivo de dueños, o vacío>,
# pattern=<patrón> por cada patrón de la unión, y only_config=<patrón> u
# only_file=<patrón> por cada uno que está en un lado y no en el otro (se
# comparan sin la barra inicial ni el /, /* o /** final). Sin archivo de
# dueños no hay con qué comparar: no hay divergencia.
# Un patrón del archivo vale como en CODEOWNERS (sin barra, a cualquier
# profundidad; un directorio, con todo lo de adentro) y uno de .city.json,
# como patrón de bash; en los dos un * también cruza /: casa de más, nunca de
# menos. Una línea sin dueños no quita nada. Si el archivo trae la línea *,
# todo archivo tiene dueño, y lo avisa por stderr.
# Sale con 0, con 1 si --check encuentra divergencia y con 2 si no puede leer.
set -euo pipefail
cr=$(printf '\r') # jq de Windows termina cada línea con \r

salir() { echo "owners: $1" >&2; exit 2; }
modo=lista; ref=""; lado=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) [ $# -ge 2 ] || salir "--ref pide un commit"; ref=$2; shift 2 ;;
    --check) modo=comprueba; shift ;;
    --match) modo=casa; shift
      case "${1:-}" in shared|owned) lado=$1; shift ;; esac ;;
    *) salir "uso: owners.sh [--ref <commit>] [--check | --match [shared|owned]]" ;;
  esac
done
command -v jq >/dev/null 2>&1 || salir "necesito jq"
raiz=$(git rev-parse --show-toplevel 2>/dev/null) || salir "no es un repo git"
cd "$raiz"

if [ -n "$ref" ]; then
  # El sha y no el nombre: Git Bash reescribe "origin/x:ruta" (ver slice.sh).
  sha=$(git rev-parse -q --verify "$ref^{commit}") || salir "no existe el commit $ref"
  config=$(git show "$sha:.city.json" 2>/dev/null) || salir "no hay .city.json en $ref"
  existe() { git cat-file -e "$sha:$1" 2>/dev/null; }
  lee() { git show "$sha:$1"; }
else
  [ -f .city.json ] || salir "no hay .city.json en la raíz del repo"
  config=$(cat .city.json)
  existe() { [ -f "$1" ]; }
  lee() { cat "$1"; }
fi
printf '%s' "$config" | jq -e 'type == "object"' >/dev/null 2>&1 || salir ".city.json no es JSON válido"
de_config=$(printf '%s' "$config" | jq -r '.codeowners_paths // [] | .[] | strings' | tr -d "$cr")
archivo=$(printf '%s' "$config" | jq -r '.codeowners_file // empty' | tr -d "$cr")
if [ -n "$archivo" ]; then
  existe "$archivo" || salir "codeowners_file dice $archivo y no existe${ref:+ en $ref}"
else
  for f in .github/CODEOWNERS CODEOWNERS docs/CODEOWNERS; do
    if existe "$f"; then archivo=$f; break; fi
  done
fi
de_archivo=""
if [ -n "$archivo" ]; then
  # Primer campo de cada línea con al menos un dueño; sin comentarios.
  de_archivo=$(lee "$archivo" | tr -d "$cr" | sed 's/[[:space:]]#.*$//' | awk '!/^[[:space:]]*#/ && NF >= 2 { print $1 }' | sort -u)
fi

canon() { # canon <patrón>: sin barra inicial ni /, /* o /** final, para comparar los dos lados
  local p=${1#/}
  p=${p%/\*\*}; p=${p%/\*}; p=${p%/}
  printf '%s\n' "$p"
}
canones() { while IFS= read -r p; do [ -z "$p" ] || canon "$p"; done; }
globos() { # globos <patrón de CODEOWNERS>: los patrones de bash que lo cubren
  local p=$1 ancla=""
  case "$p" in /*) ancla=1; p=${p#/} ;; esac
  case "$p" in '**/'*) ancla=""; p=${p#\*\*/} ;; esac
  p=${p%/}
  p=$(printf '%s' "$p" | sed 's|/\*\*/|/*|g')
  case "$p" in */*) ancla=1 ;; esac
  printf '%s\n%s/*\n' "$p" "$p"
  [ -n "$ancla" ] || printf '*/%s\n*/%s/*\n' "$p" "$p"
}

if [ "$modo" = casa ]; then
  patrones=""
  [ "$lado" = owned ] || patrones=$de_config
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ "$lado" != shared ] || continue
    patrones="$patrones
$(globos "$p")"
  done <<EOF
$de_archivo
EOF
  while IFS= read -r f; do
    f=$(printf '%s' "$f" | tr -d "$cr"); [ -n "$f" ] || continue
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      # shellcheck disable=SC2053 # sin comillas, p es patrón
      if [[ "$f" == $p ]]; then printf '%s\n' "$f"; break; fi
    done <<EOF
$patrones
EOF
  done
  exit 0
fi

printf 'file=%s\n' "$archivo"
c_config=$(printf '%s\n' "$de_config" | canones | sort -u)
c_archivo=$(printf '%s\n' "$de_archivo" | canones | sort -u)
diverge=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  printf 'pattern=%s\n' "$p"
done <<EOF
$de_config
EOF
while IFS= read -r p; do
  [ -n "$p" ] || continue
  printf '%s\n' "$c_config" | grep -qxF -- "$(canon "$p")" || printf 'pattern=%s\n' "$p"
done <<EOF
$de_archivo
EOF
if [ -n "$archivo" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    printf '%s\n' "$c_archivo" | grep -qxF -- "$(canon "$p")" || { printf 'only_config=%s\n' "$p"; diverge=1; }
  done <<EOF
$de_config
EOF
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    printf '%s\n' "$c_config" | grep -qxF -- "$(canon "$p")" || { printf 'only_file=%s\n' "$p"; diverge=1; }
  done <<EOF
$de_archivo
EOF
  if printf '%s\n' "$de_archivo" | grep -qxF -- '*'; then
    echo "owners: aviso: $archivo trae la línea *: todo archivo tiene dueño y ningún PR queda en auto-merge" >&2
  fi
fi
if [ "$modo" = comprueba ] && [ "$diverge" -eq 1 ]; then exit 1; fi
exit 0
