-- Dificultades de la partida (de la más fácil a la más difícil): Calma, Tensión, Crisis y Colapso.
-- La comparten la partida y el menú (sin dependencias, para poder usarse en los dos lugares).
-- TENSIÓN es el balance base de Config: todos sus multiplicadores valen 1. Las demás escalan a partir de ahí.
--
-- Campos de cada dificultad:
--   Name / Upper / Description / Color  lo que ve el jugador (menú, votación, etiqueta); Upper = el nombre en mayúsculas (con acento)
--   Health, Speed, Damage          multiplican la vida, la velocidad y el daño de TODOS los zombies (también el Tanque)
--   MaxAlive, Horde                multiplican el máximo de zombies vivos y el tamaño de hordas y emboscadas
--   FastChance                     probabilidad de que un zombie común sea rápido (en vez de 0.2 fijo)
--   ExtraTanks                     Tanques vivos a la vez de más (se suman al máximo según el número de jugadores)
--   TankEvery                      multiplica el tiempo entre Tanques de la extracción (menos = más seguidos)
--   SpawnInterval                  multiplica la pausa entre apariciones (menos = llegan más rápido)
--   Cost                           multiplica los precios (caja, munición y objetos)
--   Reward                         multiplica las latas que se ganan
--   MedkitHeal                     multiplica lo que curan botiquines y vendas
--   BleedTime                      multiplica los segundos que se aguanta caído antes de morir
--   SelfRevives                    veces por zona que se puede levantar solo quien juega con 1 jugador (H)
local Difficulties = {
	Order = { "Calma", "Tension", "Crisis", "Colapso" },
	Default = "Tension",
	MaxAliveCap = 32, -- tope de zombies vivos a la vez en cualquier dificultad (rendimiento en celular)

	Calma = {
		Name = "Calm",
		Upper = "CALM",
		Description = "To get to know the barrio: fewer zombies, weaker and slower. Everything costs less and you last longer downed.",
		Color = Color3.fromRGB(110, 190, 140),
		Health = 0.8,
		Speed = 0.9,
		Damage = 0.6,
		MaxAlive = 0.7,
		Horde = 0.6,
		FastChance = 0.1,
		ExtraTanks = 0,
		TankEvery = 1.5,
		SpawnInterval = 1.3,
		Cost = 0.8,
		Reward = 1,
		MedkitHeal = 1,
		BleedTime = 1.3,
		SelfRevives = 2,
	},

	Tension = {
		Name = "Tension",
		Upper = "TENSION",
		Description = "The intended experience: medium hordes, normal zombies and fair prices. Watch your back.",
		Color = Color3.fromRGB(240, 200, 80),
		Health = 1,
		Speed = 1,
		Damage = 1,
		MaxAlive = 1,
		Horde = 1,
		FastChance = 0.2,
		ExtraTanks = 0,
		TankEvery = 1,
		SpawnInterval = 1,
		Cost = 1,
		Reward = 1,
		MedkitHeal = 1,
		BleedTime = 1,
		SelfRevives = 1,
	},

	Crisis = {
		Name = "Crisis",
		Upper = "CRISIS",
		Description = "More zombies, tougher and faster. Tanks show up often and there's less help; cans go a bit further.",
		Color = Color3.fromRGB(235, 130, 55),
		Health = 1.5,
		Speed = 1.08,
		Damage = 1.4,
		MaxAlive = 1.25,
		Horde = 1.4,
		FastChance = 0.3,
		ExtraTanks = 1,
		TankEvery = 0.75,
		SpawnInterval = 0.8,
		Cost = 1.25,
		Reward = 1.15,
		MedkitHeal = 0.85,
		BleedTime = 0.85,
		SelfRevives = 1,
	},

	Colapso = {
		Name = "Collapse",
		Upper = "COLLAPSE",
		Description = "The barrio has fallen: huge hordes of hard-biting zombies, relentless Tanks and almost no help.",
		Color = Color3.fromRGB(226, 38, 44),
		Health = 2,
		Speed = 1.15,
		Damage = 1.8,
		MaxAlive = 1.4,
		Horde = 1.8,
		FastChance = 0.4,
		ExtraTanks = 2,
		TankEvery = 0.55,
		SpawnInterval = 0.65,
		Cost = 1.5,
		Reward = 1.3,
		MedkitHeal = 0.7,
		BleedTime = 0.7,
		SelfRevives = 0,
	},
}

-- La dificultad con ese id, o la de por defecto si el id no existe
function Difficulties.get(id)
	return Difficulties[id] or Difficulties[Difficulties.Default]
end

-- ¿Es un id de dificultad válido?
function Difficulties.isValid(id)
	return type(id) == "string" and table.find(Difficulties.Order, id) ~= nil
end

-- Precio con el multiplicador de la dificultad, redondeado a múltiplos de 5 (500 -> 625 en Crisis)
function Difficulties.price(base, id)
	return math.max(5, math.floor(base * Difficulties.get(id).Cost / 5 + 0.5) * 5)
end

return Difficulties
