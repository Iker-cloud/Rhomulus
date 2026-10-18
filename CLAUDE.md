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

**Dónde vamos:** fase 7 (pulido y prueba con amigos). El MVP ya se juega de inicio a fin con 1 jugador (probado en Studio de lobby a victoria y derrota), y el **mapa 1 (Morro Esperanza) está terminado**: al entrar se vota la dificultad (Morro Esperanza es el único mapa; el de prueba se retiró el 14 de octubre). **Hoy, viernes 9 de octubre, toca la prueba con Isaac** (balance, bugs y rendimiento). Regla: solo arreglar y balancear.

**Hecho (fases 2 a 6 y casi toda la 7):**
- **Mapa 1 "Morro Esperanza"** (barrio de Rhomulus, `server/MapBuilderBarrio`), completo: lobby (la cochera), 3 tramos con 3 rutas cada uno (Calle roja, Callejón amarilla, Escalera azul), 2 puntos seguros (la tienda y la iglesia), eventos (generador que abre la iglesia, "Las garrafas" del mercado que le dan gas, emboscadas, Tanque en la terminal) y extracción en el estadio con la furgoneta. Azoteas de 10 de alto en la ruta Escalera, pase de arte y sonido por zona. Detalles en "Mapa de código".
- **Votación de dificultad** al inicio de cada ronda (`server/VoteRoom`: sala aparte, 20 s, teclas 1 a 4; con un solo mapa ya no se vota el mapa, pero la sala conserva el cartel de Morro Esperanza).
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
- Zombie Tanque (1500 de vida en Tensión, lento; la dificultad lo multiplica): aparece en la horda del generador y en la extracción (`Config.Director.Tank`).
- Hitbox de zombies: caja invisible por zombie + tolerancia de puntería (`Config.HitTolerance`); los compañeros ya no bloquean las balas.
- **Modo espectador** (`client/Spectator`): al morir con 2 o más jugadores la cámara sigue a un compañero vivo (al hombro, mira hacia donde apunta); A / D, flechas o las fichas de abajo cambian de compañero; fundido a negro si está lejos; termina al reaparecer o al acabar la ronda.
- Poses de sobrevivientes (`client/PoseAnimator`): caído (se arrastra), arrodillado al revivir (atributo `Reviving`) y colgado al ser cargado.
- Furgoneta: entra animada en el cliente (`client/VanAnimator`: frenada, ruedas, baliza, pitido). Al llegar se abren las puertas laterales y se sube **manteniendo E** en la puerta (`server/Boarding`, `client/BoardingAnimator`): el personaje camina, trepa de un salto y se sienta en un asiento, anclado a mano y sin `Seat:Sit` (soldado a la furgoneta, el servidor la devolvía a su sitio y la cámara se quedaba atrás; cada cliente lo lleva pegado al asiento en `VanAnimator.followPassengers`) (`server/VanInterior` vacía la caja y pone los `Seat`; medidas en `shared/VanLayout`); con un caído en hombros suben los dos y el caído se levanta dentro. La furgoneta sale al subir todos o a los `Config.Game.VanGrace` s del primero: cierra puertas, ruge, sale en reversa, hace un giro de 180° y se va; la victoria sale mientras se va. Quien suba es inmune (atributo `Boarded`). Armas: salen de la caja subiendo y girando (`WeaponBox`/`WeaponModel`).
- Armas en la mano (`server/WeaponRig` + `client/WeaponAnimator` + `client/ArmIK`): el arma activa va en la mano derecha; brazos con cinemática inversa; reposo con el arma baja y al apuntar (clic derecho) o disparar sube; retroceso visual + sacudida de cámara; recarga por tipo (cargador / cartucho a cartucho); fogonazo. Primaria a la espalda y pistola en la cadera cuando no están en la mano. Todo se ajusta en `Config.WeaponHold`.
- Críticos: un tiro a la cabeza hace x2 (`Config.Headshot`); el servidor lo mide por cercanía del rayo a la pieza `Head` (o `saco_cabeza` del maniquí) y avisa al tirador con `Remotes.Crit` (`client/CritMarker`: marcador rojo + sonido provisional). Panel temporal de aporte por jugador bajo LATAS (`client/ContribHud`; lee el atributo `LatasEarned` que pone `Points.add(cantidad, jugador)`; Iker pasará el diseño final). Guía de objetivo (`client/ObjectiveGuide`: columna de luz, cartel con distancia y flecha en el borde; el servidor publica `Workspace.ObjectivePos/ObjectiveName` desde `GameState.OBJECTIVES`, ajustes en `Config.Guide`). Correr: `client/Sprint` + `PlayerState.setSprinting`, velocidad en `Config.Player.SprintSpeed`.
- **Pulido del mapa 1 (sesión del 9 de octubre):** lobby con carteles de `Carteles.zip` hechos con texto vivo, carro abandonado (`ZombieData/CarroAbandonado`) y detalles de pared; casas favela (`ZombieData/Favela*`, versión ligera) en la calle principal; mercado ampliado (50×106) con puestos temáticos, tragaluces y guirnaldas; estadio con campamento; puntos seguros (tienda e iglesia) con azulejos, madera y marcos verdes; zona de votación nueva desde `zona-votacion.glb` (persistente por el streaming, escala 7). Ayudas visuales apagadas en `SHOW` (carteles de marcador, flechas del suelo, franjas de ruta) y sin columna de luz de la guía (`Config.Guide.ShowBeam`). El mapa ronda las **8.275 piezas**: medir FPS antes de añadir más.
- **Zombies:** al morir caen de espaldas, rebotan, se desvanecen (`ZombieAnimator.deathAnimate`, `Config.Zombie.CorpseTime/DeathFade`). **Revivir:** prueba de acción con Espacio mientras se mantiene E, 2 pruebas fáciles; si falla se reinicia (`Config.SkillCheck`, `server/SkillCheck`, `client/SkillCheck`). Sin probar aún con 2 jugadores reales.
- **Inventario:** barra de 7 ranuras (`client/Inventory`: 1 arma, 2 pistola, 3 granada, 4 botiquín, 5 molotov, 6 vendas, 7 bengala; la munición queda junto a la mira). Objetos en `server/Items`, valores en `Config.Items`; se compran con `E` en las estaciones de munición (`client/Shop`, `Remotes.Buy/OpenShop`) y se pierden al morir. La bengala atrae zombies (`Zombies.findLure`). Precios y daños sin balancear.
- **Dificultades** (`shared/Difficulties`, `server/Difficulty`, `client/DifficultyVote`): Calma, Tensión (el balance base de `Config`, todo ×1), Crisis y Colapso, de fácil a difícil, cada una con descripción. Multiplican vida, velocidad y daño de los zombies, zombies vivos y tamaño de hordas, proporción de rápidos, Tanques extra y más seguidos, ritmo de aparición, precios (caja, munición, objetos), latas ganadas, cura de botiquines y vendas, tiempo caído y levantarse solo. Se elige en el menú (anfitrión, "Crear partida"; viaja en los datos de teletransporte) o se vota con las teclas 1 a 4 en la sala de votación (partidas públicas). Etiqueta arriba al centro con la dificultad en curso. Valores sin balancear: ajustarlos en `Difficulties.luau`. Tope de vivos `MaxAliveCap` = 32.
- **Modelos de objetos** (`server/ItemModel`, del `Kit de piezas modulares GDL`, scripts de ArchiCAD reconstruidos con piezas nativas): granada, molotov (con llama), pistola de bengalas y rollo de venda. Al usarlos se sacan en la mano (`ItemModel.hold`, esconde el arma activa) y los brazos hacen un gesto con cinemática inversa (`client/ItemPoses`, mezclado en `WeaponAnimator.update`; el servidor publica `ItemId/ItemStart/ItemEnd` en el personaje y los tiempos están en `Config.Items.<id>.Anim`): granada (pasador que salta, balanceo y lanzamiento), molotov (balanceo en arco), pistola de bengalas (apunta con dos manos, fogonazo y retroceso) y vendas (vueltas sobre el brazo y destellos verdes). Granada, molotov y bengala salen volando como el modelo.
- **Menú y partida son dos lugares:** el MENÚ es el lugar de inicio (`Places.Menu`, código en `src-menu`, `menu.project.json`, puerto 34892) y la PARTIDA es el otro (`Places.Game`, `default.project.json`, puerto 34891). Para publicar cada uno hay que conectar Rojo al proyecto correcto en el Studio del lugar correcto.
- **Aparición:** el personaje espera quieto (`AwaitGround`) hasta que el cliente confirma que tiene suelo (`client/SpawnGuard` → `Remotes.GroundReady`); rescate del vacío en `PlayerState`.
- **Lección:** en los animadores del cliente (`PoseAnimator`, `WeaponAnimator`) esperar `HasAppearanceLoaded` y comprobar las articulaciones por nombre (un campo `nil` no existe en la tabla, un `for` no lo ve).

