-- Sala de votación del mapa: una sala cerrada y aparte (muy arriba, sin zombies) con un podio y un cartel por mapa
-- (Config.Maps). Se vota acercándose a un podio y pulsando E; se puede cambiar el voto hasta que termine el tiempo
-- (Config.Vote.Time) o hasta que todos hayan votado. Empate = al azar; sin ningún voto gana Config.Vote.NoVotes.
-- El decorado viene de assets/zona-votacion.glb (ZombieData/ZonaVotacion, generado); los textos de los carteles son
-- SurfaceGui vivos (votos, tiempo). GameState llama a VoteRoom.build() una vez y a VoteRoom.run() al inicio de cada ronda.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Difficulties = require(ReplicatedStorage.Shared.Difficulties)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Progress = require(ReplicatedStorage.Shared.Progress)
local RateLimit = require(script.Parent.RateLimit)

local VoteRoom = {}

local ORIGIN_Y = 800 -- la sala está muy por encima del mapa
local pixelScale = 1 -- se ajusta al tamaño de la sala para que los carteles no pasen del límite de píxeles
local built = nil -- { spawn, options = { { map, prompt, countLabel } }, timeLabels }

local RED = Color3.fromRGB(226, 38, 44)
local PALE = Color3.fromRGB(245, 226, 222)
local BLACK = Color3.fromRGB(12, 12, 12)
local PREFIX = { Prueba = "prueba", Morro = "morro" } -- id del mapa -> prefijo de sus piezas en ZonaVotacion

local function label(parent, text, size, position, font, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = font
	if font == Enum.Font.Oswald then
		l.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold) -- letra condensada y gruesa como el diseño
	end
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
end

-- SurfaceGui en la cara que mira a los jugadores (la cara frontal del modelo original es Back en Roblox)
local function face(part, pixelsPerStud, background)
	part.Color = background or BLACK
	part.Material = Enum.Material.SmoothPlastic
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud * pixelScale
	gui.LightInfluence = 0.1
	gui.Parent = part
	return gui
end

local function rect(parent, size, position, color)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = color
	f.Parent = parent
	return f
end

local function addLight(part, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = part
end

-- Cartel del mapa: descripción y nombre, negro con letras rojas.
-- Devuelve el texto donde se muestran los votos.
local function mapBoard(part, map)
	local main, soft = RED, PALE
	local gui = face(part, 60, Color3.fromRGB(14, 14, 14))
	rect(gui, UDim2.fromScale(0.92, 0.012), UDim2.fromScale(0.04, 0.05), main)
	rect(gui, UDim2.fromScale(0.92, 0.012), UDim2.fromScale(0.04, 0.94), main)
	local count = Instance.new("TextLabel") -- ya no se vota el mapa (solo hay uno): el texto no se muestra
	local desc = label(gui, map.desc, UDim2.fromScale(0.84, 0.22), UDim2.fromScale(0.08, 0.34), Enum.Font.GothamBold, soft)
	desc.TextWrapped = true
	rect(gui, UDim2.fromScale(0.78, 0.008), UDim2.fromScale(0.11, 0.6), main)
	label(gui, string.upper(map.name), UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.64), Enum.Font.Oswald, main)
	label(gui, "M A P A", UDim2.fromScale(0.3, 0.05), UDim2.fromScale(0.35, 0.86), Enum.Font.Oswald, soft)
	return count
end

