-- Cosméticos del perfil: marcos (el aro de color del avatar) y títulos (la línea bajo el nombre). Se desbloquean al subir de nivel
-- (shared/Progress). Solo son datos: la partida guarda el que cada jugador lleva puesto y el menú lo muestra y deja elegirlo.
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

return Cosmetics
