# Revisar una spec ya mezclada

Lo lee `/city:spec revise <hito>`. Una spec en `main` cambia cuando una persona decide algo después de aprobarla: una respuesta de producto cambia la naturaleza de un corte o vuelve innecesario a otro, o una decisión técnica le suma algo (un flag, por ejemplo) a cortes ya construidos que todavía no entran. No es `split` (un corte que no cabe) ni `unblock` (una respuesta que no cambia nada más).

`<hito>` es la carpeta del hito, su `h<NN>-<slug>` o el id de uno de sus cortes. La revisión es un PR de clase `spec`, sin código, que aprueba quien aprueba el hito.

## Qué puede tocar

| Sobre | Puede | No puede |
|---|---|---|
| Un corte con `passes: false` en `origin/main`, construido o no | Editar `description`, `covers`, `steps`, `depends_on`, `rung`, `estimated_lines`, `estimate_basis`, `ships_with` y `blocked_by`; ponerle `replaced_by` | Cambiar su `id`, su `class`, su `passes`; borrarlo o renombrarlo |
| Un corte con `passes: true` | Nada | Nada: su código se corrige en una rama `-fix` (`slices.md`, "Corregir un corte ya mezclado") |
| El hito | Agregar cortes nuevos, con el número `s<NN>` que sigue | Reutilizar o reordenar ids |
| `spec.md` | Cualquier sección que la decisión cambie (la lista, abajo) | Reescribir lo que no cambia; tocar la sección `### <id>` de un corte con `passes: true` |

Si la decisión cambia la clase de un corte (de `slice` a `data`, por ejemplo), no se edita: se reemplaza por uno nuevo.

### Qué secciones de `spec.md` se pueden tocar

Todas las de la plantilla (`spec-template.md`), cada una solo en lo que la decisión cambia:

| Sección | Cuándo se toca en una revisión |
|---|---|
| "Decisiones tomadas" | Siempre: gana la línea de la decisión. Si la sección no existe, se crea. |
| "Cortes": la tabla | Una fila por corte nuevo; la de un corte editado, al día; la de uno reemplazado dice `reemplazado por <ids>`. |
| "Cortes": cada `### <id>` | La de un corte editado o nuevo ("Toca", "Migraciones", "No decide solo", "Estimación"). La de uno reemplazado se queda y gana una línea `Reemplazado por <ids> (decisión <n>)`. |
| "Escalera", con "Flag" y "Primer tramo" | Si cambia el escalón de una parte, el flag (nombre, dueño, fecha de retiro, corte que lo retira) o qué cortes forman el primer tramo. |
| "Fuera de alcance" y "Después" | Si la decisión saca algo del hito o lo manda a otro. |
| "Supuestos" y "Preguntas abiertas" | Si la decisión responde una pregunta (pasa a "Supuestos", con quién respondió), desmiente un supuesto o abre una pregunta nueva. |
| "Valores y unidades" | Si cambia qué significa un campo, su unidad o de dónde sale. |
| "Contratos y ADR" | Si un corte nuevo o editado cambia un contrato compartido. |
| "Lo que encontré en el código" | Si la decisión parte de algo del código que la spec no nombraba o nombraba mal. |
| "Problema" y "Resultado" | Solo si la decisión cambia qué resuelve el hito o qué se ve al final. Es raro: si cambian mucho, es otro hito. |

El encabezado (aplicativo, módulo, hito y fecha) no cambia: la fecha de la revisión vive en "Decisiones tomadas".

## Reglas

