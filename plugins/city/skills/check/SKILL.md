---
name: check
description: Reporte de cierre de solo lectura para quien libera, armado con gh y git. Trae los PR mergeados con su versión, funcionalidades tocadas con passes y evidencia, PR retenidos por CODEOWNERS, PR con revisor o evidencia en rojo, ADR pendientes, smoke de la instalación y qué clickear en la app. Para una funcionalidad, el día o la semana.
argument-hint: "<id> | hoy | semana"
disable-model-invocation: true
---

# /city:check

Entrada: $ARGUMENTS (vacío equivale a `hoy`).

Armas el reporte de 10 minutos para quien libera. **Solo lectura:** no editas archivos, no haces commit ni push, no comentas PR, no cambias labels, revisores ni flags, no instalas ni bajas nada. Lo único que actualizas son referencias remotas con `git fetch` y, solo si la persona lo pide después de leer el reporte, las tareas y los hitos de Notion que el reporte lista como desalineados.

## Configuración

Lee `.city.json` en la raíz del repo (`git rev-parse --show-toplevel`). Si no existe, detente y dilo: el kit no sabe nada del stack y no adivina comandos. De ahí salen los comandos (`tests`, `qa`), las rutas (`apps_dir`, `adr_dir`; dónde viven un corte y su evidencia lo dice `bash "${CLAUDE_PLUGIN_ROOT}/scripts/slice.sh" <id>`), el prefijo de rama (`branches`), el `label`, las rutas con dueño (`codeowners_paths` y el archivo de dueños del repo, con `scripts/owners.sh`) y el tope (`line_limit`). Su contrato está en `${CLAUDE_PLUGIN_ROOT}/city.schema.json`. Si falta una clave, vale su nombre de city 2.x, que el contrato lista como obsoleta (`branches`, antes `ramas`). Para lo propio de la máquina (puertos, versiones, servidores locales, cómo bajar una instalación), ver `docs/harness/entorno.md` del repo si existe; no lo supongas.

## Rango

- `hoy`: desde las 00:00 de hoy, hora local. `semana`: desde el lunes de esta semana.
- `<id>`: sin límite de fecha; solo los PR cuya rama (`headRefName`) contiene el id, o cuyo título lo nombra.
- `git fetch origin --tags` antes de leer. Repo: `gh repo view --json nameWithOwner,url`.

## Qué juntar

