-- Estado de partida: Lobby -> Zona 1 -> Punto seguro -> Zona 2 -> Extracción -> Resultado.
-- Publica Workspace attributes "Stage", "Message" y "ExtractionEnd" para que los clientes muestren el avance.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ambushes = require(script.Parent.Ambushes)
local CanPiles = require(script.Parent.CanPiles)
local Director = require(script.Parent.Director)
local MapBuilder = require(script.Parent.MapBuilder)
local MapBuilderBarrio = require(script.Parent.MapBuilderBarrio)
local PlayerState = require(script.Parent.PlayerState)
local Points = require(script.Parent.Points)
local Stats = require(script.Parent.Stats)
local WeaponBox = require(script.Parent.WeaponBox)
local Weapons = require(script.Parent.Weapons)
local Zombies = require(script.Parent.Zombies)

local GameState = {}

local map -- referencias del mapa (puertas, volúmenes, puntos)
local stage = "Lobby"

-- Hacia dónde debe ir el equipo en cada orden (clave = `tone`): devuelve la posición y el nombre que muestra la guía
-- (client/ObjectiveGuide). Las órdenes que no están aquí no tienen objetivo.
local OBJECTIVES = {
	Advance = function()
		return map.safeVolume.Position, "PUNTO SEGURO"
	end,
	Generator = function()
		return map.generator.Position, "GENERADOR"
	end,
	Warning = function()
		return map.gate.Position, "PORTÓN"
	end,
	Horde = function()
		return map.gate.Position, "PORTÓN"
	end,
	Radio = function()
		return map.radioModel:GetPivot().Position, "RADIO"
	end,
	Van = function()
		return map.vanStop.Position, "VAN"
	end,
	Board = function()
		return map.vanStop.Position, "VAN"
	end,
	Run = function()
		return map.vanStop.Position, "VAN"
	end,
	Exit = function()
		return map.exitVolume.Position, "SALIDA"
	end,
}

-- `tone` es la clave de la orden en RadioHud.luau (define su color y quién la dice por radio)
local function setStage(name, message, tone)
	stage = name
	local objective = map and OBJECTIVES[tone]
	if objective then
		local position, label = objective()
		workspace:SetAttribute("ObjectivePos", position)
		workspace:SetAttribute("ObjectiveName", label)
	else
		workspace:SetAttribute("ObjectivePos", nil)
		workspace:SetAttribute("ObjectiveName", nil)
	end
	workspace:SetAttribute("Stage", name)
	workspace:SetAttribute("Tone", tone)
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
	local players = Players:GetPlayers()
	for _, player in players do
		if PlayerState.get(player) == "Normal" then
			return false
		end
	end
	-- Un jugador solo, caído, todavía puede levantarse solo (tecla H) si le queda la oportunidad de la zona
	if #players == 1 and PlayerState.get(players[1]) == "Downed" and (players[1]:GetAttribute("SelfRevives") or 0) > 0 then
		return false
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

-- Sonido global (2D) para todos los jugadores
local function playGlobal(soundId, volume, lifetime)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, lifetime)
end

local LIGHT_OFF = Color3.fromRGB(255, 70, 50)
local LIGHT_ON = Color3.fromRGB(120, 255, 60)

-- Cambia el color de una luz del modelo (generador: luz_estado; radio: led_llamada y led_senal)
local function setLight(model, partName, color)
	local part = model and model:FindFirstChild(partName)
	if part then
		part.Color = color
	end
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

-- Puertas del lobby: la principal y, en el mapa nuevo, una por cada ruta extra (Callejón)
local function setLobbyDoors(open)
	setDoor(map.lobbyDoor, open)
	for _, extra in map.extraLobbyDoors or {} do
		setDoor(extra, open)
	end
end

local function resetMap()
	setLobbyDoors(false)
	setDoor(map.safeEntryDoor, true)
	setDoor(map.safeExitDoor, false)
	if map.gate then -- el mapa nuevo todavía no tiene portón
		setDoor(map.gate, false)
	end
	setLight(map.generatorModel, "luz_estado", LIGHT_OFF)
	setLight(map.radioModel, "led_llamada", LIGHT_OFF)
	setLight(map.radioModel, "led_senal", LIGHT_OFF)
	local van = workspace.Map:FindFirstChild("Van")
	if van then
		van:Destroy()
	end
	workspace:SetAttribute("ExtractionEnd", nil)
end

local function lobby()
	Director.setZone(nil)
	Director.setBoost(false)
	Ambushes.disarm()
	Zombies.clear()
	Stats.reset()
	Points.reset()
	CanPiles.reset()
	WeaponBox.clear()
	Weapons.resetAll()
	resetMap()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Ready", false)
	end

	PlayerState.setSafePoint(map.lobbySpawn)
	setStage("Lobby", "Practiquen en los maniquíes. Presionen Y cuando estén listos", "Lobby")
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

	setStage("Lobby", "¡Empezamos!", "Start")
	task.wait(2)
	setLobbyDoors(true)
