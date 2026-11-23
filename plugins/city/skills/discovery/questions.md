# Cuestionamientos

Lo que suele quedar en el aire en una definición funcional. Recorre la lista contra cada regla y cada criterio; pregunta solo lo que el texto no responde, con el caso concreto del hito.

## Sobre cada regla de negocio

- **El caso contrario.** La regla dice qué pasa cuando se cumple. ¿Qué pasa cuando no? ¿Mensaje, bloqueo, nada?
- **El empate.** Si dos reglas o dos configuraciones aplican al mismo caso, ¿cuál gana?
- **El borde.** El día exacto en que vence el plazo, el valor cero, el registro sin el dato, la lista vacía.
- **Los plazos.** ¿Días hábiles o calendario? ¿Desde qué fecha exacta? ¿Qué calendario de festivos?
- **Los montos.** ¿Qué unidad, cómo se redondea, de dónde sale el valor y con qué fecha de vigencia?
- **La excepción.** ¿Algún tipo de registro, municipio o rol para el que la regla no aplica?

## Sobre los datos que ya existen

- **Lo que ya está guardado.** Si la regla cambia, ¿los registros anteriores se recalculan, se dejan como están o se migran? ¿A qué valor va cada uno y quién lo aprueba?
- **Lo que está a mitad de camino.** Un trámite que empezó con la regla vieja y termina con la nueva, ¿con cuál se rige?
- **Lo que se retira.** Si se quita un estado, un tipo o una opción, ¿qué pasa con los registros que lo tienen y con los reportes que lo filtran?

## Sobre las personas

- **Quién.** ¿Qué rol puede hacerlo y cuál solo puede verlo? ¿Hace falta un permiso nuevo?
- **Qué ve.** ¿En qué pantalla, con qué nombre y qué mensaje recibe cuando sale bien y cuando sale mal?
- **Deshacer.** Si se equivoca, ¿puede corregirlo? ¿Queda rastro de quién, cuándo y por qué?
- **El otro lado.** ¿Quién más se entera: el ciudadano, otra dependencia, una entidad externa (SIMIT, RUNT), un reporte?

## Sobre el alcance

- **La frontera.** De cada cosa que se deja fuera, ¿a qué hito va o no se hace?
- **La dependencia.** ¿Qué tiene que existir antes: otro hito, un módulo, una configuración, un dato cargado?
- **El insumo.** Archivos, tablas oficiales, textos legales, plantillas, prototipos, credenciales: ¿quién lo entrega, ya está, y qué criterios se frenan si no llega?
- **El encendido.** ¿Se libera para todos los municipios a la vez o uno por uno? ¿Quién decide cuándo?
- **La prueba.** ¿Con qué caso real se demuestra que quedó bien? Número de comparendo, fechas y resultado esperado.

## Sobre el texto

- **Palabras blandas.** "Según corresponda", "cuando aplique", "de forma organizada", "como hoy": pide el caso que lo vuelve concreto.
- **Un nombre, una cosa.** El mismo estado, campo o pantalla escrito de dos formas.
- **Cifras que no cuadran** entre el módulo, el hito y sus tablas.
