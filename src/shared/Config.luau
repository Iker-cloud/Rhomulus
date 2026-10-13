-- Valores de balance. Todo número ajustable vive aquí.
return {
	Weapons = {
		Pistol = {
			Name = "Pistola",
			AmmoStyle = "Ring", -- anillo de balas
			Damage = 20,
			Pellets = 1,
			Spread = 0, -- grados de dispersión
			MagSize = 12,
			FireCooldown = 0.25, -- segundos entre disparos
			ReloadTime = 1.5,
			Range = 300,
			Auto = false,
			InfiniteReserve = true,
		},
		Rifle = {
			Name = "Rifle",
			AmmoStyle = "Drum", -- tambor giratorio
			Damage = 25,
			Pellets = 1,
			Spread = 1,
			MagSize = 30,
			FireCooldown = 0.1,
			ReloadTime = 2,
			Range = 400,
			Auto = true,
			ReserveStart = 90,
			MaxReserve = 150,
			Rarity = "Común",
			Weight = 40, -- probabilidad relativa en la caja
		},
		Shotgun = {
			Name = "Escopeta",
			AmmoStyle = "Shells", -- casquillos y cinta
			Damage = 8, -- por perdigón
			Pellets = 8,
			Spread = 6,
			MagSize = 8,
			FireCooldown = 0.9,
			ReloadTime = 2.5,
			Range = 80,
			Auto = false,
			ReserveStart = 32,
			MaxReserve = 56,
			Rarity = "Común",
			Weight = 35,
		},
		SMG = {
			Name = "Subfusil",
			AmmoStyle = "Magazine", -- cargador transparente
			Damage = 14,
			Pellets = 1,
			Spread = 2.5,
			MagSize = 40,
			FireCooldown = 0.07,
			ReloadTime = 1.8,
			Range = 250,
			Auto = true,
			ReserveStart = 120,
			MaxReserve = 200,
			Rarity = "Rara",
			Weight = 25,
		},
	},

	-- Armas en la mano (ver server/WeaponRig y client/WeaponAnimator).
	-- Los puntos Grip/Fore/Mag/Muzzle están en coordenadas del modelo (ZombieData): cañón hacia -X, arriba +Y.
	--   Grip = donde la mano derecha agarra · Fore = donde se apoya la izquierda · Mag = cargador (o puerto de la escopeta)
	-- HighGrip/LowGrip: posición de la mano derecha respecto al pecho (X derecha, Y arriba, -Z adelante), con el arma
	-- arriba (apuntando) o abajo (en reposo). Kick = studs que patea hacia atrás, Rise = cuánto sube el cañón (rad),
	-- Camera = sacudida de cámara por disparo (grados).
	WeaponHold = {
		-- Marco de la palma en la mano (R15): el arma queda con el cañón hacia donde apunta el antebrazo
		HandGrip = CFrame.new(0, -0.16, 0) * CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 1, 0), Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0)),
		LowPitch = -0.9, -- inclinación del arma en reposo (rad, negativo = hacia el suelo; cada arma puede poner el suyo)
		RaiseTime = 1.5, -- segundos que el arma sigue arriba después de disparar
		Convergence = 0.1, -- al apuntar el arma gira hacia la derecha (rad): la cámara está sobre el hombro derecho y la mira queda al centro. Cada arma puede poner la suya
		RaiseSpeed = 9, -- qué tan rápido sube y baja
		Belt = Vector3.new(-0.7, -1.4, -0.1), -- donde la mano izquierda busca cargadores y cartuchos (cadera izquierda)

		Pistol = {
			Scale = 0.9,
			Grip = Vector3.new(0.446, 0.37, 0),
			Fore = Vector3.new(0.42, 0.18, 0),
			Mag = Vector3.new(0.5, 0.1, 0),
			Muzzle = Vector3.new(-0.72, 0.84, 0),
			HighGrip = Vector3.new(0.8, -0.3, -1.4), -- brazo estirado a la derecha y al frente: se ve junto al personaje con la cámara sobre el hombro
			LowGrip = Vector3.new(0.85, -0.9, -0.6), -- en reposo va a un lado de la cadera, a la vista desde la cámara sobre el hombro
			LowPitch = -0.3,
			TwoHanded = false,
			Support = false, -- al apuntar, la izquierda no la agarra (el brazo estirado no alcanza)
			Reload = "Mag",
			Kick = 0.25,
			Rise = 0.12,
			Camera = 1.2,
		},
		Rifle = {
			Scale = 0.9,
			Grip = Vector3.new(0.3, 0.31, 0),
			Fore = Vector3.new(-0.2, 0.52, 0),
			Mag = Vector3.new(-0.19, 0.25, 0),
			Muzzle = Vector3.new(-1.95, 0.646, 0),
			-- Apuntando: a la altura del hombro y a la derecha, girada hacia la mira. Medido con la pose real: se ve desde
			-- la cámara sobre el hombro y no atraviesa el brazo (las armas largas no pueden ir al centro del pecho)
			HighGrip = Vector3.new(0.7, 0.3, -0.5),
			Convergence = 0.35,
			LowGrip = Vector3.new(0.7, -0.85, -0.3),
			TwoHanded = true,
			Reload = "Mag",
			Kick = 0.22,
			Rise = 0.05,
			Camera = 0.6,
		},
		Shotgun = {
			Scale = 0.9,
			Grip = Vector3.new(0.289, 0.177, 0),
			Fore = Vector3.new(-0.2, 0.3, 0),
			Mag = Vector3.new(0, 0.32, 0), -- puerto de carga
			Muzzle = Vector3.new(-1.254, 0.485, 0),
			HighGrip = Vector3.new(0.7, 0.3, -0.5),
			Convergence = 0.35,
			LowGrip = Vector3.new(0.7, -0.85, -0.3),
			TwoHanded = true,
			Reload = "Shell", -- cartuchos de uno en uno
			ShellLoops = 4,
			Kick = 0.5,
			Rise = 0.3,
			Camera = 3,
		},
		SMG = {
			Scale = 0.9,
			Grip = Vector3.new(0.2, 0.45, 0),
			Fore = Vector3.new(-0.15, 0.55, 0),
			Mag = Vector3.new(-0.288, 0.3, 0),
			Muzzle = Vector3.new(-1.29, 0.774, 0),
			HighGrip = Vector3.new(0.7, 0.3, -0.5),
			Convergence = 0.15,
			LowGrip = Vector3.new(0.7, -0.85, -0.3),
			TwoHanded = true,
			Reload = "Mag",
			Kick = 0.15,
			Rise = 0.04,
			Camera = 0.5,
		},
	},

	-- Sonidos (Creator Store, gratis). Cambia cualquier id aquí para sustituirlo.
	Sounds = {
		Volume = { Headshot = 0.9, Shot = 0.6, Reload = 0.5, DryFire = 0.5, Zombie = 0.7, Siren = 0.7, Box = 0.6, VanHorn = 0.9 },
		Shot = {
			Pistol = "rbxassetid://132539859090895",
			Rifle = "rbxassetid://113879008765178",
			Shotgun = "rbxassetid://132711300701696",
			SMG = "rbxassetid://92967624763578",
		},
		ShotPitch = { SMG = 1.35 }, -- el subfusil reutiliza el tiro de pistola, más agudo
		Reload = "rbxassetid://117963160131194",
		ReloadShotgun = "rbxassetid://139827026287805",
		DryFire = "rbxassetid://117629133235583",
		Headshot = "rbxassetid://137096881472307", -- "ding" de headshot (0.6 s, Creator Store). Suena solo para quien dispara
		HeadshotPitch = 1,
		ZombieGrowls = {
			"rbxassetid://129294628821291",
			"rbxassetid://100949226522885",
			"rbxassetid://130156156621885",
		},
		HordeSiren = "rbxassetid://9119163479",
		VanHorn = "rbxassetid://93042705532380", -- pitido de la furgoneta al entrar (dura 1.5 s)
		BoxSpin = "rbxassetid://9046019442",
		-- Furgoneta de rescate (client/VanAnimator): puertas, motor, marcha atrás y derrape al irse. Suenan en 3D desde la furgoneta.
		Van = {
			Door = { "rbxassetid://140296030450157", 0.8 },
			EngineStart = { "rbxassetid://80004844856889", 0.9 },
			EngineLoop = { "rbxassetid://112247549523842", 0.7 }, -- bucle; el tono sube con la velocidad
			ReverseBeep = { "rbxassetid://5471337533", 0.9 },
			Skid = { "rbxassetid://73429750798250", 1.0 },
		},
		-- Objetos de la tienda (server/Items y server/Medkits). Suenan en 3D desde el servidor. Todos de Pro Sound Effects salvo
		-- la explosión y el fuego (Creator Store). Volumen y tono por sonido: { id, volume, pitch }.
		Items = {
			PinPull = { "rbxassetid://9114659833", 0.7, 1 }, -- la granada: tirar del pasador
			Throw = { "rbxassetid://9113836369", 0.45, 1.5 }, -- lanzar: silbido de tela rápido y agudo
			Explosion = { "rbxassetid://126212934401370", 1, 1 },
			GlassBreak = { "rbxassetid://9114591515", 0.8, 1.1 }, -- el molotov se rompe
			FireLoop = { "rbxassetid://116275103627699", 0.6, 1 }, -- zona de fuego (bucle mientras dura)
			FlareShot = { "rbxassetid://132539859090895", 0.55, 0.65 }, -- la pistola de bengalas: tiro de pistola grave
			FlareHiss = { "rbxassetid://9112780743", 0.5, 1 }, -- bengala encendida (bucle)
			BandageRip = { "rbxassetid://9113836270", 0.6, 1 }, -- vendas
			MedkitOpen = { "rbxassetid://117629133235583", 0.6, 0.7 }, -- cierre del botiquín: clic grave
			MedkitRip = { "rbxassetid://9113836102", 0.6, 0.9 }, -- cinta / venda del botiquín
		},
		Music = {
			Calm = "rbxassetid://9046799798", -- lobby, punto seguro y resultados
			Tension = "rbxassetid://131562091269894", -- explorando
			Horde = "rbxassetid://9045941477", -- muchos zombies cerca
			Extraction = "rbxassetid://9044584201", -- aguantando hasta la van
		},
		MusicVolume = 0.35,
		HordeNearCount = 6, -- zombies cerca para que suene la música de horda
		HordeNearDistance = 45,
		HordeMusicHold = 10, -- segundos que se mantiene tras la última horda
		-- Ambiente de noche (client/NightSounds y client/NightLights). Casi todo es de Pro Sound Effects y APM.
		Night = {
			Wind = "rbxassetid://9113286969", -- viento con aullido bajo (bucle)
			Sirens = "rbxassetid://9112871933", -- sirenas de policía lejanas (bucle)
			Drone = "rbxassetid://9114244977", -- zumbido fantasmal de fondo (bucle)
			Heartbeat = "rbxassetid://9043365842", -- latido a 96 pulsaciones (bucle)
			Spark = "rbxassetid://9116275998", -- chispazo del farol que se apaga
			Dogs = "rbxassetid://8678449977", -- perros que ladran lejos
			-- Sonido por zona del mapa nuevo (client/NightSounds): suena en bucle dentro de la caja, o con campanas cada cierto tiempo
			Zones = {
				{ name = "Iglesia", box = { -60, 60, 140, 214 }, bell = "rbxassetid://9113803790", bellInterval = { 14, 26 }, bellVolume = 0.7 },
				{ name = "Mercado", box = { -120, -64, -32, 78 }, loop = "rbxassetid://9112852458", volume = 0.3 }, -- llovizna sobre lámina
				{ name = "Terminal", box = { -62, 62, 200, 330 }, loop = "rbxassetid://9112792684", volume = 0.22 }, -- motores y grillos lejos
				{ name = "Estadio", box = { -122, 122, 330, 440 }, loop = "rbxassetid://9125602882", volume = 0.28 }, -- tonos huecos
			},
			-- Ruidos sueltos cerca del jugador (además de los gruñidos de ZombieGrowls)
			Noises = {
				"rbxassetid://9116521880", -- golpe de metal (tubo)
				"rbxassetid://9126090979", -- mesa que cae
				"rbxassetid://9113472225", -- tropiezo y caída
				"rbxassetid://139826391278483", -- cristal roto
			},
		},
	},

	-- Animaciones oficiales de Roblox (paquetes R15). Cambia cualquier id aquí para sustituirlo.
	Animations = {
		-- Sobrevivientes: paquete Antiguo (Oldschool). Alternativa: Ninja (Idle 10921156883, Walk 10921162768, Run 10921157929, Jump 10921160088, Fall 10921159222)
		Survivor = {
			Idle = "rbxassetid://10921233298",
			Walk = "rbxassetid://10921244891",
			Run = "rbxassetid://10921240218",
			Jump = "rbxassetid://10921242013",
			Fall = "rbxassetid://10921241244",
		},
		RunSpeed = 8, -- por encima de esta velocidad se usa la animación de correr
		-- Subir a la furgoneta (server/Boarding): oficiales de Roblox
		Boarding = {
			Walk = "rbxassetid://10921244891", -- el mismo paso de los sobrevivientes
			Climb = "rbxassetid://507765644", -- trepar
			Sit = "rbxassetid://2506281703", -- sentado
		},
	},

	WeaponBox = {
		Cost = 500,
		AmmoCost = 150,
		SpinTime = 3, -- segundos girando
		TakeTime = 8, -- segundos para tomar el arma antes de que se pierda
		Pool = { "Rifle", "Shotgun", "SMG" },
	},

	-- Latas del equipo (la moneda compartida; el módulo se llama Points)
	Points = {
		Kill = { Common = 25, Fast = 40, Tank = 150 },
		Revive = 50,
		Carry = 20,
		ZoneComplete = 100,
	},

	-- Tiro a la cabeza: cuenta si el rayo pasa a menos de (tamaño del cráneo * RadiusScale) del centro de la cabeza.
	-- Depth = cuánto más allá del impacto en la caja del zombie se sigue buscando la cabeza.
	-- Ojo: el servidor no ve las animaciones de los zombies (se animan en el cliente): la cabeza se toma en su pose base.
	Headshot = { Multiplier = 2, RadiusScale = 0.4, Depth = 1.5, PartNames = { "Head", "saco_cabeza" } }, -- saco_cabeza = cabeza del maniquí

	-- Guía de objetivo (client/ObjectiveGuide): columna de luz en el mundo, flecha en el borde de la pantalla y distancia.
	-- El servidor publica la posición del objetivo de cada orden (GameState.OBJECTIVES).
	Guide = {
		Enabled = true,
		Color = Color3.fromRGB(255, 205, 60),
		ShowBeam = false, -- columna de luz en el mundo (apagada: basta con el cartel de nombre y distancia)
		BeaconHeight = 140, -- altura de la columna de luz (studs)
		BeaconWidth = 4,
		EdgeMargin = 70, -- px que separan la flecha del borde de la pantalla
		ArrowSize = 64,
		StudsPerMeter = 3.571, -- para mostrar la distancia en metros (un avatar de 5 studs ~ 1.75 m)
	},

	-- Tolerancia de puntería: radio (en studs) de la esfera con la que se busca un zombie cuando el rayo no le da.
	-- Compensa el retraso de red: en pantalla los zombies van un poco por detrás de donde están en el servidor.
	HitTolerance = 0.8,

	-- Tolerancia anti-trampa: distancia máxima entre la cabeza y el origen del rayo
	-- (la cámara en tercera persona queda detrás del jugador)
	MaxShotOriginDistance = 20,

	Camera = {
		ThirdPersonDistance = 8,
		ShoulderOffset = Vector3.new(3.5, 1.5, 0), -- cámara sobre el hombro derecho: el personaje queda a la izquierda
		NormalFov = 70,
		AimFov = 35, -- zoom al mantener clic derecho
		AimSpeed = 14, -- qué tan rápido entra/sale el zoom
		AimSensitivity = 0.5, -- multiplicador de sensibilidad del mouse al apuntar
	},

	Player = {
		WalkSpeed = 16,
		SprintSpeed = 24, -- mantener Shift (no al apuntar, disparar o recargar)
		DownedWalkSpeed = 4,
		CarrySpeed = 9,
		BleedTime = 30, -- segundos caído antes de morir
		ReviveHealth = 30,
		SpawnStreamWait = 0.4, -- margen extra quieto al aparecer, cuando el cliente ya confirmó que tiene suelo
		SpawnGroundTimeout = 12, -- máximo de segundos quieto esperando esa confirmación (si no llega, se suelta igual y manda el rescate)
		SelfReviveTime = 3, -- segundos manteniendo H para levantarse solo (1 jugador)
		SelfRevivesPerZone = 1,
	},

	Revive = {
		HoldTime = 4, -- segundos manteniendo E
		CarryHoldTime = 1,
		PromptDistance = 7,
		MaxDistance = 12, -- validación en el servidor (un poco más holgada que el prompt)
		ReplyDelay = 1.5, -- el caído responde esto después de la frase de quien revive
		BubbleTime = 2.5,
		-- Frases provisionales: la lista final sigue abierta en el GDD
		ReviverPhrases = {
			"¡Arriba, que todavía no es tu hora!",
			"¿Otra vez en el piso?",
			"Me debes una",
		},
		DownedPhrases = {
			"Ya me andaba",
			"Tardaste muchísimo",
		},
	},

	-- Prueba de acción al revivir (server/SkillCheck + client/SkillCheck): mientras se mantiene E sale un aro con una zona
	-- buena y una aguja que lo recorre; hay que pulsar Espacio (o tocar el aro) cuando la aguja pasa por la zona.
	-- Si se falla, el revivir se reinicia. Es fácil a propósito: zona grande y aguja lenta.
	SkillCheck = {
		Enabled = true,
		Times = { 0.1, 0.5 }, -- en qué parte de Revive.HoldTime sale cada prueba (una por valor). Cada una dura como mucho Delay + Period + Tolerance + 0.3; la última debe acabar antes de HoldTime
		Period = 1.1, -- segundos que tarda la aguja en dar la vuelta completa
		ZoneSize = 100, -- grados de la zona buena (de 360): unos 0.3 s de ventana
		ZoneMin = 90, -- la zona empieza al azar entre estos dos ángulos (grados desde arriba, hacia la derecha); ZoneMax + ZoneSize <= 360
		ZoneMax = 260,
		Tolerance = 0.12, -- segundos de margen por latencia
		Delay = 0.3, -- la aguja arranca esto después de aparecer el aro
		RetryDelay = 0.8, -- tras fallar, segundos antes de poder volver a intentar
		FailPhrases = { "¡Se me resbaló!", "Otra vez, aguanta", "Casi..." },
	},

	Zombie = {
		ThinkInterval = 0.2, -- cada cuánto decide (ataque, objetivo)
		RepathInterval = 0.5, -- cada cuánto recalcula la ruta
		CorpseTime = 3.6, -- segundos que el cadáver queda antes de borrarse (caída, espasmo y desvanecimiento; ver ZombieAnimator)
		DeathFade = 0.9, -- los últimos segundos del cadáver se desvanece y se hunde
		-- Trepar a los autobuses: si un jugador está sobre el techo de un autobús, los zombies cercanos suben por el costado con
		-- una animación (server/Zombies.climbBus, client/ZombieAnimator). El Tanque no sube.
		Climb = {
			MinTime = 4, -- segundos que tarda en subir (al azar entre MinTime y MaxTime)
			MaxTime = 5,
			Range = 14, -- a qué distancia del autobús empiezan a trepar
			Kinds = { Common = true, Fast = true },
		},

		-- Modelos: el común = zombie-el-brotado.glb, el rápido = zombie-el-desbocado.glb (ver tools/glb_to_lua.py).
		-- ModelDetail: "full" = todas las piezas; "light" quita dientes, dedos, vértebras y otros detalles pequeños.
		Common = {
			DisplayName = "Zombie",
			Health = 50,
			Speed = 10,
			Damage = 10,
			AttackRange = 4,
			AttackCooldown = 1,
			ModelDetail = "full",
		},

		Fast = {
			DisplayName = "Zombie rápido",
			Health = 30,
			Speed = 20,
			Damage = 10,
			AttackRange = 4,
			AttackCooldown = 1,
			ModelDetail = "light", -- hay muchos y corren: menos piezas por zombie
		},

		-- El Tanque (zombie-el-tanque.glb): grande, lento y muy resistente. Aparece en la horda del generador y en la extracción.
		Tank = {
			DisplayName = "Tanque",
			Health = 600,
			Speed = 7,
			Damage = 35,
			AttackRange = 6,
			AttackCooldown = 1.6,
			AgentRadius = 2.2, -- grosor para calcular rutas (los demás usan 1.5)
			ModelDetail = "full",
		},
	},

	Director = {
		SpawnInterval = 1, -- segundos entre apariciones mientras haya cupo
		HordeSpawnDelay = 0.15, -- pausa entre zombies de una horda
		FastChance = 0.2,
		MinSpawnDistance = 50, -- nunca aparecen más cerca de un jugador
		FarSpawnDistance = 120, -- más lejos que esto cuenta como fuera de vista
		-- Extracción (después de llamar a la radio): zombies que llegan poco a poco y con menos a la vez
		ExtractionInterval = 2.5, -- segundos entre apariciones
		ExtractionCapFactor = 0.6, -- fracción del máximo de vivos normal (con 1 jugador: 6 de 10)
		MaxFailedSpawns = 4, -- si no hay punto oculto tantas veces seguidas, se relaja la regla de vista
		-- Tanque: uno al empezar la horda del generador y uno cada cierto tiempo durante la extracción
		Tank = {
			InHorde = true,
			ExtractionFirst = 20, -- segundos después de llamar a la radio
			ExtractionInterval = 45, -- segundos entre tanques (solo aparece otro si el anterior ya murió)
		},
		-- Ajuste por número de jugadores (MaxTanks = tanques vivos a la vez)
		ByPlayers = {
			[1] = { MaxAlive = 10, HordeScale = 0.25, MaxTanks = 1 },
			[2] = { MaxAlive = 18, HordeScale = 0.6, MaxTanks = 1 },
			[3] = { MaxAlive = 22, HordeScale = 0.8, MaxTanks = 2 },
			[4] = { MaxAlive = 25, HordeScale = 1.0, MaxTanks = 2 },
		},
	},

	-- Ambiente de terror (los dos mapas): noche con luna y niebla, linterna en cada jugador, faroles que parpadean,
	-- apagones con chispazo en las emboscadas y la horda del generador, sonidos de fondo, ruidos sueltos y latido.
	-- Enabled = false deja el juego de día, como antes.
	Atmosphere = {
		Enabled = true,
		Lighting = {
			ClockTime = 0.3, -- medianoche
			Brightness = 2.5, -- luz de la luna
			Ambient = Color3.fromRGB(32, 35, 48), -- interiores
			OutdoorAmbient = Color3.fromRGB(78, 88, 122), -- exteriores (azulado); más bajo = más oscuro
			ExposureCompensation = 0.3,
		},
		Fog = { -- Lighting.Atmosphere
			Density = 0.36,
			Haze = 2,
			Glare = 0,
			Color = Color3.fromRGB(70, 80, 110),
			Decay = Color3.fromRGB(25, 28, 40),
		},
		ColorGrade = { Brightness = -0.02, Contrast = 0.15, Saturation = -0.15, Tint = Color3.fromRGB(210, 220, 255) },
		Flashlight = { Brightness = 3, Range = 50, Angle = 45, Color = Color3.fromRGB(255, 240, 215), Shadows = true },
		Lamps = {
			Color = Color3.fromRGB(255, 165, 85),
			Brightness = 5,
			Range = 40,
			FlickerChance = 0.25, -- fracción de faroles que parpadean
			BrokenChance = 0.1, -- fracción de faroles apagados
		},
		Blackout = { Radius = 70, Duration = 7 }, -- faroles que se apagan alrededor de una emboscada u horda
		Volume = { Wind = 0.35, Sirens = 0.08, Drone = 0.18, Noise = 0.7, Dogs = 0.25, Spark = 0.8, Heartbeat = 0.7 },
		Noises = { MinInterval = 7, MaxInterval = 16, MinDistance = 18, MaxDistance = 40 }, -- ruidos sueltos cerca
		Heartbeat = { ZombieDistance = 22, LowHealth = 40 }, -- empieza a sonar con un zombie a menos de esto o con poca vida
	},

	-- Mapa nuevo: emboscadas de las plazoletas del callejón (server/Ambushes). La primera vez que alguien entra a una
	-- plazoleta salen unos pocos zombies de los callejones laterales.
	Ambush = {
		Size = 8, -- zombies al 100% (4 jugadores); se escala con Director.ByPlayers.HordeScale (con 1 jugador: 2)
		FieldSize = 12, -- emboscada grande de la cancha (ruta Escalera); con 1 jugador: 3
		TerminalSize = 14, -- emboscada de la terminal (más un Tanque); con 1 jugador: 4
		MinDistance = 22, -- nunca aparecen más cerca que esto de un jugador
	},

	-- Botiquín (server/Medkits + client/MedkitHud): se recoge con E (uno como máximo) y se usa con la tecla Key,
	-- en el compañero herido al que se mira (a menos de Range) o en uno mismo. Cura Heal de vida en Time segundos.
	Medkit = {
		Heal = 80,
		Time = 5,
		Range = 7,
		Key = Enum.KeyCode.Four,
		KeyLabel = "4", -- lo que se muestra en pantalla
	},

	-- Inventario (server/Items, client/Inventory, client/Shop): barra de ranuras 1 a 7. Las armas ocupan 1 y 2; los objetos van
	-- en el orden de Order (teclas 3 a 7). Se compran en las estaciones de munición con las latas del equipo y se pierden al morir.
	Items = {
		Order = { "Grenade", "Medkit", "Molotov", "Bandage", "Flare" },
		Cooldown = 0.8, -- segundos entre usos
		-- Se saca el objeto con su tecla (3 a 7; otra vez la misma, o 1 / 2 / Q, lo guarda). Con la granada, el molotov y la bengala se
		-- mantiene el clic para cargar la fuerza (el arco se ve en pantalla) y al soltarlo se lanza; con el clic derecho se cancela.
		-- Las vendas y el botiquín se usan con un clic. La fuerza va de 0 a 1 en Charge.Time segundos: la velocidad del lanzamiento
		-- pasa de ThrowMin (sin cargar) a ThrowSpeed (carga completa) y `Loft` es lo que se le suma hacia arriba.
		Charge = { Time = 1.1 },
		Loft = 14,
		-- Anim = { Release, End }: segundos del gesto al usar el objeto (client/ItemPoses). En Release sale de la mano (se lanza o se
		-- cura) y en End termina el gesto. Si se cambian, ajustar también las fracciones de ItemPoses (Release / End).
		Grenade = { Name = "Granada", Key = Enum.KeyCode.Three, KeyLabel = "3", Max = 3, Cost = 100, Throwable = true, Anim = { Release = 0.2, End = 0.55 }, Damage = 130, Radius = 14, Fuse = 2, ThrowMin = 26, ThrowSpeed = 100, Color = Color3.fromRGB(86, 104, 52) },
		Medkit = { Name = "Botiquín", Key = Enum.KeyCode.Four, KeyLabel = "4", Max = 2, Cost = 200 }, -- se usa con server/Medkits (Config.Medkit); el gesto dura Config.Medkit.Time
		Molotov = { Name = "Molotov", Key = Enum.KeyCode.Five, KeyLabel = "5", Max = 2, Cost = 125, Throwable = true, Anim = { Release = 0.25, End = 0.65 }, Radius = 8, Duration = 6, TickDamage = 14, Tick = 0.5, ThrowMin = 24, ThrowSpeed = 90, Color = Color3.fromRGB(150, 96, 40) },
		Bandage = { Name = "Vendas", Key = Enum.KeyCode.Six, KeyLabel = "6", Max = 3, Cost = 60, Heal = 25, Time = 1.2, Anim = { Release = 1.3, End = 1.6 } },
		Flare = { Name = "Bengala", Key = Enum.KeyCode.Seven, KeyLabel = "7", Max = 2, Cost = 75, Throwable = true, Anim = { Release = 0.12, End = 0.6 }, Duration = 15, LureRange = 75, ThrowMin = 30, ThrowSpeed = 105, Color = Color3.fromRGB(235, 70, 55) },
	},

	-- Garrafas de gas (server/GasCans, mapa nuevo): el generador de la plaza no arranca hasta que le lleven Count garrafas
	-- desde el mercado. Se cargan como a un compañero (lento y solo pistola) y se sueltan con G.
	Gas = {
		Count = 3,
		HoldTime = 0.8, -- segundos manteniendo E para cargarla
		DeliverRadius = 9, -- a esta distancia del generador se entrega sola
		DeliveryHorde = 6, -- zombies que llegan con cada entrega (al 100%; con 1 jugador: 2)
		DeliverPoints = 50, -- latas para quien la entrega
		MinSeparation = 25, -- distancia mínima entre las garrafas al repartirlas
	},

	-- Mapa nuevo: montones de latas sueltas (server/CanPiles). Se recogen con E, una vez por partida.
	CanPiles = {
		Amount = 50,
		BigAmount = 75, -- montones de la ruta Escalera (la más expuesta)
		HoldTime = 0.5,
	},

	-- Mapas que se pueden votar al inicio de cada ronda (server/VoteRoom). id = clave que usa GameState para elegir el constructor.
	Maps = {
		{ id = "Prueba", name = "Prueba", desc = "El mapa de siempre: una calle larga, un generador y la extracción.", color = Color3.fromRGB(95, 100, 110) },
		{ id = "Morro", name = "Morro Esperanza", desc = "El barrio de Rhomulus: 3 rutas, 3 tramos, iglesia, estadio y furgoneta.", color = Color3.fromRGB(190, 70, 50) },
	},
	Vote = {
		Time = 20, -- segundos máximos de votación
		AfterAllVoted = 1.5, -- si todos ya votaron, se espera esto antes de cerrar
		NoVotes = "Morro", -- mapa que gana si nadie vota
	},

	Game = {
		Seed = 7, -- semilla del mapa generado
		SafeRoomTime = 10, -- segundos de descanso en el punto seguro
		GeneratorHoldTime = 4,
		HordeWarning = 4, -- segundos de sirena antes de que llegue la horda
		GeneratorHorde = 40, -- tamaño de la horda al 100% (4 jugadores)
		RadioHoldTime = 3,
		ExtractionTime = 150, -- segundos hasta que llega la van
		VanScale = 1.3, -- tamaño de la furgoneta respecto al modelo original (para que cuadre con los avatares)
		VanArriveTime = 7, -- segundos que tarda la furgoneta en entrar por la calle y frenar
		VanGrace = 15, -- margen para que suban los demás tras el primero (la furgoneta sale al subir todos o al acabarse)
		ResultTime = 15,
	},

	-- Subir a la furgoneta (server/Boarding, client/BoardingAnimator): se mantiene E en la puerta lateral y el sobreviviente (con el
	-- compañero caído que cargue) sube con su animación y se sienta. Al terminar el margen la furgoneta arranca y se va (client/VanAnimator).
	Boarding = {
		HoldTime = 1.0, -- segundos manteniendo E en la puerta
		PromptDistance = 12,
		MaxDistance = 18, -- el servidor rechaza subir desde más lejos que esto
		Duration = 3.0, -- segundos del gesto de subir hasta que se sienta
		DepartDelay = 1.2, -- segundos entre cerrar las puertas y arrancar
		ResultAfter = 6.5, -- segundos desde que arranca hasta que sale la pantalla de victoria
	},

	Dummy = {
		Health = 100,
		RespawnTime = 3,
		Positions = {
			Vector3.new(-8, 0, -243),
			Vector3.new(0, 0, -243),
			Vector3.new(8, 0, -243),
		},
		PositionsNewMap = { -- lobby de Morro Esperanza (la cochera)
			Vector3.new(-8, 0, -388),
			Vector3.new(0, 0, -388),
			Vector3.new(8, 0, -388),
		},
	},
}
