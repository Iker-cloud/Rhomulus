-- Zombies: modelo ligero + IA que persigue al jugador más cercano con PathfindingService y lo golpea.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerState = require(script.Parent.PlayerState)

local Zombies = {}

local folder = Instance.new("Folder")
folder.Name = "Zombies"
folder.Parent = workspace

local alive = 0

local function addPart(model, name, size, offset, root, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.CFrame = root.CFrame * CFrame.new(offset)
	part.CanCollide = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

local function build(stats, position)
	local model = Instance.new("Model")
	model.Name = "Zombie"

	-- La raíz queda a HipHeight del suelo; el humanoide la mueve y el resto va soldado a ella
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Color = stats.Color
	root.CFrame = CFrame.new(position + Vector3.new(0, stats.HipHeight + 1, 0))
	root.Parent = model
	model.PrimaryPart = root

	addPart(model, "Legs", Vector3.new(2, stats.HipHeight, 1), Vector3.new(0, -1 - stats.HipHeight / 2, 0), root, Color3.fromRGB(60, 70, 90))
	addPart(model, "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0), root, stats.Color)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = stats.HipHeight
	humanoid.MaxHealth = stats.Health
	humanoid.Health = stats.Health
	humanoid.WalkSpeed = stats.Speed
	humanoid.DisplayName = "Zombie"
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	return model, humanoid, root
end

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
	return alive
end

-- Crea un zombie del tipo dado ("Common" o "Fast") en la posición (a nivel del suelo). Devuelve el modelo.
function Zombies.spawn(kind, position)
	local stats = Config.Zombie[kind]
	local model, humanoid, root = build(stats, position)
	model.Parent = folder
	root:SetNetworkOwner(nil) -- el servidor simula la física del zombie

	alive += 1
	humanoid.Died:Once(function()
		alive -= 1
		task.wait(Config.Zombie.CorpseTime)
		model:Destroy()
	end)

	task.spawn(think, humanoid, root, stats)
	return model
end

return Zombies
