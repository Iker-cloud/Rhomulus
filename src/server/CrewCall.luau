-- Crew Call: el evento del sector 2 de Last Call (docs/mapa-2-aeropuerto.md). Tres tripulantes infectados (el Capitán, la
-- sobrecargo y el jefe de seguridad), uno en cada ruta, llevan las tarjetas de acceso del control de seguridad. Son zombies
-- comunes reforzados (Config.CrewCall) que no salen de su zona. Al caer sueltan su tarjeta, que se recoge con E; cada caída
-- hace ruido (atrae a los zombies cercanos y a una horda pequeña). Las tarjetas son del equipo: con las 3, GameState deja abrir
-- el control en su lector. El mapa los define en refs.crew: { members = { { id = "Captain", home = Vector3 }, ... },
-- hordePoints = { Vector3, ... } }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Difficulty = require(script.Parent.Difficulty)
local Director = require(script.Parent.Director)
local MapKit = require(script.Parent.MapKit)
local Points = require(script.Parent.Points)
local Zombies = require(script.Parent.Zombies)

local CrewCall = {}

local C = Config.CrewCall
local CARD_RED = Color3.fromRGB(255, 60, 50)

local data -- refs.crew del mapa en curso (nil en los mapas sin el evento)
local members = {} -- { info = entrada de Config.CrewCall.Members, home, state = "alive" | "card" | "taken", model, card }
local taken = 0
local token = 0 -- cambia al reiniciar: lo que quedara pendiente de la ronda anterior se ignora

local function infoOf(id)
	for _, info in C.Members do
		if info.id == id then
			return info
		end
	end
	return nil
end

local function attach(part, target)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CollisionGroup = "Zombie"
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = target
	weld.Part1 = part
	weld.Parent = part
	part.Parent = target.Parent
end

-- Uniforme: la ropa del zombie común pasa al color del tripulante, con la tarjeta colgada del pecho (luz roja) y un contorno
-- rojo que se ve a través de las paredes (así la guía lo marca). El Capitán lleva gorra.
local function dress(model, info)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and (part.Name == "camiseta" or string.find(part.Name, "manga", 1, true) or string.find(part.Name, "jiron", 1, true)) then
			part.Color = info.uniform
		end
	end
	local chest = model:FindFirstChild("pecho") or model:FindFirstChild("HumanoidRootPart")
	if chest then
		local card = Instance.new("Part")
		card.Name = "TarjetaAcceso"
		card.Size = Vector3.new(0.5, 0.7, 0.1)
		card.Color = info.trim
		card.Material = Enum.Material.Neon
		card.CFrame = chest.CFrame * CFrame.new(0.35, 0.1, -chest.Size.Z / 2 - 0.12)
		attach(card, chest)
		local light = Instance.new("PointLight")
		light.Color = CARD_RED
		light.Brightness = 2
		light.Range = 10
		light.Parent = card
	end
	local head = model:FindFirstChild("Head")
	if head and info.id == "Captain" then
		local cap = Instance.new("Part")
		cap.Name = "Gorra"
		cap.Size = Vector3.new(head.Size.X + 0.25, 0.35, head.Size.Z + 0.25)
		cap.Color = info.uniform
		cap.Material = Enum.Material.Fabric
		cap.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.1, 0)
		attach(cap, head)
		local visor = Instance.new("Part")
		visor.Name = "GorraVisera"
		visor.Size = Vector3.new(head.Size.X, 0.1, 0.4)
		visor.Color = info.trim
		visor.Material = Enum.Material.SmoothPlastic
		visor.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2, -head.Size.Z / 2 - 0.25)
		attach(visor, head)
	end
	local outline = Instance.new("Highlight")
	outline.Name = "MarcaTripulante"
	outline.FillTransparency = 1
	outline.OutlineColor = CARD_RED
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.Parent = model
end

-- La tarjeta en el suelo: flota, parpadea en rojo y se recoge con E
local function dropCard(member, position)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace:FindFirstChild("Zombies") }
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), params)
	local ground = hit and hit.Position or Vector3.new(position.X, 0, position.Z)

	local model = Instance.new("Model")
	model.Name = "AccessCard"
	local card = MapKit.deco(MapKit.block(model, "Tarjeta", Vector3.new(1.6, 1, 0.12), CFrame.new(ground + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, math.rad(35), math.rad(12)), member.info.trim, Enum.Material.Neon))
	MapKit.deco(MapKit.block(model, "TarjetaBanda", Vector3.new(1.62, 0.25, 0.14), card.CFrame * CFrame.new(0, 0.2, 0), Color3.fromRGB(30, 30, 34), Enum.Material.SmoothPlastic))
	local light = Instance.new("PointLight")
	light.Color = CARD_RED
	light.Brightness = 4
	light.Range = 16
	light.Parent = card
	local hitbox = MapKit.deco(MapKit.block(model, "Hitbox", Vector3.new(4, 4, 4), ground + Vector3.new(0, 2, 0)))
	hitbox.Transparency = 1
	MapKit.label(hitbox, "ACCESS CARD", CARD_RED, 40)
	local cardPrompt = MapKit.prompt(hitbox, "Take access card", C.PickupTime)
	cardPrompt.MaxActivationDistance = 12
	cardPrompt.Enabled = true
	model.Parent = workspace:FindFirstChild("Map") or workspace
	member.card = model
	member.cardPosition = card.Position

	local myToken = token
	task.spawn(function() -- la luz roja parpadea mientras la tarjeta siga en el suelo
		while model.Parent and myToken == token do
			light.Enabled = not light.Enabled
			task.wait(0.45)
		end
	end)
	cardPrompt.Triggered:Connect(function(player)
		if myToken ~= token or member.state ~= "card" then
			return
		end
		member.state = "taken"
		member.card = nil
		model:Destroy()
		taken += 1
		workspace:SetAttribute("CrewCards", taken)
		Points.add(C.CardReward, player)
		Points.feed(`{player.DisplayName} took an access card ({taken}/{#members})`)
	end)
