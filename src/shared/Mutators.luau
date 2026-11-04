-- Mutadores de la ronda: reglas especiales que se sortean al empezar y cambian cómo se juega esa partida (la comparten la partida y,
-- si hace falta, el menú). Cada mutador complica algo y da un bono de XP; el "Generoso" es el bueno y no da bono.
--
-- Campos de cada uno:
--   Name / Upper / Description / Color   lo que ve el jugador
--   Bonus                                XP extra que da (0.25 = +25 %)
--   Mul                                  multiplica campos de la dificultad (Speed, Horde, Reward, Cost, MedkitHeal, SpawnInterval, TankEvery…)
--   Add                                  suma a campos de la dificultad (ExtraTanks)
--   Set                                  fija un campo (FastChance)
--   Flags                                reglas que leen otros sistemas: AmmoMult (munición), PlayerHealth (vida máxima de los jugadores),
--                                        Blackout (faroles apagados), Fog (niebla densa), Explosive (zombies que explotan),
--                                        Noisy (los disparos atraen), Bleed (sangrado con poca vida) y HeadshotMult (crítico)
--   Conflicts                            ids que no pueden salir en la misma ronda
-- `Mutators.apply(dificultad, ids)` devuelve una copia de la tabla de la dificultad con todo aplicado: así los sistemas que ya leen
-- `Difficulty.get()` notan los mutadores sin cambiar nada.
local Mutators = {}

Mutators.Order = {
	"MunicionEscasa", "ZombiesRapidos", "DobleTanque", "HordasGrandes", "EconomiaFloja", "Cristal", "Apagon", "Generoso",
	"NieblaDensa", "Explosivos", "Ruidoso", "Sangrado", "CabezasDuras", "Caceria", "MalaSangre", "NocheSinFin", "Apocalipsis",
}

-- Parejas que solo pueden salir juntas en ciertas dificultades (el resto de dificultades las descarta)
Mutators.PairOnly = {
	{ "ZombiesRapidos", "HordasGrandes", { "Crisis", "Colapso" } },
}

-- Cuántos mutadores salen según la dificultad: { probabilidad de 0, de 1, de 2 }
Mutators.Count = {
	-- Con los mutadores encendidos siempre sale al menos uno (antes en Calma y Tensión a veces salían 0 y no se veía la ruleta)
	Calma = { 0, 1, 0 },
	Tension = { 0, 1, 0 },
	Crisis = { 0, 0.7, 0.3 },
	Colapso = { 0, 0.5, 0.5 },
}

Mutators.MunicionEscasa = {
	Name = "Scarce Ammo",
	Icon = "rbxassetid://86534395644640",
	Upper = "SCARCE AMMO",
	Description = "Weapons hold half the reserve ammo.",
	Color = Color3.fromRGB(240, 170, 70),
	Rarity = "Common",
	Bonus = 0.2,
	Flags = { AmmoMult = 0.5 },
	Conflicts = { "Generoso", "EconomiaFloja" },
}
Mutators.ZombiesRapidos = {
	Name = "Fast Zombies",
	Icon = "rbxassetid://138288305389572",
	Upper = "FAST ZOMBIES",
	Description = "Zombies run faster and most of them are the fast kind.",
	Color = Color3.fromRGB(230, 90, 70),
	Rarity = "Rare",
	Bonus = 0.25,
	Mul = { Speed = 1.25 },
	Set = { FastChance = 0.6 },
}
Mutators.DobleTanque = {
	Name = "Double Tank",
	Icon = "rbxassetid://120148080501363",
	Upper = "DOUBLE TANK",
	Description = "One more Tank at a time, and they show up more often.",
	Color = Color3.fromRGB(190, 70, 50),
	Rarity = "Epic",
	Bonus = 0.4,
	Add = { ExtraTanks = 1 },
	Mul = { TankEvery = 0.7 },
	Conflicts = { "Cristal" },
}
Mutators.HordasGrandes = {
	Name = "Big Hordes",
	Icon = "rbxassetid://82161701530274",
	Upper = "BIG HORDES",
	Description = "Hordes are 50% bigger, but come less often.",
	Color = Color3.fromRGB(210, 110, 60),
	Rarity = "Common",
	Bonus = 0.2,
	Mul = { Horde = 1.5, SpawnInterval = 1.25 },
}
Mutators.EconomiaFloja = {
	Name = "Weak Economy",
	Icon = "rbxassetid://79950308429100",
	Upper = "WEAK ECONOMY",
	Description = "Cans you earn are worth half.",
	Color = Color3.fromRGB(180, 160, 90),
	Rarity = "Common",
	Bonus = 0.2,
	Mul = { Reward = 0.5, Cost = 1.2 },
	Conflicts = { "Generoso", "MunicionEscasa" },
}
Mutators.Cristal = {
	Name = "Glass",
	Icon = "rbxassetid://89176976915836",
	Upper = "GLASS",
	Description = "Everyone has 50 health, but medkits and bandages heal double.",
	Color = Color3.fromRGB(150, 200, 230),
	Rarity = "Rare",
	Bonus = 0.3,
	Mul = { MedkitHeal = 2 },
	Flags = { PlayerHealth = 50, PlayerHealthCollapse = 60 }, -- en Colapso (golpes de 18 y 63) con 50 morirían de un Tanque
	Conflicts = { "DobleTanque" },
}
Mutators.Apagon = {
	Name = "Total Blackout",
	Icon = "rbxassetid://85206179377681",
	Upper = "TOTAL BLACKOUT",
	Description = "The streetlights are out: only your flashlight is left.",
	Color = Color3.fromRGB(110, 120, 170),
	Rarity = "Rare",
	Bonus = 0.25,
	Flags = { Blackout = true },
}
Mutators.Generoso = {
	Name = "Generous",
	Icon = "rbxassetid://96291763474594",
	Upper = "GENEROUS",
	Description = "Everything costs less, you earn more cans and healing goes further.",
	Color = Color3.fromRGB(110, 190, 140),
	Rarity = "Relief",
	Bonus = 0,
	Mul = { Cost = 0.6, Reward = 1.3, MedkitHeal = 1.5 },
	Conflicts = { "MunicionEscasa", "EconomiaFloja" },
}

