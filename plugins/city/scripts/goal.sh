#!/usr/bin/env bash
# Bucle por objetivo: build → ship → checks → merge, una funcionalidad a la vez
# y sin nadie mirando. Compatible con el bash 3.2 de macOS.
# Uso: goal.sh <id>... [--plan <ruta>] [--max-sesiones N] [--max-bloqueos N]
# Corre desde la raíz del repo. Por cada id, en orden: worktree nuevo desde
# origin/main en .claude/worktrees/goal-<id>; ahí `claude -p "/city:build <id>
# [plan]"` y, sin bloqueo, `claude -p "/city:ship"`; espera los checks y el
# merge del PR. Si un check falla, un reintento de build y ship sobre la misma
# rama; al segundo fallo, para ese id. Al terminar cada id baja la instalación
# (qa.bajar de .city.json; sin él, Compose con el perfil onprem) y borra el
# worktree solo si el PR entró. Paradas globales: --max-sesiones sesiones de
# claude (12), --max-bloqueos ids seguidos sin merge (2), una salida de build
# con "necesita ADR" o "Bloqueo", y Docker apagado.
# Log en ${TMPDIR:-/tmp}/city-goal/<fecha>.log; el resumen (goal.md) sale por
# stdout. Sale con 0 si todos los PR entraron, 1 si no y 2 si no pudo empezar.
set -uo pipefail

intervalo=${GOAL_INTERVALO:-30}     # segundos entre consultas a GitHub
espera_max=${GOAL_ESPERA_MAX:-7200} # segundos máximos esperando checks y merge de un PR

uso() { echo "goal: ${1:+$1. }uso: goal.sh <id>... [--plan <ruta>] [--max-sesiones N] [--max-bloqueos N]" >&2; exit 2; }
entero() { case "$2" in ''|*[!0-9]*|0) uso "$1 pide un entero mayor que 0" ;; esac; }

ids=(); plan=""; max_sesiones=12; max_bloqueos=2
while [ $# -gt 0 ]; do
  case "$1" in
    --plan) [ $# -ge 2 ] || uso "--plan pide una ruta"; plan=$2; shift 2 ;;
    --max-sesiones) [ $# -ge 2 ] || uso; entero "$1" "$2"; max_sesiones=$2; shift 2 ;;
    --max-bloqueos) [ $# -ge 2 ] || uso; entero "$1" "$2"; max_bloqueos=$2; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    -*) uso "opción desconocida: $1" ;;
    *) case "$1" in .*|*[!A-Za-z0-9._-]*) uso "id inválido: '$1'" ;; esac; ids+=("$1"); shift ;;
  esac
done
[ "${#ids[@]}" -gt 0 ] || uso "falta al menos un id"

for c in git gh jq claude docker; do
  command -v "$c" >/dev/null 2>&1 || { echo "goal: necesito $c" >&2; exit 2; }
done
raiz=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "goal: no es un repo git" >&2; exit 2; }
cd "$raiz" || exit 2
[ -f .city.json ] || { echo "goal: no hay .city.json en la raíz del repo" >&2; exit 2; }
ramas=$(jq -r '.ramas // empty' .city.json) || { echo "goal: .city.json no es JSON válido" >&2; exit 2; }
evidencia_dir=$(jq -r '.evidencia_dir // empty' .city.json)
bajar=$(jq -r '.qa.bajar // empty' .city.json)
[ -n "$ramas" ] || { echo "goal: .city.json no tiene ramas" >&2; exit 2; }
if [ "$(jq -r '.git.merge // "auto"' .city.json)" = manual ]; then
  echo "goal: el merge de este repo es manual (git.merge en .city.json) y el bucle necesita auto-merge" >&2
  exit 2
fi

