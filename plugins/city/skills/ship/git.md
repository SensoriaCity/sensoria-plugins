# Convenciones de git

La clave `git` de `.city.json` dice cómo escribe el repo sus commits y cómo entra un PR a `main`. Sin la clave o sin un campo, vale el de por omisión. Las reglas del `CLAUDE.md` del repo sobre commits y PR mandan sobre este archivo.

## Mensajes: `git.commits`

| Valor | Commit y título del PR |
|---|---|
| `conventional` (por omisión) | `<tipo>(<ámbito>): <qué cambia>`, en español. En el título, el tipo es `feat` en una rama de `ramas` y el del prefijo en una rama Conventional; si el repo versiona por título del PR, el tipo define la versión. |
| `gitmoji` | `<emoji> <frase en español que dice qué cambia>`, sin tipo ni ámbito, como los commits del repo (`git log --oneline -20 origin/main`). Va el carácter del emoji, no su código (`✨`, no `:sparkles:`). |

Emojis de gitmoji para lo que hace el kit: ✨ funcionalidad nueva, 🐛 corrección, ✅ pruebas, 📝 documentación y specs, ♻️ refactor, 🔧 configuración, 👷 CI.

Mensajes fijos del kit:

| Qué | `conventional` | `gitmoji` |
|---|---|---|
| Spec de `/city:spec` | `docs(spec): <tema>` | `📝 Escribe la spec de <tema>` |
| Evidencia del evaluador | `test(<ámbito>): evidencia de <id>` | `✅ Guarda la evidencia del evaluador de <id>` |
| Bitácora de `/city:ship` | `docs(<ámbito>): bitácora de <id>` | `📝 Registra la bitácora de <id>` |

Si el `CLAUDE.md` del repo prohíbe nombrar una IA en commits o PR, ningún commit, título ni cuerpo lleva `Co-Authored-By`, `Generated with` ni una línea parecida. Las apaga `"attribution": {"commit": "", "pr": ""}` en `.claude/settings.json` del repo; si esa clave falta, dilo en el reporte.

## Merge: `git.merge`

- `auto` (por omisión): `/city:ship` activa `gh pr merge <n> --auto --squash` y el PR entra cuando pasan los checks requeridos.
- `manual`: el PR lo aprueba y lo mergea una persona, con las reglas del repo para el merge (`docs/harness/entorno.md`). `/city:ship` no activa el auto-merge ni mergea, y `/city:goal` no corre.

## Versión: `git.version`

- `tag` (por omisión): CI crea un tag sobre el commit del merge. Se lee con `git tag --points-at <oid>`.
- `asunto`: la versión es el asunto del commit del squash, que escribe quien mergea. Se lee con `git log -1 --format=%s <oid>`.
