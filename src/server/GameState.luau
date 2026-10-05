-- Estado de partida: Lobby -> Zona 1 -> Punto seguro -> Zona 2 -> Extracción -> Resultado.
-- Publica Workspace attributes "Stage", "Message" y "ExtractionEnd" para que los clientes muestren el avance.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Director = require(script.Parent.Director)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerState = require(script.Parent.PlayerState)
local Points = require(script.Parent.Points)
local Stats = require(script.Parent.Stats)
local WeaponBox = require(script.Parent.WeaponBox)
local Weapons = require(script.Parent.Weapons)
local Zombies = require(script.Parent.Zombies)

local GameState = {}

local map -- referencias del mapa (puertas, volúmenes, puntos)
local stage = "Lobby"

local function setStage(name, message)
	stage = name
	workspace:SetAttribute("Stage", name)
	workspace:SetAttribute("Message", message)
end

local function getRoot(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function inside(part, position)
	local rel = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

-- Jugadores que están en el mapa (los muertos esperan al siguiente punto seguro)
local function livingPlayers()
	local list = {}
	for _, player in Players:GetPlayers() do
		if PlayerState.get(player) ~= "Dead" and getRoot(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function allInside(volumePart)
	local list = livingPlayers()
	if #list == 0 then
		return false
	end
	for _, player in list do
		if not inside(volumePart, getRoot(player).Position) then
			return false
		end
	end
	return true
end

-- Derrota: nadie queda de pie para revivir a los demás
local function teamWiped()
	for _, player in Players:GetPlayers() do
		if PlayerState.get(player) == "Normal" then
			return false
		end
	end
	return true
end

-- Espera a que se cumpla la condición. Devuelve false si el equipo cae o se vacía el servidor.
local function waitUntil(condition, checkWipe)
	while not condition() do
		if checkWipe and (#Players:GetPlayers() == 0 or teamWiped()) then
			return false
		end
		task.wait(0.25)
	end
	return true
end

local function setDoor(part, open)
	part.CanCollide = not open
	part.Transparency = open and 1 or 0
end

local function respawn(onlyDead)
	for _, player in Players:GetPlayers() do
		if not onlyDead or PlayerState.get(player) == "Dead" then
			task.spawn(function()
				player:LoadCharacter()
			end)
		end
	end
end

-- Espera a que alguien use un prompt (generador, radio)
local function waitForPrompt(prompt)
	local used = false
	local connection = prompt.Triggered:Connect(function()
		used = true
	end)
	prompt.Enabled = true
	local ok = waitUntil(function()
		return used
	end, true)
	prompt.Enabled = false
	connection:Disconnect()
	return ok
end

local function resetMap()
	setDoor(map.lobbyDoor, false)
	setDoor(map.safeEntryDoor, true)
	setDoor(map.safeExitDoor, false)
	setDoor(map.gate, false)
	local van = workspace.Map:FindFirstChild("Van")
	if van then
		van:Destroy()
	end
	workspace:SetAttribute("ExtractionEnd", nil)
end

local function lobby()
	Director.setZone(nil)
	Director.setBoost(false)
	Zombies.clear()
	Stats.reset()
	Points.reset()
	WeaponBox.clear()
	Weapons.resetAll()
	resetMap()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Ready", false)
	end

	PlayerState.setSafePoint(map.lobbySpawn)
	setStage("Lobby", "Practiquen en los maniquíes. Presionen Y cuando estén listos")
	respawn(false)

	waitUntil(function()
		local list = Players:GetPlayers()
		if #list == 0 then
			return false
		end
		for _, player in list do
			if not player:GetAttribute("Ready") then
				return false
			end
		end
		return true
	end, false)

	setStage("Lobby", "¡Empezamos!")
	task.wait(2)
	setDoor(map.lobbyDoor, true)
end

local function zone1()
	setStage("Zone1", "Crucen la calle hasta el punto seguro")
	Director.setZone("Zone1")
	WeaponBox.place("Zone1")
	local ok = waitUntil(function()
		return allInside(map.safeVolume)
	end, true)
	if ok then
		Points.add(Config.Points.ZoneComplete)
	end
	return ok
end

local function safeRoom()
	setDoor(map.safeEntryDoor, false) -- cierra la puerta detrás del equipo
	Director.setZone(nil)
	Zombies.clear()
	WeaponBox.clear()

	PlayerState.setSafePoint(map.safeSpawn)
	respawn(true) -- los caídos de antes reaparecen aquí
	Weapons.refillAll() -- recarga gratis del punto seguro
	setStage("SafeRoom", "Punto seguro. Descansen")
	task.wait(Config.Game.SafeRoomTime)

	setDoor(map.safeExitDoor, true)
	return true
end

local function zone2()
	setStage("Zone2", "Enciendan el generador para abrir el portón")
	Director.setZone("Zone2")
	WeaponBox.place("Zone2")
	if not waitForPrompt(map.generatorPrompt) then
		return false
	end

	setStage("Zone2", "¡HORDA! Corran al portón")
	setDoor(map.gate, true)
	task.spawn(Director.spawnHorde, Config.Game.GeneratorHorde)

	local ok = waitUntil(function()
		return allInside(map.extractionVolume)
	end, true)
	if ok then
		Points.add(Config.Points.ZoneComplete)
	end
	return ok
end

local function extraction()
	-- Sin zombies nuevos mientras llaman a la radio (solo quedan los de la horda)
	Director.setZone(nil)
	WeaponBox.place("Extraction")
	setStage("Extraction", "Llamen al rescate con la radio")
	if not waitForPrompt(map.radioPrompt) then
		return false
	end
	Director.setZone("Extraction")

	local arrival = workspace:GetServerTimeNow() + Config.Game.ExtractionTime
	workspace:SetAttribute("ExtractionEnd", arrival)
	setStage("Extraction", "¡Aguanten hasta que llegue la van!")
	Director.setBoost(true)

	local survived = waitUntil(function()
		return workspace:GetServerTimeNow() >= arrival
	end, true)
	if not survived then
		return false
	end

	-- La van entra por el fondo de la calle
	local van = MapBuilder.makeVan()
	van:PivotTo(map.vanStart)
	van.Parent = workspace.Map

	local position = Instance.new("CFrameValue")
	position.Value = map.vanStart
	position.Changed:Connect(function(value)
		van:PivotTo(value)
	end)
	local tween = TweenService:Create(position, TweenInfo.new(6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = map.vanStop })
	setStage("Extraction", "¡La van está llegando!")
	tween:Play()
	tween.Completed:Wait()
	position:Destroy()

	setStage("Extraction", "¡Súbanse a la van!")
	local reached = waitUntil(function()
		for _, player in livingPlayers() do
			if inside(map.vanVolume, getRoot(player).Position) then
				return true
			end
		end
		return false
	end, true)
	if not reached then
		return false
	end

	-- Margen para que lleguen los demás
	setStage("Extraction", "¡Corran a la van!")
	local started = os.clock()
	while os.clock() - started < Config.Game.VanGrace and not allInside(map.vanVolume) do
		task.wait(0.25)
	end
	return true
end

local function result(won)
	Director.setZone(nil)
	Director.setBoost(false)
	Zombies.clear()
	WeaponBox.clear()
	setStage("Result", won and "¡Victoria!" or "Derrota")
	Remotes.Results:FireAllClients(won, Stats.all())
	task.wait(Config.Game.ResultTime)
end

function GameState.start()
	-- La partida decide cuándo reaparece cada jugador (el siguiente punto seguro)
	Players.CharacterAutoLoads = false
	map = MapBuilder.build(Config.Game)
	WeaponBox.init(map)

	Players.PlayerAdded:Connect(function(player)
		if stage == "Lobby" then
			player:SetAttribute("Ready", false)
			player:LoadCharacter()
		end
	end)

	Remotes.Ready.OnServerEvent:Connect(function(player)
		if stage == "Lobby" then
			player:SetAttribute("Ready", true)
		end
	end)

	task.spawn(function()
		while true do
			lobby()
			local won = zone1() and safeRoom() and zone2() and extraction()
			result(won)
		end
	end)
end

return GameState
