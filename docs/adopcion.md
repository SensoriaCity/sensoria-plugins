# Adopción de city

No hay piloto comparativo: el método se adopta app por app. Primero `city-v2`, donde nace el kit, y después `city`, una squad por semana. Mientras una squad de `city` no adopta, sigue en BMAD sin cambios (ver `coexistencia-bmad.md`). La decisión de volverlo el flujo por defecto de todo `city` necesita 12 semanas de datos, que es la ventana de curva J que usa `aidd-metrics`.

- **Inicio (semana 1):** `<AAAA-MM-DD>`
- **Versión del kit al arrancar:** 1.1.0

## Calendario

| Semana | Repo y squad | Qué |
|---|---|---|
| 1 | `city-v2` | `.city.json`, ruleset, CODEOWNERS, job `revisor` de CI y sandbox con `deny`. Todo trabajo nuevo entra por `/city:build` y `/city:ship`. |
| 2 | `city-v2` | Primera retro con números. `/city:check` al cerrar cada hito. |
| 3 | `city`, squad 1 | `.city.json` de `city` (Filament), `docs/harness/entorno.md` y la preparación de abajo. Kickoff de 45 minutos. |
| 4 en adelante | `city`, una squad más por semana | La squad entra si la anterior cumple los guardarraíles de su última semana. Un cambio al kit por semana. |

## Cómo elegir la siguiente squad de `city`

- Una squad que quiera hacerlo. Sin eso se mide resistencia, no el método.
- Sin un hito BMAD grande a medias. Si lo hay, se termina en BMAD.
- Al menos una de las primeras tres lleva una feature que cambie un contrato compartido, de `Shared` o de dos módulos. Sin eso no sabemos si el método aguanta cambios de plataforma.

## Preparación de cada repo, una vez

1. **Instalar el plugin** para todo el repo, desde su clon:
   ```bash
   claude plugin marketplace add SensoriaCity/sensoria-plugins --scope project
   claude plugin install city@sensoria --scope project
   ```
   Escribe la configuración en `.claude/settings.json` del repo, que retiene CODEOWNERS. En una sesión, `/city:` debe mostrar `spec`, `build`, `ship`, `check` y `goal`, y `/mcp` el servidor `plugin:city:playwright`.
2. **`.city.json`** en la raíz, contra `plugins/city/city.schema.json`. `features` es una carpeta, con un archivo `<id>.json` por funcionalidad; la crea la primera spec. Su `qa` levanta una instalación local limpia; sin ella no hay evaluador y sin evaluador no hay `passes`. Si las specs no van en `docs/specs`, `specs_dir` dice dónde. Si el repo no escribe sus commits en Conventional Commits, no usa auto-merge o no versiona con tags, `git` lo dice (`plugins/city/skills/ship/git.md`).
3. **`docs/harness/entorno.md`** con lo propio de la máquina: puertos, versiones y cómo bajar una instalación. Si el repo va a tener cortes de clase `data`, también el comando que imprime el motor y la base activa (nadie lee `.env`) y cuál es la base de desarrollo, que no se toca.
4. **Labels:** `gh label create city --description "Flujo city" --repo SensoriaCity/<repo>` y `gh label create adr --description "Trae un ADR" --repo SensoriaCity/<repo>`. Las de clase (`class:slice`, `class:data`, `class:platform` y `class:spec`) no hay que crearlas a mano: `/city:ship` mira las que existen y crea las que falten con `gh label create`, sin pedir confirmación, antes de abrir el PR; lo mismo con `city` si alguien la borró. El token de `gh` de la sesión necesita permiso para crear etiquetas; si no lo tiene, ship lo dice y se detiene.
5. **Ruleset en `main`** con los checks requeridos (CI del repo, `revisor`, `evidencia`), squash, historial lineal y sin push directo; CODEOWNERS con los patrones de `codeowners_paths`; auto-merge permitido, salvo con `git.merge: manual`.
6. **Job `revisor`** en CI, como dice "En CI" de `metodo.md`, con los secretos `CLAUDE_CODE_OAUTH_TOKEN` y `CITY_AIDD_TOKEN` (lectura de este repo).
7. **Sandbox y `deny`** en `.claude/settings.json`: sistema de archivos en el worktree, red a `github.com` y al registro de imágenes, y `deny` en los archivos de política.
8. **Notion:** cada spec es un hito en Hitos v2 y cada corte una tarea en Tareas v2 ligada al hito, con la URL de su PR. Para medir cuánto tarda una tarea de En progreso a Finalizado, las dos automatizaciones de `programa-medicion.md` §10 (`Inicio` y `Fin`).
9. **`aidd-metrics`:** aplicar `integracion-aidd-metrics.md` y registrar el evento de la squad.
10. **Kickoff de 45 minutos** con la squad: leer `metodo.md` juntos y hacer en vivo una spec pequeña con UI, de `/city:spec` a `/city:check`, para que vean cómo se parte en cortes y al evaluador probar.

