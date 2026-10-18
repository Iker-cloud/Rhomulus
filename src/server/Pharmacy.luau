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
local Items = require(script.Parent.Items)
local RateLimit = require(script.Parent.RateLimit)
local ItemModel = require(script.Parent.ItemModel)
local Points = require(script.Parent.Points)
local Stats = require(script.Parent.Stats)
local PropModel = require(script.Parent.PropModel)
local Vitrina = require(script.Parent.ZombieData.VitrinaMostrador)

local P = Config.Pharmacy
local FX = Config.Sounds.Fx

local Pharmacy = {}

local machines = {} -- [máquina] = true
local byKey = {} -- [número] = máquina (el panel PHIAL ROLL la pide por su clave)
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

-- Quita todo lo que dejó la Phial (atributos, vida máxima) y devuelve la velocidad normal
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

-- Animación de inyectarse -----------------------------------------------------------------------------------------------------------
-- La jeringa sale en la mano derecha, el brazo izquierdo se extiende, la aguja se clava en el antebrazo, el émbolo empuja el líquido (que
-- brilla del color del efecto) y al terminar la inyección el efecto empieza. Los brazos los mueve client/ItemPoses.Syringe en todos los
-- clientes (atributos del personaje ItemReady, ItemId, ItemStart y ItemEnd); aquí se mueve el émbolo y se ponen luces, chispas y sonido.

local function smoothstep(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function playAt(parent, key, volumeScale, speed)
	local def = FX[key]
	if not def or not parent then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = def[1]
	s.Volume = def[2] * (volumeScale or 1)
	s.PlaybackSpeed = (def[3] or 1) * (speed or 1)
	s.RollOffMaxDistance = 60
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 4)
end

-- Destellos del color del efecto sobre `parent`; `count` partículas de golpe. Devuelve el emisor (se puede dejar con Rate).
local function burst(parent, color, count, speed, lifetime)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.4
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Parent = parent
	if count > 0 then
		emitter:Emit(count)
	end
	Debris:AddItem(emitter, lifetime + 4)
	return emitter
end

local function inject(player, id)
	local def = P.Effects[id]
	local character = player.Character
	local humanoid = getHumanoid(player)
	local A = P.Anim
	if not (character and humanoid and humanoid.Health > 0 and player:HasAppearanceLoaded() and character:FindFirstChild("RightHand")) then
		Pharmacy.apply(player, id)
		return
	end
	Items.unequip(player, true) -- guarda lo que tenga en la mano
	local restore, model = ItemModel.hold(player, "Syringe", { color = def.Color })
	if not model then
		Pharmacy.apply(player, id)
		return
	end
	Items.lock(player, A.Duration + 0.3)
	player:SetAttribute("Injecting", true)
	character:SetAttribute("ItemReady", "Syringe") -- solo en el personaje: el inventario del jugador no conoce este objeto
	Items.announce(character, "Syringe", A.Duration)

	local forearm = character:FindFirstChild("LeftLowerArm") or character:FindFirstChild("LeftHand")
	local hand = character:FindFirstChild("LeftHand") or forearm
	local glow = Instance.new("PointLight")
	glow.Color = def.Color
	glow.Range = 6
	glow.Brightness = 0
	glow.Parent = hand
	local veins -- destellos continuos mientras el líquido entra
	local pricked, pushing, applied = false, false, false

	local start = os.clock()
	while true do
		local t = (os.clock() - start) / A.Duration
		if t >= 1 or not character.Parent or humanoid.Health <= 0 or PlayerState.get(player) ~= "Normal" then
			break
		end
		ItemModel.setSyringe(model, smoothstep((t - A.PushStart) / (A.PushEnd - A.PushStart)))
		if not pricked and t >= A.Prick then
			pricked = true
			playAt(hand, "Select", 1.2, 1.8)
			burst(forearm, Color3.fromRGB(255, 70, 70), 4, 4, 0.5) -- una gotita de sangre
		end
		if not pushing and t >= A.PushStart then
			pushing = true
			veins = burst(forearm, def.Color, 0, 3, 0.9)
			veins.Rate = 14
			playAt(hand, "Buy", 0.5, 1.4)
		end
		if pushing and t < A.PushEnd + 0.1 then
			local k = math.sin(math.clamp((t - A.PushStart) / (A.PushEnd - A.PushStart), 0, 1) * math.pi)
			glow.Brightness = 0.7 * k
		end
		if not applied and t >= A.Apply then
			applied = true
			if veins then
				veins.Rate = 0
			end
			glow.Brightness = 0
			Pharmacy.apply(player, id)
			local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
			burst(torso, def.Color, 12, 6, 1.0)
			playAt(torso, "Revived", 0.7, 1.15)
		end
		task.wait()
	end
	if veins then
		veins.Rate = 0
	end
	glow:Destroy()
	restore()
	if character.Parent then
		character:SetAttribute("ItemReady", nil)
	end
	player:SetAttribute("Injecting", nil)
