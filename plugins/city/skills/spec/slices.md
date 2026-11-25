# Qué es un corte

Un corte es un archivo de `<hito>/slices/` y un PR a `main`. Lo construye `/city:build` en una sesión, lo prueba el evaluador solo, lo aprueba una persona y entra a `main` dejándolo desplegable. No hay ramas de hito ni de tarea: todo va a `main`.

## Las reglas

1. **Un comportamiento observable de punta a punta.** Una persona, la API, el CLI o una integración externa (el mensaje que sale a SIMIT, el PDF que se imprime) lo pueden ver cuando el corte entra. Atraviesa las capas que necesita y nada más.
2. **Se prueba solo.** El evaluador lo verifica con lo que ya está en `main` más este corte.
3. **De 2 a 5 pasos,** cada uno verificable como usuario, con curl, con el CLI o con una prueba nombrada ("con su prueba en <archivo o grupo>"). Un paso que nombra una prueba tiene que poder fallar por el cambio del corte: si la suite corre en un motor o un entorno donde el cambio no aplica (una migración que ahí sale sin hacer nada), el paso se escribe contra el motor real ("sube, baja y sube en la base de QA", o la prueba que corre `tests.database`), no contra esa suite.
4. **Estimación de máximo el 75 % de `line_limit`** (300 de 400), contando código, pruebas, migraciones con su reversa y lo generado que el repo versiona. Una migración con su reversa y su prueba rara vez baja de 120 líneas (ver Calibración). **La documentación (`docs/**`) no cuenta.** El margen del 25 % es para lo que no se ve al planear; una estimación que sale de un diff que ya existe no lo necesita (ver `estimate_basis`).
5. **Nunca por capa.** No hay cortes de "modelos", "API", "pantalla", "fundaciones", "refactor previo" ni "pruebas". Las excepciones son las clases `data` y `platform`, abajo.
6. **`main` queda desplegable.** Si el corte entra y se despliega solo, nada se rompe y nada a medio hacer queda a la vista (ver la escalera).

## El archivo de un corte

`<apps_dir>/<aplicativo>/mod-<NN>-<slug>/h<NN>-<slug>/slices/<id>.json`, con el id `m<NN>-h<NN>-s<NN>` (`m28-h01-s01`: módulo 28, hito 01, corte 01). Las claves y los valores enumerados van en inglés; el texto, en español. Es el único formato: `check-spec.sh` rechaza las claves en español de antes.

| Clave | Qué lleva |
|---|---|
| `id` | El nombre del archivo sin `.json`. |
| `class` | `slice`, `data` o `platform` (ver Clases). |
| `description` | El comportamiento en una frase de usuario. |
| `covers` | Lista de criterios y reglas del hito que cubre (`["CA1", "RN3"]`). En un corte que nace de una decisión de `/city:spec revise`, `decision:<n>`, el número de esa decisión en "Decisiones tomadas" (`revise.md`). |
| `steps` | De 2 a 5 pasos `{"do": "<qué se hace>", "expect": "<qué se debe ver>"}`. |
| `depends_on` | Lista de ids de cortes anteriores del hito, o de otro hito que ya existen. Vacía si no depende de nada. Nunca nombra un corte con `replaced_by`, y solo nombra un id mayor si ese corte trae `revision`. |
| `rung` | Escalón de la escalera, de 1 a 4. Obligatorio en `class: slice`; opcional en `data` y `platform`, que casi nunca esconden nada. |
| `estimated_lines` | Estimación en líneas, máximo el 75 % de `line_limit`; con `estimate_basis: measured`, máximo `line_limit`. |
| `estimate_basis` | Opcional: `planned` (por omisión) o `measured` (abajo). |
| `spec` | Ruta de `spec.md` del hito. |
| `passes` | Nace en `false`. Solo lo cambia `scripts/passes.sh` con la evidencia del evaluador. |
| `blocked_by` | Solo si el corte espera a una persona (abajo). Sin bloqueo, la clave no va. |
| `replaced_by` | Los ids que lo reemplazan, nuevos o anteriores. La agregan `/city:spec split <id>` y `/city:spec revise <hito>`. Con ella el corte ya no se construye ni cuenta como pendiente. |
| `revision` | Solo la pone `/city:spec revise <hito>`: la fecha `AAAA-MM-DD` de la decisión que creó o cambió el corte, la misma de "Decisiones tomadas" de la spec. |
| `ships_with` | Opcional: ids de otros cortes sin los cuales este no llega a producción (abajo). Sin orden de despliegue, la clave no va. |

