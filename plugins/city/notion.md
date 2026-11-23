# Notion y el repo: quién guarda qué

Cada dato vive en un solo lugar y el otro lado lo enlaza. Notion dice **qué** se construye, **por qué** y **en qué va**; el repo dice **cómo** y guarda la prueba. Nadie copia texto de un lado al otro.

| Dato | Vive en | Lo escribe | El otro lado |
|---|---|---|---|
| Módulo, su objetivo y sus personas | Notion, base de módulos | PO | La carpeta `<apps_dir>/<aplicativo>/<modulo>/` usa su id |
| Hito y su definición funcional | Notion, página del hito | PO, con `/city:discovery` | `spec.md` lleva la URL del hito |
| Spec, cortes y evidencia | Repo, carpeta del hito | `/city:spec` y `/city:build` | El hito lleva el enlace a `spec.md` |
| Avance de cada corte | Notion, una tarea por corte | `/city:ship` la crea con el PR de Spec y la mueve; `/city:check` la alinea | La tarea lleva el id del corte y la URL del PR |
| Estado del flag | La app (página de flags del repo) | Quien lo enciende, con motivo | El hito nombra el flag |

No hay plan técnico en Notion: la spec lo reemplaza. No hay tareas que no sean un corte, salvo hotfix.

## Configuración

`.city.json`, clave opcional `notion`: `{"milestones": "<URL de la base de hitos>", "tasks": "<URL de la base de tareas>"}` (en un `.city.json` 2.x, `hitos` y `tareas`). Sin la clave, o sin el conector de Notion en la sesión (pasa en las sesiones de `goal.sh`), ninguna skill escribe en Notion: deja en su reporte una línea `Notion pendiente: <qué>` por cada cambio, y `/city:check` lista lo desalineado y lo aplica solo si la persona que lo corre se lo pide.

## Qué escribe cada skill

Los nombres de propiedad son los de city; un repo con otros nombres los dice en su `docs/harness/entorno.md`.

| Momento | Skill | En el hito | En la tarea del corte |
|---|---|---|---|
| Definición redactada | `/city:discovery` | Solo el texto que el PO aprobó, en "Definición funcional"; `Definición lista` si el PO lo pide | — |
| PR de clase `spec` abierto | `/city:ship` | `Spec`: URL del PR; `Flag`, si hay | Crea una por corte: título `[<App>][H<nn>] s<nn> — <comportamiento>`, `Hito`, `Corte` (el id), `Clase`, tipo Desarrollo, estado "Sin empezar" |
| PR de clase `spec` mergeado | `/city:check`, si se lo piden | `Spec`: URL de `spec.md` en `main`; `Spec aprobada` | Si la revisión cambió los cortes, las alinea por id |
| Empieza un corte: pasó la compuerta y ya tiene rama | `/city:build` | Estado "En progreso", si era "Sin empezar" | Estado "En progreso", `Rama` |
| PR del corte abierto y en verde | `/city:ship` | — | `PR`: la URL; estado "Listo para TL". Si el PR sale en borrador, solo la URL: "Listo para TL" llega cuando pasa a listo |
| PR mergeado | `/city:check`, si se lo piden | — | Estado "Finalizado" |
| Último corte mergeado | `/city:check`, si se lo piden | Estado "Pruebas funcionales" | — |
| Flag encendido en producción | La persona que lo enciende | Estado "Desplegado" | — |

Reglas:

- Antes de crear una tarea, búscala por `Corte`: si existe, se actualiza. Nunca hay dos tareas para un id.
- Una skill solo mueve un estado hacia adelante. Devolverlo es de una persona.
- Si lo que hay en Notion contradice al repo (una tarea "Finalizado" con el PR abierto), manda el repo y `/city:check` lo lista en "Notion desalineado".
- `passes` no se copia a Notion: se lee en el repo.