## Si el repo tenía un plan diario

`/city:spec` reemplaza al plan diario del repo (en city-v2, `/plan-diario`). Lo que hacía se reparte así:

| Lo que hacía el plan diario | Dónde queda |
|---|---|
| Agregar las funcionalidades del hito a `features` | `/city:spec`, partidas en cortes según `slices.md`, en un PR propio |
| "Toca", lo que no decide solo quien construye y las dependencias con su línea de instalación | La sección de cada corte en la spec, que `/city:build` lee |
| Elegir de 1 a 3 funcionalidades para el día | `/city:goal <ids en orden>`, o `/city:build <id>` |
| Revisar CI y tags de `main` y darle destino a los hallazgos | `/city:check` y la retro |
| Lo propio del repo: estado, bitácora, guiones al teclado, rutas de worktree | El `CLAUDE.md` del repo o `docs/harness/entorno.md` |

Para retirarlo, en un PR del repo: borrar la skill del plan diario, cambiar la sección de flujo del `CLAUDE.md` por el ciclo de `metodo.md` y, si las specs no van en `docs/specs`, agregar `specs_dir` a `.city.json`. Los planes ya escritos se quedan como historia y `/city:build <id> <plan>` los sigue leyendo; un plan que parte una funcionalidad en entregas vale hasta que esa funcionalidad cierre. Una funcionalidad grande que quedó a medias, sin plan para lo que falta, se parte con `/city:spec split <id>`.

## Si el repo tenía `features` en un solo archivo

Hasta el kit 1.4.0, `features` era un archivo con una lista. Dos specs escritas a la vez agregaban al final de la misma lista y chocaban siempre; lo mismo una spec y el `passes` de la última funcionalidad. Desde el 2.0.0 es una carpeta con un archivo por funcionalidad. Para pasar un repo, en un solo PR:

1. Partir el archivo, con `viejo` y `nuevo` según el repo:
   ```bash
   viejo=docs/lab/features.json; nuevo=docs/lab/features
   mkdir -p "$nuevo"
   jq -r '.[].id' "$viejo" | while IFS= read -r id; do
     jq --indent 2 --arg id "$id" '.[] | select(.id == $id)' "$viejo" > "$nuevo/$id.json"
   done
   [ "$(ls "$nuevo" | wc -l)" -eq "$(jq length "$viejo")" ] && git rm -q "$viejo" && git add "$nuevo"
   ```
   Si la última línea no borra el archivo viejo, hay ids repetidos: se arreglan antes.
2. Cambiar `features` en `.city.json` por la carpeta.
3. Cambiar el job `evidencia` de CI, que leía la lista: ahora compara el `passes` de cada `<features>/<id>.json` entre la base y el PR.

El orden de la lista se pierde: el de los cortes de una spec lo da el número del id (`-c01`, `-c02`). El PR entra con el repo ya en el kit 2.0.0, y las ramas abiertas que cambiaron el archivo viejo toman después `main` y repiten su cambio: `passes.sh <id>` en una rama de build, los archivos de sus cortes en una de spec.

