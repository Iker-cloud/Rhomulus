-- Cosméticos del jugador. Perfil: marcos (el aro de color del avatar) y títulos (la línea bajo el nombre), que se desbloquean al subir
-- de nivel (shared/Progress). Armas cuerpo a cuerpo: el cuchillo es el básico y las demás son skins que se compran con Rhoms; TODAS
-- hacen lo mismo (el daño, el alcance y el ritmo están en Config.Melee), solo cambian el aspecto, el sonido y el gesto del golpe.
-- Solo son datos: la partida guarda lo que cada jugador lleva puesto y el menú lo muestra y deja elegirlo.
-- Los ids no se traducen; los nombres sí (shared/LangEs).
local Cosmetics = {}

-- Marcos: `Color` es el aro; `Level` el nivel que hace falta
Cosmetics.Frames = {
	{ Id = "Blood", Name = "Blood", Level = 1, Color = Color3.fromRGB(208, 18, 24) },
	{ Id = "Bone", Name = "Bone", Level = 3, Color = Color3.fromRGB(226, 216, 196) },
	{ Id = "Moss", Name = "Moss", Level = 6, Color = Color3.fromRGB(110, 170, 90) },
	{ Id = "Brass", Name = "Brass", Level = 10, Color = Color3.fromRGB(205, 150, 60) },
	{ Id = "Ice", Name = "Ice", Level = 15, Color = Color3.fromRGB(120, 200, 235) },
	{ Id = "Violet", Name = "Violet", Level = 20, Color = Color3.fromRGB(165, 110, 225) },
	{ Id = "Gold", Name = "Gold", Level = 30, Color = Color3.fromRGB(246, 196, 40) },
	{ Id = "Glow", Name = "Glow", Level = 40, Color = Color3.fromRGB(255, 120, 40) },
}

-- Títulos: el texto va en inglés y se traduce solo
Cosmetics.Titles = {
	{ Id = "Survivor", Name = "Survivor", Level = 1 },
	{ Id = "Scavenger", Name = "Scavenger", Level = 3 },
	{ Id = "Medic", Name = "Field Medic", Level = 6 },
	{ Id = "TankBreaker", Name = "Tank Breaker", Level = 10 },
	{ Id = "NightWalker", Name = "Night Walker", Level = 15 },
	{ Id = "Veteran", Name = "Veteran", Level = 20 },
	{ Id = "Warden", Name = "Warden of the Morro", Level = 30 },
	{ Id = "Legend", Name = "Legend of Rhomulus", Level = 40 },
	{ Id = "LastLight", Name = "The Last Light", Level = 50 },
}

Cosmetics.DefaultFrame = "Blood"
Cosmetics.DefaultTitle = "Survivor"

local byKind = { frame = Cosmetics.Frames, title = Cosmetics.Titles }

function Cosmetics.list(kind)
	return byKind[kind]
end

function Cosmetics.get(kind, id)
	for _, item in byKind[kind] or {} do
		if item.Id == id then
			return item
		end
	end
	return nil
end

-- ¿Lo tiene quien está en `level`? Un id que no existe nunca se puede poner.
function Cosmetics.unlocked(kind, id, level)
	local item = Cosmetics.get(kind, id)
	return item ~= nil and (level or 1) >= item.Level
end

-- Si lo guardado ya no existe o aún no lo tiene, el predeterminado
function Cosmetics.valid(kind, id, level)
	if Cosmetics.unlocked(kind, id, level) then
		return id
	end
	return kind == "frame" and Cosmetics.DefaultFrame or Cosmetics.DefaultTitle
end

-- Armas cuerpo a cuerpo ----------------------------------------------------------------------------------------------------------
-- Rarity: Common, Rare, Epic o Legendary (Cosmetics.Rarities). Price: Rhoms (el cuchillo es gratis y siempre se tiene).
-- Style: el gesto de los brazos (client/ItemPoses: "MeleeSlash" tajo en diagonal, "MeleeChop" golpe desde arriba, "MeleeSweep" barrido, "MeleeStab" estocada, "MeleeBash" sartenazo, "MeleeSaw" motosierra).
-- Desc: la línea del panel de la armería (en inglés; la traduce LangEs).
-- Pitch / Volume: cómo suena el golpe (el mismo sonido a otro tono). Model: cada skin usa su modelo 3D de ZombieData (Melee<Id>, server/MeleeModel); si falta sale un bloque de color; cuando
-- no hay modelo se usa Size (largo, ancho y grosor del bloque).
Cosmetics.Rarities = {
	Common = { Text = "COMMON", Color = Color3.fromRGB(176, 176, 182) },
	Rare = { Text = "RARE", Color = Color3.fromRGB(78, 160, 255) },
	Epic = { Text = "EPIC", Color = Color3.fromRGB(190, 108, 255) },
	Legendary = { Text = "LEGENDARY", Color = Color3.fromRGB(255, 196, 60) },
}

