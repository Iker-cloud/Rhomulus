-- Valores de balance. Todo número ajustable vive aquí.
return {
	Weapons = {
		Pistol = {
			Name = "Pistola",
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

	WeaponBox = {
		Cost = 500,
		AmmoCost = 150,
		SpinTime = 3, -- segundos girando
		TakeTime = 8, -- segundos para tomar el arma antes de que se pierda
		Pool = { "Rifle", "Shotgun", "SMG" },
	},

	-- Puntos del equipo
	Points = {
		Kill = { Common = 25, Fast = 40 },
		Revive = 50,
		Carry = 20,
		ZoneComplete = 100,
	},

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
		DownedWalkSpeed = 4,
		CarrySpeed = 9,
		BleedTime = 30, -- segundos caído antes de morir
		ReviveHealth = 30,
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

		Common = {
			Health = 50,
			Speed = 10,
			Damage = 10,
			AttackRange = 4,
			AttackCooldown = 1,
			HipHeight = 2,
			Color = Color3.fromRGB(90, 130, 80),
		},

		Fast = {
			Health = 30,
			Speed = 20,
			Damage = 10,
			AttackRange = 4,
			AttackCooldown = 1,
			HipHeight = 2,
			Color = Color3.fromRGB(150, 70, 60),
		},
	},

	Director = {
		SpawnInterval = 1, -- segundos entre apariciones mientras haya cupo
		HordeSpawnDelay = 0.15, -- pausa entre zombies de una horda
		FastChance = 0.2,
		MinSpawnDistance = 50, -- nunca aparecen más cerca de un jugador
		FarSpawnDistance = 120, -- más lejos que esto cuenta como fuera de vista
		BoostInterval = 0.4, -- segundos entre apariciones en la extracción
		-- Ajuste por número de jugadores
		ByPlayers = {
			[1] = { MaxAlive = 10, HordeScale = 0.25 },
			[2] = { MaxAlive = 18, HordeScale = 0.6 },
			[3] = { MaxAlive = 22, HordeScale = 0.8 },
			[4] = { MaxAlive = 25, HordeScale = 1.0 },
		},
	},

	Game = {
		Seed = 7, -- semilla del mapa generado
		SafeRoomTime = 10, -- segundos de descanso en el punto seguro
		GeneratorHoldTime = 4,
		GeneratorHorde = 40, -- tamaño de la horda al 100% (4 jugadores)
		RadioHoldTime = 3,
		ExtractionTime = 150, -- segundos hasta que llega la van
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
	},
}