end

-- Fin de partida o de ronda: nadie conserva efectos
function Pharmacy.resetEffects()
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("FxId") then
			clearEffect(player)
		end
		player:SetAttribute("PhialId", nil)
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
	machine.prompt.ActionText = "Phial Roll"
	machine.prompt.ObjectText = `Farmacia · {Difficulty.price(P.Cost)} latas`
	machine.prompt.HoldDuration = 0.25
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

-- El jugador que compra ve el panel PHIAL ROLL (client/PhialRoll): aquí se le manda cómo avanza la vitrina (Remotes.PhialUi):
--   "open" (clave, posición, precio, estado)   "spin" (clave, efecto, segundos)   "ready" (clave, efecto, segundos para tomarla)
--   "lost" (clave)   "taken" (clave, quién)   "denied" (texto)
-- y él pide "roll" (cobra y gira) o "take" (inyectarse la Phial que salió).
local function notify(player, ...)
	if player and player.Parent then
		Remotes.PhialUi:FireClient(player, ...)
	end
end

local function nearMachine(machine, player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - machine.base.Position).Magnitude <= 22
end

local function startRoll(machine, player)
	if not machines[machine] or PlayerState.get(player) ~= "Normal" or not nearMachine(machine, player) then
		return
	end
	if machine.state ~= "idle" then
		notify(player, "denied", machine.state == "cooldown" and "REPONIENDO…" or "OCUPADA")
		return
	end
	local price = Difficulty.price(P.Cost)
	if not Points.spend(price) then
		Remotes.Feed:FireClient(player, `Faltan latas: la Phial cuesta {price}`)
		notify(player, "denied", "FALTAN LATAS")
		return
	end
	machine.state = "spinning"
	machine.uses += 1
	machine.rollId += 1
	machine.roller = player
	local id = machine.rollId
	machine.prompt.Enabled = false
	Points.feed(`{player.DisplayName} compró una Phial`)

	-- La ruleta gira unos segundos y se detiene en un efecto al azar (el panel del comprador gira igual)
	local pick = weightedPick()
	notify(player, "spin", machine.key, pick, P.SpinTime)
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
	setLabel(machine, `PHIAL {def.Upper}: {def.Desc}`, def.Color)
	sound(machine, "Revived", 0.9)
	machine.prompt.ActionText = `Inyectar Phial: {def.Name}`
	machine.prompt.ObjectText = `{def.Desc} · luego {def.CrashDesc}`
	machine.prompt.HoldDuration = 0
	machine.prompt.Enabled = true
	Points.feed(`Salió la Phial {def.Name}`)
	notify(player, "ready", machine.key, pick, P.TakeTime)

	-- Si nadie la toma a tiempo, se pierde
	task.delay(P.TakeTime, function()
		if machines[machine] and machine.state == "ready" and machine.rollId == id then
			notify(machine.roller, "lost", machine.key)
			cooldown(machine)
		end
	end)
end

local function takePhial(machine, player)
	if not machines[machine] or machine.state ~= "ready" or PlayerState.get(player) ~= "Normal" then
		return
	end
	if player:GetAttribute("Injecting") or player:GetAttribute("HealingEnd") or player:GetAttribute("ItemId") then
		Remotes.Feed:FireClient(player, "Termina lo que estás haciendo antes de inyectarte")
		return
	end
	if player:GetAttribute("PhialId") then
		Remotes.Feed:FireClient(player, "Ya llevas una Phial: úsala con Z o tocando su panel")
		notify(player, "denied", "YA LLEVAS UNA PHIAL")
		return
	end
	-- La Phial no se inyecta al tomarla: se guarda en el panel de la izquierda (atributo PhialId) y se usa cuando se quiera
	local pick = machine.pick
	machine.rollId += 1
	cooldown(machine)
	sound(machine, "Buy", 0.8)
	player:SetAttribute("PhialId", pick)
	Points.feed(`{player.DisplayName} guardó la Phial {P.Effects[pick].Name}`)
	notify(machine.roller, "taken", machine.key, player.DisplayName)
end

-- Usa la Phial guardada (tecla Z o tocar su panel)
local function useStored(player)
	local id = player:GetAttribute("PhialId")
	if not id or not P.Effects[id] or PlayerState.get(player) ~= "Normal" then
		return
	end
	if player:GetAttribute("Injecting") or player:GetAttribute("HealingEnd") or player:GetAttribute("ItemId") then
		Remotes.Feed:FireClient(player, "Termina lo que estás haciendo antes de inyectarte")
		return
	end
	player:SetAttribute("PhialId", nil)
	Stats.add(player, "Phials")
	Points.feed(`{player.DisplayName} se inyectó la Phial {P.Effects[id].Name}`)
	task.spawn(inject, player, id)
