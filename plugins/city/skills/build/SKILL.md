---
name: build
description: Construye UN corte (slices/<id>.json de su hito, o features de city 2.x) en su propia rama, con una compuerta de corte antes de escribir código, prueba primero, verificación con los comandos del repo, tamaño, regla de ADR, veredicto del subagente revisor y del subagente evaluador sobre una instalación limpia. Un corte de clase data se prueba contra el motor real en una base desechable. passes solo cambia con scripts/passes.sh y la evidencia del evaluador. Úsala en una sesión nueva por funcionalidad.
argument-hint: "<id de funcionalidad> [fix] [ruta del plan del día]"
disable-model-invocation: true
---

# /city:build

Entrada: $ARGUMENTS

Construyes una sola funcionalidad y dejas la rama lista para `/city:ship`. No te calificas: el veredicto es del `reviewer` y del `evaluator`. `passes` solo cambia con `scripts/passes.sh`, que corre el evaluador después de escribir su evidencia.

## Configuración

Lee `.city.json` en la raíz del repo (`git rev-parse --show-toplevel`). Si no existe, detente y dilo: el kit no sabe nada del stack y no adivina comandos. De ahí salen los comandos (`tests`, `qa`), las rutas (`apps_dir`, `adr_dir`; dónde viven el corte, su spec y su evidencia lo dice `bash "${CLAUDE_PLUGIN_ROOT}/scripts/slice.sh" <id>`), el prefijo de rama (`branches`), el `label`, las rutas con dueño (`codeowners_paths` y el archivo de dueños del repo, con `scripts/owners.sh`), el tope (`line_limit`) y las convenciones de commits y merge (`git`, en `${CLAUDE_PLUGIN_ROOT}/skills/ship/git.md`). Su contrato está en `${CLAUDE_PLUGIN_ROOT}/city.schema.json`. Si falta una clave, vale su nombre de city 2.x, que el contrato lista como obsoleta (`branches`, antes `ramas`). Para lo propio de la máquina (puertos, versiones, servidores locales, cómo bajar una instalación), ver `docs/harness/entorno.md` del repo si existe; no lo supongas.

## Reglas duras

- Nunca cambias `passes` a mano ni editas la evidencia del evaluador: la escribe él en la `evidence` que da `slice.sh`, y `passes` cambia solo con `scripts/passes.sh`.
- Tu propia evidencia (qué corriste y el final de cada salida) va en el cuerpo del PR, no en un archivo: en `evidence/` del hito vive solo `<id>.md`, del evaluador.
- Nunca borras, renombras ni editas el texto del archivo de un corte, tampoco para que pase.
- Un corte de clase `slice` no trae migraciones: si necesitas una, detente (`Bloqueo: falta un corte de clase data`). Uno de clase `data` no trae código de la app que use lo que crea, y sigue `${CLAUDE_SKILL_DIR}/data-slices.md`: su prueba corre contra el motor real en una base desechable, nunca contra la de desarrollo.
- Nunca lees, imprimes ni tocas `.env`. El motor y la base activa se le preguntan a la app con el comando del repo que los imprime (`docs/harness/entorno.md`).
- Nunca desactivas, saltas ni borras una prueba, ni bajas un umbral para que pase.
- Una funcionalidad por sesión. La siguiente va en una sesión nueva.
- Nunca `git push --force`.
- Las reglas duras del `CLAUDE.md` del repo mandan sobre esta skill.
- Una decisión que ni la funcionalidad ni el plan prevén: si es reversible y no toca una regla dura, un ADR ni archivos fuera del alcance del plan, tómala y anótala para el PR bajo "Decisiones del ejecutor" (qué y por qué). Si no, detente y dila.
- Un archivo que los pasos del corte necesitan y que "Toca" no nombra se puede tocar si no es una migración, no tiene dueño y no es el comportamiento de otro corte: anótalo con su porqué para "Decisiones del ejecutor". Lo juzga el revisor. Si no cumple eso, detente.
- Evidencia, no afirmaciones: pega el final de la salida de cada comando.
- Si una corrección falla dos veces seguidas, para y pide contexto.

## Pasos

