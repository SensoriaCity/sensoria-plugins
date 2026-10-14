---
name: build
description: Construye UNA funcionalidad de la carpeta features de .city.json en su propia rama, con una compuerta de corte antes de escribir código, prueba primero, verificación con los comandos del repo, tamaño, regla de ADR, veredicto del subagente revisor y del subagente evaluador sobre una instalación limpia. passes solo cambia con scripts/passes.sh y la evidencia del evaluador. Úsala en una sesión nueva por funcionalidad.
argument-hint: "<id de funcionalidad> [ruta del plan del día]"
disable-model-invocation: true
---

# /city:build

Entrada: $ARGUMENTS

Construyes una sola funcionalidad y dejas la rama lista para `/city:ship`. No te calificas: el veredicto es del `revisor` y del `evaluador`. `passes` solo cambia con `scripts/passes.sh`, después de guardar la evidencia del evaluador.

## Configuración

Lee `.city.json` en la raíz del repo (`git rev-parse --show-toplevel`). Si no existe, detente y dilo: el kit no sabe nada del stack y no adivina comandos. De ahí salen los comandos (`tests`, `qa`), las rutas (`features`, `evidencia_dir`, `adr_dir`), el prefijo de rama (`ramas`), el `label`, los `codeowners_paths`, el tope (`tope_lineas`) y las convenciones de commits y merge (`git`, en `${CLAUDE_PLUGIN_ROOT}/skills/ship/git.md`). Su contrato está en `${CLAUDE_PLUGIN_ROOT}/city.schema.json`. Para lo propio de la máquina (puertos, versiones, servidores locales, cómo bajar una instalación), ver `docs/harness/entorno.md` del repo si existe; no lo supongas.

## Reglas duras

- Nunca cambias `passes` a mano ni editas la evidencia del evaluador: la guardas tal cual y `passes` cambia solo con `scripts/passes.sh`.
- Nunca borras, renombras ni editas el texto del archivo de una funcionalidad en `features`, tampoco para que pase.
- Nunca lees, imprimes ni tocas `.env`.
- Nunca desactivas, saltas ni borras una prueba, ni bajas un umbral para que pase.
- Una funcionalidad por sesión. La siguiente va en una sesión nueva.
- Nunca `git push --force`.
- Las reglas duras del `CLAUDE.md` del repo mandan sobre esta skill.
- Una decisión que ni la funcionalidad ni el plan prevén: si es reversible y no toca una regla dura, un ADR ni archivos fuera del alcance del plan, tómala y anótala para el PR bajo "Decisiones del ejecutor" (qué y por qué). Si no, detente y dila.
- Evidencia, no afirmaciones: pega el final de la salida de cada comando.
- Si una corrección falla dos veces seguidas, para y pide contexto.

## Pasos

1. **Orientación.**
   - `git status` limpio, `git fetch origin` y `git log --oneline -15 origin/main`. En un worktree, `main` local puede estar atrás: manda `origin/main`.
   - `gh pr list --state open`: si un PR abierto ya trae este id en la rama o el título, sigue en esa rama si es tuya (sesión interrumpida: `git log --oneline origin/main..HEAD` y `git diff origin/main...HEAD`, y continúa desde lo que falta); si es de otra persona, detente.
   - Plan del día, si lo pasaron: léelo. Manda sobre esta skill en alcance, archivos que toca y lo que no se decide solo. Si nombra una dependencia nueva, detente en ese paso: la instala la persona.
   - La funcionalidad, solo ella: `jq . <features>/<id>.json` (`features` es una carpeta con un archivo por funcionalidad). Si no existe, ya tiene `passes: true` o trae `reemplazada_por`, detente y dilo (en el último caso, con los ids que la reemplazan).
   - Su spec, si la funcionalidad trae `spec`: lee la sección `### <id>`. Como un plan, manda en alcance ("Toca"), en lo que no se decide solo y en las dependencias. Si plan y spec se contradicen, manda el plan; anótalo en "Decisiones del ejecutor".