**Pendiente (en orden):**
1. **Probar con 2 o más jugadores, con Isaac, hoy viernes 9 de octubre** (ya se probó una vez con Isaac en el juego publicado; falta ver las poses nuevas, la furgoneta, el Tanque, la noche y el botiquín; el mapa es Morro Esperanza (`Config.Maps`) y conviene medir antes los FPS): revivir con `E`, cargar con `F` y soltar con `G`, muertos que reaparecen en el siguiente punto seguro, derrota con varios jugadores.
2. Balance (precios, zombies, horda, tiempos) y bugs que salgan de esa prueba.
3. Revisar rendimiento: el mapa nuevo tiene unas 4800 piezas (ya se recortaron ventanas y luces lejanas); el zombie común tiene 86. Meta: 30 FPS en celular. Ya está la calidad gráfica del cliente y el panel de rendimiento (AJUSTES → RENDIMIENTO); si no llega, seguir `docs/rendimiento-celular.md` (streaming a mano en Studio, `Config.Zombie.Common.ModelDetail = "light"`, menos zombies vivos). Falta medir en un celular real.
4. Probar las animaciones de sobrevivientes (paquete Antiguo): requiere que Rojo cargue `src/character`.
5. ~~Botiquín~~ (hecho para el mapa nuevo: `server/Medkits`).
6. Dificultad elegible por el jugador (Iker lo mencionó): ahora los números salen de `Config.Director.ByPlayers`.
7. Publicar el juego para los amigos (el lugar existe, falta dejarlo accesible).

