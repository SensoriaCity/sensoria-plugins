# Evaluar con navegador

Lo lee el `evaluator` antes del primer paso de UI. El kit no fija qué navegador hay ni cómo se llaman sus herramientas: usa **las herramientas de navegador de la sesión**.

## Cuáles son

- Son las que terminan en `browser_<acción>`: `…browser_navigate`, `…browser_snapshot`, `…browser_click`, `…browser_tabs`, `…browser_take_screenshot` y las demás. El prefijo cambia según quién levantó el navegador (el servidor `playwright` del kit, u otro servidor de navegador que la sesión ya tenía): no lo supongas, mira la lista de herramientas que tienes y usa las que haya.
- Nunca `…browser_evaluate` ni `…browser_run_code_unsafe`, aunque la sesión las traiga: ejecutan código arbitrario.
- Como subagente `city:evaluator` recibes solo las de la lista `tools` de `agents/evaluator.md`: las del servidor `playwright` del kit, sin `…browser_resize` ni `…browser_close`. Cuando el rol lo corre una sesión con otro servidor de navegador, se usan sus herramientas equivalentes (la misma `browser_<acción>` con otro prefijo) y valen las mismas reglas; lo que esa sesión traiga de más (redimensionar, cerrar el navegador) se usa solo como dice la tabla de abajo.
- Si no hay ninguna herramienta de navegador, los pasos de UI quedan `no verificado: la sesión no tiene herramientas de navegador` y lo dices en "Entorno y limitaciones". No los reemplazas por `curl` contra el HTML.

## Navegador propio o compartido

Al empezar, lista las pestañas (`…browser_tabs`). Si ya hay pestañas que no abriste, el navegador es **compartido**: lo usa una persona u otra sesión. Si no hay ninguna, es **propio**.

| | Propio (lo abrió tu sesión) | Compartido |
|---|---|---|
| Dónde trabajas | En la pestaña que hay | En una pestaña nueva que abres tú; nunca navegas en una ajena |
| Al terminar | Cierras tus pestañas (`…browser_tabs`); el navegador, solo si la sesión trae `…browser_close` | Cierras solo tu pestaña. Nunca la última que quede, nunca una ajena, nunca el navegador |
| Ancho angosto (390 px) | Solo si la sesión trae `…browser_resize`: lo pruebas en pantallas nuevas y vuelves al ancho anterior | No redimensionas: la ventana es de otro. Queda en "Entorno y limitaciones" como `390 px: no verificado, navegador compartido` |
| Capturas | Borras la carpeta temporal de capturas de tu slot al terminar | Borras solo los archivos que escribiste |

Si la sesión no trae `…browser_resize` (el subagente del kit no la trae), o el `CLAUDE.md` del repo o la persona prohíben redimensionar, el ancho angosto no se prueba y queda dicho: `390 px: no verificado, <motivo>`. No es un paso del corte: no cambia el veredicto, pero no se calla.

## Capturas

- **Una o más por paso.** El nombre es `<id>-paso<n>.png` y, si un paso necesita varias, `<id>-paso<n>-<detalle>.png` (`m28-h01-s02-paso3-lista.png`, `…-paso3-recarga.png`): el detalle, en minúsculas y con guiones, dice qué muestra.
- **Dónde.** En la carpeta que diga quien llama (`capturas: <carpeta>` en la línea de entrada del evaluador), que queda fuera del repo y no se borra al terminar. Sin ella, en el temporal del servidor de navegador (el del kit, una carpeta por slot), que sí se borra. Nunca dentro del repo.
- La tabla de la evidencia nombra las capturas de cada paso por su archivo; la evidencia no las incrusta.

## Cómo se prueba

- **Vuelve a leer antes de decidir.** Después de cada acción que vuelve a pintar la pantalla (un clic que guarda, un filtro, abrir o cerrar un modal, una navegación), toma otra lectura (`…browser_snapshot`) antes de decidir o de hacer el siguiente clic. Las referencias de elementos de la lectura anterior caducan: un clic con una referencia vieja falla o cae en otro elemento. Si la pantalla carga algo, espera el texto que debe aparecer (`…browser_wait_for`) y luego lee; no esperes un tiempo fijo.
- **Decides con la lectura, no con la captura.** La lectura (el árbol de accesibilidad) es la evidencia; la captura es para personas.
- **Llega por la navegación, una vez por pantalla.** La primera vez que vas a una pantalla, llegas como un usuario: menú, enlace o botón. Eso prueba que el punto de entrada existe. Las veces siguientes puedes ir por URL directa.
- **Una lista con scroll se captura completa o se cita.** Una captura que corta la lista no demuestra lo que quedó fuera. Expande la lista (captura de página completa, o del elemento) o cita en la tabla la lectura textual de las filas que cuentan.
- **Dato guardado:** recarga y vuelve a leer. El aviso de "Guardado" no es el resultado.
- **Antes de salir de cada página:** errores de consola (`…browser_console_messages`) y respuestas 4xx o 5xx inesperadas (`…browser_network_requests`). Un error de consola en una pantalla del corte hace que no pase, salvo el **ruido del entorno**: el que también ocurre en la rama principal, sin el corte. Lo es si `docs/harness/entorno.md` del repo lo lista como conocido, o si sale igual en una pantalla que el diff no toca (un recurso de desarrollo que no carga, un aviso de una extensión o del servidor local). Se declara en "Entorno y limitaciones", con el texto del error y cómo comprobaste que no es del corte. Si no puedes comprobarlo, cuenta.
- **Romper a propósito no se hace desde aquí.** Para ver fallar una prueba de regresión no se arma una copia del repo, y nunca una con enlaces a sus carpetas de dependencias: un enlace que se borra mal se lleva la carpeta real. Lo hace quien construye, en su rama, y lo declara en el PR con la salida de la prueba fallando. El evaluador solo lo repite si el repo da un comando para ello (`tests.mutation` de `.city.json`, o lo que diga `docs/harness/entorno.md`); si no, lo declara como no hecho.
- **Credenciales:** nunca en una captura con el formulario lleno.