2. **Compuerta de corte,** antes de crear la rama y sin escribir código. Un corte es un vertical slice que cabe en `tope_lineas` y que el evaluador prueba solo (`${CLAUDE_PLUGIN_ROOT}/skills/spec/cortes.md`). Detente si:
   - la funcionalidad trae más de 5 pasos (menos de 2 no bloquea);
   - un paso necesita código que no está en `origin/main` ni entra en este corte;
   - ningún paso lo puede observar una persona, la API o el CLI: es un corte por capa. La excepción es el corte de contrato de la regla 5 de `cortes.md`, cuyos pasos pueden ser solo "con su prueba en <grupo o suite>";
   - la estimación pasa el 75 % de `tope_lineas`. Usa la de la spec o la del plan; si no hay, estima leyendo los archivos que vas a tocar y las pruebas vecinas.
   Al detenerte, escribe la partición en funcionalidades según `cortes.md` y termina con la línea `Bloqueo: no es un corte. <motivo>`. No edites `features`: la partición entra con `/city:spec partir <id>`.
   Si retomas tu rama (paso 1), no repitas la compuerta: manda `tamano.sh` del paso 8. Si el plan del día parte la funcionalidad en entregas (así los escribía el plan diario del repo hasta el 2026-10-10), la compuerta mide solo la estimación de la entrega que te toca: no cuenta pasos, observabilidad ni dependencias.

3. **Rama** `<ramas>AAAA-MM-DD-<id>` con la fecha de hoy, desde `origin/main`: `git switch -c <rama> origin/main`.

4. **Prueba primero.** Por cada paso de la funcionalidad, escribe la prueba que lo demuestra, junto al código e imitando las vecinas, con nombres en el idioma que pide el `CLAUDE.md` del repo. Córrela y confirma que falla por la razón correcta. Si un paso solo se comprueba como usuario, anótalo para el evaluador.

5. **Implementa lo mínimo** que hace pasar las pruebas. Busca el análogo en el repo antes de inventar estructura. Nada de stubs, `TODO` ni código para después; nada fuera de la funcionalidad: lo que veas va al final del reporte.

6. **Verifica** desde la raíz, uno por uno y literal, cada comando de `tests.unit`, `tests.lint`, `tests.estatico` y `tests.audit`, y los de `tests.navegador` si la funcionalidad tiene UI. Si un comando no existe en el repo (binario, script o paquete ausente), dilo en el reporte y sigue con los demás; no lo reemplaces por otro. Si el repo genera contratos o tipos de lo que cambiaste, regenéralos.

7. **Commits** según `git.commits` de `${CLAUDE_PLUGIN_ROOT}/skills/ship/git.md` (sin la clave, Conventional Commits en español: `feat(<ámbito>): …`), los que hagan falta en la rama.

8. **Tamaño:** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/tamano.sh"`. Si sale con 1 (pasa `tope_lineas`), detente como en la compuerta: la partición y `Bloqueo: no es un corte. Pasa tope_lineas`.

9. **ADR, por regla y no por criterio.** Hace falta si el diff toca `adr_dir` o un contrato compartido: un archivo de `codeowners_paths`, o una interfaz, esquema o API que otro módulo o app usa (búscalo con grep), o lo que el `CLAUDE.md` del repo exige con ADR. Está cubierto si el ADR viene en el diff o ya está en `origin/main` (`git cat-file -e origin/main:<ruta>`). Si falta, detente: un ADR imprevisto parte el corte. Propón un primer corte con solo el contrato, el ADR y sus pruebas.

10. **Revisor.** Delega al subagente `city:revisor` con una sola línea, sin tu resumen:
   `<id> · <rama> · origin/main`
   No edites mientras corre. Corrige los hallazgos `bloquea`, haz commit y pide otra vuelta: máximo 2. Los `debería` y `sugerencia` no bloquean; guárdalos para el PR. Si tras 2 vueltas sigue en `Veredicto: no mergear`, no insistas: el PR nace bloqueado y lo decide una persona.
   Si el diff toca autenticación, permisos, archivos, integraciones o el CLI, delega también al subagente `city:seguridad` con la misma línea y, debajo, uno por línea, los archivos de `git diff --name-only origin/main...HEAD` que tocan esa superficie. Mismas reglas y vueltas.