**Mapa de código** (`src/`):
- `shared/Config.luau`: **todos** los valores de balance, sonidos, animaciones y textos de precios. `shared/Remotes.luau`: único canal cliente-servidor.
- `server/`: `GameState` (etapas), `Director` + `Zombies` (+ `ZombieModel`), `Weapons`, `WeaponRig`, `WeaponBox`, `PlayerState` + `Revive`, `Points` (latas), `Stats`, `VanBuilder` (la furgoneta), `MapBuilderBarrio` (mapa 1 Morro Esperanza, ya se juega de principio a fin con 1 jugador: de momento lobby + tramo 1 completo (Calle, Callejón y Escalera) + punto seguro 1 + tramo 2 completo: rutas Calle (plaza con el generador, que abre la iglesia), Callejón (mercado con las garrafas que le dan gas al generador) y Escalera (cementerio y atrio detrás de la iglesia) + punto seguro 2 (la iglesia) + tramo 3 completo: rutas Calle (terminal con emboscada y Tanque), Callejón (avenida lateral) y Escalera (andenes), que salen de la explanada tras la iglesia + estadio con la radio y la furgoneta (entra por el portón norte). La ruta Escalera de cada tramo tiene una azotea de 10 de alto (rampas de cuña, latas de 75 y botiquín arriba); tiene un pase de arte (unas 500 piezas de detalle: basura, maleza, cables, grafitis, carteles pintados, sangre estilizada; franjas blancas en las rampas; sonido por zona en `Config.Sounds.Night.Zones`); se elige en la votación), `VoteRoom` (sala aparte, a 800 de altura, con un podio por mapa: se vota con E, 20 s, empate al azar; `Config.Maps` y `Config.Vote`), `Ambushes` (mini-hordas al entrar en las plazoletas), `CanPiles` (latas sueltas con E), `Medkits` (botiquín: se recoge con E, se usa con 4, cura 80 en 5 s; `Config.Medkit`), `GasCans` (garrafas: se cargan como a un compañero y se llevan al generador; `Config.Gas`), `Atmosphere` (noche de terror en los dos mapas: luz de luna y niebla, linterna, faroles con etiqueta `NightLamp`, apagones; se apaga con `Config.Atmosphere.Enabled`), `Dummies`, `PropModel` (cajas, generador, radio, maniquíes) y `ZombieData/*.luau` (**generados**, no se editan a mano).
- `client/`: HUDs (`AmmoHud`, `HealthHud`, `LatasHud`, `TeamHud`, `RadioHud`, `GameHud`, `ResultHud`, `DownedHud`, `EnemyBars`, `Plates`, `PromptUi`), `ZombieAnimator`, `DummyAnimator`, `PropAnimator`, `SoundController`, `CameraController`, `Shooting`, `WeaponAnimator`, `ArmIK`, `Icons`, `Slant`, `NightLights` (faroles que parpadean, apagones con chispas, linterna que sigue la cámara), `NightSounds` (ambiente, ruidos sueltos, latido), `MedkitHud` (tecla del botiquín, insignia y barra de curación). Celular: `Controls`, `TouchControls`, `SettingsPanel`, `UiFit`, `Performance` (ver "Celular").
- `character/Animate.client.luau`: animación de los sobrevivientes (reemplaza el script de Roblox).
- **Sonidos de juego** (`client/Sfx` + `Config.Sounds.Fx`): impacto y muerte de zombies y rugido del Tanque (3D), golpe recibido, caer, levantarse, prueba de acción (acierto/fallo), cargar y soltar, latas y compras, generador, radio, cuenta atrás de la furgoneta, victoria y derrota, y clics del menú y de los ajustes (el menú tiene los suyos en `Menu.client`). Salen de los atributos que ya llegan al cliente, sin remotes nuevos. Los ids (Pro Sound Effects, Daily Sounds y otros del Creator Store) se comprobó que cargan, pero no se ha oído cómo suenan en la partida: si alguno no convence, cambiar el id en `Config.Sounds.Fx`.
- **Farmacia de Doña Rosa** (`server/Pharmacy`, `client/EffectHud`, `Config.Pharmacy`, modelo `assets/vitrina-mostrador.glb` → `ZombieData/VitrinaMostrador`, 269 piezas): una vitrina por tramo (tienda, iglesia y terminal) donde, por 250 latas (× dificultad), una ruleta de jeringas gira 3,2 s sobre la vitrina como la caja de armas y se detiene en un efecto al azar; quien la toma (8 s) se inyecta. 4 efectos de 75 s con un bajón de 10 s: Furia (daño +30 %; bajón −25 %), Impulso (velocidad +25 %; −25 %), Adrenalina (+40 de vida máxima; −15 % de velocidad) y Pulso (recarga el doble de rápido; más lenta). Solo uno activo (el nuevo reemplaza al anterior); se pierde al caer o morir y al volver al lobby. El efecto vive en atributos del jugador (`FxId`, `FxPhase`, `FxEnd`, `FxDamage`, `FxSpeed`, `FxReload`) que leen `Weapons`, `PlayerState.refreshSpeed` y el HUD. Probado en Studio (ruleta, toma, efectos y bajón); sin oírlos ni jugarlos en una partida completa.
- **Revisión del 16 de octubre (mutadores y jeringas, sin jugar; solo se comprobó que compila y que el sorteo respeta las reglas):** 13 mutadores (nuevos: Niebla densa, Explosivos, Ruidoso, Sangrado, Cabezas duras; reglas en `Config.MutatorRules` y `Config.Zombie.Explosive`, ruido con `Zombies.noise`). Incompatibles: Cristal con Doble Tanque, Munición escasa con Economía floja, Niebla densa con Apagón, Zombies rápidos con Hordas grandes salvo en Crisis/Colapso (`Mutators.PairOnly`). Cristal da 60 de vida en Colapso; Economía floja sube los precios ×1,2. Tarjetas en el lobby: `client/MutatorCards` (monograma en vez de ícono; la pantalla de resultados no se tocó). Jeringas: 9 efectos (nuevos: Piel dura, Regeneración, Visión, Sigilo y Suero malo, peso 0,9 ≈ 10 %), cada bajón es el espejo de su efecto, 2 usos por vitrina y ronda (`Config.Pharmacy.MaxUses`); atributos nuevos `FxDefense`, `FxStealth`, `FxRegen`, `FxVision`.
- **Tiendas (16 de octubre):** la caja de armas, la estación de munición y objetos y la vitrina de la farmacia ya no están repartidas: viven juntas en una **Tienda** por tramo, bajo un pórtico con el cartel TIENDA (`MapBuilderBarrio.buildShop`; con `LEGACY_SHOPS = true` vuelven los lugares viejos). Tienda 1: callejón sin salida del Callejón (rect `T1` de `ALLEY`, x −115..−97); Tienda 2: antes `S4` del mercado (x −118..−86, z −88..−60); Tienda 3: rincón suroeste de la avenida (x −112..−88, z 292..328). La caja sale en un lugar fijo (`boxSpots` admite `CFrame`) y las vitrinas salen de `map.pharmacySpots` (`Pharmacy.place(spots)`); cada vitrina da 2 jeringas por ronda (`Config.Pharmacy.MaxUses`). El modelo de la vitrina se pinta en `Pharmacy.dress` (vidrios transparentes, mostrador verde y rótulo FARMACIA): PropModel no usa las texturas del .glb. Los puntos seguros solo dan la recarga gratis.
- **Inyectarse (16 de octubre):** al tomar la jeringa, `Pharmacy.inject` saca una jeringa en la mano (`ItemModel.hold(player, "Syringe", {color})`, émbolo y líquido animados con `ItemModel.setSyringe`), el personaje publica `ItemReady/ItemId/ItemStart/ItemEnd` y los brazos hacen el gesto de `ItemPoses.Syringe` (aguja al antebrazo izquierdo, empuja el émbolo, retira); el efecto empieza al 80 % del gesto (`Config.Pharmacy.Anim`, 2,8 s) con destello de pantalla (`EffectHud`). Para probarlo en cámara lenta se puede subir `Anim.Duration` y mover `ItemStart`; en Studio los prompts por `InputHoldBegin` no responden con la cámara en Scriptable. Se comprobó con números que la punta de la aguja queda a ~0,3 studs del antebrazo; no se vio el gesto completo en imagen.
- **Phial Roll (17 de octubre):** las jeringas se llaman **Phial** (textos y avisos). E en una vitrina libre abre el panel **PHIAL ROLL** (`client/PhialRoll`, diseño de Iker: cabecera con latas, tira de cartas que gira bajo una marca roja, franja de probabilidad, lista de los 9 efectos con su %, botón ROLL y SALIR); ROLL pide `Remotes.PhialUi("roll", clave)`, el servidor cobra y gira (`Pharmacy.startRoll`), manda `spin` al comprador (su tira gira y se detiene en el efecto sorteado) y `ready` (el botón pasa a INYECTAR con cuenta atrás de `Config.Pharmacy.TakeTime`); `take` o E sobre la vitrina inyecta (`takePhial`). Todos ven el nombre en la placa de la vitrina y en los avisos. Cada efecto tiene `Category`, `Rarity` (Común, Rara, Épica, Maldita en `Config.Pharmacy.Rarities`) y `Weight` = % (suman 100); textos del panel en `Config.Pharmacy.Ui`. Sin "garantizado cada N tiradas" ni Lázaro (el diseño los traía; no hay ese efecto). El destello de pantalla al inyectarse se quitó (parpadeaba) y las partículas y la luz de la mano son más suaves. Las luces de las Tiendas bajaron (`SHOP_BULB`, brillo 0,28 y 0,3). Probado en Studio: abrir, girar, aterrizar, INYECTAR y efecto aplicado; sin oír los sonidos ni ver el parpadeo en una partida real.
- **Cambios del 17 de octubre (tarde):** (1) **Cargar al compañero rehecho**: ya no se suelda ni se pasa la física (se peleaban el cliente del caído y el de quien carga); `Revive.carry` ancla el cuerpo del caído, el servidor lo mueve cada Heartbeat (`Config.Revive.CarryOffset`) y cada cliente lo pega a quien carga justo antes de dibujar (`client/CarryAttach`, etiqueta `CarriedBody` + atributo `CarriedBy`). Probado en Studio con un compañero falso (F cargó, siguió al que carga caminando y G lo soltó); **sigue sin probarse con dos jugadores reales**. (2) **Phial guardada**: GUARDAR/E en la vitrina ya no inyecta: pone el atributo `PhialId` y la Phial queda en un panel a la izquierda (`client/PhialSlot`, ícono en `client/PhialIcon`); se usa con **Z** o tocando el panel (`Remotes.PhialUi "use"` → `Pharmacy.useStored`); una a la vez; se pierde al morir. (3) Ícono de latas nuevo (`client/CanIcon`: lata gris con franja roja; contador "× N" en `LatasHud` y en PHIAL ROLL). (4) Guía de la **TIENDA** (`ObjectiveGuide` ahora crea dos guías; la de la tienda es `Workspace.ShopPos`, color `Config.Guide.ShopColor`, la publica `GameState.setStage` desde `map.shopPositions`). (5) El menú ya no pregunta por los mutadores en "Nueva sala" (solo en la sala del anfitrión).
- **Ruleta de mutaciones y rarezas (17 de octubre, noche):** hay 17 mutaciones en 5 rarezas (`Mutators.Rarities`): Común (peso 52, +15 a +20 % XP), Rara (29, +25 a +30 %), Épica (12, +40 a +45 %: Doble Tanque y los combos nuevos **Cacería**, **Mala sangre** y **Noche sin fin**), Legendaria (3, +100 %: **Apocalipsis**, solo en Crisis y Colapso) y Alivio (4, Generoso, 0 %). `Mutators.slices(dificultad)` reparte la rueda: cada casilla pesa su rareza entre las de su rareza (las raras son tajadas finas); `Mutators.roll` gira un ángulo al azar: el puntero de arriba cae en una casilla y el de abajo (a 180°) en la opuesta (se repite si son la misma o incompatibles); devuelve los ids y el ángulo (`Workspace.MutatorAngle`). El cliente (`client/MutatorWheel`, reemplaza a `MutatorCards`) anima la rueda al empezar el lobby (6,4 s, dos punteros, tarjetas con bono y bono total; sin íconos propios: monogramas). **XP de descubrimiento**: la primera vez que a un jugador le sale cada mutación gana `Mutators.DiscoveryXp` (100) al terminar la ronda (`PlayerProgress`, guardado en `seen` del DataStore, atributo `SeenMutators`). Estadística medida en Studio con 20.000 sorteos en Colapso: Común 58 %, Rara 29 %, Épica 9 %, Legendaria 2,4 %, Alivio 1,4 % por puntero. Sin balancear; la ruleta no tiene sonido propio ni se vio con la partida publicada.
- **Mutaciones siempre presentes (18 de octubre):** con los mutadores encendidos `Mutators.Count` ya no da 0 (Calma y Tensión: siempre 1; Crisis 1 o 2; Colapso 1 o 2); antes salía 0 con frecuencia y no aparecía ni la ruleta ni las fichas. Sin probar con el juego publicado.
- **Indicador de mutaciones (17 de octubre):** `client/MutatorHud` pone unas fichas en el borde izquierdo (arriba, bajo "MUTACIONES DE LA RONDA") con la insignia, el nombre, la rareza y el XP de cada mutación de la ronda; entran deslizándose, las épicas y la legendaria laten, y al pasar el cursor o tocar se despliega lo que hace. Se esconde en la votación, en los resultados y al caer. Reemplaza a la línea de texto que había bajo la dificultad.
- **Reconocimientos y récord (17 de octubre):** al final de la partida salen hasta 6 reconocimientos en la pantalla de resultados (`server/Awards`: el más asesino, el enfermero (revivió), el cargador, el más productivo (latas), puntería de oro (críticos), el saco de boxeo (daño recibido), el más caído, el que más murió y el adicto a las Phials; cada uno con mínimo, empate de dos se comparte, más de dos no se da). `Stats` ahora cuenta además `Carries`, `Downs`, `Deaths`, `Headshots` y `Phials` (ganchos en `Revive`, `PlayerState`, `Weapons` y `Pharmacy`) y `Stats.all()` trae las latas ganadas; `Remotes.Results` manda las estadísticas y los reconocimientos. **Récord de extracción rápida** (`server/Records`, DataStore `RhomulusRecords`, clave `run_<dificultad>`): el menor tiempo desde salir del lobby hasta ganar, por dificultad (equipo incluido); `GameState.result` lo manda con `Remotes.Record` y `ResultHud` muestra "TIEMPO m:ss · RÉCORD <dificultad>: m:ss" o "¡NUEVO RÉCORD!". Probado en Studio con datos de prueba; el guardado del récord no se probó (hace falta el juego publicado).
- **Mutadores de la ronda** (`shared/Mutators`, `Difficulty.setMutators`, sorteo en `GameState.rollMutators`): al elegirse la dificultad se sortean 0 a 2 reglas especiales (Calma 0 o 1; Tensión 0 o 1, casi siempre 1; Crisis 0 a 2; Colapso 1 o 2). Hay 8: Munición escasa (reserva ×0,5), Zombies rápidos, Doble Tanque, Hordas grandes, Economía floja (latas ×0,5), Cristal (50 de vida, curación ×2), Apagón total (faroles rotos) y Generoso (precios ×0,6, latas ×1,3; el bueno, sin bono). Cada uno da un bono de XP (+20 a +30 %), que se suma al de la dificultad. `Difficulty.get()` devuelve la dificultad ya con los mutadores aplicados (campos `Mutators` y `Flags`), así los sistemas existentes los notan solos; las reglas con efecto propio son `Flags.AmmoMult` (`Weapons`), `Flags.PlayerHealth` (`PlayerState`) y `Flags.Blackout` (`Atmosphere`). Se anuncian en el aviso del lobby y en una etiqueta bajo la dificultad (`Workspace.Mutators`); el sorteo va a la telemetría (`round_mutators`). **El anfitrión de una sala puede apagarlos** (interruptor MUTADORES en "Nueva sala" y en la sala del anfitrión; el estado va en la sala y en los datos de teletransporte como `mutators`; `GameState` no sortea si viene `false`); las partidas sin sala siempre los sortean. Sin fuego amigo todavía. Probado en Studio con 3 mutadores forzados; sin balancear.
- **Progresión (XP y nivel)** (`shared/Progress` + `server/PlayerProgress` + `Remotes.XpGain`; el menú lo lee en `src-menu/server/Progress.server`): al terminar la partida cada jugador recibe XP (1,5 por kill, 25 por revivir, +50 por terminar y +200 por ganar, por la dificultad: Calma ×0,8, Tensión ×1, Crisis ×1,3, Colapso ×1,6). Nivel: sube con `250 + 75·(nivel−1)` XP por nivel, hasta el 50. Se guarda por jugador en el DataStore `RhomulusProgress` (clave `p_<userId>`: xp, partidas, victorias, kills, revividos) con `UpdateAsync`; quien se va a mitad se lleva lo que llevaba sin los bonos. La pantalla de resultados muestra a **todos los supervivientes** con su avatar (cara de Roblox), kills, revividos, daño, `NIVEL N`, `+N XP` y su barra de nivel llenándose (el servidor manda la lista de todos con `Remotes.XpGain`); el menú muestra el **perfil** del jugador arriba a la derecha: avatar, nombre, `NIVEL N` y la barra de lo que le falta para el siguiente. **Dificultades por nivel** (`Progress.UnlockLevel`): Calma y Tensión desde el principio, Crisis en el nivel 5 y Colapso en el 10. Se comprueba en el servidor del menú (`create` y `setDifficulty`) y en la votación (`VoteRoom`); en una sala basta con que el anfitrión la tenga, y sin datos de nivel (guardado caído) se dejan todas. Las bloqueadas salen atenuadas con `NIVEL N` en el menú y en el panel de votación. Cosméticos todavía no. Probado en Studio (reparto y nivel con el DataStore apagado); sin probar con el juego publicado.
- **Otra partida** (`ResultHud` + `GameState.result` + `Remotes.PlayAgain`, `Config.Game.ResultTime/ResultMinTime`): el servidor publica `Workspace.ResultEnd` y el atributo `PlayAgain` de cada jugador; probado en Studio (con 1 jugador el resultado se adelanta a ~4 s; con varios jugadores no se ha probado).
- **Datos para balancear:** `server/Telemetry` manda eventos personalizados a Creator Hub (Analytics → Custom events): `stage` (embudo por etapa), `player_downed`, `player_died` y `round_end` (duración, ganó/perdió), cada uno con dificultad y número de jugadores en los campos. Sin probar con el juego publicado.
- `assets/*.glb` + `tools/glb_to_lua.py`: modelos 3D de origen y su conversor. Uso: `python tools/glb_to_lua.py <archivo-sin-.glb> <Modulo> [escala] [articulaciones]` (para cajas: articulación `tapa`). Los modelos se construyen con bloques nativos de Roblox, no se suben mallas.

