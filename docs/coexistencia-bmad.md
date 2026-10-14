# Convivencia con BMAD

En `city`, BMAD sigue igual para las squads que todavía no adoptan el método (ver `adopcion.md`). El plugin `city` no lee, no usa y no modifica nada de BMAD. Mientras convivan, los dos flujos se comparan en el mismo periodo, con squads distintas. `city-v2` no tiene BMAD: ahí todo entra por `city`.

## Qué no se toca en `city`

- `_bmad/` y los comandos de `.claude/commands/`: analyst, architect, pm, create-story, dev-story, qa, quick-dev, hito-writer.
- Los PRD, tech-plans, épicas, historias y `sprint-status` de `docs/apps/<app>/`. Una spec los puede leer como contexto, sin modificarlos; si contradicen el código, manda el código.
- Las ramas `hito/*` y `tarea/*` y su flujo apilado.
- Los revisores de GitHub, CodeRabbit y Claude Code Review.

Lo que `city` agrega al repo: `.city.json` en la raíz, las carpetas `features` y `evidencia_dir` que nombra, `docs/harness/entorno.md`, el job `revisor` de CI y los PR con rama `<ramas>` y label `city`. El ruleset y CODEOWNERS se aplican a todo `main`. Los jobs `revisor` y `evidencia` corren solo en los PR con el label `city`; en los de BMAD quedan saltados, y GitHub cuenta un job saltado como check pasado, así que BMAD no cambia.

## Equivalencias

| BMAD | `city` |
|---|---|
| analyst + pm → PRD | Spec de una página = hito, con sus funcionalidades en `features` |
| architect → tech-plan | Diseño corto en la spec. Si el cambio toca un contrato compartido, un ADR de ≤30 líneas que pide la regla y se acepta al mergearse |
| sm → épicas, historias, `sprint-status` | Funcionalidades con pasos verificables y `passes`; en Notion la spec es un hito y cada corte una tarea |
| dev-story | `/city:build <id>`, una funcionalidad por sesión |
| quick-dev | `/city:build` con una funcionalidad de un paso |
| qa / tea | Prueba primero; `revisor` en contexto limpio y en CI; `evaluador` sobre una instalación limpia, único dueño de `passes`. QA humano prueba la feature completa antes del flag |
| PR `tarea/* → hito/*`, luego `hito/* → main` | Un PR por corte directo a `main` con auto-merge por checks; lo incompleto va tras flag |

## Reglas para no contaminar la comparación

1. **Un PR es de un solo flujo.** En una rama de `city` no se usan comandos BMAD, y en ramas `hito/*` o `tarea/*` no se usan las skills de `city`.
2. **Trabajo en curso.** Si la squad tiene un hito BMAD a medias cuando adopta, lo termina en BMAD. Todo trabajo nuevo desde su semana 1 entra por `city`.
3. **Si algo no cabe en `city`,** la squad no vuelve a BMAD en silencio. Lo anota en `bitacora.md` con el motivo, y el CTO decide si ese trabajo sale del flujo.
4. **Títulos.** Los PR de `city` no usan "Story" ni "Historia" con número, porque es la firma de BMAD en `aidd-metrics`.
5. **Rutas propias.** `features` y `evidencia_dir` del `.city.json` de `city` no caen en archivos BMAD de `docs/apps/<app>/` ni usan `story`, `epic`, `prd`, `tech-plan` ni `sprint-status` en su nombre. Un PR que modifica archivos BMAD queda clasificado como BMAD aunque tenga la rama de `city`.
6. **Hotfix aparte.** Los arreglos a producción van por `hotfix/`, en los dos flujos.

## Salida de emergencia

Si una squad no puede seguir con `city`, sale como dice `adopcion.md` y vuelve a BMAD. Sus funcionalidades y su evidencia se quedan como documentación de lo que se construyó.
