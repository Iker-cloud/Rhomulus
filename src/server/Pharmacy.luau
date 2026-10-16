-- Farmacia de Doña Rosa: vitrinas con jeringas repartidas por el mapa (Config.Pharmacy.Spots). Se paga con latas del equipo y una
-- ruleta de jeringas gira sobre la vitrina (como la caja de armas) hasta detenerse en un efecto al azar; quien la toma se la inyecta.
-- Efectos temporales con "bajón": durante Duration segundos mejora algo (daño, velocidad, vida o recarga) y luego, otros CrashDuration,
-- queda un efecto malo. Solo hay uno activo por jugador (el nuevo reemplaza al anterior) y se pierde al caer o morir.
-- El efecto vive en atributos del jugador: FxId, FxPhase ("active" o "crash") y FxEnd (hora del servidor) para el HUD, y FxDamage, FxSpeed y
-- FxReload (multiplicadores que leen Weapons y PlayerState). La vida máxima se cambia directamente en el Humanoid.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Difficulty = require(script.Parent.Difficulty)
local PlayerState = require(script.Parent.PlayerState)
local Points = require(script.Parent.Points)
local PropModel = require(script.Parent.PropModel)
local Vitrina = require(script.Parent.ZombieData.VitrinaMostrador)

local P = Config.Pharmacy
local FX = Config.Sounds.Fx

local Pharmacy = {}

local machines = {} -- [máquina] = true
local sessions = {} -- [Player] = número: invalida los temporizadores de un efecto anterior
local baseMaxHealth = {} -- [Player] = vida máxima antes de inyectarse (para devolverla)

local ATTRIBUTES = { Damage = "FxDamage", Speed = "FxSpeed", Reload = "FxReload", Defense = "FxDefense", Stealth = "FxStealth", Regen = "FxRegen", Vision = "FxVision" }
local DISPLAY_SCALE = 1.9 -- la jeringa de la ruleta sale más grande que en la vitrina
local HEIGHT = 10.6 -- altura sobre la base donde flota (por encima de la vitrina)

-- Efectos ----------------------------------------------------------------------------------------------------------------------------

local function getHumanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Quita todo lo que dejó la jeringa (atributos, vida máxima) y devuelve la velocidad normal
local function clearEffect(player)
	sessions[player] = (sessions[player] or 0) + 1
	for _, attribute in ATTRIBUTES do
		player:SetAttribute(attribute, nil)
	end
	player:SetAttribute("FxId", nil)
	player:SetAttribute("FxPhase", nil)
	player:SetAttribute("FxEnd", nil)
	local base = baseMaxHealth[player]
	baseMaxHealth[player] = nil
	local humanoid = getHumanoid(player)
	if base and humanoid then
		humanoid.MaxHealth = base
		humanoid.Health = math.min(humanoid.Health, base)
	end
	PlayerState.refreshSpeed(player)
end

-- Pone los multiplicadores de `mods` (los que no estén, se quitan)
local function setMods(player, mods)
	for key, attribute in ATTRIBUTES do
		player:SetAttribute(attribute, mods[key])
	end
	PlayerState.refreshSpeed(player)
end

function Pharmacy.apply(player, id)
	local def = P.Effects[id]
	if not def then
		return
	end
	clearEffect(player)
	local session = sessions[player]
	local humanoid = getHumanoid(player)

	setMods(player, def.Mods)
	if def.Mods.MaxHealth and humanoid then
		baseMaxHealth[player] = humanoid.MaxHealth
		humanoid.MaxHealth += def.Mods.MaxHealth
		humanoid.Health = math.clamp(humanoid.Health + def.Mods.MaxHealth, 1, humanoid.MaxHealth)
	end
	local now = workspace:GetServerTimeNow()
	player:SetAttribute("FxId", id)
	player:SetAttribute("FxPhase", "active")
	player:SetAttribute("FxEnd", now + P.Duration)

	-- Al acabar el efecto viene el bajón, y después todo vuelve a la normalidad
	task.delay(P.Duration, function()
		if sessions[player] ~= session then
			return
		end
		local current = getHumanoid(player)
		local base = baseMaxHealth[player]
		if base and current then
			current.MaxHealth = base
			current.Health = math.min(current.Health, base)
			baseMaxHealth[player] = nil
		end
		setMods(player, def.Crash)
		player:SetAttribute("FxPhase", "crash")
		player:SetAttribute("FxEnd", workspace:GetServerTimeNow() + P.CrashDuration)
		task.delay(P.CrashDuration, function()
			if sessions[player] == session then
				clearEffect(player)
			end
		end)
	end)
end

-- Regeneración / sangrado de la jeringa: cada segundo suma FxRegen de vida (sin bajar de 1 ni pasar del máximo)
local function regenLoop()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local regen = player:GetAttribute("FxRegen")
			local humanoid = regen and getHumanoid(player)
			if humanoid and humanoid.Health > 0 and PlayerState.get(player) == "Normal" then
				humanoid.Health = math.clamp(humanoid.Health + regen, 1, humanoid.MaxHealth)
			end
		end
	end