Mutators.NieblaDensa = {
	Name = "Dense Fog",
	Icon = "rbxassetid://137395626720126",
	Upper = "DENSE FOG",
	Description = "The fog is so thick you can barely see 60 studs.",
	Color = Color3.fromRGB(170, 180, 190),
	Rarity = "Common",
	Bonus = 0.15,
	Flags = { Fog = true },
	Conflicts = { "Apagon" },
}
Mutators.Explosivos = {
	Name = "Explosives",
	Icon = "rbxassetid://110876086569839",
	Upper = "EXPLOSIVES",
	Description = "Some zombies explode when they die: back away for a few seconds.",
	Color = Color3.fromRGB(255, 120, 40),
	Rarity = "Rare",
	Bonus = 0.3,
	Flags = { Explosive = true },
}
Mutators.Ruidoso = {
	Name = "Noisy",
	Icon = "rbxassetid://131739712167132",
	Upper = "NOISY",
	Description = "Every shot draws nearby zombies. The pistol is silent.",
	Color = Color3.fromRGB(240, 210, 80),
	Rarity = "Rare",
	Bonus = 0.25,
	Flags = { Noisy = true },
}
Mutators.Sangrado = {
	Name = "Bleeding",
	Icon = "rbxassetid://129725832158032",
	Upper = "BLEEDING",
	Description = "Below 40 health you lose 1 per second (without going down). Bandage up.",
	Color = Color3.fromRGB(190, 40, 60),
	Rarity = "Rare",
	Bonus = 0.3,
	Flags = { Bleed = true },
}
Mutators.CabezasDuras = {
	Name = "Tough Skulls",
	Icon = "rbxassetid://77531870639085",
	Upper = "TOUGH SKULLS",
	Description = "Headshots deal x1.5 instead of x2.",
	Color = Color3.fromRGB(150, 150, 160),
	Rarity = "Common",
	Bonus = 0.15,
	Flags = { HeadshotMult = 1.5 },
}

-- Combinaciones épicas y la legendaria: reúnen reglas de otras en una sola casilla de la ruleta
Mutators.Caceria = {
	Name = "The Hunt",
	Icon = "rbxassetid://101951631272373",
	Upper = "THE HUNT",
	Description = "Fast zombies and every shot draws them: there's nowhere to hide.",
	Color = Color3.fromRGB(255, 120, 60),
	Rarity = "Epic",
	Bonus = 0.45,
	Mul = { Speed = 1.25 },
	Set = { FastChance = 0.6 },
	Flags = { Noisy = true },
	Conflicts = { "ZombiesRapidos", "Ruidoso", "Generoso" },
}
Mutators.MalaSangre = {
	Name = "Bad Blood",
	Icon = "rbxassetid://99586417134856",
	Upper = "BAD BLOOD",
	Description = "50 health and bleeding when low, but healing is worth double.",
	Color = Color3.fromRGB(200, 40, 70),
	Rarity = "Epic",
	Bonus = 0.45,
	Mul = { MedkitHeal = 2 },
	Flags = { PlayerHealth = 50, PlayerHealthCollapse = 60, Bleed = true },
	Conflicts = { "Cristal", "Sangrado", "DobleTanque", "Generoso" },
}
Mutators.NocheSinFin = {
	Name = "Endless Night",
	Icon = "rbxassetid://122445231723828",
	Upper = "ENDLESS NIGHT",
	Description = "The streetlights go out and thick fog covers everything.",
	Color = Color3.fromRGB(120, 130, 200),
	Rarity = "Epic",
	Bonus = 0.4,
	Flags = { Blackout = true, Fog = true },
	Conflicts = { "Apagon", "NieblaDensa" },
}
Mutators.Apocalipsis = {
	Name = "Apocalypse",
	Icon = "rbxassetid://85531978216232",
	Upper = "APOCALYPSE",
	Description = "More Tanks, fast zombies, huge hordes, explosions and bleeding. Only for the brave.",
	Color = Color3.fromRGB(255, 196, 60),
	Rarity = "Legendary",
	Bonus = 1,
	Add = { ExtraTanks = 1 },
	Mul = { TankEvery = 0.7, Speed = 1.25, Horde = 1.4 },
	Set = { FastChance = 0.6 },
	Flags = { Explosive = true, Bleed = true },
	OnlyIn = { "Crisis", "Colapso" },
	Conflicts = { "DobleTanque", "ZombiesRapidos", "HordasGrandes", "Explosivos", "Sangrado", "Cristal", "Caceria", "MalaSangre", "Ruidoso", "Generoso" },
}

