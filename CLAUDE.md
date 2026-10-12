# CLAUDE.md — Proyecto Zombies (Roblox)

## Cómo trabajar en este proyecto

- **Responde en español.** Ve al grano: Iker quiere terminar el juego, no aprender. No conviertas las tareas en lecciones ni propongas ejercicios; construye lo que pide y explica solo lo indispensable.
- Iker trabaja con su socio, Isaac.
- **Flujo:** Rojo 7.7 (gestionado con Aftman) + Git + GitHub (`Iker-cloud/JuegoZombies`, rama `main`). El código vive en `src/` y Rojo lo sincroniza con Studio según `default.project.json`. Los archivos son la fuente de verdad: nunca edites scripts dentro de Studio, porque Rojo los sobrescribe.
- Mapas, modelos e iluminación se hacen en Studio (no están en los archivos).
- Al terminar algo que funcione, propón un commit con un mensaje corto en español.
- Sigue la arquitectura del GDD: el servidor es la autoridad, un `ModuleScript` por sistema, valores de balance en un módulo de configuración.
- **Fase actual:** 7 — Pulido y prueba con amigos (ver "Estado actual del proyecto" abajo).

## Estado actual del proyecto (actualizado el 9 de octubre de 2026)

**Dónde vamos:** fase 7 (pulido y prueba con amigos). El MVP ya se juega de inicio a fin con 1 jugador (probado en Studio de lobby a victoria y derrota), y el **mapa 1 (Morro Esperanza) está terminado**: al entrar se vota el mapa (Prueba o Morro Esperanza). **Hoy, viernes 9 de octubre, toca la prueba con Isaac** (balance, bugs y rendimiento). Regla: solo arreglar y balancear.

