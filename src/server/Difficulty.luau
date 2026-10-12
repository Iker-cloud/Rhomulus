-- Dificultad de la partida en curso (datos en shared/Difficulties). GameState la fija antes de construir el mapa: la elige el
-- anfitrión en el menú (partida privada) o la votan los jugadores junto con el mapa. El id se publica en Workspace.Difficulty
-- para que el cliente (tienda, etiqueta en pantalla) vea los mismos precios. Aquí viven las funciones que aplican los
-- multiplicadores: Director, Zombies, Points, WeaponBox, Items, Medkits y PlayerState las usan.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Difficulties = require(ReplicatedStorage.Shared.Difficulties)

local Difficulty = {}

local currentId = Difficulties.Default
workspace:SetAttribute("Difficulty", currentId)

function Difficulty.set(id)
	currentId = Difficulties.isValid(id) and id or Difficulties.Default
	workspace:SetAttribute("Difficulty", currentId)
end

function Difficulty.id()
	return currentId
end

-- La tabla de la dificultad actual (multiplicadores)
function Difficulty.get()
	return Difficulties[currentId]
end

-- Precio de algo con el multiplicador de la dificultad actual
function Difficulty.price(base)
	return Difficulties.price(base, currentId)
end

-- Estadísticas de un tipo de zombie ("Common", "Fast" o "Tank") ya escaladas por la dificultad
function Difficulty.zombieStats(kind)
	local base = Config.Zombie[kind]
	local d = Difficulties[currentId]
	local stats = table.clone(base)
	stats.Health = math.max(1, math.floor(base.Health * d.Health + 0.5))
	stats.Speed = base.Speed * d.Speed
	stats.Damage = math.max(1, math.floor(base.Damage * d.Damage + 0.5))
	return stats
end

return Difficulty
