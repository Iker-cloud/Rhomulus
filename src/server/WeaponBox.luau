-- Caja de armas (una por zona, en un lugar al azar de la zona) y estaciones de munición.
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
local CajaMisteriosa = require(script.Parent.ZombieData.CajaMisteriosa)

local WeaponBox = {}

local boxSpots = {} -- [zona] = { Vector3, ... } candidatos que calcula MapBuilder
local current = nil -- caja activa: { model, prompt, label, display, state, rollId, pick, connection }

local RARITY_COLOR = {
	["Común"] = Color3.fromRGB(220, 220, 220),
	["Rara"] = Color3.fromRGB(90, 170, 255),
	["Épica"] = Color3.fromRGB(190, 90, 255),
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

local function resetToIdle(box)
	box.state = "idle"
	box.pick = nil
	box.model:SetAttribute("Open", false)
	box.display.Transparency = 1
	box.prompt.ActionText = "Comprar caja de armas"
	box.prompt.ObjectText = `{Config.WeaponBox.Cost} latas`
	box.prompt.HoldDuration = 0.5
	box.prompt.Enabled = true
	setLabel(box, "Caja de armas")
end

local function build(position)
	-- La caja misteriosa (modelo de caja-misteriosa.glb). El Hitbox invisible hace de base: colisión, prompt y placa.
	local model, base = PropModel.build(CajaMisteriosa, position, 0)
	model.Name = "WeaponBox"
	base.Name = "Base"

	local display = Instance.new("Part")
	display.Name = "Display"
	display.Size = Vector3.new(1.4, 1.4, 1.4)
	display.Anchored = true
	display.CanCollide = false
	display.Material = Enum.Material.Neon
	display.Transparency = 1
	display.CFrame = base.CFrame * CFrame.new(0, 3.5, 0)
	display.Parent = model

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
	return { model = model, base = base, display = display, prompt = prompt, state = "idle", rollId = 0 }
end

local function onTriggered(box, player)
	if box ~= current or PlayerState.get(player) ~= "Normal" then
		return
	end

	if box.state == "idle" then
		if not Points.spend(Config.WeaponBox.Cost) then
			Remotes.Feed:FireClient(player, `Faltan latas: la caja cuesta {Config.WeaponBox.Cost}`)
			return
		end

		box.state = "spinning"
		box.model:SetAttribute("Open", true)
		box.rollId += 1
		local id = box.rollId
		box.prompt.Enabled = false
		Points.feed(`{player.DisplayName} abrió la caja de armas`)

		-- Las armas giran unos segundos y se detiene en una al azar
		local pick = rollWeapon()
		box.display.Transparency = 0
		local music = Instance.new("Sound")
		music.SoundId = Config.Sounds.BoxSpin
		music.Volume = Config.Sounds.Volume.Box
		music.RollOffMaxDistance = 80
		music.Parent = box.base
		music:Play()
		local pool = Config.WeaponBox.Pool
		local steps = math.floor(Config.WeaponBox.SpinTime / 0.1)
		for i = 1, steps do
			if box ~= current then
				return
			end
			local name = pool[math.random(#pool)]
			setLabel(box, Config.Weapons[name].Name, RARITY_COLOR[Config.Weapons[name].Rarity])
			box.display.Color = RARITY_COLOR[Config.Weapons[name].Rarity]
			task.wait(0.1)
		end
		music:Destroy()
		if box ~= current then
			return
		end

		local cfg = Config.Weapons[pick]
		box.state = "ready"
		box.pick = pick
		box.display.Color = RARITY_COLOR[cfg.Rarity]
		setLabel(box, `{cfg.Name} ({cfg.Rarity})`, RARITY_COLOR[cfg.Rarity])
		box.prompt.ActionText = `Tomar {cfg.Name}`
		box.prompt.ObjectText = cfg.Rarity
		box.prompt.HoldDuration = 0
		box.prompt.Enabled = true
		Points.feed(`La caja sacó: {cfg.Name} ({cfg.Rarity})`)

		-- Si nadie la toma a tiempo, se pierde
		task.delay(Config.WeaponBox.TakeTime, function()
			if box == current and box.state == "ready" and box.rollId == id then
				resetToIdle(box)
			end
		end)
	elseif box.state == "ready" then
		local pick = box.pick
		resetToIdle(box)
		Weapons.givePrimary(player, pick)
		Points.feed(`{player.DisplayName} tomó {Config.Weapons[pick].Name}`)
	end
end

-- Quita la caja actual (cambio de zona o fin de partida)
function WeaponBox.clear()
	if current then
		current.connection:Disconnect()
		current.model:Destroy()
		current = nil
	end
end

-- Coloca la caja en un lugar al azar de la zona
function WeaponBox.place(zoneName)
	WeaponBox.clear()
	local spots = boxSpots[zoneName]
	if not spots or #spots == 0 then
		return
	end

	local box = build(spots[math.random(#spots)])
	resetToIdle(box)
	box.prompt.Triggered:Connect(function(player)
		onTriggered(box, player)
	end)

	-- Gira mientras la caja existe
	box.connection = RunService.Heartbeat:Connect(function(dt)
		if box.state ~= "idle" then
			box.display.CFrame = box.base.CFrame * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, os.clock() * 3, 0)
		end
	end)
	current = box
end

-- refs viene de MapBuilder (candidatos de la caja y estaciones de munición)
function WeaponBox.init(refs)
	boxSpots = refs.boxSpots

	for _, station in refs.ammoStations do
		station.prompt.ActionText = "Comprar munición"
		station.prompt.ObjectText = `{Config.WeaponBox.AmmoCost} latas`
		station.prompt.Enabled = true
		station.prompt.Triggered:Connect(function(player)
			local denied = Weapons.ammoDenied(player)
			if denied then
				Remotes.Feed:FireClient(player, denied)
			elseif Points.spend(Config.WeaponBox.AmmoCost) then
				Weapons.refillReserve(player)
				station.model:SetAttribute("Open", true)
				task.delay(1.6, function()
					station.model:SetAttribute("Open", false)
				end)
				Points.feed(`{player.DisplayName} compró munición`)
			else
				Remotes.Feed:FireClient(player, `Faltan latas: la munición cuesta {Config.WeaponBox.AmmoCost}`)
			end
		end)
	end
end

return WeaponBox