**Celular (hecho en la rama `mobile-touch-controls`, PR contra `shop-items-polish`; falta probarlo con un dedo y un celular reales):**
- `client/Controls`: modo táctil (`isTouch()`, cambia solo en dispositivos híbridos; `touchChanged`), apuntar/disparar virtuales (`aim`, `firing`, `isAiming()`, `isFiring()`), la sensibilidad del jugador y `touchText` (traduce los avisos del servidor que nombran teclas).
- `client/TouchControls`: botones a la derecha (FUEGO con arrastre para girar, APUNTAR y CORRER que alternan, RECARGAR, CANCELAR objeto, E/F de contexto sobre los `ProximityPrompt` con `InputHoldBegin/End`, SOLTAR, LEVANTAR, LISTO) y arriba (vista, ayuda, ajustes). Se ordenan alrededor del salto de Roblox (70 px en pantallas pequeñas, 120 en grandes). El joystick y el salto los pone Roblox. El giro con un dedo sobre la pantalla también lo hace Roblox: `TouchControls` mide cuánto giró la cámara en el cuadro y lo completa hasta la sensibilidad (`Config.Touch`).
- Las acciones de teclado/ratón son funciones que comparten PC y celular: `Shooting.setFiring/reload`, `ItemUse.press/release/cancel`, `Sprint.setHeld`, `CameraController.setAiming/toggleView`, `TeamHud.drop/beginSelfRevive/endSelfRevive`, `GameHud.ready`, `HelpPanel.toggle`. Quien lea el ratón (Sprint, WeaponAnimator) debe preguntar a `Controls.isAiming()/isFiring()`.
- `client/SettingsPanel` (tecla `O` o engranaje): sensibilidad (también del ratón), calidad gráfica y panel de rendimiento.
- Textos: `HelpContent.get(touch)` (ayuda, controles y bienvenida; lo usan también el menú y `HelpPanel`) y `Controls.touchText`.
- Pantallas bajas: `client/UiFit` (`scale` encoge piezas del HUD según la altura, `fitPanel` ajusta paneles centrados, `isShort`, zonas seguras de los `ScreenGui` del HUD). No poner un `UIScale` en el `ScreenGui`: los fondos a pantalla completa quedarían más pequeños. `Inventory` es compacto en celular y solo muestra lo que se tiene.
- Calidad gráfica: `client/Performance` + `Config.Performance` (ALTA/MEDIA/BAJA, AUTO baja sola si los FPS caen). Guía y orden del plan B en `docs/rendimiento-celular.md` (el streaming del mapa se activa a mano en Studio: `StreamingTargetRadius` no se puede cambiar por código).
- Menú (`src-menu`): constante `TOUCH`, lienzo recortado, pestañas y casillas más altas, el teclado del código se cierra al escribir las 4 letras.
- **Menú v2 (17 de octubre, diseño de `Diseño de barra de vida zombies.zip`):** `src-menu/client/Menu.client.luau` restilizado: fondo casi negro, texto crema, rojo sangre (`RED`, `INK`, `PANEL`, `LINE`, `BGCOL`), título RHOMULUS con goteo, filas numeradas del menú principal, perfil con aro rojo, teclas crema en CONTROLES y casillas rojas al elegir. Se quitó la pantalla de "presiona cualquier tecla" y la opción MUTADORES de "Nueva sala" (queda solo en la sala del anfitrión). Verificado en Studio: principal, lista de salas, nueva sala, sala del anfitrión y las 4 pestañas de Cómo jugar; sin ver la ventana del código ni la sala de espera de invitados.
- **Salas del menú (`src-menu/server/Rooms.server.luau` + `src-menu/client/Menu.client.luau`):** cada sala vive en el `HashMap` "Rooms" de MemoryStore (clave interna de 5 letras; las privadas llevan además `pass`, el código de 4 letras, que nunca va en la lista) y la lista sale del `SortedMap` "RoomIndex", que refrescan los servidores con jugadores en la sala (caduca a los 10 s; al empezar o vaciarse la sala se quita). Acciones: `create({map, difficulty, public})`, `list`, `join(id, código)`, `leave`, `setMap`, `setDifficulty`, `setPublic`, `start`. En Studio sin publicar (MemoryStore falla) se usa un almacén en memoria y salen tres salas de ejemplo; así se puede probar sin publicar. Los avatares (cara de cada jugador) salen de `Players:GetUserThumbnailAsync(userId, HeadShot)` con los `ids` que manda el servidor en la sala y en la lista; los nuevos aparecen creciendo. Pantallas del cliente: `main`, `list` (filas `Fila<n>` con botón `Sala<n>`, ventana para el código), `setup`, `create` (sala del anfitrión), `joined`, `help`; todas se llaman `Pantalla_<nombre>` para poder pulsarlas por ruta en las pruebas.
- Orientación: `StarterGui.ScreenOrientation = LandscapeSensor` está fijada en `default.project.json` y `menu.project.json` (Rojo la aplica al sincronizar; hay que publicar los dos lugares).
- Probado en Studio con la ventana achicada (~805×385) y modo táctil forzado (15 de octubre): lobby, tarjeta de caído, resultados (victoria y derrota), sala de votación, lista de salas, nueva sala y sala del anfitrión se ven bien; se arreglaron la etiqueta de dificultad que pisaba la tarjeta de caído, el espectador y los resultados, y la barra de objetos que tapaba el botón VOLVER AL MENÚ.
- Pendiente del celular: probar con un dedo/celular real (tamaño de botones, sensibilidad, giro), revivir/cargar/levantarse/furgoneta con botones, espectador con compañeros reales (con un solo jugador no se pudo ver), y medir FPS.

