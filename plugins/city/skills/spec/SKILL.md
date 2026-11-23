---
name: spec
description: Escribe la spec de un hito (spec = hito) en <apps_dir>/<aplicativo>/<modulo>/<hito>/ y la parte en cortes verticales con clase (slice, data o platform) que caben en line_limit; cada corte queda como un archivo en slices/ del hito, con 2 a 5 pasos verificables, el escalón de la escalera que lo esconde y passes false. Marca el primer tramo. Con split <id>, reemplaza un corte que no pasa la compuerta; con unblock <id>, quita un blocked_by que una persona ya respondió; con revise <hito>, cambia los cortes con passes false de una spec ya mezclada según una decisión con nombre y fecha. Úsala antes de /city:build o /city:goal.
argument-hint: "<ruta o URL de la definición funcional del hito | objetivo en una frase | split <id> | unblock <id> | revise <hito>>"
disable-model-invocation: true
---

# /city:spec

Entrada: $ARGUMENTS

Conviertes un hito en una spec corta y en cortes que `/city:build` construye uno por sesión y `/city:goal` recorre en orden. No escribes código. Un hito tiene **una sola spec**: no hay epics, historias, PRD, arquitectura ni plan técnico aparte. Lo que hace buena a una spec son sus cortes: cada uno es un vertical slice que cabe en `line_limit`, que el evaluador prueba solo y que deja `main` desplegable.

## Configuración

Lee `.city.json` en la raíz del repo (`git rev-parse --show-toplevel`). Si no existe, detente y dilo. De ahí salen `apps_dir` (sin él, `docs/apps`), `adr_dir`, `line_limit`, `codeowners_paths`, `flags` (la receta de flags del repo) y `notion`. Su contrato está en `${CLAUDE_PLUGIN_ROOT}/city.schema.json`; si falta una clave, vale su nombre de city 2.x, que el contrato lista como obsoleta (`line_limit`, antes `tope_lineas`). Las reglas duras del `CLAUDE.md` del repo mandan sobre esta skill.

```
<apps_dir>/<aplicativo>/<modulo>/<hito>/
  spec.md              ← esta spec
  slices/<id>.json     ← un archivo por corte
  evidence/<id>.md     ← la escribe el evaluador; la comitea /city:build
```

- `<aplicativo>` es la carpeta del aplicativo dueño del módulo (su id de código). **No es `app` de `.city.json`**, que es el nombre del repo: un repo puede traer varios aplicativos.
- `<modulo>` es `mod-<NN>-<slug>` e `<hito>` es `h<NN>-<slug>`: el número con dos dígitos (`mod-28-resoluciones`, `h01-configuracion`) y el slug corto, en minúsculas y con guiones.
- El id de un corte es `m<NN>-h<NN>-s<NN>` (`m28-h01-s01`): lleva módulo e hito para que dos hitos no choquen, y `s01`, `s02`… van en orden de construcción.

Si la carpeta no existe la creas; no mueves carpetas existentes. Dónde vive un corte lo dice siempre `bash "${CLAUDE_PLUGIN_ROOT}/scripts/slice.sh" <id>` (claves `file`, `milestone`, `spec` y `evidence`), también para los de `features` de city 2.x.

## Reglas duras

- Antes de partir, lee `${CLAUDE_SKILL_DIR}/slices.md`: las reglas de un corte, su archivo, las clases, la escalera, las recetas y la calibración. Es la parte que más importa.
- Un corte es una funcionalidad y un PR. No hay entregas ni subtareas dentro de un id.
- Nunca renombras ni borras un corte que ya está en `origin/main`, y nunca tocas uno con `passes: true`. Solo creas archivos; las únicas ediciones son `replaced_by` de `split <id>`, `blocked_by` de `unblock <id>` y las de `revise <hito>` sobre cortes con `passes: false`.
- No escribes código, migraciones ni pruebas. Tampoco ADR: si hace falta uno, va en un corte de clase `platform` (paso 5).
- Lo que nombres (archivos, clases, métodos, pruebas, tablas, rutas) existe en el repo o lo crea un corte de esta spec. **Verifícalo leyendo el código**: no cites una línea que no abriste. La definición funcional puede estar desactualizada: confirma o corrige cada referencia.
- La spec no planea fechas de entrega. La única fecha que escribe es la de retiro del flag, y sale de la receta `flags` del repo o, si no la fija, de la regla del kit (paso 6).

## Partir un corte