## Pasar a city 3.0: una spec por hito y revisión humana

Desde el 3.0.0 un hito tiene una sola spec en `<apps_dir>/<aplicativo>/<modulo>/<hito>/` (sin `apps_dir`, `docs/apps`), con sus cortes en `slices/` y la evidencia en `evidence/` de la misma carpeta. `<aplicativo>` es la carpeta del aplicativo dueño del módulo, no `app` de `.city.json` (ese es el nombre del repo); el módulo es `mod-<NN>-<slug>`, el hito `h<NN>-<slug>` y el id de cada corte `m<NN>-h<NN>-s<NN>`, siempre con dos dígitos. `features` y `evidence_dir` siguen valiendo para lo que ya existe: `scripts/slice.sh` busca un id primero en el hito y después en `features`, así que nada se mueve. En un PR del repo:

1. `"apps_dir": "docs/apps"` en `.city.json`. Las specs nuevas van ahí; las viejas se quedan donde están.
2. Si una persona aprueba cada PR, `"git": {"merge": "manual"}`. `/city:goal` deja de negarse: abre cada PR y espera el merge de la persona antes del corte siguiente. Es la fase de entrada: se pasa a auto-merge (se quita `manual`) cuando los checks requeridos del PR son confiables, es decir, corren en unos 10 minutos y `main` está en verde sin fallas conocidas. Desde ahí los PR de clase `slice` entran solos y una persona aprueba solo lo que cae en `codeowners_paths` (migraciones, ADR, plataforma) y los PR de clase `spec`, que nunca van en auto-merge.
3. El job `evidencia` de CI compara también el `passes` de cada `slices/<id>.json` bajo `apps_dir`, con la evidencia que da `slice.sh`. Para exigir además que esa evidencia sea del código vigente, el job corre `passes.sh <id> --check` sobre la cabeza del PR: sale con 1 si el código cambió después de la evaluación.
4. Si el repo usa flags (en city, Pennant con la página Funcionalidades), `docs/harness/entorno.md` dice dónde se declaran y quién los enciende; la escalera de `slices.md` dice cuándo hace falta uno.
5. Etiquetas `class:slice`, `class:data`, `class:platform` y `class:spec`: `/city:ship` le pone a cada PR la de su clase y las crea si no existen. Sirven para filtrar quién aprueba qué.
6. `"flags": "docs/harness/flags.md"` en `.city.json`, con la receta del repo: dónde se declara un flag, cómo se esconde algo detrás de él, cómo se prueba encendido y apagado, quién es su dueño (una persona o un equipo), quién lo enciende y cómo y cuándo se retira. También cómo se detecta "producción": si un flag se va a bloquear por entorno, la receta nombra la señal que distingue producción de los demás ambientes, porque los de revisión pueden correr con la misma configuración. Y recuerda que un flag que guarda datos no se revierte apagándolo: la spec de cada hito dice qué pasa con lo guardado mientras estuvo encendido. En la fecha de retiro manda la receta: si fija una fecha o un plazo, es ese. Si no dice nada, vale el del kit, la fecha del PR de clase `spec` más 60 días, que se ajusta en el PR del último corte. Sin la clave, el escalón 4 no existe en el repo.
7. `"notion": {"milestones": …, "tasks": …}` en `.city.json`. En Notion, una vez: la plantilla del hito pierde la sección "Plan Técnico" (la definición funcional se queda como está); el hito gana `Spec` (URL), `Spec aprobada`, `Definición lista` y `Flag`; la tarea gana `Corte` (el id) y `Clase`. El reparto está en `plugins/city/notion.md`: Notion guarda qué se construye y en qué va, el repo guarda cómo, y nadie copia texto de un lado al otro.
8. Cortes de clase `data`: `"database": "<comando>"` dentro de `tests` en `.city.json`, opcional. Es la receta que corre las pruebas de migración contra el motor real en una base desechable que ella misma levanta y borra, y recibe al final los argumentos del runner. Sin la clave el corte se puede construir igual: lo dice en su reporte y en el PR, y cuenta la evidencia manual del evaluador sobre la base de la instalación de QA. Si la suite general corre en otro motor, la receta del repo dice cómo se omite ahí una prueba de migración. Las reglas están en `plugins/city/skills/build/data-slices.md`.
9. Roles separados: si en la squad construir, revisar y evaluar son sesiones distintas, quien construye termina con `/city:ship draft`. El PR nace en borrador con `**Pendiente:** <quién falta>`; el veredicto del revisor llega por el check `revisor` o como comentario del PR, y el del evaluador como un commit de evidencia en la rama. `/city:ship`, otra vez, lo pasa a listo cuando los dos están vigentes. No hay archivo para la evidencia de quien construye: va en el cuerpo del PR.
10. Dueños de rutas: `codeowners_paths` y el archivo de dueños del repo pueden divergir, y el kit trata como ruta con dueño la unión de los dos. Si el archivo no está en `.github/CODEOWNERS`, `CODEOWNERS` ni `docs/CODEOWNERS`, `"codeowners_file": "<ruta>"` en `.city.json`. `bash plugins/city/scripts/owners.sh --check` (desde el plugin instalado) sale con 1 y lista lo que está en un lado y no en el otro; la guarda de auto-merge de `goal.sh` usa el mismo script, así que retiene lo mismo que `/city:ship`. Los dos lados no dicen lo mismo, y conviene escribirlos con esa idea: `codeowners_paths` son las rutas compartidas (contratos, ADR, plataforma), las que además piden ADR; el archivo de dueños dice quién debe aprobar cada ruta y puede repartir el repo entero por equipo o por panel, sin que eso pida un ADR por cada archivo. `owners.sh --match shared` y `--match owned` dicen cuál de los dos coincide con una ruta. Si el archivo trae la línea `*`, todo archivo tiene dueño y ningún PR queda en auto-merge.
11. Cambiar lo que ya está en `main` tiene tres caminos y ninguno edita un corte con `passes: true`: `/city:spec split <id>`, `/city:spec unblock <id>` y `/city:spec revise <hito>` para la spec, y una rama `<branches>AAAA-MM-DD-<id>-fix` para el código de un corte ya mezclado (`/city:build <id> fix`). Dos cosas del repo cambian con eso. El job `evidencia` de CI toma el id de una rama `-fix` sin el sufijo y corre `passes.sh <id> --check` sobre la cabeza del PR aunque el diff no cambie `passes`: sale con 1 si la rama trae código y la evidencia no se renovó. Y si un guion del repo deduce el id desde la rama, tiene que quitar ese sufijo. En un PR de clase `spec`, el job puede correr además `check-spec.sh <hito> <line_limit> --base origin/main`.
12. El check `revisor` puede terminar en `Veredicto: espera decisión` (un hallazgo `decide`: la spec parte de un supuesto que el código desmiente). El job de "En CI" de `metodo.md` no cambia: `verdict.txt` no dice `listo para merge` y el check queda en rojo hasta que la persona decida, la decisión quede en "Decisiones tomadas" de la spec y el revisor dé otra vuelta. El revisor ahora lee el cuerpo del PR, solo para su forma: el job ya tiene `pull-requests: read`.
13. Evaluar con un navegador compartido: si la sesión del evaluador usa un navegador que ya estaba abierto (otro servidor de navegador, o el de una persona), trabaja en una pestaña propia, no redimensiona la ventana y cierra solo su pestaña; el ancho de 390 px queda como no verificado en la evidencia. Como subagente, `city:evaluator` solo recibe las herramientas de su lista (`tools` de `agents/evaluator.md`), que son las del servidor `playwright` del kit, sin las de redimensionar ni cerrar el navegador: con otro servidor de navegador, el rol lo corre una sesión que tenga las equivalentes, con las mismas reglas (`skills/build/browser.md`). Deja una o más capturas por paso, `<id>-paso<n>[-<detalle>].png`, en la carpeta que diga quien lo llama (`capturas: <carpeta>`) o en el temporal. Un error de consola que también ocurre en la rama principal es ruido del entorno: conviene listar los conocidos en `docs/harness/entorno.md`, para que el evaluador los declare en vez de contarlos.
14. No se apila. Un corte se construye cuando sus `depends_on` ya están en `main`; con `git.merge: manual` eso es esperar el merge de la persona, así que conviene revisar los PR a diario y tener a mano otro corte que no dependa del que espera. `/city:build` se detiene con `Bloqueo` si una dependencia no ha entrado. Si una persona pide apilar de todos modos, la excepción está en `plugins/city/skills/spec/slices.md`: rama desde la del corte base, PR contra esa rama con la sección "Apilado sobre #N", la base en cada script (`size.sh <base>`, `passes.sh <id> --base <ref>`), el evaluador espera a que la base esté mezclada, y al resolver el conflicto del squash se conserva la versión de la rama de arriba. Si el job `evidencia` de CI corre `passes.sh <id> --check` en un PR cuya base no es `main`, le pasa `--base origin/<base del PR>`.
15. Vigencia y evidencia vencida. Sobre `main`, `passes.sh <id> --check` da por vigente la evidencia que entró con el merge del corte, aunque cortes posteriores toquen sus archivos: un guion del repo que recorra todos los cortes de `main` ya no encuentra falsos vencidos. `passes.sh <id> --reset` ahora también escribe en la evidencia: le agrega al final `VENCIDA: evaluó <commit>; el código cambió en <commit>`. Si el job `evidencia` busca `VEREDICTO: pasa` por su cuenta, que rechace además una evidencia con una línea `VENCIDA:` (o que llame a `passes.sh <id> --check`, que ya lo hace). El commit de un reset lleva su propio asunto (`skills/ship/git.md`), no el de guardar evidencia.
16. Romper a propósito. Para ver fallar una prueba de regresión, quien construye rompe el comportamiento en su rama, sin commit, y pega la salida de la prueba fallando en el PR. El evaluador no arma copias del repo ni toca las carpetas de dependencias. Si el repo tiene un comando que lo hace sin dejar rastro, va en `"mutation": "<comando>"` dentro de `tests` (opcional) o en `docs/harness/entorno.md`, y el evaluador lo repite; sin él, lo declara como no hecho.
17. Revisor y árbol de trabajo. Cuando revisa una rama que no es la actual, el revisor corre las pruebas en un árbol aparte, donde no hay dependencias instaladas y todo queda "no corrido". Si el árbol de trabajo está limpio y nadie más lo usa, quien lo llama agrega ` · arbol: libre` a su línea y el revisor lo pasa a la rama con `git checkout --detach`, corre ahí y lo devuelve; `/city:review` lo agrega sola en CI. En Windows con Git Bash: `MSYS_NO_PATHCONV=1` cambia dónde se crea el árbol temporal, y `git show <rama>:<ruta>` falla, así que el revisor lee por el sha.
18. Orden de despliegue. Si un corte ya mezclado no puede llegar a producción sin otro, su archivo lleva `"ships_with": [<id>]`. `check-spec.sh` lo valida, la plantilla del PR lo muestra y `/city:ship` y `/city:check` dicen "no desplegar hasta que entre <id>". Si el repo despliega solo en cada merge o en cada tag, quien libera tiene que leer esa línea antes: el kit no detiene un despliegue.
19. `/city:goal` y las decisiones. Si el revisor termina en `espera decisión`, el bucle no lo trata como un check en rojo: no reintenta, se detiene y `goal.md` dice quién decide. Cuando la persona decide, la decisión entra a la spec y el corte se retoma a mano en su worktree.
20. En Windows, `check-spec.sh --base` llama a git con `core.longpaths=true` y, si git no puede leer un corte de la base, sale con 2 y lo dice, en vez de reportar una falla por cada corte. Si el repo tiene rutas largas, conviene además `git config core.longpaths true` en el clon.

