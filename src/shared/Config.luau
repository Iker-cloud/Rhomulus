-- Valores de balance. Todo número ajustable vive aquí.
return {
	Weapons = {
		Pistol = {
			Damage = 20,
			MagSize = 12,
			FireCooldown = 0.25, -- segundos entre disparos
			ReloadTime = 1.5,
			Range = 300,
			InfiniteReserve = true,
		},
	},

	-- Tolerancia anti-trampa: distancia máxima entre la cabeza y el origen del rayo
	-- (la cámara en tercera persona queda detrás del jugador)
	MaxShotOriginDistance = 20,

	Camera = {
		ThirdPersonDistance = 12,
		ShoulderOffset = Vector3.new(2, 0.5, 0),
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
			[1] = { MaxAlive = 12, HordeScale = 0.4 },
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