**Controles:** clic = disparar (mantener = automática), clic derecho = apuntar, `R` recargar, `1`/`2`/`Q` cambiar de arma, `V` primera/tercera persona, `E` interactuar (revivir, abrir caja, comprar, generador, radio), `F` cargar a un caído, `G` soltar, `H` levantarse solo (1 jugador), `3` a `7` sacar/guardar un objeto (granada, botiquín, molotov, vendas, bengala): granada, molotov y bengala se cargan manteniendo el clic y se lanzan al soltar (clic derecho cancela); vendas y botiquín se usan con un clic (el botiquín cura al compañero herido que se mira o a uno mismo), `Shift` correr (mantener; se cancela al apuntar, disparar o recargar; el Shift lock está desactivado), `Y` listo en el lobby, `K` ayuda, `O` ajustes. En celular, cada una tiene su botón (ver "Celular").

**Cosas que aprendimos (para no repetir errores):**
- Si cambia `default.project.json` (carpetas nuevas), hay que **reiniciar `rojo serve`** y reconectar el plugin. Mantener una sola sesión de Rojo corriendo.
- En los modelos de articulaciones, el frente es `+Z` en el marco local: una rotación positiva en X manda hacia adelante lo que está arriba (torso, cabeza) y hacia atrás lo que cuelga (piernas, brazos). Las tapas se abren con rotación negativa.
- Ocultar interfaz en `BillboardGui` con transparencia no basta: apagarla con `Enabled = false`.
- `ColorSequence` admite máximo 20 puntos; las franjas usan 9.
- Las piezas llegan al cliente poco a poco: los animadores esperan a tener todas las articulaciones (atributo `JointCount`) antes de registrar un modelo.
- Al cargar el avatar, Roblox reemplaza las piezas del cuerpo justo después de `CharacterAdded`: espera `player:HasAppearanceLoaded()` antes de soldar algo al personaje (si no, queda pegado a una mano destruida y se cae).
- Para probar con las herramientas de Studio: `require` desde la herramienta crea una copia separada de los módulos (no sirve para cambiar valores del juego en marcha); para probar compras se bajan precios con un comentario `TEMP-PRUEBA` y se restauran (revisar con `grep TEMP-PRUEBA`). Los prompts a veces necesitan reintentarse tras un teletransporte.
- El tiempo de las pruebas puede pasar de los 8 s de `TakeTime` de la caja: tomar el arma en la misma llamada.
- **Probar el celular sin tocar los lugares publicados:** `rojo build default.project.json -o <temporal>.rbxl` (y `menu.project.json` para el menú), abrir ese archivo en una ventana nueva de Studio, forzar el modo táctil con un parche local (`touchMode = true` en `Controls`, `TOUCH = true` en el menú; marcar `TEMP-PRUEBA` y no commitear) y achicar la ventana a unos 1130×640 para un viewport de ~805×385. Para sincronizar cambios sin Rojo: servir `src` con `python -m http.server` y copiar los `Source` con `HttpService:GetAsync` desde `execute_luau`. El menú no funciona sin publicar (`MemoryStoreService`): anularlo solo en la copia de prueba.
- Con la herramienta de ratón: los clics por `instance_path` a un botón bajo `UIScale` o con `IgnoreGuiInset` caen unos 58 px más arriba que el botón; la tarjeta de bienvenida (`Help`, DisplayOrder 60) se come los clics en el lobby hasta que se cierra; con `MouseBehavior = LockCenter` los clics a botones fallan (en modo táctil el ratón queda libre). La herramienta no genera desplazamientos del ratón: el arrastre para girar solo se prueba con un gancho temporal.
- **Cargar a un caído** (`server/Revive`): los prompts E (revivir) y F (cargar) están en el mismo `HumanoidRootPart`. El de cargar usa `Exclusivity = AlwaysShow` y `GamepadKeyCode = ButtonY`: con la exclusividad por defecto (`OnePerButton`) en mando o pantalla táctil solo se muestra uno de los dos y F no sale. Si el servidor rechaza cargar, avisa en pantalla con el motivo (`canHelp` devuelve el motivo). Al cargar, el servidor pasa la física del caído a quien carga (`SetNetworkOwner`) y se la devuelve al soltar.
- **Pasar de zona al llegar todos:** `GameState.allInside(volumen)` exige a todos los vivos dentro del volumen a la vez, así que el volumen debe cubrir toda la zona de destino, no solo la puerta (en el estadio, `refs.stadiumInside` cubre la cancha y las gradas; `stadiumVolume` es solo el destino de la guía). Con una franja pequeña, si uno ya había avanzado cuando llegaba el último, nunca se cumplía.
- `MapBuilderBarrio.luau` pasa de 200.000 caracteres: desde `execute_luau` no se puede asignar su `Source` (límite de la herramienta); se prueba con Rojo o con un archivo `.rbxl` recién compilado.
- Las propiedades de streaming del `Workspace` (`StreamingTargetRadius`, `StreamingMinRadius`) son `Not Scriptable` y no hay radio por cliente: se ponen a mano en Studio y valen para todas las plataformas.

**Cómo trabaja Iker:** responder en español y al grano; **hacer preguntas de diseño antes de empezar cada fase o cambio grande**; probar en Studio antes de dar algo por hecho y decir qué no se pudo ver (las capturas de Studio funcionan con la herramienta de captura, pero la cámara del juego a veces las pisa); proponer commit con mensaje corto en español y pedir confirmación antes del `push`. Iker comparte capturas de diseños de referencia para la interfaz.

**Mapa 1 (después del MVP):** diseño en `docs/mapa-1-barrio.md` — barrio Morro Esperanza (referencia Brasil, todo en español) de la ciudad Rhomulus; 3 rutas por tramo que se juntan en cada punto seguro, 3 tramos y 2 puntos seguros, mapa de unos 800×240 studs, evento nuevo "Las garrafas" en el mercado, extracción en el estadio (Refugio Remo), botiquines, guía grande de objetivos (columna de luz, flecha en pantalla, flechas pintadas, un color por ruta). Primero mapa gris a nivel de calle; escaleras y azoteas después.

**Ideas guardadas (después del MVP):** deudas entre jugadores y "separarse sale caro" (ver identidad del juego), infección con jeringa que se vuelve verde, ruido que atrae hordas, voces en español (la ambientación latina ya está decidida, ver Decisiones abiertas), rol para quien carga, selector de dificultad, nombre del juego, lista final de frases de revivir.

---

# GDD

*Actualizado el 13 de octubre de 2026 con todo lo hecho hasta ahora (mapa 1, objetos, dificultades, menú con salas y celular).*

## Resumen

Un shooter cooperativo de zombies para 1 a 4 jugadores: el equipo cruza un mapa infestado, de un punto seguro a un punto de extracción, y solo gana si sobrevive junto.

| Campo | Decisión |
| --- | --- |
| Nombre | **Rhomulus** (decidido el 7 de oct. de 2026; falta confirmarlo con Isaac). Antes: "Proyecto Zombies" |
| Género | Acción / supervivencia cooperativa, con cámara en primera y tercera persona |
| Inspiración | Left 4 Dead: hordas, trabajo en equipo, revivir compañeros, extracción final; caja de armas al azar de los modos zombies de Call of Duty |
| Plataforma | PC y celular (controles táctiles hechos; falta probarlos con un dedo real); consola después |
| Jugadores | 1 a 4 por servidor, con salas privadas por código o partida con desconocidos |
| Duración de partida | 10 a 15 minutos |
| Público | Jugadores de Roblox de 12+ años que buscan acción en grupo |
| Desarrollo | Iker e Isaac; primer juego en Roblox Studio |
| Estado | Fase 7: pulido y prueba con amigos. El mapa 1 (Morro Esperanza) está completo y se juega de principio a fin |

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

