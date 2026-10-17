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
| PO | Participa en la spec o valida sus pasos cuando es una feature de usuario. Decide cuándo se enciende el flag. |
| QA | No prueba cortes: eso lo hace el `evaluador`. Prueba la feature completa antes del flag, y lo que encuentra se vuelve paso o prueba. |
| Diseño | Deja el enlace de Figma en la spec cuando hay UI nueva. |

## Reglas

1. **Spec de una página = hito.** La escribe `/city:spec`: cabe en una página y es un hito en Hitos v2. Sus cortes son funcionalidades de la carpeta `features` de `.city.json`, un archivo `<id>.json` por corte para que dos specs escritas a la vez no choquen, cada una con pasos verificables y `passes: false`, y entran a `main` en un PR propio antes del primer corte. Un cambio que cabe en una frase no lleva spec.
2. **Cortes verticales de ≤400 líneas.** Un corte es un vertical slice: un comportamiento que una persona, la API o el CLI pueden observar de punta a punta, que el evaluador prueba solo, con 2 a 5 pasos, en un PR a `main` de máximo `tope_lineas` (400). Se planea con una estimación de máximo el 75 % del tope. Un corte es una funcionalidad: no hay entregas dentro de un id. Una funcionalidad que no es un corte se reemplaza con `/city:spec partir <id>`, que la deja con `reemplazada_por` y agrega los cortes. No se corta por capas y no hay ramas de hito ni PR apilados. Las reglas y la calibración están en `plugins/city/skills/spec/cortes.md`; `/city:spec` las aplica al partir y `/city:build` las vuelve a aplicar en su compuerta, antes de escribir código. El tamaño real se mide solo con `scripts/tamano.sh`, sin lockfiles, `vendor/` ni la evidencia.
3. **Lo incompleto va tras flag,** no en una rama larga. Un merge a `main` no despliega, pero la versión siguiente lo llevaría.
4. **Prueba primero.** Cada paso tiene una prueba que falla sin el cambio, escrita antes de implementar. "Listo" es la salida de las pruebas a la vista, no una afirmación.
5. **Quien construye no se califica.** El `revisor` lee el diff en contexto limpio; el `evaluador` prueba como usuario sobre una instalación limpia. Ninguno recibe el resumen de quien construyó, la descripción del PR ni sus comentarios.
6. **El evaluador es el único dueño de `passes`.** `passes` cambia solo con `scripts/passes.sh`, que exige `<evidencia_dir>/<id>.md` con el encabezado de ese id y la última línea `VEREDICTO: pasa`. Nadie lo cambia a mano.
7. **Merge por checks.** El PR entra solo, por squash, cuando pasan los checks requeridos: el CI del repo, el `revisor` y la `evidencia`. Si toca un patrón de `codeowners_paths`, lo retiene CODEOWNERS hasta que lo apruebe una persona.
8. **ADR por regla, no por criterio.** Hace falta si el diff toca `adr_dir`, un patrón de `codeowners_paths` o una interfaz, esquema o API que usa otro módulo o app. El corte 1 lleva solo el contrato, el ADR (≤30 líneas) y sus pruebas; lo retiene CODEOWNERS de otra squad. Un ADR en `main` está aceptado.
9. **Firma.** Rama `<ramas>AAAA-MM-DD-<id>` y el `label` de `.city.json` (`city`). Sin eso el flujo no se puede medir.
10. **Hotfix por su flujo.** Los arreglos a producción van por `hotfix/`, nunca por la rama de `city`, o el change failure rate queda subcontado.
11. **Las dependencias las instala una persona.** El hook `dependency-guard` rechaza lo que cambia manifiestos o lockfiles, y CODEOWNERS retiene el PR que los toca.

## Comandos