end

-- Fin de partida o de ronda: nadie conserva efectos
function Pharmacy.resetEffects()
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("FxId") then
			clearEffect(player)
		end
	end
end

-- La jeringa de la ruleta ---------------------------------------------------------------------------------------------------------

-- Una jeringa suelta construida con las piezas de una jeringa del propio modelo de la vitrina (jeringa_0_0_*), con el líquido del color
-- del efecto. Queda de pie (la aguja hacia abajo) y su pivote es el centro del cuerpo.
local function buildSyringe(color)
	local pieces = {}
	local body
	for _, piece in Vitrina.parts do
		if piece.name:sub(1, 11) == "jeringa_0_0" then
			table.insert(pieces, piece)
			if piece.name:sub(-6) == "cuerpo" then
				body = piece
			end
		end
	end
	if not body then
		return nil
	end
	-- El eje largo del cuerpo (en el mundo del modelo) hay que ponerlo vertical
	local size = body.size
	local axisLocal = Vector3.xAxis
	if size.Y >= size.X and size.Y >= size.Z then
		axisLocal = Vector3.yAxis
	elseif size.Z >= size.X and size.Z >= size.Y then
		axisLocal = Vector3.zAxis
	end
	local axis = body.cf:VectorToWorldSpace(axisLocal).Unit
	local target = Vector3.yAxis
	local cross = axis:Cross(target)
	local upright = CFrame.identity
	if cross.Magnitude > 1e-4 then
		upright = CFrame.fromAxisAngle(cross.Unit, math.acos(math.clamp(axis:Dot(target), -1, 1)))
	elseif axis:Dot(target) < 0 then
		upright = CFrame.Angles(math.pi, 0, 0)
	end

	local model = Instance.new("Model")
	model.Name = "JeringaRuleta"
	local center = body.cf.Position
	for _, piece in pieces do
		local part = Instance.new("Part")
		part.Name = piece.name:sub(13)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Size = piece.size * DISPLAY_SCALE
		local offset = (piece.cf.Position - center) * DISPLAY_SCALE
		part.CFrame = upright * CFrame.new(offset) * (piece.cf - piece.cf.Position)
		part.Color = piece.name:sub(-7) == "liquido" and color or piece.color
		if piece.name:sub(-7) == "liquido" then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = color
			sparkles.Parent = part
		end
		part.Material = piece.name:sub(-7) == "liquido" and Enum.Material.Neon or Enum.Material.SmoothPlastic
		if piece.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		elseif piece.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		end
		part.Parent = model
		if piece == body then
			model.PrimaryPart = part
		end
	end
	return model
end

-- Máquina ----------------------------------------------------------------------------------------------------------------------------

local function setLabel(machine, text, color)
	machine.base:SetAttribute("PlateText", text)
	machine.base:SetAttribute("PlateColor", color or Color3.fromRGB(245, 200, 70))
end

local function sound(machine, key, volumeScale)
	local def = FX[key]
	if not def then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = def[1]
	s.Volume = def[2] * (volumeScale or 1)
	s.PlaybackSpeed = def[3] or 1
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = 90
	s.Parent = machine.base
	s:Play()
	Debris:AddItem(s, 4)
end

-- Un efecto al azar según el peso de cada uno (Weight, 1 por defecto)
local function weightedPick()
	local total = 0
	for _, id in P.Order do
		total += P.Effects[id].Weight or 1
	end
	local roll = math.random() * total
	for _, id in P.Order do
		roll -= P.Effects[id].Weight or 1
		if roll <= 0 then
			return id
		end
	end
	return P.Order[1]
end

local function hideSyringe(machine)
	if machine.shown then
		machine.shown.Parent = nil
		machine.shown = nil
	end
end

local function showSyringe(machine, id)
	hideSyringe(machine)
	local def = P.Effects[id]
	machine.light.Color = def.Color
	machine.light.Enabled = true
	machine.shown = machine.syringes[id]
	machine.shown.Parent = machine.model
end

local function placeSyringe(machine, dt)
	local shown = machine.shown
	if not shown then
		return
	end
	machine.angle += dt * (machine.state == "spinning" and 8 or 1.8)
	local height = HEIGHT
	if machine.state == "ready" then
		height += math.sin(os.clock() * 2) * 0.25
	end
	shown:PivotTo(machine.base.CFrame * CFrame.new(0, height - machine.base.Size.Y / 2, 0) * CFrame.Angles(0, machine.angle, 0))
end

local function resetToIdle(machine)
	machine.state = "idle"
	machine.pick = nil
	hideSyringe(machine)
	machine.light.Enabled = false
	if machine.uses >= P.MaxUses then
		machine.prompt.Enabled = false
		setLabel(machine, "Agotada", Color3.fromRGB(150, 146, 140))
		return
	end
	machine.prompt.ActionText = "Probar suerte"
	machine.prompt.ObjectText = `Farmacia · {Difficulty.price(P.Cost)} latas`
	machine.prompt.HoldDuration = 0.5
	machine.prompt.Enabled = true
	setLabel(machine, "Farmacia")