Ningún hito BMAD vivo se mueve: termina en BMAD. El primero que entra por 3.0 es uno nuevo, empezando por su PR de clase `spec`.

## Nombres en inglés: migrar `.city.json` y los cortes

Desde el 3.0.0 todo lo estructural del kit va en inglés (archivos, claves, valores enumerados, etiquetas, scripts, skills y agentes); el texto para personas sigue en español.

**`.city.json`: no hay que tocarlo el mismo día.** Los scripts y las skills leen la clave nueva y, si falta, la vieja; el schema acepta las viejas marcadas como obsoletas. Conviene pasarlo en un PR propio (cae en `codeowners_paths`):

| Clave de city 2.x | Clave de city 3.0 |
|---|---|
| `tope_lineas` | `line_limit` |
| `evidencia_dir` | `evidence_dir` |
| `ramas` | `branches` |
| `revisor_extra` | `reviewer_extra` |
| `seguridad_checklist` | `security_checklist` |
| `tests.navegador` | `tests.browser` |
| `tests.estatico` | `tests.static` |
| `qa.instalar` | `qa.install` |
| `qa.bajar` | `qa.teardown` |
| `qa.puerto` | `qa.port` |
| `qa.usuario` | `qa.user` |
| `qa.usuario_stdin`, con `correo`, `nombre`, `contraseña` | `qa.user_stdin`, con `email`, `name`, `password` |
| `git.version: asunto` | `git.version: subject` |
| `notion.hitos` | `notion.milestones` |
| `notion.tareas` | `notion.tasks` |

