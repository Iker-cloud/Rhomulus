-- Zombies: modelo ligero + IA que persigue al jugador más cercano con PathfindingService y lo golpea.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Zombies = {}

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
	root.Color = Color3.fromRGB(90, 130, 80)
	root.CFrame = CFrame.new(position + Vector3.new(0, stats.HipHeight + 1, 0))
	root.Parent = model
	model.PrimaryPart = root

	addPart(model, "Legs", Vector3.new(2, stats.HipHeight, 1), Vector3.new(0, -1 - stats.HipHeight / 2, 0), root, Color3.fromRGB(60, 70, 90))
	addPart(model, "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0), root, Color3.fromRGB(120, 160, 110))

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
		if humanoid and root and humanoid.Health > 0 then
			local distance = (root.Position - fromPosition).Magnitude
			if not bestDistance or distance < bestDistance then
				best, bestDistance = { humanoid = humanoid, root = root }, distance
			end
		end
	end
	return best, bestDistance
end

local function think(model, humanoid, root, stats)
	local path = PathfindingService:CreatePath({
		AgentRadius = 1.5,
		AgentHeight = 5.5,
		AgentCanJump = true,
	})
	local lastPath = 0
	local lastAttack = 0

	while humanoid.Health > 0 and model.Parent do
		local target, distance = nearestTarget(root.Position)
		if target then
			local now = os.clock()

			if distance <= stats.AttackRange then
				humanoid:MoveTo(root.Position) -- se detiene para golpear
				if now - lastAttack >= stats.AttackCooldown then
					lastAttack = now
					target.humanoid:TakeDamage(stats.Damage)
				end
			elseif now - lastPath >= Config.Zombie.RepathInterval then
				lastPath = now
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
		task.wait(Config.Zombie.ThinkInterval)
	end
end

-- Crea un zombie del tipo dado ("Common") en la posición (a nivel del suelo). Devuelve el modelo.
function Zombies.spawn(kind, position)
	local stats = Config.Zombie[kind]
	local model, humanoid, root = build(stats, position)
	model.Parent = workspace
	root:SetNetworkOwner(nil) -- el servidor simula la física del zombie

	humanoid.Died:Connect(function()
		task.wait(Config.Zombie.CorpseTime)
		model:Destroy()
	end)

	task.spawn(think, model, humanoid, root, stats)
	return model
end

return Zombies
