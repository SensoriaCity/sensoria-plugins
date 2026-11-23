---
name: goal
description: Explica y prepara el bucle por objetivo, scripts/goal.sh, que corre los cortes de un hito en orden, uno a la vez, cada uno con build → ship → checks → merge en su propio worktree, con paradas globales. Con git.merge manual abre cada PR y espera a que una persona lo apruebe y lo mergee antes del siguiente. Da la línea exacta para lanzarlo en una terminal y cómo leer el log. El cierre es /city:check.
argument-hint: "<id>... [--plan <ruta>] [--max-sessions N] [--max-blocks N] [--quiet]"
disable-model-invocation: true
---

# /city:goal

Entrada: $ARGUMENTS

No corres el bucle en esta sesión: dura horas y abre sus propias sesiones de `claude -p`. Compruebas que puede arrancar y le das a la persona la línea para lanzarlo en una terminal.

## Antes de lanzar

1. `.city.json` en la raíz del repo (`git rev-parse --show-toplevel`); si no existe, detente y dilo. De ahí salen `branches`, `apps_dir`, `qa.teardown` y `git.merge` (o `ramas` y `qa.bajar`, sus nombres en city 2.x). Su contrato: `${CLAUDE_PLUGIN_ROOT}/city.schema.json`.
2. Cada id existe en `origin/main` con `passes: false`, sin `replaced_by` ni `blocked_by` (el bucle construye desde ahí): `bash "${CLAUDE_PLUGIN_ROOT}/scripts/slice.sh" <id> --ref origin/main` da su `file`, y `git show origin/main:<file> | jq '{passes, replaced_by, blocked_by, depends_on}'`. Van en el orden de `depends_on`: un corte después de los que necesita, y cada uno se construye con los anteriores ya en `main` (el bucle no apila ramas). La spec del hito ya está en `main` (su PR de clase `spec` se aprobó).
3. Ningún PR abierto trae ya ese id (`gh pr list --state open`), ni queda `.claude/worktrees/goal-<id>` de una corrida anterior.
4. `docker info` responde y queda un slot libre: caben tres bucles, uno por slot (`ls "${TMPDIR:-/tmp}/city-goal/slots"`; el de un PID muerto se recupera). Dos bucles no comparten ids: los cortes de una spec van todos en el mismo bucle, en orden.
5. Si pasan `--plan`, el archivo existe.
6. `git.merge` (`${CLAUDE_PLUGIN_ROOT}/skills/ship/git.md`). Con `auto`, el bucle activa el auto-merge de cada PR que no retiene CODEOWNERS. Con `manual`, no activa nada: abre el PR, avisa en el log que espera a una persona y sigue con el corte siguiente cuando ella lo mergea, hasta 24 h (`GOAL_HUMAN_WAIT`, en segundos). Di a la persona que revise cada PR cuando el log diga `espera la aprobación`.

Si algo falla, dilo y no des la línea.

## La línea

```
caffeinate -i bash "${CLAUDE_PLUGIN_ROOT}/scripts/goal.sh" <id>... [--plan <ruta>] > goal.md
```

Desde la raíz del repo. `caffeinate -i` evita que el Mac se duerma; `goal.md` recibe el resumen y el avance sale por la terminal. Con `--quiet`, la terminal muestra solo las líneas del log, sin herramientas ni línea de estado.

## Qué hace, por id y en orden

