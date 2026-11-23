# Cortes de clase `data`

Lo leen `/city:build`, el `reviewer` y el `evaluator` cuando el `class` del corte es `data`: migraciones con su reversa, permisos sin asignar o un cambio de datos. El kit no sabe qué motor de base usa el repo. **Motor real** es el que corre en producción; los comandos salen de `.city.json` y de `docs/harness/entorno.md` del repo, nunca de este archivo.

## Tres bases, y cómo saber cuál está activa

| Base | De quién es | Qué se puede hacer |
|---|---|---|
| De desarrollo | De la persona o compartida por el equipo | Nada de lo de abajo: ni subir ni bajar la migración del corte, ni alterar filas. |
| De la instalación de QA | La levanta `qa.install` y la baja quien la creó | Subir, bajar y volver a subir la migración; alterar filas marcadas. |
| Desechable | La crea y la borra `tests.database`, o la receta del repo | Lo mismo, y es donde corren las pruebas de migración. |

- Nadie lee `.env`. El motor y el nombre de la base activa se le preguntan a la app, con el comando del repo que los imprime (su consola o su CLI; lo nombra `docs/harness/entorno.md`). Si el repo no dice cómo, se dice y se para: no se deduce de archivos con secretos.
- Antes de subir o bajar una migración, o de alterar una fila, confirma con ese comando que la conexión activa es la de QA o una desechable y que su motor es el real. Si es la de desarrollo, una compartida o producción, o no se puede saber, no se ejecuta.
- Dos nombres de driver del mismo motor (el de una bifurcación compatible, por ejemplo) cuentan como el mismo motor solo si la migración los trata igual: una condición que nombra un solo driver deja al otro sin migrar.

## La prueba de la migración

1. **Contra el motor real, desde "prueba primero".** La prueba se escribe antes que la migración y se ve fallar en el motor real; no se deja para la instalación del evaluador.
2. **`tests.database`** de `.city.json` (opcional) es el comando que corre las pruebas de migración contra el motor real en una base desechable que él mismo levanta y borra; recibe al final los argumentos del runner para acotar a una prueba. Con la clave, quien construye lo corre en los pasos 4 y 6 de `/city:build`, y el `reviewer` y el `evaluator` lo corren literal.
3. **Sin `tests.database`,** nadie inventa un comando ni apunta la suite a otra base. El reporte de build y el PR dicen `Sin tests.database: la migración no tiene prueba automática contra el motor real`, y la evidencia manual del `evaluator` es la que cuenta.
   **No es lo mismo que "hoy no hay motor disponible".** Si la clave existe y el comando no pudo correr (Docker apagado, falta la imagen, un puerto ocupado), la prueba existe y no corrió: es un problema de la máquina, no del repo. Se dice `tests.database no corrió: <motivo>`, nunca `Sin tests.database`, y nadie decide por su cuenta que la evidencia manual la reemplaza. Quien construye se detiene y lo dice; el `reviewer` anota `no corrido: <motivo>` y deja el paso pendiente; el `evaluator` verifica el paso a mano en la base de QA si su motor es el real, y dice en "Entorno y limitaciones" de la evidencia que la prueba automática no corrió y por qué. Si tampoco hay motor real en QA, el paso queda `no verificado`.
4. **Si la suite general corre en otro motor** donde la migración no aplica, la prueba se omite ahí con el mecanismo de omisión del runner (o el que diga la receta del repo) y el motivo a la vista. No es saltar una prueba: nace así y corre con `tests.database`.
5. **Nunca** una tautología (afirma algo que es cierto con la migración y sin ella), ni comparar el texto del archivo de la migración, ni una prueba que corre solo en el motor donde la migración no hace nada. Una prueba que no puede fallar por el cambio del corte cuenta como ausente.
6. **Qué prueba:** que sube, baja y vuelve a subir; que las filas que ya existían siguen ahí y válidas después de subir y después de bajar; que el código de `main` sigue funcionando con la migración arriba; y **el modo simulado**. Si el migrador del repo puede correr una migración sin ejecutarla (imprime lo que haría), la del corte también corre así, al subir y al bajar: termina sin error, no cambia el esquema ni una fila, y lo que imprime es lo que haría de verdad. Ese modo no ejecuta las lecturas: una migración que decide leyendo la base (cuenta filas, mira si existe una columna, recorre registros) ahí recibe vacío y falla, o imprime otra cosa. Es el modo en que alguien la revisa antes de un despliegue, y un defecto así pasa todo lo demás de esta lista. Si el migrador no tiene modo simulado, se dice y no se inventa.

## Qué demuestra un paso

Subir y bajar una migración es un paso manual por naturaleza. En un corte de clase `data`, un paso queda demostrado por **una** de dos:

- una prueba que corre contra el motor real y falla sin el cambio, o
- la evidencia del `evaluator` sobre el commit vigente (`passes.sh <id> --check` sale con 0), con el comando y el final de su salida en la tabla.

Si el `reviewer` corre antes que el `evaluator`, un paso sin prueba contra el motor real no bloquea: lo reporta como `debería`, pendiente de esa evidencia. El PR no queda listo sin ella: `/city:ship` exige el veredicto vigente del `evaluator`.

## Datos y limpieza

- Las filas que haga falta crear o alterar se marcan con `QA-CITY` donde el modelo tenga un campo de texto libre. Si no lo tiene, no se fuerza la marca en un campo con formato: se identifican por su id y se declaran en la evidencia ("Datos creados": tabla e ids), para poder limpiarlas.
- Al terminar, la base queda con la migración arriba (el último paso del corte) y sin las filas marcadas. Lo que no se pudo limpiar se dice en la evidencia.
- Nunca se reinicia, vacía ni restaura la base entera ni se borran volúmenes, tampoco en un corte de clase `data`.

## Dónde va la evidencia de quien construye

En el cuerpo del PR ("Migraciones" y "Pasos y evidencia" de la plantilla): los comandos que corrió y el final de su salida, una sola vez. No hay archivo para ella: en `evidence/` del hito vive solo `<id>.md`, que escribe el `evaluator`.
