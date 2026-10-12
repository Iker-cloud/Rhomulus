-- Objetos del inventario (granada, botiquín, molotov, vendas, bengala). Cada jugador guarda su cantidad en el atributo
-- "Item_<id>" (lo lee client/Inventory). Se compran en las estaciones de munición (WeaponBox llama a Items.tryBuy), se pierden
-- al morir y al empezar cada partida. Valores en Config.Items. El botiquín lo usa server/Medkits; el resto, Items.use.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Difficulty = require(script.Parent.Difficulty)
local ItemModel = require(script.Parent.ItemModel)
local PlayerState = require(script.Parent.PlayerState)
local Points = require(script.Parent.Points)
local Stats = require(script.Parent.Stats)

local Items = {}

local I = Config.Items
local busyUntil = {} -- [Player] = os.clock() hasta que termina el gesto del objeto que está usando
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
	local cost = Difficulty.price(cfg.Cost)
	if not Points.spend(cost) then
		return false, `Faltan latas: {string.lower(cfg.Name)} cuesta {cost}`
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

-- Proyectil: el modelo del objeto (ItemModel) con su bola invisible de colisión. Devuelve (la bola, el modelo).
-- Para quitarlo hay que destruir el modelo entero.
local PROJECTILE_MODEL = { Grenade = "Grenade", Molotov = "Molotov", Flare = "Flare" }

local function newProjectile(player, direction, id)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local model = ItemModel.build(PROJECTILE_MODEL[id])
	local part = model.PrimaryPart
	part.CanCollide = true
	local origin = head.Position + direction * 2.5
	model:PivotTo(CFrame.new(origin, origin + direction))
	model.Parent = projectiles
	part:SetNetworkOwner(nil)
	return part, model
end

local function throw(part, direction, speed)
	part.AssemblyLinearVelocity = direction * speed + Vector3.new(0, 14, 0)
	part.AssemblyAngularVelocity = Vector3.new(math.random(-9, 9), math.random(-9, 9), math.random(-9, 9)) -- gira en el aire
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

-- Efectos del gesto (todos visibles para el resto del equipo) ------------------------------------------------------

-- El pasador y la anilla saltan de la granada cuando la izquierda tira de ellos
local function popPin(character)
	local hand = character:FindFirstChild("LeftHand")
	if not hand then
		return
	end
	local brass = Color3.fromRGB(199, 184, 140)
	for i = 1, 2 do
		local piece = Instance.new("Part")
		piece.Name = "Pasador"
		piece.Size = i == 1 and Vector3.new(0.34, 0.05, 0.05) or Vector3.new(0.22, 0.22, 0.04)
		piece.Shape = i == 1 and Enum.PartType.Block or Enum.PartType.Cylinder
		piece.Color = brass
		piece.Material = Enum.Material.Metal
		piece.CanTouch = false
		piece.CastShadow = false
		piece.CFrame = hand.CFrame * CFrame.new(0, -0.3, 0)
		piece.Parent = projectiles
		piece:SetNetworkOwner(nil)
		piece.AssemblyLinearVelocity = hand.CFrame.LookVector * 6 + Vector3.new(math.random(-3, 3), math.random(5, 9), math.random(-3, 3))
		piece.AssemblyAngularVelocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
		Debris:AddItem(piece, 2)
	end
end

-- Fogonazo en la boca de la pistola de bengalas
local function flareFlash(gun)
	local root = gun and gun.PrimaryPart
	if not root then
		return
	end
	local flash = Instance.new("Part")
	flash.Name = "Fogonazo"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 0.7
	flash.Color = Color3.fromRGB(255, 190, 90)
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.CFrame = root.CFrame * CFrame.new(0.7, 0.17, 0)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Brightness = 4
	light.Range = 14
	light.Parent = flash
	local smoke = Instance.new("ParticleEmitter")
	smoke.Rate = 0
	smoke.Lifetime = NumberRange.new(0.5, 0.9)
	smoke.Speed = NumberRange.new(3, 7)
	smoke.SpreadAngle = Vector2.new(25, 25)
	smoke.Color = ColorSequence.new(Color3.fromRGB(190, 190, 190))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.2) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Parent = flash
	flash.Parent = projectiles
	smoke:Emit(10)
	TweenService:Create(flash, TweenInfo.new(0.18), { Size = Vector3.one * 0.1, Transparency = 1 }):Play()
	TweenService:Create(light, TweenInfo.new(0.18), { Brightness = 0 }):Play()
	Debris:AddItem(flash, 1.2)
