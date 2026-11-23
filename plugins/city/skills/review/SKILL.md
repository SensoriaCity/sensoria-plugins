---
name: review
description: Revisa un PR por número con el subagente city:reviewer, en GitHub Actions o a mano. Lee rama, base y título con gh, deduce el id de la funcionalidad desde la rama o el título (o `ninguna` si no lo traen), delega con una sola línea y deja la respuesta en verdict.md y su veredicto en verdict.txt. No edita archivos del repo.
argument-hint: "<número de PR>"
allowed-tools: Bash(git *), Bash(gh *), Bash(printenv GITHUB_ACTIONS), Read, Grep, Glob, Write, Agent, Task
---

# /city:review

Entrada: $ARGUMENTS

Corres la revisión de un PR fuera de una sesión de build: en el job de CI o a mano. No revisas tú: delegas al subagente `city:reviewer` y guardas lo que diga. No editas archivos del repo, no haces commit ni push, no comentas el PR ni cambias sus labels. Los únicos archivos que escribes son `verdict.md` y `verdict.txt`, en el directorio actual, y no los comiteas.

**Si un paso no se puede completar,** escribe en `verdict.md` una línea `review: <paso> · <motivo>` y en `verdict.txt` `Veredicto: no mergear`, y detente. Sin veredicto del revisor, el PR no entra.

## Pasos

1. **Número.** `$ARGUMENTS` es un entero positivo `<n>`; si no, para.
2. **El PR, solo esto:** `gh pr view <n> --json headRefName,baseRefName,title`. Nunca lees el cuerpo, los comentarios ni las revisiones del PR, ni se los pasas a nadie: no son evidencia. El revisor lee el cuerpo por su cuenta, solo para comprobar su forma.
3. **Las dos ramas.** Si `git rev-parse --is-shallow-repository` dice `true`, antes `git fetch --unshallow --no-tags origin`. Luego:
   `git fetch --no-tags origin "+refs/heads/<base>:refs/remotes/origin/<base>" "+refs/heads/<head>:refs/remotes/origin/<head>"`
4. **Diff.** `git diff --stat origin/<base>...origin/<head>`. Si falla o está vacío, para.
5. **Configuración.** `git show origin/<head>:.city.json`, el mismo que leerá el revisor. Si no existe o no es JSON, para. De ahí salen `branches`, `apps_dir` y `features`.
6. **Id de la funcionalidad.**
   - Si `<head>` es `<branches>AAAA-MM-DD-<id>`, el id es lo que sigue a la fecha. Si eso no es un corte de `origin/<head>` y termina en `-fix` o `-fix<n>` (la rama corrige un corte ya mezclado), el id es lo de antes del sufijo.
   - Si no, los ids de los archivos de corte de `origin/<head>` (`git ls-tree -r --name-only origin/<head> <apps_dir>` que terminan en `/slices/<id>.json`, y `<features>/<id>.json`) que aparecen en el título como palabra entera; si hay varios, el más largo.
   - El id solo lleva letras, números, `.`, `_` y `-`.
   - Sin id en la rama ni en el título, no paras: el id es `ninguna` y sigues. El revisor revisa lo que no depende de una funcionalidad; la falta de id no decide el veredicto.
7. **Revisor.** Delega al subagente `city:reviewer` en primer plano (`run_in_background: false`): su respuesta vuelve en la misma llamada. Le pasas una sola línea y nada más:
   `<id> · origin/<head> · origin/<base>`
   Sin id, `ninguna · origin/<head> · origin/<base>`. Ni el título, ni el cuerpo, ni tu resumen.
   Lo único que se le agrega, al final, es ` · arbol: libre`, y solo cuando nadie más usa este árbol de trabajo: en CI (`printenv GITHUB_ACTIONS` da `true`: el checkout es de este job) o si la persona que te llamó lo dijo. Con esa marca y el árbol limpio, el revisor puede pasarlo a la rama para correr las pruebas y lo devuelve; sin ella, usa un árbol aparte. La configuración es la de `.city.json` del paso 5.
8. **Resultado.**
   - Si la llamada no devolvió la respuesta del revisor (por ejemplo, avisa que quedó en segundo plano), `verdict.txt` dice `Veredicto: no mergear` y `verdict.md`, `review: el revisor no devolvió respuesta`. No cierres el turno esperándolo.
   - `verdict.md`: la respuesta del revisor tal cual, sin agregar ni quitar una línea.
   - `verdict.txt`: una sola línea, según la última línea con texto de esa respuesta. Si empieza por `Veredicto: listo para merge`, exactamente `Veredicto: listo para merge`; si empieza por `Veredicto: no mergear`, exactamente `Veredicto: no mergear`; si empieza por `Veredicto: espera decisión`, esa línea entera, con la persona que decide. El check queda en rojo también con esta: el PR no entra hasta que la persona decida y el revisor dé otra vuelta.
   - Si no es ninguna de las tres, `verdict.txt` dice `Veredicto: no mergear` y al final de `verdict.md` agregas `review: el revisor no terminó con un veredicto`.
9. **Respuesta:** la línea de `verdict.txt` y la ruta de los dos archivos.