### `estimate_basis`: una estimación medida

`planned` es una estimación hecha antes de construir, y por eso lleva margen: máximo el 75 % de `line_limit`. `measured` dice que la estimación parte de un diff que ya existe: lo que mide `scripts/size.sh origin/main --ref <rama>` sobre la rama o el PR abierto del corte, más lo que una decisión posterior le suma. Ahí el margen ya está gastado y el máximo es el `line_limit` entero. Partir un corte ya construido de 247 líneas porque un flag lo lleva a 320 estimadas, bajo un tope de 400, no protege a nadie.

`measured` vale solo al actualizar la spec de un corte ya construido y sin mezclar, con `/city:spec revise <hito>`, y el PR de clase `spec` dice de qué rama salió la medida y cuánto midió. Nunca en una spec nueva ni en un corte sin rama: sin diff no hay medida. El tope real no cambia: el PR del corte lo mide `size.sh` contra `line_limit`, como siempre.

### `blocked_by`: un corte que espera una respuesta

```json
"blocked_by": [
  { "question": "¿Qué tabla oficial de tarifas aplica desde 2027?", "owner": "Ana Ruiz (PO)", "blocks_since": "2026-11-17" }
]
```

Una entrada por pregunta o insumo: `question` dice qué falta en una frase, `owner` quién responde (una persona, no un área) y `blocks_since` desde qué fecha espera (`AAAA-MM-DD`, la del PR de Spec). La misma pregunta va en "Preguntas abiertas" de la spec. Mientras tenga la clave, `/city:build` y `/city:goal` no lo construyen, y los cortes que dependen de él tampoco; los demás siguen.

**Se desbloquea con un PR de clase `spec`** que edita solo ese campo: cuando la persona responde, `/city:spec unblock <id>` quita la entrada (y la clave, si era la última), pone la respuesta en el cuerpo del PR y la pasa a "Supuestos" de `spec.md`. Lo aprueba quien aprobó la spec. Si la respuesta cambia los pasos, la naturaleza del corte o vuelve innecesario a otro, no es un desbloqueo: es `/city:spec revise <hito>`.

Un `blocked_by` que solo repite la espera de un `depends_on` ("espera a que entre s03") es redundante y no va: `depends_on` ya detiene al corte hasta que el otro entre. `blocked_by` es para lo que responde una persona.

### `ships_with`: cortes que se despliegan juntos

`depends_on` dice qué tiene que estar en `main` para construir un corte. No dice lo contrario: que un corte, ya en `main`, no puede llegar a producción sin otro que viene después. Pasa cuando B depende de A y A solo deja algo a medias que la escalera no esconde: una migración que el código de `main` tolera pero que no debe quedarse sola, un contrato sin su consumidor, un cambio que solo es correcto con el siguiente.

```json
"ships_with": ["m28-h01-s04"]
```

Va en el corte que no puede salir solo (A) y nombra a los que lo completan (B), aunque tengan un id mayor. Significa: se mezclan juntos, o no se despliega entre uno y otro. `check-spec.sh` comprueba que sea una lista de cortes que existen y que no fueron reemplazados. La plantilla del PR lo muestra, `/city:ship` lo dice en su cierre y `/city:check` lo lista bajo "No desplegar" mientras falte alguno: `no desplegar hasta que entre <id>`. El kit no despliega ni detiene un despliegue: quien libera lee esa línea. No reemplaza a la escalera: si un escalón esconde lo incompleto, `ships_with` sobra.

## Un corte se construye sobre la rama principal

Un corte se construye cuando todos sus `depends_on` ya están en la rama principal (`origin/main`): su rama sale de ahí y su PR va contra ahí. Con `git.merge: manual`, eso es esperar el merge de la persona; mientras tanto se construye un corte que no dependa de él, o se espera. No se monta un corte sobre la rama de otro para ir adelantando: `size.sh` sin base cuenta los dos cortes y manda partir, build y ship comparan contra `origin/main`, el squash del PR de abajo deja en conflicto al de arriba y la evidencia del de arriba se vence.

**Excepción: apilado.** Solo si una persona lo pide, y queda dicho en el PR.

