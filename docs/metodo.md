# El método city

`city` es la forma de desarrollar con agentes en Sensoria. Un solo plugin de Claude Code sirve a `city` (Filament) y a `city-v2` (Laravel + React): cada repo le dice al kit cómo es su stack con un `.city.json` en la raíz, y el kit no adivina nada. Reemplaza a AIDD Lite, cuyo piloto no llegó a empezar (su último estado quedó en el tag `aidd-lite-0.2.0`), y a BMAD a medida que cada squad lo adopta (ver `adopcion.md`). La decisión de arquitectura del lado de city-v2 es su ADR-0031.

Lo que buscamos atacar está medido en `aidd-metrics/docs/descubrimiento.md`. En el periodo BMAD el tamaño mediano de PR a `main` pasó de 144 a 507 líneas, el p85 de 806 a 4.240, la apertura → merge mediana de 42 h a 143 h, y el 92% de los PRs a `main` se mergeó sin revisión humana. Son señales exploratorias, no métricas validadas, pero apuntan a lotes grandes y a un impuesto de verificación que nadie está pagando. AIDD Lite respondía con una persona que aprobara cada PR; `city` paga ese impuesto con verificación automática que no se puede saltar y deja a las personas donde su lectura decide algo.

## El ciclo

```
Cualquier persona con Claude, una sesión por funcionalidad                     Quien libera
/city:spec ─▶ /city:build ───────────────────────────▶ /city:ship ─▶ checks ─▶ /city:check ─▶ flag
1 pág. =      compuerta de corte · prueba primero ·     PR, label,    CI +       10 min,       on
hito, en      revisor · evaluador en una instalación    auto-merge    revisor +  reporte
cortes        limpia → evidencia → passes.sh            por squash    evidencia  armado
```

`/city:goal` encadena `build` y `ship` por los cortes de una spec, en orden y sin persona.

Un cambio que cabe en una frase se salta la spec: va directo a `/city:build` con su funcionalidad.

## Sin roles

Cualquier persona corre `build`, `ship` y `check`, y cualquiera hace push a sus ramas. Ninguna skill distingue senior, junior ni TL. Las personas aparecen en tres lugares fijos (ver "Control humano") y en los PR que retiene CODEOWNERS.

Fuera del desarrollo:

| Rol | Qué hace |
|---|---|
| PO | Redacta el módulo y cada hito en Notion con `/city:discovery`, que le pregunta lo que falta y cuestiona lo que quedó en el aire. Valida los pasos de la spec cuando es una feature de usuario. Decide cuándo se enciende el flag. |
| QA | No prueba cortes: eso lo hace el `evaluator`. Prueba la feature completa antes del flag, y lo que encuentra se vuelve paso o prueba. |
| Diseño | Deja el enlace de Figma en la spec cuando hay UI nueva. |

## Reglas

