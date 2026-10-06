-- Zombies: modelo con articulaciones (ZombieModel) + IA que persigue al jugador más cercano con PathfindingService y lo golpea.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerState = require(script.Parent.PlayerState)
local ZombieModel = require(script.Parent.ZombieModel)

local Zombies = {}

-- Modelo de cada tipo (se generan con tools/glb_to_lua.py desde assets/*.glb)
local MODELS = {
	Common = require(script.Parent.ZombieData.Brotado),
	Fast = require(script.Parent.ZombieData.Desbocado),
}

local folder = Instance.new("Folder")
folder.Name = "Zombies"
folder.Parent = workspace

local function nearestTarget(fromPosition)
	local best, bestDistance
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		-- Los caídos no son objetivo: los zombies van por los que siguen de pie
		if humanoid and root and humanoid.Health > 0 and PlayerState.get(player) == "Normal" then
			local distance = (root.Position - fromPosition).Magnitude
			if not bestDistance or distance < bestDistance then
				best, bestDistance = { player = player, root = root, character = character }, distance
			end
		end
	end
	return best, bestDistance
end

local function think(humanoid, root, stats)
	local path = PathfindingService:CreatePath({
		AgentRadius = 1.5,
		AgentHeight = 5.5,
		AgentCanJump = true,
	})
	local sightParams = RaycastParams.new()
	sightParams.FilterType = Enum.RaycastFilterType.Exclude

	local lastAttack = 0
	-- Desfase aleatorio para que 25 zombies no calculen ruta en el mismo frame
	local lastPath = os.clock() - math.random() * Config.Zombie.RepathInterval

	while humanoid.Health > 0 and root.Parent do
		local target, distance = nearestTarget(root.Position)
		if target then
			local now = os.clock()

			if distance <= stats.AttackRange then
				humanoid:MoveTo(root.Position) -- se detiene para golpear
				if now - lastAttack >= stats.AttackCooldown then
					lastAttack = now
					root.Parent:SetAttribute("Attack", workspace:GetServerTimeNow()) -- el cliente anima la embestida
					PlayerState.damage(target.player, stats.Damage)
				end
			elseif now - lastPath >= Config.Zombie.RepathInterval then
				lastPath = now

				-- Con línea de vista libre no hace falta calcular ruta (más barato)
				sightParams.FilterDescendantsInstances = { folder, target.character }
				local blocked = workspace:Raycast(root.Position, target.root.Position - root.Position, sightParams)
				if not blocked then
					humanoid:MoveTo(target.root.Position)
				else
					local ok = pcall(path.ComputeAsync, path, root.Position, target.root.Position)
					local waypoints = ok and path.Status == Enum.PathStatus.Success and path:GetWaypoints()
					if waypoints and #waypoints >= 2 then
						local waypoint = waypoints[2]
						if waypoint.Action == Enum.PathWaypointAction.Jump then
							humanoid.Jump = true
						end
						humanoid:MoveTo(waypoint.Position)
					else
						humanoid:MoveTo(target.root.Position) -- sin ruta: acercarse en línea recta
					end
				end
			end
		end
		task.wait(Config.Zombie.ThinkInterval)
	end
end

-- Zombies vivos ahora mismo (lo usa el director para respetar el límite)
function Zombies.getAlive()
	local count = 0
	for _, model in folder:GetChildren() do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			count += 1
		end
	end
	return count
end

-- Borra todos los zombies (cambio de zona, fin de partida)
function Zombies.clear()
	folder:ClearAllChildren()
end

-- Crea un zombie del tipo dado ("Common" o "Fast") en la posición (a nivel del suelo). Devuelve el modelo.
-- Se anima en el cliente (ZombieAnimator), así que aquí solo se construye y se le da la IA.
function Zombies.spawn(kind, position)
	local stats = Config.Zombie[kind]
	local model, humanoid, root = ZombieModel.build(MODELS[kind], stats, position)
	model:SetAttribute("Kind", kind)
	model.Parent = folder
	root:SetNetworkOwner(nil) -- el servidor simula la física del zombie

	humanoid.Died:Once(function()
		task.wait(Config.Zombie.CorpseTime)
		model:Destroy()
	end)

	task.spawn(think, humanoid, root, stats)
	return model
end

return Zombies
