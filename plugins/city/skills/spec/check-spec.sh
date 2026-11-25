#!/usr/bin/env bash
# Compuerta mecánica de los cortes de un hito, antes del commit de /city:spec.
# Compatible con el bash 3.2 de macOS.
# Uso: check-spec.sh <carpeta del hito> [line_limit] [--base <commit>]   (tope por omisión 400)
# La carpeta es <apps_dir>/<aplicativo>/mod-<NN>-<slug>/h<NN>-<slug>/, con dos
# dígitos o más. Revisa cada <hito>/slices/*.json: que su nombre sea su id y
# el id sea m<NN>-h<NN>-s<NN> con el módulo y el hito de la carpeta; class
# slice, data o platform; de 2 a 5 steps con "do" y "expect"; rung de 1 a 4
# (obligatorio en class slice, opcional en data y platform); passes false (o
# true con su evidencia); estimated_lines de máximo el 75 % del tope, o del
# tope entero si el corte trae estimate_basis measured (la estimación sale de
# un diff que ya existe; sin la clave vale planned); blocked_by, si viene, una
# lista no vacía de {question, owner, blocks_since} con la fecha AAAA-MM-DD;
# revision, si viene, una fecha AAAA-MM-DD que aparece en "Decisiones tomadas"
# de spec.md (en una lista numerada o con viñetas: basta la fecha en una línea
# de la sección); y ninguna clave del formato anterior en español.
# depends_on nombra cortes anteriores del hito (por orden de id), de otro hito
# que ya existen, o uno posterior del hito solo si ese trae revision (nació o
# cambió en /city:spec revise); nunca uno reemplazado, y sin ciclos.
# ships_with, si viene, es una lista no vacía de ids de otros cortes que
# existen (del hito, anteriores o posteriores, o de otro hito) y que no fueron
# reemplazados: el corte no se despliega sin ellos.
# Un corte con replaced_by ya no se construye: de él solo se revisa el id,
# que replaced_by sea una lista de cortes que existen y que passes sea false.
# Con --base (origin/main en un PR de clase spec) compara con ese commit:
# ningún corte se borra ni se renombra; uno con passes true no cambia; ninguno
# cambia su passes; y uno que cambia algo más que blocked_by o replaced_by
# trae revision. Si git no puede leer un corte de ese commit, es un error del
# script y no una falla del corte: lo dice y sale con 2.
# Imprime una línea "falla: …" por falla y sale con 0 si no hay ninguna, 1 si
# hay alguna y 2 si no puede revisar. Si spec.md pasa de 150 líneas más 5 por
# corte, lo dice con "aviso: …" y no falla.
set -uo pipefail
cr=$(printf '\r') # jq de Windows termina cada línea con \r

uso() { echo "check-spec: uso: check-spec.sh <carpeta del hito> [line_limit] [--base <commit>]" >&2; exit 2; }
hito=""; tope=""; base=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) [ $# -ge 2 ] || uso; base=$2; shift 2 ;;
    -*) uso ;;
    *) if [ -z "$hito" ]; then hito=${1%/}; elif [ -z "$tope" ]; then tope=$1; else uso; fi; shift ;;
  esac
done
[ -n "$hito" ] || uso
tope=${tope:-400}
case "$tope" in ''|*[!0-9]*) echo "check-spec: line_limit no es un entero: $tope" >&2; exit 2 ;; esac
command -v jq >/dev/null 2>&1 || { echo "check-spec: necesito jq" >&2; exit 2; }
[ -d "$hito/slices" ] || { echo "check-spec: no existe $hito/slices" >&2; exit 2; }
max=$((tope * 3 / 4))
slice_sh="$(cd "$(dirname "$0")/../.." && pwd)/scripts/slice.sh"

fallas=0; previos=" "; n=0; reemplazados=0; fechas=""
falla() { echo "falla: $1"; fallas=$((fallas + 1)); }
[ -f "$hito/spec.md" ] || falla "no existe $hito/spec.md"