- **Rama y PR.** La rama del corte de arriba sale de la del corte base (`git switch -c <rama> --no-track origin/<rama del corte base>`). Su PR se abre con esa base (`gh pr create --base <rama del corte base>`) y trae la sección "Apilado sobre #N" de la plantilla.
- **Todos los scripts reciben la base.** `size.sh origin/<rama del corte base>`; `passes.sh <id> --base origin/<rama del corte base>`, también con `--check` y `--reset`; cada `git diff origin/main...HEAD` de build y ship se lee contra esa rama; y el revisor la recibe como `<base>`. Sin la base, cada uno cuenta el corte de abajo como propio.
- **El evaluador no evalúa un corte apilado** hasta que su base esté mezclada y la rama haya tomado la principal. Antes probaría los dos cortes juntos, y su evidencia se vencería con el squash del de abajo. Mientras tanto el PR queda en borrador, con `**Pendiente:** evaluator · apilado sobre #N`.
- **Cuando el PR de abajo entra,** en la rama de arriba: `git fetch origin && git merge origin/main`. El squash trae el mismo contenido con otra historia, así que puede haber conflicto en los archivos que tocaron los dos: se conserva la versión de la rama de arriba (`git checkout --ours -- <archivo>`), que ya contiene el corte base. Después, `git diff --stat origin/main...HEAD` muestra solo el corte de arriba; si muestra algo del de abajo, la resolución quedó mal. El PR cambia su base (`gh pr edit <n> --base main`) y sigue como cualquier corte: `size.sh` sin base, pruebas, revisor y evaluador.

## Cambiar lo que ya está en `main`

| Qué pasó | Camino | Qué puede tocar |
|---|---|---|
| Un corte con `passes: false` no cabe o no pasa la compuerta | `/city:spec split <id>` | Agrega cortes y le pone `replaced_by` al original. |
| Una persona respondió una pregunta y nada más cambia | `/city:spec unblock <id>` | Quita esa entrada de `blocked_by`. |
| Una respuesta de producto o una decisión técnica cambia cortes con `passes: false`, construidos o no | `/city:spec revise <hito>` | Edita esos cortes, marca reemplazados (también hacia un corte anterior) y agrega nuevos; la spec gana la decisión en "Decisiones tomadas". Detalle en `revise.md`, junto a este archivo. |
| Hay que corregir código de un corte con `passes: true` | Una rama de corrección (abajo) | El código, y en el mismo PR la evidencia renovada. Su archivo no se edita. |

Un corte nunca se borra ni se renombra, y uno con `passes: true` nunca cambia de texto. Los ids no se reutilizan ni se reordenan: un corte que nace en una revisión toma el número que sigue, y por eso otro con id menor puede depender de él (`check-spec.sh` lo acepta si el nuevo trae `revision` y no hay ciclos).

### Corregir un corte ya mezclado

Un PR posterior que cambia código de un corte con `passes: true` va en una rama con su id, `<branches>AAAA-MM-DD-<id>-fix` (`-fix2` si ya hubo una), con la misma clase del corte. En el **mismo PR** el `evaluator` hace una pasada sobre la cabeza y reemplaza `evidence/<id>.md`, y `passes` se reconfirma con `scripts/passes.sh`: `passes.sh <id> --check` sale con 1 mientras la rama traiga código y la evidencia sea la de antes. `/city:ship` lo exige y el `reviewer` lo comprueba. Lo que vence la evidencia de un corte mezclado es eso, código nuevo en la rama que se comprueba: sobre `main`, la evidencia que entró con el merge del corte sigue vigente aunque otro corte posterior, con su propia evidencia, cambie los mismos archivos. No pide pasada nueva un cambio que `passes.sh` deja fuera de la huella: `docs/`, la evidencia, el archivo del corte y `PROGRESO.md`. Un arreglo a producción sigue yendo por `hotfix/`.

**Código, para la evidencia, es todo lo demás.** Las pruebas cuentan: un commit que solo cambia un archivo de prueba vence la evidencia igual que uno que cambia la app, porque el evaluador corre esas pruebas en sus pasos. Antes de pedir una corrección menor (un `debería` del revisor) sobre un corte ya evaluado, cuenta con otra pasada completa del evaluador; si no la vale, va como deuda a un corte posterior que toque ese archivo.

### Corregir un corte que aún no entra