1. **Orientación.**
   - `git status` limpio, `git fetch origin` y `git log --oneline -15 origin/main`. En un worktree, `main` local puede estar atrás: manda `origin/main`.
   - `gh pr list --state open`: si un PR abierto ya trae este id en la rama o el título, sigue en esa rama si es tuya (sesión interrumpida: `git log --oneline origin/main..HEAD` y `git diff origin/main...HEAD`, y continúa desde lo que falta); si es de otra persona, detente.
   - Plan del día, si lo pasaron: léelo. Manda sobre esta skill en alcance, archivos que toca y lo que no se decide solo. Si nombra una dependencia nueva, detente en ese paso: la instala la persona.
   - El corte, solo él: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/slice.sh" <id>` da su `file`, su `spec` y dónde va su `evidence`; `jq . <file>`. Si no existe, ya tiene `passes: true`, trae `replaced_by` o `blocked_by`, detente y dilo (un `blocked_by` se quita con `/city:spec unblock <id>`, no aquí). Con `passes: true` sigues solo si la entrada trae `fix`: corriges un corte ya mezclado (`${CLAUDE_PLUGIN_ROOT}/skills/spec/slices.md`, "Corregir un corte ya mezclado"). No hay compuerta de corte; la rama es `<branches>AAAA-MM-DD-<id>-fix`; la prueba primero es la que falla por el defecto; y el paso 11 no se salta nunca: el evaluador vuelve a probar todos los pasos sobre la cabeza y reemplaza la evidencia en este mismo PR. Cada paso es `{do, expect}`; `class` (`slice`, `data` o `platform`) y `rung` dicen qué puede traer y cómo se esconde; `rung` puede faltar en `data` y `platform`. Con `rung` 4, lee la receta de `flags` de `.city.json` antes de escribir código: el flag se declara, se consulta y se prueba como dice ahí, no como se te ocurra.
   - **Sus `depends_on` ya están en `origin/main`:** por cada uno, `slice.sh <dep> --ref origin/main` da su `file`, y `git show origin/main:<file> | jq .passes` da `true`. Si alguno no, detente: `Bloqueo: <id> depende de <dep>, que aún no está en main` (con `git.merge: manual`, se espera el merge de la persona). No montes la rama sobre la de otro corte. La excepción es el apilado, solo si una persona lo pidió (en la entrada o en el plan del día): sigue "Un corte se construye sobre la rama principal" de `${CLAUDE_PLUGIN_ROOT}/skills/spec/slices.md`. Ahí la rama sale de la del corte base, cada script y cada `git diff` de esta skill recibe esa base en vez de `origin/main` (`size.sh origin/<rama base>`, `passes.sh <id> --base origin/<rama base>`), y el evaluador (paso 11) no corre hasta que la base esté mezclada y la rama haya tomado `origin/main`: mientras, `/city:ship draft`.
   - Su spec: lee la sección `### <id>` y, si existe, "Valores y unidades". Como un plan, manda en alcance ("Toca"), en lo que no se decide solo y en las dependencias. Si plan y spec se contradicen, manda el plan; anótalo en "Decisiones del ejecutor".

2. **Compuerta de corte,** antes de crear la rama y sin escribir código. Un corte es un vertical slice que cabe en `line_limit` y que el evaluador prueba solo (`${CLAUDE_PLUGIN_ROOT}/skills/spec/slices.md`). Detente si:
   - la funcionalidad trae más de 5 pasos (menos de 2 no bloquea);
   - un paso necesita código que no está en `origin/main` ni entra en este corte;
   - ningún paso lo puede observar una persona, la API o el CLI: es un corte por capa. La excepción es el corte de contrato de la regla 5 de `slices.md`, cuyos pasos pueden ser solo "con su prueba en <grupo o suite>";
   - la estimación pasa el 75 % de `line_limit` (o el `line_limit` entero, si el corte trae `estimate_basis: measured`). Usa la de la spec o la del plan; si no hay, estima leyendo los archivos que vas a tocar y las pruebas vecinas.
   Al detenerte, escribe la partición en funcionalidades según `slices.md` y termina con la línea `Bloqueo: no es un corte. <motivo>`. No edites el archivo del corte: la partición entra con `/city:spec split <id>`.
   Si retomas tu rama (paso 1), no repitas la compuerta: manda `size.sh` del paso 8. Si el plan del día parte la funcionalidad en entregas (así los escribía el plan diario del repo hasta el 2026-10-10), la compuerta mide solo la estimación de la entrega que te toca: no cuenta pasos, observabilidad ni dependencias.

3. **Rama** `<branches>AAAA-MM-DD-<id>` con la fecha de hoy, desde `origin/main`: `git switch -c <rama> --no-track origin/main` (sin `--no-track`, un `git push` sin argumentos iría a `main`). Recién ahora, con la compuerta pasada, Notion: la tarea del corte pasa a "En progreso" según `${CLAUDE_PLUGIN_ROOT}/notion.md`; sin conector, `Notion pendiente: …` al final del reporte.

