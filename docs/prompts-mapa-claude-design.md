# Prompts para construir el mapa 1 con Claude Design (por partes)

Estos prompts piden a Claude Design el mapa **Morro Esperanza** (barrio de Rhomulus, referencia Brasil) dividido en partes pequeñas, para que no se sature. Basados en `docs/mapa-1-barrio.md`.

## Cómo usarlos

1. Abre **una conversación nueva por cada parte** (así no se acumula contexto).
2. En cada una, pega **primero el "Prompt 0 — Documento maestro"** y **después** el prompt de esa parte.
3. Pide siempre las tres salidas: vista 3D interactiva, plano visto desde arriba y **lista de piezas en JSON** (ver Prompt 0). El JSON es lo que luego se convierte en piezas de Roblox.
4. Guarda lo que te devuelva con el nombre de la parte (por ejemplo `parte-03-tramo1-calle.json`).
5. Al final usa el **Prompt 15 — Ensamblaje y revisión**.

Orden recomendado: 0 → 1 → 2 → 3 → 4 … → 15.

| Parte | Contenido |
| --- | --- |
| 0 | Documento maestro (se pega siempre) |
| 1 | Kit de piezas repetibles |
| 2 | Lobby: la cochera |
| 3 | Tramo 1 — Ruta Calle (roja) |
| 4 | Tramo 1 — Ruta Callejón (amarilla) |
| 5 | Tramo 1 — Ruta Escalera (azul) |
| 6 | Punto seguro 1: la tienda |
| 7 | Tramo 2 — Ruta Calle: plaza y generador |
| 8 | Tramo 2 — Ruta Callejón: el mercado y las garrafas |
| 9 | Tramo 2 — Ruta Escalera: detrás de la iglesia |
| 10 | Punto seguro 2: la iglesia |
| 11 | Tramo 3 — Ruta Calle: la terminal |
| 12 | Tramo 3 — Ruta Callejón: la avenida lateral |
| 13 | Tramo 3 — Ruta Escalera: los andenes |
| 14 | El estadio y la extracción |
| 15 | Ensamblaje y revisión |

---

## Prompt 0 — Documento maestro (pegar al inicio de cada conversación)

