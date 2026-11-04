-- Caja de armas (una por zona, o una por ruta en el mapa nuevo, en un lugar al azar) y estaciones de munición.
-- La caja cuesta latas del equipo; las armas giran unos segundos y se detiene en una al azar.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)
local Points = require(script.Parent.Points)
local PropModel = require(script.Parent.PropModel)
local Weapons = require(script.Parent.Weapons)
local Items = require(script.Parent.Items)
local Difficulty = require(script.Parent.Difficulty)
local RateLimit = require(script.Parent.RateLimit)
local CajaMisteriosa = require(script.Parent.ZombieData.CajaMisteriosa)
local WeaponModel = require(script.Parent.WeaponModel)
local RifleAsalto = require(script.Parent.ZombieData.RifleAsalto)
local Escopeta = require(script.Parent.ZombieData.Escopeta)
local Subfusil = require(script.Parent.ZombieData.Subfusil)

local WeaponBox = {}

local boxSpots = {} -- [zona] = { Vector3, ... } candidatos que calcula MapBuilder (o una lista por ruta: { { Vector3, ... }, ... })
local active = {} -- cajas en el mapa: [caja] = true. Cada caja: { model, prompt, display, state, rollId, pick, connection }

-- Modelo 3D de cada arma de la caja. Si alguna no tiene modelo, sale como un cubo de luz.
local WEAPON_MODELS = {
	Rifle = RifleAsalto,
	Shotgun = Escopeta,
	SMG = Subfusil,
}
local DISPLAY_SCALE = 1.5 -- el arma sale más grande que en la mano para que se vea desde lejos
local RISE_TIME = 0.6 -- segundos que tarda el arma en salir de la caja
local HEIGHT_START, HEIGHT_END = 0.6, 3.8 -- altura sobre la base: dentro de la caja -> flotando encima

local RARITY_COLOR = {
	["Common"] = Color3.fromRGB(220, 220, 220),
	["Rare"] = Color3.fromRGB(90, 170, 255),
	["Epic"] = Color3.fromRGB(190, 90, 255),
}

local function rollWeapon()
	local total = 0
	for _, cfg in Config.WeaponBox.Pool do
		total += Config.Weapons[cfg].Weight
	end
	local roll = math.random() * total
	for _, name in Config.WeaponBox.Pool do
		roll -= Config.Weapons[name].Weight
		if roll <= 0 then
			return name
		end
	end
	return Config.WeaponBox.Pool[1]
end

-- La placa sobre la caja la dibuja el cliente (Plates.luau) a partir de estos atributos
local function setLabel(box, text, color)
	box.base:SetAttribute("PlateText", text)
	box.base:SetAttribute("PlateColor", color or Color3.fromRGB(245, 200, 70))
end

-- Muestra el arma `name` sobre la caja (el modelo 3D, o el cubo de luz si no tiene) con la luz de su rareza
local function hideWeapon(box)
	if box.shown == box.display then
		box.display.Transparency = 1
	elseif box.shown then
		box.shown.Parent = nil
	end
	box.shown = nil
end

local placeWeapon -- se define más abajo

local function showWeapon(box, name)
	hideWeapon(box)
	local color = RARITY_COLOR[Config.Weapons[name].Rarity]
	box.display.Color = color
	box.light.Color = color
	local weaponModel = box.models[name]
	if weaponModel then
		weaponModel.Parent = box.model
		box.shown = weaponModel
	else
		box.display.Transparency = 0
		box.shown = box.display
	end
	placeWeapon(box, 0) -- que aparezca ya en su sitio, sin esperar al siguiente cuadro
end

-- Coloca el arma que se muestra: sale de la caja, gira y flota
function placeWeapon(box, dt)
	local shown = box.shown
	if not shown then
		return
	end
	local elapsed = os.clock() - box.openedAt
	local rise = 1 - (1 - math.clamp(elapsed / RISE_TIME, 0, 1)) ^ 3 -- sale rápido y frena
	local height = HEIGHT_START + (HEIGHT_END - HEIGHT_START) * rise
	if box.state == "ready" then
		height += math.sin(os.clock() * 2) * 0.2
	end
	box.angle += dt * (box.state == "spinning" and 7 or 1.6)
	local cframe = box.base.CFrame * CFrame.new(0, height, 0) * CFrame.Angles(0, box.angle, 0)
	if shown:IsA("Model") then
		shown:PivotTo(cframe)
	else
		shown.CFrame = cframe
	end