Un PR abierto cuyo corte ya trae `passes: true` en su rama, pero no en `origin/main`, no es una corrección de un corte mezclado: no lleva `fix` en la entrada de `/city:build` ni rama `-fix`. Se sigue en la misma rama, en este orden:

1. El commit del código.
2. `passes.sh <id> --reset`, que ahora sale con algo que hacer (antes del commit del código, `--check` sale con 0 y no marca nada), y el commit de la evidencia vencida con su mensaje de `git.md`.
3. La primera línea del cuerpo vuelve a `**Pendiente:** reviewer, evaluator`. El veredicto del revisor que estaba sobre otro commit queda vencido: en "Veredictos" dice `vencido: era de <sha>`, no el veredicto viejo.
4. Otra vuelta del revisor y otra pasada del evaluador sobre la cabeza. Con roles separados, quien construye hace los pasos 1 a 3 y no corre ninguno de los dos.

"La prueba primero" se cumple así cuando el defecto está en la prueba misma: se muestra la prueba vieja en verde con el defecto y la nueva en rojo con el mismo defecto (por ejemplo, el valor por omisión cambiado a mano, sin commit).

### Un corte mezclado cuyos pasos deja falsos una decisión posterior

Un corte con `passes: true` no cambia de texto. Si una decisión posterior vuelve falso uno de sus pasos (lo que bloqueaba ya no se decide igual), `/city:spec revise <hito>` crea un corte nuevo con `covers: ["decision:<n>"]` que hace verdad lo nuevo. La entrada de "Decisiones tomadas" nombra los pasos que reemplaza, con su corte y número: `pasos 3 y 4 de m28-h01-s15 los reemplaza m28-h01-s16`. La evidencia del corte viejo se queda como historia de lo que fue verdad en su commit.

Si lo que cambia es solo cómo se prueba un paso (otra técnica, otra prueba) y el `do` y el `expect` siguen siendo verdad, no hay revisión: los pasos describen comportamiento, no la prueba. La evidencia del evaluador dice en esa fila con qué prueba lo comprobó.

## Clases

Cada corte tiene una clase. Va como etiqueta del PR (`class:slice`, `class:data`, `class:platform`, `class:spec`) y decide quién aprueba.

| Clase | Qué lleva | Quién aprueba |
|---|---|---|
| `slice` | Un comportamiento (lo de arriba). La mayoría. | Una persona del equipo, ~10 min |
| `data` | Migraciones (con su reversa), permisos sin asignar o un cambio de datos, todos del mismo *expand*: pueden ser varias si crean juntas lo que un mismo corte va a usar. **Aditiva**: columnas nulas, tablas nuevas; nada que el código actual de `main` deje de entender. Se despliega antes que el corte que la usa. Pasos: subir, bajar y subir en la base de la instalación de QA, y "el código de `main` sigue funcionando" con su prueba, que corre donde la migración aplica: contra el motor real, no en una suite donde no hace nada (`skills/build/data-slices.md` del kit). Borrar o volver obligatorio algo (*contract*) es otro corte de clase `data`, después de que nada lo lea. | Quien cuida la base, ~15 min |
| `platform` | Un contrato compartido (interfaz, proveedor, dependencia, CI) con su ADR y sus pruebas, cuando lo usan varios módulos o aplicativos. Pasos: "con su prueba en …". Tocar un archivo con dueño en CODEOWNERS no basta para ser `platform`: eso lo resuelve la revisión del PR. | Tech Lead, ~30 min |
| `spec` | La spec y sus cortes, el desbloqueo de un corte o la revisión de una spec ya mezclada. Sin código. No es un valor de `class` de un corte: es la clase del PR. | Quien aprueba el hito |

Una migración nunca va dentro de un corte de clase `slice`. Si un corte necesita una columna, un corte de clase `data` anterior la crea.

## La escalera: cómo se esconde lo incompleto

La spec dice qué escalón usa (`rung`). Se toma el más barato que alcance:

1. **Cada corte ya es entregable.** Si cada corte, solo, deja algo correcto (aunque el hito no esté completo), no hay nada que esconder. Es lo normal en hitos que corrigen comportamiento.
2. **El punto de entrada va al final.** Se construye por dentro y el último corte agrega el menú, el botón o la ruta.
3. **Un permiso sin asignar.** La pantalla nueva existe en `main`, pero nadie la ve hasta que alguien asigna el permiso a un rol. No esconde nada a un rol que se salta los permisos (en city, `super_admin`): si eso importa, usa el 4.
4. **Un flag,** como dice la receta de `flags` de `.city.json` (en city, Pennant con la página Funcionalidades), solo si nada de lo anterior alcanza; el caso típico es cambiar una pantalla que la gente ya usa. Lo crea el primer corte que esconde algo, apagado, con dueño y **fecha de retiro**.
   - **Dueño:** una persona o un equipo, lo que diga la receta `flags` del repo. Si la receta no lo dice, una persona.
   - **Fecha de retiro:** manda la receta `flags` del repo: si fija una fecha, un plazo o desde cuándo se cuenta, es eso. El kit solo da el valor por omisión, para cuando la receta no lo dice: la fecha del PR de Spec más 60 días. La spec no planea cuándo entra cada corte, así que no se calcula desde "el último corte". Se ajusta una sola vez, en el PR del último corte del hito: ahí se sabe cuándo se va a encender, y ese PR corrige la fecha en `spec.md` y donde la receta la registre.
   - Se enciende sin desplegar, cuando el hito está completo. Si no puede encenderse en producción hasta otro hito, el corte que lo retira va en ese hito.
   - Con el flag apagado, la app se ve y se comporta como antes: es un paso de cada corte que esconde algo.
   - **Un flag que guarda datos no se revierte apagándolo.** Si con el flag encendido la app guarda algo (registros, estados, archivos, mensajes que salen a otro sistema), apagarlo esconde la pantalla y deja lo guardado. La spec dice qué pasa con lo que se guardó mientras estuvo encendido: quién lo lee con el flag apagado, y si se conserva, se ignora o se limpia. Si eso es inaceptable, el flag se bloquea por entorno (no se puede encender donde no debe) o el consumidor de esos datos también consulta el flag.
   - **Cómo se detecta "producción" lo dice la receta `flags` del repo,** no el kit. Los ambientes de revisión pueden correr con la misma configuración que producción: la receta nombra una señal que los distinga. Si no la nombra, el bloqueo por entorno no existe en ese repo: la spec lo dice y lo deja en "Preguntas abiertas".
5. **Nunca una rama larga.**

## Cómo partir

En este orden, hasta que cada corte cumpla las reglas:

1. **Esqueleto que camina:** el camino más corto de punta a punta.
2. **Caso normal completo.**
3. **Validaciones y errores.**
4. **Permisos y alcance.**
5. **Casos borde, volumen y rendimiento.**

Si un criterio de aceptación depende de algo que construye un hito posterior, pasa a ese hito y se anota en "Fuera de alcance"; no se crea un contrato provisional que se comporte igual que hoy.

Si la definición pide algo que el código ya cumple, no hay corte: una prueba de regresión lo deja fijo dentro del corte más cercano. Esa prueba pasa antes del cambio: quien construye rompe a propósito el comportamiento en su rama, la ve fallar, lo restaura y lo declara en el PR con el final de la salida de la prueba fallando. El revisor juzga por lectura si la prueba puede fallar; el evaluador solo lo repite si el repo da un comando para ello (`tests.mutation` de `.city.json`, o lo que diga `docs/harness/entorno.md`).

Si un hito corrige varios consumidores independientes de un dato, cada consumidor es un candidato natural a corte. Si un tramo sigue sin caber, pártelo por operación o por aplicativo.

## Receta: retirar un valor que ya está en los datos

Cuando el hito quita una opción, un estado o un tipo que hay registros usando (y la columna queda más angosta), son cuatro cortes, cada uno su PR, en este orden:

| # | Corte | Clase | Qué hace | Cómo se revierte |
|---|---|---|---|---|
| 1 | Dejar de ofrecer el valor | `slice` | La app ya no deja elegirlo ni lo crea; lo que está guardado se sigue leyendo y mostrando. | Revertir el PR. |
| 2 | Homologar los datos | `data` | Pasa cada registro del valor viejo al nuevo y guarda en una tabla de homologación `registro · valor anterior · valor nuevo · fecha`. La reversa de la migración restaura desde esa tabla. | La reversa, con la tabla. |
| 3 | Quitar el valor del código | `slice` | Borra el enum, las ramas, las traducciones y las pruebas del valor viejo. | Revertir el PR. |
| 4 | Encoger la columna | `data` | El *contract*: quita el valor del tipo o de la restricción de la columna. La tabla de homologación se queda hasta que quien cuida la base la retire. | Solo con la tabla: es el paso que no tiene vuelta barata. |