```
Eres un diseñador de niveles y artista 3D de bajo polígono. Vas a diseñar, por partes, el mapa de un videojuego cooperativo de zombies para Roblox (1 a 4 jugadores). Todo lo que diseñes debe poder construirse en Roblox con piezas simples (cajas, cilindros y cuñas), sin texturas ni mallas.

JUEGO
- Nombre: Rhomulus (es la ciudad). Este mapa es uno de sus barrios: MORRO ESPERANZA.
- Género: acción cooperativa de zombies, estilo Left 4 Dead. El equipo cruza el mapa de un punto seguro a otro y termina en una extracción (una furgoneta entra al estadio a rescatarlos). Gana quien sube a la furgoneta.
- Ambiente: apocalipsis latinoamericano con inspiración en BRASIL (barrios populares y favelas). Es un barrio abandonado y semidestruido: casas de colores apiladas, cables, ropa tendida, motos tiradas, buses chocados, grafitis, carteles pintados a mano, vegetación que invade, ropa y cajas tiradas. TODOS los carteles y textos van en ESPAÑOL (no portugués).
- Cámara en tercera persona sobre el hombro. La partida dura 10 a 15 minutos.

ESCALA (muy importante). Unidad: STUD de Roblox.
- Avatar: 5.5 de alto y 2 de ancho. Salta 7 de alto. Corre a 24 studs/s y camina a 16.
- Vano de puerta transitable: 8 de ancho y 10 de alto. Pasillo mínimo transitable: 6 de ancho (los zombies miden 2 a 3 de ancho y el Tanque 5).
- Muro que NO se puede saltar: 12 de alto como mínimo. Cobertura baja: 3 a 5 de alto. Escalones o desniveles transitables: máximo 1 stud (o rampa de 25° como máximo).
- Referencias de tamaño: furgoneta de rescate 8.4 de ancho × 11.5 de alto × 22.6 de largo. Autobús: 8 × 11 × 30. Carro: 6 × 4.5 × 12. Moto: 2 × 4 × 6.
- Piso: nivel y = 0 en todo el mapa (la altura, con escaleras y azoteas, se añadirá en una segunda versión). No hay desniveles ni colinas todavía.

SISTEMA DE COORDENADAS
- X = lateral (de -120 a +120). Y = altura (suelo en 0). Z = avance del recorrido (de -400 a +400). El centro de la calle principal es x = 0.
- El frente de los vehículos y modelos mira hacia -Z.
- Medidas totales del mapa: 240 de ancho × 800 de largo.

DIVISIÓN DEL MAPA A LO LARGO (Z)
| Zona | Z desde | Z hasta | Largo |
| --- | --- | --- | --- |
| Lobby (cochera) | -400 | -350 | 50 |
| Tramo 1: el barrio | -350 | -130 | 220 |
| Punto seguro 1: la tienda | -130 | -90 | 40 |
| Tramo 2: la plaza y la feria | -90 | 160 | 250 |
| Punto seguro 2: la iglesia | 160 | 200 | 40 |
| Tramo 3: la terminal y el estadio | 200 | 400 | 200 |

TRES RUTAS POR TRAMO (cada una con un color que se repite en carteles, flechas y un tramo de pared)
- Ruta CALLE, color ROJO #D64545: carril central, x de -30 a +30. Calle ancha, más zombies, una caja de armas.
- Ruta CALLEJÓN, color AMARILLO #F2C94C: carril oeste, x de -110 a -45. Estrecho, hordas cortas, latas sueltas.
- Ruta ESCALERA, color AZUL #3B82F6: carril este, x de +45 a +110. Pasajes y escalones decorativos (a nivel del suelo), recursos extra.
- Entre rutas hay bloques de edificios (muros altos de 14 a 20) con un pasaje de cruce de 8 de ancho cada 70 studs aproximadamente, para poder cambiar de ruta.
- Las tres rutas SE JUNTAN en cada punto seguro (embudo hacia la puerta) y se vuelven a abrir después de él.

ESTRUCTURA DE LOS PUNTOS SEGUROS
- Edificio cerrado, con techo, de 60 de ancho × 40 de largo, con dos puertas de reja (entrada y salida) de 24 de ancho y 14 de alto, centradas en x = 0. Dentro: una zona de descanso de 30 × 26, 2 botiquines, una estación de munición y una radio con una pista.

ELEMENTOS DE JUEGO QUE DEBE HABER (reservar espacio)
- Puntos de aparición de zombies: callejones y huecos entre edificios, a 60 studs o más del equipo y fuera de su vista.
- Cajas de armas: 3 por tramo, una por ruta. Estación de munición: 1 por tramo, junto a la acera.
- Botiquines: 2 por punto seguro y 1 por ruta en los tramos 2 y 3.
- Pensar siempre en pasillos continuos de piso sin huecos, para que los zombies encuentren camino.

GUÍA PARA NO PERDERSE (en cada bifurcación)
- Un cartel grande pintado a mano con el nombre de la ruta y su color (por ejemplo "→ CALLEJÓN" en amarillo), una flecha pintada en el suelo de 6 × 2.5 con el color de la ruta y una franja de pared del mismo color a ambos lados de la entrada de cada ruta.
- En cada punto seguro, una baliza: poste o torre de 30 de alto con luz.

ESTILO VISUAL
- Bajo polígono. Solo cajas, cilindros y cuñas. Colores sólidos (nada de texturas). Reutiliza piezas idénticas.
- Paleta: terracota #C4572F, mostaza #E0A526, turquesa #2FA8A0, rosa salmón #E8836A, verde lima #9BC53D, azul cobalto #2F5DA8, blanco sucio #E9E4D6, concreto #8A8A86, óxido #8C4A2F, asfalto #3A3A40, acera #6B6B6F, lonas azul #2B6CB0 / naranja #E86A1C / verde #3E8E41, grafiti magenta #D6336C, tierra #8B6B43, pasto seco #6E7F3A.
- Cada edificio tiene un color base distinto, techo plano o de lámina (#8C4A2F o #8A8A86), puertas y ventanas como cajas hundidas de color oscuro, y 1 o 2 detalles (cables, antena, tanque de agua, ropa tendida, grafiti).
- Presupuesto de rendimiento: máximo 800 piezas por zona, máximo 25 formas distintas y todo lo demás repetido. Decoración pequeña sin colisión.

LO QUE DEBES ENTREGAR EN CADA PARTE (las tres cosas)
1. VISTA 3D INTERACTIVA en un solo archivo HTML (Three.js), con cámara orbital, cuadrícula en studs, y una figura de referencia de 5.5 de alto para ver la escala. Colores y piezas exactamente como en el JSON.
2. PLANO visto desde arriba, con ejes en studs, nombres de cada edificio y objeto, y flechas con el color de las rutas.
3. LISTA DE PIEZAS en JSON, una pieza por objeto simple, con este formato exacto:
   {"nombre": "T1_Calle_Casa_03", "tipo": "caja|cilindro|cuña", "tamaño": [x, y, z], "posicion": [x, y, z], "giroY": 0, "color": "#C4572F", "colision": true, "etiqueta": "edificio|suelo|cobertura|decoracion|puerta|cartel|aparicion|caja_armas|botiquin|municion|objetivo"}
   - "posicion" es el CENTRO de la pieza en studs, en coordenadas globales del mapa. "giroY" en grados.
   - Usa el prefijo de la parte en todos los nombres (por ejemplo T1_Calle_, PS1_, T2_Mercado_).
   - Marca con etiqueta "aparicion" los lugares de aparición de zombies y con "objetivo" lo que el jugador debe usar (generador, radio, garrafas, camión).

REGLAS DE TRABAJO
- Si no tienes un dato, pregúntame antes de inventarlo. No cambies las medidas ni los límites de arriba.
- Cuando termines una parte, haz una lista de comprobación: caminos continuos, anchos mínimos, alturas de muros, piezas totales y que nada atraviese otra pieza.
- Responde en español.

Espera mi siguiente mensaje con la parte concreta que debes diseñar.
```

