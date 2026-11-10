-- Estado de partida: Lobby -> Zona 1 -> Punto seguro -> Zona 2 -> Extracción -> Resultado.
-- Publica Workspace attributes "Stage", "Message" y "ExtractionEnd" para que los clientes muestren el avance.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ambushes = require(script.Parent.Ambushes)
local Atmosphere = require(script.Parent.Atmosphere)
local SurvivalWaves = require(script.Parent.SurvivalWaves)
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
local MapBuilderAirport = require(script.Parent.MapBuilderAirport)
local MapBuilderBarrio = require(script.Parent.MapBuilderBarrio)
local PlayerState = require(script.Parent.PlayerState)
local Points = require(script.Parent.Points)
local Stats = require(script.Parent.Stats)
local Telemetry = require(script.Parent.Telemetry)
local Pharmacy = require(script.Parent.Pharmacy)
local Mutators = require(ReplicatedStorage.Shared.Mutators)
local PlayerProgress = require(script.Parent.PlayerProgress)
local Awards = require(script.Parent.Awards)
local Records = require(script.Parent.Records)
local WeaponBox = require(script.Parent.WeaponBox)
local Weapons = require(script.Parent.Weapons)
local Zombies = require(script.Parent.Zombies)

local GameState = {}

-- Constructor de cada mapa votable (las claves son los id de Config.Maps)
-- (Survival es el mismo mapa con la Tienda dentro del estadio: lo pide el anfitrión de una sala desde el menú)
local BUILDERS = { Morro = MapBuilderBarrio, Survival = MapBuilderBarrio, LastCall = MapBuilderAirport }

-- Textos de la partida que cambian con el mapa: cada constructor puede dar los suyos en `refs.texts`; los que falten son estos (Morro Esperanza)
local DEFAULT_TEXTS = {
	zone1 = "Cross the street to the safe room",
	zone3 = "Cross the terminal to the stadium",
	zone3Label = "STADIUM",
}

local map -- referencias del mapa (puertas, volúmenes, puntos)
local stage = "Lobby"
local reachedZone2 = false -- el equipo llegó al menos a la zona 2: sin eso la ronda no da Rhoms
local runStart = nil -- os.clock() al salir del lobby: el récord de extracción mide hasta la victoria

-- Hacia dónde debe ir el equipo en cada orden (clave = `tone`): devuelve la posición y el nombre que muestra la guía
-- (client/ObjectiveGuide). Las órdenes que no están aquí no tienen objetivo.
local OBJECTIVES = {
	Advance = function()
		return map.safeVolume.Position, "SAFE ROOM"
	end,
	Generator = function()
		return map.generator.Position, "GENERATOR"
	end,
	Gas = function()
		return map.gas.marketPos, "MERCADO"
	end,
	GasCarry = function()
		return map.generator.Position, "GENERATOR"
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
		return (map.extractionGoal or map.stadiumVolume).Position, map.texts.zone3Label
	end,
	Checkpoint = function()
		return map.gate.Position, map.gateText.label
	end,
}

-- `tone` es la clave de la orden en RadioHud.luau (define su color y quién la dice por radio)
local function setStage(name, message, tone)
	stage = name
	if name == "Zone2" or name == "Zone3" or name == "Extraction" then
		reachedZone2 = true
	end
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
	-- La Tienda de la zona en curso (Zone1 a Zone3) tiene su propia guía en pantalla
	workspace:SetAttribute("ShopPos", map and map.shopPositions and map.shopPositions[name == "WaveBreak" and "Survival" or name] or nil)
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

-- Atributos del modo Survival que lee el cliente (client/WaveHud)
local WAVE_ATTRIBUTES = { "Wave", "WaveTotal", "WaveLeft", "WaveBoss", "WaveBreakEnd" }

local function clearWaveAttributes()
	for _, name in WAVE_ATTRIBUTES do
		workspace:SetAttribute(name, nil)
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
	local second = map.safe2 or map.church -- el segundo punto seguro (la iglesia de Morro, la Fire Station de Last Call)
	if second then
		setDoor(second.exitDoor, false)
		for _, extra in second.extraExits or {} do
			setDoor(extra, false)
		end
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

-- Sortea los mutadores de la ronda (según la dificultad ya elegida) y los deja aplicados antes de construir el mapa
local function rollMutators()
	local ids, angle = Mutators.roll(Difficulty.id())
	workspace:SetAttribute("MutatorAngle", angle) -- donde se detiene la ruleta de mutaciones (client/MutatorWheel)
	Difficulty.setMutators(ids)
	Atmosphere.refreshFog()
	Telemetry.mutators(ids)