Por qué en ese orden: si se homologa antes de dejar de ofrecer el valor (2 antes que 1), entre la migración y el despliegue se crean registros nuevos con el valor viejo y la homologación queda incompleta. Si se quita del código antes de homologar (3 antes que 2), `main` deja de entender registros que todavía existen. Y la columna se encoge al final (4) porque es lo único destructivo: antes de ese corte, cada paso se deshace sin perder nada, y `main` queda desplegable después de cada uno. Qué valor nuevo recibe cada registro lo decide el PO, no la spec: si no está en la definición, el corte 2 nace con `blocked_by`.

**Variante sin homologación.** Cuando producto confirma que nadie usa el valor (queda escrito en "Supuestos" o en "Decisiones tomadas", con quién lo dijo), no hay nada que homologar ni tabla que guardar. El corte 2 sigue existiendo y sigue siendo de clase `data`, pero es una **comprobación**: cuenta los registros con el valor viejo y, si encuentra alguno, se detiene con un error que dice cuántos y no cambia nada; si no encuentra ninguno, termina sin tocar datos. Su reversa no hace nada. Sus pasos prueban los dos casos: sin registros pasa, y con un registro marcado se detiene y el registro sigue igual. Los cortes 1, 3 y 4 no cambian, ni su orden: el 4 depende del 2, porque es la comprobación la que garantiza que encoger la columna no pierde nada. Si la comprobación se detiene en un entorno, la confirmación era falsa: se vuelve a la receta completa con `/city:spec revise <hito>`.

## Partes y primer tramo

Si un hito pasa de 8 cortes, la spec se ordena en partes (A, B…) que se esconden distinto: una pantalla nueva con el escalón 3 y el cambio a una pantalla existente con el 4, por ejemplo. El **primer tramo** es el menor conjunto de cortes desde el principio, los de clase `data` incluidos, que deja algo que una persona puede ver; es lo primero que se construye y lo primero que se mide.

## Calibración

| Así no | Así sí |
|---|---|
| "Migración y modelo", "API" y "pantalla" de lo mismo, en tres cortes | `data`: la columna nula. `slice` 1: un consumidor la usa de punta a punta. `slice` 2: el siguiente consumidor |
| "Fundaciones": un servicio que nadie usa todavía | El primer corte que lo necesita lo crea y lo usa |
| Una migración dentro del corte que la usa | Un PR de clase `data` antes, desplegado primero |
| Siete tareas de 650 a 1.500 líneas en una rama de hito | Tantos cortes como comportamientos, cada uno a `main` |
| "Refactor del servicio" antes de la funcionalidad | El refactor va en el corte que lo necesita, si cabe |
| Un paso que dice "la pantalla de s03 muestra lo de s02" en el corte s02 | Ese paso va en s03 |
| Homologar los datos y encoger la columna en la misma migración | La receta de retiro: cuatro cortes, la columna al final |
| Saltarse el corte de datos porque "nadie usa el valor" | La variante sin homologación: una comprobación que se detiene sin cambiar nada si encuentra registros |
| Esconder detrás de un flag un corte ya construido y estimar "unas líneas" | Suma de 60 a 80 líneas: la declaración del flag, la consulta donde se esconde, los textos y el caso apagado en las pruebas. Sobre el diff medido, con `estimate_basis: measured` |
| Partir un corte ya construido de 247 líneas porque una decisión lo lleva a 320 estimadas, con tope de 400 | `/city:spec revise <hito>` con `estimate_basis: measured`: el máximo es el tope entero |
| Un `blocked_by` que dice "espera a s03" | `depends_on: ["…-s03"]` y nada más |
| Estimar una migración por lo que "cambia": 70 líneas para agregar un valor a una lista cerrada de valores (fueron 129, un 84 % más) | Mínimo unas 120 con su prueba. Si la migración repite una lista de valores, cuéntala tres veces: al subir, al bajar y en la prueba |
| En un corte de clase `data`, el paso "corre la prueba X", cuando X corre en un motor donde la migración no hace nada: pasa con el cambio y sin él | El paso se escribe contra el motor real: subir, bajar y subir en la base de QA, o la prueba que corre `tests.database` |
