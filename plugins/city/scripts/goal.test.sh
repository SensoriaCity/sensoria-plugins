#!/usr/bin/env bash
# Prueba en seco de goal.sh con claude, gh y docker falsos en el PATH, sobre un
# repo de prueba con su origin. Recorre dos ids: S1 entra (build, ship, checks
# en verde, merge) y S2 para por "Bloqueo" en la salida de build. Corre goal.sh
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
    && printf '{"ramas": "feat/", "label": "city", "features": "f", "evidencia_dir": "ev"}\n' > .city.json \
    && mkdir f && printf '{"id": "S1", "passes": false}\n' > f/S1.json \
    && printf '{"id": "S2", "passes": false}\n' > f/S2.json \
    && git add . && git commit -q -m base \
    && git remote add origin "$tmp/origin.git" && git push -q origin main
) || { echo "FALLA: no pude armar el repo de prueba"; exit 1; }

mkdir -p "$tmp/bin" "$tmp/t"
L="$tmp/llamadas"
cat > "$tmp/bin/claude" <<EOF
#!/bin/sh
prompt=""; modo=""
while [ \$# -gt 0 ]; do
  case "\$1" in -p) prompt=\$2; shift ;; --permission-mode) modo=\$2; shift ;; esac
  shift
done
echo "claude \$modo \$prompt" >> "$L"
case "\$prompt" in
  "/city:build S1"*)
    git switch -q -c "feat/\$(date +%Y-%m-%d)-S1" && mkdir -p ev
    printf '# Evidencia · S1 · hoy · abc\n\n| Paso | Qué hizo | Resultado |\n|---|---|---|\n| 1 | a | cumple |\n| 2 | b | cumple |\n\nVEREDICTO: pasa\n' > ev/S1.md
    git add ev && git commit -q -m "test(s1): evidencia de S1"
    echo "7. Siguiente paso: /city:ship en esta sesión." ;;
  "/city:build S2"*) echo "Bloqueo: falta el usuario de prueba" ;;
  "/city:ship") echo "1. PR: https://github.com/x/y/pull/7" ;;
esac
EOF
cat > "$tmp/bin/gh" <<EOF
#!/bin/sh
echo "gh \$*" >> "$L"
case "\$1 \$2" in
  "pr list") case "\$*" in *-S1*) echo 7 ;; esac ;;
  "pr view") echo MERGED ;;
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
[ "$(grep -c '^claude ' "$L")" -eq 3 ] || falla "debería haber 3 sesiones de claude: build S1, ship S1 y build S2"
grep -q '^claude auto /city:build S1$' "$L" || falla "build S1 debería correr con --permission-mode auto"
grep -q '^claude auto /city:ship$' "$L" || falla "ship debería correr con --permission-mode auto"
[ "$(grep -c '^claude auto /city:ship' "$L")" -eq 1 ] || falla "S2 no debería llegar a ship"
grep -q '^gh pr checks 7 --watch' "$L" || falla "debería esperar los checks del PR 7 con --watch"
[ "$(grep -c '^docker compose --profile onprem down -v --remove-orphans$' "$L")" -eq 2 ] \
  || falla "debería bajar la instalación de cada id"
[ ! -e "$tmp/repo/.claude/worktrees/goal-S1" ] || falla "el worktree de S1 debería borrarse: su PR entró"
[ -d "$tmp/repo/.claude/worktrees/goal-S2" ] || falla "el worktree de S2 debería quedar: su PR no entró"
git -C "$tmp/repo" worktree list | grep -q 'goal-S1' && falla "git todavía lista el worktree de S1"
[ -z "$(git -C "$tmp/repo" branch --list 'feat/*-S1')" ] || falla "la rama local de S1 debería borrarse tras el merge"
ls "$tmp"/t/city-goal/*.log >/dev/null 2>&1 || falla "el log debería quedar en \$TMPDIR/city-goal"
[ -z "$(git -C "$tmp/repo" status --porcelain -- . ':!.claude')" ] || falla "goal.sh no debería dejar archivos en el repo"

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
echo "goal.sh en seco: 2 ids, uno entra y otro para por Bloqueo (bash $BASH_VERSION)"