- **Cada cambio sale de una decisión con nombre y fecha.** `spec.md` gana (o crece) la sección "Decisiones tomadas", una entrada por decisión con cuatro datos: la fecha `AAAA-MM-DD`, quién decidió (persona y rol), qué cambia y los cortes que toca. La forma no importa mientras traiga los cuatro: una lista numerada (`1. <AAAA-MM-DD> · <quién> · <qué cambia> · cortes: <ids>`) o con viñetas (`- <AAAA-MM-DD> · …`), en una línea o con el detalle en líneas con sangría debajo. `check-spec.sh` solo exige la fecha de cada `revision` en una línea de la sección; los otros tres datos los comprueba el revisor. Las decisiones no se borran ni se reordenan: una nueva va al final. Sin persona que haya decidido no hay revisión: es una pregunta, y va a "Preguntas abiertas" con su `blocked_by`.
- **`covers` de un corte que nace de una decisión.** Si el corte cubre un criterio o una regla del hito, lleva su id, como siempre (`"CA3"`). Si lo que cubre no está en la definición funcional sino en la decisión, lleva `decision:<n>`, con `<n>` el número de esa decisión en "Decisiones tomadas", contando desde 1 en el orden de la sección (con lista numerada, su número). Pueden ir los dos: `["CA3", "decision:2"]`. Un corte que la revisión solo edita conserva su `covers` y gana `decision:<n>` solo si la decisión le suma algo que cubrir.
- **`revision`.** Cada corte que la revisión edita o crea lleva `"revision": "<AAAA-MM-DD>"`, la fecha de su decisión. Agregar `replaced_by` o quitar una entrada de `blocked_by` no la piden.
- **Reemplazar.** Un corte que la decisión vuelve innecesario queda con `"replaced_by": [<ids>]`, hacia cortes nuevos o hacia uno anterior que ya cubre lo suyo, y no cambia en nada más. Ya no se construye ni cuenta como pendiente. Ningún `depends_on` puede seguir apuntando a él: los cortes que dependían de él pasan a depender de su reemplazo, en la misma revisión.
- **Dependencias hacia adelante.** Un corte nuevo toma el número que sigue, aunque se construya antes que otros. Un corte con id menor puede depender de él: `check-spec.sh` lo acepta porque el nuevo trae `revision`, y falla si se forma un ciclo. El orden de construcción lo da `depends_on`, no el número.
- **Corte ya construido y sin mezclar** (tiene rama o PR abierto). La estimación parte de lo medido: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/size.sh" origin/main --ref <rama>` más lo que la decisión le suma (esconderlo detrás de un flag suma de 60 a 80 líneas), con `"estimate_basis": "measured"`. Así el máximo es el `line_limit` entero y no su 75 %. El PR dice de qué rama salió la medida y cuánto midió. Si aun así pasa el tope, se parte.
- **Después del merge de la revisión,** la rama de un corte construido toma `main` (`git merge origin/main`) para recibir su archivo revisado y sigue con `/city:build <id>`: el código que cambie vence la evidencia que tuviera, como siempre.
- Un `blocked_by` que solo repite la espera de un `depends_on` se quita en la misma revisión.

## Pasos

1. `git fetch origin` y rama `docs/AAAA-MM-DD-revise-<hito>` con `git switch -c <rama> --no-track origin/main`.
2. Lee la spec, todos sus cortes con su `passes` en `origin/main`, y qué ramas y PR abiertos hay de cada uno (`gh pr list --state open`). Lee el código donde cae la decisión: lo que nombres existe o lo crea un corte.
3. Escribe la decisión en "Decisiones tomadas" y aplica los cambios a los cortes y a `spec.md`.
4. Compuerta de siempre sobre lo que cambió (pasos 4 a 8 de la skill) y, con la salida a la vista:
   `bash "${CLAUDE_SKILL_DIR}/check-spec.sh" <hito> <line_limit> --base origin/main`
   Con `--base` falla si un corte se borró, si cambió uno con `passes: true`, si cambió un `passes` o si un corte editado no trae `revision`.
5. `git status --short -uall` muestra solo `spec.md` y archivos de `slices/` del hito.
6. Commit con el mensaje de revisión de una spec de `${CLAUDE_PLUGIN_ROOT}/skills/ship/git.md` (no el de una spec nueva) y `/city:ship`. El cuerpo sale de `${CLAUDE_PLUGIN_ROOT}/skills/ship/spec-pr-template.md` con su sección "Revisión": la decisión y la tabla "antes → ahora", una fila por corte tocado y, si ayuda a quien aprueba, una fila `sin cambios` por cada corte que la decisión nombra y deja igual.
7. Notion, según `${CLAUDE_PLUGIN_ROOT}/notion.md`: una tarea por corte nuevo, y la de un corte reemplazado se anota como reemplazada; devolver un estado es de una persona.