No cambian `app`, `tests.unit`, `tests.lint`, `tests.audit`, `tests.postgres`, `qa.url`, `qa.smoke`, `features`, `apps_dir`, `specs_dir`, `adr_dir`, `label`, `codeowners_paths`, `flags`, `git.commits` ni `git.merge` (`manual` sigue siendo `manual`). Con jq, de una vez:

```bash
jq --indent 2 '
  def ren(a; b): if has(a) then .[b] = .[a] | del(.[a]) else . end;
  ren("tope_lineas"; "line_limit") | ren("evidencia_dir"; "evidence_dir") | ren("ramas"; "branches")
  | ren("revisor_extra"; "reviewer_extra") | ren("seguridad_checklist"; "security_checklist")
  | .tests |= (ren("navegador"; "browser") | ren("estatico"; "static"))
  | .qa |= (ren("instalar"; "install") | ren("bajar"; "teardown") | ren("puerto"; "port") | ren("usuario"; "user") | ren("usuario_stdin"; "user_stdin"))
  | if .qa.user_stdin then .qa.user_stdin |= map({correo: "email", nombre: "name", "contraseña": "password"}[.] // .) else . end
  | if .git.version == "asunto" then .git.version = "subject" else . end
  | if .notion then .notion |= (ren("hitos"; "milestones") | ren("tareas"; "tasks")) else . end
' .city.json > .city.json.nuevo && mv .city.json.nuevo .city.json
```