4. **Prueba primero.** Por cada paso de la funcionalidad, escribe la prueba que lo demuestra, junto al código e imitando las vecinas, con nombres en el idioma que pide el `CLAUDE.md` del repo. Córrela y confirma que falla por la razón correcta. Una prueba de regresión de algo que el código ya cumple pasa desde el principio: romperla a propósito te toca a ti, no al evaluador. En tu rama y sin hacer commit de lo roto, rompe el comportamiento, corre la prueba, guarda el final de su salida fallando, restáuralo (`git diff` vacío sobre ese archivo) y anótala para "Pasos y evidencia" del PR con qué rompiste y esa salida. Nunca en una copia del repo con enlaces a las carpetas de dependencias, ni tocando esas carpetas. Si un paso solo se comprueba como usuario, anótalo para el evaluador. Con escalón 4, un paso prueba que con el flag apagado todo sigue como antes. En un corte de clase `data`, la prueba de la migración corre contra el motor real desde este paso, con `tests.database` (`${CLAUDE_SKILL_DIR}/data-slices.md`): no se deja para la instalación del evaluador, y no vale una prueba que pasa donde la migración no hace nada.

5. **Implementa lo mínimo** que hace pasar las pruebas. Busca el análogo en el repo antes de inventar estructura. Nada de stubs, `TODO` ni código para después; nada fuera de la funcionalidad: lo que veas va al final del reporte.

6. **Verifica** desde la raíz, uno por uno y literal, cada comando de `tests.unit`, `tests.lint`, `tests.static` y `tests.audit`, los de `tests.browser` si la funcionalidad tiene UI y `tests.database` si el corte es de clase `data` (sin la clave, el reporte lo dice como manda `data-slices.md`). Si un comando no existe en el repo (binario, script o paquete ausente), dilo en el reporte y sigue con los demás; no lo reemplaces por otro. Si el repo genera contratos o tipos de lo que cambiaste, regenéralos.

7. **Commits** según `git.commits` de `${CLAUDE_PLUGIN_ROOT}/skills/ship/git.md` (sin la clave, Conventional Commits en español: `feat(<ámbito>): …`), los que hagan falta en la rama.

8. **Tamaño:** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/size.sh"` (en un corte apilado, con su base como argumento: sin ella cuenta también el corte de abajo). Si sale con 1 (pasa `line_limit`), detente como en la compuerta: la partición y `Bloqueo: no es un corte. Pasa line_limit`.

9. **ADR, por regla y no por criterio.** Hace falta si el diff toca `adr_dir` o un contrato compartido: una ruta compartida, de `codeowners_paths` (las que imprime `git diff --name-only origin/main...HEAD | bash "${CLAUDE_PLUGIN_ROOT}/scripts/owners.sh" --ref origin/main --match shared`), o una interfaz, esquema o API que otro módulo o app usa (búscalo con grep), o lo que el `CLAUDE.md` del repo exige con ADR. Un archivo que solo aparece en el archivo de dueños del repo (`--match owned`: un equipo o un panel que debe aprobar) no pide ADR: retiene el merge, y lo dice `/city:ship`. Está cubierto si el ADR viene en el diff o ya está en `origin/main` (`git cat-file -e origin/main:<ruta>`). Un cambio aditivo de esquema (tabla, columna o valor nuevos) que ningún otro módulo o app lee todavía no pide ADR: lo pide el corte que lo vuelva contrato. Si falta, detente: un ADR imprevisto parte el corte. Propón un primer corte con solo el contrato, el ADR y sus pruebas.

10. **Revisor.** Si en tu equipo revisa o evalúa otra sesión (lo dice la persona o el plan del día), sáltate de los pasos 10 y 11 lo que no te toca, dilo en el reporte y sigue con `/city:ship draft`. Si no, delega al subagente `city:reviewer` con una sola línea, sin tu resumen:
   `<id> · <rama> · origin/main`
   No edites mientras corre. Corrige los hallazgos `bloquea`, haz commit y pide otra vuelta: máximo 2. Los `debería` y `sugerencia` no bloquean; guárdalos para el PR. Si tras 2 vueltas sigue en `Veredicto: no mergear`, no insistas: el PR nace bloqueado y lo decide una persona. Un hallazgo `decide` (`Veredicto: espera decisión`) no lo corriges ni lo decides tú y no gasta vueltas: guárdalo para el PR, con la persona que nombra.
   Si el diff toca autenticación o sesión, permisos, subida, descarga o rutas de archivos, integraciones o el CLI, delega también al subagente `city:security` con la misma línea y, debajo, uno por línea, los archivos de `git diff --name-only origin/main...HEAD` que tocan esa superficie. Mismas reglas y vueltas. Si no toca nada de eso, `city:security` se salta y el reporte dice `no aplica` con esa razón.