end

-- Construye el mapa elegido (destruye el anterior) y conecta los sistemas que dependen de él
local function loadMap(id)
	Pharmacy.clear()
	WeaponBox.clear()
	Zombies.clear()
	map = BUILDERS[id].build(Config.Game, { survival = id == "Survival" })
	Atmosphere.decorate(map)
	WeaponBox.init(map)
	Pharmacy.place(map.pharmacySpots)
	CanPiles.init(map.canPiles)
	Medkits.init(map.medkits)
	GasCans.init(map.gas)
	map.gateText = map.gateText or { label = "GATE", open = "open the gate", run = "to the gate" }
	map.texts = setmetatable(map.texts or {}, { __index = DEFAULT_TEXTS })
	workspace:SetAttribute("MapId", id)
	Dummies.setLayout(id)
end

-- Partida privada creada desde el menú: el anfitrión ya eligió el mapa (viaja en los datos de teletransporte),
-- así que no hay votación. Solo aplica en servidores reservados; en los públicos devuelve nil.
local privateChoice
local privateDifficulty
local privateMutators = true -- el anfitrión puede apagar los mutadores en el menú
local function privateMap()
	if privateChoice then
		return privateChoice
	end
	if Config.Survival.ForceInStudio and RunService:IsStudio() then
		privateChoice = "Survival" -- solo para probar el modo en Studio
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
				privateMutators = joinData.TeleportData.mutators ~= false
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
	Director.setSurvival(false)
	Director.setBoost(false)
	clearWaveAttributes()
	Ambushes.disarm()
	Zombies.clear()
	WeaponBox.clear()
	Pharmacy.clear()
	workspace:SetAttribute("ObjectivePos", nil)
	workspace:SetAttribute("ObjectiveName", nil)
	workspace:SetAttribute("ShopPos", nil)
	workspace:SetAttribute("ExtractionEnd", nil)

	local fixed = privateMap()
	if fixed then
		Difficulty.set(fixed ~= "Survival" and privateDifficulty or nil) -- la eligió el anfitrión en el menú (nil = la de por defecto); Survival sube sola
		if privateMutators and fixed ~= "Survival" then
			rollMutators()
		else
			Telemetry.mutators({})
		end
		loadMap(fixed)
		return
	end

	PlayerState.setSafePoint(VoteRoom.build().spawn)
	setStage("Vote", "Vote on the difficulty with 1 to 4", "Vote")
	respawn(false)

	local winner, difficulty = VoteRoom.run(function(text)
		setStage("Vote", text, "Vote")
	end)
	Difficulty.set(difficulty)
	rollMutators()
	local name = winner
	for _, option in Config.Maps do
		if option.id == winner then
			name = option.name
		end
	end
	setStage("Vote", `Map chosen: {name}. Difficulty: {Difficulties.get(difficulty).Name}`, "Vote")
	task.wait(1.5)
	loadMap(winner)
end

-- Limpia lo de la ronda anterior (lo usan el lobby y el modo Survival)
local function resetRound()
	Director.setZone(nil)
	Director.setSurvival(false)
	Director.setBoost(false)
	Ambushes.disarm()
	Zombies.clear()
	Stats.reset()
	Points.reset()
	CanPiles.reset()
	Medkits.reset()
	Items.resetAll()
	Pharmacy.resetEffects()
	GasCans.reset()
	WeaponBox.clear()
	Weapons.resetAll()
	resetMap()
	clearWaveAttributes()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Ready", false)
	end
end

local function lobby()
	resetRound()

	PlayerState.setSafePoint(map.lobbySpawn)
	-- Las mutaciones de la ronda las muestran la ruleta y las fichas del cliente (no van en este texto: así se puede traducir entero)
	setStage("Lobby", `Difficulty {Difficulties.get(Difficulty.id()).Name}. Practice on the dummies. Press Y when you're ready`, "Lobby")
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

	setStage("Lobby", "Let's go!", "Start")
	runStart = os.clock()
	reachedZone2 = false
	task.wait(2)
	setLobbyDoors(true)
end

