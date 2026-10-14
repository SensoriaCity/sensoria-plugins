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
3. **`docs/harness/entorno.md`** con lo propio de la máquina: puertos, versiones y cómo bajar una instalación.
4. **Labels:** `gh label create city --description "Flujo city" --repo SensoriaCity/<repo>` y `gh label create adr --description "Trae un ADR" --repo SensoriaCity/<repo>`.
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
| Agregar las funcionalidades del hito a `features` | `/city:spec`, partidas en cortes según `cortes.md`, en un PR propio |
| "Toca", lo que no decide solo quien construye y las dependencias con su línea de instalación | La sección de cada corte en la spec, que `/city:build` lee |
| Elegir de 1 a 3 funcionalidades para el día | `/city:goal <ids en orden>`, o `/city:build <id>` |
| Revisar CI y tags de `main` y darle destino a los hallazgos | `/city:check` y la retro |
| Lo propio del repo: estado, bitácora, guiones al teclado, rutas de worktree | El `CLAUDE.md` del repo o `docs/harness/entorno.md` |

Para retirarlo, en un PR del repo: borrar la skill del plan diario, cambiar la sección de flujo del `CLAUDE.md` por el ciclo de `metodo.md` y, si las specs no van en `docs/specs`, agregar `specs_dir` a `.city.json`. Los planes ya escritos se quedan como historia y `/city:build <id> <plan>` los sigue leyendo; un plan que parte una funcionalidad en entregas vale hasta que esa funcionalidad cierre. Una funcionalidad grande que quedó a medias, sin plan para lo que falta, se parte con `/city:spec partir <id>`.

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

El script lee la firma (`ramas` y `label`) del `.city.json` del repo, clasifica con una versión simplificada del ADR-008 y da, por flujo: n, tamaño p50 y p85, lead time del primer commit al merge, % sin revisión humana, primera revisión humana p50 y % de aprobación rápida. Con `--autores usuario1,usuario2` filtra por los autores de una squad. En el flujo `city` el % sin revisión humana es alto a propósito: lo que importa ahí son los guardarraíles de abajo.

**Actualizar el kit.** Cuando cambia la versión, en cada repo: `claude plugin marketplace update sensoria` y `claude plugin update city@sensoria`, y reiniciar Claude Code. CI toma la versión de `main` de este repo en cada corrida. La bitácora registra la versión que usó cada squad esa semana.

No se juzga a una squad antes de su semana 4. DORA espera una caída de productividad al inicio de cualquier cambio de proceso (curva J, informe p.8 a p.10).

## Guardarraíles

Si uno falla en la semana de una squad, no entra la siguiente hasta corregir la causa.

1. 0 funcionalidades con `passes: true` sin evidencia del evaluador.
2. 0 PR mergeados con el check `revisor` en rojo o ausente.
3. Arreglos a producción atribuibles a PR de `city` no mayores que los de `bmad` + 5 pp en el mismo periodo (B8, A3).
4. Churn a 21 días de los PR de `city` no mayor que el de `bmad` del mismo tramo (B9).

**Flujo,** desde la semana 4 de cada squad: lead time p50 del primer commit al merge menor en `city` que en `bmad` (A1), o cycle time p50 de las tareas de Notion menor con throughput no menor que la historia de la squad (C2, C4).

**Señales para la retro,** no deciden solas: hallazgos reales o ruido del `revisor` y del `evaluador`, pasos `no verificado`, PR retenidos por CODEOWNERS por semana y lo que QA humano encontró en la feature completa que el evaluador debió ver.

**Muestra.** Cada grupo necesita n ≥ 5 (`min_sample_size`). Si no se alcanza, se espera otra semana en vez de decidir con muestra insuficiente.

## Salida de emergencia

Si una squad no puede trabajar con el método, lo anota en `bitacora.md` con el motivo y el CTO decide. Para salir: `claude plugin uninstall city@sensoria --scope project` en un PR, y la squad vuelve a BMAD. Las funcionalidades y su evidencia se quedan como documentación de lo que se construyó.

## Guía de la retro

1. ¿Entendías qué construir antes de empezar cada funcionalidad?
2. ¿El revisor y el evaluador encontraron problemas reales o ruido? ¿QA humano encontró en la feature completa algo que el evaluador debió ver?
3. ¿Qué PR retuvo CODEOWNERS y valió la pena leerlo?
4. ¿Confías en el código que llegó a `main` sin que nadie lo leyera?
5. ¿Qué pieza del kit quitarías esta semana, y cómo sabríamos si hizo falta?