11. **Evaluador,** siempre: su evidencia es el único camino a `passes`.
    - Antes, ver `docs/harness/entorno.md` del repo. Si hay una instalación que no creó esta sesión, no la bajes ni borres datos: di qué encontraste y espera el sí de la persona. Con `CITY_SLOT` en el entorno (lo exporta `goal.sh`), la tuya es la de ese slot: las de otros slots son de otros bucles; no las tocas ni te detienen.
    - Instalación limpia: corre `qa.install` y luego `qa.smoke`, literales y con timeout amplio; la shell expande las variables que nombren, como `${CITY_HTTP_PORT:-<puerto>}`. Si falla algo de la máquina (Docker apagado, puerto ocupado), dilo y detente; si falla por el código, arréglalo antes de seguir.
    - Usuario de prueba, si `.city.json` trae `qa.user`: en un solo comando de Bash, sin escribir nada a disco, genera correo `qa+<fecha y hora>@city.localhost`, nombre `QA` y contraseña aleatoria de 20 caracteres, y crea el usuario pasando por la entrada estándar una línea por elemento de `qa.user_stdin`, en su orden (`email`, `name` o `password`; en un `.city.json` 2.x, `correo`, `nombre` o `contraseña`):
      `c="qa+$(date +%Y%m%d%H%M%S)@city.localhost"; p="$(openssl rand -base64 15)"; printf '%s\n' <"$c" por email, QA por name, "$p" por password> | <qa.user> && printf '%s %s\n' "$c" "$p"`
      Si falla, dilo y detente. La contraseña no va a ningún archivo, commit, PR ni evidencia: vive solo en esta instalación desechable.
    - Si el clon no trae `.city.json` en su raíz, copia el del worktree a `<clon>/.city.json` antes de delegar: el evaluador lo lee de ahí.
    - Delega al subagente `city:evaluator` con una sola línea, con `<url>` igual a la salida de `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/qa.py" url` desde el clon (`qa.url` con sus variables expandidas, sin slot a su valor por omisión, y el puerto de `qa.port` si la URL no trae uno; si sale con 1, dilo y detente) y `<clon>` la ruta absoluta del clon donde corrió `qa.install`:
      `<id> · url: <url> · usuario: <correo> · contraseña: <contraseña> · repo: <clon> · instalacion: desechable`
      Sin `qa.user`, quita usuario y contraseña. `· instalacion: desechable` va solo si esta sesión creó la instalación en ese clon y la va a bajar con `down -v`; si no, quítala y el evaluador no ejecuta pasos destructivos. Opcionales, al final: `· capturas: <carpeta fuera del repo>` si una persona quiere las capturas en un lugar fijo, y `· commit: evidencia · push: evidencia` solo cuando evaluar es una sesión aparte que deja su commit en la rama del PR.
    - Si responde `BLOQUEADO: …`, no pudo empezar (URL, usuario, entorno) y no escribió nada: dilo y detente. Un paso bloqueado llega como `VEREDICTO: no pasa` con el motivo en la tabla.
    - Si no, el evaluador ya escribió su evidencia en la `evidence` que da `slice.sh`, dentro de `<clon>`, y con `VEREDICTO: pasa` corrió `passes.sh <id>`; su respuesta es esa misma evidencia. No le agregas ni le quitas una línea. Si `<clon>` no es tu worktree, copia el archivo tal cual a la misma ruta. Con `VEREDICTO: pasa`, confírmalo en tu worktree con `bash "${CLAUDE_PLUGIN_ROOT}/scripts/passes.sh" <id>` (sale con 0 si ya estaba en `true`); si sale con 1, detente y pega su mensaje.
    - El commit es tuyo: la evidencia y el cambio del archivo del corte juntos, con el mensaje de evidencia de `git.md`; con `no pasa`, solo la evidencia.
    - Si no pasa, corrige, haz commit y pide otra pasada: máximo 2. Si las correcciones cambian más que unas líneas, pide también otra vuelta al revisor.
    - Un commit de código después de un `VEREDICTO: pasa` vence esa evidencia: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/passes.sh" <id> --reset` devuelve `passes` a `false` y le agrega a la evidencia la línea `VENCIDA: …`, para que no siga diciendo que pasa. Comitea los dos archivos con el mensaje de evidencia vencida de `git.md` (no el de guardar evidencia); hace falta otra pasada del evaluador.
    - Al terminar, baja la instalación de esta sesión como dice `docs/harness/entorno.md` del repo.

12. **Reporte** en 7 líneas:
    1. Funcionalidad: `<id>` · rama `<rama>`.
    2. Archivos tocados.
    3. Pruebas: comandos en verde, en rojo o ausentes del repo.
    4. Tamaño: `<n>` de `<line_limit>`.
    5. ADR: no aplica, cubierto (`<ruta>`) o falta.
    6. Revisor, seguridad y evaluador: veredicto, vueltas y pendientes `debería`.
    7. Siguiente paso: `/city:ship` en esta sesión, o `/city:ship draft` si falta el veredicto de otra sesión. Para el PR: decisiones del ejecutor, archivos fuera de "Toca" y hallazgos `decide`.
