-- Objetos del inventario (granada, botiquín, molotov, vendas, bengala). Cada jugador guarda su cantidad en el atributo
-- "Item_<id>" (lo lee client/Inventory). Se compran en las estaciones de munición (WeaponBox llama a Items.tryBuy), se pierden
-- al morir y al empezar cada partida. Valores en Config.Items. El botiquín lo usa server/Medkits; el resto, Items.use.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)
local Points = require(script.Parent.Points)
local Stats = require(script.Parent.Stats)

local Items = {}

local I = Config.Items
local lastUse = {} -- [Player] = os.clock() del último uso
local projectiles = Instance.new("Folder")
projectiles.Name = "Projectiles"
projectiles.Parent = workspace
local flares = Instance.new("Folder")
flares.Name = "Flares" -- Zombies.luau mira esta carpeta: las bengalas atraen a los zombies
flares.Parent = workspace

local function attr(id)
	return "Item_" .. id
end

function Items.count(player, id)
	return player:GetAttribute(attr(id)) or 0
end

function Items.canAdd(player, id)
	return Items.count(player, id) < I[id].Max
end

-- Suma (o resta, con n negativo) respetando el máximo
function Items.add(player, id, n)
	local value = math.clamp(Items.count(player, id) + (n or 1), 0, I[id].Max)
	player:SetAttribute(attr(id), value)
	return value
end

function Items.clear(player)
	for _, id in I.Order do
		player:SetAttribute(attr(id), 0)
	end
end

function Items.resetAll()
	for _, player in Players:GetPlayers() do
		Items.clear(player)
	end
	flares:ClearAllChildren()
	projectiles:ClearAllChildren()
end

-- Compra un objeto (las latas son del equipo). Devuelve (ok, mensaje).
function Items.tryBuy(player, id)
	local cfg = I[id]
	if not cfg then
		return false, "Objeto desconocido"
	end
	if PlayerState.get(player) ~= "Normal" then
		return false, "No puedes comprar ahora"
	end
	if not Items.canAdd(player, id) then
		return false, `Ya llevas el máximo de {string.lower(cfg.Name)}`
	end
	if not Points.spend(cfg.Cost) then
		return false, `Faltan latas: {string.lower(cfg.Name)} cuesta {cfg.Cost}`
	end
	Items.add(player, id, 1)
	Points.feed(`{player.DisplayName} compró {string.lower(cfg.Name)}`)
	return true
end

local function getHumanoid(player)
	return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end

-- Daño a un zombie con crédito de la baja a quien lo tiró
local function hurtZombie(player, humanoid, model, amount)
	if humanoid.Health <= 0 then
		return
	end
	humanoid:TakeDamage(amount)
	if humanoid.Health <= 0 and model.Parent == workspace.Zombies then
		Stats.add(player, "Kills")
		Points.add(Config.Points.Kill[model:GetAttribute("Kind")] or 0, player)
	end
end

local function zombiesNear(position, radius)
	local list = {}
	for _, model in workspace.Zombies:GetChildren() do
		local root = model:FindFirstChild("HumanoidRootPart")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local distance = (root.Position - position).Magnitude
			if distance <= radius then
				table.insert(list, { model = model, humanoid = humanoid, root = root, distance = distance })
			end
		end
	end
	return list
end

-- ¿Hay pared entre el punto y el zombie? (las explosiones no atraviesan muros)
local function blocked(from, to)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace.Zombies, projectiles, flares }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(params.FilterDescendantsInstances, player.Character)
		end
	end
	return workspace:Raycast(from, to - from, params) ~= nil
end

local function newProjectile(player, direction, color, size)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * size
	part.Color = color
	part.Material = Enum.Material.Metal
	part.Position = head.Position + direction * 2.5
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = projectiles
	part:SetNetworkOwner(nil)
	return part
end

local function throw(part, direction, speed)
	part.AssemblyLinearVelocity = direction * speed + Vector3.new(0, 14, 0)
end

local function explode(player, position)
	local cfg = I.Grenade
	local blast = Instance.new("Explosion")
	blast.Position = position
	blast.BlastRadius = cfg.Radius * 0.6
	blast.BlastPressure = 0
	blast.DestroyJointRadiusPercent = 0
	blast.ExplosionType = Enum.ExplosionType.NoCraters
	blast.Parent = workspace
	for _, z in zombiesNear(position, cfg.Radius) do
		if not blocked(position + Vector3.new(0, 1, 0), z.root.Position) then
			hurtZombie(player, z.humanoid, z.model, cfg.Damage * (1 - 0.5 * z.distance / cfg.Radius))
		end
	end
end

