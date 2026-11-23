# Integración con aidd-metrics

`aidd-metrics` ya prevé un flujo `liviano` (ADR-008) con la firma vacía y un evento `metodo-liviano` sin fecha. Ese flujo es el de `city`: para medirlo hacen falta dos cambios de configuración en ese repo. La clasificación por flujo todavía no está implementada (feature ING-007 en `false`); mientras tanto, `scripts/numeros.py` de este repo da los números de control desde GitHub con la misma firma.

## 1. Firma del flujo

La firma sale del `.city.json` de cada repo: la rama empieza por `branches` y el PR lleva `label`. En `config/settings.yaml`, bloque `workflow_classification`:

```yaml
  liviano:                        # firma del plugin city; basta con cumplir una de las dos
    branch_regex: '^<branches>'      # el branches del .city.json del repo medido, por ejemplo '^city/'
    labels: ["city"]
```

`branch_regex` y `labels` se combinan con O: un PR es `liviano` si su rama empieza por `branches` o si tiene el label. Hay que dejarlo así en ING-007. El label es el mismo en todos los repos; el prefijo de rama, no, así que si `aidd-metrics` mide más de un repo, la regex va por repo.

La precedencia de ADR-008 se mantiene: `hotfix`, `experimento`, `proceso`, `bmad`, `liviano`, `clasico`. Consecuencias:

- las rutas de `features` y `evidence_dir` no usan `story`, `epic`, `prd`, `tech-plan` ni `sprint-status`, así que no activan la regla de documentos de BMAD. Si el nombre de alguna carpeta de app contiene una de esas palabras (por ejemplo `history`), hay que ajustar `bmad.doc_path_regex` para que solo mire el nombre del archivo;
- un PR con la rama de `city` que modifique archivos BMAD de `docs/apps/<app>/` cae en `bmad`;
- un PR que solo toca documentación cae en `proceso`; por eso la funcionalidad, su evidencia y el código viajan juntos;
- un arreglo a producción va por `hotfix/` y queda como `hotfix`, que es lo correcto para el change failure rate.

## 2. Eventos de adopción

En `config/events.yaml`, uno por repo o squad cuando adopta:

```yaml
  - id: city-adopcion-<repo o squad>
    date: "<AAAA-MM-DD>"           # inicio de su semana 1
    name: "Adopción de city en <repo o squad>"
    kind: process_change
    confirmed: true
```

Los eventos de `aidd-metrics` son globales: la banda antes/después se dibuja para toda la organización aunque solo cambie una squad. La lectura principal es el filtro por flujo; el evento sirve para comparar a cada squad contra su propia historia, filtrando por equipo. `metodo-liviano` queda para cuando `city` sea el flujo por defecto de todo el repo.

## Qué mirar

- **Comparación principal.** Filtro `workflow`: `liviano` contra `bmad` en el mismo periodo, mientras haya squads en BMAD. Separa el efecto del método del paso del tiempo.
- **Comparación secundaria.** Cada squad antes y después de su evento de adopción.
- **Lead time.** Con PRs directos a `main` el cálculo del ADR-004 es más simple: primer commit del PR → merge a `main`. Sigue siendo proxy de deploy (ADR-001).
- **Revisión humana.** En `liviano` el % sin revisión humana es alto por diseño: el merge depende de los checks. La señal es otra: PR mergeados con el check `revisor` en rojo o ausente, y `passes` sin evidencia, que deben ser 0.
- **Vínculo con Notion.** Cada spec es un hito en Hitos v2 y cada corte una tarea en Tareas v2 ligada al hito, con la URL del PR en el campo `PR`: método 1 del ADR-005, confianza alta.
- **Atribución a IA.** Con la decisión del 2026-09-29 (ADR-003, atribución por política) no hace falta trailer. El label `city` queda como evidencia observable de uso.
