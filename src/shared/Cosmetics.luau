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
-- Style: el gesto de los brazos (client/ItemPoses: "MeleeSlash" tajo en diagonal, "MeleeChop" golpe desde arriba, "MeleeSweep" barrido).
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
	{ Id = "Knife", Desc = "Standard issue. Quick and quiet.", Name = "Combat Knife", Rarity = "Common", Price = 0, Style = "MeleeSlash", Pitch = 1.0, Volume = 0.5,
		Color = Color3.fromRGB(170, 174, 180), Size = Vector3.new(0.14, 0.5, 1.5) },
	{ Id = "Pan", Desc = "Cast iron. Rings like a church bell.", Name = "Frying Pan", Rarity = "Common", Price = 3, Style = "MeleeSweep", Pitch = 0.7, Volume = 0.6,
		Color = Color3.fromRGB(70, 72, 78), Size = Vector3.new(0.2, 1.2, 1.9) },
	{ Id = "Bat", Desc = "Studded with nails. Leaves a mark.", Name = "Baseball Bat", Rarity = "Common", Price = 6, Style = "MeleeSweep", Pitch = 0.85, Volume = 0.6,
		Color = Color3.fromRGB(190, 140, 80), Size = Vector3.new(0.3, 0.3, 2.6) },
	{ Id = "Machete", Desc = "Market steel. Clears a path.", Name = "Machete", Rarity = "Rare", Price = 12, Style = "MeleeSlash", Pitch = 1.25, Volume = 0.55,
		Color = Color3.fromRGB(120, 130, 135), Size = Vector3.new(0.12, 0.6, 2.2) },
	{ Id = "Axe", Desc = "Fire station red. Heavy and final.", Name = "Fire Axe", Rarity = "Epic", Price = 25, Style = "MeleeChop", Pitch = 0.6, Volume = 0.7,
		Color = Color3.fromRGB(200, 40, 36), Size = Vector3.new(0.3, 0.9, 2.4) },
	{ Id = "Chainsaw", Desc = "Loud, brutal and unforgettable.", Name = "Chainsaw", Rarity = "Legendary", Price = 50, Style = "MeleeChop", Pitch = 0.45, Volume = 0.8,
		Color = Color3.fromRGB(255, 150, 30), Size = Vector3.new(0.6, 0.9, 2.6) },
}
Cosmetics.DefaultMelee = "Knife"

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