1. **Spec de una página = hito.** La escribe `/city:spec`: cabe en una página y es un hito en Hitos v2. Sus cortes viven en `slices/` de la carpeta del hito (`<apps_dir>/<aplicativo>/<modulo>/<hito>/`; en city 2.x, en la carpeta `features` de `.city.json`), un archivo `<id>.json` por corte para que dos specs escritas a la vez no choquen, cada una con pasos verificables y `passes: false`, y entran a `main` en un PR propio antes del primer corte. Un cambio que cabe en una frase no lleva spec.
2. **Cortes verticales de ≤400 líneas.** Un corte es un vertical slice: un comportamiento que una persona, la API o el CLI pueden observar de punta a punta, que el evaluador prueba solo, con 2 a 5 pasos, en un PR a `main` de máximo `line_limit` (400). Se planea con una estimación de máximo el 75 % del tope; si la estimación sale del diff ya medido de un corte construido (`estimate_basis: measured`), el máximo es el tope entero. Un corte es una funcionalidad: no hay entregas dentro de un id. Una funcionalidad que no es un corte se reemplaza con `/city:spec split <id>`, que la deja con `replaced_by` y agrega los cortes. Una spec ya mezclada cambia con `/city:spec revise <hito>`, por una decisión con nombre y fecha y solo en cortes con `passes: false`; el código de un corte con `passes: true` se corrige en una rama `<branches>AAAA-MM-DD-<id>-fix` cuyo PR renueva la evidencia. No se corta por capas y no hay ramas de hito ni PR apilados: un corte se construye cuando sus `depends_on` ya están en la rama principal, y con `git.merge: manual` se espera el merge de la persona. Apilar un corte sobre la rama de otro es una excepción que pide una persona (ver "No se apila", abajo). Las reglas y la calibración están en `plugins/city/skills/spec/slices.md`; `/city:spec` las aplica al partir y `/city:build` las vuelve a aplicar en su compuerta, antes de escribir código. El tamaño real se mide solo con `scripts/size.sh`, sin lockfiles, `vendor/` ni la evidencia.
3. **Lo incompleto va tras flag,** no en una rama larga. Un merge a `main` no despliega, pero la versión siguiente lo llevaría. Un flag que guarda datos no se revierte apagándolo: la spec dice qué pasa con lo guardado mientras estuvo encendido, y si eso es inaceptable el flag se bloquea por entorno o el consumidor también lo consulta. Cómo se distingue producción lo dice la receta `flags` del repo. Cuando un corte ya mezclado no puede llegar a producción sin otro, lo dice su `ships_with` y `/city:check` lo lista: "no desplegar hasta que entre <id>".
4. **Prueba primero.** Cada paso tiene una prueba que falla sin el cambio, escrita antes de implementar. "Listo" es la salida de las pruebas a la vista, no una afirmación. En un corte de clase `data`, la prueba de la migración corre contra el motor real en una base desechable (`tests.database`), nunca contra la de desarrollo; si el repo no tiene esa receta, el paso lo demuestra la evidencia del evaluador (`plugins/city/skills/build/data-slices.md`).
5. **Quien construye no se califica.** El `reviewer` lee el diff en contexto limpio; el `evaluator` prueba como usuario sobre una instalación limpia. Ninguno recibe el resumen de quien construyó, la descripción del PR ni sus comentarios; el revisor lee el cuerpo del PR solo para comprobar su forma, nunca como evidencia. Construir, revisar y evaluar pueden ser tres sesiones distintas: entonces `/city:ship draft` abre el PR en borrador con la línea `**Pendiente:**` y lo pasa a listo cuando están los dos veredictos. La evidencia de quien construye va en el cuerpo del PR, no en un archivo.
6. **El evaluador es el único dueño de `passes`.** `passes` cambia solo con `scripts/passes.sh`, que exige la evidencia del corte (`evidence/<id>.md` de su hito; en city 2.x, `<evidence_dir>/<id>.md`) con el encabezado de ese id y la última línea `VEREDICTO: pasa`. Nadie lo cambia a mano. La evidencia la escribe el evaluador, que también corre `passes.sh`; el commit lo hace quien lo llamó. Vale para el código que probó: si el código cambia después en la rama del corte, `passes.sh <id> --check` sale con 1 y `passes.sh <id> --reset` devuelve `passes` a `false` hasta la siguiente pasada, y le agrega a la evidencia la línea `VENCIDA: evaluó <commit>; el código cambió en <commit>`, para que no siga diciendo que pasa. Después del merge, también por squash, la evidencia que entró con el corte sigue vigente sobre `main`: lo que la vence es código nuevo en la rama que se comprueba (la del corte o una `-fix`), no que un corte posterior, con su propia evidencia, toque los mismos archivos. El límite que queda está en el encabezado de `passes.sh`: un cambio al código de un corte mezclado que llega a `main` por otro camino no se nota ahí.
7. **Merge por checks.** El PR entra solo, por squash, cuando pasan los checks requeridos: el CI del repo, el `revisor` y la `evidencia`. Si toca una ruta con dueño, lo retiene CODEOWNERS hasta que lo apruebe una persona. Ruta con dueño es la unión de `codeowners_paths` y del archivo de dueños del repo (`scripts/owners.sh`, que también usa la guarda de `goal.sh`); `/city:check` avisa si los dos divergen. Si el revisor termina en `espera decisión`, el PR tampoco entra hasta que la persona que nombra decida.
8. **ADR por regla, no por criterio.** Hace falta si el diff toca `adr_dir`, un patrón de `codeowners_paths` o una interfaz, esquema o API que usa otro módulo o app. `codeowners_paths` son las rutas compartidas; el archivo de dueños del repo dice quién debe aprobar, puede repartir todo por equipo o por panel, y una ruta que solo está ahí retiene el merge sin pedir ADR (`owners.sh --match shared` y `--match owned` dicen cuál coincide). Un cambio aditivo de esquema que nadie lee todavía no lo pide. El corte 1 lleva solo el contrato, el ADR (≤30 líneas) y sus pruebas; lo retiene CODEOWNERS de otra squad. Un ADR en `main` está aceptado.
9. **Firma.** Rama `<branches>AAAA-MM-DD-<id>` y el `label` de `.city.json` (`city`). Sin eso el flujo no se puede medir.
10. **Hotfix por su flujo.** Los arreglos a producción van por `hotfix/`, nunca por la rama de `city`, o el change failure rate queda subcontado. Todo hito lleva spec; en un hotfix la spec es opcional y el PR lleva los pasos y la evidencia.
11. **Las dependencias las instala una persona.** El hook `dependency-guard` rechaza lo que cambia manifiestos o lockfiles, y CODEOWNERS retiene el PR que los toca.

