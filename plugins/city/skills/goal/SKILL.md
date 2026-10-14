---
name: goal
description: Explica y prepara el bucle por objetivo, scripts/goal.sh, que corre varias funcionalidades de features sin nadie mirando, una a la vez, cada una con build → ship → checks → merge en su propio worktree, con paradas globales. Da la línea exacta para lanzarlo en una terminal y cómo leer el log. El cierre es /city:check.
argument-hint: "<id>... [--plan <ruta>] [--max-sesiones N] [--max-bloqueos N]"
disable-model-invocation: true
---

# /city:goal

Entrada: $ARGUMENTS

No corres el bucle en esta sesión: dura horas y abre sus propias sesiones de `claude -p`. Compruebas que puede arrancar y le das a la persona la línea para lanzarlo en una terminal.

## Antes de lanzar

1. `.city.json` en la raíz del repo (`git rev-parse --show-toplevel`); si no existe, detente y dilo. De ahí salen `ramas`, `features`, `evidencia_dir`, `qa.bajar` y `git.merge`. Su contrato: `${CLAUDE_PLUGIN_ROOT}/city.schema.json`.
2. Cada id existe en `origin/main` con `passes: false` y sin `reemplazada_por` (el bucle construye desde ahí): `git show origin/main:<features>/<id>.json | jq '{passes, reemplazada_por}'`. Los cortes de una spec son secuenciales: van en orden, c1 antes que c2.
3. Ningún PR abierto trae ya ese id (`gh pr list --state open`), ni queda `.claude/worktrees/goal-<id>` de una corrida anterior.
4. `docker info` responde y no hay otra instalación viva: en la máquina cabe una sola.
5. Si pasan `--plan`, el archivo existe.
6. `git.merge` no es `manual`: el bucle espera el auto-merge de cada PR (`${CLAUDE_PLUGIN_ROOT}/skills/ship/git.md`). `goal.sh` también lo comprueba.

Si algo falla, dilo y no des la línea.

## La línea

```
caffeinate -i bash "${CLAUDE_PLUGIN_ROOT}/scripts/goal.sh" <id>... [--plan <ruta>] > goal.md
```

Desde la raíz del repo. `caffeinate -i` evita que el Mac se duerma; `goal.md` recibe el resumen y el avance sale por la terminal.

## Qué hace, por id y en orden

1. `git fetch` y worktree nuevo `.claude/worktrees/goal-<id>` desde `origin/main`.
2. `claude -p "/city:build <id> [plan]" --permission-mode auto --permission-prompts none`, con la instrucción de terminar en `Bloqueo: <motivo>` si se detiene.
3. Sin bloqueo, `claude -p "/city:ship"`; toma el PR con `gh pr list --head <rama>`, espera `gh pr checks --watch` y luego el merge.
4. Si un check falla: un reintento de build sobre la misma rama, con los checks en rojo como contexto, y otro ship. Al segundo fallo, ese id para.
5. Baja la instalación con `qa.bajar` (sin él, Compose con el perfil `onprem`, `down -v`) y borra el worktree solo si el PR entró.

## Paradas globales

- `--max-sesiones N` (12): cada build y cada ship es una sesión.
- `--max-bloqueos N` (2): ids seguidos sin merge, por la razón que sea.
- Una salida de build con `necesita ADR` o `Bloqueo`, también la de su compuerta de corte, que detiene el bucle antes de escribir código.
- Docker apagado.

Un id también para sin parar el bucle si build no deja su rama, ship no abre PR, el PR queda retenido por CODEOWNERS, nace bloqueado (verde sin auto-merge) o pasan 2 h sin merge.

## Leer el resultado

- `goal.md`: una fila por id con PR, estado (`MERGED`, `OPEN`, `CLOSED`, `sin PR`), pasos del evaluador (`cumplen` de la tabla de la evidencia y el veredicto) y por qué paró; abajo, sesiones usadas y la parada global.
- Log: `${TMPDIR:-/tmp}/city-goal/<fecha>.log`, fuera del repo. Cada línea con hora; `PARADA:` marca la que cortó el bucle. La salida completa de cada sesión queda junto al log, en `<fecha>-<id>-build1.txt`, `-ship1.txt`, etc.
- Un id que no entró deja su worktree para que una persona lo retome con `/city:build <id>` en esa carpeta. Si paró en la compuerta de corte, borra el worktree (`git worktree remove`) y parte la funcionalidad con `/city:spec partir <id>`.

El cierre es `/city:check`: `hoy` a la mañana siguiente, o `<id>` por funcionalidad. Ahí se ve qué entró, qué quedó retenido y qué está en rojo.
