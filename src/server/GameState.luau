-- Estado de partida: Lobby -> Zona 1 -> Punto seguro -> Zona 2 -> Extracción -> Resultado.
-- Publica Workspace attributes "Stage", "Message" y "ExtractionEnd" para que los clientes muestren el avance.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ambushes = require(script.Parent.Ambushes)
local Atmosphere = require(script.Parent.Atmosphere)
local Boarding = require(script.Parent.Boarding)
local CanPiles = require(script.Parent.CanPiles)
local Director = require(script.Parent.Director)
local Difficulty = require(script.Parent.Difficulty)
local RateLimit = require(script.Parent.RateLimit)
local Difficulties = require(ReplicatedStorage.Shared.Difficulties)
local Dummies = require(script.Parent.Dummies)
local GasCans = require(script.Parent.GasCans)
local Medkits = require(script.Parent.Medkits)
local VoteRoom = require(script.Parent.VoteRoom)
local Items = require(script.Parent.Items)
local VanBuilder = require(script.Parent.VanBuilder)
local MapBuilderBarrio = require(script.Parent.MapBuilderBarrio)
local PlayerState = require(script.Parent.PlayerState)
local Points = require(script.Parent.Points)
local Stats = require(script.Parent.Stats)
local Telemetry = require(script.Parent.Telemetry)
local WeaponBox = require(script.Parent.WeaponBox)
local Weapons = require(script.Parent.Weapons)
local Zombies = require(script.Parent.Zombies)

local GameState = {}

-- Constructor de cada mapa votable (las claves son los id de Config.Maps)
local BUILDERS = { Morro = MapBuilderBarrio }

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
	Gas = function()
		return map.gas.marketPos, "MERCADO"
	end,
	GasCarry = function()
		return map.generator.Position, "GENERADOR"
	end,
	Warning = function()
		return map.gate.Position, map.gateText.label
	end,
	Horde = function()
		return map.gate.Position, map.gateText.label
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
	Stadium = function()
		return map.stadiumVolume.Position, "ESTADIO"
	end,
}

-- `tone` es la clave de la orden en RadioHud.luau (define su color y quién la dice por radio)
local function setStage(name, message, tone)
	stage = name
	Telemetry.stage(name)
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
		if PlayerState.get(player) == "Normal" or player:GetAttribute("Boarded") or player:GetAttribute("Boarding") then
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
	for _, extra in map.safeExtraExits or {} do
		setDoor(extra, false)
	end
	setDoor(map.gate, false)
	if map.church then
		setDoor(map.church.exitDoor, false)
	end
	setLight(map.generatorModel, "luz_estado", LIGHT_OFF)
	setLight(map.radioModel, "led_llamada", LIGHT_OFF)
	setLight(map.radioModel, "led_senal", LIGHT_OFF)
	Boarding.reset()
	local van = workspace.Map:FindFirstChild("Van")
	if van then
		van:Destroy()
	end
	workspace:SetAttribute("ExtractionEnd", nil)
end

-- Construye el mapa elegido (destruye el anterior) y conecta los sistemas que dependen de él
local function loadMap(id)
	WeaponBox.clear()
	Zombies.clear()
	map = BUILDERS[id].build(Config.Game)
	Atmosphere.decorate(map)
	WeaponBox.init(map)
	CanPiles.init(map.canPiles)
	Medkits.init(map.medkits)
	GasCans.init(map.gas)
	map.gateText = map.gateText or { label = "PORTÓN", open = "abrir el portón", run = "al portón" }
	workspace:SetAttribute("MapId", id)
	Dummies.setLayout(id)
end

-- Partida privada creada desde el menú: el anfitrión ya eligió el mapa (viaja en los datos de teletransporte),
-- así que no hay votación. Solo aplica en servidores reservados; en los públicos devuelve nil.
local privateChoice
local privateDifficulty
local function privateMap()
	if privateChoice then
		return privateChoice
	end
	if game.PrivateServerId == "" or game.PrivateServerOwnerId ~= 0 then
		return nil
	end
	local deadline = os.clock() + 30
	repeat
		for _, player in Players:GetPlayers() do
			local ok, joinData = pcall(function()
				return player:GetJoinData()
			end)
			local id = ok and joinData.TeleportData and joinData.TeleportData.map
			if id and BUILDERS[id] then
				privateChoice = id
				privateDifficulty = Difficulties.isValid(joinData.TeleportData.difficulty) and joinData.TeleportData.difficulty or nil
				return id
			end
		end
		task.wait(0.5)
	until os.clock() > deadline
	return nil