| Comando | Quién | Entrada | Qué deja |
|---|---|---|---|
| `/city:spec` | Cualquiera, con el PO si es una feature de usuario | objetivo en una frase, documento o URL del hito; o `partir <id>` | Rama `docs/AAAA-MM-DD-spec-<tema>` con la spec en `specs_dir` y un archivo por corte en `features`, cada uno con `spec` y `passes: false`. Revisa cada corte contra `cortes.md` antes de escribirlo. El PR lo abre `/city:ship`. |
| `/city:build` | Cualquiera | id de funcionalidad, y el plan del día si lo hay | Rama `<ramas>AAAA-MM-DD-<id>`: compuerta de corte (para con `Bloqueo` si la funcionalidad no es un vertical slice que cabe), prueba primero, implementación, tamaño, ADR, veredictos del `revisor` (y de `seguridad` si aplica) y del `evaluador`. Guarda la evidencia y, si pasa, corre `passes.sh`. |
| `/city:ship` | Cualquiera | nada | PR a `main` con la plantilla del repo, el `label` y `gh pr merge --auto --squash`. Si CODEOWNERS retiene, dice qué archivos y a quién. |
| `/city:check` | Quien libera | `<id>`, `hoy` o `semana` | Reporte de solo lectura de 10 minutos: mergeados y versiones, `passes` con evidencia, retenidos, PR en rojo, ADR pendientes, smoke y qué clickear. |
| `/city:revisar` | CI, o cualquiera a mano | número de PR | Delega al `revisor` con `id · rama · base` (id `ninguna` si la rama y el título no lo traen) y deja su respuesta en `veredicto.md` y el veredicto en `veredicto.txt`. Es la única skill que puede invocar el modelo, porque corre sin persona. |
| `/city:goal` | Cualquiera, en una terminal | ids en orden, y `--plan`, `--max-sesiones`, `--max-bloqueos`, `--quiet` | Da la línea para `scripts/goal.sh`, que corre sin persona y un id a la vez: worktree desde `origin/main`, `claude -p` con `/city:build` y `/city:ship` en auto mode, espera checks y merge, un reintento si un check falla. Para todo con `necesita ADR` o `Bloqueo` en build, dos ids seguidos sin merge, el tope de sesiones (12), Docker apagado o `claude` sin sesión (`Not logged in`), que también se prueba antes del primer worktree. Muestra en la terminal una línea por herramienta de cada sesión y una línea de estado (`--quiet` las apaga). Deja el log en `${TMPDIR:-/tmp}/city-goal/` y el resumen `goal.md` por stdout; el cierre es `/city:check`. |

Diseñados y todavía sin construir, en este orden: `/city:retro` (números y una pieza menos) y `/city:adr`. Hasta entonces, la retro y los ADR se hacen con lo que tenga el repo.

## Agentes

- **`revisor`.** Contexto limpio, sin edición. Recibe `<id> · <rama> · <base>`. Lee el diff completo, corre las pruebas de `tests`, aplica las reglas duras del `CLAUDE.md` del repo, el checklist de seguridad (`seguridad_checklist`) y los chequeos del stack (`revisor_extra`). Hallazgos `bloquea`, `debería` o `sugerencia`; termina en `Veredicto: listo para merge` o `Veredicto: no mergear`. Con id `ninguna` revisa solo reglas duras, seguridad, título y dependencias, y el veredicto sale de esos hallazgos. Máximo dos vueltas; a la tercera, el PR nace bloqueado y lo decide una persona. Corre dentro de `/city:build` y como check de CI con `/city:revisar` (ver "En CI").
- **`seguridad`.** Solo cuando el diff toca autenticación, permisos, archivos, integraciones o el CLI, y solo sobre los archivos que le pasan. Mismo veredicto que el revisor.
- **`evaluador`.** Contexto limpio, sin edición, sin `browser_evaluate` ni `browser_run_code_unsafe`. Recibe el id, la URL de una instalación local limpia (`entorno-qa.py` lo confirma) y la ruta del clon donde corre. Ejecuta cada paso como un usuario: UI con Playwright, API con curl, infra con bash y `qa.smoke`; una cláusula "con su prueba en <grupo o suite>" la verifica corriendo esa prueba en el clon (con `tests.postgres` si necesita base desechable), nunca leyendo CI. Umbral duro: un paso que no cumple o no se pudo verificar, no pasa. Lo que ve fuera de la funcionalidad va en "Fuera de alcance" y no cambia el veredicto. Solo con `instalacion: desechable` ejecuta pasos que borran o alteran filas; nunca reinicia la base ni borra volúmenes. Calibrado con ejemplos de "esto no pasa", porque un evaluador sin calibrar se convence de que un problema no es grave.

## `.city.json`

El contrato entre el kit y cada repo está en `plugins/city/city.schema.json`; el de city-v2 sirve de ejemplo en `docs/ejemplos/city-v2.city.json`. De ahí salen los comandos de prueba (`tests`), la instalación del evaluador (`qa`), `features`, `specs_dir`, `evidencia_dir`, `adr_dir`, `ramas`, `label`, `codeowners_paths`, `tope_lineas` y, si el repo no sigue los valores por omisión, sus convenciones de commits, merge y versión (`git`). Lo propio de cada máquina (puertos, versiones, cómo bajar una instalación) va en `docs/harness/entorno.md` del repo.

