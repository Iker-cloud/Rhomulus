# Mapa 1 — Morro Esperanza, barrio de Rhomulus (diseño)

Estado: **diseño base cerrado el 7 de octubre de 2026**, con las decisiones de Iker. Lo marcado como *propuesta* no está confirmado. Referencia de aspecto: **Brasil** (ver "Referencia de aspecto"). No se construye antes del viernes 9 (alcance congelado); es el diseño para la siguiente fase.

Juego: **Rhomulus** (nombre de trabajo, falta confirmarlo con Isaac) · Ambiente: **apocalipsis latinoamericano**.
**Rhomulus es la ciudad.** Este primer mapa es uno de sus barrios.

## Lo decidido

| Tema | Decisión |
| --- | --- |
| Ciudad | Rhomulus |
| Barrio | **Morro Esperanza** |
| Refugio final | **Refugio Remo** (el gemelo de Rhomulus: Rómulo y Remo) |
| Idioma de carteles y textos | **Solo español** |
| Altura (escaleras y azoteas) | **Después**: primero todo a nivel de calle; las escaleras y azoteas se añaden luego |
| Tamaño del mapa | Unos **800 studs de largo × 240 de ancho** (ver "Tamaño") |
| Lugar | Barrio popular / colonia (casas de colores, tiendas de barrio, tendederos, murales, calles estrechas, buses) |
| Forma | Mapa abierto con **3 rutas por tramo**, que se juntan en cada punto seguro. **Ninguna ruta se bloquea**, ni con 1 jugador |
| Estructura | **3 tramos y 2 puntos seguros** (partida de 10 a 15 minutos) |
| Hitos | Mercado o tienda de barrio · plaza con iglesia · estación de buses / terminal · estadio o cancha de fútbol |
| Historia | **Pistas sueltas**: carteles, grafitis y la radio del comandante cuentan qué pasó, sin texto largo |
| Evento nuevo | En el **mercado**: **"Las garrafas"** (confirmado) |
| Extracción | **En el estadio**: la van entra por la puerta hacia la cancha |
| Generador | **Se mantiene** (el evento del mercado se suma, no lo reemplaza) |
| Caja de armas | **Una por ruta** (3 por tramo), para que todas las rutas tengan recompensa |
| Botiquín | **Entra** en este mapa (estaba recortado del MVP); cantidades en "Botiquines" |
| Orientación | **Indicaciones grandes y visibles** para no perderse (confirmado, ver "Guía para no perderse") |

## Recorrido (propuesta de nombres y orden)

```
 LOBBY ──▶ TRAMO 1: El barrio ──▶ PUNTO SEGURO 1: la tienda ──▶ TRAMO 2: La plaza y el mercado
                                                                        │
   TRAMO 3: La terminal y el estadio ◀── PUNTO SEGURO 2: la iglesia ◀──┘
        └──▶ EXTRACCIÓN en la cancha (radio + van)
```

Cada tramo tiene **3 caminos** entre su principio y su punto seguro. Todos llevan al mismo punto y la puerta siguiente solo se abre cuando todos están dentro (como hoy).

### Lobby — la cochera
Cuarto cerrado al inicio, como el de hoy. Los maniquíes para practicar. Una cochera o taller con una radio y un mapa del barrio pegado en la pared (ahí empieza la guía de rutas).

### Tramo 1 — El barrio
Calles estrechas entre casas de colores. Enseña los controles.
- **Calle principal:** ancha, más zombies, una caja de armas.
- **Callejón de los murales:** estrecho, hordas cortas, latas sueltas.
- **Cancha de barrio / pasaje:** abierta, más recursos pero se ve desde lejos.
- Obstáculos: autobús escolar volcado, carros chocados, puestos ambulantes, tendederos y cables.

### Punto seguro 1 — La tienda de barrio
Tienda con reja metálica. Recarga gratis, munición para comprar y **botiquín**. Un cartel y una radio dan la primera pista de la historia.

### Tramo 2 — La plaza y el mercado
Zona de combate más grande: la plaza con la iglesia al fondo.
- **Cruzar la plaza:** espacio abierto, hordas grandes, sin cobertura.
- **Por el mercado cubierto:** pasillos y puestos, combates cortos y cercanos. Aquí está el evento.
- **Por detrás de la iglesia:** atrio y escaleras, camino largo pero tranquilo.
- Aquí también va el **generador** (se mantiene, con su horda y su portón).

### Punto seguro 2 — La iglesia
Interior de la iglesia. Recarga gratis, munición, botiquín y la segunda pista. Descanso antes del final.

### Tramo 3 — La terminal y el estadio
Estación de buses con buses chocados como obstáculos, y al fondo el estadio.
- **Terminal por el centro:** buses chocados, muy cerrado.
- **Por la avenida lateral:** abierta, hordas más largas.
- **Por los andenes:** pasillos largos con pocas salidas.
- Zona más tensa, con el **Tanque** y las hordas más fuertes.
- **Extracción:** la radio en la tribuna, y la van entra por la puerta del estadio hacia la cancha. Se aguanta la horda continua hasta que llega.

