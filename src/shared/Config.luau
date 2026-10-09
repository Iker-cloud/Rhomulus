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
		Volume = { Headshot = 0.7, Shot = 0.6, Reload = 0.5, DryFire = 0.5, Zombie = 0.7, Siren = 0.7, Box = 0.6, VanHorn = 0.9 },
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
		Headshot = "rbxassetid://117629133235583", -- provisional: el clic de DryFire, agudo. Cambia el id por un "ding" cuando haya uno
		HeadshotPitch = 2,
		ZombieGrowls = {
			"rbxassetid://129294628821291",
			"rbxassetid://100949226522885",
			"rbxassetid://130156156621885",
		},
		HordeSiren = "rbxassetid://9119163479",
		VanHorn = "rbxassetid://93042705532380", -- pitido de la furgoneta al entrar (dura 1.5 s)
		BoxSpin = "rbxassetid://9046019442",
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

	Zombie = {
		ThinkInterval = 0.2, -- cada cuánto decide (ataque, objetivo)
		RepathInterval = 0.5, -- cada cuánto recalcula la ruta
		CorpseTime = 2, -- segundos que el cadáver queda antes de borrarse

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

	-- Mapa nuevo: montones de latas sueltas (server/CanPiles). Se recogen con E, una vez por partida.
	CanPiles = {
		Amount = 50,
		BigAmount = 75, -- montones de la ruta Escalera (la más expuesta)
		HoldTime = 0.5,
	},

	Game = {
		-- Mapa 1 nuevo, Morro Esperanza (server/MapBuilderBarrio). De momento solo llega hasta el punto seguro 1:
		-- al cruzar su puerta de salida se gana la prueba. false = el mapa de siempre (server/MapBuilder).
		UseNewMap = false,
		Seed = 7, -- semilla del mapa generado
		SafeRoomTime = 10, -- segundos de descanso en el punto seguro
		GeneratorHoldTime = 4,
		HordeWarning = 4, -- segundos de sirena antes de que llegue la horda
		GeneratorHorde = 40, -- tamaño de la horda al 100% (4 jugadores)
		RadioHoldTime = 3,
		ExtractionTime = 150, -- segundos hasta que llega la van
		VanScale = 1.3, -- tamaño de la furgoneta respecto al modelo original (para que cuadre con los avatares)
		VanArriveTime = 7, -- segundos que tarda la furgoneta en entrar por la calle y frenar
		VanGrace = 5, -- margen para que suban los demás tras el primero
		ResultTime = 15,
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