jq deja las claves renombradas al final de su objeto; el orden no importa.

**Lo que sí hay que cambiar al actualizar el kit,** porque no tiene compatibilidad:

| Antes | Ahora | Dónde se nota en el repo |
|---|---|---|
| `/city:revisar` | `/city:review` | El `prompt` del job `revisor` de CI |
| `veredicto.md`, `veredicto.txt` | `verdict.md`, `verdict.txt` | Los dos últimos pasos del job `revisor` |
| Agentes `city:revisor`, `city:evaluador`, `city:seguridad` | `city:reviewer`, `city:evaluator`, `city:security` | Permisos o `allow` de `.claude/settings.json` que los nombren |
| `scripts/corte.sh`, con `archivo=`, `hito=`, `spec=`, `evidencia=` | `scripts/slice.sh`, con `file=`, `milestone=`, `spec=`, `evidence=` | El job `evidencia` de CI |
| `scripts/tamano.sh`, `scripts/entorno-qa.py`, `skills/spec/comprueba.sh` | `scripts/size.sh`, `scripts/qa-env.py`, `skills/spec/check-spec.sh` | Jobs de CI o guiones que los llamen |
| `qa.py puerto` | `qa.py port` (`puerto` sigue valiendo) | Guiones del lab |
| `GOAL_INTERVALO`, `GOAL_ESPERA_MAX`, `GOAL_ESPERA_HUMANA` | `GOAL_INTERVAL`, `GOAL_MAX_WAIT`, `GOAL_HUMAN_WAIT` | Quien lance `goal.sh` con otros tiempos |
| `/city:spec partir <id>`, `/city:spec desbloquear <id>`, `/city:discovery modulo <URL>` | `/city:spec split <id>`, `/city:spec unblock <id>`, `/city:discovery module <URL>` | Lo que teclea la persona; guiones o docs del repo que los nombren |
| `goal.sh --max-sesiones`, `--max-bloqueos` | `--max-sessions`, `--max-blocks` (las anteriores siguen valiendo) | Quien lance `goal.sh` con otros topes |
| Etiquetas `clase:Corte`, `clase:Datos`, `clase:Plataforma`, `clase:Spec` | `class:slice`, `class:data`, `class:platform`, `class:spec` | Filtros y reglas que las usen; ship crea las nuevas |