local function fireZone(player, position)
	local cfg = I.Molotov
	local zone = Instance.new("Part")
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	zone.Transparency = 1
	zone.Size = Vector3.new(cfg.Radius * 2, 0.4, cfg.Radius * 2)
	zone.Position = position
	zone.Parent = projectiles

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/fire_main.dds"
	emitter.Rate = 70
	emitter.Lifetime = NumberRange.new(0.7, 1.3)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 190, 60), Color3.fromRGB(230, 60, 20))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3.5), NumberSequenceKeypoint.new(1, 0.5) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.LightEmission = 0.8
	emitter.Shape = Enum.ParticleEmitterShape.Disc
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.Parent = zone
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 50)
	light.Range = cfg.Radius * 2.2
	light.Brightness = 2
	light.Parent = zone

	task.spawn(function()
		local endTime = os.clock() + cfg.Duration
		while os.clock() < endTime and zone.Parent do
			for _, z in zombiesNear(position, cfg.Radius) do
				hurtZombie(player, z.humanoid, z.model, cfg.TickDamage)
			end
			task.wait(cfg.Tick)
		end
		emitter.Enabled = false
		Debris:AddItem(zone, 1.5)
	end)
end

local function placeFlare(position)
	local cfg = I.Flare
	local flare = Instance.new("Part")
	flare.Name = "Bengala"
	flare.Anchored = true
	flare.CanCollide = false
	flare.Size = Vector3.new(0.6, 1.4, 0.6)
	flare.Color = Color3.fromRGB(255, 70, 50)
	flare.Material = Enum.Material.Neon
	flare.Position = position + Vector3.new(0, 0.7, 0)
	flare:SetAttribute("Lure", true)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 80, 60)
	light.Range = 40
	light.Brightness = 3
	light.Parent = flare
	local sparks = Instance.new("ParticleEmitter")
	sparks.Rate = 25
	sparks.Lifetime = NumberRange.new(0.5, 1)
	sparks.Speed = NumberRange.new(4, 9)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 150, 80))
	sparks.Size = NumberSequence.new(0.3, 0)
	sparks.LightEmission = 1
	sparks.Parent = flare
	flare.Parent = flares
	Debris:AddItem(flare, cfg.Duration)
end

-- Usa un objeto lanzable o las vendas. `direction` = hacia dónde mira (lo manda el cliente).
function Items.use(player, id, direction)
	local cfg = I[id]
	if not cfg or id == "Medkit" or typeof(id) ~= "string" then
		return
	end
	if PlayerState.get(player) ~= "Normal" or player:GetAttribute("Carrying") or Items.count(player, id) <= 0 then
		return
	end
	if os.clock() - (lastUse[player] or 0) < I.Cooldown then
		return
	end
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if id == "Bandage" then
		if humanoid.Health >= humanoid.MaxHealth then
			Remotes.Feed:FireClient(player, "Tienes la vida llena")
			return
		end
		lastUse[player] = os.clock()
		Items.add(player, id, -1)
		task.delay(cfg.Time, function()
			local current = getHumanoid(player)
			if current and current.Health > 0 and PlayerState.get(player) == "Normal" then
				current.Health = math.min(current.MaxHealth, current.Health + cfg.Heal)
			end
		end)
		return
	end

	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.1 or direction.Magnitude ~= direction.Magnitude then
		return
	end
	direction = direction.Unit
	lastUse[player] = os.clock()
	local part = newProjectile(player, direction, cfg.Color, id == "Flare" and 0.8 or 1.2)
	if not part then
		return
	end
	Items.add(player, id, -1)
	throw(part, direction, cfg.ThrowSpeed)

	if id == "Grenade" then
		task.delay(cfg.Fuse, function()
			if part.Parent then
				local position = part.Position
				part:Destroy()
				explode(player, position)
			end
		end)
	elseif id == "Molotov" then
		local landed = false
		local function land()
			if landed or not part.Parent then
				return
			end
			landed = true
			local position = part.Position
			part:Destroy()
			fireZone(player, position)
		end
		task.delay(0.25, function() -- un instante para despegarse de la mano antes de detectar golpes
			if part.Parent then
				part.Touched:Connect(function(hit)
					if not hit:IsDescendantOf(player.Character) and hit.CanCollide then
						land()
					end
				end)
			end
		end)
		task.delay(3, land)
	elseif id == "Flare" then
		task.delay(1.4, function()
			if part.Parent then
				local position = part.Position
				part:Destroy()
				placeFlare(position)
			end
		end)
	end
end

function Items.start()
	Remotes.UseItem.OnServerEvent:Connect(Items.use)
	PlayerState.Changed.Event:Connect(function(player, state)
		if state == "Dead" then
			Items.clear(player)
		end
	end)
	Players.PlayerAdded:Connect(Items.clear)
	for _, player in Players:GetPlayers() do
		Items.clear(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
end

return Items