**Hecho (fases 2 a 6 y casi toda la 7):**
- **Mapa 1 "Morro Esperanza"** (barrio de Rhomulus, `server/MapBuilderBarrio`), completo: lobby (la cochera), 3 tramos con 3 rutas cada uno (Calle roja, Callejón amarilla, Escalera azul), 2 puntos seguros (la tienda y la iglesia), eventos (generador que abre la iglesia, "Las garrafas" del mercado que le dan gas, emboscadas, Tanque en la terminal) y extracción en el estadio con la furgoneta. Azoteas de 10 de alto en la ruta Escalera, pase de arte y sonido por zona. Detalles en "Mapa de código".
- **Votación del mapa** al inicio de cada ronda (`server/VoteRoom`: sala aparte con un podio por mapa, se vota con `E`, 20 s, empate al azar).
- **Ambiente de terror** en los dos mapas (`server/Atmosphere`, `client/NightLights`, `client/NightSounds`): noche con luna y niebla, linterna, faroles que parpadean y se apagan, ruidos, latido.
- **Botiquín** (`server/Medkits`, tecla `4`): solo en el mapa nuevo.
- Disparo con raycast validado en el servidor, 4 armas (pistola, rifle, escopeta, subfusil), zoom con clic derecho, cámara sobre el hombro y primera persona (`V`).
- Zombie común y rápido con modelos propios (desde `.glb`), IA con `PathfindingService`, director de hordas con límite por número de jugadores.
- Caída, revivir con frases, cargar al compañero, levantarse solo con 1 jugador (`H`, una vez por zona), reaparición en el siguiente punto seguro.
- Partida completa: lobby, zona 1, punto seguro, zona 2 (generador, horda, portón), extracción (radio, cuenta atrás, van), resultados.
- Latas del equipo (antes "puntos"), caja de armas (500 latas), estaciones de munición (150 latas).
- Sonido: disparos, recargas, gruñidos 3D, sirena de horda, música por estado, melodía de la caja.
- Interfaz propia: munición junto a la mira (4 estilos), jeringa de sangre, latas, panel de radio por órdenes, placas de señalética, prompts con precio, barras de vida de enemigos, pantallas de victoria y derrota, tarjeta de caído.
- Modelos 3D propios de: zombies (común, rápido y Tanque), cajas de munición y misteriosa, maniquíes del lobby, generador, radio, furgoneta de rescate y armas (pistola, rifle de asalto, escopeta, subfusil).
- Zombie Tanque (600 de vida, lento): aparece en la horda del generador y en la extracción (`Config.Director.Tank`).
- Hitbox de zombies: caja invisible por zombie + tolerancia de puntería (`Config.HitTolerance`); los compañeros ya no bloquean las balas.
- Poses de sobrevivientes (`client/PoseAnimator`): caído (se arrastra), arrodillado al revivir (atributo `Reviving`) y colgado al ser cargado.
- Furgoneta: entra animada en el cliente (`client/VanAnimator`: frenada, ruedas, baliza, pitido). Armas: salen de la caja subiendo y girando (`WeaponBox`/`WeaponModel`).
- Armas en la mano (`server/WeaponRig` + `client/WeaponAnimator` + `client/ArmIK`): el arma activa va en la mano derecha; brazos con cinemática inversa; reposo con el arma baja y al apuntar (clic derecho) o disparar sube; retroceso visual + sacudida de cámara; recarga por tipo (cargador / cartucho a cartucho); fogonazo. Primaria a la espalda y pistola en la cadera cuando no están en la mano. Todo se ajusta en `Config.WeaponHold`.
- Críticos: un tiro a la cabeza hace x2 (`Config.Headshot`); el servidor lo mide por cercanía del rayo a la pieza `Head` (o `saco_cabeza` del maniquí) y avisa al tirador con `Remotes.Crit` (`client/CritMarker`: marcador rojo + sonido provisional). Panel temporal de aporte por jugador bajo LATAS (`client/ContribHud`; lee el atributo `LatasEarned` que pone `Points.add(cantidad, jugador)`; Iker pasará el diseño final). Guía de objetivo (`client/ObjectiveGuide`: columna de luz, cartel con distancia y flecha en el borde; el servidor publica `Workspace.ObjectivePos/ObjectiveName` desde `GameState.OBJECTIVES`, ajustes en `Config.Guide`). Correr: `client/Sprint` + `PlayerState.setSprinting`, velocidad en `Config.Player.SprintSpeed`.
- **Pulido del mapa 1 (sesión del 9 de octubre):** lobby con carteles de `Carteles.zip` hechos con texto vivo, carro abandonado (`ZombieData/CarroAbandonado`) y detalles de pared; casas favela (`ZombieData/Favela*`, versión ligera) en la calle principal; mercado ampliado (50×106) con puestos temáticos, tragaluces y guirnaldas; estadio con campamento; puntos seguros (tienda e iglesia) con azulejos, madera y marcos verdes; zona de votación nueva desde `zona-votacion.glb` (persistente por el streaming, escala 7). Ayudas visuales apagadas en `SHOW` (carteles de marcador, flechas del suelo, franjas de ruta) y sin columna de luz de la guía (`Config.Guide.ShowBeam`). El mapa ronda las **8.275 piezas**: medir FPS antes de añadir más.
- **Zombies:** al morir caen de espaldas, rebotan, se desvanecen (`ZombieAnimator.deathAnimate`, `Config.Zombie.CorpseTime/DeathFade`). **Revivir:** prueba de acción con Espacio mientras se mantiene E, 2 pruebas fáciles; si falla se reinicia (`Config.SkillCheck`, `server/SkillCheck`, `client/SkillCheck`). Sin probar aún con 2 jugadores reales.
- **Inventario:** barra de 7 ranuras (`client/Inventory`: 1 arma, 2 pistola, 3 granada, 4 botiquín, 5 molotov, 6 vendas, 7 bengala; la munición queda junto a la mira). Objetos en `server/Items`, valores en `Config.Items`; se compran con `E` en las estaciones de munición (`client/Shop`, `Remotes.Buy/OpenShop`) y se pierden al morir. La bengala atrae zombies (`Zombies.findLure`). Precios y daños sin balancear.
- **Dificultades** (`shared/Difficulties`, `server/Difficulty`, `client/DifficultyVote`): Calma, Tensión (el balance base de `Config`, todo ×1), Crisis y Colapso, de fácil a difícil, cada una con descripción. Multiplican vida, velocidad y daño de los zombies, zombies vivos y tamaño de hordas, proporción de rápidos, Tanques extra y más seguidos, ritmo de aparición, precios (caja, munición, objetos), latas ganadas, cura de botiquines y vendas, tiempo caído y levantarse solo. Se elige en el menú (anfitrión, "Crear partida"; viaja en los datos de teletransporte) o se vota con las teclas 1 a 4 en la sala de votación (partidas públicas). Etiqueta arriba al centro con la dificultad en curso. Valores sin balancear: ajustarlos en `Difficulties.luau`. Tope de vivos `MaxAliveCap` = 32.
- **Modelos de objetos** (`server/ItemModel`, del `Kit de piezas modulares GDL`, scripts de ArchiCAD reconstruidos con piezas nativas): granada, molotov (con llama), pistola de bengalas y rollo de venda. Se sacan en la mano un instante (`ItemModel.hold`, esconde el arma activa) y granada, molotov y bengala salen volando como el modelo. Sin sonidos aún; el brazo no se levanta (solo aparece el objeto en la mano).
- **Menú y partida son dos lugares:** el MENÚ es el lugar de inicio (`Places.Menu`, código en `src-menu`, `menu.project.json`, puerto 34892) y la PARTIDA es el otro (`Places.Game`, `default.project.json`, puerto 34891). Para publicar cada uno hay que conectar Rojo al proyecto correcto en el Studio del lugar correcto.
- **Aparición:** el personaje espera quieto (`AwaitGround`) hasta que el cliente confirma que tiene suelo (`client/SpawnGuard` → `Remotes.GroundReady`); rescate del vacío en `PlayerState`.
- **Lección:** en los animadores del cliente (`PoseAnimator`, `WeaponAnimator`) esperar `HasAppearanceLoaded` y comprobar las articulaciones por nombre (un campo `nil` no existe en la tabla, un `for` no lo ve).