Los checks de CI `revisor`, `evidencia` y `evaluador` conservan su nombre: son del ruleset de cada repo, no del kit.

**Los cortes de un hito ya escrito con el 3.0 en español** (el piloto) se pasan en un solo PR `chore/`, que aprueba una persona. El check `revisor` lo va a marcar, porque edita y renombra archivos de corte: es la única vez que eso se hace en `main`.

1. Carpetas: `git mv <hito>/cortes <hito>/slices` y `git mv <hito>/evidencia <hito>/evidence`. Si el módulo o el hito no siguen `mod-<NN>-<slug>` y `h<NN>-<slug>` con dos dígitos (`h1-…` pasa a `h01-…`), se renombran también.
2. Ids: de `<hito>-cNN` a `m<NN>-h<NN>-s<NN>`. Cambia el nombre del archivo, su `id`, los `depends_on` y `replaced_by` que lo nombran, el archivo de su evidencia y el encabezado `# Evidencia · <id> · …` de esa evidencia (`passes.sh` y el job `evidencia` lo comparan con el id).
3. Claves y valores de cada corte, y después una pasada a mano por `blocked_by`, que ahora es una lista de `{question, owner, blocks_since}`:
   ```bash
   jq --indent 2 '{
     id, class: {Corte: "slice", Datos: "data", Plataforma: "platform"}[.clase],
     description: .descripcion, covers: .cubre,
     steps: [.pasos[] | {do: .hace, expect: .debe_ver}],
     depends_on: .depende_de, rung: .escalon, estimated_lines: .estimacion_lineas, spec, passes
   } + (if .reemplazada_por then {replaced_by: .reemplazada_por} else {} end)
     + (if .bloqueado_por then {blocked_by: [{question: (.bloqueado_por | tostring), owner: "<quién responde>", blocks_since: "<AAAA-MM-DD>"}]} else {} end)
   ' <corte>.json
   ```
4. `bash plugins/city/skills/spec/check-spec.sh <hito> <line_limit>` (desde el plugin instalado) debe salir con 0: rechaza cualquier clave en español que haya quedado.
5. Las tareas de Notion llevan el id en `Corte`: se actualizan con los ids nuevos.

Las funcionalidades de `features` de city 2.x no se tocan: `slice.sh` las sigue encontrando y `passes.sh` las sigue cerrando.

## Cada semana