## Comandos

| Comando | Quién | Entrada | Qué deja |
|---|---|---|---|
| `/city:discovery` | PO | `module <URL>` o la URL de un hito en Notion | Con `module`, la página del módulo y su reparto en hitos. Con un hito, su definición funcional redactada con las respuestas del PO, y `Definición: lista` o lo que sigue en el aire con quién lo resuelve. El PO aprueba cada texto; no toca el repo. |
| `/city:spec` | Cualquiera, con el PO si es una feature de usuario | objetivo en una frase, documento o URL del hito; o `split <id>`, `unblock <id>`, `revise <hito>` | Rama `docs/AAAA-MM-DD-spec-<tema>` con `spec.md` y un archivo por corte en `slices/` de la carpeta del hito, cada uno con su `class` y `passes: false`. Revisa cada corte contra `slices.md` y corre `check-spec.sh` antes del commit. Con `unblock <id>`, quita un `blocked_by` respondido. Con `revise <hito>`, cambia cortes con `passes: false` de una spec ya mezclada, marca reemplazados y agrega nuevos, con la decisión en "Decisiones tomadas" y la tabla "antes → ahora" en el PR. El PR lo abre `/city:ship`. |
| `/city:build` | Cualquiera | id de funcionalidad, y el plan del día si lo hay | Rama `<branches>AAAA-MM-DD-<id>`: compuerta de corte (para con `Bloqueo` si la funcionalidad no es un vertical slice que cabe), prueba primero, implementación, tamaño, ADR, veredictos del `reviewer` (y de `security` si aplica) y del `evaluator`, que escribe su evidencia y, si pasa, corre `passes.sh`; build hace el commit. Un corte de clase `data` se prueba contra el motor real desde el principio. |
| `/city:ship` | Cualquiera | nada, o `draft` | PR a `main` con la plantilla del repo, el `label`, la etiqueta de su clase (`class:slice`, `class:data`, `class:platform` o `class:spec`; las crea si faltan) y `gh pr merge --auto --squash` si ningún archivo tiene dueño (en `/city:goal` lo activa `goal.sh`, con la misma guarda). Si CODEOWNERS retiene, dice qué archivos y a quién. Con `draft`, cuando revisar o evaluar le toca a otra sesión, abre el PR en borrador con `**Pendiente:**` y, al volver a correr con los dos veredictos vigentes, lo pasa a listo. Comprueba con `passes.sh --check` que la evidencia sea del código vigente. |
| `/city:check` | Quien libera | `<id>`, `hoy` o `semana` | Reporte de solo lectura de 10 minutos: mergeados y versiones, `passes` con evidencia, retenidos, PR en rojo, ADR pendientes, smoke y qué clickear. |
| `/city:review` | CI, o cualquiera a mano | número de PR | Delega al `reviewer` con `id · rama · base` (id `ninguna` si la rama y el título no lo traen) y deja su respuesta en `verdict.md` y el veredicto en `verdict.txt`. Es la única skill que puede invocar el modelo, porque corre sin persona. |
| `/city:goal` | Cualquiera, en una terminal | ids en orden, y `--plan`, `--max-sessions`, `--max-blocks`, `--quiet` | Da la línea para `scripts/goal.sh`, que corre sin persona y un id a la vez: worktree desde `origin/main`, `claude -p` con `/city:build` y `/city:ship` en auto mode, espera checks y merge, un reintento si un check falla. Para todo con `necesita ADR` o `Bloqueo` en build, con un PR que nace esperando la decisión de una persona (no lo cuenta como vuelta ni lo reintenta: dice quién decide), dos ids seguidos sin merge, el tope de sesiones (12), Docker apagado o `claude` sin sesión (`Not logged in`), que también se prueba antes del primer worktree. Muestra en la terminal una línea por herramienta de cada sesión y una línea de estado (`--quiet` las apaga). Deja el log en `${TMPDIR:-/tmp}/city-goal/` y el resumen `goal.md` por stdout; el cierre es `/city:check`. |

