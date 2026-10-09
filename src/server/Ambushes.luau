-- Emboscadas del mapa nuevo: la primera vez que un jugador entra en una zona marcada (las plazoletas del callejón)
-- salen unos pocos zombies desde sus puntos (Director.spawnAmbush). MapBuilderBarrio las define en refs.ambushes:
-- { { volume = Part, points = { Vector3, ... }, size = número opcional }, ... }. El mapa de siempre no tiene emboscadas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Atmosphere = require(script.Parent.Atmosphere)
local Director = require(script.Parent.Director)
local PlayerState = require(script.Parent.PlayerState)

local Ambushes = {}

local token = 0 -- cambia al armar o desarmar: el bucle anterior se detiene

local function inside(part, position)
	local rel = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

-- Arma las emboscadas de la zona (cada una salta una sola vez)
function Ambushes.arm(list)
	token += 1
	local myToken = token
	local pending = table.clone(list or {})
	if #pending == 0 then
		return
	end

	task.spawn(function()
		while myToken == token and #pending > 0 do
			for i = #pending, 1, -1 do
				local ambush = pending[i]
				for _, player in Players:GetPlayers() do
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if root and PlayerState.get(player) == "Normal" and inside(ambush.volume, root.Position) then
						table.remove(pending, i)
						Atmosphere.blackout(ambush.volume.Position) -- los faroles cercanos chispean y se apagan
						task.spawn(Director.spawnAmbush, ambush.size or Config.Ambush.Size, ambush.points)
						break
					end
				end
			end
			task.wait(0.25)
		end
	end)
end

function Ambushes.disarm()
	token += 1
end

return Ambushes