Con `split <id>`, la entrada es un corte con `passes: false` que no pasa la compuerta de `/city:build` o que una persona decidió partir en la revisión. Lee sus pasos, su evidencia si existe y el código de `origin/main`. Los cortes nuevos van en la misma carpeta del hito, con los pasos 4 a 10 de siempre y los números `s<NN>` que siguen, y al original le agregas `"replaced_by": [<ids nuevos>]` sin cambiar nada más. Si otro corte dependía del original, `check-spec.sh` falla (nadie depende de un corte reemplazado): pasar ese `depends_on` al reemplazo es una edición de `revise <hito>`, con su decisión. Si la persona solo movió pasos (por ejemplo, uno que depende de un hotfix), el original se queda con los suyos y el nuevo lleva `depends_on` con lo que espera.

## Desbloquear un corte

Con `unblock <id>`, la persona dueña de una pregunta de `blocked_by` ya respondió. En una rama `docs/AAAA-MM-DD-unblock-<id>` desde `origin/main`, quita del archivo del corte **solo** la entrada respondida de `blocked_by` (y la clave entera si era la última): ni pasos, ni estimación, ni nada más. La respuesta va en el cuerpo del PR y, en `spec.md`, la línea de "Preguntas abiertas" pasa a "Supuestos" con quién respondió. Corre el paso 9 y sigue `/city:ship`: es un PR de clase `spec`. Si la respuesta cambia los pasos del corte, su naturaleza o a otros cortes, no es un desbloqueo: es `revise <hito>`.

## Revisar una spec ya mezclada

Con `revise <hito>`, una persona ya decidió algo que cambia la spec que está en `main`: una respuesta de producto cambia un corte o vuelve innecesario a otro, o una decisión técnica les suma algo a cortes construidos que aún no entran. Lee `${CLAUDE_SKILL_DIR}/revise.md` y síguelo: rama `docs/AAAA-MM-DD-revise-<hito>`; edita solo cortes con `passes: false` en `origin/main`, marca reemplazados con `replaced_by` (también hacia un corte anterior) y agrega cortes nuevos; cada corte editado o nuevo lleva `revision` con la fecha de la decisión, y `spec.md`, la sección "Decisiones tomadas" (fecha, quién, qué cambia y cortes; numerada o con viñetas). Un corte que nace de la decisión lleva `decision:<n>` en `covers`. Un corte ya construido se estima desde su diff, con `"estimate_basis": "measured"`: su máximo es el `line_limit` entero, y el PR dice de qué rama salió la medida. Solo ahí vale `measured`; en una spec nueva la estimación es `planned` y la clave no va. El PR, de clase `spec`, trae la tabla "antes → ahora" por corte.

## Pasos

1. **Orientación.** Si la entrada es la URL de un hito en Notion, lee solo su "Definición funcional" (el PO la redacta con `/city:discovery`); si sus criterios no traen id o le falta "Fuera de alcance", dilo en el reporte y sigue con lo que hay. `git fetch origin` y rama `docs/AAAA-MM-DD-spec-<hito>` con `git switch -c <rama> --no-track origin/main` (sin `--no-track`, un `git push` sin argumentos iría a `main`). Lee los ADR de `adr_dir` que tocan el tema, la spec de los hitos anteriores del módulo y el código donde va a caer (grep).

2. **Preguntas.** Lo que la definición deja abierto lo resuelves leyendo el código. Lo que el código no responde va a "Supuestos" con la lectura más razonable, o a "Preguntas abiertas" con el corte que bloquea. Un insumo o una decisión que falta (un archivo, una tabla oficial, una regla que solo sabe el PO) bloquea solo su corte: lo marcas con `blocked_by`, una lista de `{"question": "<qué falta, en una frase>", "owner": "<quién responde>", "blocks_since": "<AAAA-MM-DD de hoy>"}`, y los demás siguen. `/city:build` y `/city:goal` no construyen un corte con `blocked_by`; se quita con `unblock <id>`.

3. **Spec** en `<hito>/spec.md`, con `${CLAUDE_SKILL_DIR}/spec-template.md`. Cabe en unas 150 líneas más 5 por corte (`check-spec.sh` avisa si se pasa). Si el hito pasa de 8 cortes, la spec se ordena en **partes** (A, B…), cada una con su escalón; no se escriben dos specs para un hito.

4. **Cortes,** con `${CLAUDE_SKILL_DIR}/slices.md`. Cada corte lleva en la spec: clase, comportamiento en una frase de usuario, criterios del hito que cubre, "Toca" con archivos reales, lo que no decide solo quien construye, dependencias y la estimación (código + pruebas; sin `docs/`; una migración con su prueba, mínimo unas 120 líneas). Si el hito mueve dinero, cantidades o fechas, llena "Valores y unidades": qué significa cada campo, en qué unidad va y de dónde sale, para que dos cortes no elijan distinto. Si el hito retira un valor que ya está guardado en datos, usa la receta de retiro de `slices.md`.