11. **Evaluador,** siempre: su evidencia es el único camino a `passes`.
    - Antes, ver `docs/harness/entorno.md` del repo. Si hay una instalación que no creó esta sesión, no la bajes ni borres datos: di qué encontraste y espera el sí de la persona.
    - Instalación limpia: corre `qa.instalar` y luego `qa.smoke`, literales y con timeout amplio. Si falla algo de la máquina (Docker apagado, puerto ocupado), dilo y detente; si falla por el código, arréglalo antes de seguir.
    - Usuario de prueba, si `.city.json` trae `qa.usuario`: en un solo comando de Bash, sin escribir nada a disco, genera correo `qa+<fecha y hora>@city.localhost`, nombre `QA` y contraseña aleatoria de 20 caracteres, y crea el usuario pasando por la entrada estándar una línea por elemento de `qa.usuario_stdin`, en su orden:
      `c="qa+$(date +%Y%m%d%H%M%S)@city.localhost"; p="$(openssl rand -base64 15)"; printf '%s\n' <"$c" por correo, QA por nombre, "$p" por contraseña> | <qa.usuario> && printf '%s %s\n' "$c" "$p"`
      Si falla, dilo y detente. La contraseña no va a ningún archivo, commit, PR ni evidencia: vive solo en esta instalación desechable.
    - Si el clon no trae `.city.json` en su raíz, copia el del worktree a `<clon>/.city.json` antes de delegar: el evaluador lo lee de ahí.
    - Delega al subagente `city:evaluador` con una sola línea, con `<url>` igual a `qa.url` con el puerto de la instalación (`qa.puerto` si lo trae) y `<clon>` la ruta absoluta del clon donde corrió `qa.instalar`:
      `<id> · url: <url> · usuario: <correo> · contraseña: <contraseña> · repo: <clon> · instalacion: desechable`
      Sin `qa.usuario`, quita usuario y contraseña. `· instalacion: desechable` va solo si esta sesión creó la instalación en ese clon y la va a bajar con `down -v`; si no, quítala y el evaluador no ejecuta pasos destructivos.
    - Si responde `BLOQUEADO: …`, no pudo empezar (URL, usuario, entorno): no guardes nada, dilo y detente. Un paso bloqueado llega como `VEREDICTO: no pasa` con el motivo en la tabla.
    - Si no, guarda su respuesta tal cual, sin agregar ni quitar una línea, en `<evidencia_dir>/<id>.md` (crea la carpeta si falta).
    - Si su última línea es `VEREDICTO: pasa`, corre `bash "${CLAUDE_PLUGIN_ROOT}/scripts/passes.sh" <id>`. Si sale con 1, detente y pega su mensaje. Comitea la evidencia y el cambio de `features` juntos, con el mensaje de evidencia de `git.md`; con `no pasa`, comitea solo la evidencia.
    - Si no pasa, corrige, haz commit y pide otra pasada: máximo 2. Si las correcciones cambian más que unas líneas, pide también otra vuelta al revisor.
    - Al terminar, baja la instalación de esta sesión como dice `docs/harness/entorno.md` del repo.

12. **Reporte** en 7 líneas:
    1. Funcionalidad: `<id>` · rama `<rama>`.
    2. Archivos tocados.
    3. Pruebas: comandos en verde, en rojo o ausentes del repo.
    4. Tamaño: `<n>` de `<tope_lineas>`.
    5. ADR: no aplica, cubierto (`<ruta>`) o falta.
    6. Revisor, seguridad y evaluador: veredicto, vueltas y pendientes `debería`.
    7. Siguiente paso: `/city:ship` en esta sesión.