function VoteRoom.build()
	if built then
		return built
	end
	local data = require(script.Parent.ZombieData.ZonaVotacion)
	-- Modelo persistente: con StreamingEnabled el cliente siempre lo tiene cargado, si no el personaje cae por el suelo
	-- que aún no ha llegado (la sala está 800 studs por encima del mapa)
	local folder = Instance.new("Model")
	folder.Name = "VoteRoom"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	folder.Parent = workspace
	local origin = CFrame.new(0, ORIGIN_Y, 0)

	local named = {}
	for _, d in data.parts do
		local p = Instance.new("Part")
		p.Name = d.name
		p.Anchored = true
		p.Size = d.size
		p.CFrame = origin * d.cf
		p.Color = d.color
		p.Material = d.neon and Enum.Material.Neon or Enum.Material.Concrete
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		-- Solo el suelo, las paredes y los escalones de los podios se pisan; el resto del decorado no estorba
		p.CanCollide = d.name == "suelo" or d.name:find("^pared") ~= nil or d.name:find("_escalon$") ~= nil
		p.CanQuery = p.CanCollide
		if d.shape == "Ball" then
			p.Shape = Enum.PartType.Ball
		elseif d.shape == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
		end
		p.Parent = folder
		named[d.name] = p
	end

	-- Solo hay un mapa: el podio de Morro Esperanza (negro con neón rojo tenue, como era el de Prueba) queda de cartel
	for name, part in named do
		local twin = name:match("^morro_(base)$") or name:match("^morro_(franja_%d+)$") or name:match("^morro_(neon_%a)$")
		if twin and named["prueba_" .. twin] then
			part.Color = named["prueba_" .. twin].Color
		end
	end
	for name, part in named do
		if name:find("^prueba_") then
			part:Destroy()
			named[name] = nil
		end
	end

	-- Recinto cerrado alrededor del decorado (el modelo original está abierto por delante y por arriba)
	local function wall(name, size, position)
		local w = Instance.new("Part")
		w.Name = name
		w.Anchored = true
		w.Size = size
		w.Position = position + Vector3.new(0, ORIGIN_Y, 0)
		w.Color = Color3.fromRGB(24, 22, 22)
		w.Material = Enum.Material.Concrete
		w.TopSurface = Enum.SurfaceType.Smooth
		w.BottomSurface = Enum.SurfaceType.Smooth
		w.Parent = folder
	end
	-- Paredes, techo y piso de 6 de grosor: así la cámara nunca atraviesa el recinto y ve el vacío
	local k = data.scale / 3
	pixelScale = 1.5 / k
	local bx, bz = data.bounds.max.X, data.bounds.max.Z
	local height, T = 6 * data.scale, 6
	wall("RecintoFrente", Vector3.new(2 * bx + 2 * T, height + 2 * T, T), Vector3.new(0, height / 2, -bz - T / 2))
	wall("RecintoFondo", Vector3.new(2 * bx + 2 * T, height + 2 * T, T), Vector3.new(0, height / 2, bz + T / 2))
	wall("RecintoOeste", Vector3.new(T, height + 2 * T, 2 * bz), Vector3.new(-bx - T / 2, height / 2, 0))
	wall("RecintoEste", Vector3.new(T, height + 2 * T, 2 * bz), Vector3.new(bx + T / 2, height / 2, 0))
	wall("RecintoTecho", Vector3.new(2 * bx + 2 * T, T, 2 * bz + 2 * T), Vector3.new(0, height + 0.5 + T / 2, 0))
	wall("RecintoPiso", Vector3.new(2 * bx + 2 * T, T, 2 * bz + 2 * T), Vector3.new(0, -0.9 - T / 2, 0))

	-- Título
	local title = face(named.letrero_cara, 40)
	rect(title, UDim2.fromScale(1, 0.03), UDim2.fromScale(0, 0), RED)
	rect(title, UDim2.fromScale(1, 0.03), UDim2.fromScale(0, 0.97), RED)
	label(title, "CHOOSE WITH KEYS 1 TO 4 · YOU CAN CHANGE YOUR VOTE", UDim2.fromScale(0.78, 0.13), UDim2.fromScale(0.11, 0.06), Enum.Font.Oswald, PALE)
	rect(title, UDim2.fromScale(0.78, 0.012), UDim2.fromScale(0.11, 0.22), RED)
	label(title, "VOTE ON THE DIFFICULTY", UDim2.fromScale(0.82, 0.46), UDim2.fromScale(0.09, 0.27), Enum.Font.Oswald, RED)
	label(title, "DAY 01  ·  SAFE ZONE", UDim2.fromScale(0.4, 0.1), UDim2.fromScale(0.3, 0.8), Enum.Font.Oswald, RED)

	-- Pantalla del tótem, agrandada, con el tiempo en números rojos grandes para que todos lo vean
	local screen = named.totem_pantalla
	screen.Size = Vector3.new(7 * k, 5 * k, 0.1)
	screen.CFrame = origin * CFrame.new(0, 3.9 * k, screen.Position.Z) * CFrame.Angles(0, math.pi, 0)
	local timeLabels = {}
	local timeGui = face(screen, 20) -- pocos píxeles por stud: TextScaled no pasa de 100 y así los números salen enormes
	rect(timeGui, UDim2.fromScale(1, 0.04), UDim2.fromScale(0, 0), RED)
	rect(timeGui, UDim2.fromScale(1, 0.04), UDim2.fromScale(0, 0.96), RED)
	rect(timeGui, UDim2.fromScale(0.02, 1), UDim2.fromScale(0, 0), RED)
	rect(timeGui, UDim2.fromScale(0.02, 1), UDim2.fromScale(0.98, 0), RED)
	label(timeGui, "TIME TO VOTE", UDim2.fromScale(0.8, 0.12), UDim2.fromScale(0.1, 0.07), Enum.Font.Oswald, PALE)
	table.insert(timeLabels, label(timeGui, tostring(Config.Vote.Time), UDim2.fromScale(0.9, 0.7), UDim2.fromScale(0.05, 0.2), Enum.Font.Oswald, RED))
	addLight(screen, Color3.fromRGB(255, 40, 40), 30 * k, 1)

	-- Luces: bombillas del fondo y fogatas de los barriles
	for i = 0, 3 do
		addLight(named["bombilla_" .. i], Color3.fromRGB(255, 205, 150), 40 * k, 1.2)
	end
	for _, name in { "llama_a_0", "llama_b_0" } do
		addLight(named[name], Color3.fromRGB(255, 120, 40), 26 * k, 1.8)
	end

	-- Un podio por mapa: placa con la tecla, cartel con los votos y un prompt de votación
	local options = {}
	for _, map in Config.Maps do
		local prefix = PREFIX[map.id]
		local base = prefix and named[prefix .. "_base"]
		if not base then
			warn(`VoteRoom: el mapa {map.id} no tiene podio en ZonaVotacion`)
			continue
		end
		local count = mapBoard(named[prefix .. "_cartel_cara"], map)
		local key = face(named[prefix .. "_placa"], 100, RED)
		label(key, "E", UDim2.fromScale(0.7, 0.8), UDim2.fromScale(0.15, 0.1), Enum.Font.Oswald, BLACK)
		addLight(base, Color3.fromRGB(255, 40, 40), 18 * k, 0.9)

		local hitbox = Instance.new("Part")
		hitbox.Name = "Hitbox" .. map.id
		hitbox.Anchored = true
		hitbox.Size = Vector3.new(11 * k, 6 * k, 9 * k)
		hitbox.Position = base.Position + Vector3.new(0, 2.5, 0)
		hitbox.Transparency = 1
		hitbox.CanCollide = false
		hitbox.CanQuery = false
		hitbox.Parent = folder
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Vote"
		prompt.ObjectText = map.name
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 12 * k
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Custom -- la interfaz la dibuja client/PromptUi
		prompt.Enabled = false
		prompt.Parent = hitbox
		table.insert(options, { map = map, prompt = prompt, countLabel = count })
	end

	built = {
		spawn = CFrame.lookAt(Vector3.new(0, ORIGIN_Y + 3, -11 * k), Vector3.new(0, ORIGIN_Y + 3, 12 * k)),
		options = options,
		timeLabels = timeLabels,
	}
	return built