end

-- Tras tomar o perder la jeringa, la vitrina se repone unos segundos
local function cooldown(machine)
	machine.state = "cooldown"
	hideSyringe(machine)
	machine.light.Enabled = false
	machine.prompt.Enabled = false
	setLabel(machine, "Reponiendo…", Color3.fromRGB(150, 146, 140))
	local id = machine.rollId
	task.delay(P.Cooldown, function()
		if machines[machine] and machine.rollId == id then
			resetToIdle(machine)
		end
	end)
end

local function onTriggered(machine, player)
	if not machines[machine] or PlayerState.get(player) ~= "Normal" then
		return
	end

	if machine.state == "idle" then
		local price = Difficulty.price(P.Cost)
		if not Points.spend(price) then
			Remotes.Feed:FireClient(player, `Faltan latas: la jeringa cuesta {price}`)
			return
		end
		machine.state = "spinning"
		machine.uses += 1
		machine.rollId += 1
		local id = machine.rollId
		machine.prompt.Enabled = false
		Points.feed(`{player.DisplayName} probó suerte en la farmacia`)

		-- La ruleta gira unos segundos y se detiene en un efecto al azar
		local pick = weightedPick()
		local steps = math.floor(P.SpinTime / 0.12)
		local last
		for i = 1, steps do
			if not machines[machine] or machine.rollId ~= id then
				return
			end
			-- Cada paso enseña un efecto distinto al anterior
			local choice
			repeat
				choice = P.Order[math.random(#P.Order)]
			until choice ~= last
			last = choice
			setLabel(machine, P.Effects[choice].Upper, P.Effects[choice].Color)
			showSyringe(machine, choice)
			sound(machine, "Select", 0.6)
			task.wait(0.12)
		end
		if not machines[machine] or machine.rollId ~= id then
			return
		end

		local def = P.Effects[pick]
		machine.state = "ready"
		machine.pick = pick
		showSyringe(machine, pick)
		setLabel(machine, `{def.Upper}: {def.Desc}`, def.Color)
		sound(machine, "Revived", 0.9)
		machine.prompt.ActionText = `Inyectarse {def.Name}`
		machine.prompt.ObjectText = `{def.Desc} · luego {def.CrashDesc}`
		machine.prompt.HoldDuration = 0
		machine.prompt.Enabled = true
		Points.feed(`La farmacia sacó: {def.Name}`)

		-- Si nadie la toma a tiempo, se pierde
		task.delay(P.TakeTime, function()
			if machines[machine] and machine.state == "ready" and machine.rollId == id then
				cooldown(machine)
			end
		end)
	elseif machine.state == "ready" then
		local pick = machine.pick
		machine.rollId += 1
		cooldown(machine)
		Pharmacy.apply(player, pick)
		sound(machine, "Buy", 0.8)
		Points.feed(`{player.DisplayName} se inyectó {P.Effects[pick].Name}`)
	end
end

local function build(position, yaw)
	local model, base = PropModel.build(Vitrina, position, yaw)
	model.Name = "Farmacia"
	base.Name = "Base"

	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 2.5
	light.Enabled = false
	light.Parent = base

	-- Una jeringa lista por cada efecto (fuera del mundo hasta que se muestra)
	local syringes = {}
	for _, id in P.Order do
		syringes[id] = buildSyringe(P.Effects[id].Color)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom -- la interfaz la dibuja PromptUi.luau
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	base:SetAttribute("PlateRange", 20)
	base:SetAttribute("PlateHeight", Vitrina.maxY + 1.5)
	CollectionService:AddTag(base, "Plate")

	model.Parent = workspace:FindFirstChild("Map") or workspace
	return { model = model, base = base, light = light, syringes = syringes, angle = 0, state = "idle", prompt = prompt, rollId = 0, uses = 0 }
end

-- Quita las máquinas (fin de ronda o cambio de mapa)
function Pharmacy.clear()
	for machine in machines do
		machine.connection:Disconnect()
		machine.model:Destroy()
	end
	table.clear(machines)
end

-- Pone una vitrina en cada lugar de Config.Pharmacy.Spots
function Pharmacy.place()
	Pharmacy.clear()
	for _, spot in P.Spots do
		local machine = build(spot[1], math.rad(spot[2]))
		resetToIdle(machine)
		machine.prompt.Triggered:Connect(function(player)
			onTriggered(machine, player)
		end)
		machine.connection = RunService.Heartbeat:Connect(function(dt)
			if machine.state == "spinning" or machine.state == "ready" then
				placeSyringe(machine, dt)
			end
		end)
		machines[machine] = true
	end
end

function Pharmacy.start()
	task.spawn(regenLoop)
	-- Caer o morir hace perder el efecto
	PlayerState.Changed.Event:Connect(function(player, state)
		if state ~= "Normal" and player:GetAttribute("FxId") then
			clearEffect(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		baseMaxHealth[player] = nil
	end)
end

return Pharmacy