**Pendiente (en orden):**
1. **Probar con 2 o más jugadores, con Isaac, hoy viernes 9 de octubre** (ya se probó una vez con Isaac en el juego publicado; falta ver las poses nuevas, la furgoneta, el Tanque, la noche y el botiquín; el mapa nuevo se elige en la votación del lobby (`Config.Maps`: Prueba o Morro Esperanza) y conviene medir antes los FPS): revivir con `E`, cargar con `F` y soltar con `G`, muertos que reaparecen en el siguiente punto seguro, derrota con varios jugadores.
2. Balance (precios, zombies, horda, tiempos) y bugs que salgan de esa prueba.
3. Revisar rendimiento: el mapa nuevo tiene unas 4800 piezas (ya se recortaron ventanas y luces lejanas); el zombie común tiene 86. Si baja el FPS, `Config.Zombie.Common.ModelDetail = "light"` y poner a mano en Workspace `StreamingTargetRadius = 320` y `StreamingMinRadius = 96`. Meta: 30 FPS en celular.
4. Probar las animaciones de sobrevivientes (paquete Antiguo): requiere que Rojo cargue `src/character`.
5. ~~Botiquín~~ (hecho para el mapa nuevo: `server/Medkits`; el mapa de siempre no tiene botiquines).
6. Dificultad elegible por el jugador (Iker lo mencionó): ahora los números salen de `Config.Director.ByPlayers`.
7. Publicar el juego para los amigos (el lugar existe, falta dejarlo accesible).

