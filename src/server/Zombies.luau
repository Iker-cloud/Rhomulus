-- Zombies: modelo ligero + IA que persigue al jugador más cercano con PathfindingService y lo golpea.
local ContentProvider = game:GetService("ContentProvider")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerState = require(script.Parent.PlayerState)

local Zombies = {}

local folder = Instance.new("Folder")
folder.Name = "Zombies"
folder.Parent = workspace

-- Cuerpo R15 base (se crea una vez y se clona para cada zombie)
local template = nil

local function getTemplate()
	if template then
		return template
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("No se pudo crear el cuerpo base de los zombies:", model)
		return nil
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy() -- sin el Animate de Roblox: animamos nosotros
		end
	end
	-- Precarga las animaciones para que las pistas no nazcan vacías
	local animations = {}
	for _, id in Config.Animations.Zombie do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		table.insert(animations, animation)
	end
	ContentProvider:PreloadAsync(animations)

	template = model
	return template
end

local function loadTrack(animator, id, priority)
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track.Priority = priority
	return track
end

-- Se llama con el zombie ya dentro del workspace (si no, Roblox no carga las pistas)
local function animate(kind, stats, humanoid)
	-- Idle parado, caminar o correr (el rápido) al moverse
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local anims = Config.Animations.Zombie
	local idle = loadTrack(animator, anims.Idle, Enum.AnimationPriority.Idle)
	local move = loadTrack(animator, kind == "Fast" and anims.Run or anims.Walk, Enum.AnimationPriority.Movement)
	idle:Play()
	humanoid.Running:Connect(function(speed)
		if speed > 1 then
			if not move.IsPlaying then
				idle:Stop()
				move:Play()
			end
			move:AdjustSpeed(math.clamp(speed / stats.Speed, 0.5, 1.5))
		elseif not idle.IsPlaying then
			move:Stop()
			idle:Play()
		end
	end)
end

local function build(kind, stats, position)
	local base = getTemplate()
	if not base then
		return nil
	end
	local model = base:Clone()
	model.Name = "Zombie"

	-- Piel verde (o rojiza si es rápido) y piernas oscuras
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			if part.Name:find("Leg") or part.Name:find("Foot") then
				part.Color = Color3.fromRGB(60, 70, 90)
			else
				part.Color = stats.Color
			end
		end
		if part:IsA("Accessory") or part:IsA("Shirt") or part:IsA("Pants") then
			part:Destroy()
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.MaxHealth = stats.Health
	humanoid.Health = stats.Health
	humanoid.WalkSpeed = stats.Speed
	humanoid.DisplayName = "Zombie"
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged

	local root = model.HumanoidRootPart
	model:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))

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

-- Prepara el cuerpo y las animaciones al arrancar, antes del primer zombie
task.spawn(getTemplate)

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
function Zombies.spawn(kind, position)
	local stats = Config.Zombie[kind]
	local model, humanoid, root = build(kind, stats, position)
	if not model then
		return nil
	end
	model:SetAttribute("Kind", kind)
	model.Parent = folder
	animate(kind, stats, humanoid)
	root:SetNetworkOwner(nil) -- el servidor simula la física del zombie

	humanoid.Died:Once(function()
		task.wait(Config.Zombie.CorpseTime)
		model:Destroy()
	end)

	task.spawn(think, humanoid, root, stats)
	return model
end

return Zombies
