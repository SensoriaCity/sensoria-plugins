# sensoria-plugins

Repo de los plugins de Claude Code de Sensoria. Hoy trae uno, `city`, en `plugins/city/`, con su marketplace en `.claude-plugin/marketplace.json` y la documentación del método y de la adopción en `docs/`. El código que construyen las squads vive en `SensoriaCity/city` y `SensoriaCity/city-v2`, no aquí.

## Reglas para cambiar el kit

- La prosa, en español: el cuerpo de las skills, la spec, el texto de los pasos, la evidencia, los docs y los mensajes de los scripts. Lo estructural, en inglés: nombres de archivos y carpetas del plugin, claves de JSON, valores enumerados, etiquetas de GitHub, variables de entorno y nombres de scripts, skills y agentes. Nombres de archivos, comandos y rutas en backticks.
- Una clave de `.city.json` que cambia de nombre se sigue leyendo con el nombre anterior (en jq, `.line_limit // .tope_lineas`) y queda en el schema marcada como obsoleta. El JSON de un corte no tiene compatibilidad: solo vale el formato vigente.
- Durante la adopción entra máximo un cambio de comportamiento por semana. Cada cambio sube la versión en `plugins/city/.claude-plugin/plugin.json` y agrega una línea en `CHANGELOG.md` bajo `## city <versión> · <fecha>`, con el motivo y la entrada de `bitacora.md` que lo pidió.
- Una skill o regla nueva entra solo si la bitácora muestra el mismo tropiezo dos veces.
- Cada `SKILL.md` se queda por debajo de 120 líneas. Lo que no quepa va a un archivo de apoyo en la misma carpeta, referenciado con `${CLAUDE_SKILL_DIR}`.
- Las skills llevan `disable-model-invocation: true`: las invoca la persona, no el modelo. La única excepción es `review`, que corre en GitHub Actions sin persona; no pasa de 60 líneas, lee del PR solo rama, base y título, y delega al revisor con una sola línea.
- No hay roles: ninguna skill distingue senior, junior ni TL. El control humano está en `/city:check`, en la feature completa antes del flag, en la retro y en los PR que retiene CODEOWNERS.
- El kit no sabe nada del stack: todo lo que ejecuta o lee sale de `.city.json`, cuyo contrato es `plugins/city/city.schema.json`. `validate.sh` falla si una skill o agente nombra un comando de un stack o no lee `.city.json`.
- Los agentes `reviewer`, `security` y `evaluator` no tienen herramientas de edición y no se les agregan. Su Bash no está restringido por el runtime, así que sus límites viven en el prompt: el revisor y seguridad solo leen y corren pruebas (el revisor, cuando la rama no es la actual, en un árbol aparte con `git worktree add` en una carpeta temporal que borra; o, si el árbol de trabajo está limpio y su línea de entrada trae `arbol: libre`, con `git checkout --detach <rama>`, que siempre deshace; del PR lee título y cuerpo, el cuerpo solo para su forma); el evaluador solo prueba en una instalación local, nunca reinicia la base ni borra volúmenes, y escribe solo en su `mktemp -d`, salvo dos cosas del repo que prueba: su evidencia (`evidence/<id>.md`) y el `passes` del corte, con `passes.sh`. El commit lo hace quien lo llamó, o él mismo si su línea de entrada trae `commit: evidencia`; el push, solo si además trae `push: evidencia`. No crea copias del repo con enlaces a las carpetas de dependencias ni las toca: romper a propósito una prueba de regresión lo hace quien construye, en su rama, y el evaluador solo lo repite con el comando que dé el repo (`tests.mutation`). En un corte de clase `data` puede subir y bajar la migración del corte y alterar filas marcadas, solo en la base de la instalación de QA o en una desechable. En cualquier clase puede insertar directo, marcado y declarado, un dato que la app ya no deja crear.
- `passes` cambia solo con `plugins/city/scripts/passes.sh`, que exige la evidencia del evaluador con `VEREDICTO: pasa` sobre el código vigente; con `--check` dice si un `passes: true` sigue valiendo y con `--reset` lo devuelve a `false` cuando el código cambió después de evaluar, y marca la evidencia con una línea `VENCIDA:`, que `passes.sh` ya no acepta. Lo que vence una evidencia es código nuevo en la rama que se comprueba (la del corte o una `-fix`); sobre `main`, la que entró con el merge del corte sigue vigente aunque cortes posteriores toquen sus archivos. Con `--base <ref>` compara contra otra base (un corte apilado). Nada del kit cambia `passes` de otra forma.
- La evidencia de quien construye va en el cuerpo del PR, no en un archivo: en `evidence/` de un hito vive solo `<id>.md`, del evaluador.
- Lo propio de un corte de clase `data` (motor real, base desechable, `tests.database`, qué demuestra un paso) vive en `plugins/city/skills/build/data-slices.md`, que leen `build`, el `reviewer` y el `evaluator`.
- El tamaño se mide solo con `plugins/city/scripts/size.sh`. `validate.sh` falla si una skill o agente usa otro comando.
- Un corte se construye cuando sus `depends_on` ya están en la rama principal. Apilar una rama sobre la de otro corte es una excepción que pide una persona, y vive en "Un corte se construye sobre la rama principal" de `plugins/city/skills/spec/slices.md`: todos los scripts reciben la base y el evaluador espera a que la base esté mezclada. `ships_with` es la clave del corte para "no desplegar sin el otro"; el kit lo lista, no despliega.
- Un corte que ya está en `main` cambia solo por tres caminos de `/city:spec` (`split`, `unblock` y `revise`, este con `revision` y "Decisiones tomadas") y nunca si tiene `passes: true`: su código se corrige en una rama `-fix` cuyo PR renueva la evidencia. `check-spec.sh --base` lo comprueba.
- Ruta con dueño es la unión de `codeowners_paths` y del archivo de dueños del repo, y la da solo `plugins/city/scripts/owners.sh`, también a la guarda de `goal.sh`. Los dos lados no significan lo mismo: `codeowners_paths` son las rutas compartidas, que piden ADR (`--match shared`); el archivo de dueños dice quién aprueba y solo retiene el merge (`--match owned`).
- La guía de navegador del evaluador vive en `plugins/city/skills/build/browser.md` y no fija el prefijo de las herramientas; la lista `tools` de `evaluator.md` sí, porque un agente solo recibe las que nombra.
- La versión de `@playwright/mcp` va fija en `plugins/city/.mcp.json`. Subirla es un cambio de comportamiento del kit y pide agregar su lista de herramientas a `validate.sh`. Si cambia el nombre del servidor (`playwright`), cambian los nombres de sus herramientas: hay que actualizar `tools` de `evaluator.md`.
- Los agentes de un plugin ignoran `mcpServers`, `hooks` y `permissionMode` en su frontmatter. Por eso el servidor de Playwright va en `.mcp.json` del plugin y el hook de dependencias en `hooks/hooks.json`.
- `evaluator` lista sus herramientas de Playwright una por una, sin comodín: `browser_run_code_unsafe` y `browser_evaluate` ejecutan código arbitrario y no se le dan; tampoco `browser_resize` ni `browser_close`, porque el navegador puede ser de otro. Antes de tocar nada, corre `scripts/qa-env.py`.
- Nada del kit usa los comandos BMAD ni modifica `_bmad/` o los archivos BMAD de `docs/apps/<app>/` de `city`.
- La firma del flujo (rama con el prefijo `branches` de `.city.json`, label `city`) no cambia sin actualizar `docs/integracion-aidd-metrics.md`, `scripts/numeros.py` y la config de `aidd-metrics`.

## Verificar

```bash
./scripts/validate.sh
```

Corre `claude plugin validate --strict` sobre el marketplace, el plugin y sus skills; revisa frontmatter, tamaño, que los agentes no editen, archivos referenciados, el `.mcp.json` y las herramientas del evaluador, que la versión tenga entrada en el changelog, que el kit no nombre el stack, `size.sh`, `passes.sh` y `qa-env.py` en un repo de prueba, la prueba del hook de dependencias, y ShellCheck y la prueba en seco de `goal.sh` (necesita `shellcheck`).

Para probar un cambio en un repo sin instalar, desde su clon:

```bash
claude --plugin-dir ~/Projects/sensoria-plugins/plugins/city
```
