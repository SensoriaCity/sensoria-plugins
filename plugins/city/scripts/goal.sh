#!/usr/bin/env bash
# Bucle por objetivo: build → ship → checks → merge, una funcionalidad a la vez
# y sin nadie mirando. Compatible con el bash 3.2 de macOS.
# Uso: goal.sh <id>... [--plan <ruta>] [--max-sesiones N] [--max-bloqueos N] [--quiet]
# Corre desde la raíz del repo. Por cada id, en orden: worktree nuevo desde
# origin/main en .claude/worktrees/goal-<id>; ahí `claude -p "/city:build <id>
# [plan]"` y, sin bloqueo, `claude -p "/city:ship"`; si ningún archivo del PR
# cae en codeowners_paths, activa su auto-merge; espera los checks y el merge.
# Si un check falla, quita el auto-merge y reintenta build y ship en la misma
# rama; al segundo fallo, para ese id. Al terminar cada id baja la instalación
# (qa.bajar de .city.json; sin él, Compose con el perfil onprem) y borra el
# worktree solo si el PR entró. Paradas globales: --max-sesiones sesiones de
# claude (12), --max-bloqueos ids seguidos sin merge (2), una salida de build
# con "necesita ADR" o "Bloqueo", una sesión con "Not logged in" y Docker
# apagado. Antes del primer worktree prueba que claude tenga sesión.
# Log en ${TMPDIR:-/tmp}/city-goal/<fecha>.log; el resumen (goal.md) sale por
# stdout y el avance por stderr: una línea por herramienta de cada sesión y, en
# una terminal, una línea de estado (--quiet: solo las líneas del log). Sale
# con 0 si todos los PR entraron, 1 si no y 2 si no pudo empezar.
set -uo pipefail

intervalo=${GOAL_INTERVALO:-30}     # segundos entre consultas a GitHub
espera_max=${GOAL_ESPERA_MAX:-7200} # segundos máximos esperando checks y merge de un PR

uso() { echo "goal: ${1:+$1. }uso: goal.sh <id>... [--plan <ruta>] [--max-sesiones N] [--max-bloqueos N] [--quiet]" >&2; exit 2; }
entero() { case "$2" in ''|*[!0-9]*|0) uso "$1 pide un entero mayor que 0" ;; esac; }

ids=(); plan=""; max_sesiones=12; max_bloqueos=2; quiet=""
while [ $# -gt 0 ]; do
  case "$1" in
    --plan) [ $# -ge 2 ] || uso "--plan pide una ruta"; plan=$2; shift 2 ;;
    --max-sesiones) [ $# -ge 2 ] || uso; entero "$1" "$2"; max_sesiones=$2; shift 2 ;;
    --max-bloqueos) [ $# -ge 2 ] || uso; entero "$1" "$2"; max_bloqueos=$2; shift 2 ;;
    --quiet) quiet=1; shift ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
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

# claude con sesión antes del primer worktree: a primera hora la sesión puede
# haber vencido y cada `claude -p` sale en segundos con "Not logged in". Sin
# herramientas (--tools ""): con ellas, un turno no alcanza y sale con 1.
prueba=$(claude -p "Responde solo: ok" --max-turns 1 --tools "" </dev/null 2>&1); rc_prueba=$?
if [ "$rc_prueba" -ne 0 ] || printf '%s' "$prueba" | grep -qF 'Not logged in'; then
  echo "goal: claude no tiene sesión (salió con $rc_prueba: $(printf '%s' "$prueba" | head -n1 | cut -c1-120))." >&2
  echo "goal: corre \`claude\` en una terminal, entra con /login y vuelve a lanzar goal.sh." >&2
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
# Con stderr en una terminal y sin --quiet, una línea de estado que se reescribe
# con \r; cada línea que sale por stderr empieza borrándola.
tty=""; borra=""
if [ -z "$quiet" ] && [ -t 2 ]; then tty=1; borra=$'\r\033[K'; fi
anota() { local l; l="$(date +%H:%M:%S) $*"; printf '%s\n' "$l" >>"$log"; printf '%s%s\n' "$borra" "$l" >&2; }