Diseñados y todavía sin construir, en este orden: `/city:retro` (números y una pieza menos) y `/city:adr`. Hasta entonces, la retro y los ADR se hacen con lo que tenga el repo.

## Agentes

- **`reviewer`.** Contexto limpio, sin edición. Recibe `<id> · <rama> · <base>`. Lee el diff completo, corre las pruebas de `tests`, aplica las reglas duras del `CLAUDE.md` del repo, el checklist de seguridad (`security_checklist`) y los chequeos del stack (`reviewer_extra`). Hallazgos `bloquea`, `decide`, `debería` o `sugerencia`; termina en `Veredicto: listo para merge`, `Veredicto: no mergear` o `Veredicto: espera decisión`. `decide` es para lo que no es un defecto del código: la spec parte de un supuesto que el código desmiente, y el PR no se mezcla hasta que la persona que el revisor nombra decida; `ship` lo trata como pendiente de una persona, no como un rojo. Si la rama no es la actual, corre las pruebas en un árbol aparte (`git worktree add` en una carpeta temporal que borra); si ahí faltan las dependencias, lo dice y razona por lectura. Cuando el árbol de trabajo está limpio y quien lo llama dice que nadie más lo usa (`arbol: libre` en su línea; la sesión de CI lo pone), puede pasarlo a la rama con `git checkout --detach`, correr ahí, donde sí están las dependencias, y devolverlo a donde estaba. Si una prueba de regresión puede fallar lo juzga por lectura; un ADR lo pide una ruta de `codeowners_paths`, no cualquier archivo con dueño. Lee el cuerpo del PR solo para su forma (línea de estado, atribuciones prohibidas). Con id `ninguna` revisa solo reglas duras, seguridad, título, forma del PR y dependencias, y el veredicto sale de esos hallazgos; en un PR de clase `spec` comprueba además qué cambió de cada corte. Máximo dos vueltas; a la tercera, el PR nace bloqueado y lo decide una persona. En un corte de clase `data` aplica además su bloque de migraciones: espera de bloqueos, drivers equivalentes, reversa que decide datos y tabla grande. Corre dentro de `/city:build` y como check de CI con `/city:review` (ver "En CI").
- **`security`.** Solo cuando el diff toca autenticación, permisos, archivos, integraciones o el CLI, y solo sobre los archivos que le pasan. Mismo veredicto que el revisor.
- **`evaluator`.** Contexto limpio, sin edición, sin `browser_evaluate` ni `browser_run_code_unsafe`, y sin herramientas para redimensionar o cerrar el navegador. Recibe el id, la URL de una instalación local limpia (`qa-env.py` lo confirma) y la ruta del clon donde corre. Ejecuta cada paso como un usuario: UI con las herramientas de navegador de la sesión (en un navegador compartido trabaja en una pestaña propia, no redimensiona y cierra solo lo suyo; `plugins/city/skills/build/browser.md`), API con curl, infra con bash y `qa.smoke`; una cláusula "con su prueba en <grupo o suite>" la verifica corriendo esa prueba en el clon (con `tests.postgres` si necesita base desechable), nunca leyendo CI. Umbral duro: un paso que no cumple o no se pudo verificar, no pasa. Lo que ve fuera de la funcionalidad va en "Fuera de alcance" y no cambia el veredicto. Solo con `instalacion: desechable`, o en un corte de clase `data` sobre la base de la instalación de QA o una desechable, ejecuta pasos que borran o alteran filas o que suben y bajan una migración; nunca reinicia la base ni borra volúmenes, y nunca toca la base de desarrollo. Escribe su evidencia en `evidence/<id>.md` y corre `passes.sh`; hace el commit solo con `commit: evidencia` en su línea de entrada y el push solo con `push: evidencia`. No arma copias del repo ni toca las carpetas de dependencias: romper a propósito una prueba de regresión lo hace quien construye, en su rama, y lo declara en el PR; el evaluador solo lo repite si el repo da un comando (`tests.mutation`). No evalúa un corte apilado hasta que su base esté en `main`. Un error de consola que también ocurre sin el corte es ruido del entorno: se declara y no cuenta. Deja una o más capturas por paso (`<id>-paso<n>[-<detalle>].png`). Calibrado con ejemplos de "esto no pasa", porque un evaluador sin calibrar se convence de que un problema no es grave.

