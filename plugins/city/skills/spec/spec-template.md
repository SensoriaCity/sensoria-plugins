# <Hito> · spec

Aplicativo: <aplicativo> · Módulo: <mod-NN-slug> · Hito: <URL de la definición> · Fecha: <AAAA-MM-DD>

## Problema
<De 2 a 4 líneas: quién, qué pasa hoy y por qué importa.>

## Resultado
<Qué ve o qué cambia cuando entra el último corte.>

## Lo que encontré en el código
<Las referencias de la definición, confirmadas o corregidas, y lo que la definición no nombraba. Una línea cada una, con `archivo:línea`.>

## Valores y unidades
<Solo si el hito mueve dinero, cantidades o fechas: cada campo, qué significa, en qué unidad va y de dónde sale. Ej.: "iNvalorInf1: valor base del comparendo, pesos enteros, tickets.price sin el doble de la fuga". O "no aplica".>

## Escalera
| Parte | Cortes | Escalón | Por qué |
|---|---|---|---|
| <A · nombre> | <s01–s07> | <1 a 4> | <qué esconde y por qué ese escalón alcanza> |

Flag: <nombre, qué esconde, dueño (persona o equipo, según la receta `flags`), fecha de retiro (la que fije la receta `flags`; si no la fija, la del PR de Spec + 60 días; se ajusta en el PR del último corte) y el corte que lo retira; o "ninguno">.
Primer tramo: <ids> — <qué ve una persona cuando entran>.

## Fuera de alcance
- <Lo que no entra, y a dónde va (otro hito, hotfix aparte).>

## Supuestos
- <Lo que se decidió sin preguntar.>

## Preguntas abiertas
- <Lo que necesita a una persona, quién responde y qué corte bloquea (el mismo texto de su `blocked_by`), o "ninguna".>

## Decisiones tomadas
<Solo si la spec cambió después de mezclada, con `/city:spec revise`; una entrada por decisión, numerada o con viñeta, con fecha, quién, qué cambia y cortes. Una decisión nueva va al final: no se borran ni se reordenan. En una spec nueva la sección no va.>
1. <AAAA-MM-DD> · <quién decidió, persona y rol> · <qué cambia> · cortes: <ids>

## Contratos y ADR
<Interfaces, esquemas o API compartidas que cambian y el ADR que las cubre, o "ninguno".>

## Cortes

| # | id | Clase | Comportamiento | Cubre | Pasos | Escalón | Estimación | Depende de |
|---|---|---|---|---|---|---|---|---|
| 1 | <id> | <slice/data/platform> | <una frase> | <CA, RG> | <n> | <1 a 4, o —> | <líneas> de <line_limit> | <ids o —> |

### <id> · <comportamiento>
- Toca: <archivos reales>
- Migraciones: <qué crea y su reversa, y por qué `main` la tolera; solo en clase `data`>
- No decide solo: <o "nada">
- Estimación: <código + pruebas>

Los pasos de cada corte están en `slices/<id>.json`.

## Después
- <Lo que queda para otro hito, o "nada".>