Antes del primer id toma un slot `sN` libre (de 1 a 3; sin slot libre no arranca y sale con 2) y exporta a sus sesiones `CITY_SLOT`, `CITY_HTTP_PORT` (`808N`), `CITY_MAILPIT_PORT` (`802(5+N)`) y `CITY_BASE_DOMAIN` (`sN.city.localhost`), que nombran `qa.install`, `qa.url` y `qa.port`. Lo suelta al salir.
1. Reclama el id en `${TMPDIR:-/tmp}/city-goal/ids/<id>` (si otro bucle lo tiene, no lo corre), `git fetch` y worktree nuevo `.claude/worktrees/goal-<id>` desde `origin/main`.
2. `claude -p "/city:build <id> [plan]" --permission-mode auto --permission-prompts none`, con la instrucción de terminar en `Bloqueo: <motivo>` si se detiene.
3. Sin bloqueo, `claude -p "/city:ship"`, que no activa el auto-merge; toma el PR con `gh pr list --head <rama>` y lee sus archivos, también el nombre anterior de los renombrados. Si el PR nació con `**Pendiente:** decisión de <persona>` (el revisor terminó en `Veredicto: espera decisión`), no es un rojo: no activa el auto-merge, no espera checks ni reintenta, y el bucle se detiene diciendo quién decide. Si no, y ninguno tiene dueño (`scripts/owners.sh --match` sobre `origin/main`: la unión de `codeowners_paths` y del archivo de dueños del repo), activa `gh pr merge --auto --squash --match-head-commit <cabeza>`, espera `gh pr checks --watch` y luego el merge (si el PR queda `BEHIND`, `gh pr update-branch` y vuelve a esperar los checks; con conflicto, el id para con "conflicto con main"); si alguno cae, el id para con "retenido por CODEOWNERS" y el PR espera a una persona.
4. Si un check falla: quita el auto-merge, un reintento de build sobre la misma rama, con los checks en rojo como contexto, otro ship y otra vez la guarda. Al segundo fallo, ese id para.
5. Baja la instalación de su slot con `qa.teardown` (sin él, Compose con el perfil `onprem`, `down -v`, solo si el `.env` del worktree trae `COMPOSE_PROJECT_NAME`), suelta el id y borra el worktree solo si el PR entró.

## Paradas globales

- `--max-sessions N` (12): cada build y cada ship es una sesión.
- `--max-blocks N` (2): ids seguidos sin merge, por la razón que sea.
- Una salida de build con `necesita ADR` o `Bloqueo`, también la de su compuerta de corte, que detiene el bucle antes de escribir código, y la de un corte cuyos `depends_on` aún no están en `main`.
- Un PR que espera la decisión de una persona: `goal.md` dice `espera decisión de <persona> · <qué>`. No gasta el reintento ni cuenta como check en rojo; cuando la persona decide, el corte se retoma a mano en su worktree.
- Docker apagado, o `claude` sin sesión. Antes del primer worktree, `goal.sh` prueba `claude -p "Responde solo: ok" --max-turns 1 --tools ""`; si dice `Not logged in` o falla, sale con 2 y pide correr `claude` y `/login`. Si una sesión del bucle dice `Not logged in`, para todo con `claude sin sesión` y borra el worktree que quedó vacío.

Un id también para sin parar el bucle si lo construye otro bucle, build no deja su rama, ship no abre PR, el PR queda retenido por CODEOWNERS, nace bloqueado (verde sin auto-merge), tiene conflicto con main o pasan 2 h sin merge.

## Leer el avance y el resultado

- Una línea por herramienta de cada sesión, también en el log: `<hora> <id> · <fase> · <herramienta> · <resumen>`, con la fase (`build1`, `ship1`, `build2`…) y, truncado a 80 caracteres, el comando de Bash, la ruta de Read o Edit o el subagente de Agent; `↳` marca lo que hace un subagente. Nunca contenidos de archivos ni salidas.
- En una terminal, abajo, una línea de estado que se reescribe: `[i/n] <id> · <fase> · <tiempo> · sesión s/max` y, mientras espera el PR, `PR #n · checks <verdes>/<total>`. Con la salida redirigida no aparece.
- `goal.md`: una fila por id con PR, estado (`MERGED`, `OPEN`, `CLOSED`, `sin PR`), pasos del evaluador (`cumplen` de la tabla de la evidencia y el veredicto) y por qué paró; abajo, sesiones usadas y la parada global.
- Log: `${TMPDIR:-/tmp}/city-goal/<fecha>.log`, fuera del repo; `goal.md` dice el slot. Cada línea con hora; `PARADA:` marca la que cortó el bucle. Junto al log, por sesión, el texto final en `<fecha>-<id>-build1.txt`, `-ship1.txt`, etc., y todo lo que hizo en `.jsonl`, que crece mientras corre (`tail -f` para verlo; trae salidas de herramientas, así que no lo compartas).
- Un id que no entró deja su worktree para que una persona lo retome con `/city:build <id>` en esa carpeta. Si paró en la compuerta de corte, borra el worktree (`git worktree remove`) y parte la funcionalidad con `/city:spec split <id>`.

El cierre es `/city:check`: `hoy` a la mañana siguiente, o `<id>` por funcionalidad. Ahí se ve qué entró, qué quedó retenido y qué está en rojo.