---

## Prompt 1 — Kit de piezas repetibles

```
PARTE 1: KIT DE PIEZAS REPETIBLES.

Diseña un kit de piezas modulares que se reutilizará en todo el mapa. Cada pieza debe ser un grupo de cajas, cilindros y cuñas con medidas exactas (en studs), pocos elementos y colores de la paleta. Entrega cada pieza con su nombre, medidas totales, lista de piezas simples (formato JSON del documento maestro, con el origen de la pieza en el centro de su base) y una vista 3D de todas juntas en fila para compararlas con la figura de 5.5 de alto.

Piezas del kit:
1. Casa baja de barrio (16 × 9 × 14): 6 variantes de color y de detalle (puerta, 2 ventanas, tanque de agua, antena, ropa tendida, techo de lámina).
2. Casa de dos pisos (16 × 17 × 14): 4 variantes, con escalera exterior y balcón.
3. Edificio de tres pisos (24 × 26 × 18), 2 variantes, con comercio en planta baja.
4. Pared medianera lisa y pared con grafiti (largo 20 × alto 14 × grosor 1.5), 5 variantes con colores y grafitis simples (una mancha, una cara, una frase en español).
5. Puesto de feria (8 × 9 × 6): toldo de lona de 3 colores, mesa y cajas de fruta. 3 variantes.
6. Poste de luz con cables (alto 18) y tramo de cables entre postes (largo 30), caído y de pie.
7. Tendedero con ropa (largo 12, alto 8).
8. Carro chocado (6 × 4.5 × 12), 4 colores; autobús escolar volcado (8 × 11 × 30); bus de ciudad (8 × 11 × 30), 3 colores; moto tirada (2 × 4 × 6).
9. Contenedor de basura (4 × 4 × 3), barril (2 × 3), caja de madera (3 × 3 × 3), pila de cajas (6 × 6 × 6) y sacos de arena (4 × 2 × 4) como cobertura baja.
10. Reja metálica (largo 24 × alto 14 × grosor 0.6) abierta y cerrada, y puerta de reja doble de 24 de ancho.
11. Cartel grande pintado a mano (12 × 6 × 0.5) en 3 versiones, y flecha pintada en el suelo (6 × 0.1 × 2.5) en rojo, amarillo y azul.
12. Árbol seco (alto 14), arbusto (4 × 3 × 4) y maleza (2 × 1 × 2).
13. Baliza de punto seguro: torre de 30 de alto con luz en la punta.
14. Banca (6 × 3 × 2), farol de plaza (alto 12), kiosco pequeño (8 × 9 × 8).

Reglas: cada pieza con 5 a 40 formas simples; sin texturas. Indica para cada una si lleva colisión y cuál es su etiqueta.
```