## `.city.json`

El contrato entre el kit y cada repo está en `plugins/city/city.schema.json`; el de city-v2 sirve de ejemplo en `docs/ejemplos/city-v2.city.json`. De ahí salen los comandos de prueba (`tests`), la instalación del evaluador (`qa`), `features`, `specs_dir`, `evidence_dir`, `adr_dir`, `branches`, `label`, `codeowners_paths`, `codeowners_file`, `line_limit`, `apps_dir` y, si el repo no sigue los valores por omisión, sus convenciones de commits, merge y versión (`git`). Las claves van en inglés; las de city 2.x en español se siguen leyendo cuando falta la nueva (la tabla está en `adopcion.md`). Lo propio de cada máquina (puertos, versiones, cómo bajar una instalación) va en `docs/harness/entorno.md` del repo.

## En CI

El check `revisor` del ruleset es este job (el check conserva su nombre; el agente es `reviewer` y la skill, `/city:review`). Corre `/city:review` sobre el PR con el plugin de `main` de este repo y falla si el veredicto no es `listo para merge`. Solo corre en los PR con el label `city`; en los demás queda saltado, y GitHub cuenta un job saltado como check pasado.

```yaml
name: revisor
on:
  pull_request:
    types: [opened, synchronize, reopened, labeled]
permissions:
  contents: read
  pull-requests: read
jobs:
  revisor:
    if: contains(github.event.pull_request.labels.*.name, 'city')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: anthropics/claude-code-action@v1
        env:
          GH_TOKEN: ${{ github.token }}
          # Subagentes en primer plano. En segundo plano la sesión cierra su
          # turno al lanzar city:reviewer, la acción se queda con ese primer
          # `result` (run-claude-sdk.ts corta en él) y termina antes de que
          # exista verdict.txt.
          CLAUDE_CODE_DISABLE_BACKGROUND_TASKS: "1"
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          github_token: ${{ github.token }}
          plugin_marketplaces: https://x-access-token:${{ secrets.CITY_AIDD_TOKEN }}@github.com/SensoriaCity/sensoria-plugins.git
          plugins: city@sensoria
          prompt: "/city:review ${{ github.event.pull_request.number }}"
          claude_args: '--max-turns 30 --allowedTools "Bash,Read,Grep,Glob,Write,Agent,Task"'
      - name: Veredicto en el resumen
        if: always() && hashFiles('verdict.md') != ''
        run: cat verdict.md >> "$GITHUB_STEP_SUMMARY"
      - name: Veredicto
        run: grep -q "listo para merge" verdict.txt
```

- `CLAUDE_CODE_OAUTH_TOKEN` sale de `claude setup-token`; `CITY_AIDD_TOKEN` es un token de solo lectura de `SensoriaCity/sensoria-plugins` (el secreto conserva el nombre de cuando el repo se llamaba `city-aidd`). Ninguno da acceso a un entorno.
- El job no recibe el cuerpo ni los comentarios del PR: la skill lee solo rama, base y título, y el revisor recibe una línea. El revisor lee el cuerpo por su cuenta (`gh pr view --json title,body`) solo para comprobar su forma. Con `Veredicto: espera decisión`, `verdict.txt` no dice `listo para merge` y el check queda en rojo hasta que la persona decida.
- Si falta `verdict.txt` (la sesión se cortó, llegó a `--max-turns` o dejó al revisor en segundo plano), el último paso falla y el PR no entra. `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` evita lo último: `claude-code-action` termina en el primer `result` de la sesión, y con el revisor en segundo plano ese `result` llega antes que su respuesta.
- Las pruebas que corre el revisor necesitan las dependencias del repo en el runner; si no están, las reporta como "no corrido". `--allowedTools` en `claude_args` les da a la skill y al revisor las herramientas que usan sin pedir permiso en CI; la skill además las acota en su `allowed-tools`.

