-- Mutadores de la ronda: reglas especiales que se sortean al empezar y cambian cómo se juega esa partida (la comparten la partida y,
-- si hace falta, el menú). Cada mutador complica algo y da un bono de XP; el "Generoso" es el bueno y no da bono.
--
-- Campos de cada uno:
--   Name / Upper / Description / Color   lo que ve el jugador
--   Bonus                                XP extra que da (0.25 = +25 %)
--   Mul                                  multiplica campos de la dificultad (Speed, Horde, Reward, Cost, MedkitHeal, SpawnInterval, TankEvery…)
--   Add                                  suma a campos de la dificultad (ExtraTanks)
--   Set                                  fija un campo (FastChance)
--   Flags                                reglas que leen otros sistemas: AmmoMult (munición), PlayerHealth (vida máxima de los jugadores)
--                                        y Blackout (faroles apagados)
--   Conflicts                            ids que no pueden salir en la misma ronda
-- `Mutators.apply(dificultad, ids)` devuelve una copia de la tabla de la dificultad con todo aplicado: así los sistemas que ya leen
-- `Difficulty.get()` notan los mutadores sin cambiar nada.
local Mutators = {}

Mutators.Order = { "MunicionEscasa", "ZombiesRapidos", "DobleTanque", "HordasGrandes", "EconomiaFloja", "Cristal", "Apagon", "Generoso" }

-- Cuántos mutadores salen según la dificultad: { probabilidad de 0, de 1, de 2 }
Mutators.Count = {
	Calma = { 0.6, 0.4, 0 },
	Tension = { 0.25, 0.75, 0 },
	Crisis = { 0.1, 0.6, 0.3 },
	Colapso = { 0, 0.5, 0.5 },
}

Mutators.MunicionEscasa = {
	Name = "Munición escasa",
	Upper = "MUNICIÓN ESCASA",
	Description = "Las armas guardan la mitad de munición de reserva.",
	Color = Color3.fromRGB(240, 170, 70),
	Bonus = 0.2,
	Flags = { AmmoMult = 0.5 },
	Conflicts = { "Generoso" },
}
Mutators.ZombiesRapidos = {
	Name = "Zombies rápidos",
	Upper = "ZOMBIES RÁPIDOS",
	Description = "Los zombies corren más y casi todos son de los rápidos.",
	Color = Color3.fromRGB(230, 90, 70),
	Bonus = 0.2,
	Mul = { Speed = 1.25 },
	Set = { FastChance = 0.6 },
}
Mutators.DobleTanque = {
	Name = "Doble Tanque",
	Upper = "DOBLE TANQUE",
	Description = "Un Tanque más a la vez, y aparecen más seguidos.",
	Color = Color3.fromRGB(190, 70, 50),
	Bonus = 0.3,
	Add = { ExtraTanks = 1 },
	Mul = { TankEvery = 0.7 },
}
Mutators.HordasGrandes = {
	Name = "Hordas grandes",
	Upper = "HORDAS GRANDES",
	Description = "Las hordas son un 50 % mayores, pero llegan menos seguido.",
	Color = Color3.fromRGB(210, 110, 60),
	Bonus = 0.2,
	Mul = { Horde = 1.5, SpawnInterval = 1.25 },
}
Mutators.EconomiaFloja = {
	Name = "Economía floja",
	Upper = "ECONOMÍA FLOJA",
	Description = "Las latas que se ganan valen la mitad.",
	Color = Color3.fromRGB(180, 160, 90),
	Bonus = 0.25,
	Mul = { Reward = 0.5 },
	Conflicts = { "Generoso" },
}
Mutators.Cristal = {
	Name = "Cristal",
	Upper = "CRISTAL",
	Description = "Todos tienen 50 de vida, pero botiquines y vendas curan el doble.",
	Color = Color3.fromRGB(150, 200, 230),
	Bonus = 0.25,
	Mul = { MedkitHeal = 2 },
	Flags = { PlayerHealth = 50 },
}
Mutators.Apagon = {
	Name = "Apagón total",
	Upper = "APAGÓN TOTAL",
	Description = "Los faroles están apagados: solo queda tu linterna.",
	Color = Color3.fromRGB(110, 120, 170),
	Bonus = 0.25,
	Flags = { Blackout = true },
}
Mutators.Generoso = {
	Name = "Generoso",
	Upper = "GENEROSO",
	Description = "Todo cuesta menos, se ganan más latas y la curación rinde más.",
	Color = Color3.fromRGB(110, 190, 140),
	Bonus = 0,
	Mul = { Cost = 0.6, Reward = 1.3, MedkitHeal = 1.5 },
	Conflicts = { "MunicionEscasa", "EconomiaFloja" },
}

function Mutators.isValid(id)
	return type(id) == "string" and table.find(Mutators.Order, id) ~= nil
end

-- Los ids de una lista separada por comas ("Apagon,Cristal"), solo los válidos
function Mutators.parse(text)
	local list = {}
	if type(text) == "string" then
		for id in string.gmatch(text, "[^,]+") do
			if Mutators.isValid(id) and not table.find(list, id) then
				table.insert(list, id)
			end
		end
	end
	return list
end

function Mutators.serialize(ids)
	return table.concat(ids, ",")
end

local function conflict(a, b)
	return table.find(Mutators[a].Conflicts or {}, b) ~= nil or table.find(Mutators[b].Conflicts or {}, a) ~= nil
end

-- Sortea los mutadores de una ronda según la dificultad. `random` es un Random (o nil). Devuelve una lista de ids.
function Mutators.roll(difficultyId, random)
	random = random or Random.new()
	local odds = Mutators.Count[difficultyId] or Mutators.Count.Tension
	local roll, count = random:NextNumber(), 0
	for n = 0, 2 do
		roll -= odds[n + 1]
		count = n
		if roll < 0 then
			break
		end
	end
	local picked = {}
	local pool = table.clone(Mutators.Order)
	while #picked < count and #pool > 0 do
		local id = table.remove(pool, random:NextInteger(1, #pool))
		local ok = true
		for _, other in picked do
			if conflict(id, other) then
				ok = false
			end
		end
		if ok then
			table.insert(picked, id)
		end
	end
	return picked
end

-- XP extra de la ronda (fracción: 0.45 = +45 %)
function Mutators.xpBonus(ids)
	local total = 0
	for _, id in ids do
		total += Mutators[id].Bonus
	end
	return total
end

-- Copia de la tabla de la dificultad con los mutadores aplicados. Agrega `Mutators` (los ids) y `Flags` (reglas de los mutadores).
function Mutators.apply(difficulty, ids)
	local result = table.clone(difficulty)
	result.Mutators = ids
	result.Flags = {}
	for _, id in ids do
		local m = Mutators[id]
		for key, factor in m.Mul or {} do
			result[key] = (result[key] or 1) * factor
		end
		for key, amount in m.Add or {} do
			result[key] = (result[key] or 0) + amount
		end
		for key, value in m.Set or {} do
			result[key] = value
		end
		for key, value in m.Flags or {} do
			result.Flags[key] = value
		end
	end
	return result
end

return Mutators