El juego tiene tres mapas previstos, cada uno con su propio vehículo de extracción; todos siguen la misma estructura de partida de 10 a 15 minutos.

| Mapa | Ambiente | Extracción final | Estado |
| --- | --- | --- | --- |
| **Morro Esperanza** (barrio de la ciudad Rhomulus) | Favela latina de noche: callejones, escaleras, azoteas, tienda, iglesia, mercado, terminal y estadio | La furgoneta del Refugio Remo, que entra por el portón norte del estadio | **Hecho** (3 tramos, 2 puntos seguros) |
| Centro comercial | Pasillos, tiendas, escaleras eléctricas, estacionamiento | Un auto deportivo en el estacionamiento | Después |
| Aeropuerto | Terminal, bandas de equipaje, hangar y pista | Un avión que hay que alcanzar en la pista | Después |

Los mapas nuevos reutilizan todos los sistemas. El diseño del mapa 1 está en `docs/mapa-1-barrio.md`.

Estructura de cada partida:

1. **Menú de entrada** (otro lugar de la experiencia): título, y desde ahí *Jugar* (la **lista de salas** abiertas de todos los servidores: con jugadores x/4, mapa y dificultad; las **públicas** se entran con un toque y las **privadas** salen con candado y piden su código de 4 letras; las que ya empezaron no salen), *Crear partida* (pantalla de nueva sala: pública o privada, mapa y dificultad, con vista previa de cómo saldrá en la lista) y *Cómo jugar*. El anfitrión puede cambiar la sala entre pública y privada, el mapa y la dificultad hasta que pulsa Empezar; en una privada el código lo genera el juego. Con Empezar, cada sala va a su propio servidor reservado con el mapa y la dificultad elegidos (se salta la votación).
2. **Votación** (solo si se entra a la partida sin sala: sala aparte, 20 s, empate al azar): se vota la dificultad con 1 a 4 (o tocando el panel en celular). Las salas del menú ya traen mapa y dificultad.
3. **Lobby** (la cochera): maniquíes para practicar, tarjeta de bienvenida la primera vez, y *Listo* (`Y` o botón) para empezar.
4. **Tramo 1:** tres rutas (Calle, Callejón, Escalera) que se juntan en el primer punto seguro. Zombies sueltos, pocos recursos.
5. **Punto seguro 1 (la tienda):** sin zombies; estación de suministros y recarga gratis. Se avanza cuando todos están dentro.
6. **Tramo 2:** plaza con el generador, que abre la iglesia. Primero hay que llevarle **3 garrafas de gas** desde el mercado (cada entrega atrae zombies); al arrancar sale una horda con un Tanque. Emboscadas en las plazoletas.
7. **Punto seguro 2 (la iglesia).**
8. **Tramo 3:** terminal con emboscada y Tanque, avenida lateral y andenes, hasta la explanada.
9. **Extracción (estadio):** el equipo llama a la radio, aguanta una horda continua con Tanques periódicos durante la cuenta atrás hasta que llega la furgoneta y todos suben.
10. **Resultado:** victoria si al menos un jugador sube a la furgoneta; derrota si todos caen. Pantalla con estadísticas (kills, revividos, daño recibido) y dos botones: **OTRA PARTIDA** (con la cuenta atrás de 15 s hasta la siguiente; si todos los que quedan lo pulsan, se adelanta tras 3 s para poder leer las estadísticas) y volver al menú. Quien no pulsa nada sigue en el servidor y la partida siguiente empieza sola.

Cada ruta del tramo tiene su color (roja, amarilla, azul). La ruta Escalera tiene azoteas de 10 de alto con rampas, latas extra y botiquín arriba, más expuestas. Una columna de luz, un cartel con la distancia y una flecha en el borde de la pantalla guían hacia el objetivo.

Si un jugador muere, mira a sus compañeros en **modo espectador** (cambia de compañero con `A`/`D` o tocando su ficha) y reaparece en el siguiente punto seguro, igual que en Left 4 Dead. Así nadie se queda viendo la partida entera.

## Sistemas

Cada sistema se describe como está hoy en el juego; los valores numéricos viven en `Config` y se afinan en pruebas.

### Jugador

- Vida: 100 puntos. Al llegar a 0, el jugador cae (no muere): se arrastra, puede disparar la pistola y se desangra durante 30 s (cambia con la dificultad).
- Correr: mantener `Shift` (en celular, botón que alterna). Se cancela al apuntar, disparar o recargar.
- Revivir: un compañero mantiene `E` 4 s junto al caído y acierta una **prueba de acción** (un aro con una zona buena y una aguja; `Espacio`, o tocar el aro en celular). Lo levanta con 30 de vida. Mientras tanto, cada personaje dice una frase al azar en un globo de texto (después, con voz). Ejemplos del que revive: "¡Arriba, que todavía no es tu hora!", "¿Otra vez en el piso?", "Me debes una". Ejemplos del caído: "Ya me andaba", "Tardaste muchísimo".
- Cargar: un compañero puede levantar al caído (`F`) y llevarlo en hombros a un lugar seguro antes de revivirlo; se suelta con `G`. Quien carga camina más lento y solo usa la pistola; el caído sigue disparando desde el hombro. Las garrafas de gas se cargan igual.
- Levantarse solo: con 1 jugador, mantener `H` 3 s (veces por zona según la dificultad).
- Si nadie lo revive a tiempo, muere, mira a sus compañeros como espectador y reaparece en el siguiente punto seguro.
- Poses propias: caído (se arrastra), arrodillado al revivir y colgado al ser cargado.

### Armas

| Arma | Rol | Daño por tiro | Cargador | Notas |
| --- | --- | --- | --- | --- |
| Pistola | Secundaria, munición infinita | 20 | 12 | Siempre disponible, también estando caído |
| Rifle de asalto | Principal, todo terreno (común) | 25 | 30 | Automático |
| Escopeta | Principal, corto alcance (común) | 8 x 8 perdigones | 8 | Fuerte contra hordas en pasillos |
| Subfusil | Principal, mucha cadencia (rara) | 14 | 40 | Automático |

Disparo con raycast validado en el servidor (ver Arquitectura). Fuego amigo desactivado. Un tiro a la **cabeza hace x2** (crítico, con marcador y sonido solo para el tirador). Al disparar seguido la dispersión crece (**bloom**, con un aro en la mira que lo muestra). Clic derecho apunta con zoom. El arma activa va en la mano con los brazos animados (retroceso visual, recarga por tipo); la primaria queda a la espalda y la pistola en la cadera cuando no están en la mano.

### Caja de armas

Todos empiezan con pistola; las armas principales salen de una caja misteriosa, como en los modos zombies de Call of Duty.

- Cuesta **500 latas** del equipo (ver Latas).
- Al abrirla, las armas giran unos segundos sobre la caja con luz y melodía, y se detiene en una al azar (rifle, escopeta o subfusil). Hay 8 s para tomarla antes de que se pierda.
- Cada arma tiene rareza (común, rara): las raras salen menos.
- Hay una caja por zona, en un lugar distinto en cada partida, para que el equipo siempre tenga una adelante.
- Diseño propio de la caja y las armas, sin copiar modelos ni nombres de Call of Duty.
- Posibles armas futuras: francotirador, ametralladora ligera y un arma épica por mapa.

### Latas del equipo (puntos)

Las latas son una sola bolsa compartida por todo el equipo y se ven en la interfaz de todos, con un panel temporal del aporte de cada jugador.

- Se ganan matando (común 25, rápido 40, Tanque 150), reviviendo (50), cargando (20), completando cada zona (100), entregando una garrafa (50) y recogiendo **montones de latas** sueltos por el mapa (50; 75 en las azoteas).
- Se gastan en la caja de armas (500) y en las **estaciones de suministros** (ver Objetos y tienda).
- Cualquier jugador puede gastar; la interfaz avisa quién compró qué, para que el equipo se coordine. La dificultad multiplica precios y ganancias.

### Objetos y tienda

Barra de inventario de 7 ranuras: 1 = arma principal, 2 = pistola, 3 a 7 = objetos. Se sacan con su tecla (o tocando la ranura en celular) y se pierden al morir.

