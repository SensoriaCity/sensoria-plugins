---
name: check
description: Reporte de cierre de solo lectura para quien libera, desde gh y git: PR mergeados con su versión, funcionalidades tocadas con passes y evidencia, PR retenidos por CODEOWNERS, PR con revisor o evidencia en rojo, ADR pendientes, smoke de la instalación y qué clickear en la app. Para una funcionalidad, el día o la semana.
argument-hint: "<id> | hoy | semana"
disable-model-invocation: true
---

# /city:check

Entrada: $ARGUMENTS (vacío equivale a `hoy`).

Armas el reporte de 10 minutos para quien libera. **Solo lectura:** no editas archivos, no haces commit ni push, no comentas PR, no cambias labels, revisores ni flags, no instalas ni bajas nada. Lo único que actualizas son referencias remotas con `git fetch`.

## Configuración

Lee `.city.json` en la raíz del repo (`git rev-parse --show-toplevel`). Si no existe, detente y dilo: el kit no sabe nada del stack y no adivina comandos. De ahí salen los comandos (`tests`, `qa`), las rutas (`features`, `evidencia_dir`, `adr_dir`), el prefijo de rama (`ramas`), el `label`, los `codeowners_paths` y el tope (`tope_lineas`). Su contrato está en `${CLAUDE_PLUGIN_ROOT}/city.schema.json`. Para lo propio de la máquina (puertos, versiones, servidores locales, cómo bajar una instalación), ver `docs/harness/entorno.md` del repo si existe; no lo supongas.

## Rango

- `hoy`: desde las 00:00 de hoy, hora local. `semana`: desde el lunes de esta semana.
- `<id>`: sin límite de fecha; solo los PR cuya rama (`headRefName`) contiene el id, o cuyo título lo nombra.
- `git fetch origin --tags` antes de leer. Repo: `gh repo view --json nameWithOwner,url`.

## Qué juntar

1. **Mergeados** en el rango: `gh pr list --state merged --search "merged:>=<AAAA-MM-DD>" --limit 100 --json number,title,mergedAt,mergeCommit,headRefName,url`. Versión según `git.version` de `${CLAUDE_PLUGIN_ROOT}/skills/ship/git.md`: con `tag` (o sin la clave), `git tag --points-at <mergeCommit.oid>`; con `asunto`, `git log -1 --format=%s <mergeCommit.oid>`. Sin versión, "sin versión".
2. **Funcionalidades tocadas:** los ids de las ramas `<ramas>AAAA-MM-DD-<id>` y de `git show <oid> -- <features>` de cada merge. Estado actual: `git show origin/main:<features> | jq` para cada id. Evidencia: si `git cat-file -e origin/main:<evidencia_dir>/<id>.md`, su URL en GitHub (`<url>/blob/main/<evidencia_dir>/<id>.md`) y su línea `VEREDICTO:`. `passes: true` sin evidencia es un hallazgo.
3. **Retenidos por CODEOWNERS:** `gh pr list --state open --label <label> --json number,title,url,files,reviewDecision,reviewRequests`. Retenido es un PR con un archivo que coincide con `codeowners_paths` y `reviewDecision` distinta de `APPROVED`. Son los únicos diffs que lee la persona: lista número, a quién espera y los archivos que lo retienen.
4. **En rojo:** PR abiertos (`gh pr checks <n>`) con el check `revisor` o `evidencia` en `FAILURE`, o con `**Bloqueado:**` en el cuerpo. El check `evaluador` es opcional: si existe y falla, cuenta; si el repo no lo tiene, no es hallazgo. Un PR sin `revisor` o sin `evidencia` sí lo es: dilo.
5. **ADR:** nuevos en el rango con `git log origin/main --since=<desde> --diff-filter=A --name-only -- <adr_dir>`, y pendientes: PR abiertos que tocan `adr_dir` o cuyo cuerpo dice "necesita ADR" o "ADR: falta".
6. **Smoke:** si hay una instalación viva (cómo se reconoce: ver `docs/harness/entorno.md` del repo; si no lo dice, `curl -s -o /dev/null -w '%{http_code}' <qa.url>`; para ver contenedores, `docker compose ps` desde la raíz, nunca `docker compose ls`, que queda fuera del allow), corre `qa.smoke` literal y toma su resultado. Si no hay instalación, "sin instalación"; no levantes una.
7. **Qué clickear:** de 3 a 5 acciones tomadas de los pasos de las funcionalidades tocadas con UI, escritas como "en `<qa.url>` …, haz … y verás …". No inventes rutas ni datos: si el paso no los dice, cítalo como está.

## Salida

Llena `${CLAUDE_SKILL_DIR}/plantilla-cierre.md` y respóndelo en el chat; no lo escribas en disco. Máximo 40 líneas: si no cabe, resume los mergeados en una línea por día y deja completo lo que pide una persona (retenidos, en rojo y ADR). Una sección sin datos queda en una línea con "ninguno". Cada línea cabe en 100 columnas, tablas incluidas: acorta títulos y rutas, y si una acción de "Qué clickear" o un ADR pendiente no cabe, sigue en una segunda línea con sangría; nunca la cortes a media frase.