end

local function zone1()
	setStage("Zone1", "Crucen la calle hasta el punto seguro", "Advance")
	PlayerState.resetSelfRevives()
	Director.setZone("Zone1")
	WeaponBox.place("Zone1")
	Ambushes.arm(map.ambushes)
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
	Ambushes.disarm()
	Zombies.clear()
	WeaponBox.clear()

	PlayerState.setSafePoint(map.safeSpawn)
	respawn(true) -- los caídos de antes reaparecen aquí
	Weapons.refillAll() -- recarga gratis del punto seguro
	setStage("SafeRoom", "Punto seguro. Descansen", "Safe")
	task.wait(Config.Game.SafeRoomTime)

	setDoor(map.safeExitDoor, true)
	return true
end

local function zone2()
	setStage("Zone2", "Enciendan el generador para abrir el portón", "Generator")
	PlayerState.resetSelfRevives()
	Director.setZone("Zone2")
	WeaponBox.place("Zone2")
	if not waitForPrompt(map.generatorPrompt) then
		return false
	end

	setLight(map.generatorModel, "luz_estado", LIGHT_ON) -- el generador arranca
	-- Aviso: se oye una sirena unos segundos antes de que llegue la horda
	setStage("Zone2", "¡Se acerca una horda! Prepárense", "Warning")
	setDoor(map.gate, true)
	playGlobal(Config.Sounds.HordeSiren, Config.Sounds.Volume.Siren, 15)
	task.wait(Config.Game.HordeWarning)
	setStage("Zone2", "¡HORDA! Corran al portón", "Horde")
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
	setStage("Extraction", "Llamen al rescate con la radio", "Radio")
	PlayerState.resetSelfRevives()
	if not waitForPrompt(map.radioPrompt) then
		return false
	end
	Director.setZone("Extraction")

	setLight(map.radioModel, "led_llamada", LIGHT_ON) -- la llamada de rescate sale
	setLight(map.radioModel, "led_senal", LIGHT_ON)
	local arrival = workspace:GetServerTimeNow() + Config.Game.ExtractionTime
	workspace:SetAttribute("ExtractionEnd", arrival)
	setStage("Extraction", "¡Aguanten hasta que llegue la van!", "Hold")
	Director.setBoost(true)

	local survived = waitUntil(function()
		return workspace:GetServerTimeNow() >= arrival
	end, true)
	if not survived then
		return false
	end

	-- La van entra por el fondo de la calle
	-- El servidor solo dice de dónde a dónde y cuándo: cada cliente anima la entrada (VanAnimator), así se ve fluida
	local van = MapBuilder.makeVan(map.vanStart.Position)
	local arrivalTime = Config.Game.VanArriveTime
	van:SetAttribute("From", map.vanStart)
	van:SetAttribute("To", map.vanStop)
	van:SetAttribute("Duration", arrivalTime)
	van:SetAttribute("Start", workspace:GetServerTimeNow())
	van.Parent = workspace.Map
	setStage("Extraction", "¡La van está llegando!", "Van")
	task.wait(arrivalTime)
	van:PivotTo(map.vanStop) -- posición final real (colisiones y detección de quién subió)
	van:SetAttribute("Arrived", true)

	setStage("Extraction", "¡Súbanse a la van!", "Board")
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
	setStage("Extraction", "¡Corran a la van!", "Run")
	local started = os.clock()
	while os.clock() - started < Config.Game.VanGrace and not allInside(map.vanVolume) do
		task.wait(0.25)
	end
	return true
end

-- Mapa nuevo (solo hasta el punto seguro 1): la prueba se gana al cruzar la puerta de salida
local function testExit()
	setStage("SafeRoom", "Fin del tramo de prueba. Salgan por la puerta", "Exit")
	local ok = waitUntil(function()
		return allInside(map.exitVolume)
	end, true)
	if ok then
		Points.add(Config.Points.ZoneComplete)
	end
	return ok
end

local function result(won)
	Director.setZone(nil)
	Ambushes.disarm()
	Director.setBoost(false)
	Zombies.clear()
	WeaponBox.clear()
	setStage("Result", won and "¡Victoria!" or "Derrota", won and "Victory" or "Defeat")
	Remotes.Results:FireAllClients(won, Stats.all())
	task.wait(Config.Game.ResultTime)
end

function GameState.start()
	-- La partida decide cuándo reaparece cada jugador (el siguiente punto seguro)
	Players.CharacterAutoLoads = false
	local builder = Config.Game.UseNewMap and MapBuilderBarrio or MapBuilder
	map = builder.build(Config.Game)
	WeaponBox.init(map)
	CanPiles.init(map.canPiles)

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
			local won = zone1() and safeRoom()
			if won then
				if map.exitVolume then
					won = testExit()
				else
					won = zone2() and extraction()
				end
			end
			result(won)
		end
	end)
end

return GameState
