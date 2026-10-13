# Bitácora

Una entrada por repo o squad cada viernes. Se agrega al final, no se edita lo anterior. Los tropiezos son la materia prima para cambiar el kit: una skill o regla nueva entra solo si el mismo tropiezo aparece dos veces. Cada cambio del kit en `CHANGELOG.md` enlaza la entrada que lo pidió.

Plantilla:

```
## Semana <n> · <AAAA-MM-DD> · <repo> · <squad> · kit <versión>
- PR mergeados / abiertos / retenidos por CODEOWNERS: <n> / <n> / <n>
- Tamaño p50 / p85: <líneas> / <líneas> · lead time p50: <horas>
- Funcionalidades con passes: <n> · sin evidencia: <n, debe ser 0>
- PR mergeados con revisor en rojo o ausente: <n, debe ser 0>
- Revisor: bloqueos reales / ruido: <n> / <n> · PR que nacieron bloqueados: <n>
- Evaluador: pasadas <n> · no pasa reales / ruido: <n> / <n> · pasos no verificado: <n y por qué> · BLOQUEADO: <n y por qué> · tiempo típico: <min>
- QA humano de features completas: <features probadas> · hallazgos que el evaluador debió ver: <n y enlace>
- Arreglos a producción por cambios de city: <n y enlace>
- Tropiezos: <qué pasó, en qué skill, agente o paso, enlace al PR o sesión>
- Trabajo que no cupo en city: <qué y por qué, o "ninguno">
- Pieza del kit a quitar o ajustar: <una, o "ninguna">
```

---

## Semana 3 · 2026-10-10 · city-v2 · Belmar · kit 1.2.2
- Números: sin medir en esta entrada. city-v2 suspendió la retro semanal hasta cerrar el hito del núcleo (`docs/lab/estado.md` de city-v2).
- Tropiezos: funcionalidades del tamaño de un hito partidas en entregas bajo el mismo id, varias por capa. S3-04 lleva al menos 9 entregas en los planes (E1b a E4x) y S3-12, con 11 pasos, más de 15 (E1 a E6, con E5a a E5l), entre ellas "Fundaciones de estados" y "Oficio medido en CI". Las entregas no tienen pasos ni `passes` propios: el evaluador juzga solo al final y `/city:goal`, que avanza por id, no puede recorrerlas. La causa está en dos lugares: la spec la escribe `/plan-diario` del repo, que parte por tamaño ("más de 300 líneas sale partida en entregas") sin regla de cómo partir, y `/city:build` mide el tamaño en su paso 7, después de implementar.
- Pieza del kit a quitar o ajustar: `/city:spec` con las reglas de un corte, y una compuerta de corte en `/city:build` antes de escribir código.

## Semana 1 · 2026-10-13 · city · Belmar · kit 1.3.0
- Números: sin medir. Es la instalación del flujo (PR #2791 de city, mergeado como `3.7.2.9`), todavía sin funcionalidades.
- Tropiezos: el PR #2791 llegó con 7 commits en Conventional Commits con `Co-Authored-By` de Claude, y el merge se propuso con el título del PR como asunto. city escribe sus commits en Gitmoji, su `CLAUDE.md` prohíbe nombrar una IA en los commits, cada merge a `main` lleva como asunto la versión `X.Y.Z.W` y `main` exige una aprobación, así que no hay auto-merge. La rama se rehízo en un solo commit Gitmoji y una persona hizo el merge con `3.7.2.9`. Con el kit 1.3.0, cada PR del flujo en city repetiría lo mismo: `build` y `ship` escriben en Conventional, `ship` activa el auto-merge, el revisor exige títulos Conventional y `check` lee la versión de tags que city ya no crea (el último es `v3.6.2.5`).
- Pieza del kit a quitar o ajustar: las convenciones de git de cada repo, en `.city.json`.