-- Rareza: cuánto pesa en la ruleta (suman 100 con todas las rarezas) y cómo se ve. La ruleta reparte sus casillas según este peso entre
-- las mutaciones de cada rareza, así que las raras ocupan tajadas finas. El Alivio (Generoso) sale poco y no da XP.
Mutators.Rarities = {
	Common = { Text = "COMMON", Color = Color3.fromRGB(176, 176, 182), Weight = 52 },
	Rare = { Text = "RARE", Color = Color3.fromRGB(78, 160, 255), Weight = 29 },
	Epic = { Text = "EPIC", Color = Color3.fromRGB(190, 108, 255), Weight = 12 },
	Legendary = { Text = "LEGENDARY", Color = Color3.fromRGB(255, 196, 60), Weight = 3 },
	Relief = { Text = "RELIEF", Color = Color3.fromRGB(110, 190, 140), Weight = 4 },
}
Mutators.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Relief" }

-- XP único la primera vez que a un jugador le sale cada mutación (lo reparte server/PlayerProgress al terminar la ronda)
Mutators.DiscoveryXp = 100

-- Las mutaciones que pueden salir en una dificultad, en el orden de Mutators.Order
function Mutators.eligible(difficultyId)
	local list = {}
	for _, id in Mutators.Order do
		local only = Mutators[id].OnlyIn
		if not only or table.find(only, difficultyId) then
			table.insert(list, id)
		end
	end
	return list
end

-- Las casillas de la ruleta de una dificultad: { id, fraction (0 a 1 del círculo), from, to (grados desde arriba, en sentido horario) }
-- El tamaño de cada una es el peso de su rareza repartido entre las de esa rareza (así es también su probabilidad de salir por un puntero).
function Mutators.slices(difficultyId)
	local ids = Mutators.eligible(difficultyId)
	local perTier = {}
	for _, id in ids do
		local rarity = Mutators[id].Rarity
		perTier[rarity] = (perTier[rarity] or 0) + 1
	end
	local total = 0
	for rarity, count in perTier do
		total += Mutators.Rarities[rarity].Weight
	end
	local slices, angle = {}, 0
	for _, id in ids do
		local rarity = Mutators[id].Rarity
		local fraction = Mutators.Rarities[rarity].Weight / perTier[rarity] / total
		table.insert(slices, { id = id, fraction = fraction, from = angle, to = angle + fraction * 360 })
		angle += fraction * 360
	end
	return slices
end

-- La casilla que hay en `angle` grados (de 0 a 360)
function Mutators.sliceAt(slices, angle)
	angle %= 360
	for _, slice in slices do
		if angle >= slice.from and angle < slice.to then
			return slice
		end
	end
	return slices[#slices]
end

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

local function conflict(a, b, difficultyId)
	if table.find(Mutators[a].Conflicts or {}, b) ~= nil or table.find(Mutators[b].Conflicts or {}, a) ~= nil then
		return true
	end
	for _, pair in Mutators.PairOnly do
		if (pair[1] == a and pair[2] == b) or (pair[1] == b and pair[2] == a) then
			if not table.find(pair[3], difficultyId) then
				return true
			end
		end
	end
	return false
end

-- Sortea los mutadores de una ronda según la dificultad. Primero cuántos salen (Mutators.Count) y luego se gira la ruleta: un ángulo al azar;
-- el puntero de arriba cae en una casilla y el de abajo (a 180°) en la opuesta, y cada casilla pesa según su rareza (Mutators.slices).
-- Si las dos casillas son la misma o no se llevan bien, se vuelve a girar. Devuelve (lista de ids, ángulo del puntero de arriba en grados).
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
	if count == 0 then
		return {}, 0
	end
	local slices = Mutators.slices(difficultyId)
	for _ = 1, 80 do
		local angle = random:NextNumber() * 360
		local first = Mutators.sliceAt(slices, angle)
		if count == 1 then
			return { first.id }, angle
		end
		local second = Mutators.sliceAt(slices, angle + 180)
		if second.id ~= first.id and not conflict(first.id, second.id, difficultyId) then
			return { first.id, second.id }, angle
		end
	end
	local fallback = slices[1]
	return { fallback.id }, (fallback.from + fallback.to) / 2
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