| Objeto | Precio | Máx. | Qué hace |
| --- | --- | --- | --- |
| Granada | 100 | 3 | 130 de daño en área (radio 14), mecha de 2 s; se carga la fuerza manteniendo el clic y se lanza al soltar, con el arco a la vista |
| Botiquín | 200 | 2 | Cura 80 en 5 s; a uno mismo o al compañero herido que se mira |
| Molotov | 125 | 2 | Fuego en el suelo durante 6 s (14 de daño cada 0,5 s, radio 8) |
| Vendas | 60 | 3 | Curan 25 en 1,2 s |
| Bengala | 75 | 2 | Atrae zombies durante 15 s (alcance 75) |

La **tienda de suministros** se abre con `E` en una estación de munición (150 latas la recarga) y vende todo lo anterior. Los botiquines también aparecen sueltos en el mapa nuevo.

### Dificultades

Se votan al inicio de cada ronda (o las elige el anfitrión de una sala). **Tensión** es el balance base. Calma y Tensión están abiertas desde el principio; **Crisis se desbloquea en el nivel 5 y Colapso en el 10** (en una sala basta con que el anfitrión la tenga).

| Dificultad | Zombies (vida / velocidad / daño) | Máx. vivos / hordas | Tanques | Precios / latas | Ayuda |
| --- | --- | --- | --- | --- | --- |
| Calma | x0,8 / x0,9 / x0,6 | x0,7 / x0,6 | Más espaciados | x0,8 / x1 | Caído aguanta x1,3; 2 levantadas solo |
| Tensión | x1 / x1 / x1 | x1 / x1 | Normal | x1 / x1 | 1 levantada solo |
| Crisis | x1,5 / x1,08 / x1,4 | x1,25 / x1,4 | +1 vivo, más seguidos | x1,25 / x1,15 | Curación x0,85; caído x0,85 |
| Colapso | x2 / x1,15 / x1,8 | x1,4 / x1,8 | +2 vivos, muy seguidos | x1,5 / x1,3 | Curación x0,7; caído x0,7; sin levantarse solo |

Hay un tope de 32 zombies vivos en cualquier dificultad (rendimiento en celular).

### Cámara

El jugador cambia entre primera y tercera persona con una tecla (`V`; botón en celular). La tercera persona es sobre el hombro; el disparo sale del centro de la pantalla en ambas para que apuntar se sienta igual. Con clic derecho (o el botón de apuntar) hay zoom y la sensibilidad baja. La sensibilidad es ajustable por el jugador (`O`).

### Enemigos

| Enemigo | Vida | Comportamiento | Estado |
| --- | --- | --- | --- |
| Zombie común | 50 | Persigue al jugador más cercano y golpea (10 de daño) | Hecho |
| Zombie rápido | 30 | Corre al doble de velocidad, poca vida | Hecho |
| Zombie Tanque | 1500 | Lento, golpea fuerte (35); aparece en la horda del generador, en la emboscada de la terminal y cada cierto tiempo en la extracción | Hecho |
| Zombie especial que atrapa a un jugador | 150 | Inmoviliza a un jugador; la víctima se libera presionando una tecla muchas veces (en celular, tocando un botón rápido) o un compañero le dispara al zombie | Después |

IA básica: buscar al jugador más cercano con `PathfindingService`, recalcular la ruta cada 0.5 a 1 s, atacar al estar a menos de 4 studs. Los zombies trepan a los techos bajos (autobuses) en 4 o 5 segundos. Modelos propios hechos con bloques de Roblox; el común tiene un modo ligero de menos piezas.

### Director de hordas

Un script del servidor decide cuándo y dónde aparecen zombies, fuera de la vista de los jugadores: límite de zombies vivos, puntos de aparición por zona, hordas en los eventos (generador, garrafas, extracción) y **emboscadas** al entrar en las plazoletas. Más adelante puede volverse dinámico (más presión si el equipo va bien, respiro si va mal), como el "AI Director" de Left 4 Dead.

Se ajusta al número de jugadores al iniciar la partida y se multiplica por la dificultad:

| Jugadores | Zombies vivos máx. | Tamaño de horda | Tanques a la vez | Ajuste extra |
| --- | --- | --- | --- | --- |
| 1 | 10 | 25% | 1 | Puede levantarse solo (por zona, según dificultad) |
| 2 | 18 | 60% | 1 | Ninguno |
| 3 | 22 | 80% | 2 | Ninguno |
| 4 | 25 | 100% | 2 | Ninguno |

En la extracción la presión **sube con la cuenta atrás** (`Config.Director.Extraction`): el tope de vivos va del 80% al 130% del máximo (con tope de 32), la pausa entre apariciones baja de 2,5 s a 1 s, y salen oleadas cada 22 s que en el último minuto pasan a cada 12 s y más grandes. Todo se multiplica por jugadores y dificultad. Si alguien sale o entra a mitad de partida, los valores se recalculan en el siguiente punto seguro.

### Recursos

- Munición: se compra con latas en las estaciones de suministros; cada punto seguro da una recarga gratis.
- Curación: botiquín (80 en 5 s) y vendas (25 en 1,2 s); ambos sirven en uno mismo, el botiquín también en un compañero.

### Interfaz (UI)

- Estilo propio, con tipografía Oswald, placas inclinadas y cinta de peligro: munición junto a la mira (4 estilos), jeringa de sangre, latas y aporte del equipo, inventario de 7 ranuras, panel de radio con las órdenes del comandante, placas de señalética, prompts con precio, barras de vida de enemigos, guía de objetivo, tarjeta de caído, espectador con fichas, pantallas de victoria y derrota.
- Vida y estado de cada compañero (normal, caído, muerto) y marcador sobre los caídos.
- Ayuda "Cómo jugar" (`K`): objetivo, controles, consejos y dificultades; también en el menú. Tarjeta de bienvenida la primera vez.
- Ajustes (`O`): sensibilidad, calidad gráfica y panel de rendimiento.

### Controles en celular

El joystick y el salto los pone Roblox; el giro es arrastrar el dedo por la pantalla. A la derecha: FUEGO (mantener = automática; arrastrar sin soltar gira la cámara), APUNTAR y CORRER (alternan), RECARGAR y CANCELAR (al cargar un lanzamiento). Los botones **E** y **F** aparecen solo cuando hay algo cerca (revivir, caja, comprar, generador, radio, furgoneta…), y SOLTAR, LEVANTAR y LISTO cuando corresponde. Arriba: vista, ayuda y ajustes. Los textos de ayuda, bienvenida y radio tienen versión táctil. La interfaz se encoge en pantallas bajas y respeta las zonas seguras (muescas).

### Guardado de datos

Se guardan con `DataStoreService` (por jugador) la sensibilidad y la calidad gráfica (`server/SettingsState` + `client/SettingsSave`) y si ya vio la bienvenida (`server/HelpState`). Monedas, desbloqueos y estadísticas totales vienen después.

### Estilo visual

Realista y atractivo, con una regla por encima de todo: el juego debe correr bien en PC, celular y consola.

- **Noche de terror latina:** luz de luna, niebla, linterna del jugador, faroles que parpadean y se apagan (apagones con chispas), carteles pintados a mano, grafitis, sangre estilizada y detalles de barrio. Se puede apagar con `Config.Atmosphere.Enabled`.
- Iluminación y `Atmosphere` para niebla; materiales PBR (`SurfaceAppearance`) solo en lo que se ve de cerca.
- Presupuesto de rendimiento: modelos con pocas piezas, texturas reutilizadas, decoración anclada y sin colisión, y `StreamingEnabled` activado si hace falta.
- Zombies ligeros: pocas piezas por modelo; el límite de zombies vivos también protege el rendimiento.
- Meta: 30 FPS estables en un celular de gama media; cada mapa se prueba ahí antes de darlo por terminado. El cliente tiene tres niveles de calidad gráfica (ALTA, MEDIA, BAJA) con bajada automática si los FPS caen, y un panel de rendimiento para medir en el dispositivo; el plan B está en `docs/rendimiento-celular.md`.
- Primero se construye cada mapa en bloques grises para probar que sea divertido, y después se hace el pase de arte.

### Audio

El sonido carga la mitad de la tensión: el jugador debe poder oír una horda antes de verla.

| Elemento | Qué hace | Estado |
| --- | --- | --- |
| Zombies en 3D | Gruñidos y pasos que suenan desde su posición, para saber de dónde vienen | Hecho |
| Aviso de horda | Una sirena distintiva segundos antes de cada horda | Hecho |
| Armas | Disparo, recarga y "clic" sin munición para cada arma | Hecho |
| Música dinámica | Cambia por estado: calma, tensión, horda y extracción | Hecho (versión simple) |
| Caja de armas | Melodía propia mientras giran las armas | Hecho |
| Ambiente de noche | Viento, sirenas, perros, ruidos sueltos cerca, latido con zombies cerca o poca vida, y sonido por zona del barrio | Hecho |
| Furgoneta | Frenada, pitido y baliza al llegar | Hecho |
| Combate, equipo y mundo | Impactos y muerte de zombies, rugido del Tanque, golpes recibidos, caer y levantarse, prueba de acción, cargar, latas y compras, generador, radio, cuenta atrás y final; clics del menú | Hecho (sin oír en partida) |
| Voces | Las frases de revivir y avisos como "¡Horda!" o "Recargando"; voces en español | Después |

