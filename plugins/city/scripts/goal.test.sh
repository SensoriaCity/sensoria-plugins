#!/usr/bin/env bash
# Prueba en seco de goal.sh con claude, gh y docker falsos en el PATH, sobre un
# repo de prueba con su origin. Recorre dos ids: S1 entra (build, ship, checks
# en verde, merge) y S2 para por "Bloqueo" en la salida de build. Luego, la
# guarda del auto-merge (rutas de dueños, renombrados y reintento) y claude
# sin sesión: antes del primer worktree y en la salida de build. Corre goal.sh
# con el mismo bash que corre esta prueba. Sale con 0 si todo cumple.
set -uo pipefail

G="$(cd "$(dirname "$0")" && pwd)/goal.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fallas=0
falla() { echo "FALLA: $1"; fallas=$((fallas + 1)); }
export GIT_AUTHOR_NAME=v GIT_AUTHOR_EMAIL=v@v GIT_COMMITTER_NAME=v GIT_COMMITTER_EMAIL=v@v

git init -q --bare "$tmp/origin.git"
git init -q "$tmp/repo"
(
  cd "$tmp/repo" && git checkout -q -b main \
    && printf '{"ramas": "feat/", "label": "city", "features": "f", "evidencia_dir": "ev", "codeowners_paths": ["docs/adr/**", "docker/**"]}\n' > .city.json \
    && mkdir f && printf '{"id": "S1", "passes": false}\n' > f/S1.json \
    && printf '{"id": "S2", "passes": false}\n' > f/S2.json \
    && git add . && git commit -q -m base \
    && git remote add origin "$tmp/origin.git" && git push -q origin main
) || { echo "FALLA: no pude armar el repo de prueba"; exit 1; }

mkdir -p "$tmp/bin" "$tmp/t"
L="$tmp/llamadas"
# claude falso: con --output-format stream-json emite un stream pequeño (texto,
# herramientas, un subagente, una salida con un secreto y el result); sin él,
# solo el texto, como claude -p en modo texto.
printf '#!/bin/sh\nL="%s"\n' "$L" > "$tmp/bin/claude"
cat >> "$tmp/bin/claude" <<'EOF'
prompt=""; modo=""; formato=""; extra=""
while [ $# -gt 0 ]; do
  case "$1" in
    -p) prompt=$2; shift ;; --permission-mode) modo=$2; shift ;; --output-format) formato=$2; shift ;;
    --append-system-prompt) extra=$2; shift ;;
  esac
  shift
done
echo "claude $modo $prompt" >> "$L"
[ "$prompt" != /city:ship ] || echo "ship-extra $extra" >> "$L"
texto() {
  case "${SIN_SESION:-}:$prompt" in
    todo:*|build:/city:build*) echo "Not logged in · Please run /login"; exit 1 ;;
  esac
  case "$prompt" in
    "/city:build S1"*)
      git switch -q -c "feat/$(date +%Y-%m-%d)-S1" && mkdir -p ev
      printf '# Evidencia · S1 · hoy · abc\n\n| Paso | Qué hizo | Resultado |\n|---|---|---|\n| 1 | a | cumple |\n| 2 | b | cumple |\n\nVEREDICTO: pasa\n' > ev/S1.md
      git add ev && git commit -q -m "test(s1): evidencia de S1"
      echo "7. Siguiente paso: /city:ship en esta sesión." ;;
    "/city:build S2"*) echo "Bloqueo: falta el usuario de prueba" ;;
    "/city:build S6"*|"/city:build S7"*|"/city:build S8"*)
      id=${prompt#/city:build }; id=${id%% *}
      git switch -q -c "feat/$(date +%Y-%m-%d)-$id" 2>/dev/null || true
      echo "7. Siguiente paso: /city:ship en esta sesión." ;;
    "/city:ship") echo "1. PR: https://github.com/x/y/pull/7" ;;
  esac
}
[ "$formato" = stream-json ] || { texto; exit; }
echo '{"type":"system","subtype":"init"}'
jq -nc --arg f "$PWD/ev/S1.md" '{type: "assistant", parent_tool_use_id: null, message: {content: [
  {type: "text", text: "PENSANDO-EN-VOZ-ALTA"},
  {type: "tool_use", id: "t1", name: "Bash", input: {command: "git switch -c feat/S1\necho hecho"}},
  {type: "tool_use", id: "t2", name: "Agent", input: {subagent_type: "city:evaluador", prompt: "PROMPT-DEL-SUBAGENTE"}}]}},
  {type: "assistant", parent_tool_use_id: "t2", message: {content: [{type: "tool_use", id: "t3", name: "Read", input: {file_path: $f}}]}},
  {type: "user", parent_tool_use_id: null, message: {content: [{type: "tool_result", tool_use_id: "t1", content: "SECRETO=abc"}]}}'