**Mapa de código** (`src/`):
- `shared/Config.luau`: **todos** los valores de balance, sonidos, animaciones y textos de precios. `shared/Remotes.luau`: único canal cliente-servidor.
- `server/`: `GameState` (etapas), `Director` + `Zombies` (+ `ZombieModel`), `Weapons`, `WeaponRig`, `WeaponBox`, `PlayerState` + `Revive`, `Points` (latas), `Stats`, `MapBuilder` (mapa gris por código), `MapBuilderBarrio` (mapa 1 Morro Esperanza, ya se juega de principio a fin con 1 jugador: de momento lobby + tramo 1 completo (Calle, Callejón y Escalera) + punto seguro 1 + tramo 2 completo: rutas Calle (plaza con el generador, que abre la iglesia), Callejón (mercado con las garrafas que le dan gas al generador) y Escalera (cementerio y atrio detrás de la iglesia) + punto seguro 2 (la iglesia) + tramo 3 completo: rutas Calle (terminal con emboscada y Tanque), Callejón (avenida lateral) y Escalera (andenes), que salen de la explanada tras la iglesia + estadio con la radio y la furgoneta (entra por el portón norte). La ruta Escalera de cada tramo tiene una azotea de 10 de alto (rampas de cuña, latas de 75 y botiquín arriba); tiene un pase de arte (unas 500 piezas de detalle: basura, maleza, cables, grafitis, carteles pintados, sangre estilizada; franjas blancas en las rampas; sonido por zona en `Config.Sounds.Night.Zones`); se elige en la votación), `VoteRoom` (sala aparte, a 800 de altura, con un podio por mapa: se vota con E, 20 s, empate al azar; `Config.Maps` y `Config.Vote`), `Ambushes` (mini-hordas al entrar en las plazoletas), `CanPiles` (latas sueltas con E), `Medkits` (botiquín: se recoge con E, se usa con 4, cura 80 en 5 s; `Config.Medkit`), `GasCans` (garrafas: se cargan como a un compañero y se llevan al generador; `Config.Gas`), `Atmosphere` (noche de terror en los dos mapas: luz de luna y niebla, linterna, faroles con etiqueta `NightLamp`, apagones; se apaga con `Config.Atmosphere.Enabled`), `Dummies`, `PropModel` (cajas, generador, radio, maniquíes) y `ZombieData/*.luau` (**generados**, no se editan a mano).
- `client/`: HUDs (`AmmoHud`, `HealthHud`, `LatasHud`, `TeamHud`, `RadioHud`, `GameHud`, `ResultHud`, `DownedHud`, `EnemyBars`, `Plates`, `PromptUi`), `ZombieAnimator`, `DummyAnimator`, `PropAnimator`, `SoundController`, `CameraController`, `Shooting`, `WeaponAnimator`, `ArmIK`, `Icons`, `Slant`, `NightLights` (faroles que parpadean, apagones con chispas, linterna que sigue la cámara), `NightSounds` (ambiente, ruidos sueltos, latido), `MedkitHud` (tecla del botiquín, insignia y barra de curación).
- `character/Animate.client.luau`: animación de los sobrevivientes (reemplaza el script de Roblox).
- `assets/*.glb` + `tools/glb_to_lua.py`: modelos 3D de origen y su conversor. Uso: `python tools/glb_to_lua.py <archivo-sin-.glb> <Modulo> [escala] [articulaciones]` (para cajas: articulación `tapa`). Los modelos se construyen con bloques nativos de Roblox, no se suben mallas.

**Controles:** clic = disparar (mantener = automática), clic derecho = apuntar, `R` recargar, `1`/`2`/`Q` cambiar de arma, `V` primera/tercera persona, `E` interactuar (revivir, abrir caja, comprar, generador, radio), `F` cargar a un caído, `G` soltar, `H` levantarse solo (1 jugador), `4` usar el botiquín (en el compañero herido al que se mira o en uno mismo), `Shift` correr (mantener; se cancela al apuntar, disparar o recargar; el Shift lock está desactivado), `Y` listo en el lobby.

**Cosas que aprendimos (para no repetir errores):**
- Si cambia `default.project.json` (carpetas nuevas), hay que **reiniciar `rojo serve`** y reconectar el plugin. Mantener una sola sesión de Rojo corriendo.
- En los modelos de articulaciones, el frente es `+Z` en el marco local: una rotación positiva en X manda hacia adelante lo que está arriba (torso, cabeza) y hacia atrás lo que cuelga (piernas, brazos). Las tapas se abren con rotación negativa.
- Ocultar interfaz en `BillboardGui` con transparencia no basta: apagarla con `Enabled = false`.
- `ColorSequence` admite máximo 20 puntos; las franjas usan 9.
- Las piezas llegan al cliente poco a poco: los animadores esperan a tener todas las articulaciones (atributo `JointCount`) antes de registrar un modelo.
- Al cargar el avatar, Roblox reemplaza las piezas del cuerpo justo después de `CharacterAdded`: espera `player:HasAppearanceLoaded()` antes de soldar algo al personaje (si no, queda pegado a una mano destruida y se cae).
- Para probar con las herramientas de Studio: `require` desde la herramienta crea una copia separada de los módulos (no sirve para cambiar valores del juego en marcha); para probar compras se bajan precios con un comentario `TEMP-PRUEBA` y se restauran (revisar con `grep TEMP-PRUEBA`). Los prompts a veces necesitan reintentarse tras un teletransporte.
- El tiempo de las pruebas puede pasar de los 8 s de `TakeTime` de la caja: tomar el arma en la misma llamada.

**Cómo trabaja Iker:** responder en español y al grano; **hacer preguntas de diseño antes de empezar cada fase o cambio grande**; probar en Studio antes de dar algo por hecho y decir qué no se pudo ver (las capturas de Studio funcionan con la herramienta de captura, pero la cámara del juego a veces las pisa); proponer commit con mensaje corto en español y pedir confirmación antes del `push`. Iker comparte capturas de diseños de referencia para la interfaz.