5. **ADR, por regla.** Si un corte cambia un contrato que usa otro módulo o app (interfaz, esquema, API) y ningún ADR lo cubre, ese corte es de clase `platform`, va antes de los que lo usan y lleva el contrato, el ADR (máximo 30 líneas) y sus pruebas. Tocar un archivo de `codeowners_paths` sin cambiar un contrato no hace `platform` a un corte: lo retiene CODEOWNERS en el PR. Si el objetivo contradice un ADR vigente, detente: `necesita ADR`.

6. **Escalera y primer tramo.** Por cada parte, el escalón más barato que esconde lo incompleto (`slices.md`) y por qué. Para el escalón 4, lee la receta de `flags`: de ahí salen el nombre del flag, dónde se declara, quién lo enciende y quién es su dueño, una persona o un equipo, lo que diga la receta. Su **fecha de retiro** la manda la receta: si fija una fecha o un plazo, es ese. Si no lo dice, vale el del kit, la fecha del PR de Spec (hoy) más 60 días; no la calculas de otra forma, y se ajusta en el PR del último corte. Si lo que el flag esconde guarda datos, apagarlo no lo revierte: la spec dice qué pasa con lo guardado mientras estuvo encendido y, si la salida es bloquearlo por entorno, con qué señal de la receta se distingue producción (`slices.md`). Si el repo no tiene `flags`, el escalón 4 no existe y el primer corte de la parte es de clase `platform` y lo trae. Marca el **primer tramo**: el menor conjunto de cortes desde el principio, los de clase `data` incluidos, que deja en `main` algo que una persona puede ver en la app.

7. **Compuerta.** Cada corte contra las reglas y la tabla de `slices.md`: de 2 a 5 pasos; estimación de máximo el 75 % de `line_limit` (el tope entero solo con `estimate_basis: measured`, en `revise`); `depends_on` solo nombra cortes anteriores (o, en `revise`, uno nuevo con `revision`), y el orden deja construir cada corte con los suyos ya en `main`, sin apilar ramas; al menos un paso observable; un paso que nombra una prueba puede fallar por el cambio del corte (si la suite corre donde el cambio no aplica, el paso va contra el motor real); toda migración en un corte de clase `data` antes del que la usa; cada criterio del hito cubierto por un corte o anotado en "Fuera de alcance" con a dónde va. Si uno falla, vuelve a partir.

8. **Cortes como archivos.** Un `<hito>/slices/<id>.json` por corte, pasado por `jq --indent 2 .`, con las claves de "El archivo de un corte" de `slices.md`: `id`, `class` (`slice`, `data` o `platform`), `description`, `covers`, `steps` (cada uno `{"do": …, "expect": …}`), `depends_on`, `rung` (1 a 4; obligatorio en `class: slice`, opcional en `data` y `platform`), `estimated_lines`, `spec` y `passes: false`; `blocked_by` solo si aplica (no para repetir la espera de un `depends_on`), y `ships_with` solo si el corte no puede llegar a producción sin otro que viene después (`slices.md`). Las claves van en inglés y el texto, en español.

9. **Comprueba** con la salida a la vista: `git status --short -uall` muestra solo archivos nuevos bajo el hito (con `split`, además el original con `replaced_by`; con `unblock`, solo el corte y `spec.md`; con `revise`, `spec.md` y los cortes que la decisión toca), y `bash "${CLAUDE_SKILL_DIR}/check-spec.sh" <hito> <line_limit>` sale con 0. Con `split`, `unblock` y `revise`, agrégale `--base origin/main`: falla si se borró un corte, si cambió uno con `passes: true` o si uno editado no trae `revision`.

10. **Commit** con la spec y los cortes (mensaje de spec de `${CLAUDE_PLUGIN_ROOT}/skills/ship/git.md`; en `revise`, el de revisión de una spec). Sigue `/city:ship`: el PR es de clase `spec`, con `${CLAUDE_PLUGIN_ROOT}/skills/ship/spec-pr-template.md`, y lo aprueba una persona antes del primer corte. Lo que cambia en Notion (el enlace a la spec en el hito y una tarea por corte, que crea `/city:ship` al abrir el PR) está en `${CLAUDE_PLUGIN_ROOT}/notion.md`.

## Reporte

1. Spec: ruta, partes y escalón de cada una; el flag, su dueño y su fecha de retiro, si hay.
2. Cortes: una línea por corte, `id · clase · comportamiento · pasos · estimación · depende de`.
3. Primer tramo.
4. ADR: no aplica, o en qué corte.
5. Supuestos, preguntas abiertas y cortes con `blocked_by` (pregunta, dueño y desde cuándo), o "ninguno".
6. Referencias de la definición funcional que el código contradijo.