end

local function resetToIdle(box)
	box.state = "idle"
	box.pick = nil
	box.model:SetAttribute("Open", false)
	hideWeapon(box)
	box.prompt.ActionText = "Buy weapon box"
	box.prompt.ObjectText = `{Difficulty.price(Config.WeaponBox.Cost)} cans`
	box.prompt.HoldDuration = 0.5
	box.prompt.Enabled = true
	setLabel(box, "Weapon box")
end

local function build(spot)
	-- La caja misteriosa (modelo de caja-misteriosa.glb). El Hitbox invisible hace de base: colisión, prompt y placa.
	-- `spot` es un Vector3 (mira al sur) o un CFrame (posición y giro; las Tiendas la ponen mirando a la entrada)
	local position, yaw = spot, 0
	if typeof(spot) == "CFrame" then
		position = spot.Position
		local _, spotYaw = spot:ToOrientation()
		yaw = spotYaw
	end
	local model, base = PropModel.build(CajaMisteriosa, position, yaw)
	model.Name = "WeaponBox"
	base.Name = "Base"

	local display = Instance.new("Part")
	display.Name = "Display"
	display.Size = Vector3.new(1.4, 1.4, 1.4)
	display.Anchored = true
	display.CanCollide = false
	display.Material = Enum.Material.Neon
	display.Transparency = 1
	display.CFrame = base.CFrame * CFrame.new(0, HEIGHT_END, 0)
	display.Parent = model

	-- Luz del color de la rareza sobre la caja
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 2
	light.Parent = display

	-- Modelos 3D de las armas, listos (fuera del mundo) hasta que se necesiten
	local models = {}
	for name, data in WEAPON_MODELS do
		models[name] = WeaponModel.build(data, DISPLAY_SCALE)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom -- la interfaz la dibuja PromptUi.luau
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	base:SetAttribute("PlateRange", 18)
	base:SetAttribute("PlateHeight", 4.2)
	CollectionService:AddTag(base, "Plate")

	model.Parent = workspace.Map
	return { model = model, base = base, display = display, light = light, models = models, angle = 0, openedAt = 0, state = "idle", prompt = prompt, rollId = 0 }
end