**Mapa 1 (después del MVP):** diseño en `docs/mapa-1-barrio.md` — barrio Morro Esperanza (referencia Brasil, todo en español) de la ciudad Rhomulus; 3 rutas por tramo que se juntan en cada punto seguro, 3 tramos y 2 puntos seguros, mapa de unos 800×240 studs, evento nuevo "Las garrafas" en el mercado, extracción en el estadio (Refugio Remo), botiquines, guía grande de objetivos (columna de luz, flecha en pantalla, flechas pintadas, un color por ruta). Primero mapa gris a nivel de calle; escaleras y azoteas después.

**Ideas guardadas (después del MVP):** deudas entre jugadores y "separarse sale caro" (ver identidad del juego), infección con jeringa que se vuelve verde, ruido que atrae hordas, voces en español (la ambientación latina ya está decidida, ver Decisiones abiertas), rol para quien carga, selector de dificultad, nombre del juego, lista final de frases de revivir.

---

# GDD

## Resumen

Un shooter cooperativo de zombies para 1 a 4 jugadores: el equipo cruza un mapa infestado, de un punto seguro a un punto de extracción, y solo gana si sobrevive junto.

| Campo | Decisión |
| --- | --- |
| Nombre | **Rhomulus** (decidido el 7 de oct. de 2026; falta confirmarlo con Isaac). Antes: "Proyecto Zombies" |
| Género | Acción / supervivencia cooperativa, con cámara en primera y tercera persona |
| Inspiración | Left 4 Dead: hordas, trabajo en equipo, revivir compañeros, extracción final; caja de armas al azar de los modos zombies de Call of Duty |
| Plataforma | Roblox (PC primero; móvil y consola después del MVP) |
| Jugadores | 1 a 4 por servidor |
| Duración de partida | 10 a 15 minutos |
| Público | Jugadores de Roblox de 12+ años que buscan acción en grupo |
| Desarrollador | Iker, primer juego en Roblox Studio |

Lo que lo hace divertido: la presión de la horda obliga a quedarse juntos, y caer sin ayuda significa perder. El juego premia cubrirse las espaldas, no jugar solo.

## Core loop y fantasía

Fantasía del jugador: "soy parte de un grupo de sobrevivientes que se abre paso en una ciudad caída y nadie se queda atrás".

Ciclo dentro de la partida (se repite cada pocos minutos):

1. Avanzar por el mapa explorando.
2. Encontrar recursos: munición, botiquines, armas mejores.
3. Sobrevivir encuentros con zombies y hordas.
4. Ayudar a compañeros caídos o en problemas.
5. Llegar al siguiente punto seguro y respirar.

Ciclo entre partidas (después del MVP): ganar monedas por partida completada, desbloquear skins o armas iniciales, y volver a intentar en una dificultad mayor.

## Estructura de una partida

El juego tiene tres mapas, cada uno con su propio vehículo de extracción; todos siguen la misma estructura de partida de 10 a 15 minutos.

| Mapa | Ambiente | Extracción final |
| --- | --- | --- |
| Ciudad abandonada | Calles con autos chocados, edificios en ruinas, callejones | Una van que llega por la calle principal |
| Centro comercial | Pasillos, tiendas, escaleras eléctricas, estacionamiento | Un auto deportivo en el estacionamiento |
| Aeropuerto | Terminal, bandas de equipaje, hangar y pista | Un avión que hay que alcanzar en la pista |

El MVP construye un solo mapa completo (la ciudad abandonada) y los otros dos reutilizan todos sus sistemas. Se empieza por la ciudad porque es la geometría más sencilla: calles abiertas y edificios simples.

Estructura de cada partida:

1. **Lobby:** los jugadores se juntan, votan el mapa y presionan "Listo".
2. **Zona 1:** zombies sueltos, pocos recursos. Sirve para aprender los controles.
3. **Punto seguro:** cuarto cerrado donde no entran zombies. Hay munición y botiquines; se avanza cuando todos están dentro.
4. **Zona 2:** pasillos, más zombies y una horda activada por un evento (abrir un portón, encender un generador).
5. **Final — Extracción:** el equipo llama al rescate y aguanta una horda continua durante 2 a 3 minutos hasta que llega el vehículo de ese mapa.
6. **Resultado:** victoria si al menos un jugador llega al vehículo; derrota si todos caen. Pantalla con estadísticas (kills, compañeros revividos, daño recibido).