end

-- Votación del mapa en la sala aparte; al terminar se construye el ganador
local function vote()
	Director.setZone(nil)
	Director.setBoost(false)
	Ambushes.disarm()
	Zombies.clear()
	WeaponBox.clear()
	workspace:SetAttribute("ObjectivePos", nil)
	workspace:SetAttribute("ObjectiveName", nil)
	workspace:SetAttribute("ExtractionEnd", nil)

	local fixed = privateMap()
	if fixed then
		Difficulty.set(privateDifficulty) -- la eligió el anfitrión en el menú (nil = la de por defecto)
		loadMap(fixed)
		return
	end

	PlayerState.setSafePoint(VoteRoom.build().spawn)
	setStage("Vote", "Voten la dificultad con 1 a 4", "Vote")
	respawn(false)

	local winner, difficulty = VoteRoom.run(function(text)
		setStage("Vote", text, "Vote")
	end)
	Difficulty.set(difficulty)
	local name = winner
	for _, option in Config.Maps do
		if option.id == winner then
			name = option.name
		end
	end
	setStage("Vote", `Mapa elegido: {name}. Dificultad: {Difficulties.get(difficulty).Name}`, "Vote")
	task.wait(1.5)
	loadMap(winner)
end

local function lobby()
	Director.setZone(nil)
	Director.setBoost(false)
	Ambushes.disarm()
	Zombies.clear()
	Stats.reset()
	Points.reset()
	CanPiles.reset()
	Medkits.reset()
	Items.resetAll()
	GasCans.reset()
	WeaponBox.clear()
	Weapons.resetAll()
	resetMap()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Ready", false)
	end

	PlayerState.setSafePoint(map.lobbySpawn)
	setStage("Lobby", `Dificultad {Difficulties.get(Difficulty.id()).Name}. Practiquen en los maniquíes. Presionen Y cuando estén listos`, "Lobby")
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

-- `room` = { entryDoor, exitDoor, extraExits?, spawn }: el punto seguro 1 de cada mapa o la iglesia del mapa nuevo
local function safeRoom(room)
	setDoor(room.entryDoor, false) -- cierra la puerta detrás del equipo
	Director.setZone(nil)
	Ambushes.disarm()
	Zombies.clear()
	WeaponBox.clear()

	PlayerState.setSafePoint(room.spawn)
	respawn(true) -- los caídos de antes reaparecen aquí
	Weapons.refillAll() -- recarga gratis del punto seguro
	setStage("SafeRoom", "Punto seguro. Descansen", "Safe")
	task.wait(Config.Game.SafeRoomTime)

	setDoor(room.exitDoor, true)
	for _, extra in room.extraExits or {} do
		setDoor(extra, true)
	end
	return true
end

-- Mapa nuevo: el generador está sin gas; hay que llevarle las garrafas del mercado. Devuelve false si el equipo cae.
local function fuelGenerator()
	GasCans.activate()
	local lastKey
	return waitUntil(function()
		local count, carried = GasCans.delivered(), GasCans.anyCarried()
		local key = `{count}{carried}`
		if key ~= lastKey then
			lastKey = key
			if carried then
				setStage("Zone2", `Lleven la garrafa al generador ({count}/{Config.Gas.Count})`, "GasCarry")
			else
				setStage("Zone2", `El generador no tiene gas: busquen garrafas en el mercado ({count}/{Config.Gas.Count})`, "Gas")
			end
		end
		return count >= Config.Gas.Count
	end, true)
end

local function zone2()
	PlayerState.resetSelfRevives()
	Director.setZone("Zone2")
	WeaponBox.place("Zone2")
	Ambushes.arm(map.ambushesZone2)
	if map.gas and not fuelGenerator() then
		return false
	end
	setStage("Zone2", `Enciendan el generador para {map.gateText.open}`, "Generator")
	if not waitForPrompt(map.generatorPrompt) then
		return false
	end

	setLight(map.generatorModel, "luz_estado", LIGHT_ON) -- el generador arranca
	-- Aviso: se oye una sirena unos segundos antes de que llegue la horda
	setStage("Zone2", "¡Se acerca una horda! Prepárense", "Warning")
	setDoor(map.gate, true)
	playGlobal(Config.Sounds.HordeSiren, Config.Sounds.Volume.Siren, 15)
	task.wait(Config.Game.HordeWarning)
	setStage("Zone2", `¡HORDA! Corran {map.gateText.run}`, "Horde")
	Atmosphere.blackout(map.generator.Position) -- el generador sobrecarga la red: los faroles cercanos revientan
	task.spawn(Director.spawnHorde, Config.Game.GeneratorHorde)

	-- Mapa de siempre: la entrada de la extracción; mapa nuevo: la iglesia
	local goal = map.church and map.church.volume or map.extractionVolume
	local ok = waitUntil(function()
		return allInside(goal)
	end, true)
	if ok then
		Points.add(Config.Points.ZoneComplete)
	end
	return ok