# El plan: si está versionado en origin/main, el worktree lo trae y va con su
# ruta relativa; si no, va con su ruta absoluta y su carpeta se agrega a la sesión.
plan_arg=""; dir_extra=""
if [ -n "$plan" ]; then
  [ -f "$plan" ] || { echo "goal: no existe el plan $plan" >&2; exit 2; }
  plan_abs="$(cd "$(dirname "$plan")" && pwd)/$(basename "$plan")"
  rel=${plan_abs#"$raiz"/}
  if [ "$rel" != "$plan_abs" ] && git cat-file -e "origin/main:$rel" 2>/dev/null; then
    plan_arg=$rel
  else
    plan_arg=$plan_abs; dir_extra=$(dirname "$plan_abs")
  fi
fi

dir_log="${TMPDIR:-/tmp}"; dir_log="${dir_log%/}/city-goal"
mkdir -p "$dir_log" || exit 2
fecha=$(date +%Y-%m-%d-%H%M%S)
log="$dir_log/$fecha.log"
anota() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$log" >&2; }

SIN_PERSONA="Corres desde goal.sh, sin nadie mirando: nadie va a responder preguntas ni aprobar nada. \
Si la skill te dice que te detengas, o no puedes seguir por cualquier motivo, termina con una línea \
que empiece por 'Bloqueo: ' y el motivo; si el motivo es un ADR, escribe 'necesita ADR' en esa línea. \
No uses la palabra 'Bloqueo' para nada más."

sesiones=0; parada=""; rc=0
sesion() { # sesion <worktree> <salida> <prompt> [contexto]: corre claude -p y deja su código en rc
  if [ "$sesiones" -ge "$max_sesiones" ]; then
    parada="alcanzó --max-sesiones ($max_sesiones)"; anota "PARADA: $parada"; return 1
  fi
  sesiones=$((sesiones + 1))
  anota "sesión $sesiones/$max_sesiones en $(basename "$1"): $3"
  local -a args
  args=(-p "$3" --permission-mode auto --permission-prompts none --append-system-prompt "$SIN_PERSONA${4:-}")
  if [ -n "$dir_extra" ]; then args+=(--add-dir "$dir_extra"); fi
  (cd "$1" && claude "${args[@]}") >"$2" 2>&1 </dev/null
  rc=$?
  cat "$2" >>"$log"
  anota "claude salió con $rc (salida en $2)"
  return 0
}

espera_pr() { # espera_pr <n>: deja en resultado merged, cerrado, rojo, retenido, sin-auto o tiempo
  local n=$1 inicio=$SECONDS estado_pr pendientes info
  fallidos=""
  anota "PR #$n: esperando checks y merge"
  gh pr checks "$n" --watch --fail-fast --interval "$intervalo" >>"$log" 2>&1
  while :; do
    estado_pr=$(gh pr view "$n" --json state --jq .state 2>>"$log")
    case "$estado_pr" in
      MERGED) resultado=merged; return ;;
      CLOSED) resultado=cerrado; return ;;
    esac
    fallidos=$(gh pr checks "$n" --json name,bucket \
      --jq '[.[] | select(.bucket == "fail" or .bucket == "cancel") | .name] | join(", ")' 2>>"$log")
    if [ -n "$fallidos" ]; then resultado=rojo; return; fi
    pendientes=$(gh pr checks "$n" --json bucket --jq '[.[] | select(.bucket == "pending")] | length' 2>>"$log")
    if [ "${pendientes:-1}" = 0 ]; then
      # Todo en verde y sin merge: sin auto-merge (nació bloqueado) o retenido por CODEOWNERS.
      info=$(gh pr view "$n" --json autoMergeRequest,reviewDecision \
        --jq '"\(.autoMergeRequest != null) \(.reviewDecision)"' 2>>"$log")
      case "$info" in
        false*) resultado=sin-auto; return ;;
        *REVIEW_REQUIRED*|*CHANGES_REQUESTED*) resultado=retenido; return ;;
      esac
    fi
    if [ $((SECONDS - inicio)) -ge "$espera_max" ]; then resultado=tiempo; return; fi
    sleep "$intervalo"
  done
}

pasos_evaluador() { # pasos_evaluador <worktree> <id>: "3/4 cumplen · pasa" desde la evidencia, o —
  local f="$1/${evidencia_dir%/}/$2.md"
  if [ -z "$evidencia_dir" ] || [ ! -f "$f" ]; then echo "—"; return; fi
  awk -F'|' '$2 ~ /^ *[0-9]+ *$/ { n++; r = $(NF-1); if (r ~ /cumple/ && r !~ /no cumple/) ok++ }
    /^VEREDICTO:/ { v = $0; sub(/^VEREDICTO: */, "", v) }
    END { printf "%d/%d cumplen · %s\n", ok, n, (v == "" ? "sin veredicto" : v) }' "$f"
}

baja() { # baja <worktree>: baja la instalación que haya quedado en el worktree
  anota "bajando la instalación en $(basename "$1")"
  if [ -n "$bajar" ]; then
    (cd "$1" && sh -c "$bajar") >>"$log" 2>&1
  else
    (cd "$1" && docker compose --profile onprem down -v --remove-orphans) >>"$log" 2>&1
  fi || anota "no se pudo bajar la instalación (ver el log)"
}