echo 'línea suelta que no es JSON'
sleep "${PAUSA:-0}"
if [ "$prompt" = "/city:build S5" ]; then echo "claude murió a medias" >&2; exit 3; fi
t=$(texto); r=$?
jq -nc --arg t "$t" '{type: "result", subtype: "success", is_error: false, result: $t}'
exit "$r"
EOF
cat > "$tmp/bin/gh" <<EOF
#!/bin/sh
echo "gh \$*" >> "$L"
# PR 7 (S1) entra; 8 (S6) toca docs/adr; 9 (S7) renombra desde docker/; 10 (S8)
# sigue abierto con un check en rojo.
case "\$1 \$2" in
  "pr list") case "\$*" in *-S1*) echo 7 ;; *-S6*) echo 8 ;; *-S7*) echo 9 ;; *-S8*) echo 10 ;; esac ;;
  "pr view") case "\$*" in
      *headRefOid*) echo abc1234def ;;
      *autoMergeRequest*) echo true ;;
      *" 10 "*) echo OPEN ;;
      *) echo MERGED ;;
    esac ;;
  "pr checks") case "\$*" in *" 10 "*name,bucket*) echo api ;; esac ;;
  "api --paginate") case "\$*" in
      */pulls/8/files*) printf 'api/x.php\ndocs/adr/ADR-9.md\n' ;;
      */pulls/9/files*) printf 'api/nuevo.sh\ndocker/viejo.sh\n' ;;
      *) echo api/x.php ;;
    esac ;;
esac
exit 0
EOF
cat > "$tmp/bin/docker" <<EOF
#!/bin/sh
echo "docker \$*" >> "$L"
EOF
chmod +x "$tmp/bin/claude" "$tmp/bin/gh" "$tmp/bin/docker"

salida=$(cd "$tmp/repo" && PATH="$tmp/bin:$PATH" TMPDIR="$tmp/t" GOAL_INTERVALO=1 GOAL_ESPERA_MAX=5 \
  "$BASH" "$G" S1 S2 2>"$tmp/stderr")
rc=$?

[ "$rc" -eq 1 ] || falla "con S2 sin merge debería salir con 1 (salió con $rc)"
echo "$salida" | grep -qF '| S1 | #7 | MERGED | 2/2 cumplen · pasa | entró |' || falla "S1 debería entrar con el PR 7 y 2/2 pasos"
echo "$salida" | grep -qF '| S2 | — | sin PR | — | Bloqueo: falta el usuario de prueba |' || falla "S2 debería parar por Bloqueo sin PR"
echo "$salida" | grep -qF 'Parada global: build de S2: Bloqueo' || falla "el Bloqueo de S2 debería ser parada global"
echo "$salida" | grep -qF '/city:check' || falla "el resumen debería terminar en /city:check"
[ "$(head -n1 "$L")" = "claude  Responde solo: ok" ] || falla "lo primero debería ser la prueba de sesión de claude"
[ "$(grep -c '^claude auto ' "$L")" -eq 3 ] || falla "debería haber 3 sesiones de claude: build S1, ship S1 y build S2"
grep -q '^claude auto /city:build S1$' "$L" || falla "build S1 debería correr con --permission-mode auto"
grep -q '^claude auto /city:ship$' "$L" || falla "ship debería correr con --permission-mode auto"
[ "$(grep -c '^claude auto /city:ship' "$L")" -eq 1 ] || falla "S2 no debería llegar a ship"
grep -q '^gh pr checks 7 --watch' "$L" || falla "debería esperar los checks del PR 7 con --watch"
grep -qx 'gh pr merge 7 --auto --squash --match-head-commit abc1234def' "$L" \
  || falla "debería activar el auto-merge del PR 7 atado a su cabeza"
