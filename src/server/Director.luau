-- Director de hordas: decide cuándo y dónde aparecen zombies, fuera de la vista de los jugadores.
-- Los puntos de aparición son Parts dentro de Workspace/SpawnPoints/<zona> (los crea MapBuilder o se colocan en Studio).
-- GameState le dice en qué zona está el equipo con setZone; sin zona no aparece nadie.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Zombies = require(script.Parent.Zombies)

local Director = {}

local zone = nil
local boost = false

function Director.setZone(name)
	zone = name
end

-- Presión alta (extracción): los zombies aparecen más seguido
function Director.setBoost(on)
	boost = on
end

local function getSpawnPoints()
	local points = {}
	local root = workspace:FindFirstChild("SpawnPoints")
	local folder = root and zone and root:FindFirstChild(zone)
	if folder then
		for _, part in folder:GetChildren() do
			if part:IsA("BasePart") then
				table.insert(points, part.Position - Vector3.new(0, part.Size.Y / 2, 0))
			end
		end
	end
	return points
end

-- Ajuste por número de jugadores (se recalcula en cada ciclo)
local function getScaling()
	local count = math.clamp(#Players:GetPlayers(), 1, 4)
	return Config.Director.ByPlayers[count]
end

local function getMaxAlive()
	return getScaling().MaxAlive
end

-- Un punto es válido si está lejos de todos los jugadores y ninguno lo ve
local function isHidden(point)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	for _, player in Players:GetPlayers() do
		local head = player.Character and player.Character:FindFirstChild("Head")
		if head then
			local eye = point + Vector3.new(0, 3, 0)
			local delta = eye - head.Position
			if delta.Magnitude < Config.Director.MinSpawnDistance then
				return false
			end
			-- Muy lejos se considera fuera de vista aunque no haya paredes en medio
			if delta.Magnitude < Config.Director.FarSpawnDistance then
				params.FilterDescendantsInstances = { workspace:FindFirstChild("Zombies"), player.Character }
				if not workspace:Raycast(head.Position, delta, params) then
					return false -- línea de vista libre
				end
			end
		end
	end
	return true
end

local function pickPoint()
	local candidates = {}
	for _, point in getSpawnPoints() do
		if isHidden(point) then
			table.insert(candidates, point)
		end
	end
	if #candidates > 0 then
		return candidates[math.random(#candidates)]
	end
end

local function spawnOne()
	local point = pickPoint()
	if not point then
		return false
	end
	local kind = math.random() < Config.Director.FastChance and "Fast" or "Common"
	Zombies.spawn(kind, point)
	return true
end

-- Horda: aparece de golpe, respetando el límite de vivos. size es el tamaño al 100% (4 jugadores).
function Director.spawnHorde(size)
	local count = math.floor(size * getScaling().HordeScale + 0.5)
	for _ = 1, count do
		if Zombies.getAlive() >= getMaxAlive() then
			break
		end
		spawnOne()
		task.wait(Config.Director.HordeSpawnDelay)
	end
end

function Director.start()
	task.spawn(function()
		while true do
			if zone and #Players:GetPlayers() > 0 and Zombies.getAlive() < getMaxAlive() then
				spawnOne()
			end
			task.wait(boost and Config.Director.BoostInterval or Config.Director.SpawnInterval)
		end
	end)
end

return Director