---

## Prompt 2 — Lobby: la cochera

```
PARTE 2: LOBBY (LA COCHERA). Z de -400 a -350, X de -60 a +60.

Diseña un cuarto cerrado al inicio de la calle donde empiezan los jugadores. Es una cochera o taller de barrio al estilo brasileño.
- Edificio cerrado de 120 de ancho × 50 de largo y 20 de alto. Interior libre de 90 × 40.
- Una puerta enrollable hacia el sur del tramo 1 en z = -350, centrada en x = 0, de 30 de ancho y 14 de alto (se abre cuando empieza la partida). Una pared trasera sin salida.
- Dentro: 3 maniquíes de práctica (objetos de 6 de alto) en x = -8, 0 y 8, z = -388, cerca de la pared trasera y mirando hacia +Z, una radio sobre una mesa, un mapa del barrio pegado en la pared del fondo (cartel de 12 × 8 con el nombre "MORRO ESPERANZA" y las 3 rutas en rojo, amarillo y azul), cajas, herramientas, llantas, bidones, un carro viejo sin ruedas, un cartel "Cuidado con el perro" y otro "Aquí no se rinde nadie" pintados a mano.
- El jugador aparece en (0, 3, -375) mirando hacia +Z.
- Luz cálida de un foco colgado. Color base de las paredes: blanco sucio con una franja baja de terracota.

Entrega las tres cosas del documento maestro. Prefijo: LOBBY_.
```

---

## Prompt 3 — Tramo 1, ruta Calle (roja)

```
PARTE 3: TRAMO 1, RUTA CALLE (ROJA). Z de -350 a -130, X de -30 a +30 (calle) más aceras de 5 a cada lado (x de -35 a -30 y de +30 a +35).

Es la calle principal del barrio: ancha, con más zombies y una caja de armas. Enseña los controles.
- Piso de asfalto (#3A3A40) de 60 × 220 con aceras de 5 en #6B6B6F. Líneas de calle amarillas gastadas.
- Fachadas a ambos lados (x = ±35 a ±60): casas de dos pisos y edificios de tres pisos con colores distintos, pegados entre sí, con una puerta cada 20 studs. Las fachadas del lado oeste (x = -35) llevan una franja amarilla a 6 de altura y las del lado este una franja azul (marcan las otras rutas); las esquinas de la calle llevan una franja roja a 3 de altura.
- Obstáculos en la calle: 5 carros chocados repartidos con huecos de 10 o más para pasar, 1 autobús escolar volcado atravesado a medias en z = -250 (deja un paso de 12), puestos de feria abandonados, postes caídos con cables, contenedores y pilas de cajas como cobertura baja.
- Zonas de aparición de zombies (etiqueta "aparicion"): 4 en bocacalles y huecos entre edificios, a 60 o más del inicio.
- Caja de armas: 1 en una posición libre dentro de la calle (indica 3 lugares posibles).
- Estación de munición: 1 en la acera este, hacia z = -220.
- Carteles de guía: al inicio (z = -350) cartel grande "→ CALLE" en rojo con flecha en el suelo, y a la altura de cada pasaje de cruce los carteles de las otras rutas.
- Pasajes de cruce de 8 de ancho hacia el callejón (oeste) y hacia la escalera (este) en z = -310, -240 y -170.
- Al final (z = -150 a -130): la calle se estrecha en embudo hacia la puerta del punto seguro 1 (x de -12 a +12).

Prefijo: T1_Calle_. Entrega las tres cosas del documento maestro.
```