end

local function onTriggered(machine, player)
	if not machines[machine] or PlayerState.get(player) ~= "Normal" then
		return
	end
	if machine.state == "idle" then
		-- Con la vitrina libre, E abre el panel PHIAL ROLL (el cobro lo pide el botón ROLL)
		notify(player, "open", machine.key, machine.base.Position, Difficulty.price(P.Cost), machine.state)
	elseif machine.state == "ready" then
		takePhial(machine, player)
	end
end

-- El modelo de la vitrina trae sus piezas en blanco (PropModel no usa las texturas del .glb): aquí se pintan. Los vidrios se vuelven
-- transparentes para que se vean las jeringas, el mostrador y el rótulo toman color y el rótulo dice FARMACIA.
local COUNTER_GREEN = Color3.fromRGB(44, 112, 92)
local COUNTER_CREAM = Color3.fromRGB(238, 232, 214)
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

local function boardGui(part, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.2
	gui.Parent = part
	return gui
end

local function dress(model)
	for _, piece in model:GetChildren() do
		local name = piece.Name
		if not piece:IsA("BasePart") then
			continue
		end
		if name:sub(1, 6) == "vidrio" then
			piece.Material = Enum.Material.Glass
			piece.Color = Color3.fromRGB(190, 225, 235)
			piece.Transparency = 0.8
			piece.CanQuery = false
		elseif name == "impacto_vidrio" then
			piece.Transparency = 1
		elseif name == "base" then
			piece.Color = COUNTER_GREEN
		elseif name == "base_frente" then
			piece.Color = COUNTER_GREEN
			local gui = boardGui(piece, Enum.NormalId.Back) -- el frente del modelo mira a -Z y las piezas vienen giradas 180°
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 0.4)
			label.Position = UDim2.fromScale(0, 0.3)
			label.FontFace = OSWALD
			label.TextScaled = true
			label.TextColor3 = COUNTER_CREAM
			label.Text = "FARMACIA · DOÑA ROSA"
			label.Parent = gui
		elseif name:sub(1, 15) == "etiqueta_precio" then
			piece.Color = COUNTER_CREAM
		elseif name == "rotulo" then
			piece.Color = COUNTER_CREAM
			local gui = boardGui(piece, Enum.NormalId.Back)
			local cross = Instance.new("Frame")
			cross.BackgroundColor3 = COUNTER_GREEN
			cross.BorderSizePixel = 0
			cross.AnchorPoint = Vector2.new(0.5, 0.5)
			cross.Position = UDim2.fromScale(0.09, 0.5)
			cross.Size = UDim2.fromScale(0.09, 0.17)
			cross.Parent = gui
			local cross2 = cross:Clone()
			cross2.Size = UDim2.fromScale(0.03, 0.5)
			cross2.Parent = gui
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(0.78, 0.8)
			label.Position = UDim2.fromScale(0.19, 0.1)
			label.FontFace = OSWALD
			label.TextScaled = true
			label.TextColor3 = COUNTER_GREEN
			label.Text = "FARMACIA"
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Parent = gui
		end
	end
end

local function build(position, yaw)
	local model, base = PropModel.build(Vitrina, position, yaw)
	dress(model)
	model.Name = "Farmacia"
	base.Name = "Base"

	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 1.1
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
	table.clear(byKey)
end

-- Pone una vitrina en cada lugar de `spots` (las Tiendas del mapa: { posición, giro en grados }); sin lista, Config.Pharmacy.Spots
function Pharmacy.place(spots)
	Pharmacy.clear()
	for index, spot in spots or P.Spots do
		local machine = build(spot[1], math.rad(spot[2]))
		machine.key = index
		byKey[index] = machine
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
	-- El panel PHIAL ROLL pide girar ("roll") o inyectarse la Phial que salió ("take")
	Remotes.PhialUi.OnServerEvent:Connect(function(player, action, key)
		if not RateLimit.check(player, "PhialUi", 0.3) then
			return
		end
		if action == "use" then
			useStored(player)
			return
		end
		if typeof(key) ~= "number" then
			return
		end
		local machine = byKey[key]
		if not machine or not machines[machine] or not nearMachine(machine, player) then
			return
		end
		if action == "roll" then
			startRoll(machine, player)
		elseif action == "take" then
			takePhial(machine, player)
		end
	end)
	-- Caer o morir hace perder el efecto
	PlayerState.Changed.Event:Connect(function(player, state)
		if state ~= "Normal" and player:GetAttribute("FxId") then
			clearEffect(player)
		end
		if state == "Dead" then
			player:SetAttribute("PhialId", nil) -- la Phial guardada se pierde al morir
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		baseMaxHealth[player] = nil
	end)
end

return Pharmacy
