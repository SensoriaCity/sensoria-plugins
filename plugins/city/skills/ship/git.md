# Convenciones de git

La clave `git` de `.city.json` dice cómo escribe el repo sus commits y cómo entra un PR a `main`. Sin la clave o sin un campo, vale el de por omisión. Las reglas del `CLAUDE.md` del repo sobre commits y PR mandan sobre este archivo.

## Mensajes: `git.commits`

| Valor | Commit y título del PR |
|---|---|
| `conventional` (por omisión) | `<tipo>(<ámbito>): <qué cambia>`, en español. En el título, el tipo es `feat` en una rama de `branches` y el del prefijo en una rama Conventional; si el repo versiona por título del PR, el tipo define la versión. |
| `gitmoji` | `<emoji> <frase en español que dice qué cambia>`, sin tipo ni ámbito, como los commits del repo (`git log --oneline -20 origin/main`). Va el carácter del emoji, no su código (`✨`, no `:sparkles:`). |

Emojis de gitmoji para lo que hace el kit: ✨ funcionalidad nueva, 🐛 corrección, ✅ pruebas, 📝 documentación y specs, ♻️ refactor, 🔧 configuración, 👷 CI, 🗃️ migraciones y cambios de datos (los cortes de clase `data`), ⏪ una evidencia que dejó de valer.

Mensajes fijos del kit:

| Qué | `conventional` | `gitmoji` |
|---|---|---|
| Spec de `/city:spec` | `docs(spec): <tema>` | `📝 Escribe la spec de <tema>` |
| Revisión de una spec, de `/city:spec revise <hito>` | `docs(spec): revisa <hito> · <decisión en pocas palabras>` | `📝 Revisa la spec de <hito>: <decisión en pocas palabras>` |
| Evidencia del evaluador | `test(<ámbito>): evidencia de <id>` | `✅ Guarda la evidencia del evaluador de <id>` |
| Evidencia vencida, de `passes.sh <id> --reset` | `test(<ámbito>): vence la evidencia de <id>` | `⏪ Vence la evidencia del evaluador de <id>` |
| Bitácora de `/city:ship` | `docs(<ámbito>): bitácora de <id>` | `📝 Registra la bitácora de <id>` |

El commit de evidencia lleva solo la evidencia del evaluador (`evidence/<id>.md`) y, si cambió, el `passes` del archivo del corte: nada de código. Usa siempre el mensaje de la tabla, sea cual sea la clase del corte: en uno de clase `data`, 🗃️ es para la migración y ✅ para su evidencia.

Devolver `passes` a `false` con `passes.sh <id> --reset` no es guardar evidencia y no lleva ese mensaje: lleva el de evidencia vencida. Ese commit trae el `passes` en `false` y la evidencia con la línea que el script le agrega al final, `VENCIDA: evaluó <commit>; el código cambió en <commit>`; así el historial no dice "guarda la evidencia" sobre una que dejó de valer, y el archivo no sigue diciendo que pasa. La pasada siguiente del evaluador reemplaza el archivo entero y va con el mensaje de evidencia.

El commit de una revisión lleva `spec.md` y los cortes que la decisión toca, y su asunto nombra el hito (`h<NN>-<slug>`, o `m<NN>-h<NN>`) y la decisión, no "la spec de": así se distingue en el historial de la spec original.

Si el `CLAUDE.md` del repo prohíbe nombrar una IA en commits o PR, ningún commit, título ni cuerpo lleva `Co-Authored-By`, `Generated with` ni una línea parecida. Las apaga `"attribution": {"commit": "", "pr": ""}` en `.claude/settings.json` del repo; si esa clave falta, dilo en el reporte.

## Ramas

| Rama | Para qué | Clase del PR |
|---|---|---|
| `<branches>AAAA-MM-DD-<id>` | Construir el corte `<id>` | La del corte |
| `<branches>AAAA-MM-DD-<id>-fix` (`-fix2`…) | Corregir código de un corte que ya tiene `passes: true`; el mismo PR renueva su evidencia | La del corte |
| `docs/AAAA-MM-DD-spec-<hito>`, `…-unblock-<id>`, `…-revise-<hito>` | Spec nueva, desbloqueo o revisión de una spec ya mezclada | `spec` |

Toda rama sale de `origin/main` y su PR va contra `main`: un corte se construye cuando sus `depends_on` ya están ahí. Apilar una rama sobre la de otro corte es una excepción que pide una persona; qué cambia entonces (la base en cada script, cuándo evalúa el evaluador y cómo se resuelve el squash del PR de abajo) está en `skills/spec/slices.md`, "Un corte se construye sobre la rama principal".

## Merge: `git.merge`

- `auto` (por omisión): `/city:ship` activa `gh pr merge <n> --auto --squash` si ningún archivo del PR tiene dueño, y el PR entra cuando pasan los checks requeridos. Ruta con dueño es la unión de `codeowners_paths` y del archivo de dueños del repo, que da `scripts/owners.sh`. Dentro de `/city:goal` lo activa `goal.sh`, no la sesión, con la misma guarda: `owners.sh --match` sobre los archivos del PR. Los dos lados no dicen lo mismo (`codeowners_paths` son las rutas compartidas, que además piden ADR; el archivo de dueños dice quién aprueba), pero cualquiera de los dos retiene el merge; `owners.sh --check` y `/city:check` avisan si divergen.
- `manual`: el PR lo aprueba y lo mergea una persona, con las reglas del repo para el merge (`docs/harness/entorno.md`). `/city:ship` no activa el auto-merge ni mergea, y `/city:goal` abre cada PR y espera a que la persona lo mergee antes del corte siguiente. Fuera del bucle la regla es la misma: el corte siguiente se construye cuando el anterior ya está en `main`, no sobre su rama.

## Versión: `git.version`

- `tag` (por omisión): CI crea un tag sobre el commit del merge. Se lee con `git tag --points-at <oid>`.
- `subject` (`asunto` en un `.city.json` 2.x): la versión es el asunto del commit del squash, que escribe quien mergea. Se lee con `git log -1 --format=%s <oid>`.