end

local function onDeath(member, position)
	if member.state ~= "alive" then
		return
	end
	member.state = "card"
	member.model = nil
	dropCard(member, position)
	Points.add(C.Reward)
	Points.feed(`Crew member down: {member.info.display}. Grab the access card!`)
	-- El ruido de la pelea: los zombies cercanos van hacia allí y llega una horda pequeña
	Zombies.noise(position, C.NoiseRange, C.NoiseTime)
	task.spawn(Director.spawnAmbush, C.DeathHorde, data.hordePoints)
end

local function spawnMember(member)
	local base = Difficulty.zombieStats("Common") -- ya trae la dificultad y los mutadores
	local players = math.max(1, #Players:GetPlayers())
	local model = Zombies.spawn("Common", member.home, {
		Health = math.floor(C.Health * (base.Health / Config.Zombie.Common.Health) * (1 + C.HealthPerPlayer * (players - 1)) + 0.5),
		Speed = base.Speed * C.Speed,
		Damage = math.max(1, math.floor(base.Damage * C.Damage + 0.5)),
		DisplayName = member.info.display,
		ModelDetail = "full",
		Home = member.home, -- no sale de su zona (ver Zombies.think)
		LeashRadius = C.LeashRadius,
		PatrolRadius = C.PatrolRadius,
	})
	model:SetAttribute("Crew", member.info.id)
	dress(model, member.info)
	member.model = model
	member.state = "alive"
	local myToken = token
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.Died:Once(function()
		if myToken == token then
			local root = model:FindFirstChild("HumanoidRootPart")
			onDeath(member, root and root.Position or member.home)
		end
	end)
end

-- El mapa que se acaba de construir (nil = sin evento)
function CrewCall.init(crew)
	CrewCall.reset()
	data = crew
end

-- Fin de ronda o vuelta al lobby: se quitan los tripulantes y las tarjetas
function CrewCall.reset()
	token += 1
	for _, member in members do
		if member.card then
			member.card:Destroy()
		end
		if member.model and member.model.Parent then
			member.model:Destroy()
		end
	end
	table.clear(members)
	taken = 0
	workspace:SetAttribute("CrewCards", nil)
end

-- Empieza el evento: aparecen los tres tripulantes, cada uno en su puesto
function CrewCall.start()
	CrewCall.reset()
	if not data then
		return
	end
	for _, entry in data.members do
		local info = infoOf(entry.id)
		if info then
			local member = { info = info, home = entry.home, state = "alive" }
			table.insert(members, member)
			spawnMember(member)
		end
	end
	workspace:SetAttribute("CrewCards", 0)
end

function CrewCall.cards()
	return taken
end

function CrewCall.total()
	return #members
end

-- Tarjetas sueltas en el suelo, esperando a que alguien las recoja
function CrewCall.looseCards()
	local count = 0
	for _, member in members do
		-- Si el zombie desapareció sin morir (no debería), su tarjeta queda en su puesto: el evento nunca se bloquea
		if member.state == "alive" and not (member.model and member.model.Parent) then
			onDeath(member, member.home)
		end
		if member.state == "card" then
			count += 1
		end
	end
	return count
end

-- Hacia dónde manda la guía: la tarjeta suelta o el tripulante vivo más cercano a `from` (posición del equipo).
-- Devuelve (posición, nombre) o nil si ya están las tres.
function CrewCall.objective(from)
	local bestPosition, bestName, bestScore
	for _, member in members do
		local position, name
		if member.state == "card" and member.card then
			position, name = member.cardPosition, "ACCESS CARD"
		elseif member.state == "alive" and member.model then
			local root = member.model:FindFirstChild("HumanoidRootPart")
			position, name = root and root.Position, member.info.name
		end
		if position then
			-- una tarjeta suelta va antes que un tripulante vivo
			local score = (from and (position - from).Magnitude or 0) - (member.state == "card" and 1000 or 0)
			if not bestScore or score < bestScore then
				bestPosition, bestName, bestScore = position, name, score
			end
		end
	end
	return bestPosition, bestName
end

return CrewCall