Si un jugador muere, reaparece en el siguiente punto seguro, igual que en Left 4 Dead. Así nadie se queda viendo la partida entera.

## Sistemas

Cada sistema tiene una versión mínima para el MVP; los valores numéricos son puntos de partida para balancear en pruebas.

### Jugador

- Vida: 100 puntos. Al llegar a 0, el jugador cae (no muere): puede disparar con pistola desde el suelo mientras se desangra durante 30 s.
- Revivir: un compañero mantiene presionada una tecla 4 s junto a él y lo levanta con 30 de vida. Mientras tanto, cada personaje dice una frase al azar en un globo de texto (después, con voz). Ejemplos del que revive: "¡Arriba, que todavía no es tu hora!", "¿Otra vez en el piso?", "Me debes una". Ejemplos del caído: "Ya me andaba", "Tardaste muchísimo".
- Cargar: un compañero puede levantar al caído y llevarlo en hombros a un lugar seguro antes de revivirlo. Quien carga camina más lento y solo usa la pistola; el caído sigue disparando desde el hombro.
- Si nadie lo revive a tiempo, muere y reaparece en el siguiente punto seguro.

### Armas

| Arma | Rol | Daño por tiro | Cargador | Notas |
| --- | --- | --- | --- | --- |
| Pistola | Secundaria, munición infinita | 20 | 12 | Siempre disponible, también estando caído |
| Rifle | Principal, todo terreno | 25 | 30 | Disparo automático |
| Escopeta | Principal, corto alcance | 8 x 8 perdigones | 8 | Fuerte contra hordas en pasillos |

Disparo con raycast desde el servidor (ver Arquitectura). Fuego amigo desactivado en el MVP.

### Caja de armas

Todos empiezan con pistola; las armas principales salen de una caja misteriosa, como en los modos zombies de Call of Duty.

- Cuesta puntos del equipo (ver Puntos del equipo).
- Al abrirla, las armas giran unos segundos sobre la caja con luz y sonido, y se detiene en una al azar.
- Cada arma tiene rareza (común, rara, épica): las épicas salen menos.
- Hay una caja por zona, en un lugar distinto de la zona en cada partida, para que el equipo siempre tenga una adelante mientras avanza.
- Arsenal posible: rifle, escopeta, subfusil, francotirador, ametralladora ligera y un arma épica por mapa.
- Diseño propio de la caja y las armas, sin copiar modelos ni nombres de Call of Duty.

### Puntos del equipo

Los puntos (en el juego se llaman **latas**) son una sola bolsa compartida por todo el equipo y se ven en la UI de todos.

- Se ganan matando zombies, reviviendo o cargando compañeros y completando cada zona.
- Se gastan en la caja de armas y en estaciones de munición que hay en cada zona.
- Cualquier jugador puede gastar; la UI muestra quién compró qué, para que el equipo se coordine.

### Cámara

El jugador cambia entre primera y tercera persona con una tecla (en celular, con un botón). En el MVP, la primera persona solo acerca la cámara a la cabeza del personaje, sin brazos ni armas animados por separado; esos *viewmodels* llegan después del MVP. La tercera persona es sobre el hombro, y en ambas el disparo sale del centro de la pantalla para que apuntar se sienta igual.

### Enemigos

| Enemigo | Vida | Comportamiento | Cuándo entra |
| --- | --- | --- | --- |
| Zombie común | 50 | Persigue al jugador más cercano y golpea (10 de daño) | MVP |
| Zombie rápido | 30 | Corre al doble de velocidad, poca vida | MVP |
| Zombie tanque | 800 | Lento, golpea fuerte (40), aparece en el final | Después del MVP |
| Zombie especial que atrapa a un jugador | 150 | Inmoviliza a un jugador; la víctima se libera presionando una tecla muchas veces (en celular, tocando un botón rápido) o un compañero le dispara al zombie | Después del MVP |

IA básica: buscar al jugador más cercano con `PathfindingService`, recalcular la ruta cada 0.5 a 1 s, atacar al estar a menos de 4 studs.

### Director de hordas

Un script del servidor decide cuándo y dónde aparecen zombies, fuera de la vista de los jugadores. En el MVP es simple: un límite de zombies vivos (ej. 25), puntos de aparición por zona y hordas fijas en los eventos. Después puede volverse dinámico (más presión si el equipo va bien, respiro si va mal), como el "AI Director" de Left 4 Dead.

La dificultad se ajusta al número de jugadores al iniciar la partida (valores iniciales para balancear en pruebas):