local function onTriggered(box, player)
	if not active[box] or PlayerState.get(player) ~= "Normal" then
		return
	end

	if box.state == "idle" then
		if not Points.spend(Difficulty.price(Config.WeaponBox.Cost)) then
			Remotes.Feed:FireClient(player, `Not enough cans: the box costs {Difficulty.price(Config.WeaponBox.Cost)}`)
			return
		end

		box.state = "spinning"
		box.model:SetAttribute("Open", true)
		box.rollId += 1
		local id = box.rollId
		box.prompt.Enabled = false
		Points.feed(`{player.DisplayName} opened the weapon box`)

		-- Las armas giran unos segundos y se detiene en una al azar
		local pick = rollWeapon()
		box.openedAt = os.clock()
		local music = Instance.new("Sound")
		music.SoundId = Config.Sounds.BoxSpin
		music.Volume = Config.Sounds.Volume.Box
		music.RollOffMaxDistance = 80
		music.Parent = box.base
		music:Play()
		local pool = Config.WeaponBox.Pool
		local steps = math.floor(Config.WeaponBox.SpinTime / 0.1)
		for i = 1, steps do
			if not active[box] then
				return
			end
			local name = pool[math.random(#pool)]
			setLabel(box, Config.Weapons[name].Name, RARITY_COLOR[Config.Weapons[name].Rarity])
			showWeapon(box, name)
			task.wait(0.1)
		end
		music:Destroy()
		if not active[box] then
			return
		end

		local cfg = Config.Weapons[pick]
		box.state = "ready"
		box.pick = pick
		showWeapon(box, pick)
		setLabel(box, `{cfg.Name} ({cfg.Rarity})`, RARITY_COLOR[cfg.Rarity])
		box.prompt.ActionText = `Take {cfg.Name}`
		box.prompt.ObjectText = cfg.Rarity
		box.prompt.HoldDuration = 0
		box.prompt.Enabled = true
		Points.feed(`The box gave: {cfg.Name} ({cfg.Rarity})`)

		-- Si nadie la toma a tiempo, se pierde
		task.delay(Config.WeaponBox.TakeTime, function()
			if active[box] and box.state == "ready" and box.rollId == id then
				resetToIdle(box)
			end
		end)
	elseif box.state == "ready" then
		local pick = box.pick
		resetToIdle(box)
		Weapons.givePrimary(player, pick)
		Points.feed(`{player.DisplayName} took {Config.Weapons[pick].Name}`)
	end
end

-- Quita las cajas (cambio de zona o fin de partida)
function WeaponBox.clear()
	for box in active do
		box.connection:Disconnect()
		box.model:Destroy()
	end
	table.clear(active)
end

-- Pone una caja en uno de los lugares de la lista, al azar
local function spawnBox(spots)
	local box = build(spots[math.random(#spots)])
	resetToIdle(box)
	box.prompt.Triggered:Connect(function(player)
		onTriggered(box, player)
	end)

	-- Gira mientras la caja existe
	box.connection = RunService.Heartbeat:Connect(function(dt)
		if box.state ~= "idle" then
			placeWeapon(box, dt)
		end
	end)
	active[box] = true
end

-- Coloca las cajas de la zona: una lista de lugares = una caja; una lista de listas = una caja por ruta
function WeaponBox.place(zoneName)
	WeaponBox.clear()
	local spots = boxSpots[zoneName]
	if not spots or #spots == 0 then
		return
	end
	local groups = typeof(spots[1]) == "Vector3" and { spots } or spots
	for _, group in groups do
		if #group > 0 then
			spawnBox(group)
		end
	end
end

local stations = {}
local buyConnected = false

-- Compra en una estación ("Ammo" o un objeto de Config.Items): se valida que el jugador esté cerca de alguna
local function onBuy(player, id)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or typeof(id) ~= "string" then
		return
	end
	local station
	for _, s in stations do
		if s.part.Parent and (s.part.Position - root.Position).Magnitude <= 18 then
			station = s
			break
		end
	end
	if not station then
		return
	end
	if id == "Ammo" then
		local denied = Weapons.ammoDenied(player)
		if denied then
			Remotes.Feed:FireClient(player, denied)
		elseif Points.spend(Difficulty.price(Config.WeaponBox.AmmoCost)) then
			Weapons.refillReserve(player)
			station.model:SetAttribute("Open", true)
			task.delay(1.6, function()
				station.model:SetAttribute("Open", false)
			end)
			Points.feed(`{player.DisplayName} bought ammo`)
		else
			Remotes.Feed:FireClient(player, `Not enough cans: ammo costs {Difficulty.price(Config.WeaponBox.AmmoCost)}`)
		end
		return
	end
	local ok, message = Items.tryBuy(player, id)
	if not ok then
		Remotes.Feed:FireClient(player, message)
	end
end

-- refs viene de MapBuilder (candidatos de la caja y estaciones de munición)
function WeaponBox.init(refs)
	boxSpots = refs.boxSpots

	stations = refs.ammoStations
	if not buyConnected then
		buyConnected = true
		Remotes.Buy.OnServerEvent:Connect(RateLimit.wrap("Buy", 0.25, onBuy))
	end
	for _, station in refs.ammoStations do
		station.prompt.ActionText = "Supplies"
		station.prompt.ObjectText = "Ammo and items"
		station.prompt.Enabled = true
		station.prompt.Triggered:Connect(function(player)
			Remotes.OpenShop:FireClient(player, station.part.Position)
		end)
	end
end

return WeaponBox