local function zone1()
	setStage("Zone1", map.texts.zone1, "Advance")
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
	setStage("SafeRoom", "Safe room. Catch your breath", "Safe")
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
				setStage("Zone2", `Bring the gas can to the generator ({count}/{Config.Gas.Count})`, "GasCarry")
			else
				setStage("Zone2", `The generator is out of gas: find gas cans in the mercado ({count}/{Config.Gas.Count})`, "Gas")
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
	if map.gatePrompt then
		-- Last Call: el control de seguridad se abre en su lector de tarjetas
		setStage("Zone2", "Open the security checkpoint at the card reader", "Checkpoint")
		if not waitForPrompt(map.gatePrompt) then
			return false
		end
	else
		if map.gas and not fuelGenerator() then
			return false
		end
		setStage("Zone2", `Turn on the generator to {map.gateText.open}`, "Generator")
		if not waitForPrompt(map.generatorPrompt) then
			return false
		end
		setLight(map.generatorModel, "luz_estado", LIGHT_ON) -- el generador arranca
	end

	-- Aviso: se oye una sirena unos segundos antes de que llegue la horda
	setStage("Zone2", "Horde incoming! Get ready", "Warning")
	setDoor(map.gate, true)
	playGlobal(Config.Sounds.HordeSiren, Config.Sounds.Volume.Siren, 15)
	task.wait(Config.Game.HordeWarning)
	setStage("Zone2", `HORDE! Run {map.gateText.run}`, "Horde")
	Atmosphere.blackout((map.generator or map.gate).Position) -- la red se sobrecarga: los faroles cercanos revientan
	task.spawn(Director.spawnHorde, Config.Game.GeneratorHorde)

	-- El segundo punto seguro: la iglesia (Morro Esperanza) o la Fire Station (Last Call)
	local second = map.safe2 or map.church
	local goal = second and second.volume or map.extractionVolume
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
	setStage("Extraction", "Call for rescue on the radio", "Radio")
	PlayerState.resetSelfRevives()
	if not waitForPrompt(map.radioPrompt) then
		return false
	end
	Director.setZone("Extraction")

	setLight(map.radioModel, "led_llamada", LIGHT_ON) -- la llamada de rescate sale
	setLight(map.radioModel, "led_senal", LIGHT_ON)
	local arrival = workspace:GetServerTimeNow() + Config.Game.ExtractionTime
	workspace:SetAttribute("ExtractionEnd", arrival)
	setStage("Extraction", "Hold out until the van arrives!", "Hold")
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
	setStage("Extraction", "The van is arriving!", "Van")
	task.wait(arrivalTime)
	van:PivotTo(map.vanStop) -- posición final real (colisiones y detección de quién subió)
	van:SetAttribute("Arrived", true)

	-- Se abren las puertas y cada quien sube manteniendo E (server/Boarding); con un caído en hombros suben los dos
	Boarding.open(van)
	setStage("Extraction", "Get in the van! Hold E at the door", "Board")
	local reached = waitUntil(function()
		return Boarding.count() > 0
	end, true)
	if not reached then
		return false
	end

	-- Margen para que lleguen los demás; la van sale al subir todos o al acabarse
	setStage("Extraction", "Run to the van!", "Run")
	local started = os.clock()
	while os.clock() - started < Config.Game.VanGrace and not Boarding.allBoarded(livingPlayers()) do
		task.wait(0.25)
	end
	Boarding.close()

	-- La van arranca: puertas cerradas, marcha atrás, giro y a toda velocidad (client/VanAnimator); la victoria sale mientras se va
	setStage("Extraction", "Go, go, go!", "Run")
	Boarding.depart()
	task.wait(Config.Boarding.ResultAfter)
	return true
end

-- Mapa nuevo, tramo 3: cruzar la terminal hasta la puerta del estadio (emboscada con Tanque en el camino)
local function zone3()
	setStage("Zone3", map.texts.zone3, "Stadium")
	PlayerState.resetSelfRevives()
	Director.setZone("Zone3")
	WeaponBox.place("Zone3")
	Ambushes.arm(map.ambushesZone3)
	local ok = waitUntil(function()
		return allInside(map.extractionArea or map.stadiumInside or map.stadiumVolume)
	end, true)
	if ok then
		Points.add(Config.Points.ZoneComplete)
	end
	return ok
end

-- Cuántas veces han caído o muerto los jugadores en total (para saber si una oleada se limpió sin caídas)
local function downsTotal()
	local total = 0
	for _, entry in Stats.all() do
		total += entry.downs + entry.deaths
	end
	return total
end

