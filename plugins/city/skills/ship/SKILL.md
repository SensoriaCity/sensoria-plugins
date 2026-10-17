---
name: ship
description: Abre el PR de la funcionalidad construida con /city:build, con la plantilla del repo y el label de .city.json, y lo deja en auto-merge por squash o esperando el merge de una persona, según git.merge. Antes comprueba rama, árbol, tamaño, pruebas, veredictos vigentes del revisor y del evaluador, y la evidencia de passes. Úsala al final de /city:build, en la misma sesión.
argument-hint: "(sin argumentos)"
disable-model-invocation: true
---

# /city:ship

Abres el PR y, si el repo usa auto-merge, lo activas. Nunca apruebas ni mergeas: con auto-merge el PR entra cuando pasan los checks requeridos; con merge manual, lo aprueba y lo mergea una persona. Si CODEOWNERS lo retiene, lo lee una persona.

## Configuración

Lee `.city.json` en la raíz del repo (`git rev-parse --show-toplevel`). Si no existe, detente y dilo: el kit no sabe nada del stack y no adivina comandos. De ahí salen los comandos (`tests`, `qa`), las rutas (`features`, `evidencia_dir`, `adr_dir`), el prefijo de rama (`ramas`), el `label`, los `codeowners_paths`, el tope (`tope_lineas`) y las convenciones de commits, merge y versión (`git`, en `${CLAUDE_SKILL_DIR}/git.md`). Su contrato está en `${CLAUDE_PLUGIN_ROOT}/city.schema.json`. Para lo propio de la máquina (puertos, versiones, servidores locales, cómo bajar una instalación), ver `docs/harness/entorno.md` del repo si existe; no lo supongas.

## Chequeos (si uno falla, detente y dilo)

1. **Rama.** Empieza por `ramas` o por un prefijo Conventional: `chore/`, `fix/`, `docs/`, `build/`, `ci/`, `refactor/` o `test/`. Si no, detente. Con `<ramas>AAAA-MM-DD-<id>`, el id de la funcionalidad es lo que sigue a la fecha; con un prefijo Conventional el id es `ninguna`: no hay evaluador, el revisor recibe `ninguna` y ninguna funcionalidad puede pasar a `"passes": true`.
2. **Árbol limpio y al día.** `git status --porcelain` vacío, `git fetch origin` y `git merge-base --is-ancestor origin/main HEAD`. Si no está al día: `git rebase origin/main` si la rama aún no está en `origin`, o `git merge origin/main` si ya está (nunca `push --force`). Con conflictos, detente. Después, vuelve a correr las pruebas.
3. **Tamaño:** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/tamano.sh"`. Si sale con 1, detente y propón la partición en funcionalidades según `${CLAUDE_PLUGIN_ROOT}/skills/spec/cortes.md`.
4. **Pruebas en verde ahora mismo.** Corre otra vez, literales, los comandos de `tests` que aplican al corte, con la regla de `/city:build`: un comando que no existe en el repo se anota y no se reemplaza. Guarda el final de cada salida para el PR.
5. **Veredictos vigentes** del subagente `city:revisor`; del `city:seguridad`, si el diff toca su superficie; y del `city:evaluador` si hay id. Vigente es sin commits con cambios de código después de él; un rebase o merge de `origin/main` sin conflictos no lo invalida. Si falta uno (hubo `/clear`, es otra sesión o hubo cambios después), repítelo ahora como en los pasos 10 y 11 de `/city:build`, con sus 2 vueltas.
6. **passes con evidencia.** `git diff origin/main...HEAD -- <features>`. Si un archivo de `features` pasa a `"passes": true` o nace con él, debe ser `<features>/<id>.json`, el de esta rama, y debe existir en la rama `<evidencia_dir>/<id>.md` con el encabezado `# Evidencia · <id> · …` y la última línea `VEREDICTO: pasa`, lo mismo que exige `scripts/passes.sh`. Si no, detente: `passes` solo cambia con la evidencia del evaluador.
7. **ADR.** La regla del paso 9 de `/city:build`. Si falta, detente y vuelve a `/city:build`.

## Abrir el PR

1. `git push -u origin HEAD`.
2. **Cuerpo.** Usa `.github/PULL_REQUEST_TEMPLATE.md` del repo si existe; si no, `${CLAUDE_SKILL_DIR}/plantilla-pr.md`. Llénalo en un archivo temporal fuera del repo, con datos reales; borra lo que no aplique y no dejes comentarios de la plantilla sin responder. Si la plantilla no las trae, agrega al final:
   - "Decisiones del ejecutor": las que tomó `/city:build`, qué y por qué, o "ninguna".
   - "Evidencia": el final de la salida del chequeo 4 y del tamaño.
   - "Veredictos": revisor, seguridad y evaluador, vueltas y pendientes `debería` y `sugerencia`.
   Si alguno quedó en rojo tras 2 vueltas, la primera línea del cuerpo es `**Bloqueado:** <quién y motivo>`.
3. **Título** según `git.commits` de `${CLAUDE_SKILL_DIR}/git.md`; sin la clave, Conventional Commit en español.
4. `gh pr create --base main --label <label> --title "<título>" --body-file <archivo>`. Si el label no existe, dilo; créalo solo si la persona lo confirma.
5. **Bitácora.** Si el repo tiene `PROGRESO.md` en la raíz, escribe la entrada con su formato y en la ruta que indica, con el número del PR; commit con el mensaje de bitácora de `git.md` y push a la misma rama. Si no existe, no hay bitácora.
6. **CODEOWNERS.** `gh pr view <n> --json files,reviewRequests`. Si un archivo del PR (o el nombre anterior de uno renombrado) coincide con un patrón de `codeowners_paths`, el PR queda retenido hasta que lo lea una persona: di qué archivos y a quién, según `reviewRequests` o el archivo CODEOWNERS del repo (`.github/`, raíz o `docs/`), y no actives el auto-merge. GitHub no le pide al autor la revisión de sus propias rutas: si el PR sale con el token del único dueño, en auto-merge entraría sin que nadie lo lea.
7. **Merge** según `git.merge`. Si corres desde `goal.sh` (te lo dice el prompt de sistema), no lo actives: lo decide el bucle. Si no, con `auto` (o sin la clave), sin archivos retenidos en el paso 6 y sin que el PR nazca bloqueado, `gh pr merge <n> --auto --squash --match-head-commit <sha de la cabeza>`; si el repo no permite auto-merge, dilo. Con `manual`, no lo actives. Nunca mergees a mano.

## Cierre

Responde en 5 líneas:
1. PR: URL y título.
2. Tamaño y ADR.
3. Revisor y evaluador: veredictos; `passes` y su evidencia, si cambió.
4. Merge: auto-merge activo, lo decide `goal.sh`, manual (espera la aprobación y el merge de una persona), bloqueado (motivo) o retenido por CODEOWNERS (archivos y a quién).
5. Bitácora: ruta de la entrada, o "sin bitácora".