end

local function tally(votes)
	local counts = {}
	for _, map in Config.Maps do
		counts[map.id] = 0
	end
	for player, id in votes do
		if player.Parent == Players and counts[id] then
			counts[id] += 1
		end
	end
	return counts
end

-- Votos de dificultad: los publica en atributos para que el panel del cliente (client/DifficultyVote) los muestre
local function publishDifficultyVotes(votes)
	local counts = {}
	for _, id in Difficulties.Order do
		counts[id] = 0
	end
	for player, id in votes do
		if player.Parent == Players and counts[id] then
			counts[id] += 1
		end
	end
	for _, id in Difficulties.Order do
		workspace:SetAttribute("DiffVotes_" .. id, counts[id])
	end
	for _, player in Players:GetPlayers() do
		player:SetAttribute("DifficultyVote", votes[player])
	end
	return counts
end

-- Abre la votación y espera. `onTick(texto)` recibe el aviso con la cuenta atrás.
-- Devuelve (id del mapa ganador, id de la dificultad ganadora).
function VoteRoom.run(onTick)
	local room = VoteRoom.build()
	local votes = {}
	local difficultyVotes = {}
	local connections = {}
	table.insert(connections, Remotes.VoteDifficulty.OnServerEvent:Connect(function(player, id)
		-- Solo se puede votar una dificultad que el jugador ya tenga desbloqueada (por nivel)
		if Difficulties.isValid(id) and Progress.isUnlocked(id, player:GetAttribute("ProgXP")) and RateLimit.check(player, "VoteDifficulty", 0.2) then
			difficultyVotes[player] = id
		end
	end))

	local startedAt = os.clock()
	local allVotedAt = nil
	while true do
		local counts = tally(votes)
		for _, option in room.options do
			option.countLabel.Text = tostring(counts[option.map.id])
		end
		publishDifficultyVotes(difficultyVotes)

		local list = Players:GetPlayers()
		local voted = 0
		for _, player in list do
			if difficultyVotes[player] then
				voted += 1
			end
		end
		local left = math.max(math.ceil(Config.Vote.Time - (os.clock() - startedAt)), 0)
		local urgent = left <= 5 and math.floor(os.clock() * 2) % 2 == 0 -- los últimos 5 s parpadean
		for _, timeLabel in room.timeLabels do
			timeLabel.Text = tostring(left)
			timeLabel.TextColor3 = urgent and PALE or RED
		end
		onTick(`Vote on the difficulty with 1 to 4 ({voted}/{#list})`)

		if #list > 0 and voted == #list then
			allVotedAt = allVotedAt or os.clock()
			if os.clock() - allVotedAt >= Config.Vote.AfterAllVoted then
				break
			end
		else
			allVotedAt = nil
		end
		if left <= 0 then
			break
		end
		task.wait(0.25)
	end

	for _, connection in connections do
		connection:Disconnect()
	end
	for _, option in room.options do
		option.prompt.Enabled = false
	end

	-- Dificultad ganadora: la más votada; empate = al azar; sin votos = la de por defecto
	local diffCounts = publishDifficultyVotes(difficultyVotes)
	local diffBest, diffLeaders = 0, {}
	for _, id in Difficulties.Order do
		if diffCounts[id] > diffBest then
			diffBest, diffLeaders = diffCounts[id], { id }
		elseif diffCounts[id] == diffBest and diffBest > 0 then
			table.insert(diffLeaders, id)
		end
	end
	local difficulty = diffBest > 0 and diffLeaders[math.random(#diffLeaders)] or Difficulties.Default
	for _, id in Difficulties.Order do
		workspace:SetAttribute("DiffVotes_" .. id, nil)
	end
	for _, player in Players:GetPlayers() do
		player:SetAttribute("DifficultyVote", nil)
	end

	-- Mapa ganador: el que tiene más votos; empate = al azar; sin votos = Config.Vote.NoVotes
	local counts = tally(votes)
	local best, leaders = -1, {}
	for _, map in Config.Maps do
		if counts[map.id] > best then
			best, leaders = counts[map.id], { map.id }
		elseif counts[map.id] == best then
			table.insert(leaders, map.id)
		end
	end
	if best == 0 then
		return Config.Vote.NoVotes, difficulty
	end
	return leaders[math.random(#leaders)], difficulty
end

return VoteRoom
