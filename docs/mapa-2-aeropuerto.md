# Mapa 2 — LAST CALL, el aeropuerto de Rhomulus (diseño)

Estado: **en construcción desde el 10 de noviembre de 2026**. Hecho: `MapKit`, el mapa gris completo y amueblado (lobby, los 3 sectores, los 2 puntos seguros, las 3 Tiendas, la torre y la pista), el paso de etapas en `GameState`, el evento Crew Call, la extracción con Remo One, la arena de Survival del Hangar 7, la votación de mapa y la elección de mapa y arena en el menú. Falta: arte, altura y rendimiento (ver CLAUDE.md).

Juego: **Rhomulus** · Ambiente: apocalipsis latinoamericano, ahora en el **aeropuerto internacional de la ciudad**.

## Lo decidido

| Tema | Decisión |
| --- | --- |
| Mapa | **Last Call** (el último aviso de embarque). Lugar: **Rhomulus International Airport (RHM)** |
| Estructura | Igual que Morro Esperanza: **3 sectores, 2 puntos seguros, 3 rutas por sector** que se juntan en cada punto seguro. Ninguna ruta se bloquea, ni con 1 jugador |
| Lo que cambia | Otro tipo de rutas (interior, servicio y pista), **evento propio** (ver "Crew Call"), extracción en **avión** en vez de furgoneta, y un tono más frío y de noche con lluvia |
| Evento propio | **Crew Call**: tres tripulantes infectados llevan las tarjetas que abren el control de seguridad |
| Extracción | **Remo One**: el avión de rescate aterriza en la pista; se sube por la escalerilla |
| Survival | **Sí**: arena propia en el **Hangar 7** |
| Idioma | **Solo inglés** en carteles y rótulos (confirmado). La radio y los avisos siguen las reglas de `Lang` (inglés en el código, español automático) |
| Tamaño | Unos **900 studs de largo × 280 de ancho** (propuesta; ver "Tamaño y rendimiento") |
| Altura | Primero todo a nivel de suelo; después, la pasarela del segundo piso y los puentes de embarque (ver "Altura") |

## Recorrido

```
 LOBBY ──▶ SECTOR 1: Arrivals ──▶ PUNTO SEGURO 1: Sky Lounge ──▶ SECTOR 2: Departures
 (Lost & Found)                                                        │
                                                                       ▼
  EXTRACCIÓN: Runway ◀── SECTOR 3: Gates & Hangars ◀── PUNTO SEGURO 2: Fire Station
  (torre + Remo One)
```

Cada sector tiene **3 caminos** con el mismo color en los tres sectores. Son distintos a Calle / Callejón / Escalera:

| Ruta | Color | Cómo se siente |
| --- | --- | --- |
| **Concourse** (pasillos del terminal) | Rojo | Interior ancho, líneas de visión largas, tiendas y cintas de equipaje. Más zombies. La ruta "segura" a la vista, pero sin cobertura |
| **Service** (túneles de servicio y equipaje) | Amarillo | Corredores estrechos y oscuros, tuberías, carritos; la linterna importa. Hordas cortas y zombies que salen por detrás |
| **Apron** (la plataforma, al aire libre) | Azul | Exterior abierto bajo la lluvia, con aviones aparcados, camiones y tractores de equipaje como cobertura. Se ve desde lejos, más recursos |

### Lobby — Lost & Found
Cuarto cerrado de objetos perdidos, con maniquíes para practicar, una radio y el mapa del aeropuerto pegado en la pared (ahí empieza la guía de rutas). Las maletas sin dueño hacen de decoración y de pista.

### Sector 1 — Arrivals
Estacionamiento, la acera de llegadas con taxis y buses de traslado abandonados, y el salón de llegadas. Enseña los controles.
- **Concourse:** el salón de llegadas por el centro, con los mostradores de alquiler de autos y una caja de armas.
- **Service:** la rampa de carga y el túnel de equipaje que cruza por debajo del salón.
- **Apron:** por el borde exterior, entre taxis y buses de traslado.
- Obstáculos: autos chocados, carritos de equipaje, barreras de la acera, puertas giratorias atoradas.

### Punto seguro 1 — Sky Lounge
Sala VIP de una aerolínea, con sillones, barra y una pantalla de vuelos que ahora solo muestra "CANCELLED". Recarga gratis y botiquines. La radio da la primera pista de lo que pasó.

