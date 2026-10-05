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
		},
	},

	-- Temporal (fase 3): zona de prueba generada por código
	TestArena = {
		ZombieSpawn = Vector3.new(0, 0, 60),
		RespawnTime = 5,
		Walls = {
			{ Position = Vector3.new(0, 5, 35), Size = Vector3.new(30, 10, 2) },
			{ Position = Vector3.new(-20, 5, 15), Size = Vector3.new(2, 10, 30) },
		},
	},

	Dummy = {
		Health = 100,
		RespawnTime = 3,
		Positions = {
			Vector3.new(0, 0, -25),
			Vector3.new(12, 0, -45),
			Vector3.new(-12, 0, -65),
		},
	},
}