Los sonidos deben ser propios o tener licencia libre (por ejemplo, del Creator Store de Roblox).

## Alcance: MVP vs después

El MVP es una partida completa y jugable de principio a fin con 1 a 4 amigos. Todo lo demás espera hasta que eso funcione y sea divertido. Lo que ya está hecho aparece en la columna izquierda; la regla de oro sigue valiendo para lo de la derecha.

| Hecho (entró al MVP o antes de tiempo) | Después del MVP |
| --- | --- |
| Mapa 1 Morro Esperanza completo (3 tramos, 2 puntos seguros, extracción en furgoneta) | Centro comercial (auto deportivo) y aeropuerto (avión) |
| Pistola inicial, caja de armas con rifle, escopeta y subfusil, críticos, bloom y brazos animados | Más armas en la caja (francotirador, ametralladora), arma épica por mapa, cuerpo a cuerpo |
| Zombie común, rápido y Tanque | Zombies especiales (el que atrapa a un jugador) |
| Caída, revivir con frases y prueba de acción, cargar al compañero, levantarse solo, espectador y reaparición | Fuego amigo |
| Director de hordas con límite por jugadores, 4 dificultades votables, emboscadas y eventos (garrafas, generador, radio) | Director dinámico que ajusta la presión |
| Latas del equipo, tienda de suministros, granada, botiquín, molotov, vendas y bengala | Marcadores de ítems, chat de voz rápido |
| Menú de entrada con salas por código y votación de mapa y dificultad | Más mapas en la votación |
| Interfaz propia completa, ayuda "Cómo jugar" y ajustes de sensibilidad | Voces en español, más frases de revivir |
| Noche de terror, pase de arte del mapa 1 y sonido ambiente | Pase de arte de más mapas |
| PC y celular (controles táctiles, interfaz adaptada, calidad gráfica con bajada automática) | Consola, y probar el celular con un dedo y un dispositivo reales |
| Ajustes guardados (sensibilidad y calidad) | Monedas, desbloqueos y estadísticas con DataStore |

## Identidad del juego (después del MVP)

Lo que nos diferencia de otros juegos de zombies: **"nadie se queda atrás"**. Cargar al compañero en hombros mientras sigue disparando ya es parte del juego; estas dos ideas lo refuerzan. Entran después del MVP, cuando un grupo de amigos lo haya terminado y quiera jugarlo otra vez (ver regla de oro).

1. **Deudas entre jugadores.** Cada vez que alguien te revive, le debes una (como dicen las frases: "Me debes una"). Si luego lo revives tú, quedan a mano. La pantalla de resultados muestra quién debe a quién ("Iker le debe 2 a Isaac") y quién es el mayor deudor.
2. **Separarse sale caro.** El director de hordas manda más zombies hacia quien está lejos del equipo, o quien está solo recibe más daño. Es una regla del juego, no solo un consejo.

Ideas guardadas para más adelante (no decididas): ruido que atrae hordas (armas silenciadas o cuerpo a cuerpo como respiro), ambientación y voces latinas en español, y un rol para quien va en hombros (marca zombies para quien lo carga).

## Arquitectura técnica en Roblox

Toda la lógica que importa (daño, vida, zombies) vive en el servidor; el cliente solo detecta lo que hace el jugador y muestra el resultado.

Estructura cliente-servidor:

- **Servidor (`ServerScriptService`, autoridad):** armas (valida cada disparo, raycast y daño), director de hordas (aparece zombies fuera de la vista; el máximo vivo sale del número de jugadores y la dificultad, con tope de 32), IA de zombies (`PathfindingService` hacia el jugador más cercano), estado de partida (vida, caída, revivir, zonas y extracción).
- **Compartido (`ReplicatedStorage`):** RemoteEvents (único canal cliente-servidor), módulos compartidos (datos de armas y enemigos), assets (modelos de zombies y armas).
- **Cliente (`StarterPlayer` / `StarterGui`):** controles (detecta clic y teclas, pide acciones al servidor), UI (vida, munición, equipo, resultados), cámara y efectos.
- **Dos lugares en una experiencia:** el *menú* (`menu.project.json`, `src-menu`: título, salas por código con `MemoryStoreService` y teletransporte) y la *partida* (`default.project.json`, `src`). Comparten `Places`, `Difficulties` y `HelpContent`. Nunca se conectan los dos proyectos de Rojo a la misma ventana de Studio.
- **Entrada unificada:** PC y celular llaman a las mismas funciones del cliente (disparar, recargar, usar objeto, soltar…); `Controls` guarda el modo táctil y la sensibilidad, y `TouchControls` pone los botones. El servidor no distingue dispositivos.
- Flujo: el cliente pide (disparar, revivir, usar botiquín) → el servidor responde (vida, munición, estado del equipo).

El cliente nunca dice "le hice 50 de daño"; dice "disparé hacia aquí" y el servidor decide si le dio y cuánto daño hizo. Así se evitan trampas y los cuatro jugadores ven lo mismo.

Reglas de organización desde el día uno:

- Un `ModuleScript` por sistema (armas, zombies, director, estado de partida), en vez de un script gigante.
- Los valores de balance (daño, vida, velocidad) van en un módulo de configuración, no repartidos en el código.
- Los zombies no usan física pesada ni demasiadas piezas: el límite de zombies vivos es por rendimiento. Lo que solo afecta a la pantalla de cada jugador (calidad gráfica, tamaño de la interfaz) se resuelve en el cliente y no cambia el juego de los demás.

## Plan de desarrollo y decisiones abiertas

Cada fase termina con algo que se puede probar en Studio; no se pasa a la siguiente hasta cumplir su criterio.

1. ~~**Fundamentos de Roblox**~~ (omitida: se va directo a construir).
2. ~~**Disparar:**~~ pistola con raycast validado en el servidor, munición y cámara en primera y tercera persona.
3. ~~**Un zombie:**~~ IA que persigue y ataca.
4. ~~**Muchos zombies:**~~ puntos de aparición y director simple con límite.
5. ~~**Cooperativo:**~~ caída, revivir con frases, cargar al compañero, reaparición y UI de equipo.
6. ~~**El mapa:**~~ partida completa de inicio a fin (primero un mapa gris de prueba, ya retirado; después Morro Esperanza).
7. **Pulido y prueba con amigos** (fase actual): sonidos, balance, bugs, rendimiento y celular. Listo cuando: 3 amigos terminan una partida y quieren otra. Después se construyen el centro comercial y el aeropuerto con los mismos sistemas.

Pendiente de la fase 7: probar con Isaac y más jugadores (revivir, cargar, derrota con varios), balance, medir los FPS en un celular real y probar los controles táctiles con un dedo, publicar el juego para los amigos.

### Decisiones abiertas

- [x] Cámara: primera y tercera persona, a elección del jugador
- [x] Estilo visual: realista pero optimizado para correr bien en todos lados
- [x] Extracción distinta por mapa: van, auto deportivo y avión
- [x] Nombre: Rhomulus. Ambientación: **apocalipsis latinoamericano** (barrio en ruinas: carteles pintados a mano, tiendas de barrio, buses, murales, radio de emergencia en español, jerga local). Textos, radio, carteles y sonido ambiente ya aplicados en el mapa 1; faltan las voces
- [x] Flujo de trabajo: Rojo + Git + GitHub desde el inicio (la partida y el menú son dos lugares con proyectos de Rojo distintos)
- [x] Precios de la caja de armas y de la munición (500 y 150 latas; se pueden afinar en pruebas)
- [x] Dificultad elegible: cuatro niveles (Calma, Tensión, Crisis, Colapso), votados en la partida o elegidos por el anfitrión de una sala
- [x] Plataforma móvil: controles táctiles, interfaz en pantallas bajas y calidad gráfica adaptable
- [ ] Lista final de frases para revivir
- [ ] Nombre final del juego, confirmado con Isaac
- [x] Guardar los ajustes del jugador (sensibilidad, calidad) entre partidas (hecho; sin probar con el juego publicado)
- [ ] Consola: controles y pruebas
