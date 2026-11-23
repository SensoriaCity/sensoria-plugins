## Qué decide esta spec
<Dos o tres frases: el hito, qué cambia para quién y cómo se esconde lo incompleto.>

- Spec: `<apps_dir>/<aplicativo>/<modulo>/<hito>/spec.md` (PR de clase `spec`: sin código)
- Cortes: `<hito>/slices/` (<n> archivos, todos con `passes: false`; `check-spec.sh` en verde)
- Definición funcional: <URL o ruta>

## Cortes
| # | id | Clase | Comportamiento | Estimación | Escalón | Depende de |
|---|---|---|---|---|---|---|
| 1 | <id> | <slice/data/platform> | <una frase> | <líneas> | <1 a 4, o —> | <ids o —> |

- Se despliegan juntos (`ships_with`): <id> no llega a producción sin <ids>, y por qué; o "ninguno".

## Primer tramo
<Ids y lo que una persona ve cuando entran: dónde, con qué permiso y si hay que encender un flag.>

## Migraciones
<Por corte de clase `data`: qué crea, su reversa y por qué el código de `main` la tolera. O "ninguna".>

## Flag
<Nombre, qué esconde, dueño (persona o equipo, según la receta `flags`), fecha de retiro (la que fije la receta `flags`; si no la fija, la de este PR + 60 días) y el corte que lo retira. O "ninguno" y por qué alcanza un escalón más barato.>

## Lo que el código contradijo de la definición
- <referencia de la definición → lo que hay en el código, con `archivo:línea`; o "nada">

## Preguntas para quien aprueba
1. <pregunta> — bloquea <corte o "nada">; propuesta: <la lectura más razonable>.

## Cortes bloqueados
- <id> · <`question`> · responde <`owner`> · desde <`blocks_since`>; o "ninguno". En un PR de desbloqueo: <id>, la respuesta y quién la dio.

## Revisión
<Solo en un PR de `/city:spec revise <hito>`; en una spec nueva, un `split` o un `unblock`, borra la sección. En una revisión, las secciones de arriba describen solo lo que cambia.>

Decisión <n>: <AAAA-MM-DD> · <quién decidió, persona y rol> · <qué cambia y por qué>. Es la misma entrada de "Decisiones tomadas" de `spec.md`, con su número.

| id | Antes | Ahora |
|---|---|---|
| <id de un corte editado> | <lo que decía: pasos, dependencias, estimación> | <lo que dice> |
| <id de un corte reemplazado> | pendiente | reemplazado por <ids>: <por qué ya no hace falta> |
| <id de un corte nuevo> | no existía | <comportamiento, clase, estimación, depende de; `covers` con `decision:<n>` si lo que cubre sale de la decisión> |
| <id de un corte que la decisión nombra y deja igual> | <lo que dice> | sin cambios: <por qué la decisión no lo toca> |

Las filas `sin cambios` son opcionales: van cuando quien aprueba podría preguntar por ese corte. Un corte con `passes: true` solo puede ir así.

- Cortes con `passes: true`: ninguno cambia (`check-spec.sh <hito> <line_limit> --base origin/main` en verde).
- Estimaciones medidas (`estimate_basis: measured`): <id> · rama `<rama>` · <líneas que da `size.sh origin/main --ref <rama>`> + <lo que suma la decisión> = <estimated_lines>; o "ninguna".
- Ramas y PR abiertos de cortes tocados: <rama o #PR y qué tiene que hacer su dueño (tomar `main` y seguir con `/city:build <id>`)>; o "ninguno".

## Para aprobar
Quien aprueba el hito revisa que cada corte sea un comportamiento que se prueba solo, que las migraciones vayan antes y sean aditivas, y que el escalón de cada parte sea el más barato que alcance. Al aprobar, el primer tramo se construye con `/city:goal <ids en orden>`.