Cosmetics.MeleeSkins = {
	{ Id = "Knife", Desc = "Standard issue. Quick and quiet.", Name = "Combat Knife", Rarity = "Common", Price = 0, Style = "MeleeStab", Pitch = 1.0, Volume = 0.5,
		Color = Color3.fromRGB(170, 174, 180), Size = Vector3.new(0.14, 0.5, 1.5) },
	{ Id = "Pan", Desc = "Cast iron. Rings like a church bell.", Name = "Frying Pan", Rarity = "Common", Price = 3, Style = "MeleeBash", Pitch = 0.7, Volume = 0.6,
		Color = Color3.fromRGB(70, 72, 78), Size = Vector3.new(0.2, 1.2, 1.9) },
	{ Id = "Bat", Desc = "Studded with nails. Leaves a mark.", Name = "Baseball Bat", Rarity = "Common", Price = 6, Style = "MeleeSweep", Pitch = 0.85, Volume = 0.6,
		Color = Color3.fromRGB(190, 140, 80), Size = Vector3.new(0.3, 0.3, 2.6) },
	{ Id = "Machete", Desc = "Market steel. Clears a path.", Name = "Machete", Rarity = "Rare", Price = 12, Style = "MeleeSlash", Pitch = 1.25, Volume = 0.55,
		Color = Color3.fromRGB(120, 130, 135), Size = Vector3.new(0.12, 0.6, 2.2) },
	{ Id = "Axe", Desc = "Fire station red. Heavy and final.", Name = "Fire Axe", Rarity = "Epic", Price = 25, Style = "MeleeChop", Pitch = 0.6, Volume = 0.7,
		Color = Color3.fromRGB(200, 40, 36), Size = Vector3.new(0.3, 0.9, 2.4) },
	{ Id = "Chainsaw", Desc = "Loud, brutal and unforgettable.", Name = "Chainsaw", Rarity = "Legendary", Price = 50, Style = "MeleeSaw", Pitch = 0.45, Volume = 0.8,
		Color = Color3.fromRGB(255, 150, 30), Size = Vector3.new(0.6, 0.9, 2.6) },
}
Cosmetics.DefaultMelee = "Knife"

-- Variantes de color de las armas de arriba: salen solo de las CAJAS (Crate = true, sin precio). Usan el modelo, el gesto y el tono de
-- su arma base (`Base`) y repintan sus piezas hacia `Tint` (Cosmetics.tintModel). Los ids de aquí se guardan en el DataStore: no cambiarlos.
local VARIANTS = {
	{ Id = "KnifeRust", Base = "Knife", Name = "Rusty Knife", Desc = "Pulled from a flooded basement.", Rarity = "Common", Tint = Color3.fromRGB(150, 84, 44) },
	{ Id = "KnifeBone", Base = "Knife", Name = "Bone Knife", Desc = "Carved by someone with time to spare.", Rarity = "Rare", Tint = Color3.fromRGB(226, 218, 196) },
	{ Id = "KnifeBlood", Base = "Knife", Name = "Blood Knife", Desc = "It was never really clean.", Rarity = "Epic", Tint = Color3.fromRGB(150, 14, 24) },
	{ Id = "PanCopper", Base = "Pan", Name = "Copper Pan", Desc = "Grandma's good one. Handle with respect.", Rarity = "Rare", Tint = Color3.fromRGB(196, 112, 62) },
	{ Id = "PanGold", Base = "Pan", Name = "Golden Pan", Desc = "Solid gold. Terrible for cooking.", Rarity = "Legendary", Tint = Color3.fromRGB(255, 200, 60) },
	{ Id = "BatBurnt", Base = "Bat", Name = "Charred Bat", Desc = "Survived the fire at the market.", Rarity = "Common", Tint = Color3.fromRGB(46, 38, 34) },
	{ Id = "BatNeon", Base = "Bat", Name = "Toxic Bat", Desc = "Glows a little. Don't ask why.", Rarity = "Epic", Tint = Color3.fromRGB(110, 255, 90) },
	{ Id = "MacheteJade", Base = "Machete", Name = "Jade Machete", Desc = "Cold green steel from the old country.", Rarity = "Epic", Tint = Color3.fromRGB(70, 190, 130) },
	{ Id = "MacheteObsidian", Base = "Machete", Name = "Obsidian Machete", Desc = "Black as the night over the hill.", Rarity = "Legendary", Tint = Color3.fromRGB(30, 24, 40) },
	{ Id = "AxeFrost", Base = "Axe", Name = "Frost Axe", Desc = "Chipped from a frozen delivery truck.", Rarity = "Epic", Tint = Color3.fromRGB(130, 200, 255) },
	{ Id = "AxeGilded", Base = "Axe", Name = "Gilded Axe", Desc = "The chief's axe. Heavy and shiny.", Rarity = "Legendary", Tint = Color3.fromRGB(255, 196, 70) },
	{ Id = "ChainsawToxic", Base = "Chainsaw", Name = "Toxic Chainsaw", Desc = "Runs on something that shouldn't burn.", Rarity = "Legendary", Tint = Color3.fromRGB(150, 255, 60) },
}
for _, variant in VARIANTS do
	local base
	for _, skin in Cosmetics.MeleeSkins do
		if skin.Id == variant.Base then
			base = skin
		end
	end
	table.insert(Cosmetics.MeleeSkins, {
		Id = variant.Id, Base = variant.Base, Crate = true, Tint = variant.Tint, Name = variant.Name, Desc = variant.Desc,
		Rarity = variant.Rarity, Price = 0, Style = base.Style, Pitch = base.Pitch, Volume = base.Volume,
		Color = variant.Tint, Size = base.Size,
	})
