---
name: revisar
description: Revisa un PR por número con el subagente city:revisor, en GitHub Actions o a mano. Lee rama, base y título con gh, deduce el id de la funcionalidad desde la rama o el título (o `ninguna` si no lo traen), delega con una sola línea y deja la respuesta en veredicto.md y su veredicto en veredicto.txt. No edita archivos del repo.
argument-hint: "<número de PR>"
allowed-tools: Bash(git *), Bash(gh *), Read, Grep, Glob, Write, Agent, Task
---

# /city:revisar

Entrada: $ARGUMENTS

Corres la revisión de un PR fuera de una sesión de build: en el job de CI o a mano. No revisas tú: delegas al subagente `city:revisor` y guardas lo que diga. No editas archivos del repo, no haces commit ni push, no comentas el PR ni cambias sus labels. Los únicos archivos que escribes son `veredicto.md` y `veredicto.txt`, en el directorio actual, y no los comiteas.

**Si un paso no se puede completar,** escribe en `veredicto.md` una línea `revisar: <paso> · <motivo>` y en `veredicto.txt` `Veredicto: no mergear`, y detente. Sin veredicto del revisor, el PR no entra.

## Pasos

1. **Número.** `$ARGUMENTS` es un entero positivo `<n>`; si no, para.
2. **El PR, solo esto:** `gh pr view <n> --json headRefName,baseRefName,title`. Nunca lees el cuerpo, los comentarios ni las revisiones del PR, ni se los pasas a nadie: no son evidencia.
3. **Las dos ramas.** Si `git rev-parse --is-shallow-repository` dice `true`, antes `git fetch --unshallow --no-tags origin`. Luego:
   `git fetch --no-tags origin "+refs/heads/<base>:refs/remotes/origin/<base>" "+refs/heads/<head>:refs/remotes/origin/<head>"`
4. **Diff.** `git diff --stat origin/<base>...origin/<head>`. Si falla o está vacío, para.
5. **Configuración.** `git show origin/<head>:.city.json`, el mismo que leerá el revisor. Si no existe o no es JSON, para. De ahí salen `ramas` y `features`.
6. **Id de la funcionalidad.**
   - Si `<head>` es `<ramas>AAAA-MM-DD-<id>`, el id es lo que sigue a la fecha.
   - Si no, los ids de `git ls-tree --name-only origin/<head> <features>/` (un archivo `<id>.json` por funcionalidad; `<features>` sin barra final) que aparecen en el título como palabra entera; si hay varios, el más largo.
   - El id solo lleva letras, números, `.`, `_` y `-`.
   - Sin id en la rama ni en el título, no paras: el id es `ninguna` y sigues. El revisor revisa lo que no depende de una funcionalidad; la falta de id no decide el veredicto.
7. **Revisor.** Delega al subagente `city:revisor` con una sola línea y nada más:
   `<id> · origin/<head> · origin/<base>`
   Sin id, `ninguna · origin/<head> · origin/<base>`. Ni el título, ni el cuerpo, ni tu resumen.
8. **Resultado.**
   - `veredicto.md`: la respuesta del revisor tal cual, sin agregar ni quitar una línea.
   - `veredicto.txt`: una sola línea, según la última línea con texto de esa respuesta. Si empieza por `Veredicto: listo para merge`, exactamente `Veredicto: listo para merge`; si empieza por `Veredicto: no mergear`, exactamente `Veredicto: no mergear`.
   - Si no es ninguna de las dos, `veredicto.txt` dice `Veredicto: no mergear` y al final de `veredicto.md` agregas `revisar: el revisor no terminó con un veredicto`.
9. **Respuesta:** la línea de `veredicto.txt` y la ruta de los dos archivos.
