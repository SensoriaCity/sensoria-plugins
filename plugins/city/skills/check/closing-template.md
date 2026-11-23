# Cierre <app> · <id, hoy (AAAA-MM-DD) o semana (AAAA-MM-DD a AAAA-MM-DD)>

## Mergeados
- #<n> <título> · <vX.Y.Z o "sin versión"> · <fecha>

## Funcionalidades
| id | passes | evidencia |
|---|---|---|
| <id> | <true, false o reemplazado> | [<evidence de slice.sh>](<url>) · <VEREDICTO>, "sin evidencia" o "vencida: <motivo de passes.sh --check>" |

## No desplegar
- <id> (#<n>, ya en `main`) no sale sin <id pendiente>: no desplegar hasta que entre <id pendiente> (#<n abierto> o "sin PR")

## Para leer: retenidos por CODEOWNERS
- #<n> <título> · espera a <persona o equipo> · <archivos que lo retienen>
- Dueños que divergen: <patrón> solo en `codeowners_paths` · <patrón> solo en <archivo de dueños>; o borra la línea

## Esperan una decisión
- #<n> <título> · decide <persona> · <qué>

## En rojo
- #<n> <título> · <revisor, evidencia o evaluador; o "sin check revisor/evidencia">: <motivo en una línea>

## ADR
- Nuevos: <ruta> · <título>
- Pendientes: #<n> <qué necesita ADR>

## Instalación
- Smoke: <verde, rojo (qué falló) o "sin instalación"> · <qa.url>

## Notion desalineado
- <tarea o hito> · <qué dice Notion> → <qué dice el repo>

## Qué clickear
1. <en dónde, qué hacer y qué se debe ver>
2. <…>
3. <…>