### Sector 2 — Departures
El corazón del terminal: check-in, **control de seguridad**, tiendas libres de impuestos y zona de comida. Zona de combate más grande.
- **Concourse:** el salón de check-in y los arcos de seguridad por el centro, combates abiertos.
- **Service:** los pasillos de equipaje detrás de los mostradores, con la cinta transportadora.
- **Apron:** por fuera, por las puertas de embarque de la planta baja.
- Aquí va el evento **Crew Call**, que abre el control de seguridad (ver abajo).

### Punto seguro 2 — Fire Station
El cuartel de bomberos del aeropuerto, con sus camiones, mangueras y literas. Recarga gratis y botiquines. Segunda pista: el avión de rescate sale de aquí hacia la pista.

### Sector 3 — Gates & Hangars
Las puertas de embarque, los hangares y la pista, hasta la torre de control.
- **Concourse:** el pasillo de las puertas de embarque, largo y recto, muy tenso.
- **Service:** los hangares y talleres, con grúas, motores desarmados y poca luz.
- **Apron:** la plataforma hasta la pista, abierta, con el **Tanque** y las hordas más fuertes.
- **Extracción:** ver "Extracción".

## Eventos

| Evento | Dónde | Cómo funciona |
| --- | --- | --- |
| **Crew Call** *(nuevo)* | Sector 2 | Ver abajo |
| **Radio → aguantar → Remo One** | Pista (sector 3) | Como la radio y la furgoneta de Morro, con el avión de escenario |

### Crew Call (evento nuevo del sector 2)
La puerta del control de seguridad está sellada. Para abrirla hacen falta las **3 tarjetas de acceso**, y las llevan tres tripulantes infectados, uno en cada ruta:
- **El Capitán** (Concourse), **la sobrecargo** (Service) y **el jefe de seguridad** (Apron). Se ven por el uniforme y una luz roja parpadeante en la tarjeta, y la guía los marca.
- Cada uno es un zombie reforzado (más vida que un común, menos que un Tanque, `Config.CrewCall`) que patrulla cerca de su zona y **no huye**. Al caer suelta su tarjeta, que se recoge con `E`.
- Cada tripulante que cae atrae una pequeña horda (el ruido) y avisa por radio cuántas tarjetas faltan.
- Con las 3 tarjetas, se pasan por el lector del control y la puerta se abre. La puerta pide mantener `E` unos segundos y, mientras, llega una horda corta: el equipo debe volver a juntarse.
- Con 1 jugador va de una en una y en el orden que quiera; con 2 o más, pueden repartirse las rutas o ir todos juntos.
- **Por qué:** es distinto de las garrafas (cargar) y del generador (aguantar). Obliga a recorrer las tres rutas y premia coordinarse, y casi todo se reutiliza: zombie con variante, objeto que se recoge, guía de objetivo y director de hordas.

### Extracción — Remo One
- La radio está en la **torre de control**. Se llama, empieza la cuenta atrás y el director aprieta la presión, igual que en Morro (`Difficulties.ExtractPressure`).
- El avión **Remo One** aterriza en la pista, rueda hasta la plataforma y frena junto a la torre. Se abre la puerta y baja la **escalerilla**.
- Se sube manteniendo `E` en la escalerilla (reutiliza `Boarding`: el personaje camina, sube y se sienta, y el caído en hombros sube con quien lo carga). El avión despega con quien haya subido a los `Config.Game.VanGrace` segundos del primero, o antes si suben todos.
- El avión despega con rodaje, carrera y ascenso; la pantalla de victoria sale mientras se va.
- Los modelos nuevos (avión, escalerilla, camiones) se arman con bloques nativos, como los demás.

## Survival en el aeropuerto — Hangar 7