corre_id() { # corre_id <id>: deja pr, estado, pasos y motivo
  local id=$1 wt intento=1 extra="" rama="" salida linea
  pr="—"; estado="sin PR"; pasos="—"; motivo=""
  if ! docker info >/dev/null 2>&1; then
    parada="Docker apagado"; motivo=$parada; anota "PARADA: $parada"; return
  fi
  git fetch -q origin >>"$log" 2>&1 || { motivo="git fetch falló"; return; }
  wt="$raiz/.claude/worktrees/goal-$id"
  if [ -e "$wt" ]; then motivo="ya existe $wt de una corrida anterior"; return; fi
  mkdir -p "$raiz/.claude/worktrees"
  git worktree add -q --detach "$wt" origin/main >>"$log" 2>&1 || { motivo="no pude crear el worktree"; return; }
  anota "$id: worktree $wt desde origin/main"
  while :; do
    salida="$dir_log/$fecha-$id-build$intento.txt"
    sesion "$wt" "$salida" "/city:build $id${plan_arg:+ $plan_arg}" "$extra" || { motivo=$parada; break; }
    linea=$(grep -m1 -e 'necesita ADR' -e 'Bloqueo' "$salida" | cut -c1-200)
    if [ -n "$linea" ]; then
      parada="build de $id: $linea"; motivo=$linea; anota "PARADA: $parada"; break
    fi
    if [ "$rc" -ne 0 ]; then motivo="build salió con $rc"; break; fi
    rama=$(git -C "$wt" symbolic-ref --short -q HEAD)
    case "$rama" in
      "$ramas"*"-$id") ;;
      *) motivo="build no dejó la rama ${ramas}AAAA-MM-DD-$id"; break ;;
    esac
    [ "$intento" -eq 1 ] || extra=" El PR #$pr de esta rama ya existe: haz push a la rama y no abras otro."
    sesion "$wt" "$dir_log/$fecha-$id-ship$intento.txt" "/city:ship" "$extra" || { motivo=$parada; break; }
    if [ "$rc" -ne 0 ]; then motivo="ship salió con $rc"; break; fi
    pr=$(gh pr list --head "$rama" --state all --json number --jq '.[0].number // empty' 2>>"$log")
    if [ -z "$pr" ]; then pr="—"; motivo="ship no abrió PR"; break; fi
    estado=OPEN
    espera_pr "$pr"
    case "$resultado" in
      merged) estado=MERGED; motivo="entró"; break ;;
      cerrado) estado=CLOSED; motivo="el PR se cerró sin merge"; break ;;
      retenido) motivo="retenido por CODEOWNERS"; break ;;
      sin-auto) motivo="checks en verde sin auto-merge: nació bloqueado"; break ;;
      tiempo) motivo="sin merge tras ${espera_max}s"; break ;;
    esac
    anota "PR #$pr: checks en rojo ($fallidos), intento $intento"
    if [ "$intento" -ge 2 ]; then motivo="checks en rojo dos veces: $fallidos"; break; fi
    intento=2
    extra=" El PR #$pr de esta rama tiene checks en rojo: $fallidos. Míralos con gh pr checks $pr y gh run view --log-failed, y corrige en esta misma rama."
  done
  pasos=$(pasos_evaluador "$wt" "$id")
  baja "$wt"
  if [ "$estado" = MERGED ]; then
    git worktree remove --force "$wt" >>"$log" 2>&1 || anota "no pude borrar $wt"
    git branch -D "$rama" >>"$log" 2>&1
  fi
}

anota "goal: ${ids[*]} · plan ${plan_arg:-ninguno} · máx. $max_sesiones sesiones y $max_bloqueos ids seguidos sin merge · log $log"
filas=""; seguidos=0; todos=0
for id in "${ids[@]}"; do
  if [ -n "$parada" ]; then
    filas="$filas| $id | — | sin correr | — | no corrió: $parada |"$'\n'; todos=1; continue
  fi
  corre_id "$id"
  anota "$id: $estado · $motivo"
  case "$pr" in [0-9]*) pr="#$pr" ;; esac
  filas="$filas| $id | $pr | $estado | $pasos | $motivo |"$'\n'
  if [ "$estado" = MERGED ]; then seguidos=0; else seguidos=$((seguidos + 1)); todos=1; fi
  if [ -z "$parada" ] && [ "$seguidos" -ge "$max_bloqueos" ]; then
    parada="$seguidos ids seguidos sin merge"; anota "PARADA: $parada"
  fi
done

resumen="# goal · $fecha

| id | PR | estado | pasos del evaluador | por qué paró |
|---|---|---|---|---|
$filas
Sesiones de claude: $sesiones de $max_sesiones.
Parada global: ${parada:-ninguna}.
Log: $log

El cierre es \`/city:check hoy\`: lo que entró, lo retenido y lo que quedó en rojo."
printf '%s\n' "$resumen" >>"$log"
printf '%s\n' "$resumen"
exit "$todos"