# El prefijo de los ids sale de la carpeta: mod-28-<slug>/h01-<slug> → m28-h01-s.
abs=$(cd "$hito" && pwd)
h=$(basename "$abs" | sed -n -E 's/^h([0-9]{2,})-.+$/\1/p')
m=$(basename "$(dirname "$abs")" | sed -n -E 's/^mod-([0-9]{2,})-.+$/\1/p')
prefijo=""
if [ -n "$h" ] && [ -n "$m" ]; then
  prefijo="m$m-h$h-s"
else
  falla "la carpeta no es mod-<NN>-<slug>/h<NN>-<slug> (dos dígitos): $(basename "$(dirname "$abs")")/$(basename "$abs")"
fi

tiene() { jq -e --arg k "$2" 'has($k)' "$hito/slices/$1.json" >/dev/null 2>&1; } # tiene <id> <clave>
existe() { [ -f "$hito/slices/$1.json" ] || bash "$slice_sh" "$1" >/dev/null 2>&1; } # existe <id>

for f in $(find "$hito/slices" -name '*.json' -type f | sort); do
  n=$((n + 1))
  id=$(basename "$f" .json)
  ev=false; [ -f "$hito/evidence/$id.md" ] && ev=true
  r=$(jq -r --arg id "$id" --arg prefijo "$prefijo" --argjson max "$max" --argjson tope "$tope" --argjson evidencia "$ev" '
    def falla(c; m): if c then empty else m end;
    def texto: type == "string" and length > 0;
    [ falla(.id == $id; "el id no es el nombre del archivo"),
      falla($prefijo == "" or ($id | test("^" + $prefijo + "[0-9]{2,}$")); "el id no es \($prefijo)<NN>, con el módulo y el hito de su carpeta"),
      (["clase", "escalon", "depende_de", "bloqueado_por", "pasos", "estimacion_lineas", "reemplazada_por", "descripcion", "cubre"] as $viejas
        | keys[] | select(IN($viejas[]))
        | "trae la clave \(.) del formato anterior: las claves van en inglés (docs/adopcion.md del kit)"),
      if has("replaced_by") then
        falla((.replaced_by | type) == "array" and (.replaced_by | length) > 0 and ([.replaced_by[] | texto and . != $id] | all);
          "replaced_by no es una lista no vacía de ids de otros cortes"),
        falla(.passes == false; "trae replaced_by y passes no es false: un corte que ya pasó no se reemplaza, se corrige (slices.md)")
      else
        falla(.class | IN("slice", "data", "platform"); "class \(.class) no es slice, data ni platform"),
        falla((.steps | type) == "array" and (.steps | length) >= 2 and (.steps | length) <= 5; "tiene \(.steps | length) steps (de 2 a 5)"),
        falla([.steps[]? | (.do | texto) and (.expect | texto)] | all; "un paso no tiene do y expect"),
        falla(if .class == "slice" then .rung | IN(1, 2, 3, 4) else .rung == null or (.rung | IN(1, 2, 3, 4)) end;
          "rung \(.rung) no es de 1 a 4 (obligatorio en class slice, opcional en data y platform)"),
        falla(.passes == false or (.passes == true and $evidencia); "passes no es false (o es true sin evidencia)"),
        falla((has("estimate_basis") | not) or (.estimate_basis | IN("planned", "measured")); "estimate_basis \(.estimate_basis) no es planned ni measured"),
        ((if .estimate_basis == "measured" then [$tope, "el tope entero: estimate_basis es measured"]
          else [$max, "75 % del tope; si la estimación sale del diff ya medido en la rama del corte, estimate_basis measured admite hasta \($tope)"] end) as [$lim, $porque]
          | falla((.estimated_lines | type) == "number" and .estimated_lines <= $lim; "estimated_lines \(.estimated_lines) pasa \($lim) (\($porque))")),
        falla((.depends_on | type) == "array"; "depends_on no es una lista"),
        falla((has("blocked_by") | not) or ((.blocked_by | type) == "array" and (.blocked_by | length) > 0
            and ([.blocked_by[] | type == "object" and (.question | texto) and (.owner | texto)
              and ((.blocks_since | type) == "string") and (.blocks_since | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$"))] | all));
          "blocked_by no es una lista no vacía de {question, owner, blocks_since: AAAA-MM-DD} (sin bloqueo, la clave no va)"),
        falla((has("revision") | not) or ((.revision | type) == "string" and (.revision | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")));
          "revision no es una fecha AAAA-MM-DD"),
        falla((has("ships_with") | not) or ((.ships_with | type) == "array" and (.ships_with | length) > 0 and ([.ships_with[] | texto and . != $id] | all));
          "ships_with no es una lista no vacía de ids de otros cortes (sin orden de despliegue, la clave no va)"),
        falla((.spec | type) == "string"; "no trae spec")
      end
    ] | .[] | strings' "$f" 2>&1 | tr -d "$cr") || r="no es JSON válido"
  if [ -n "$r" ]; then
    printf '%s\n' "$r" | sed "s|^|falla: $id: |"; fallas=$((fallas + 1))
  fi
  if tiene "$id" replaced_by; then
    reemplazados=$((reemplazados + 1))
    for d in $(jq -r '.replaced_by[]? | strings' "$f" 2>/dev/null | tr -d "$cr"); do
      existe "$d" || falla "$id: replaced_by nombra $d, que no existe"
    done
    previos="$previos$id "
    continue
  fi
  fechas="$fechas $(jq -r '.revision // empty | strings' "$f" 2>/dev/null | tr -d "$cr")"
  for d in $(jq -r '.depends_on[]? // empty' "$f" 2>/dev/null | tr -d "$cr"); do
    if [ "$d" = "$id" ]; then
      falla "$id: depende de sí mismo"
    elif [ -f "$hito/slices/$d.json" ]; then
      if tiene "$d" replaced_by; then
        falla "$id: depende de $d, que fue reemplazado: apunta a los cortes de su replaced_by"
      else
        case "$previos" in
          *" $d "*) ;;
          *) tiene "$d" revision \
               || falla "$id: depende de $d, que va después (solo vale si $d nació o cambió en una revisión y trae revision)" ;;
        esac
      fi
    elif ! bash "$slice_sh" "$d" >/dev/null 2>&1; then
      falla "$id: depende de $d, que no existe (si es un insumo externo, va en blocked_by)"
    fi
  done
  for d in $(jq -r '.ships_with[]? | strings' "$f" 2>/dev/null | tr -d "$cr"); do
    [ "$d" != "$id" ] || continue
    if [ -f "$hito/slices/$d.json" ]; then
      ! tiene "$d" replaced_by || falla "$id: ships_with nombra $d, que fue reemplazado: apunta a los cortes de su replaced_by"
    elif ! bash "$slice_sh" "$d" >/dev/null 2>&1; then
      falla "$id: ships_with nombra $d, que no existe"
    fi
  done
  previos="$previos$id "
done
[ "$n" -gt 0 ] || { echo "falla: $hito/slices no tiene cortes"; exit 1; }

# Con dependencias hacia un id mayor ya no basta el orden: no puede haber ciclos.
# shellcheck disable=SC2046 # los archivos de un hito no llevan espacios
ciclo=$(jq -s -r '
  (map(select(type == "object" and (has("replaced_by") | not) and (.id | type) == "string")
    | {key: .id, value: [.depends_on[]? | strings]}) | from_entries) as $g
  | def poda: . as $q
      | [to_entries[] | select([.value[] | select($q[.] != null)] | length == 0) | .key] as $libres
      | if ($libres | length) == 0 then $q else with_entries(select(.key as $k | $libres | index($k) | not)) | poda end;
  $g | poda | keys | if length > 0 then join(", ") else empty end' \
  $(find "$hito/slices" -name '*.json' -type f | sort) 2>/dev/null | tr -d "$cr")
[ -z "$ciclo" ] || falla "depends_on forma un ciclo entre $ciclo"

# Cada revision es una decisión con fecha en la spec.
for d in $(printf '%s\n' $fechas | sort -u); do
  [ -f "$hito/spec.md" ] || break
  awk -v d="$d" '/^## Decisiones tomadas/ { s = 1; next } /^## / { s = 0 } s && index($0, d) { ok = 1 } END { exit !ok }' "$hito/spec.md" \
    || falla "hay cortes con revision $d y spec.md no trae esa fecha bajo \"## Decisiones tomadas\" (quién, fecha y qué cambia)"
done

if [ -n "$base" ]; then
  # core.longpaths: en Windows, git muere con "Filename too long" en rutas
  # largas, y la carpeta de un hito lo es. Un git que falla aquí no dice nada
  # de los cortes: es un error del script, no un corte que cambió.
  g() { git -C "$hito" -c core.longpaths=true "$@"; }
  sha=$(g rev-parse -q --verify "$base^{commit}" 2>/dev/null) \
    || { echo "check-spec: no existe el commit $base (o $hito no está en un repo git)" >&2; exit 2; }
  rel=$(g rev-parse --show-prefix | tr -d "$cr")
  en_base=$(g ls-tree -r --name-only --full-name "$sha" -- slices/) \
    || { echo "check-spec: git no pudo listar los cortes de $base en $hito; no comparo nada" >&2; exit 2; }
  for bf in $(printf '%s\n' "$en_base" | tr -d "$cr" | grep '\.json$'); do
    f="$hito/${bf#"$rel"}"; id=$(basename "$bf" .json)
    [ -f "$f" ] || { falla "$id: está en $base y aquí no: un corte no se borra ni se renombra (se marca con replaced_by)"; continue; }
    crudo=$(g show "$sha:$bf" 2>/dev/null) \
      || { echo "check-spec: git show no pudo leer $bf de $base ($(g show "$sha:$bf" 2>&1 >/dev/null | head -n 1 | tr -d "$cr")); no comparo nada" >&2; exit 2; }
    antes=$(printf '%s' "$crudo" | jq -S -c . 2>/dev/null | tr -d "$cr")
    [ -n "$antes" ] || { echo "check-spec: $bf de $base no es JSON válido; no comparo nada" >&2; exit 2; }
    ahora=$(jq -S -c . "$f" 2>/dev/null | tr -d "$cr")
    [ "$antes" != "$ahora" ] || continue
    if [ "$(printf '%s' "$antes" | jq -r '.passes' | tr -d "$cr")" = true ]; then
      falla "$id: tiene passes true en $base y cambió: un corte que ya pasó no se edita; se corrige en su rama -fix (slices.md)"
    elif [ "$(printf '%s' "$ahora" | jq -r '.passes' | tr -d "$cr")" != false ]; then
      falla "$id: cambia passes: solo lo cambia passes.sh, en el PR del corte"
    elif [ "$(printf '%s' "$antes" | jq -S -c 'del(.blocked_by, .replaced_by)' | tr -d "$cr")" != "$(printf '%s' "$ahora" | jq -S -c 'del(.blocked_by, .replaced_by)' | tr -d "$cr")" ] \
      && ! tiene "$id" revision; then
      falla "$id: cambió respecto a $base y no trae revision: una spec ya mezclada se cambia con /city:spec revise, que fecha cada cambio"
    fi
  done
fi

if [ -f "$hito/spec.md" ]; then
  lineas=$(wc -l < "$hito/spec.md" | tr -d ' '); cabe=$((150 + 5 * n))
  [ "$lineas" -le "$cabe" ] || echo "aviso: spec.md tiene $lineas líneas; con $n cortes caben unas $cabe (150 + 5 por corte)"
fi
if [ "$fallas" -gt 0 ]; then exit 1; fi
echo "check-spec: $n cortes de $hito en regla, $reemplazados reemplazados (tope $tope; máximo $max por corte, $tope con estimate_basis measured)"