[ "$(grep -n '^gh pr merge 7 --auto' "$L" | cut -d: -f1)" -gt "$(grep -n '^claude auto /city:ship' "$L" | cut -d: -f1)" ] \
  || falla "el auto-merge debería activarse después de ship"
grep -q '^ship-extra .*No actives el auto-merge' "$L" || falla "ship debería recibir que no active el auto-merge"
[ "$(grep -c '^docker compose --profile onprem down -v --remove-orphans$' "$L")" -eq 2 ] \
  || falla "debería bajar la instalación de cada id"
[ ! -e "$tmp/repo/.claude/worktrees/goal-S1" ] || falla "el worktree de S1 debería borrarse: su PR entró"
[ -d "$tmp/repo/.claude/worktrees/goal-S2" ] || falla "el worktree de S2 debería quedar: su PR no entró"
git -C "$tmp/repo" worktree list | grep -q 'goal-S1' && falla "git todavía lista el worktree de S1"
[ -z "$(git -C "$tmp/repo" branch --list 'feat/*-S1')" ] || falla "la rama local de S1 debería borrarse tras el merge"
ls "$tmp"/t/city-goal/*.log >/dev/null 2>&1 || falla "el log debería quedar en \$TMPDIR/city-goal"
[ -z "$(git -C "$tmp/repo" status --porcelain -- . ':!.claude')" ] || falla "goal.sh no debería dejar archivos en el repo"

# El avance: una línea por herramienta en stderr y en el log, sin contenidos ni
# salidas; sin TTY, sin \r. El stream completo queda en el .jsonl y el .txt
# tiene lo mismo que daría claude -p en modo texto.
d="$tmp/t/city-goal"
grep -qF 'S1 · build1 · Bash · git switch -c feat/S1 echo hecho' "$tmp/stderr" || falla "debería mostrar el comando de Bash de build1"
grep -qF 'S1 · build1 · Agent · city:evaluador' "$tmp/stderr" || falla "debería mostrar el subagente de Agent"
grep -qF 'S1 · build1 · ↳ Read · ev/S1.md' "$tmp/stderr" || falla "debería mostrar el Read del subagente con su ruta relativa"
grep -qF 'S2 · build1 · Bash' "$tmp/stderr" || falla "debería mostrar las herramientas de build de S2"
grep -qF 'S1 · ship1 · Bash' "$tmp/stderr" || falla "debería mostrar las herramientas de ship"
grep -qF 'S1 · build1 · Agent' "$d"/*.log || falla "las líneas de herramientas deberían quedar en el log"
grep -qE 'SECRETO|PROMPT-DEL|PENSANDO' "$tmp/stderr" && falla "stderr no debería traer salidas, prompts ni texto de las sesiones"
grep -q "$(printf '\r')" "$tmp/stderr" && falla "sin TTY no debería haber \\r en stderr"
[ "$(cat "$d"/*-S1-build1.txt)" = "$(printf 'línea suelta que no es JSON\n7. Siguiente paso: /city:ship en esta sesión.')" ] \
  || falla "el .txt de build1 de S1 debería tener lo que no es JSON y el texto del result"
[ "$(tail -n1 "$d"/*-S2-build1.txt)" = "Bloqueo: falta el usuario de prueba" ] || falla "el .txt de build de S2 debería terminar en su Bloqueo"
grep -q '"type":"result"' "$d"/*-S1-build1.jsonl || falla "el stream completo debería quedar en el .jsonl"

# --quiet: lo de antes, sin stream ni herramientas, y el mismo resumen y .txt.
git -C "$tmp/repo" worktree remove --force "$tmp/repo/.claude/worktrees/goal-S2"
mkdir -p "$tmp/q"
salida_q=$(cd "$tmp/repo" && PATH="$tmp/bin:$PATH" TMPDIR="$tmp/q" GOAL_INTERVALO=1 GOAL_ESPERA_MAX=5 \
  "$BASH" "$G" S1 S2 --quiet 2>"$tmp/stderr-q")
rc=$?
[ "$rc" -eq 1 ] || falla "con --quiet debería salir con 1 como sin él (salió con $rc)"
normaliza() { sed -e '1s/ · .*//' -e '/^Log: /d'; }
[ "$(echo "$salida" | normaliza)" = "$(echo "$salida_q" | normaliza)" ] || falla "con --quiet el resumen debería ser el mismo"
grep -q ' · build1 · ' "$tmp/stderr-q" && falla "con --quiet no debería mostrar herramientas"
ls "$tmp"/q/city-goal/*.jsonl >/dev/null 2>&1 && falla "con --quiet no debería escribir .jsonl"
for f in S1-build1 S1-ship1 S2-build1; do
  [ "$(cat "$tmp"/q/city-goal/*-$f.txt)" = "$(grep -v '^línea suelta' "$d"/*-$f.txt)" ] \
    || falla "con --quiet el .txt de $f debería ser el texto de su result"
done
git -C "$tmp/repo" worktree remove --force "$tmp/repo/.claude/worktrees/goal-S2"

# Un stream sin result (claude murió): el .txt lleva lo que haya y el id para.
: > "$L"
salida_m=$(cd "$tmp/repo" && PATH="$tmp/bin:$PATH" TMPDIR="$tmp/m" "$BASH" "$G" S5 2>"$tmp/stderr-m")
echo "$salida_m" | grep -qF '| S5 | — | sin PR | — | build salió con 3 |' || falla "S5 debería parar con build salió con 3"
[ "$(cat "$tmp"/m/city-goal/*-S5-build1.txt)" = "$(printf 'claude murió a medias\nlínea suelta que no es JSON')" ] \
  || falla "sin result, el .txt de S5 debería traer stderr y lo que no es JSON"
grep -qF 'S5 · build1 · Bash' "$tmp/stderr-m" || falla "sin result, las herramientas deberían verse igual"
git -C "$tmp/repo" worktree remove --force "$tmp/repo/.claude/worktrees/goal-S5"

# La guarda: un PR con una ruta de dueños, también renombrada desde ella, no
# queda en auto-merge ni espera checks; para con "retenido por CODEOWNERS".
: > "$L"
salida_r=$(cd "$tmp/repo" && PATH="$tmp/bin:$PATH" TMPDIR="$tmp/r" GOAL_INTERVALO=1 GOAL_ESPERA_MAX=5 \
  "$BASH" "$G" S6 S7 --quiet 2>/dev/null)
echo "$salida_r" | grep -qF '| S6 | #8 | OPEN | — | retenido por CODEOWNERS: docs/adr/ADR-9.md |' \
  || falla "S6 debería quedar retenido por docs/adr/ADR-9.md"
echo "$salida_r" | grep -qF '| S7 | #9 | OPEN | — | retenido por CODEOWNERS: docker/viejo.sh |' \
  || falla "S7 debería quedar retenido por el nombre anterior docker/viejo.sh"
grep -qE '^gh pr merge (8|9) ' "$L" && falla "un PR con rutas de dueños no debería tocar el merge"
grep -qE '^gh pr checks (8|9) --watch' "$L" && falla "un PR retenido no debería esperar checks"
git -C "$tmp/repo" worktree remove --force "$tmp/repo/.claude/worktrees/goal-S6"
git -C "$tmp/repo" worktree remove --force "$tmp/repo/.claude/worktrees/goal-S7"

# Con checks en rojo, quita el auto-merge antes del reintento de build.
: > "$L"
salida_ro=$(cd "$tmp/repo" && PATH="$tmp/bin:$PATH" TMPDIR="$tmp/ro" GOAL_INTERVALO=1 GOAL_ESPERA_MAX=5 \
  "$BASH" "$G" S8 --quiet 2>/dev/null)
echo "$salida_ro" | grep -qF '| S8 | #10 | OPEN | — | checks en rojo dos veces: api |' \
  || falla "S8 debería parar con checks en rojo dos veces"
[ "$(grep -c '^claude auto /city:build S8' "$L")" -eq 2 ] || falla "S8 debería reintentar build una vez"
quita=$(grep -n '^gh pr merge 10 --disable-auto$' "$L" | head -n1 | cut -d: -f1)
build2=$(grep -n '^claude auto /city:build S8' "$L" | sed -n 2p | cut -d: -f1)
[ -n "$quita" ] && [ "$quita" -lt "${build2:-0}" ] || falla "debería quitar el auto-merge del PR 10 antes del reintento"
git -C "$tmp/repo" worktree remove --force "$tmp/repo/.claude/worktrees/goal-S8"

# Con TTY (script de macOS), la línea de estado se reescribe con \r.
if [ "$(uname)" = Darwin ]; then
  (cd "$tmp/repo" && PATH="$tmp/bin:$PATH" TMPDIR="$tmp/y" PAUSA=2 \
    script -q "$tmp/tty" "$BASH" "$G" S2 >/dev/null 2>&1 </dev/null)
  grep -qF "$(printf '\r\033[K[1/1] S2 · build1 · 0m0')" "$tmp/tty" || falla "con TTY debería mostrar la línea de estado de build1"
  grep -qF ' · sesión 1/12' "$tmp/tty" || falla "la línea de estado debería decir la sesión"
  git -C "$tmp/repo" worktree remove --force "$tmp/repo/.claude/worktrees/goal-S2"
fi

# Sin sesión de claude, goal.sh no arranca: ni worktrees ni ids.
: > "$L"
salida_ss=$(cd "$tmp/repo" && PATH="$tmp/bin:$PATH" TMPDIR="$tmp/t" SIN_SESION=todo "$BASH" "$G" S3 S4 2>"$tmp/stderr-ss")
rc=$?
[ "$rc" -eq 2 ] || falla "sin sesión de claude debería salir con 2 (salió con $rc)"
grep -q '/login' "$tmp/stderr-ss" || falla "sin sesión de claude debería pedir /login"
[ -z "$salida_ss" ] || falla "sin sesión de claude no debería escribir resumen"
grep -q '^claude auto ' "$L" && falla "sin sesión de claude no debería abrir sesiones de build ni ship"
grep -q '^docker ' "$L" && falla "sin sesión de claude no debería llegar a ningún id"
[ ! -e "$tmp/repo/.claude/worktrees/goal-S3" ] || falla "sin sesión de claude no debería crear worktrees"

# Si una sesión dice "Not logged in", es parada global y no fallo del id.
: > "$L"
salida_sb=$(cd "$tmp/repo" && PATH="$tmp/bin:$PATH" TMPDIR="$tmp/t" SIN_SESION=build "$BASH" "$G" S3 S4 2>"$tmp/stderr-sb")
rc=$?
[ "$rc" -eq 1 ] || falla "con build sin sesión debería salir con 1 (salió con $rc)"
echo "$salida_sb" | grep -qF 'Parada global: claude sin sesión.' || falla "Not logged in en build debería ser parada global"
echo "$salida_sb" | grep -qF '| S3 | — | sin PR | — | claude sin sesión |' || falla "S3 debería decir claude sin sesión"
echo "$salida_sb" | grep -qF '| S4 | — | sin correr | — | no corrió: claude sin sesión |' || falla "S4 no debería correr"
[ "$(grep -c '^claude auto ' "$L")" -eq 1 ] || falla "tras Not logged in no debería abrir más sesiones"
[ ! -e "$tmp/repo/.claude/worktrees/goal-S3" ] || falla "el worktree vacío de S3 debería borrarse"

# Con git.merge manual, goal.sh no arranca ni abre sesiones.
: > "$L"
jq '. + {git: {merge: "manual"}}' "$tmp/repo/.city.json" > "$tmp/manual.json" && cp "$tmp/manual.json" "$tmp/repo/.city.json"
(cd "$tmp/repo" && PATH="$tmp/bin:$PATH" TMPDIR="$tmp/t" "$BASH" "$G" S2 >/dev/null 2>"$tmp/stderr-manual")
rc=$?
[ "$rc" -eq 2 ] || falla "con git.merge manual debería salir con 2 (salió con $rc)"
grep -q 'merge de este repo es manual' "$tmp/stderr-manual" || falla "con git.merge manual debería decir por qué no arranca"
grep -q '^claude ' "$L" && falla "con git.merge manual no debería abrir sesiones de claude"

if [ "$fallas" -gt 0 ]; then
  echo "--- stdout"; echo "$salida"; echo "--- stderr"; cat "$tmp/stderr"; echo "--- llamadas"; cat "$L"
  exit 1
fi
echo "goal.sh en seco: 2 ids, uno entra y otro para por Bloqueo; guarda del auto-merge; --quiet; stream sin result; claude sin sesión antes y durante (bash $BASH_VERSION)"