end

local function extraction()
	-- Sin zombies nuevos mientras llaman a la radio (solo quedan los de la horda)
	Director.setZone(nil)
	Ambushes.disarm()
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
	local van = VanBuilder.makeVan(map.vanStart.Position)
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

	-- Se abren las puertas y cada quien sube manteniendo E (server/Boarding); con un caído en hombros suben los dos
	Boarding.open(van)
	setStage("Extraction", "¡Súbanse a la van! Mantén E en la puerta", "Board")
	local reached = waitUntil(function()
		return Boarding.count() > 0
	end, true)
	if not reached then
		return false
	end

	-- Margen para que lleguen los demás; la van sale al subir todos o al acabarse
	setStage("Extraction", "¡Corran a la van!", "Run")
	local started = os.clock()
	while os.clock() - started < Config.Game.VanGrace and not Boarding.allBoarded(livingPlayers()) do
		task.wait(0.25)
	end
	Boarding.close()

	-- La van arranca: puertas cerradas, marcha atrás, giro y a toda velocidad (client/VanAnimator); la victoria sale mientras se va
	setStage("Extraction", "¡Arranca, arranca!", "Run")
	Boarding.depart()
	task.wait(Config.Boarding.ResultAfter)
	return true
end

-- Mapa nuevo, tramo 3: cruzar la terminal hasta la puerta del estadio (emboscada con Tanque en el camino)
local function zone3()
	setStage("Zone3", "Crucen la terminal hasta el estadio", "Stadium")
	PlayerState.resetSelfRevives()
	Director.setZone("Zone3")
	WeaponBox.place("Zone3")
	Ambushes.arm(map.ambushesZone3)
	local ok = waitUntil(function()
		return allInside(map.stadiumInside or map.stadiumVolume)
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
	Telemetry.result(won)
	task.wait(Config.Game.ResultTime)
end

function GameState.start()
	-- La partida decide cuándo reaparece cada jugador (el siguiente punto seguro)
	Players.CharacterAutoLoads = false
	-- El mapa se construye en cada ronda tras la votación (vote -> loadMap)

	local function onJoin(player)
		if stage == "Lobby" or stage == "Vote" then
			player:SetAttribute("Ready", false)
			player:LoadCharacter()
		elseif stage ~= "Result" then
			-- Entra con la partida empezada: aparece junto a un compañero que siga de pie (si no hay, en el último punto seguro)
			for _, other in Players:GetPlayers() do
				local root = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
				if root and PlayerState.get(other) == "Normal" then
					PlayerState.spawnAt(player, root.CFrame * CFrame.new(0, 2, 0))
					break
				end
			end
			player:SetAttribute("Ready", true)
			player:LoadCharacter()
		end
	end
	Players.PlayerAdded:Connect(onJoin)
	-- Quien ya estaba conectado antes de arrancar este módulo también necesita su personaje
	for _, player in Players:GetPlayers() do
		if not player.Character then
			task.spawn(onJoin, player)
		end
	end

	Remotes.Ready.OnServerEvent:Connect(function(player)
		if not RateLimit.check(player, "Ready", 0.5) then
			return
		end
		if stage == "Lobby" then
			player:SetAttribute("Ready", true)
		end
	end)

	task.spawn(function()
		while true do
			vote()
			lobby()
			local won = zone1() and safeRoom({ entryDoor = map.safeEntryDoor, exitDoor = map.safeExitDoor, extraExits = map.safeExtraExits, spawn = map.safeSpawn })
			if won then
				if map.church then
					-- Mapa nuevo: generador -> horda -> iglesia -> descanso -> terminal -> estadio -> extracción
					won = zone2() and safeRoom({ entryDoor = map.gate, exitDoor = map.church.exitDoor, spawn = map.church.spawn }) and zone3() and extraction()
				else
					won = zone2() and extraction()
				end
			end
			result(won)
		end
	end)
end

return GameState
