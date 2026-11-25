## Qué hace
<Una o dos frases: qué comportamiento nuevo existe y dónde.>

- Clase: <`slice`, `data` o `platform`> · escalón <1 a 4, o "no aplica">
- Corte: `<file que da slice.sh>` · spec: `<spec.md del hito>`
- Corrección de un corte ya mezclado: <qué estaba mal y en qué PR entró; la evidencia se renueva en este PR; o borra la línea>
- Despliegue: <por cada `ships_with` pendiente, no desplegar hasta que entre <id> (#PR o "sin PR todavía"); y la línea "Despliegue" de la sección del corte en la spec, literal (qué se hace en cada ambiente antes de que llegue el código); o borra la línea si no hay ninguna de las dos>
- Plan del día: <ruta, o "sin plan">
- ADR: <ruta, o "no aplica">
- Flag: <nombre y si este corte lo crea, esconde algo detrás de él o lo retira; si es el último corte del hito, la fecha de retiro ajustada; o "no aplica">
- Migraciones: <qué crean, su reversa y por qué `main` las tolera; contra qué motor se probaron y con qué, `tests.database` o a mano; solo en clase `data`>

## Pasos y evidencia
Una fila por paso. Va una sola vez: no se repite abajo ni en otra sección.

| Paso | Prueba o comando de quien construyó | Final de su salida | ¿Regresión? |
|---|---|---|---|
| 1 | <prueba o comando> | <pasa, con la última línea de la salida> | <no; o "sí: pasa antes y después, y falla al romper <qué>"> |

```
<final de la salida de cada comando de tests y de size.sh, una vez cada uno>
<por cada prueba de regresión: qué rompió a propósito quien construyó, en su rama, y el final de la salida de la prueba fallando; después lo restauró>
```

## Apilado sobre #<N>
<Solo si una persona pidió apilar este corte sobre otro que aún no está en la rama principal; si no, borra la sección.>
- Lo pidió: <persona> · base: `<rama del corte base>` (#<N>)
- Tamaño contra la base: <salida de `size.sh origin/<rama del corte base>`>
- Evaluador: pendiente hasta que #<N> entre y esta rama tome la principal. Después: `git merge origin/main` (en un conflicto se conserva la versión de esta rama), `git diff --stat origin/main...HEAD` muestra solo este corte, y el PR cambia su base.

## Decisiones del ejecutor
- <qué y por qué, una línea cada una; o "ninguna">
- Archivos fuera de "Toca" de la spec: <archivo y por qué el corte lo necesita; lo juzga el revisor; o "ninguno">

## Veredictos
- Revisor (`city:reviewer`): <listo para merge, no mergear o espera decisión de <persona>> en <n> vuelta(s), sobre <sha corto>; o "pendiente: lo da <otra sesión o el check `revisor`>"; o "vencido: era de <sha corto>" si hubo commits de código después.
- Seguridad (`city:security`): <listo para merge o no mergear>; o "no aplica: el diff no toca autenticación, permisos, archivos, integraciones ni el CLI"; o "pendiente: <quién>".
- Evaluador (`city:evaluator`): <pasa o no pasa> en <n> vuelta(s), sobre <url local>. Evidencia: `<evidence que da slice.sh>`; o "pendiente: lo da <otra sesión>".
- Pendientes `debería` y `sugerencia`, y hallazgos medios y bajos del evaluador: <lista, o "ninguno"; o "aún no hay veredictos">

## Riesgos
- <datos existentes, permisos, integraciones, migraciones; o "ninguno identificado">