-- Pausa entre oleadas con cuenta atrás en pantalla (WaveBreakEnd). Devuelve false si el equipo cae.
local function waveBreak(seconds, message)
	local finish = workspace:GetServerTimeNow() + seconds
	workspace:SetAttribute("WaveBreakEnd", finish)
	workspace:SetAttribute("WaveLeft", nil)
	setStage("WaveBreak", message, "Survival")
	return waitUntil(function()
		return workspace:GetServerTimeNow() >= finish
	end, true)
end

-- Modo Survival: el equipo aparece en el estadio y aguanta oleadas cada vez peores hasta que caen todos. Los muertos reaparecen al
-- empezar cada pausa. Devuelve la última oleada que se limpió (0 si cayeron en la primera).
local function survival()
	local S = Config.Survival
	resetRound()
	Director.setSurvival(true)
	Director.setZone("Survival")
	PlayerState.setSafePoint(map.survivalSpawn)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Ready", true)
	end
	respawn(false)
	runStart = os.clock()
	reachedZone2 = false
	WeaponBox.place("Survival")
	for _, key in { "generatorPrompt", "radioPrompt", "gatePrompt" } do
		if map[key] then
			map[key].Enabled = false -- los eventos del modo historia no se usan aquí
		end
	end

	-- Espera a que todos tengan personaje (si no, el equipo parece vencido de entrada)
	local loadDeadline = os.clock() + 20
	while os.clock() < loadDeadline do
		local loaded = #Players:GetPlayers() > 0
		for _, player in Players:GetPlayers() do
			if PlayerState.get(player) == "Dead" or not getRoot(player) then
				loaded = false
			end
		end
		if loaded then
			break
		end
		task.wait(0.25)
	end

	local reached = 0
	local wave = 0
	local alive = waveBreak(S.FirstWaveDelay, "Hold the stadium! The first wave is coming. Shop first")
	while alive do
		wave += 1
		local composition = SurvivalWaves.compose(wave, #Players:GetPlayers())
		Difficulty.setWaveScale(composition.health, composition.speed, composition.damage)
		PlayerState.resetSelfRevives()
		workspace:SetAttribute("Wave", wave)
		workspace:SetAttribute("WaveTotal", composition.total)
		workspace:SetAttribute("WaveLeft", composition.total)
		workspace:SetAttribute("WaveBoss", composition.boss)
		workspace:SetAttribute("WaveBreakEnd", nil)
		if composition.boss then
			setStage("Wave", `Wave {wave}: boss wave! Something big is coming`, "Boss")
			playGlobal(Config.Sounds.HordeSiren, Config.Sounds.Volume.Siren, 10)
		else
			setStage("Wave", `Wave {wave}: here they come!`, "Wave")
		end
		Telemetry.wave(wave, #Players:GetPlayers())

		-- Suelta la oleada respetando el máximo de vivos; termina al caer todos los zombies (o si el equipo cae)
		local queue = table.clone(composition.kinds)
		local downsBefore = downsTotal()
		local allSpawnedAt = nil
		while true do
			if #Players:GetPlayers() == 0 or teamWiped() then
				alive = false
				break
			end
			local living = Zombies.getAlive()
			if #queue > 0 and living < composition.cap then
				local kind = table.remove(queue, 1)
				if Director.spawnKind(kind) then
					task.wait(S.SpawnDelay)
				else
					table.insert(queue, kind) -- sin hueco para ese tipo o sin punto libre: lo intenta más tarde
					task.wait(S.SpawnRetry)
				end
			else
				if #queue == 0 then
					allSpawnedAt = allSpawnedAt or os.clock()
					if living == 0 then
						break
					end
					local waited = os.clock() - allSpawnedAt
					if (living <= 3 and waited > S.StragglerTime) or waited > S.StragglerTime * 2 then
						Zombies.clear() -- alguno quedó atascado fuera de alcance: la oleada se da por limpia
						break
					end
				end
				task.wait(0.25)
			end
			workspace:SetAttribute("WaveLeft", #queue + Zombies.getAlive())
		end
		if not alive then
			break
		end

		-- Oleada limpia: latas del equipo, los muertos vuelven y, cada tanto, se reponen los suministros
		reached = wave
		local bonus = S.WaveBonus.Base + S.WaveBonus.PerWave * wave
		local clean = downsTotal() == downsBefore
		if clean then
			bonus += S.WaveBonus.Clean
		end
		Points.add(bonus)
		respawn(true)
		local supplies = wave % S.SuppliesEvery == 0
		if supplies then
			Weapons.refillAll()
			CanPiles.reset()
			Medkits.reset()
			Pharmacy.restock()
		end
		local message = supplies and `Wave {wave} cleared! +{bonus} cans. Supplies restocked, regroup at the shop`
			or `Wave {wave} cleared! +{bonus} cans. Regroup at the shop`
		alive = waveBreak(composition.boss and S.BossBreakTime or S.BreakTime, message)
	end

	Director.setSurvival(false)
	Director.setZone(nil)
	Difficulty.setWaveScale(1, 1, 1)
	return reached
end

local function result(won, waves)
	Director.setZone(nil)
	Director.setSurvival(false)
	Ambushes.disarm()
	Director.setBoost(false)
	Difficulty.setWaveScale(1, 1, 1)
	Zombies.clear()
	WeaponBox.clear()
	clearWaveAttributes()
	local isSurvival = waves ~= nil -- Survival: `waves` = oleadas que aguantó el equipo (no hay victoria, solo récord)
	if isSurvival then
		setStage("Result", `You held out {waves} waves`, "Defeat")
	else
		setStage("Result", won and "Victory!" or "Defeat", won and "Victory" or "Defeat")
	end
	local stats = Stats.all()
	Remotes.Results:FireAllClients(won, stats, Awards.compute(stats), isSurvival and { waves = waves } or nil)
	-- Récord de oleadas (Survival): por número de jugadores; el DataStore tarda, así que se avisa aparte cuando contesta
	if isSurvival then
		local names = {}
		for _, entry in stats do
			table.insert(names, entry.name)
		end
		local teamSize = math.clamp(#Players:GetPlayers(), 1, 4)
		task.spawn(function()
			Remotes.Record:FireAllClients(Records.submitWaves(teamSize, waves, names))
		end)
	end
	-- Récord de extracción rápida: solo cuenta ganar; el DataStore tarda, así que se avisa aparte cuando contesta
	if won and runStart then
		local seconds = os.clock() - runStart
		local names = {}
		for _, entry in stats do
			table.insert(names, entry.name)
		end
		local difficultyId = Difficulty.id()
		task.spawn(function()
			Remotes.Record:FireAllClients(Records.submit(difficultyId, seconds, names))
		end)
	end
	PlayerProgress.award(won, reachedZone2, waves)
	Telemetry.result(won)

	-- Cuenta atrás hasta la siguiente partida (la pantalla de resultados la muestra). Si todos los que quedan pulsan OTRA PARTIDA
	-- (tras unos segundos para leer), se adelanta.
	for _, player in Players:GetPlayers() do
		player:SetAttribute("PlayAgain", false)
	end
	local startedAt = os.clock()
	workspace:SetAttribute("ResultEnd", workspace:GetServerTimeNow() + Config.Game.ResultTime)
	local function everyoneAgain()
		local list = Players:GetPlayers()
		for _, player in list do
			if not player:GetAttribute("PlayAgain") then
				return false
			end
		end
		return #list > 0
	end
	while os.clock() - startedAt < Config.Game.ResultTime do
		task.wait(0.25)
		if os.clock() - startedAt >= Config.Game.ResultMinTime and everyoneAgain() then
			break
		end
	end
	workspace:SetAttribute("ResultEnd", nil)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("PlayAgain", nil)
	end
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

	Remotes.PlayAgain.OnServerEvent:Connect(function(player)
		if stage == "Result" and RateLimit.check(player, "PlayAgain", 0.5) then
			player:SetAttribute("PlayAgain", true)
		end
	end)

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
			if workspace:GetAttribute("MapId") == "Survival" then
				result(false, survival())
				continue
			end
			lobby()
			local won = zone1() and safeRoom({ entryDoor = map.safeEntryDoor, exitDoor = map.safeExitDoor, extraExits = map.safeExtraExits, spawn = map.safeSpawn })
			if won then
				local second = map.safe2 or map.church
				if second then
					-- Evento del sector 2 -> horda -> segundo punto seguro -> descanso -> sector 3 -> extracción
					won = zone2() and safeRoom({ entryDoor = map.gate, exitDoor = second.exitDoor, extraExits = second.extraExits, spawn = second.spawn }) and zone3() and extraction()
				else
					won = zone2() and extraction()
				end
			end
			result(won)
		end
	end)
end

return GameState
