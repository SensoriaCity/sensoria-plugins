---
name: spec
description: Escribe la spec de una página de un hito y la parte en cortes verticales que caben en tope_lineas; cada corte entra a features como funcionalidad nueva con 2 a 5 pasos verificables y passes false. Con partir <id>, reemplaza una funcionalidad que no es un corte. Úsala antes de /city:build o /city:goal cuando el cambio no cabe en una frase.
argument-hint: "<objetivo en una frase | ruta a un documento | URL del hito | partir <id>>"
disable-model-invocation: true
---

# /city:spec

Entrada: $ARGUMENTS

Conviertes un objetivo en una spec de una página y en cortes que `/city:build` construye uno por sesión y `/city:goal` recorre en orden. No escribes código. Lo que hace buena a una spec son sus cortes: cada uno es un vertical slice que cabe en `tope_lineas` y que el evaluador prueba solo.

## Configuración

Lee `.city.json` en la raíz del repo (`git rev-parse --show-toplevel`). Si no existe, detente y dilo: el kit no sabe nada del stack y no adivina. De ahí salen `features`, `adr_dir`, `tope_lineas`, `codeowners_paths` y `specs_dir` (sin él, `docs/specs`). Su contrato está en `${CLAUDE_PLUGIN_ROOT}/city.schema.json`. Las reglas duras del `CLAUDE.md` del repo mandan sobre esta skill.

## Reglas duras

- Antes de partir, lee `${CLAUDE_SKILL_DIR}/cortes.md`: las cinco reglas de un corte, cómo partir y la tabla de calibración. Es la parte que más importa de la spec.
- Un corte es una funcionalidad. No hay entregas, subtareas ni "E1, E2" dentro de un id: si algo necesita partirse, son varias funcionalidades.
- Nunca editas, reordenas ni borras una funcionalidad que ya está en `features`. Solo agregas al final; la única excepción es la clave `reemplazada_por` de `partir <id>`.
- No escribes código, migraciones ni pruebas. Tampoco ADR: si hace falta uno, lo dices (paso 5).
- Lo que nombres (archivos, pruebas, tablas, rutas) existe en el repo o lo crea un corte de esta spec. No lo inventas.

## Partir una funcionalidad

Con `partir <id>`, la entrada es una funcionalidad de `features` con `passes: false` que no pasa la compuerta de `/city:build` (si tiene `passes: true`, detente: lo que falte es otra spec). Lee sus pasos, los PR mergeados que traen su id (`gh pr list --state merged --search "<id>"`) y el código de `origin/main`. La spec cubre solo lo que falta, con los pasos 1 a 9 de siempre, y en el paso 7 le agregas a la original `"reemplazada_por": [<ids nuevos>]`, sin cambiar nada más: `/city:build` y `/city:goal` ya no la toman.

## Pasos

1. **Orientación.** `git fetch origin` y rama `docs/AAAA-MM-DD-spec-<tema>` desde `origin/main`. Lee de `features` los ids y las claves de las existentes, los ADR de `adr_dir` que tocan el tema y el código donde va a caer (búscalo con grep).

2. **Preguntas.** Si la entrada no dice quién usa el resultado, qué ve al terminar o qué queda fuera, pregunta antes de escribir, máximo 3 preguntas en un solo mensaje. Sin nadie a quien preguntar, toma la lectura más razonable y anótala en "Supuestos".

3. **Spec** en `<specs_dir>/AAAA-MM-DD-<tema>.md`, con `${CLAUDE_SKILL_DIR}/plantilla-spec.md`. Cabe en una página: si pasa de 8 cortes, son dos specs; escribe la primera y deja la segunda en "Después".

4. **Cortes,** con `${CLAUDE_SKILL_DIR}/cortes.md`. Cada corte lleva en la spec: comportamiento en una frase de usuario, "Toca" con archivos o carpetas reales, lo que no decide solo quien construye, dependencias nuevas con la línea exacta que las instala (la corre una persona) y la estimación en líneas. Los pasos van en `features`: de 2 a 5, en el lenguaje de quien usa la app, cada uno con lo que el evaluador hace y lo que debe ver.

5. **ADR, por regla.** Si un corte cambia un archivo de `codeowners_paths` o una interfaz, esquema o API que usa otro módulo o app, y ningún ADR de `origin/main` lo cubre, ese corte es el 1 y lleva el contrato, el ADR y sus pruebas. Si el objetivo contradice un ADR vigente, detente: responde `necesita ADR` con el motivo y no agregues funcionalidades.

6. **Compuerta.** Antes de tocar `features`, revisa cada corte contra las cinco reglas y la tabla de `cortes.md`, y contra estos límites: máximo 5 pasos; estimación de máximo el 75 % de `tope_lineas`; ningún paso depende de un corte posterior; al menos un paso que una persona, la API o el CLI pueden observar, salvo en el corte de contrato de la regla 5. Si uno falla, vuelve a partir. No lo dejes pasar con una nota.

7. **Funcionalidades.** Agrega los cortes al final de `features`, en el orden de la tabla:
   - Las mismas claves que las funcionalidades existentes; si no hay ninguna, `id`, `descripcion`, `pasos` y `passes`.
   - `"spec": "<ruta de la spec>"` y `"passes": false`.
   - Ids con el patrón de los existentes, o `<tema>-c01`, `<tema>-c02`…; solo letras, números, punto, guion y guion bajo (lo exige `scripts/passes.sh`).
   - Con jq y la sangría del archivo (`--indent <n>` o `--tab`), la misma que conserva `scripts/passes.sh`. Antes, `jq <formato> . <features> | cmp -s - <features>`: si difiere, detente; el formato de `features` se arregla en un PR aparte.
   - Escribe el arreglo nuevo en un archivo temporal fuera del repo y corre `jq <formato> --slurpfile n <temporal> '. + $n[0]' <features> > <temporal 2> && mv <temporal 2> <features>`. Con `partir <id>`, en la misma pasada: `jq <formato> --slurpfile n <temporal> --arg id <id> 'map(if .id == $id then . + {reemplazada_por: ($n[0] | map(.id))} else . end) + $n[0]' <features>`.

8. **Comprueba** con la salida a la vista:
   - `jq -e 'map(.id) | length == (unique | length)' <features>`: ids únicos.
   - `git diff origin/main -- <features>`: solo líneas agregadas; con `partir`, además la clave `reemplazada_por` y la coma que la precede.
   - `jq -e --arg s <ruta de la spec> '[.[] | select(.spec == $s)] | length > 0 and all(.passes == false and (.pasos | length) >= 2 and (.pasos | length) <= 5 and (.id | test("^[A-Za-z0-9_-][A-Za-z0-9._-]*$")))' <features>`: las nuevas, con `passes: false`, `spec`, de 2 a 5 pasos e ids válidos.

9. **Commit** con la spec y `features`, con el mensaje de spec de `${CLAUDE_PLUGIN_ROOT}/skills/ship/git.md` según `git.commits` (sin la clave, `docs(spec): <tema>`). El PR lo abre `/city:ship` en esta sesión (rama `docs/`, sin funcionalidad). Cuando entre a `main`, sigue `/city:goal <ids en orden>` o `/city:build <id>` en una sesión nueva por corte.

## Reporte

1. Spec: ruta, hito y flag.
2. Cortes: una línea por corte, `id · comportamiento · pasos · estimación`.
3. ADR: no aplica, en el corte 1 (`<ruta>`) o `necesita ADR` con el motivo.
4. Supuestos y preguntas abiertas, o "ninguno".
5. Siguiente paso: `/city:ship` en esta sesión.
