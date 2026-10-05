-- Caja de armas (una por zona, en un lugar al azar de la zona) y estaciones de munición.
-- La caja cuesta puntos del equipo; las armas giran unos segundos y se detiene en una al azar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)
local Points = require(script.Parent.Points)
local Weapons = require(script.Parent.Weapons)

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

local function setLabel(box, text, color)
	box.label.Text = text
	box.label.TextColor3 = color or Color3.fromRGB(255, 220, 90)
end

local function resetToIdle(box)
	box.state = "idle"
	box.pick = nil
	box.display.Transparency = 1
	box.prompt.ActionText = `Abrir caja ({Config.WeaponBox.Cost} pts)`
	box.prompt.HoldDuration = 0.5
	box.prompt.Enabled = true
	setLabel(box, "▼ CAJA DE ARMAS")
end

local function build(position)
	local model = Instance.new("Model")
	model.Name = "WeaponBox"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(5, 3, 3)
	base.Anchored = true
	base.Color = Color3.fromRGB(110, 70, 40)
	base.Material = Enum.Material.Wood
	base.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0))
	base.Parent = model

	local trim = Instance.new("Part")
	trim.Name = "Trim"
	trim.Size = Vector3.new(5.2, 0.6, 3.2)
	trim.Anchored = true
	trim.CanCollide = false
	trim.Color = Color3.fromRGB(255, 200, 60)
	trim.Material = Enum.Material.Neon
	trim.CFrame = base.CFrame * CFrame.new(0, 0.9, 0)
	trim.Parent = model

	local display = Instance.new("Part")
	display.Name = "Display"
	display.Size = Vector3.new(1.4, 1.4, 1.4)
	display.Anchored = true
	display.CanCollide = false
	display.Material = Enum.Material.Neon
	display.Transparency = 1
	display.CFrame = base.CFrame * CFrame.new(0, 3.5, 0)
	display.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 40)
	gui.StudsOffset = Vector3.new(0, 6.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 25 -- solo se lee de cerca
	gui.Parent = base
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Caja de armas"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	model.Parent = workspace.Map
	return { model = model, base = base, display = display, label = label, prompt = prompt, state = "idle", rollId = 0 }
end

local function onTriggered(box, player)
	if box ~= current or PlayerState.get(player) ~= "Normal" then
		return
	end

	if box.state == "idle" then
		if not Points.spend(Config.WeaponBox.Cost) then
			Remotes.Feed:FireClient(player, `Faltan puntos: la caja cuesta {Config.WeaponBox.Cost}`)
			return
		end

		box.state = "spinning"
		box.rollId += 1
		local id = box.rollId
		box.prompt.Enabled = false
		Points.feed(`{player.DisplayName} abrió la caja de armas`)

		-- Las armas giran unos segundos y se detiene en una al azar
		local pick = rollWeapon()
		box.display.Transparency = 0
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
		if box ~= current then
			return
		end

		local cfg = Config.Weapons[pick]
		box.state = "ready"
		box.pick = pick
		box.display.Color = RARITY_COLOR[cfg.Rarity]
		setLabel(box, `{cfg.Name} ({cfg.Rarity})`, RARITY_COLOR[cfg.Rarity])
		box.prompt.ActionText = `Tomar {cfg.Name}`
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
		station.prompt.ActionText = `Comprar munición ({Config.WeaponBox.AmmoCost} pts)`
		station.prompt.Enabled = true
		station.prompt.Triggered:Connect(function(player)
			local denied = Weapons.ammoDenied(player)
			if denied then
				Remotes.Feed:FireClient(player, denied)
			elseif Points.spend(Config.WeaponBox.AmmoCost) then
				Weapons.refillReserve(player)
				Points.feed(`{player.DisplayName} compró munición`)
			else
				Remotes.Feed:FireClient(player, `Faltan puntos: la munición cuesta {Config.WeaponBox.AmmoCost}`)
			end
		end)
	end
end

return WeaponBox