# Del stream-json de una sesión, una línea por herramienta: el comando de Bash,
# la ruta de Read o Edit, el subagente de Agent. Nunca contenidos ni salidas.
# shellcheck disable=SC2016 # las $ son de jq
FILTRO='def corta: gsub("[\\n\\t]+"; " ") | if length > 80 then .[0:79] + "…" else . end;
  fromjson? | objects | select(.type == "assistant") | .parent_tool_use_id as $p
  | .message.content[]? | objects | select(.type == "tool_use") | (.input // {}) as $in
  | (.name // "?" | sub("^mcp__.*__"; "")) as $h
  | (if $h == "Bash" then $in.command
     elif ($h | test("^(Read|Edit|MultiEdit|Write|NotebookEdit)$")) then ($in.file_path // $in.notebook_path)
     elif $h == "Agent" or $h == "Task" then ($in.subagent_type // "general-purpose")
     elif $h == "Grep" or $h == "Glob" then $in.pattern
     elif $h == "Skill" then $in.skill
     elif $h == "WebFetch" or $h == "browser_navigate" then $in.url
     else null end) as $r
  | "\(now | strflocaltime("%H:%M:%S")) \($id) · \($fase) · \(if $p then "↳ " else "" end)\($h)"
    + (if ($r | type) == "string" and $r != "" then " · " + ($r | ltrimstr($wt) | corta) else "" end)'
herramientas() { # herramientas <worktree> <fase>: lee el stream de stdin y escribe sus líneas en stderr y el log
  jq -R -r --unbuffered --arg wt "$1/" --arg id "$id" --arg fase "$2" "$FILTRO" 2>/dev/null \
    | while IFS= read -r l; do printf '%s\n' "$l" >>"$log"; printf '%s%s\n' "$borra" "$l" >&2; done
}

vivo=""
estado_vivo() { # estado_vivo <fase> [cola] [pr]: con TTY, reescribe la línea de estado cada segundo hasta para_estado
  para_estado
  [ -n "$tty" ] || return 0
  local pos=0 x
  for x in "${ids[@]}"; do pos=$((pos + 1)); [ "$x" = "$id" ] && break; done
  (
    inicio=$SECONDS consulta=-1 checks="" t=0 d="" c=""
    while kill -0 "$$" 2>/dev/null; do
      t=$((SECONDS - inicio))
      if [ -n "${3:-}" ] && { [ "$consulta" -lt 0 ] || [ $((t - consulta)) -ge "$intervalo" ]; }; then
        consulta=$t
        c=$(gh pr checks "$3" --json bucket \
          --jq '"\([.[] | select(.bucket == "pass" or .bucket == "skipping")] | length)/\(length)"' 2>/dev/null)
        [ -n "$c" ] && checks=" · checks $c"
      fi
      if [ "$t" -ge 3600 ]; then d=$(printf '%dh%02dm' $((t / 3600)) $((t % 3600 / 60)))
      else d=$(printf '%dm%02ds' $((t / 60)) $((t % 60))); fi
      printf '\r\033[K[%d/%d] %s · %s%s · %s%s' "$pos" "${#ids[@]}" "$id" "$1" "$checks" "$d" "${2:+ · $2}" >&2
      sleep 1
    done
  ) &
  vivo=$!
}
para_estado() { # borra la línea de estado y para a quien la reescribe
  [ -n "$vivo" ] || return 0
  kill "$vivo" 2>/dev/null; wait "$vivo" 2>/dev/null; vivo=""
  printf '\r\033[K' >&2
}
trap para_estado EXIT

SIN_PERSONA="Corres desde goal.sh, sin nadie mirando: nadie va a responder preguntas ni aprobar nada. \
Si la skill te dice que te detengas, o no puedes seguir por cualquier motivo, termina con una línea \
que empiece por 'Bloqueo: ' y el motivo; si el motivo es un ADR, escribe 'necesita ADR' en esa línea. \
No uses la palabra 'Bloqueo' para nada más."

# Ship no activa el auto-merge: el clasificador del modo auto lo niega ("Merge
# Without Review") y lo decide activa_auto, que mira los archivos del PR.
SIN_AUTO=" No actives el auto-merge ni lo intentes: goal.sh lo activa después si ningún archivo del PR \
cae en codeowners_paths. En la línea 4 del cierre escribe 'Merge: lo decide goal.sh'."

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
  if [ -n "$quiet" ]; then
    (cd "$1" && claude "${args[@]}") >"$2" 2>&1 </dev/null
    rc=$?
  else
    # El stream completo va a <salida>.jsonl; la salida queda como en modo texto:
    # stderr, lo que no sea JSON y el texto del último result.
    local fase=${2##*-} stream=${2%.txt}.jsonl
    fase=${fase%.txt}
    estado_vivo "$fase" "sesión $sesiones/$max_sesiones"
    (cd "$1" && claude "${args[@]}" --output-format stream-json --verbose) 2>"$2" </dev/null \
      | tee "$stream" | { herramientas "$1" "$fase"; cat >/dev/null; }
    rc=${PIPESTATUS[0]}
    para_estado
    jq -R -s -r 'split("\n") | map(select(length > 0) | {l: ., j: ((try fromjson catch null) | if type == "object" then . else null end)})
      | (.[] | select(.j == null) | .l), ([.[].j | select(.type? == "result")] | last | .result? | strings)' \
      "$stream" >>"$2" 2>>"$log"
  fi
  cat "$2" >>"$log"
  anota "claude salió con $rc (salida en $2)"
  if grep -qF 'Not logged in' "$2"; then
    parada="claude sin sesión"; anota "PARADA: $parada: corre \`claude\` y /login"; return 1
  fi
  return 0
}

# El auto-merge lo activa goal.sh, nunca la sesión. Un PR que toca una ruta de
# codeowners_paths no queda en auto-merge: si el autor es el único dueño, GitHub
# no le pide su revisión y entraría sin que nadie lo lea. Los patrones salen de
# origin/main, no del PR ni del checkout. Con [[ == ]] un `*` también cruza `/`:
# casa de más, nunca de menos. Cuenta también el nombre anterior de un renombrado.
activa_auto() { # activa_auto <n>: deja resultado vacío (auto-merge activo), retenido o sin-auto, y razon
  local n=$1 sha archivos patrones f p
  resultado=""; razon=""
  patrones=$(git show origin/main:.city.json 2>>"$log" | jq -r '.codeowners_paths // [] | .[]' 2>>"$log")
  if [ -z "$patrones" ]; then
    for f in .github/CODEOWNERS CODEOWNERS docs/CODEOWNERS; do
      if git cat-file -e "origin/main:$f" 2>/dev/null; then
        resultado=sin-auto; razon="hay $f y .city.json no trae codeowners_paths"; return
      fi
    done
  fi
  sha=$(gh pr view "$n" --json headRefOid --jq .headRefOid 2>>"$log")
  archivos=$(gh api --paginate "repos/{owner}/{repo}/pulls/$n/files" \
    --jq '.[] | .filename, (.previous_filename // empty)' 2>>"$log")
  if [ -z "$sha" ] || [ -z "$archivos" ]; then
    resultado=sin-auto; razon="no pude leer la cabeza o los archivos del PR #$n"; return
  fi
  while IFS= read -r f; do
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      # shellcheck disable=SC2053 # sin comillas, p es patrón
      if [[ "$f" == $p ]]; then razon="$razon $f"; break; fi
    done <<<"$patrones"
  done <<<"$archivos"
  if [ -n "$razon" ]; then
    resultado=retenido; razon=${razon# }; anota "PR #$n: toca $razon; queda sin auto-merge"; return
  fi
  # Atado al SHA cuyos archivos se leyeron: si llegó otro push, no se activa.
  if gh pr merge "$n" --auto --squash --match-head-commit "$sha" >>"$log" 2>&1; then
    anota "PR #$n: auto-merge activo sobre $(printf '%.7s' "$sha")"
  else
    resultado=sin-auto; razon="gh pr merge --auto falló (ver el log)"
  fi
}

espera_pr() { # espera_pr <n>: deja en resultado merged, cerrado, rojo, retenido, sin-auto o tiempo
  local n=$1 inicio=$SECONDS estado_pr pendientes info
  fallidos=""
  anota "PR #$n: esperando checks y merge"
  estado_vivo "PR #$n" "" "$n"
  gh pr checks "$n" --watch --fail-fast --interval "$intervalo" >>"$log" 2>&1
  while :; do
    estado_pr=$(gh pr view "$n" --json state --jq .state 2>>"$log")
    case "$estado_pr" in
      MERGED) resultado=merged; break ;;
      CLOSED) resultado=cerrado; break ;;
    esac
    fallidos=$(gh pr checks "$n" --json name,bucket \
      --jq '[.[] | select(.bucket == "fail" or .bucket == "cancel") | .name] | join(", ")' 2>>"$log")
    if [ -n "$fallidos" ]; then resultado=rojo; break; fi
    pendientes=$(gh pr checks "$n" --json bucket --jq '[.[] | select(.bucket == "pending")] | length' 2>>"$log")
    if [ "${pendientes:-1}" = 0 ]; then
      # Todo en verde y sin merge: sin auto-merge (nació bloqueado) o retenido por CODEOWNERS.
      info=$(gh pr view "$n" --json autoMergeRequest,reviewDecision \
        --jq '"\(.autoMergeRequest != null) \(.reviewDecision)"' 2>>"$log")
      case "$info" in
        false*) resultado=sin-auto; break ;;
        *REVIEW_REQUIRED*|*CHANGES_REQUESTED*) resultado=retenido; break ;;
      esac
    fi
    if [ $((SECONDS - inicio)) -ge "$espera_max" ]; then resultado=tiempo; break; fi
    sleep "$intervalo"
  done
  para_estado
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
    sesion "$wt" "$dir_log/$fecha-$id-ship$intento.txt" "/city:ship" "$SIN_AUTO$extra" || { motivo=$parada; break; }
    if [ "$rc" -ne 0 ]; then motivo="ship salió con $rc"; break; fi
    pr=$(gh pr list --head "$rama" --state all --json number --jq '.[0].number // empty' 2>>"$log")
    if [ -z "$pr" ]; then pr="—"; motivo="ship no abrió PR"; break; fi
    estado=OPEN
    activa_auto "$pr"
    case "$resultado" in
      retenido) motivo="retenido por CODEOWNERS: $razon"; break ;;
      sin-auto) motivo="sin auto-merge: $razon"; break ;;
    esac
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
    # El reintento empuja a esta rama: con el auto-merge armado, entraría en
    # cuanto pasen los checks, sin que activa_auto vuelva a leer sus archivos.
    if ! gh pr merge "$pr" --disable-auto >>"$log" 2>&1 &&
       [ "$(gh pr view "$pr" --json autoMergeRequest --jq '.autoMergeRequest != null' 2>>"$log")" != false ]; then
      motivo="no pude quitar el auto-merge del PR #$pr antes del reintento"; break
    fi
    intento=2
    extra=" El PR #$pr de esta rama tiene checks en rojo: $fallidos. Míralos con gh pr checks $pr y gh run view --log-failed, y corrige en esta misma rama."
  done
  pasos=$(pasos_evaluador "$wt" "$id")
  baja "$wt"
  if [ "$estado" = MERGED ]; then
    git worktree remove --force "$wt" >>"$log" 2>&1 || anota "no pude borrar $wt"
    git branch -D "$rama" >>"$log" 2>&1
  elif [ "$parada" = "claude sin sesión" ] && [ -z "$rama" ]; then
    # build no llegó a correr: el worktree quedó vacío y bloquearía la corrida siguiente.
    git worktree remove "$wt" >>"$log" 2>&1 || anota "no pude borrar $wt"
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