---

## Prompt 4 — Tramo 1, ruta Callejón (amarilla)

```
PARTE 4: TRAMO 1, RUTA CALLEJÓN (AMARILLA). Z de -350 a -130, X de -110 a -45.

Es el camino estrecho del oeste: callejones entre casas, hordas cortas y latas sueltas.
- Callejón principal serpenteante de 8 a 10 de ancho (nunca menos de 6), con 3 plazoletas más abiertas de 20 × 20 (en z = -300, -230 y -170).
- Casas bajas y de dos pisos pegadas con murales grandes en las paredes (grafitis de la paleta, caras, frases en español como "Esperanza", "Aquí vive gente").
- Detalles: tendederos cruzando de lado a lado a 9 de altura (sin colisión), tanques de agua en las azoteas, cables, escalones decorativos de 0.5, barriles y cajas de cobertura baja, motos tiradas.
- Zonas de aparición: 3, en los fondos de los callejones laterales.
- Caja de armas: 1 en una plazoleta.
- 3 puntos con latas sueltas (etiqueta "objetivo") en las plazoletas.
- Entrada a la ruta (z = -350): cartel grande "→ CALLEJÓN" en amarillo y flecha en el suelo.
- Pasajes de cruce hacia la calle (este) en z = -310, -240 y -170 (8 de ancho).
- Al final el callejón desemboca en el embudo del punto seguro 1.

Prefijo: T1_Callejon_. Entrega las tres cosas del documento maestro.
```

---

## Prompt 5 — Tramo 1, ruta Escalera (azul)

```
PARTE 5: TRAMO 1, RUTA ESCALERA (AZUL). Z de -350 a -130, X de +45 a +110.

Es el camino del este: pasajes y escalinatas decorativas, con recursos extra. TODO a nivel del suelo (y = 0): los escalones son decoración con desnivel máximo de 1 stud.
- Pasaje de 8 a 12 de ancho entre bloques altos, con tramos de "escalera pintada" (franjas de escalones bajos de 0.5 de alto cada 2 de largo, color azul y blanco) y muros de contención de 14 de alto.
- Una pequeña cancha de barrio abierta (40 × 30) con dos arcos de fútbol, en z = -240, con tierra #8B6B43.
- Casas de dos pisos con balcones, ropa colgada, antenas, un autobús escolar volcado cerca de la cancha.
- Zonas de aparición: 3 detrás de las casas de la cancha.
- Caja de armas: 1 junto a la cancha.
- Estación de munición: 1 en el pasaje.
- Recursos extra: 3 puntos con latas (etiqueta "objetivo").
- Entrada (z = -350): cartel grande "→ ESCALERA" en azul y flecha en el suelo.
- Pasajes de cruce hacia la calle (oeste) en z = -310, -240 y -170.
- Al final desemboca en el embudo del punto seguro 1.

Prefijo: T1_Escalera_. Entrega las tres cosas del documento maestro.
```

---

## Prompt 6 — Punto seguro 1: la tienda

```
PARTE 6: PUNTO SEGURO 1 (LA TIENDA DE BARRIO). Z de -130 a -90, X de -30 a +30 (edificio de 60 de ancho × 40 de largo, 16 de alto).

- Tienda de barrio abandonada pero resguardada: fachada de la tienda con reja metálica, cartel grande en español "ABARROTES DOÑA ...", anuncio de gaseosas y frutas pintado a mano.
- Dos puertas de reja de 24 de ancho y 14 de alto centradas en x = 0: entrada al sur (z = -130) y salida al norte (z = -90).
- Interior: zona de descanso de 30 × 26 con mostrador, estantes, refrigeradores, cajas y costales. Hay 2 botiquines (etiqueta "botiquin"), 1 estación de munición y una radio con un cartel con una pista de la historia ("El comandante dijo que el Refugio Remo todavía resiste").
- Una baliza de 30 de alto sobre el techo, con luz azul, visible desde lejos.
- Fuera, los tres carriles se juntan en un embudo: la calle (x de -30 a +30), el callejón (desde x = -110) y la escalera (desde x = +110) se estrechan hasta las puertas.
- Zona de espera exterior de 40 × 10 con cobertura baja.

Prefijo: PS1_. Entrega las tres cosas del documento maestro.
```

