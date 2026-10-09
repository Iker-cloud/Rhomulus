-- Sala de votación del mapa: una sala cerrada y aparte (muy arriba, sin zombies) con un podio y un cartel por mapa
-- (Config.Maps). Se vota acercándose a un podio y pulsando E; se puede cambiar el voto hasta que termine el tiempo
-- (Config.Vote.Time) o hasta que todos hayan votado. Empate = al azar; sin ningún voto gana Config.Vote.NoVotes.
-- GameState llama a VoteRoom.build() una vez y a VoteRoom.run() al inicio de cada ronda.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local VoteRoom = {}

local ORIGIN_Y = 800 -- la sala está muy por encima del mapa
local built = nil -- { spawn, options = { { map, prompt, countLabel } } }

local function part(parent, name, size, position, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(parent, text, size, position, font, color, textSize)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
end

-- Cartel con SurfaceGui en la cara frontal (-Z) de una pieza
local function board(parent, name, size, position, color)
	local p = part(parent, name, size, position, color, Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.Parent = p
	return p, gui
end

function VoteRoom.build()
	if built then
		return built
	end
	local folder = Instance.new("Folder")
	folder.Name = "VoteRoom"
	folder.Parent = workspace
	local y0 = ORIGIN_Y
	local wall = Color3.fromRGB(70, 66, 62)

	part(folder, "Piso", Vector3.new(64, 1, 44), Vector3.new(0, y0 - 0.5, 0), Color3.fromRGB(58, 54, 52))
	part(folder, "Techo", Vector3.new(64, 1, 44), Vector3.new(0, y0 + 17, 0), wall)
	part(folder, "MuroN", Vector3.new(64, 17, 1), Vector3.new(0, y0 + 8.5, 22), wall)
	part(folder, "MuroS", Vector3.new(64, 17, 1), Vector3.new(0, y0 + 8.5, -22), wall)
	part(folder, "MuroE", Vector3.new(1, 17, 44), Vector3.new(32, y0 + 8.5, 0), wall)
	part(folder, "MuroO", Vector3.new(1, 17, 44), Vector3.new(-32, y0 + 8.5, 0), wall)
	for _, x in { -18, 0, 18 } do
		local lamp = part(folder, "Lampara", Vector3.new(4, 0.4, 1.5), Vector3.new(x, y0 + 16.4, 0), Color3.fromRGB(255, 225, 170), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 150)
		light.Range = 36
		light.Brightness = 1.6
		light.Parent = lamp
	end

	-- Título
	local _, titleGui = board(folder, "Titulo", Vector3.new(26, 4, 0.4), Vector3.new(0, y0 + 13.5, 21.3), Color3.fromRGB(20, 18, 18))
	label(titleGui, "VOTEN EL MAPA", UDim2.fromScale(0.94, 0.8), UDim2.fromScale(0.03, 0.1), Enum.Font.GothamBlack, Color3.fromRGB(255, 205, 60))
	local _, hintGui = board(folder, "Ayuda", Vector3.new(34, 2.4, 0.4), Vector3.new(0, y0 + 10, 21.3), Color3.fromRGB(20, 18, 18))
	label(hintGui, "Acércate a un podio y presiona E (puedes cambiar tu voto)", UDim2.fromScale(0.96, 0.8), UDim2.fromScale(0.02, 0.1), Enum.Font.GothamMedium, Color3.fromRGB(220, 215, 205))

	-- Un podio con su cartel por mapa
	local options = {}
	local count = #Config.Maps
	for i, map in Config.Maps do
		local x = (i - (count + 1) / 2) * 22
		part(folder, "Podio" .. map.id, Vector3.new(12, 1, 8), Vector3.new(x, y0 + 0.5, 12), map.color, Enum.Material.SmoothPlastic)
		local _, gui = board(folder, "Cartel" .. map.id, Vector3.new(16, 8, 0.4), Vector3.new(x, y0 + 5.5, 16.5), map.color)
		label(gui, string.upper(map.name), UDim2.fromScale(0.92, 0.3), UDim2.fromScale(0.04, 0.05), Enum.Font.GothamBlack, Color3.new(1, 1, 1))
		local desc = label(gui, map.desc, UDim2.fromScale(0.9, 0.3), UDim2.fromScale(0.05, 0.36), Enum.Font.GothamMedium, Color3.fromRGB(250, 245, 235))
		desc.TextWrapped = true
		local countLabel = label(gui, "0 votos", UDim2.fromScale(0.9, 0.24), UDim2.fromScale(0.05, 0.72), Enum.Font.GothamBlack, Color3.fromRGB(255, 235, 150))

		local hitbox = part(folder, "Hitbox" .. map.id, Vector3.new(12, 6, 8), Vector3.new(x, y0 + 4, 12), Color3.new(1, 1, 1))
		hitbox.Transparency = 1
		hitbox.CanCollide = false
		hitbox.CanQuery = false
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Votar"
		prompt.ObjectText = map.name
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Custom -- la interfaz la dibuja client/PromptUi
		prompt.Enabled = false
		prompt.Parent = hitbox
		table.insert(options, { map = map, prompt = prompt, countLabel = countLabel })
	end

	built = { spawn = CFrame.lookAt(Vector3.new(0, y0 + 3, -12), Vector3.new(0, y0 + 3, 12)), options = options }
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

-- Abre la votación y espera. `onTick(texto)` recibe el aviso con la cuenta atrás. Devuelve el id del mapa ganador.
function VoteRoom.run(onTick)
	local room = VoteRoom.build()
	local votes = {}
	local connections = {}
	for _, option in room.options do
		option.prompt.Enabled = true
		table.insert(connections, option.prompt.Triggered:Connect(function(player)
			votes[player] = option.map.id
		end))
	end

	local startedAt = os.clock()
	local allVotedAt = nil
	while true do
		local counts = tally(votes)
		for _, option in room.options do
			local n = counts[option.map.id]
			option.countLabel.Text = n == 1 and "1 voto" or `{n} votos`
		end

		local list = Players:GetPlayers()
		local voted = 0
		for _, player in list do
			if votes[player] then
				voted += 1
			end
		end
		local left = math.ceil(Config.Vote.Time - (os.clock() - startedAt))
		onTick(`Voten el mapa en los podios con E ({voted}/{#list}) · {math.max(left, 0)} s`)

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

	-- Ganador: el que tiene más votos; empate = al azar; sin votos = Config.Vote.NoVotes
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
		return Config.Vote.NoVotes
	end
	return leaders[math.random(#leaders)]
end

return VoteRoom