| Cuándo | Qué | Quién | Duración |
|---|---|---|---|
| Cada viernes | Entrada en `bitacora.md` con los números de la semana y los tropiezos | Alguien de cada squad | 15 min |
| Cada viernes | Retro: números, `/city:check semana` y una pieza del kit a quitar o ajustar | Squads activas + CTO | 30 min |
| Cada viernes | Máximo un cambio de comportamiento al kit, con versión y línea en `CHANGELOG.md` | CTO | |

**Números de la semana.** Mientras el dashboard de `aidd-metrics` no tenga la clasificación por flujo (ING-007), salen de GitHub, desde la raíz del repo medido:

```bash
gh pr list --repo SensoriaCity/<repo> --state merged --limit 1000 \
  --search "merged:>=<inicio>" \
  --json number,title,author,headRefName,baseRefName,labels,createdAt,mergedAt,additions,deletions,changedFiles,files,reviews,commits \
  | python3 ~/Projects/sensoria-plugins/scripts/numeros.py
```

El script lee la firma (`branches` y `label`) del `.city.json` del repo, clasifica con una versión simplificada del ADR-008 y da, por flujo: n, tamaño p50 y p85, lead time del primer commit al merge, % sin revisión humana, primera revisión humana p50 y % de aprobación rápida. Con `--autores usuario1,usuario2` filtra por los autores de una squad. En el flujo `city` el % sin revisión humana es alto a propósito: lo que importa ahí son los guardarraíles de abajo.

**Actualizar el kit.** Cuando cambia la versión, en cada repo: `claude plugin marketplace update sensoria` y `claude plugin update city@sensoria`, y reiniciar Claude Code. CI toma la versión de `main` de este repo en cada corrida. La bitácora registra la versión que usó cada squad esa semana.

No se juzga a una squad antes de su semana 4. DORA espera una caída de productividad al inicio de cualquier cambio de proceso (curva J, informe p.8 a p.10).

## Guardarraíles

Si uno falla en la semana de una squad, no entra la siguiente hasta corregir la causa.

1. 0 funcionalidades con `passes: true` sin evidencia del evaluador.
2. 0 PR mergeados con el check `revisor` en rojo o ausente.
3. Arreglos a producción atribuibles a PR de `city` no mayores que los de `bmad` + 5 pp en el mismo periodo (B8, A3).
4. Churn a 21 días de los PR de `city` no mayor que el de `bmad` del mismo tramo (B9).

**Flujo,** desde la semana 4 de cada squad: lead time p50 del primer commit al merge menor en `city` que en `bmad` (A1), o cycle time p50 de las tareas de Notion menor con throughput no menor que la historia de la squad (C2, C4).

**Señales para la retro,** no deciden solas: hallazgos reales o ruido del `reviewer` y del `evaluator`, pasos `no verificado`, PR retenidos por CODEOWNERS por semana y lo que QA humano encontró en la feature completa que el evaluador debió ver.

**Muestra.** Cada grupo necesita n ≥ 5 (`min_sample_size`). Si no se alcanza, se espera otra semana en vez de decidir con muestra insuficiente.

## Salida de emergencia

Si una squad no puede trabajar con el método, lo anota en `bitacora.md` con el motivo y el CTO decide. Para salir: `claude plugin uninstall city@sensoria --scope project` en un PR, y la squad vuelve a BMAD. Las funcionalidades y su evidencia se quedan como documentación de lo que se construyó.

## Guía de la retro

1. ¿Entendías qué construir antes de empezar cada funcionalidad?
2. ¿El revisor y el evaluador encontraron problemas reales o ruido? ¿QA humano encontró en la feature completa algo que el evaluador debió ver?
3. ¿Qué PR retuvo CODEOWNERS y valió la pena leerlo?
4. ¿Confías en el código que llegó a `main` sin que nadie lo leyera?
5. ¿Qué pieza del kit quitarías esta semana, y cómo sabríamos si hizo falta?