## En CI

El check `revisor` del ruleset es este job. Corre `/city:revisar` sobre el PR con el plugin de `main` de este repo y falla si el veredicto no es `listo para merge`. Solo corre en los PR con el label `city`; en los demás queda saltado, y GitHub cuenta un job saltado como check pasado.

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
          # turno al lanzar city:revisor, la acción se queda con ese primer
          # `result` (run-claude-sdk.ts corta en él) y termina antes de que
          # exista veredicto.txt.
          CLAUDE_CODE_DISABLE_BACKGROUND_TASKS: "1"
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          github_token: ${{ github.token }}
          plugin_marketplaces: https://x-access-token:${{ secrets.CITY_AIDD_TOKEN }}@github.com/SensoriaCity/sensoria-plugins.git
          plugins: city@sensoria
          prompt: "/city:revisar ${{ github.event.pull_request.number }}"
          claude_args: '--max-turns 30 --allowedTools "Bash,Read,Grep,Glob,Write,Agent,Task"'
      - name: Veredicto en el resumen
        if: always() && hashFiles('veredicto.md') != ''
        run: cat veredicto.md >> "$GITHUB_STEP_SUMMARY"
      - name: Veredicto
        run: grep -q "listo para merge" veredicto.txt
```

- `CLAUDE_CODE_OAUTH_TOKEN` sale de `claude setup-token`; `CITY_AIDD_TOKEN` es un token de solo lectura de `SensoriaCity/sensoria-plugins` (el secreto conserva el nombre de cuando el repo se llamaba `city-aidd`). Ninguno da acceso a un entorno.
- El job no recibe el cuerpo ni los comentarios del PR: la skill lee solo rama, base y título, y el revisor recibe una línea.
- Si falta `veredicto.txt` (la sesión se cortó, llegó a `--max-turns` o dejó al revisor en segundo plano), el último paso falla y el PR no entra. `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` evita lo último: `claude-code-action` termina en el primer `result` de la sesión, y con el revisor en segundo plano ese `result` llega antes que su respuesta.
- Las pruebas que corre el revisor necesitan las dependencias del repo en el runner; si no están, las reporta como "no corrido". `--allowedTools` en `claude_args` les da a la skill y al revisor las herramientas que usan sin pedir permiso en CI; la skill además las acota en su `allowed-tools`.

## Las cuatro capas que sostienen el auto-merge

1. **Sandbox de Claude Code.** Sistema de archivos: el worktree. Red: `github.com` y el registro de imágenes del repo. Sin registries de paquetes, instalar una dependencia es imposible por construcción; el agente la pide en un PR que CODEOWNERS retiene. Lo que era `ask` sobre archivos de política pasa a `deny`, porque en auto mode `ask` no pregunta.
2. **Ruleset en `main`.** Checks requeridos: CI del repo, `revisor` y `evidencia`. Historial lineal, squash, sin push directo. CODEOWNERS con el TL de la app en `.claude/**`, `.github/**`, manifiestos, lockfiles, ADR y el núcleo compartido (`Shared/` en city, `app/Domain/Core` en city-v2).
3. **Token acotado.** `gh` por sesión: push a las ramas de `ramas` y a las Conventional que acepta `ship` (`docs/` para las specs), crear PR y habilitar auto-merge. Sin merge, sin admin, sin secretos. El despliegue lo hace CI en cada tag; ninguna credencial de un entorno entra a una sesión.
4. **Flags.** Lo incompleto para el usuario va tras flag, y el flag lo enciende una persona después de `/city:check`.

Límites conocidos: el clasificador de auto mode deja pasar un 17% de acciones peligrosas (dato de Anthropic) y el CLI de Docker habla con el daemon fuera del sandbox. Por eso el alcance es el repo y los entornos de prueba, nunca una instancia municipal.

## Varias personas, varias tareas, varias apps

- Una spec = un hito = una persona de punta a punta. Sus cortes son secuenciales (c2 arranca con c1 en `main`); distintas specs y apps corren en paralelo sin tocarse.
- El reclamo de un corte es su PR abierto: `/city:build` no sigue si otra persona ya tiene un PR con ese id.
- Un corte que toca un contrato compartido lleva ADR y lo retiene CODEOWNERS de otra squad: es el único punto donde una persona lee código de otra por obligación.
- Cuándo parar es igual para todos: necesita ADR, dos bloqueos del revisor en el mismo PR, dos pasadas del evaluador sin `pasa`, o una corrección que falla dos veces seguidas.

## Control humano, en tres lugares

1. **`/city:check`** al cerrar una funcionalidad, el día o la semana: 10 minutos con el reporte armado. Los PR retenidos por CODEOWNERS son los únicos diffs que se leen.
2. **La feature completa** antes del flag: QA humano la prueba en Tareas v2, con el entorno donde se va a probar.
3. **La retro** de cada viernes: números de `scripts/numeros.py`, la entrada de `bitacora.md` y una pieza del kit a quitar o ajustar.

Nadie lee cada PR. Quien quiera leer uno, puede; no es la compuerta.

## Seguimiento

- **Por feature.** La spec es un hito en Hitos v2; `passes` en `features` muestra qué funcionalidades ya pasaron, con su evidencia en `evidencia_dir`.
- **Por squad.** Cada corte es una tarea en Tareas v2 ligada al hito, con su PR.
- **Por sesión.** Una sesión por funcionalidad, sin archivo de progreso: el estado queda en git (rama, commits, PR y evidencia). Si una sesión se corta, `/city:build` con el mismo id retoma la rama.

## Qué no trae, a propósito

- Personas de agente (analyst, pm, architect, sm, dev, qa). Un agente con la spec y el código a la mano hace ese trabajo con un plan corto.
- PRD, documento de arquitectura por módulo, épicas y `sprint-status`. La spec, el hito y las tareas de Notion cubren eso; la arquitectura se decide con un ADR corto cuando un cambio cruza módulos.
- Contratos por ronda entre generador y evaluador. Anthropic quitó los sprints de su harness al pasar a Opus 4.6 y dejó el evaluador en una pasada al final (ver `fundamentos.md`); aquí pasa una vez por funcionalidad, con máximo 2 vueltas.
- `/city:goal` en un runner de nube: pide su propio ADR y secretos en GitHub. `goal.sh` corre en la máquina de una persona, un id a la vez, porque en la máquina cabe una sola instalación.
- Cambios al `CLAUDE.md` del repo. El método vive en el plugin; el repo aporta sus reglas duras y su `.city.json`.

## Decisiones de diseño

- **Plugin y no archivos copiados en cada repo.** Las skills quedan con prefijo (`/city:build`) y no chocan con los comandos del repo. El kit se versiona aquí y se actualiza en cada repo con `claude plugin update`.
- **`.city.json` por repo.** Un kit para dos stacks distintos solo funciona si no sabe nada de ninguno. `validar.sh` falla si una skill o agente nombra un comando del stack.
- **El evaluador es otro agente, no la sesión que construyó.** Anthropic reporta que es más fácil calibrar un evaluador escéptico aparte que volver crítico al que genera. Su evidencia es un archivo con formato fijo para que `passes.sh` y `ship` puedan comprobarla sin interpretarla.
- **Instalación local y desechable.** El evaluador prueba en una instalación que `build` levanta desde cero en un clon y baja al terminar, sin esperar un deploy y sin datos de nadie.
- **Revisor sin la prosa del PR.** Al clasificador de auto mode Anthropic le quitó la prosa del asistente para que no lo convenza; el revisor recibe una sola línea por la misma razón, también en CI.
- **ADR solo para contratos compartidos.** En la muestra de `aidd-metrics` el 17% de los PRs toca dos o más módulos y el 12% solo código compartido. Ahí una spec de una página no alcanza para decidir cómo cambia algo que usan otras apps.
- **400 líneas.** Es el objetivo de la acción P-07 del programa de medición. El kit lo controla, así que no se usa como criterio de éxito.
- **PR directo a `main`.** Elimina la espera de integración en la rama de hito (P-20) y el tramo `hito → main` donde casi nadie revisa.

## Cómo evoluciona el kit

Cada pieza del kit es un supuesto sobre algo que el modelo no hace solo, y esos supuestos caducan cuando cambia el modelo. Por eso:

- durante la adopción entra máximo un cambio de comportamiento al kit por semana, con versión en `plugin.json` y línea en `CHANGELOG.md`, para poder atribuir efectos en las métricas;
- cada retro prueba quitar o ajustar una pieza a la vez y lo mide;
- una skill o regla nueva entra solo cuando `bitacora.md` muestra el mismo tropiezo dos veces.