- Mapa `"LastCallSurvival"`: mismo constructor con `{ survival = true }` y arena propia, como el estadio de Morro.
- **Arena:** el Hangar 7, grande y cerrado, con un avión aparcado en el centro y grúas y cajones como cobertura. El equipo aparece dentro; la **Tienda** (caja, munición y farmacia) está en una oficina del hangar.
- **Entradas:** 12 puntos de aparición repartidos por las puertas del hangar y los pasillos del taller. Las puertas son **solo de zombies** (grupos de colisión `Zombie` y `GateWall`, como el portón del estadio).
- Mismas oleadas (`SurvivalWaves`, `Config.Survival`) y mismos jefes. Un aeropuerto da jefes con tema: más Tanques de "personal de pista" y Atrapadores desde la oleada 10.
- El récord de oleadas hoy se guarda por número de jugadores (`waves_<n>`); con dos arenas hay que separarlo por mapa (`waves_<mapa>_<n>`).

## Tiendas

Igual que en Morro: una **Tienda** por sector con caja de armas, estación de munición y objetos, y vitrina de Phials. Los puntos seguros solo dan la recarga gratis.

| Tienda | Dónde | Tema |
| --- | --- | --- |
| Tienda 1 | Sector 1 | Quiosco de prensa y souvenirs, `Newsstand` |
| Tienda 2 | Sector 2 | Tienda libre de impuestos, `Duty Free` |
| Tienda 3 | Sector 3 | Taller del hangar, `Ground Crew Workshop` |

## Guía para no perderse

Se reutiliza todo lo de Morro (`ObjectiveGuide`, guía de la Tienda, flechas, color por ruta), pero con el lenguaje de un aeropuerto:
1. **Carteles colgantes amarillos y negros** de aeropuerto en cada bifurcación, con el nombre de la ruta y el color ("→ GATES", "→ BAGGAGE", "→ RAMP").
2. **Líneas de color en el suelo** (rojo, amarillo, azul), como las de un hospital, que se siguen hasta la bifurcación siguiente.
3. **Balizas de pista:** luces alternas visibles desde lejos en los puntos seguros y en el objetivo.
4. **La radio** repite el objetivo con frases cortas ("Head for the departures hall").
5. Las **tarjetas del Crew Call** y la torre de control se marcan con la guía del objetivo (`GameState.OBJECTIVES`).

## Ambiente

- **Noche con lluvia** y niebla baja sobre la pista (`Atmosphere`, con `Config` aparte del mapa 1). Los faroles se reemplazan por luces fluorescentes que parpadean dentro del terminal y balizas de pista fuera. Apagones con chispas, como en Morro.
- **Sonido:** altavoces con avisos entrecortados ("Last call for flight RM-2…"), aviones lejanos, alarma de incendio, cinta de equipaje, lluvia, eco en los pasillos. Por zona, en `Config.Sounds.Night.Zones`.
- **Historia con pistas sueltas:** pantallas de vuelos, carteles de "Quarantine in effect", maletas, un check-in abandonado, notas de la tripulación y la radio del comandante, sin texto largo.
- **Rótulos:** solo en inglés.

## Altura

Primero todo a nivel de suelo. En una segunda pasada:
- **Pasarela del segundo piso** del sector 2 (escaleras mecánicas y rampas de cuña) sobre el salón de check-in, con latas y botiquín, más expuesta.
- **Puentes de embarque** del sector 3: pasillos elevados con el techo bajo, sobre la plataforma, que dan una ruta alta paralela a la Apron.

## Tamaño y rendimiento

**Unos 900 studs de largo × 280 de ancho** (Morro: 800 × 240). El aeropuerto tiene muchas zonas planas y abiertas, así que pesa menos en piezas que el barrio.
- **Reparto aproximado a lo largo:** lobby 50 · sector 1 220 · punto seguro 1 40 · sector 2 270 · punto seguro 2 40 · sector 3 280 (incluye la pista y la torre).
- **Presupuesto de piezas:** meta de **5.500 a 6.500**, menos que las 8.275 de Morro, con pocos módulos repetidos (sillas, mostradores, columnas, maletas, luces). Activar el streaming y medir los FPS en celular a mitad de la construcción.
- **Caminos de zombies:** la plataforma es muy abierta; hay que cuidar el coste de `PathfindingService` (rutas con puntos intermedios y puntos de aparición por ruta y por sector). Los zombies atascados reaparecen con `Zombies.relocate`, como en Survival.

## Lista de objetos y modelos (para construir)