---

## Prompt 7 — Tramo 2, ruta Calle: plaza y generador

```
PARTE 7: TRAMO 2, RUTA CALLE (ROJA): LA PLAZA. Z de -90 a 160, X de -30 a +30 con una plaza más ancha (x de -50 a +50, z de -10 a 110) y un atrio de iglesia al final (z de 110 a 160).

- Calle de asfalto que entra a una plaza grande de 100 × 120 y sigue a un atrio con escalinata hacia la IGLESIA, que cierra el tramo: su fachada blanca (50 de ancho × 30 de alto, con campanario de 40) está en z = 160 y es la fachada sur del punto seguro 2 (el interior se diseña aparte, en la parte 10).
- Plaza: piso de adoquín gris claro, 4 faroles, 6 bancas, una fuente rota en el centro (cilindro de 12 de diámetro), un monumento pequeño, árboles secos, kioscos, carros chocados y puestos de feria como cobertura.
- Aquí está el GENERADOR (etiqueta "objetivo"): un generador grande (6 × 5 × 4) en una esquina de la plaza, en x = 30, z = 40, con cobertura alrededor. Al encenderlo llega una horda desde las bocacalles.
- Un PORTÓN de reja entre la plaza y el atrio, en z = 110, de 40 de ancho (x de -20 a +20) y 16 de alto, que se abre al encender el generador.
- Zonas de aparición: 5 en las bocacalles que rodean la plaza.
- Caja de armas: 1 libre en la plaza.
- Estación de munición: 1.
- 1 botiquín en la mitad de la ruta.
- Entrada (z = -90): cartel grande "→ CALLE" en rojo.

Prefijo: T2_Calle_. Entrega las tres cosas del documento maestro.
```

---

## Prompt 8 — Tramo 2, ruta Callejón: el mercado y las garrafas

```
PARTE 8: TRAMO 2, RUTA CALLEJÓN (AMARILLA): LA FERIA. Z de -90 a 160, X de -110 a -45.

- Un mercado cubierto de 60 × 80 con techo de lámina (techo a 14 de alto) y pasillos de 6 a 8 de ancho entre puestos, con puestos de lona (azul, naranja y verde), cajas de fruta, mesas, jaulas, carros de mano y toldos rotos. Combate corto y cercano.
- EVENTO NUEVO "LAS GARRAFAS": 3 garrafas de gas (cilindros de 1.5 de diámetro × 3.5 de alto, color naranja #E86A1C) repartidas en 3 puestos distintos, separadas entre sí unas 30 studs (etiqueta "objetivo"). Y un CAMIÓN DE REPARTO (10 × 10 × 24) estacionado en la salida sur-oeste del mercado, con una reja grande detrás que se abre cuando se entregan las 3 garrafas (etiqueta "objetivo"). Deja espacio libre de 10 de ancho entre las garrafas y el camión para que alguien las cargue lento mientras otros lo cubren.
- Alrededor: callejones estrechos con casas de colores, tendederos, cables y puestos ambulantes.
- Zonas de aparición: 4, dentro del mercado y en los callejones.
- Caja de armas: 1 dentro del mercado.
- 1 botiquín en la mitad del mercado.
- Pasajes de cruce hacia la calle (este) en z = -40, 40 y 120.
- Entrada (z = -90): cartel grande "→ CALLEJÓN" en amarillo.
- Cartel grande en el mercado: "FERIA DEL BARRIO — HOY SE VENDE DE TODO".

Prefijo: T2_Mercado_. Entrega las tres cosas del documento maestro.
```

---

## Prompt 9 — Tramo 2, ruta Escalera: detrás de la iglesia