## Las cuatro capas que sostienen el auto-merge

1. **Sandbox de Claude Code.** Sistema de archivos: el worktree. Red: `github.com` y el registro de imágenes del repo. Sin registries de paquetes, instalar una dependencia es imposible por construcción; el agente la pide en un PR que CODEOWNERS retiene. Lo que era `ask` sobre archivos de política pasa a `deny`, porque en auto mode `ask` no pregunta.
2. **Ruleset en `main`.** Checks requeridos: CI del repo, `revisor` y `evidencia`. Historial lineal, squash, sin push directo. CODEOWNERS con el TL de la app en `.claude/**`, `.github/**`, manifiestos, lockfiles, ADR y el núcleo compartido (`Shared/` en city, `app/Domain/Core` en city-v2). GitHub no le pide al autor la revisión de sus propias rutas: si el PR sale con el token del dueño, CODEOWNERS no lo retiene. Por eso ni `ship` ni `goal.sh` activan el auto-merge en un PR que toca una ruta con dueño, de `codeowners_paths` o del archivo de dueños.
3. **Token acotado.** `gh` por sesión: push a las ramas de `branches` y a las Conventional que acepta `ship` (`docs/` para las specs), crear PR y habilitar auto-merge. Sin merge, sin admin, sin secretos. El despliegue lo hace CI en cada tag; ninguna credencial de un entorno entra a una sesión.
4. **Flags.** Lo incompleto para el usuario va tras flag, y el flag lo enciende una persona después de `/city:check`.

Límites conocidos: el clasificador de auto mode deja pasar un 17% de acciones peligrosas (dato de Anthropic) y el CLI de Docker habla con el daemon fuera del sandbox. Por eso el alcance es el repo y los entornos de prueba, nunca una instancia municipal.

## Varias personas, varias tareas, varias apps

- Una spec = un hito = una persona de punta a punta. Sus cortes son secuenciales (c2 arranca con c1 en `main`); distintas specs y apps corren en paralelo sin tocarse.
- **No se apila.** Un corte se construye cuando sus `depends_on` ya están en la rama principal; con `git.merge: manual`, se espera el merge de la persona y mientras tanto se construye un corte que no dependa de él. Montar un corte sobre la rama de otro sale caro: `size.sh` sin base cuenta los dos y manda partir, build y ship comparan contra `origin/main`, el squash del PR de abajo deja en conflicto al de arriba y su evidencia se vence. La excepción, **apilado**, solo si una persona lo pide: la rama sale de la del corte base; el PR va contra esa rama, con la sección "Apilado sobre #N"; todos los scripts reciben la base (`size.sh <base>`, `passes.sh <id> --base <ref>`); el evaluador no lo evalúa hasta que su base esté mezclada y la rama haya tomado la principal; y al resolver el conflicto del squash se conserva la versión de la rama de arriba y se comprueba que el diff contra la principal sea solo el corte. El detalle está en `plugins/city/skills/spec/slices.md`.
- Un corte que ya está en `main` y no puede llegar a producción sin otro lo dice con `ships_with`: se mezclan juntos o no se despliega entre uno y otro. El kit no despliega; `/city:ship` y `/city:check` lo listan para quien libera.
- El reclamo de un corte es su PR abierto: `/city:build` no sigue si otra persona ya tiene un PR con ese id.
- Un corte que toca un contrato compartido lleva ADR y lo retiene CODEOWNERS de otra squad: es el único punto donde una persona lee código de otra por obligación.
- Cuándo parar es igual para todos: necesita ADR, dos bloqueos del revisor en el mismo PR, dos pasadas del evaluador sin `pasa`, o una corrección que falla dos veces seguidas.

## Control humano, en tres lugares