- Módulos del terminal: mostradores de check-in, arcos de seguridad, cintas de equipaje, sillas de espera, tiendas, escaleras mecánicas, pantallas de vuelos, puertas giratorias.
- Vehículos: **avión Remo One** (fuselaje, alas, motores, escalerilla), avión aparcado del hangar, camión de bomberos, camión de combustible, tractor de equipaje, taxis y buses de traslado.
- Entorno: torre de control, hangares, balizas de pista, vallas, conos, carritos de equipaje y maletas.
- Los modelos propios existentes (zombies, armas, cajas, generador, radio, furgoneta) se mantienen; la furgoneta se sustituye por el avión en este mapa.
- Zombies con ropa propia: personal de pista con chaleco, tripulación y seguridad (variantes de color y accesorios sobre el modelo común, para no crear modelos nuevos).

## Notas técnicas

- **Constructor nuevo:** `server/MapBuilderAirport.luau`, con el mismo contrato que `MapBuilderBarrio` (`build(config, options)`, `refs`, `spawnPoints`, `shopPositions`, `pharmacySpots`). `MapBuilderBarrio` pasa de 200.000 caracteres, así que conviene **sacar primero los ayudantes comunes** (pintar piezas, rampas, carteles, tienda, luces) a un módulo compartido (`MapKit`) para no copiarlos.
- **Configuración:** añadir el mapa a `Config.Maps` (con dos mapas vuelve la votación de mapa en `VoteRoom` y la elección en las salas del menú; el podio y el cartel de la sala de votación necesitan el nuevo mapa), `GameState.OBJECTIVES` y los atributos de guía.
- **Crew Call:** nuevo módulo `server/CrewCall` (tres zombies reforzados, tarjetas recogibles, puerta con lector), con valores en `Config.CrewCall`. Usa `Zombies` (variante), `Director` (hordas cortas) y la guía de objetivo.
- **Remo One:** variante de `VanBuilder` / `VanAnimator` / `Boarding` / `VanInterior` para el avión y la escalerilla (`shared/VanLayout` con otras medidas). La llegada y el despegue se animan en el cliente, como la furgoneta.
- **Survival:** el mapa `LastCallSurvival` reutiliza `GameState.survival()`, `SurvivalWaves` y las puertas solo para zombies; hay que añadir el segundo mapa a las pantallas del menú (MODE: SURVIVAL → elegir arena).
- **Texto:** todo en inglés en el código y su par al español en `shared/LangEs`, según las reglas de `Lang`. Los carteles decorativos del terminal son en inglés y no se traducen; los avisos y etiquetas de juego sí.
- **Orden de trabajo (propuesta):** (1) `MapKit` y mapa gris con las 3 rutas del sector 1; (2) sectores 2 y 3 en gris con puntos seguros y tiendas; (3) Crew Call; (4) extracción con Remo One; (5) Survival en el Hangar 7; (6) pase de arte, sonido y altura; (7) medir rendimiento y balancear. Cada paso se prueba en Studio antes de seguir.

## Decisiones confirmadas (10 de noviembre de 2026)

1. **Nombres:** Last Call (mapa), Arrivals, Sky Lounge, Departures, Fire Station y Gates & Hangars (sectores y puntos seguros), confirmados.
2. **Rótulos:** solo en inglés (sin doble idioma).
3. **Remo One:** avión de pasajeros **grande**. Hay que vigilar el número de piezas del avión (la meta de 5.500 a 6.500 piezas del mapa lo incluye).
4. **Crew Call:** los tres tripulantes son **zombies reforzados** normales, sin habilidad propia.
5. **Remo One:** fuselaje cerrado; al subir, la cámara pasa a seguir el avión desde fuera. Modelo `avion_pasajeros.glb` a **escala 3** (unos 102 × 101 × 24 studs).
6. **Acceso:** Last Call está abierto desde el principio (sin nivel ni requisito).

## Trazado construido

El mapa mide 280 × 860 studs jugables (x de -140 a 140, z de -450 a 410; la pista sigue hasta z 480). Bandas: SERVICE al oeste (x -130..-50), CONCOURSE al centro (x -40..40) y APRON al este (x 50..130). A lo largo: lobby z -440..-400 · sector 1 z -400..-190 · Sky Lounge z -180..-140 · sector 2 z -130..120 · Fire Station z 130..170 · sector 3 z 180..330 · plataforma z 330..410. La cuadrícula está en `src/server/AirportLayout.luau`.