## Eventos

| Evento | Dónde | Cómo funciona |
| --- | --- | --- |
| **Generador → horda → portón** | Plaza (tramo 2) | Se mantiene como hoy |
| **Las garrafas** *(nueva)* | Mercado (tramo 2) | Ver abajo |
| **Radio → aguantar → van** | Estadio (tramo 3) | Se mantiene, con el estadio como escenario |

### Las garrafas (evento nuevo del mercado, confirmado)
En el mercado hay **3 garrafas de gas** repartidas por distintos puestos. Hay que llevarlas **cargadas** hasta el camión de reparto que abre la reja del mercado.
- Quien carga una garrafa camina lento y solo usa la pistola (igual que cuando carga a un compañero: **se reutiliza esa mecánica**).
- Los demás lo cubren. Cada vez que alguien deja una garrafa en el camión, llega una pequeña horda.
- Con 3 garrafas entregadas se abre la reja y se activa el siguiente tramo.
- Con 1 jugador, las lleva de una en una.
- **Por qué:** refuerza "nadie se queda atrás" (cargar, cubrir al que carga) y casi no necesita código nuevo.

## Guía para no perderse

Con 3 rutas, hay que dejar siempre claro **hacia dónde ir** y **qué ruta conviene**. Propuesta (todo grande y visible, nada discreto):
1. **Marcador de objetivo siempre visible:** una columna de luz en el mundo y una **flecha grande en pantalla** (en el borde, apuntando al objetivo) con la distancia en metros. Cambia con la etapa: siguiente punto seguro, generador, camión de las garrafas, radio, van.
2. **Flechas pintadas en el suelo y carteles** en cada bifurcación, con el nombre y el color de cada ruta ("→ MERCADO", "→ CALLEJÓN"), pintadas a mano para quedar en el estilo del barrio. Las flechas del suelo son grandes y brillan un poco.
3. **Un color por ruta** (por ejemplo rojo, amarillo y azul), repetido en el cartel, la flecha y un tramo de pared cada pocos pasos, para saber que se sigue en la misma ruta.
4. **Balizas en los puntos seguros:** una luz alta y visible desde lejos, para que siempre se sepa dónde está el refugio.
5. **La radio del comandante** repite el objetivo con frases cortas ("Sigan hacia la plaza").
6. **Brújula en la parte de arriba** con las marcas del objetivo (opcional).

Todo esto se apaga o se achica fácilmente desde `Config` para ajustarlo al gusto.

## Referencia de aspecto: Brasil

Idea: un barrio al estilo de las favelas y barrios populares de Brasil, mezclado con el tono latinoamericano que ya tiene el juego.
- **Casas apiladas y de colores** subiendo por una colina, con escaleras largas, azoteas y pasarelas. (Da altura y rutas: calles de abajo, escaleras y azoteas.)
- **Mercado** de feria: puestos de lona, cajas de fruta, toldos de colores.
- **Terminal** de buses con buses urbanos de colores y motos tiradas.
- **Campo de fútbol** de barrio de tierra y un **estadio** grande al fondo.
- **Iglesia** de barrio con muros blancos y campanario.
- Detalles: cables y antenas, ropa tendida, motos taxi, grafitis, carteles pintados a mano (en español).
- **Idioma:** todo en español, sin portugués en los carteles.
- **Altura:** primero se construye todo a nivel de calle; las escaleras y azoteas (y con ellas la ruta "Escalera" con altura real) se añaden en una segunda pasada. Hasta entonces la ruta azul es un camino de escaleras y pasajes a nivel del suelo.

## Nombres propuestos

**El barrio** (Rhomulus es la ciudad) — elegido: **Morro Esperanza**; las demás opciones quedan como alternativas:
| Nombre | Idea |
| --- | --- |
| **Morro Esperanza** (recomendado) | "Morro" es la colina del barrio, "Esperanza" suena a refugio; mezcla español y portugués |
| Vila Esperança | Más brasileño, mismo significado |
| El Cerro de las Luces | Pensado para las balizas y la guía de luces |
| Barrio Tejado Rojo | Por los techos de colores |
| Morro de los Santos | Por la iglesia y los santos pintados |
| La Cuesta | Corto, fácil de recordar |

**El refugio final** — elegido: **Refugio Remo**:
| Nombre | Idea |
| --- | --- |
| **Refugio Remo** (recomendado) | Rómulo y Remo: Rhomulus es la ciudad de Rómulo, y Remo es el refugio gemelo |
| El Faro | Una luz que guía; encaja con la guía de luces |
| Casa Madre | Lugar de reunión de los sobrevivientes |
| Puerto Seguro | Idea de salida y rescate |
| El Estadio | El rescate sale por la cancha |