| Jugadores | Zombies vivos máx. | Tamaño de horda | Ajuste extra |
| --- | --- | --- | --- |
| 1 | 10 | 25% | Puede levantarse solo una vez por zona |
| 2 | 18 | 60% | Ninguno |
| 3 | 22 | 80% | Ninguno |
| 4 | 25 | 100% | Ninguno |

Si alguien sale o entra a mitad de partida, los valores se recalculan en el siguiente punto seguro.

### Recursos

- Munición: se compra con puntos del equipo en estaciones de cada zona; cada punto seguro da una recarga gratis.
- Botiquín: cura 80 de vida en 5 s; se puede usar en uno mismo o en un compañero.

### Interfaz (UI)

- Barra de vida y munición propias.
- Vida y estado de cada compañero (normal, caído, muerto).
- Indicador en pantalla de compañero caído.
- Pantalla de resultados al final.

### Guardado de datos

El MVP no guarda nada entre partidas. Después se usa `DataStoreService` para monedas, desbloqueos y estadísticas totales.

### Estilo visual

Realista y atractivo, con una regla por encima de todo: el juego debe correr bien en PC, celular y consola.

- Iluminación Future y `Atmosphere` para niebla y polvo; materiales PBR (`SurfaceAppearance`) solo en lo que se ve de cerca.
- Presupuesto de rendimiento: modelos con pocos polígonos, texturas reutilizadas, `StreamingEnabled` activado y decoración anclada y sin colisión.
- Zombies ligeros: pocas piezas por modelo; el límite de zombies vivos también protege el rendimiento.
- Meta: 30 FPS estables en un celular de gama media; cada mapa se prueba ahí antes de darlo por terminado.
- Primero se construye cada mapa en bloques grises para probar que sea divertido, y después se hace el pase de arte.

### Audio

El sonido carga la mitad de la tensión: el jugador debe poder oír una horda antes de verla.

| Elemento | Qué hace | Cuándo entra |
| --- | --- | --- |
| Zombies en 3D | Gruñidos y pasos que suenan desde su posición, para saber de dónde vienen | MVP |
| Aviso de horda | Un grito o sirena distintivo segundos antes de cada horda | MVP |
| Armas | Disparo, recarga y "clic" sin munición para cada arma | MVP |
| Música dinámica | Cambia por estado: calma, tensión, horda y extracción | MVP (versión simple) |
| Caja de armas | Melodía propia mientras giran las armas | MVP |
| Ambiente por mapa | Viento y alarmas de autos en la ciudad, música de tienda rota en el centro comercial, avisos de altavoz en el aeropuerto | Con cada mapa |
| Voces | Las frases de revivir y avisos como "¡Horda!" o "Recargando" | Después del MVP |

Los sonidos deben ser propios o tener licencia libre (por ejemplo, del Creator Store de Roblox).

## Alcance: MVP vs después

El MVP es una partida completa y jugable de principio a fin con 1 a 4 amigos. Todo lo demás espera hasta que eso funcione y sea divertido.

| Entra al MVP | Después del MVP |
| --- | --- |
| Ciudad abandonada completa, con extracción en van | Centro comercial (auto deportivo) y aeropuerto (avión) |
| Pistola inicial y caja de armas con rifle, escopeta y subfusil | Más armas en la caja, rarezas, cuerpo a cuerpo, granadas, brazos animados en primera persona |
| Zombie común y rápido | Tanque y zombies especiales |
| Caída, revivir con frases, cargar al compañero y reaparición | Fuego amigo, niveles de dificultad |
| Director de hordas simple | Director dinámico que ajusta la presión |
| UI básica de vida, munición y equipo | Chat de voz rápido, marcadores de ítems |
| Sin guardado de datos | Monedas, desbloqueos y estadísticas con DataStore |
| Mapa en bloques grises con iluminación Future | Pase de arte realista: modelos, texturas PBR, animaciones, voces y sonidos |
| PC | Controles para móvil y consola |

Regla de oro: no se agrega nada de la columna derecha hasta que un grupo de amigos haya terminado el MVP y quiera jugarlo otra vez.

## Identidad del juego (después del MVP)

Lo que nos diferencia de otros juegos de zombies: **"nadie se queda atrás"**. Cargar al compañero en hombros mientras sigue disparando ya es parte del juego; estas dos ideas lo refuerzan. Entran después del MVP, cuando un grupo de amigos lo haya terminado y quiera jugarlo otra vez (ver regla de oro).