end

-- Repinta un modelo de arma hacia el color de la skin (las variantes de las cajas). Las piezas oscuras o claras conservan algo de su tono.
function Cosmetics.tintModel(model, skin)
	if not skin or not skin.Tint then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Color = part.Color:Lerp(skin.Tint, 0.7)
			if skin.Rarity == "Legendary" or skin.Rarity == "Epic" then
				part.Material = Enum.Material.Metal
			end
		end
	end
end

-- Cajas ---------------------------------------------------------------------------------------------------------------------------
-- Arsenal: skins de cuerpo a cuerpo. Se compra con Rhoms o cae como premio al terminar una ronda; los repetidos devuelven Rhoms.
-- Weights = % por rareza (entre las skins de esa rareza se reparte por igual). Pity: tras tantas cajas sin una rareza, la siguiente la
-- garantiza (la Épica también sale si cae Legendaria). Sin balancear.
Cosmetics.Crates = {
	Arsenal = {
		Price = 8,
		Weights = { Common = 55, Rare = 28, Epic = 13, Legendary = 4 },
		Refund = { Common = 1, Rare = 2, Epic = 4, Legendary = 10 }, -- Rhoms al sacar un repetido
		Pity = { Epic = 8, Legendary = 30 },
		Drop = { Base = 0.20, Win = 0.12, Max = 0.6, Difficulty = { Calma = 0, Tension = 0.05, Crisis = 0.10, Colapso = 0.20 }, Rarity = 0.10 },
	},
}

-- Lista de skins que pueden salir de la caja Arsenal (todas menos la del cuchillo básico)
function Cosmetics.crateSkins(rarity)
	local list = {}
	for _, skin in Cosmetics.MeleeSkins do
		if skin.Id ~= Cosmetics.DefaultMelee and (not rarity or skin.Rarity == rarity) then
			table.insert(list, skin)
		end
	end
	return list
end

-- Sortea una caja: devuelve la skin que sale. `pity` = { sinceEpic, sinceLegendary } (cajas sin esa rareza antes de esta); `roll` es un
-- número de 0 a 1 para la rareza y `pick` otro para elegir la skin (así el servidor decide y se puede probar con números fijos).
function Cosmetics.rollCrate(crateId, pity, roll, pick)
	local crate = Cosmetics.Crates[crateId]
	local rarity
	if (pity.sinceLegendary or 0) + 1 >= crate.Pity.Legendary then
		rarity = "Legendary"
	elseif (pity.sinceEpic or 0) + 1 >= crate.Pity.Epic then
		rarity = "Epic"
	else
		local total = 0
		for _, weight in crate.Weights do
			total += weight
		end
		local at = roll * total
		for _, name in { "Common", "Rare", "Epic", "Legendary" } do
			at -= crate.Weights[name]
			if at < 0 then
				rarity = name
				break
			end
		end
		rarity = rarity or "Common"
	end
	local pool = Cosmetics.crateSkins(rarity)
	return pool[math.clamp(math.floor(pick * #pool) + 1, 1, #pool)]
end

-- Probabilidad de que caiga una caja Arsenal al terminar la ronda
function Cosmetics.crateDropChance(won, difficultyId, rarities)
	local d = Cosmetics.Crates.Arsenal.Drop
	local chance = d.Base + (won and d.Win or 0) + (d.Difficulty[difficultyId] or 0)
	for _, rarity in rarities or {} do
		if rarity == "Epic" or rarity == "Legendary" then
			chance += d.Rarity
			break
		end
	end
	return math.min(chance, d.Max)
end

function Cosmetics.melee(id)
	for _, skin in Cosmetics.MeleeSkins do
		if skin.Id == id then
			return skin
		end
	end
	return nil
end

-- `owned` es una lista de ids (o un texto "Knife,Pan"). El cuchillo siempre se tiene.
function Cosmetics.ownsMelee(owned, id)
	if id == Cosmetics.DefaultMelee then
		return true
	end
	if type(owned) == "string" then
		owned = string.split(owned, ",")
	end
	return table.find(owned or {}, id) ~= nil and Cosmetics.melee(id) ~= nil
end

-- La skin que lleva puesta de verdad: la elegida si existe y la tiene; si no, el cuchillo
function Cosmetics.validMelee(owned, id)
	if id and Cosmetics.ownsMelee(owned, id) then
		return id
	end
	return Cosmetics.DefaultMelee
end

return Cosmetics
