#!/usr/bin/env bash
# Tamaño de un corte: inserciones más borrados contra la base, sin lockfiles,
# vendor ni la carpeta de evidencia. Es el único comando de tamaño del kit:
# build, ship y revisor lo llaman. Compatible con el bash 3.2 de macOS.
# Uso: size.sh [base] [--ref <commit>]
#      size.sh --help
# La base es origin/main por omisión; si no existe, main. En un corte apilado
# (su rama sale de la de otro corte que aún no está en la principal), la base
# es esa rama: sin ella, cuenta también las líneas del corte de abajo. Con
# --ref mide esa rama o ese commit en vez de HEAD, sin cambiar de rama, y lee
# .city.json de ahí. Lee line_limit y evidence_dir de .city.json en la raíz
# del repo (o, si faltan, tope_lineas y evidencia_dir, sus nombres en city
# 2.x); sin él, tope 400. Sale con 0 si cabe, 1 si pasa el tope y 2 si no
# puede medir.
set -euo pipefail

uso() { sed -n '2,/^set -euo/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//' | tr -d '\015'; }

base=""; ref=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) [ $# -ge 2 ] || { echo "size: --ref pide una rama o un commit" >&2; exit 2; }; ref=$2; shift 2 ;;
    -h|--help) uso; exit 0 ;;
    -*) echo "size: opción desconocida: $1" >&2; exit 2 ;;
    *) [ -z "$base" ] || { echo "size: uso: size.sh [base] [--ref <commit>]" >&2; exit 2; }; base=$1; shift ;;
  esac
done

raiz=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "size: no es un repo git" >&2; exit 2; }
cd "$raiz"

cabeza=HEAD; config=""
if [ -n "$ref" ]; then
  # El sha y no el nombre: Git Bash reescribe "origin/x:ruta" (ver slice.sh).
  cabeza=$(git rev-parse -q --verify "$ref^{commit}") || { echo "size: no existe el commit $ref" >&2; exit 2; }
  config=$(git show "$cabeza:.city.json" 2>/dev/null || true)
elif [ -f .city.json ]; then
  config=$(cat .city.json)
fi

campo() { # campo <clave>: valor de primer nivel de .city.json, vacío si no está
  [ -n "$config" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$config" | jq -r --arg k "$1" '.[$k] // empty'
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$config" | python3 -c 'import json,sys; v=json.load(sys.stdin).get(sys.argv[1]); print("" if v is None else v)' "$1"
  else
    echo "size: sin jq ni python3 no leo .city.json; uso los valores por omisión" >&2
  fi
}

tope=$(campo line_limit); [ -n "$tope" ] || tope=$(campo tope_lineas); tope=${tope:-400}
case "$tope" in ''|*[!0-9]*) echo "size: line_limit no es un entero: $tope" >&2; exit 2 ;; esac
evidencia=$(campo evidence_dir); [ -n "$evidencia" ] || evidencia=$(campo evidencia_dir); evidencia=${evidencia%/}

if [ -z "$base" ]; then
  for b in origin/main main; do
    if git rev-parse -q --verify "$b^{commit}" >/dev/null; then base=$b; break; fi
  done
fi
if [ -z "$base" ] || ! git rev-parse -q --verify "$base^{commit}" >/dev/null; then
  echo "size: no encuentro la base ${base:-origin/main ni main}" >&2; exit 2
fi

excluir=(':!docs/*' ':!*composer.lock' ':!*package-lock.json' ':!*pnpm-lock.yaml' ':!*yarn.lock' ':!*bun.lockb' ':!vendor/*' ':!*/vendor/*')
if [ -n "$evidencia" ]; then excluir+=(":!$evidencia/*"); fi

lineas=$(git diff --numstat "$base...$cabeza" -- . "${excluir[@]}" | awk '$1 ~ /^[0-9]+$/ { n += $1 + $2 } END { print n + 0 }')
echo "Tamaño: $lineas líneas${ref:+ de $ref} contra $base (tope $tope)"
if [ "$lineas" -gt "$tope" ]; then echo "Pasa el tope: parte el corte." >&2; exit 1; fi