end

-- Destellos verdes al terminar de vendarse
local function healSparkles(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 0.5, 0)
	attachment.Parent = root
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Rate = 0
	sparkles.Lifetime = NumberRange.new(0.8, 1.3)
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Acceleration = Vector3.new(0, 3, 0)
	sparkles.Color = ColorSequence.new(Color3.fromRGB(150, 255, 170), Color3.fromRGB(255, 255, 255))
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparkles.LightEmission = 1
	sparkles.Parent = attachment
	sparkles:Emit(16)
	Debris:AddItem(attachment, 1.6)
end

-- Publica el gesto en el personaje (ItemId, ItemStart, ItemEnd: client/ItemPoses lo anima en todos los clientes)
local function announce(character, id, duration)
	local start = workspace:GetServerTimeNow()
	character:SetAttribute("ItemId", id)
	character:SetAttribute("ItemStart", start)
	character:SetAttribute("ItemEnd", start + duration)
	task.delay(duration + 0.1, function()
		if character:GetAttribute("ItemStart") == start then
			character:SetAttribute("ItemId", nil)
			character:SetAttribute("ItemStart", nil)
			character:SetAttribute("ItemEnd", nil)
		end
	end)
end

-- Lanza el proyectil ya con el objeto fuera de la mano (se llama en el momento de soltarlo)
local function launch(player, id, direction)
	local cfg = I[id]
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 or PlayerState.get(player) ~= "Normal" or Items.count(player, id) <= 0 then
		return
	end
	local part, model = newProjectile(player, direction, id)
	if not part then
		return
	end
	Items.add(player, id, -1)
	throw(part, direction, cfg.ThrowSpeed)

	if id == "Grenade" then
		task.delay(cfg.Fuse, function()
			if part.Parent then
				local position = part.Position
				model:Destroy()
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
			model:Destroy()
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
				model:Destroy()
				placeFlare(position)
			end
		end)
	end
end

-- Usa un objeto lanzable o las vendas. `direction` = hacia dónde mira (lo manda el cliente).
-- Se saca el objeto en la mano (ItemModel.hold), los brazos hacen el gesto (client/ItemPoses) y en cfg.Anim.Release
-- sale de la mano: se lanza o se aplica. El gesto termina en cfg.Anim.End.
function Items.use(player, id, direction)
	local cfg = I[id]
	if typeof(id) ~= "string" or not cfg or id == "Medkit" then
		return
	end
	if PlayerState.get(player) ~= "Normal" or player:GetAttribute("Carrying") or Items.count(player, id) <= 0 then
		return
	end
	if os.clock() < (busyUntil[player] or 0) then
		return -- todavía está haciendo el gesto de otro objeto
	end
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local character = player.Character

	if id == "Bandage" then
		if humanoid.Health >= humanoid.MaxHealth then
			Remotes.Feed:FireClient(player, "Tienes la vida llena")
			return
		end
	else
		if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.1 or direction.Magnitude ~= direction.Magnitude then
			return
		end
		direction = direction.Unit
	end

	busyUntil[player] = os.clock() + cfg.Anim.End + I.Cooldown * 0.3
	local release, held = ItemModel.hold(player, id)
	announce(character, id, cfg.Anim.End)
	if id == "Grenade" then
		task.delay(cfg.Anim.End * 0.3, popPin, character) -- tira del pasador a mitad del gesto
	end

	if id == "Bandage" then
		Items.add(player, id, -1)
	end
	task.delay(cfg.Anim.Release, function()
		if id == "Flare" then
			flareFlash(held)
		end
		if release then
			release()
		end
		if id == "Bandage" then
			local current = getHumanoid(player)
			if current and current.Health > 0 and PlayerState.get(player) == "Normal" then
				current.Health = math.min(current.MaxHealth, current.Health + cfg.Heal * Difficulty.get().MedkitHeal)
				healSparkles(character)
			end
		else
			launch(player, id, direction)
		end
	end)
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
		busyUntil[player] = nil
	end)
end

return Items