1. **`/city:check`** al cerrar una funcionalidad, el día o la semana: 10 minutos con el reporte armado. Los PR retenidos por CODEOWNERS son los únicos diffs que se leen.
2. **La feature completa** antes del flag: QA humano la prueba en Tareas v2, con el entorno donde se va a probar.
3. **La retro** de cada viernes: números de `scripts/numeros.py`, la entrada de `bitacora.md` y una pieza del kit a quitar o ajustar.

Nadie lee cada PR. Quien quiera leer uno, puede; no es la compuerta.

## Seguimiento

- **Por feature.** La spec es un hito en Hitos v2; `passes` en el archivo de cada corte muestra cuáles ya pasaron, con su evidencia en `evidence/` del hito.
- **Por squad.** Cada corte es una tarea en Tareas v2 ligada al hito, con su PR.
- **Por sesión.** Una sesión por funcionalidad, sin archivo de progreso: el estado queda en git (rama, commits, PR y evidencia). Si una sesión se corta, `/city:build` con el mismo id retoma la rama.

## Qué no trae, a propósito

- Personas de agente (analyst, pm, architect, sm, dev, qa). Un agente con la spec y el código a la mano hace ese trabajo con un plan corto.
- PRD, documento de arquitectura por módulo, épicas y `sprint-status`. La spec, el hito y las tareas de Notion cubren eso; la arquitectura se decide con un ADR corto cuando un cambio cruza módulos.
- Contratos por ronda entre generador y evaluador. Anthropic quitó los sprints de su harness al pasar a Opus 4.6 y dejó el evaluador en una pasada al final (ver `fundamentos.md`); aquí pasa una vez por funcionalidad, con máximo 2 vueltas.
- `/city:goal` en un runner de nube: pide su propio ADR y secretos en GitHub. `goal.sh` corre en la máquina de una persona, un id a la vez por bucle y hasta tres bucles, uno por slot del lab (ADR-0035 de `city-v2`).
- Cambios al `CLAUDE.md` del repo. El método vive en el plugin; el repo aporta sus reglas duras y su `.city.json`.

## Decisiones de diseño

- **Plugin y no archivos copiados en cada repo.** Las skills quedan con prefijo (`/city:build`) y no chocan con los comandos del repo. El kit se versiona aquí y se actualiza en cada repo con `claude plugin update`.
- **`.city.json` por repo.** Un kit para dos stacks distintos solo funciona si no sabe nada de ninguno. `validate.sh` falla si una skill o agente nombra un comando del stack.
- **El evaluador es otro agente, no la sesión que construyó.** Anthropic reporta que es más fácil calibrar un evaluador escéptico aparte que volver crítico al que genera. Su evidencia es un archivo con formato fijo para que `passes.sh` y `ship` puedan comprobarla sin interpretarla.
- **Instalación local y desechable.** El evaluador prueba en una instalación que `build` levanta desde cero en un clon y baja al terminar, sin esperar un deploy y sin datos de nadie.
- **Revisor sin la prosa del PR.** Al clasificador de auto mode Anthropic le quitó la prosa del asistente para que no lo convenza; el revisor recibe una sola línea por la misma razón, también en CI. El cuerpo del PR lo lee solo para su forma: lo que afirma no cambia un hallazgo.
- **ADR solo para contratos compartidos.** En la muestra de `aidd-metrics` el 17% de los PRs toca dos o más módulos y el 12% solo código compartido. Ahí una spec de una página no alcanza para decidir cómo cambia algo que usan otras apps.
- **400 líneas.** Es el objetivo de la acción P-07 del programa de medición. El kit lo controla, así que no se usa como criterio de éxito.
- **PR directo a `main`.** Elimina la espera de integración en la rama de hito (P-20) y el tramo `hito → main` donde casi nadie revisa.

## Cómo evoluciona el kit

Cada pieza del kit es un supuesto sobre algo que el modelo no hace solo, y esos supuestos caducan cuando cambia el modelo. Por eso:

- durante la adopción entra máximo un cambio de comportamiento al kit por semana, con versión en `plugin.json` y línea en `CHANGELOG.md`, para poder atribuir efectos en las métricas;
- cada retro prueba quitar o ajustar una pieza a la vez y lo mide;
- una skill o regla nueva entra solo cuando `bitacora.md` muestra el mismo tropiezo dos veces.
