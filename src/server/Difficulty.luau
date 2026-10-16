-- Dificultad de la partida en curso (datos en shared/Difficulties). GameState la fija antes de construir el mapa: la elige el
-- anfitrión en el menú (partida privada) o la votan los jugadores junto con el mapa. El id se publica en Workspace.Difficulty
-- para que el cliente (tienda, etiqueta en pantalla) vea los mismos precios. Aquí viven las funciones que aplican los
-- multiplicadores: Director, Zombies, Points, WeaponBox, Items, Medkits y PlayerState las usan.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Difficulties = require(ReplicatedStorage.Shared.Difficulties)
local Mutators = require(ReplicatedStorage.Shared.Mutators)

local Difficulty = {}

local currentId = Difficulties.Default
local currentMutators = {} -- ids de los mutadores de la ronda
local effective = Difficulties[currentId] -- la dificultad con los mutadores aplicados (lo que leen los demás sistemas)
workspace:SetAttribute("Difficulty", currentId)
workspace:SetAttribute("Mutators", "")

local function rebuild()
	effective = Mutators.apply(Difficulties[currentId], currentMutators)
	workspace:SetAttribute("Mutators", Mutators.serialize(currentMutators))
end

-- Fija la dificultad. Quita los mutadores: se sortean aparte con Difficulty.setMutators.
function Difficulty.set(id)
	currentId = Difficulties.isValid(id) and id or Difficulties.Default
	currentMutators = {}
	workspace:SetAttribute("Difficulty", currentId)
	rebuild()
end

-- Mutadores de la ronda (lista de ids). Se publican en Workspace.Mutators para que el cliente los muestre.
function Difficulty.setMutators(ids)
	currentMutators = {}
	for _, id in ids do
		if Mutators.isValid(id) then
			table.insert(currentMutators, id)
		end
	end
	rebuild()
end

function Difficulty.mutators()
	return currentMutators
end

function Difficulty.id()
	return currentId
end

-- La tabla de la dificultad actual (multiplicadores), con los mutadores de la ronda ya aplicados
function Difficulty.get()
	return effective
end

-- Precio de algo con el multiplicador de la dificultad actual (y los mutadores), redondeado a múltiplos de 5
function Difficulty.price(base)
	return math.max(5, math.floor(base * effective.Cost / 5 + 0.5) * 5)
end

-- Estadísticas de un tipo de zombie ("Common", "Fast" o "Tank") ya escaladas por la dificultad
function Difficulty.zombieStats(kind)
	local base = Config.Zombie[kind]
	local d = effective
	local stats = table.clone(base)
	stats.Health = math.max(1, math.floor(base.Health * d.Health + 0.5))
	stats.Speed = base.Speed * d.Speed
	stats.Damage = math.max(1, math.floor(base.Damage * d.Damage + 0.5))
	return stats
end

return Difficulty
