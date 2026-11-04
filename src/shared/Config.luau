-- Valores de balance. Todo número ajustable vive aquí.
return {
	Weapons = {
		Pistol = {
			Name = "Pistol",
			AmmoStyle = "Ring", -- anillo de balas
			Damage = 20,
			Pellets = 1,
			Spread = 0, -- grados de dispersión
			-- Bloom: al disparar seguido la dispersión crece PerShot grados por tiro (hasta Max) y se recupera Recover grados por segundo
			-- sin disparar (server/Weapons; la mira lo muestra como un aro, client/Hud). Sustituye al retroceso de cámara.
			Bloom = { PerShot = 1, Max = 3, Recover = 3 },
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
			Bloom = { PerShot = 0.35, Max = 3.5, Recover = 5 },
			MagSize = 30,
			FireCooldown = 0.1,
			ReloadTime = 2,
			Range = 400,
			Auto = true,
			ReserveStart = 90,
			MaxReserve = 150,
			Rarity = "Common",
			Weight = 40, -- probabilidad relativa en la caja
		},
		Shotgun = {
			Name = "Shotgun",
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
			Rarity = "Common",
			Weight = 35,
		},
		SMG = {
			Name = "SMG",
			AmmoStyle = "Magazine", -- cargador transparente
			Damage = 14,
			Pellets = 1,
			Spread = 2.5,
			Bloom = { PerShot = 0.3, Max = 4, Recover = 6 },
			MagSize = 40,
			FireCooldown = 0.07,
			ReloadTime = 1.8,
			Range = 250,
			Auto = true,
			ReserveStart = 120,
			MaxReserve = 200,
			Rarity = "Rare",
			Weight = 25,
		},
	},

	-- Armas en la mano (ver server/WeaponRig y client/WeaponAnimator).
	-- Los puntos Grip/Fore/Mag/Muzzle están en coordenadas del modelo (ZombieData): cañón hacia -X, arriba +Y.
	--   Grip = donde la mano derecha agarra · Fore = donde se apoya la izquierda · Mag = cargador (o puerto de la escopeta)
	-- HighGrip/LowGrip: posición de la mano derecha respecto al pecho (X derecha, Y arriba, -Z adelante), con el arma
	-- arriba (apuntando) o abajo (en reposo). Kick = studs que patea hacia atrás, Rise = cuánto sube el cañón (rad),
	-- Camera = sacudida de cámara por disparo (grados): se mantiene baja para que la mira no se vaya hacia arriba; la imprecisión
	-- al disparar seguido es el Bloom de Config.Weapons.
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
			Camera = 0.4,
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
			Camera = 0.2,
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
			Camera = 2.2,
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
			Camera = 0.15,
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
		-- Sonidos de juego del cliente (client/Sfx): combate, equipo, mundo e interfaz. Cada uno es { id, volumen, tono } o una lista de
		-- esos (suena uno al azar); con `clip` solo suenan esos segundos. Los que llevan 3D salen desde donde pasa. Los ids vienen del
		-- Creator Store (Pro Sound Effects, Daily Sounds y otros gratuitos): se probó que cargan, pero no se ha oído cómo suenan en la
		-- partida, así que si alguno no convence se cambia el id aquí.
		Fx = {
			-- Interfaz y menú
			Click = { "rbxassetid://110948579458469", 0.5, 1 },
			Hover = { "rbxassetid://106984966606682", 0.25, 1.6 },
			Select = { "rbxassetid://9118138365", 0.45, 1.2 }, -- votar dificultad, cambiar ajuste
			Confirm = { "rbxassetid://99980076888596", 0.5, 1 }, -- LISTO, entrar a una sala
			-- Latas y tienda (suben o bajan las latas del equipo)
			Coin = { "rbxassetid://130378474223829", 0.45, 1 },
			Buy = { "rbxassetid://138309872562566", 0.5, 0.85 },
			-- Combate
			ZombieHit = { "rbxassetid://75492070005287", 0.5, 1 }, -- 3D, al herir a un zombie
			ZombieDeath = { "rbxassetid://138338177111300", 0.6, 0.85 }, -- 3D
			TankRoar = { "rbxassetid://9113980319", 0.9, 0.55 }, -- 3D, al aparecer un Tanque
			TankDeath = { "rbxassetid://94978851787238", 1, 1 }, -- 3D, al caer un Tanque
			TankSlam = { "rbxassetid://126212934401370", 1, 0.55 }, -- 3D, el Tanque golpea el suelo (explosión grave; sin oír todavía)
			AlertTank = { "rbxassetid://9113980319", 0.6, 0.8 }, -- 2D, aviso de que salió un Tanque
			AlertGrabber = { "rbxassetid://9113980319", 0.45, 1.9 }, -- 2D, aviso de que salió un Atrapador
			-- Atrapador (ids reutilizados con otro tono: sin oír todavía)
			GrabberAim = { "rbxassetid://9113980319", 0.5, 1.9 }, -- 3D, empieza a apuntar
			TongueShot = { "rbxassetid://75492070005287", 0.8, 1.6 }, -- 3D, sale la lengua
			TongueHit = { "rbxassetid://138338177111300", 0.9, 1.3 }, -- 3D / 2D, agarra
			TongueSnap = { "rbxassetid://75492070005287", 0.8, 0.7 }, -- 3D, la lengua se recoge tras soltar
			Struggle = { "rbxassetid://75492070005287", 0.35, 1.8 }, -- 2D, cada pulsación al forcejear
			Hurt = { -- el jugador recibe un golpe
				{ "rbxassetid://9120417632", 0.7, 1 },
				{ "rbxassetid://9120417141", 0.7, 1 },
				{ "rbxassetid://9120417581", 0.7, 1 },
				{ "rbxassetid://9120417872", 0.7, 1 },
			},
			-- Equipo
			Down = { "rbxassetid://96795857757261", 0.7, 0.8 }, -- el jugador cae
			Revived = { "rbxassetid://129388074782199", 0.7, 1 }, -- el jugador se levanta
			SkillOk = { "rbxassetid://138309872562566", 0.45, 1.5 }, -- prueba de acción acertada
			SkillFail = { "rbxassetid://9120094547", 0.6, 0.7 }, -- prueba de acción fallada
			Carry = { "rbxassetid://9113836270", 0.6, 0.8 }, -- se carga al compañero (o una garrafa)
			Drop = { "rbxassetid://75492070005287", 0.6, 0.7 }, -- se suelta
			-- Mundo
			Generator = { "rbxassetid://9125345489", 0.45, 0.75 }, -- el generador arranca
			Radio = { "rbxassetid://9113405790", 0.5, 1, clip = 2.4 }, -- se llama a la radio (solo el principio: estática y pitidos)
			Countdown = { "rbxassetid://136924498052589", 0.6, 1 }, -- últimos segundos antes de que llegue la furgoneta
			-- Final de la partida (suenan juntos)
			Victory = {
				{ "rbxassetid://71587723216424", 0.8, 1 },
				{ "rbxassetid://129388074782199", 0.6, 1 },
			},
			Defeat = {
				{ "rbxassetid://96795857757261", 0.8, 0.6 },
				{ "rbxassetid://130018094603454", 0.5, 0.8 },
			},
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

	-- Farmacia de Doña Rosa (server/Pharmacy): una vitrina por tramo donde, por latas, una ruleta de jeringas sortea un efecto temporal
	-- (como la caja de armas). Quien se inyecta recibe el efecto un rato y luego un "bajón" más corto. Solo hay un efecto activo a la vez
	-- (la nueva jeringa reemplaza a la anterior) y se pierde al caer o morir.
	Pharmacy = {
		Cost = 250, -- latas por probar suerte (la dificultad lo multiplica)
		SpinTime = 3.2, -- segundos girando la ruleta
		TakeTime = 8, -- segundos para tomar la Phial antes de que se pierda
		Cooldown = 3, -- pausa tras tomar o perder una Phial
		-- Animación de inyectarse (fracciones de Duration; deben coincidir con las claves de client/ItemPoses.Syringe)
		Anim = { Duration = 2.8, Prick = 0.44, PushStart = 0.50, PushEnd = 0.78, Apply = 0.80 },
		Duration = 75, -- segundos de efecto
		CrashDuration = 10, -- segundos de bajón
		-- Lugares de las vitrinas: { posición del suelo, giro en grados (el frente del modelo mira a -Z) }
		Spots = {
			{ Vector3.new(-20.5, 0, -94.6), 0 }, -- la tienda: contra la pared norte, a la izquierda de la salida
			{ Vector3.new(25.5, 0, 177), 90 }, -- la iglesia: contra la pared este, mirando a la nave
			{ Vector3.new(-55.5, 0, 283), -90 }, -- la terminal: contra la pared oeste (la estación de munición está más al sur)
		},
		-- Efectos. Mods: Damage, Speed y Reload multiplican; MaxHealth suma vida máxima (y cura lo mismo al inyectarse).
		-- Crash: lo que queda al acabar el efecto, durante CrashDuration.
		-- Mods extra: Defense (multiplica el daño recibido), Stealth (alcance en studs a partir del cual los zombies no te notan),
		-- Regen (vida por segundo; negativa = sangrado) y Vision (los zombies se ven a través de las paredes).
		-- Weight: probabilidad en el sorteo (suman 100, así se muestran en el panel). Category y Rarity salen en las cartas del panel PHIAL ROLL.
		-- MaxUses: Phials por vitrina y ronda.
		MaxUses = 2,
		Rarities = {
			Common = { Text = "COMMON", Color = Color3.fromRGB(176, 176, 182) },
			Rare = { Text = "RARE", Color = Color3.fromRGB(78, 160, 255) },
			Epic = { Text = "EPIC", Color = Color3.fromRGB(190, 108, 255) },
			Cursed = { Text = "CURSED", Color = Color3.fromRGB(150, 205, 60) },
		},
		-- Textos del panel PHIAL ROLL
		Ui = { Title = "PHIAL ROLL", Subtitle = "FARMÁCIA POPULAR · MORRO ESPERANZA" },
		Order = { "Furia", "Impulso", "Adrenalina", "Pulso", "PielDura", "Regeneracion", "Vision", "Sigilo", "SueroMalo" },
		Effects = {
			Furia = {
				Name = "Fury", Category = "DAMAGE", Rarity = "Epic", Weight = 7, Upper = "FURY", Color = Color3.fromRGB(220, 50, 55), Desc = "+30% damage",
				Mods = { Damage = 1.3 }, Crash = { Damage = 0.75 }, CrashDesc = "-25% damage",
			},
			Impulso = {
				Name = "Rush", Category = "SPEED", Rarity = "Common", Weight = 16, Upper = "RUSH", Color = Color3.fromRGB(80, 220, 110), Desc = "+25% speed",
				Mods = { Speed = 1.25 }, Crash = { Speed = 0.75 }, CrashDesc = "-25% speed",
			},
			Adrenalina = {
				Name = "Adrenaline", Category = "HEALTH", Rarity = "Common", Weight = 16, Upper = "ADRENALINE", Color = Color3.fromRGB(245, 170, 50), Desc = "+40 max health",
				Mods = { MaxHealth = 40 }, Crash = { Speed = 0.85 }, CrashDesc = "-15% speed",
			},
			Pulso = {
				Name = "Pulse", Category = "RELOADING", Rarity = "Rare", Weight = 12, Upper = "PULSE", Color = Color3.fromRGB(70, 150, 255), Desc = "Reloads twice as fast",
				Mods = { Reload = 0.5 }, Crash = { Reload = 1.6 }, CrashDesc = "slower reload",
			},
			PielDura = {
				Name = "Thick Skin", Category = "ARMOR", Rarity = "Rare", Weight = 12, Upper = "THICK SKIN", Color = Color3.fromRGB(190, 150, 110), Desc = "-30% damage taken",
				Mods = { Defense = 0.7 }, Crash = { Defense = 1.2 }, CrashDesc = "+20% damage taken",
			},
			Regeneracion = {
				Name = "Regeneration", Category = "HEALING", Rarity = "Common", Weight = 18, Upper = "REGENERATION", Color = Color3.fromRGB(120, 230, 170), Desc = "you recover 2 health per second",
				Mods = { Regen = 2 }, Crash = { Regen = -1 }, CrashDesc = "you lose 1 health per second",
			},
			Vision = {
				Name = "Vision", Category = "SIGHT", Rarity = "Epic", Weight = 6, Upper = "VISION", Color = Color3.fromRGB(190, 120, 255), Desc = "you see zombies through walls",
				Mods = { Vision = true }, Crash = { Reload = 1.3 }, CrashDesc = "shaky hands: slower reload",
			},
			Sigilo = {
				Name = "Stealth", Category = "STEALTH", Rarity = "Rare", Weight = 8, Upper = "STEALTH", Color = Color3.fromRGB(110, 120, 140), Desc = "zombies farther than 20 studs don't notice you",
				Mods = { Stealth = 20 }, Crash = { Speed = 0.9 }, CrashDesc = "-10% speed",
			},
			SueroMalo = {
				Name = "Bad Serum", Category = "RISK", Rarity = "Cursed", Weight = 5, Upper = "BAD SERUM", Color = Color3.fromRGB(150, 200, 60), Desc = "+60% damage, but -30 max health",
				Mods = { Damage = 1.6, MaxHealth = -30 }, Crash = { Damage = 0.85 }, CrashDesc = "-15% damage",
			},
		},
	},

	-- Latas del equipo (la moneda compartida; el módulo se llama Points)
	Points = {
		Kill = { Common = 25, Fast = 40, Tank = 150, Grabber = 100 },
		Revive = 50,
		Carry = 20,
		ZoneComplete = 100,
	},

	-- Tiro a la cabeza: cuenta si el rayo pasa a menos de (tamaño del cráneo * RadiusScale) del centro de la cabeza.
	-- Depth = cuánto más allá del impacto en la caja del zombie se sigue buscando la cabeza.
	-- Ojo: el servidor no ve las animaciones de los zombies (se animan en el cliente): la cabeza se toma en su pose base.
	-- Mutadores con efecto propio (shared/Mutators): ruido de disparos (alcance en studs, segundos que dura, pausa entre ruidos por
	-- jugador) y sangrado (vida por debajo de la cual sangra, vida por segundo)
	MutatorRules = { Noise = { Range = 70, Duration = 5, Cooldown = 0.6 }, Bleed = { Below = 40, PerSecond = 1 } },

	Headshot = { Multiplier = 2, RadiusScale = 0.4, Depth = 1.5, PartNames = { "Head", "saco_cabeza" } }, -- saco_cabeza = cabeza del maniquí

	-- Guía de objetivo (client/ObjectiveGuide): columna de luz en el mundo, flecha en el borde de la pantalla y distancia.
	-- El servidor publica la posición del objetivo de cada orden (GameState.OBJECTIVES).
	Guide = {
		Enabled = true,
		Color = Color3.fromRGB(255, 205, 60),
		ShopColor = Color3.fromRGB(70, 215, 225), -- la guía de la TIENDA va de otro color que la del objetivo
		ShowBeam = false, -- columna de luz en el mundo (apagada: basta con el cartel de nombre y distancia)
		BeaconHeight = 140, -- altura de la columna de luz (studs)
		BeaconWidth = 4,
		EdgeMargin = 70, -- px que separan la flecha del borde de la pantalla
		ArrowSize = 64,
		StudsPerMeter = 3.571, -- para mostrar la distancia en metros (un avatar de 5 studs ~ 1.75 m)
	},

	-- Golpe cuerpo a cuerpo (tecla X, server/Melee): igual para TODAS las skins de Cosmetics.MeleeSkins, que solo cambian aspecto,
	-- sonido y gesto. Se golpea a lo que haya delante dentro del cono, sin atravesar paredes.
	Melee = {
		Damage = 35, -- por zombie (el común tiene 50: dos golpes)
		Cooldown = 0.6, -- segundos entre golpes
		Duration = 0.5, -- lo que dura el gesto (la pose de brazos y el arma en la mano)
		HitAt = 0.45, -- fracción del gesto en que cae el golpe (coincide con la clave de golpe de client/ItemPoses.Melee*)
		Range = 6.5, -- studs desde el pecho
		Arc = 100, -- grados del cono
		MaxTargets = 2, -- zombies que alcanza un solo golpe
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

	-- Calidad gráfica del cliente (client/Performance). Cada nivel solo toca cosas del cliente que cuestan en celular; el servidor y
	-- los demás jugadores no lo notan. En AUTO el celular arranca en TouchDefault y baja un nivel si los FPS se quedan por debajo
	-- de FpsBelow durante Seconds (nunca sube solo). El jugador puede fijar el nivel en AJUSTES.
	Performance = {
		Levels = {
			{ Name = "HIGH", LampDistance = 110, FlashlightShadows = true, GlobalShadows = true },
			{ Name = "MEDIUM", LampDistance = 70, FlashlightShadows = false, GlobalShadows = true },
			{ Name = "LOW", LampDistance = 40, FlashlightShadows = false, GlobalShadows = false },
		},
		PcDefault = 1,
		TouchDefault = 2,
		AutoDegrade = { FpsBelow = 24, Seconds = 6, Cooldown = 15 },
	},

	-- Celular (client/TouchControls). La sensibilidad del jugador (client/Controls, ajustable en AJUSTES) multiplica el giro de la
	-- cámara tanto al arrastrar el dedo como con el ratón.
	Touch = {
		LookDegPerPixel = 0.3, -- grados que gira la cámara por píxel arrastrado, con sensibilidad 1
		AimLookFactor = 0.55, -- al apuntar el giro se frena (como AimSensitivity del ratón)
		MaxPitch = 80, -- grados máximos hacia arriba y hacia abajo
		SensitivityMin = 0.4,
		SensitivityMax = 2.5,
		SensitivityStep = 0.1,
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
		CarryOffset = CFrame.new(0.5, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), -- el caído acostado sobre los hombros de quien lo carga (marco de quien carga)
		PromptDistance = 7,
		MaxDistance = 12, -- validación en el servidor (un poco más holgada que el prompt)
		ReplyDelay = 1.5, -- el caído responde esto después de la frase de quien revive
		BubbleTime = 2.5,
		-- Frases provisionales: la lista final sigue abierta en el GDD
		ReviverPhrases = {
			"Up you get, it's not your time yet!",
			"Back on the floor again?",
			"You owe me one, amigo",
		},
		DownedPhrases = {
			"About time, hermano",
			"Took you long enough, compa",
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
		FailPhrases = { "It slipped!", "Again, hold on", "Almost..." },
	},

	Zombie = {
		Explosive = { Chance = 0.3, Fuse = 0.9, Radius = 10, Damage = 20 }, -- mutador "Explosivos" (nunca el Tanque)
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
			DisplayName = "Fast Zombie",
			Health = 30,
			Speed = 20,
			Damage = 10,
			AttackRange = 4,
			AttackCooldown = 1,
			ModelDetail = "light", -- hay muchos y corren: menos piezas por zombie
		},

		-- El Tanque (zombie-el-tanque.glb): grande, lento y muy resistente. Aparece en la horda del generador y en la extracción.
		Tank = {
			DisplayName = "Tank",
			Health = 1500, -- la dificultad lo multiplica (Calma x0,8 ... Colapso x2)
			Speed = 7,
			Damage = 35,
			AttackRange = 6,
			AttackCooldown = 1.6,
			AgentRadius = 2.2, -- grosor para calcular rutas (los demás usan 1.5)
			ModelDetail = "full",
			-- Golpe al suelo (server/Zombies.slam, client/TankSlamFx): levanta los brazos (Windup, con un círculo rojo en el suelo),
			-- golpea y suelta una onda en área. Se esquiva alejándose del círculo o SALTANDO cuando llega la onda (Airborne).
			Slam = {
				FirstCooldown = 4, -- espera tras aparecer
				Cooldown = 11, -- espera entre golpes
				TriggerRange = 12, -- lo usa cuando hay alguien a esta distancia o menos
				Windup = 1.05, -- segundos con los brazos arriba antes de golpear
				Recover = 0.9, -- segundos quieto tras el golpe
				Radius = 13, -- radio de la onda
				DamageMult = 1.3, -- daño = su daño normal x esto (la dificultad ya lo multiplica)
				Airborne = 3.2, -- quien esté a más de esta altura del suelo cuando llega la onda no recibe daño
				Knock = 48, -- empujón horizontal que recibe quien lo sufre (cliente)
				Lift = 26, -- y hacia arriba
				Shake = 0.9, -- fuerza de la sacudida de cámara (0 a 1) cerca del golpe
			},
		},

		-- El Atrapador (zombie-el-atrapador.glb): frágil, se mantiene a media distancia y caza con la lengua (server/Grabber, Config.Grabber).
		-- WeakPoints: piezas que cuentan como crítico, además de la cabeza (los quistes brillantes y el ojo extra).
		Grabber = {
			DisplayName = "Grabber",
			Health = 150,
			Speed = 13,
			Damage = 12,
			AttackRange = 5,
			AttackCooldown = 1.2,
			AgentRadius = 1.8,
			ModelDetail = "full",
			WeakPoints = { "ojo_extra", "quiste_0", "quiste_1", "quiste_2", "quiste_3" },
		},
	},

	-- El Atrapador (server/Grabber, client/GrabberFx, client/Grabbed): apunta con un láser rojo (Aim), dispara la lengua (Speed) y, si
	-- acierta, arrastra a su víctima. La víctima puede disparar, moverse flojo (Resist) y forcejear (Struggle); la lengua se corta a tiros
	-- (TongueHealth). Los tiempos de espera se multiplican por Difficulties.GrabberEvery.
	Grabber = {
		Range = 44, -- alcance de la lengua (studs)
		MinRange = 14, -- más cerca que esto retrocede en vez de apuntar
		Aim = 0.85, -- segundos de aviso (láser rojo y cabeza hacia atrás) antes de disparar
		TongueSpeed = 75, -- studs por segundo de la lengua en el aire
		HitRadius = 3.6, -- cuánto se puede haber movido la víctima desde que se fijó el tiro para que aún acierte
		FirstCooldown = 3, -- espera tras aparecer
		Cooldown = 9, -- espera tras soltar a una víctima
		MissCooldown = 4, -- espera tras fallar
		PullSpeed = 24, -- velocidad a la que arrastra (studs/s)
		Resist = 0.45, -- fracción de su velocidad de caminar que la víctima puede usar para resistirse
		MaxPull = 6, -- si en tantos segundos no llega al zombie, la lengua se suelta
		HoldRange = 6, -- a esta distancia la víctima ya está en sus manos y deja de arrastrarse
		HoldDamage = 7, -- daño por mordida (se multiplica por la dificultad)
		HoldInterval = 0.8,
		MaxHold = 14, -- segundos máximos agarrado
		StruggleNeeded = 14, -- pulsaciones para soltarse
		StruggleDecay = 1.6, -- pulsaciones que se pierden por segundo
		StruggleMaxRate = 12, -- pulsaciones por segundo que el servidor acepta
		TongueHealth = 30, -- daño de bala para cortar la lengua
		StunCut = 2.4, -- segundos aturdido si le cortan la lengua
		StunBreak = 1.3, -- segundos aturdido si la víctima se suelta
		AmbushChance = 0.3, -- probabilidad de que una emboscada traiga un Atrapador
		Loose = { Chance = 0.04, Gap = 40, Zones = { Zone2 = true, Zone3 = true, Extraction = true } }, -- apariciones sueltas del director
		Extraction = { First = 40, Interval = 55 }, -- en la extracción: segundos tras llamar a la radio y entre atrapadores
	},

	Director = {
		SpawnInterval = 1, -- segundos entre apariciones mientras haya cupo
		HordeSpawnDelay = 0.15, -- pausa entre zombies de una horda
		FastChance = 0.2,
		MinSpawnDistance = 50, -- nunca aparecen más cerca de un jugador
		FarSpawnDistance = 120, -- más lejos que esto cuenta como fuera de vista
		-- Extracción (después de llamar a la radio): zombies que llegan poco a poco y con menos a la vez
		-- La presión sube mientras pasa la cuenta atrás (de 0 al inicio a 1 cuando llega la van) y se multiplica por la dificultad:
		--   tope de vivos = máximo normal x Cap (de CapStart a CapEnd), con el tope de Difficulties.MaxAliveCap
		--   pausa entre apariciones = Interval (de IntervalStart a IntervalEnd)
		--   oleadas: cada WaveEvery segundos sale una horda de WaveSize (al 100%: se escala con jugadores y dificultad);
		--   en los últimos FinalSeconds salen cada FinalEvery y son de FinalSize
		Extraction = {
			CapStart = 1.0,
			CapEnd = 1.6,
			MinAlive = 14, -- suelo del tope de vivos (con pocos jugadores el normal es muy bajo); también se multiplica por la presión
			MinHordeScale = 0.7, -- las oleadas nunca bajan de esta fracción de su tamaño, aunque juegue 1 solo
			IntervalStart = 2.0,
			IntervalEnd = 0.7,
			FirstWave = 10, -- segundos después de llamar a la radio
			WaveEvery = 16,
			WaveSize = 14,
			FinalSeconds = 70,
			FinalEvery = 9,
			FinalSize = 22,
		},
		FailedSpawnRetry = 0.4, -- si no hay punto libre, reintenta pronto en vez de esperar la pausa entera
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
		FogDense = { Density = 0.62, Haze = 3.2 }, -- mutador "Niebla densa"
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
		Grenade = { Name = "Grenade", Key = Enum.KeyCode.Three, KeyLabel = "3", Max = 3, Cost = 100, Throwable = true, Anim = { Release = 0.2, End = 0.55 }, Damage = 130, Radius = 14, Fuse = 2, ThrowMin = 26, ThrowSpeed = 100, Color = Color3.fromRGB(86, 104, 52) },
		Medkit = { Name = "Medkit", Key = Enum.KeyCode.Four, KeyLabel = "4", Max = 2, Cost = 200 }, -- se usa con server/Medkits (Config.Medkit); el gesto dura Config.Medkit.Time
		Molotov = { Name = "Molotov", Key = Enum.KeyCode.Five, KeyLabel = "5", Max = 2, Cost = 125, Throwable = true, Anim = { Release = 0.25, End = 0.65 }, Radius = 8, Duration = 6, TickDamage = 14, Tick = 0.5, ThrowMin = 24, ThrowSpeed = 90, Color = Color3.fromRGB(150, 96, 40) },
		Bandage = { Name = "Bandages", Key = Enum.KeyCode.Six, KeyLabel = "6", Max = 3, Cost = 60, Heal = 25, Time = 1.2, Anim = { Release = 1.3, End = 1.6 } },
		Flare = { Name = "Flare", Key = Enum.KeyCode.Seven, KeyLabel = "7", Max = 2, Cost = 75, Throwable = true, Anim = { Release = 0.12, End = 0.6 }, Duration = 15, LureRange = 75, ThrowMin = 30, ThrowSpeed = 105, Color = Color3.fromRGB(235, 70, 55) },
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
		{ id = "Morro", name = "Morro Esperanza", desc = "The Rhomulus barrio: 3 routes, 3 sections, iglesia, stadium and van.", color = Color3.fromRGB(190, 70, 50) },
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
		ResultTime = 15, -- segundos que se ve el resultado antes de empezar otra partida
		ResultMinTime = 3, -- aunque todos pidan "otra partida", se espera esto para poder leer las estadísticas
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
		Positions = { -- lobby de Morro Esperanza (la cochera)
			Vector3.new(-8, 0, -388),
			Vector3.new(0, 0, -388),
			Vector3.new(8, 0, -388),
		},
	},
}