```
PARTE 9: TRAMO 2, RUTA ESCALERA (AZUL): DETRÁS DE LA IGLESIA. Z de -90 a 160, X de +45 a +110.

- Camino largo pero tranquilo: pasajes de 8 a 12 de ancho, un atrio (patio) lateral de 40 × 40 junto a la iglesia, casas bajas con ropa tendida, un cementerio pequeño o capilla (opcional, 20 × 20), escalinatas decorativas (desnivel máximo de 1) en azul y blanco.
- Ruta con más latas y un botiquín, pero menos zombies. 3 puntos con latas (etiqueta "objetivo").
- Zonas de aparición: 2 (menos que en las otras rutas).
- Caja de armas: 1 en el atrio.
- Estación de munición: 1.
- 1 botiquín.
- Pasajes de cruce hacia la calle (oeste) en z = -40, 40 y 120.
- Entrada (z = -90): cartel grande "→ ESCALERA" en azul.
- Al final desemboca en el embudo del punto seguro 2.

Prefijo: T2_Escalera_. Entrega las tres cosas del documento maestro.
```

---

## Prompt 10 — Punto seguro 2: la iglesia

```
PARTE 10: PUNTO SEGURO 2 (LA IGLESIA). Z de 160 a 200, X de -30 a +30 (edificio de 60 de ancho × 40 de largo, 20 de alto).

- Interior de una iglesia de barrio: nave central con bancas de madera tiradas, un altar, velas, vitrales de colores (cajas de colores en las ventanas), un campanario con una campana en la torre de 40 de alto (parte de la fachada del punto seguro; la fachada exterior al sur se diseñó en la parte 7).
- Dos puertas de reja de 24 de ancho y 14 de alto: entrada al sur (z = 160) y salida al norte (z = 200).
- Dentro: zona de descanso de 30 × 26, 2 botiquines, 1 estación de munición, una radio con una pista de la historia ("Rhomulus cayó, pero el Refugio Remo sigue en pie").
- Una baliza de 30 de alto en el campanario, con luz azul.
- Fuera, los carriles se juntan en un embudo hacia las puertas (calle y callejón de un lado y de otro).
- Cartel pintado a mano en español: "Aquí nadie se queda atrás".

Prefijo: PS2_. Entrega las tres cosas del documento maestro.
```

---

## Prompt 11 — Tramo 3, ruta Calle: la terminal

```
PARTE 11: TRAMO 3, RUTA CALLE (ROJA): LA TERMINAL. Z de 200 a 330, X de -30 a +30 (ampliar hasta x de -60 a +60 dentro de la terminal).

- Terminal de buses (rodoviaria) a cielo abierto con techo de lámina en los andenes: piso de asfalto y concreto, 8 buses chocados y atravesados como obstáculos (8 × 11 × 30) con huecos de 8 de paso, una caseta de boletos, bancas, paneles con horarios en español.
- Zona más tensa: aquí aparece el Tanque y las hordas más fuertes. Reserva un área abierta de 40 × 40 para combate.
- Zonas de aparición: 5, entre buses y detrás de las casetas.
- Caja de armas: 1.
- Estación de munición: 1.
- 1 botiquín en la mitad.
- Entrada (z = 200): cartel grande "→ CALLE" en rojo.
- Al final (z = 330) la terminal desemboca en la entrada del estadio.

Prefijo: T3_Terminal_. Entrega las tres cosas del documento maestro.
```

---

## Prompt 12 — Tramo 3, ruta Callejón: la avenida lateral

```
PARTE 12: TRAMO 3, RUTA CALLEJÓN (AMARILLA): LA AVENIDA LATERAL. Z de 200 a 330, X de -110 a -45.

- Una avenida abierta de 40 de ancho que bordea la terminal por el oeste: pasto seco, vallas rotas, vallas publicitarias (cajas de 20 × 10 × 1 con anuncios en español), postes caídos, motos tiradas y carros chocados en fila.
- Hordas más largas y expuestas: pocos obstáculos y mucho espacio. Cobertura baja cada 20 studs.
- Zonas de aparición: 4 en los extremos.
- Caja de armas: 1.
- 1 botiquín.
- Pasajes de cruce hacia la terminal (este) en z = 240, 280 y 320.
- Entrada (z = 200): cartel grande "→ CALLEJÓN" en amarillo.
- Al final conduce al lado oeste de la entrada del estadio.

Prefijo: T3_Avenida_. Entrega las tres cosas del documento maestro.
```