1. **Mergeados** en el rango: `gh pr list --state merged --search "merged:>=<AAAA-MM-DD>" --limit 100 --json number,title,mergedAt,mergeCommit,headRefName,url`. Versión según `git.version` de `${CLAUDE_PLUGIN_ROOT}/skills/ship/git.md`: con `tag` (o sin la clave), `git tag --points-at <mergeCommit.oid>`; con `subject` (`asunto` en un `.city.json` 2.x), `git log -1 --format=%s <mergeCommit.oid>`. Sin versión, "sin versión".
2. **Funcionalidades tocadas:** los ids de las ramas `<branches>AAAA-MM-DD-<id>` (sin el sufijo `-fix` de una corrección) y de los archivos de corte (`slices/<id>.json`, o `features` en city 2.x) en `git show --name-only --format= <oid>` de cada merge. Por cada id, `slice.sh <id> --ref origin/main` da su `file` y su `evidence`. Estado actual: `git show origin/main:<file> | jq '{passes, replaced_by, blocked_by, class, ships_with}'`. Evidencia: si `git cat-file -e origin/main:<evidence>`, su URL en GitHub (`<url>/blob/main/<evidence>`) y su línea `VEREDICTO:`. `passes: true` sin evidencia es un hallazgo. Con `passes: true`, `bash "${CLAUDE_PLUGIN_ROOT}/scripts/passes.sh" <id> --check --ref origin/main` dice si esa evidencia vale: sobre `main` vale la que entró con el merge del corte (también por squash), y que cortes posteriores, con su propia evidencia, hayan tocado los mismos archivos no la vence. Si sale con 1, es un hallazgo con su motivo: la evidencia no dice `pasa`, o trae la marca `VENCIDA:` de un `--reset` y nadie la renovó. Un corte con `replaced_by` va como "reemplazado", no como pendiente. **Orden de despliegue:** si un corte tocado, ya en `main`, trae `ships_with`, mira el `passes` en `origin/main` de cada id que nombra; por cada uno que no esté en `true` va una línea en "No desplegar": `<id> no sale sin <id pendiente>: no desplegar hasta que entre <id pendiente>`, con su PR abierto si lo hay.
3. **Retenidos por CODEOWNERS:** `gh pr list --state open --label <label> --json number,title,url,files,reviewDecision,reviewRequests`. Retenido es un PR con un archivo con dueño y `reviewDecision` distinta de `APPROVED`. Ruta con dueño es la unión de `codeowners_paths` (rutas compartidas, que además piden ADR) y del archivo de dueños del repo (quién debe aprobar): pasa los archivos de cada PR a `bash "${CLAUDE_PLUGIN_ROOT}/scripts/owners.sh" --ref origin/main --match` (con `--match shared` u `owned` dice cuál de los dos lados coincide). Son los únicos diffs que lee la persona: lista número, a quién espera y los archivos que lo retienen. Además, `owners.sh --ref origin/main --check`: si sale con 1, `.city.json` y el archivo de dueños divergen; lista sus líneas `only_config=` (está en `codeowners_paths` y no en el archivo: GitHub no le pide revisión a nadie) y `only_file=` (está en el archivo y no en `.city.json`: retiene el merge pero no cuenta como ruta compartida, así que no pide ADR; si debería pedirlo, falta en `codeowners_paths`).
4. **En rojo:** PR abiertos (`gh pr checks <n>`) con el check `revisor` o `evidencia` en `FAILURE`, o con `**Bloqueado:**` en el cuerpo. Un PR cuyo cuerpo empieza por `**Pendiente:** decisión de <persona>` no está en rojo aunque el check `revisor` falle: espera a esa persona y va en "Esperan una decisión", con quién y qué. El check `evaluador` es opcional: si existe y falla, cuenta; si el repo no lo tiene, no es hallazgo. Un PR sin `revisor` o sin `evidencia` sí lo es: dilo.
5. **ADR:** lo piden `adr_dir`, las rutas de `codeowners_paths` y los contratos compartidos, no cualquier archivo con dueño. Nuevos en el rango con `git log origin/main --since=<desde> --diff-filter=A --name-only -- <adr_dir>`, y pendientes: PR abiertos que tocan `adr_dir` o cuyo cuerpo dice "necesita ADR" o "ADR: falta".
6. **Smoke:** si hay una instalación viva (cómo se reconoce: ver `docs/harness/entorno.md` del repo; si no lo dice, `curl -s -o /dev/null -w '%{http_code}' <qa.url>`, con `<qa.url>` la salida de `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/qa.py" url`, que expande sus variables; para ver contenedores, `docker compose ps` desde la raíz, nunca `docker compose ls`, que queda fuera del allow), corre `qa.smoke` literal y toma su resultado. Si no hay instalación, "sin instalación"; no levantes una.
7. **Notion,** si `.city.json` trae `notion` y la sesión tiene el conector: compara cada corte tocado con su tarea según `${CLAUDE_PLUGIN_ROOT}/notion.md` (estado, PR, hito) y lista lo que no coincide, con el cambio exacto que lo arregla. Manda el repo. Sin conector, "sin conector".
8. **Qué clickear:** de 3 a 5 acciones tomadas de los pasos de las funcionalidades tocadas con UI, escritas como "en `<qa.url>` …, haz … y verás …". No inventes rutas ni datos: si el paso no los dice, cítalo como está.

## Salida

Llena `${CLAUDE_SKILL_DIR}/closing-template.md` y respóndelo en el chat; no lo escribas en disco. Máximo 40 líneas: si no cabe, resume los mergeados en una línea por día y deja completo lo que pide una persona ("No desplegar", retenidos, decisiones que esperan, en rojo y ADR). Una sección sin datos queda en una línea con "ninguno". Cada línea cabe en 100 columnas, tablas incluidas: acorta títulos y rutas, y si una acción de "Qué clickear" o un ADR pendiente no cabe, sigue en una segunda línea con sangría; nunca la cortes a media frase.