**Las 3 rutas** (un color cada una): propuesta "Calle" (rojo), "Callejón" (amarillo), "Escalera" (azul), y se repiten en los tres tramos con el mismo color.

**Tramos y puntos seguros** (propuesta): Tramo 1 "La Cuesta", punto seguro 1 "La Tienda de Doña ...", Tramo 2 "La Plaza y la Feria", punto seguro 2 "La Iglesia", Tramo 3 "La Terminal y el Coloso" (el estadio).

## Botiquines (confirmado como punto de partida; se balancea en pruebas)

Un botiquín cura 80 de vida en 5 s (uno mismo o un compañero).
- **Punto seguro:** 2 botiquines cada uno (4 en total).
- **Tramo 1:** ninguno (es el tramo de aprendizaje).
- **Tramos 2 y 3:** 1 por ruta (6 en total), en la mitad del camino.
- Total: unos 10 por partida; se ajusta con las pruebas (con 1 o 2 jugadores se pueden quitar los de ruta).

## Tamaño del mapa (recomendación)

**Unos 800 studs de largo × 240 de ancho** (hoy son 500 × 140).
- **Tiempo:** caminando a 16 studs/s, cada tramo de unos 250 studs son 16 s sin pelear; con zombies, paradas, cajas y eventos se vuelven 2 o 3 minutos por tramo. Con 3 tramos, 2 puntos seguros y la extracción de 150 s, la partida cae en 10 a 15 minutos.
- **Rutas:** 240 de ancho deja unos 60 a 70 studs entre rutas, suficiente para que se sientan distintas y para que el equipo se vea y se junte con facilidad.
- **Reparto aproximado a lo largo:** lobby 50 · tramo 1 220 · punto seguro 1 40 · tramo 2 250 · punto seguro 2 40 · tramo 3 200 (incluye el estadio).
- **Rendimiento:** unas 2.5 veces más superficie que hoy. Activar `StreamingEnabled`, pocos modelos reutilizados, decoración sin colisión y comprobar los FPS en celular a mitad de construcción.
- **Si resulta grande:** se puede recortar el ancho (a 200) o un tramo sin cambiar el diseño.

## Pistas y ambientación (apocalipsis latinoamericano)

- Carteles pintados a mano, grafitis, murales, rótulos de tiendas ("Abarrotes Don ..."), avisos de la alcaldía.
- Radio del comandante con jerga local; pistas sueltas en cada punto seguro.
- Frases de revivir y avisos en español de la región (lista pendiente).
- Sonido ambiente: radio lejana, perros, campanas, cumbia o música de tienda rota.

## Lista de objetos y modelos (para construir)

- Casas de colores (pocos modelos reutilizados con colores distintos), tendederos, puestos ambulantes.
- Autobús escolar, buses de terminal, carros chocados, camión de reparto.
- Iglesia (fachada, atrio e interior), mercado cubierto, tienda de barrio con reja, tribuna y puerta del estadio.
- Garrafas de gas (3), botiquines, columnas de luz y flechas.
- Carteles y grafitis (texturas reutilizadas).
- Los modelos propios que ya existen (zombies, armas, cajas, generador, radio, furgoneta) se mantienen.

## Notas técnicas

- El mapa hoy se genera por código en bloques grises (`MapBuilder`: una sola calle recta de 500 studs con 5 tramos). Con 3 rutas por tramo hay que rehacer el trazado y comprobar que los zombies encuentran camino (`PathfindingService`) por todas.
- Primero se construye el **mapa gris** con la forma nueva y se prueba que sea divertido; después el pase de arte (regla del GDD).
- La guía necesita saber el **objetivo actual**: `GameState` ya conoce la etapa, solo habría que publicar la posición del objetivo para que el cliente dibuje la flecha y la luz.
- El evento de las garrafas reutiliza la mecánica de cargar (`Revive`: velocidad lenta, solo pistola) con otro objeto, y la horda del generador (`Director`).
- El botiquín (80 de vida en 5 s, uno mismo o un compañero) es un sistema nuevo; hay que construirlo.
- Rendimiento: meta de 30 FPS en celular. Activar `StreamingEnabled`, decoración anclada y sin colisión, y texturas reutilizadas.
- El director de hordas necesita puntos de aparición por tramo y por ruta; los números siguen saliendo de `Config.Director.ByPlayers`.

## Preguntas abiertas

1. ¿Confirmas los nombres de tramos y puntos seguros propuestos ("La Cuesta", "La Plaza y la Feria", "La Terminal y el Coloso") o prefieres otros?
2. ¿Cómo se llama la tienda del punto seguro 1 (por ejemplo "Abarrotes Doña ...")?
3. ¿Quieren que la guía (luces y flechas) se construya antes que el mapa nuevo, para probarla en el mapa actual?