---

## Prompt 13 — Tramo 3, ruta Escalera: los andenes

```
PARTE 13: TRAMO 3, RUTA ESCALERA (AZUL): LOS ANDENES. Z de 200 a 330, X de +45 a +110.

- Pasillos largos entre los andenes de espera cubiertos por techo de lámina (alto 12), con pocas salidas laterales (cada 40 studs, 8 de ancho). Barandas, torniquetes rotos (cajas de 3 × 4 × 2 con colisión), bancas, cajas, maletas y mochilas tiradas, escaleras decorativas (desnivel máximo de 1) en azul y blanco.
- Combate lineal y cerrado: ideal para la escopeta.
- Zonas de aparición: 3.
- Caja de armas: 1.
- 1 botiquín.
- Pasajes de cruce hacia la terminal (oeste) en z = 240, 280 y 320.
- Entrada (z = 200): cartel grande "→ ESCALERA" en azul.
- Al final conduce al lado este de la entrada del estadio.

Prefijo: T3_Andenes_. Entrega las tres cosas del documento maestro.
```

---

## Prompt 14 — El estadio y la extracción

```
PARTE 14: EL ESTADIO Y LA EXTRACCIÓN. Z de 330 a 400, X de -120 a +120.

- Estadio de barrio: gradas de concreto (cajas escalonadas de 3 de alto cada una, 4 filas) en tres lados, una cancha de tierra y pasto seco de 160 × 60 en el centro (x de -80 a +80, z de 338 a 398), con dos arcos de fútbol oxidados, líneas de cal gastadas, reflectores caídos y banderines rotos.
- La puerta del estadio por la que ENTRA LA FURGONETA DE RESCATE: abertura de 20 de ancho y 14 de alto en el muro sur, en x = 0, z = 330 (por donde entran también los jugadores). La furgoneta (8.4 × 11.5 × 22.6) entra por la puerta en dirección -Z y frena en la cancha, en (0, 0, 365). Deja libres un pasillo de 16 de ancho desde la puerta hasta ese punto y un espacio de 28 × 28 alrededor del punto de frenado.
- La RADIO de extracción (etiqueta "objetivo", 3 × 4 × 3) en la tribuna sur-oeste, a 12 de altura de grada o sobre una caseta junto a la cancha, con cobertura alrededor. Cuando la llaman hay que aguantar 150 s contra hordas continuas.
- Zonas de aparición para la extracción: 6 en el perímetro del estadio (túneles y accesos de las gradas), a 60 o más del punto de la furgoneta.
- Cobertura baja repartida por la cancha (bancos, cajas, un carro).
- 1 estación de munición y 1 botiquín.
- Carteles en español: "ESTADIO EL COLOSO" y "REFUGIO REMO → RESCATE".
- Una baliza grande de 40 de alto sobre la tribuna, con luz amarilla, para marcar el punto de extracción.

Prefijo: T3_Estadio_. Entrega las tres cosas del documento maestro.
```

---

## Prompt 15 — Ensamblaje y revisión

```
PARTE 15: ENSAMBLAJE Y REVISIÓN.

Te voy a pasar, uno por uno, los JSON de las partes 2 a 14. Cuando te los dé todos:
1. Únelos en un solo mapa de 240 × 800 y entrega una vista 3D completa y un plano general, con las tres rutas en rojo, amarillo y azul.
2. Revisa y lista los problemas: piezas que se atraviesan, huecos en el piso, pasillos de menos de 6 de ancho, muros saltables (menos de 12) donde deben bloquear, rutas que no se juntan en el embudo del punto seguro, rutas bloqueadas, zonas de aparición a menos de 60 del inicio de su tramo, cajas de armas o botiquines faltantes, y objetos de otras partes que no encajan.
3. Cuenta las piezas por zona y avisa si pasa de 800.
4. Corrige y entrega el JSON final unificado con la lista de etiquetas ordenada por zona.
Pregúntame antes de cambiar medidas o límites.
```
