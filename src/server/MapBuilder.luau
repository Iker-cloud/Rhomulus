-- Mapa de la ciudad abandonada en bloques grises, generado por código para que viaje en git.
-- Es el pase "gris" del GDD: sirve para probar que la partida es divertida antes del pase de arte.
--
-- Eje de la partida (z creciente): Lobby -> Zona 1 -> Punto seguro -> Zona 2 (generador, portón) -> Extracción.
-- El suelo es la Baseplate (cara superior en y = 0).
local MapBuilder = {}

local GRAY = Color3.fromRGB(110, 110, 115)
local DARK = Color3.fromRGB(70, 70, 75)

local ZONES = {
	{ name = "Zone1", z1 = -210, z2 = -90 },
	{ name = "Zone2", z1 = -60, z2 = 78 },
	{ name = "Extraction", z1 = 82, z2 = 246 },
}

local function block(parent, name, size, center, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = center
	part.Color = color or GRAY
	part.Material = Enum.Material.Concrete
	part.Parent = parent
	return part
end

-- Bloque apoyado en el suelo entre x1..x2 y z1..z2
local function slab(parent, name, x1, x2, z1, z2, height, color)
	return block(parent, name, Vector3.new(x2 - x1, height, z2 - z1), Vector3.new((x1 + x2) / 2, height / 2, (z1 + z2) / 2), color)
end

-- Zona invisible para detectar jugadores dentro
local function volume(parent, name, x1, x2, z1, z2, height)
	local part = slab(parent, name, x1, x2, z1, z2, height)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

local function marker(parent, position)
	local part = Instance.new("Part")
	part.Name = "SpawnPoint"
	part.Anchored = true
	part.Size = Vector3.one
	part.Position = position + Vector3.new(0, 0.5, 0)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

local function door(parent, name, z, width, height)
	local part = block(parent, name, Vector3.new(width, height, 2), Vector3.new(0, height / 2, z), Color3.fromRGB(150, 110, 60))
	part.Material = Enum.Material.Metal
	return part
end

local function prompt(part, action, holdTime)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.HoldDuration = holdTime
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Enabled = false
	p.Parent = part
	return p
end

-- Letrero visible a través de paredes sobre un objetivo
local function label(part, text, color, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 36)
	gui.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = maxDistance or 35 -- solo se lee de cerca
	gui.Parent = part

	local text_ = Instance.new("TextLabel")
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.Font = Enum.Font.GothamBold
	text_.TextScaled = true
	text_.TextColor3 = color
	text_.TextStrokeTransparency = 0.3
	text_.Text = text
	text_.Parent = gui
end

function MapBuilder.build(config)
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local oldSpawns = workspace:FindFirstChild("SpawnPoints")
	if oldSpawns then
		oldSpawns:Destroy()
	end

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	local spawnRoot = Instance.new("Folder")
	spawnRoot.Name = "SpawnPoints"
	spawnRoot.Parent = workspace
	local spawnFolders = {}
	for _, zone in ZONES do
		local folder = Instance.new("Folder")
		folder.Name = zone.name
		folder.Parent = spawnRoot
		spawnFolders[zone.name] = folder
	end

	local rng = Random.new(config.Seed)
	local refs = {}

	-- Límites de la ciudad
	slab(map, "WallW", -72, -70, -250, 250, 30, DARK)
	slab(map, "WallE", 70, 72, -250, 250, 30, DARK)
	slab(map, "WallN", -72, 72, -250, -248, 30, DARK)
	slab(map, "WallS", -72, 72, 248, 250, 30, DARK)

	-- Lobby: cuarto cerrado al inicio de la calle
	slab(map, "LobbyBlockW", -70, -15, -248, -210, 20)
	slab(map, "LobbyBlockE", 15, 70, -248, -210, 20)
	refs.lobbyDoor = door(map, "LobbyDoor", -210, 30, 14)
	refs.lobbySpawn = CFrame.lookAt(Vector3.new(0, 3, -225), Vector3.new(0, 3, -200))

	-- Punto seguro: bloques a los lados, techo y dos puertas
	slab(map, "SafeBlockW", -70, -15, -90, -60, 20)
	slab(map, "SafeBlockE", 15, 70, -90, -60, 20)
	block(map, "SafeRoof", Vector3.new(30, 1, 30), Vector3.new(0, 20.5, -75))
	refs.safeEntryDoor = door(map, "SafeEntryDoor", -90, 30, 14)
	refs.safeExitDoor = door(map, "SafeExitDoor", -60, 30, 14)
	refs.safeVolume = volume(map, "SafeVolume", -15, 15, -88, -62, 12)
	refs.safeSpawn = CFrame.lookAt(Vector3.new(0, 3, -75), Vector3.new(0, 3, -50))

	-- Portón entre la zona 2 y la extracción
	slab(map, "GateBlockW", -70, -20, 78, 82, 20)
	slab(map, "GateBlockE", 20, 70, 78, 82, 20)
	refs.gate = door(map, "Gate", 80, 40, 16)

	-- Edificios a los lados de la calle, con callejones donde aparecen los zombies
	for _, zone in ZONES do
		for _, side in { -1, 1 } do
			local z = zone.z1
			while z < zone.z2 do
				local length = math.min(rng:NextInteger(18, 30), zone.z2 - z)
				local height = rng:NextInteger(15, 35)
				local x1, x2 = 25, 65
				if side == -1 then
					x1, x2 = -65, -25
				end
				slab(map, "Building", x1, x2, z, z + length, height)
				z += length

				if z < zone.z2 - 8 then
					marker(spawnFolders[zone.name], Vector3.new(side * 50, 0, z + 4))
					z += 8
				end
			end
		end
	end

	-- Relleno de aceras (x 20..25) para que no haya huecos por donde colarse al callejón
	for _, zone in ZONES do
		slab(map, "SidewalkW", -25, -20, zone.z1, zone.z2, 1, DARK)
		slab(map, "SidewalkE", 20, 25, zone.z1, zone.z2, 1, DARK)
	end

	-- Autos chocados como obstáculos en la calle
	local function cars(z1, z2, count)
		for _ = 1, count do
			local car = block(
				map,
				"Car",
				Vector3.new(6, 4, 12),
				Vector3.new(rng:NextInteger(-16, 16), 2, rng:NextInteger(z1 + 8, z2 - 8)),
				Color3.fromRGB(rng:NextInteger(60, 140), rng:NextInteger(60, 120), rng:NextInteger(60, 120))
			)
			car.CFrame *= CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), 0)
		end
	end
	cars(-210, -90, 9)
	cars(82, 246, 9)

	-- Zona 2: barreras en zigzag para formar pasillos
	block(map, "Barrier", Vector3.new(26, 6, 2), Vector3.new(-7, 3, -38))
	block(map, "Barrier", Vector3.new(26, 6, 2), Vector3.new(7, 3, -14))
	block(map, "Barrier", Vector3.new(26, 6, 2), Vector3.new(-7, 3, 10))

	-- Generador (evento que activa la horda y abre el portón)
	refs.generator = block(map, "Generator", Vector3.new(4, 5, 4), Vector3.new(0, 2.5, 45), Color3.fromRGB(190, 160, 40))
	refs.generator.Material = Enum.Material.Neon
	refs.generatorPrompt = prompt(refs.generator, "Encender generador", config.GeneratorHoldTime)
	label(refs.generator, "▼ GENERADOR", Color3.fromRGB(255, 220, 90))

	-- Entrada de la extracción
	refs.extractionVolume = volume(map, "ExtractionVolume", -20, 20, 86, 120, 12)

	-- Radio para llamar el rescate
	refs.radio = block(map, "Radio", Vector3.new(3, 4, 3), Vector3.new(0, 2, 100), Color3.fromRGB(90, 220, 110))
	refs.radio.Material = Enum.Material.Neon
	refs.radioPrompt = prompt(refs.radio, "Llamar al rescate", config.RadioHoldTime)
	label(refs.radio, "▼ RADIO", Color3.fromRGB(120, 255, 140))

	-- Van de extracción
	refs.vanStart = CFrame.new(0, 3.5, 236)
	refs.vanStop = CFrame.new(0, 3.5, 175)
	refs.vanVolume = volume(map, "VanVolume", -12, 12, 165, 185, 12)

	-- Estaciones de munición (una por zona, en la acera)
	refs.ammoStations = {}
	for _, spot in { Vector3.new(17, 0, -150), Vector3.new(17, 0, 30), Vector3.new(17, 0, 130) } do
		local station = block(map, "AmmoStation", Vector3.new(3, 4, 2), spot + Vector3.new(0, 2, 0), Color3.fromRGB(70, 130, 220))
		station.Material = Enum.Material.Neon
		label(station, "▼ MUNICIÓN", Color3.fromRGB(120, 180, 255), 25)
		table.insert(refs.ammoStations, { part = station, prompt = prompt(station, "Comprar munición", 0.5) })
	end

	-- Lugares posibles de la caja de armas: libres de obstáculos, dentro de la calle de cada zona
	refs.boxSpots = {}
	local boxRanges = {
		Zone1 = { -195, -105 },
		Zone2 = { -50, 70 },
		Extraction = { 95, 160 },
	}
	for zoneName, range in boxRanges do
		local spots = {}
		for _ = 1, 60 do
			local spot = Vector3.new(rng:NextInteger(-14, 14), 0, rng:NextInteger(range[1], range[2]))
			local blocked = workspace:GetPartBoundsInBox(CFrame.new(spot + Vector3.new(0, 4, 0)), Vector3.new(9, 6, 7))
			if #blocked == 0 then
				table.insert(spots, spot)
			end
			if #spots >= 8 then
				break
			end
		end
		refs.boxSpots[zoneName] = spots
	end

	-- Puntos extra al final de la calle para la horda de extracción
	marker(spawnFolders.Extraction, Vector3.new(-8, 0, 240))
	marker(spawnFolders.Extraction, Vector3.new(8, 0, 240))

	return refs
end

-- La van llega desde el fondo de la calle (se crea solo al llamar el rescate)
function MapBuilder.makeVan()
	local model = Instance.new("Model")
	model.Name = "Van"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(8, 6, 16)
	body.Color = Color3.fromRGB(235, 235, 235)
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model

	local cab = Instance.new("Part")
	cab.Name = "Cab"
	cab.Size = Vector3.new(8, 4, 5)
	cab.Color = Color3.fromRGB(200, 200, 205)
	cab.Anchored = true
	cab.CanCollide = false
	cab.CFrame = body.CFrame * CFrame.new(0, -1, -10.5)
	cab.Parent = model

	model.PrimaryPart = body
	return model
end

return MapBuilder