1. **Deudas entre jugadores.** Cada vez que alguien te revive, le debes una (como dicen las frases: "Me debes una"). Si luego lo revives tú, quedan a mano. La pantalla de resultados muestra quién debe a quién ("Iker le debe 2 a Isaac") y quién es el mayor deudor.
2. **Separarse sale caro.** El director de hordas manda más zombies hacia quien está lejos del equipo, o quien está solo recibe más daño. Es una regla del juego, no solo un consejo.

Ideas guardadas para más adelante (no decididas): ruido que atrae hordas (armas silenciadas o cuerpo a cuerpo como respiro), ambientación y voces latinas en español, y un rol para quien va en hombros (marca zombies para quien lo carga).

## Arquitectura técnica en Roblox

Toda la lógica que importa (daño, vida, zombies) vive en el servidor; el cliente solo detecta lo que hace el jugador y muestra el resultado.

Estructura cliente-servidor:

- **Servidor (`ServerScriptService`, autoridad):** armas (valida cada disparo, raycast y daño), director de hordas (aparece zombies fuera de la vista, máx. 25), IA de zombies (`PathfindingService` hacia el jugador más cercano), estado de partida (vida, caída, revivir, zonas y extracción).
- **Compartido (`ReplicatedStorage`):** RemoteEvents (único canal cliente-servidor), módulos compartidos (datos de armas y enemigos), assets (modelos de zombies y armas).
- **Cliente (`StarterPlayer` / `StarterGui`):** controles (detecta clic y teclas, pide acciones al servidor), UI (vida, munición, equipo, resultados), cámara y efectos.
- Flujo: el cliente pide (disparar, revivir, usar botiquín) → el servidor responde (vida, munición, estado del equipo).

El cliente nunca dice "le hice 50 de daño"; dice "disparé hacia aquí" y el servidor decide si le dio y cuánto daño hizo. Así se evitan trampas y los cuatro jugadores ven lo mismo.

Reglas de organización desde el día uno:

- Un `ModuleScript` por sistema (armas, zombies, director, estado de partida), en vez de un script gigante.
- Los valores de balance (daño, vida, velocidad) van en un módulo de configuración, no repartidos en el código.
- Los zombies no usan física pesada ni demasiadas piezas: el límite de 25 vivos es por rendimiento.

## Plan de desarrollo y decisiones abiertas

Cada fase termina con algo que se puede probar en Studio; no se pasa a la siguiente hasta cumplir su criterio.

1. ~~**Fundamentos de Roblox**~~ (omitida: se va directo a construir).
2. **Disparar:** pistola con raycast validado en el servidor, munición y cámara en primera y tercera persona. Listo cuando: se le puede disparar a un maniquí y su vida baja.
3. **Un zombie:** IA que persigue y ataca. Listo cuando: un zombie te sigue por obstáculos, te hace daño y muere a tiros.
4. **Muchos zombies:** puntos de aparición y director simple con límite. Listo cuando: el juego aguanta 25 zombies sin lag notable.
5. **Cooperativo:** caída, revivir con frases, cargar al compañero, reaparición y UI de equipo. Listo cuando: dos jugadores en un servidor de prueba pueden revivirse.
6. **El mapa:** ciudad abandonada con zonas, punto seguro, caja de armas, evento de horda y extracción en van. Listo cuando: se puede jugar la partida completa de inicio a fin.
7. **Pulido y prueba con amigos:** sonidos, balance, bugs. Listo cuando: 3 amigos terminan una partida y quieren otra. Después se construyen el centro comercial y el aeropuerto con los mismos sistemas.

### Decisiones abiertas

- [x] Cámara: primera y tercera persona, a elección del jugador
- [x] Estilo visual: realista pero optimizado para correr bien en todos lados
- [x] Extracción distinta por mapa: van, auto deportivo y avión
- [x] Nombre: Rhomulus. Ambientación: **apocalipsis latinoamericano** (ciudad latina en ruinas: carteles pintados a mano, tiendas de barrio, buses, murales, radio de emergencia en español, jerga local). Se aplica después del MVP: primero textos, radio y frases; luego carteles y sonido ambiente
- [x] Flujo de trabajo: Rojo + Git + GitHub desde el inicio
- [ ] Lista final de frases para revivir
- [x] Precios de la caja de armas y de la munición (500 y 150 latas; se pueden afinar en pruebas)
