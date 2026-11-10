-- Mapa 2, Last Call: el aeropuerto internacional de Rhomulus (RHM). Diseño: docs/mapa-2-aeropuerto.md.
-- Mismo contrato que MapBuilderBarrio: build(config, options) deja Workspace/Map y Workspace/SpawnPoints y devuelve las
-- referencias que usan GameState y los demás sistemas (puertas, volúmenes, tiendas, puntos de aparición...).
--
-- La estructura (pisos, muros, techos, vallas y puntos de aparición) sale de la cuadrícula de server/AirportLayout; aquí se
-- colocan las puertas, las luces, los muebles, las Tiendas y lo que se recoge. Rutas: CONCOURSE (roja, el terminal por el centro),
-- SERVICE (amarilla, túneles al oeste) y APRON (azul, exterior al este). Recorrido: lobby (Lost & Found) -> sector 1 (Arrivals)
-- -> Sky Lounge -> sector 2 (Departures, evento Crew Call) -> Fire Station -> sector 3 (Gates & Hangars) -> plataforma y pista.
-- Ejes: X lateral, Y altura (suelo en 0), Z avance. Rótulos solo en inglés.
local CollectionService = game:GetService("CollectionService")

local AirportLayout = require(script.Parent.AirportLayout)
local MapKit = require(script.Parent.MapKit)
local PropModel = require(script.Parent.PropModel)
local Radio = require(script.Parent.ZombieData.Radio)

local MapBuilderAirport = {}

local L = AirportLayout
local C = MapKit.C
local FLOOR_TOP = MapKit.FLOOR_TOP
local RHO_BLACK = MapKit.RHO_BLACK
local hex = MapKit.hex
local block = MapKit.block
local slab = MapKit.slab
local deco = MapKit.deco
local floor = MapKit.floor
local pole = MapKit.pole
local volume = MapKit.volume
local marker = MapKit.marker
local prompt = MapKit.prompt
local label = MapKit.label
local car = MapKit.car
local crates = MapKit.crates
local barrel = MapKit.barrel
local boardText = MapKit.boardText
local boardRect = MapKit.boardRect
local blankBoard = MapKit.blankBoard
local canPile = MapKit.canPile
local medkitPickup = MapKit.medkitPickup
local yawFacing = MapKit.yawFacing

local WALL_H = 20 -- alto de los muros y del techo del terminal
local DOOR_H = 14

-- Paleta del aeropuerto: fría y gris, con los tres colores de ruta
local P = {
	wall = hex("#A7AEB5"),
	tile = hex("#C4C9CE"), -- piso del terminal
	serviceFloor = hex("#63666A"), -- piso de los túneles de servicio
	asphalt = hex("#34363B"),
	sidewalk = hex("#7B7F85"),
	ceiling = hex("#D5D9DD"),
	fence = hex("#474C52"),
	steel = hex("#6E757D"),
	dark = Color3.fromRGB(34, 36, 40),
	seat = hex("#2F4E79"),
	taxi = hex("#E7B416"),
	signYellow = hex("#F2C230"),
	tube = Color3.fromRGB(214, 232, 255), -- luz fluorescente
	mast = Color3.fromRGB(255, 214, 160), -- focos de la plataforma
	door = Color3.fromRGB(96, 104, 112),
	red = C.rojo, -- CONCOURSE
	yellow = C.amarillo, -- SERVICE
	blue = C.azul, -- APRON
}

---------------------------------------------------------------------------------------------------
-- Cuadrícula

local ROWS = L.ROWS

local function cell(row, col)
	local line = ROWS[row + 1]
	if not line or col < 0 or col >= #line then
		return " "
	end
	return string.sub(line, col + 1, col + 1)
end

local function band(col)
	return col <= 9 and "Service" or (col <= 17 and "Concourse" or "Apron")
end

-- Junta las celdas vecinas con la misma clave en rectángulos (menos piezas). `match(letra, fila, columna)` devuelve la clave o nil.
local function rects(match)
	local used, out = {}, {}
	local rowCount, colCount = #ROWS, #ROWS[1]
	local function key(row, col)
		if used[row * 100 + col] then
			return nil
		end
		return match(cell(row, col), row, col)
	end
	for row = 0, rowCount - 1 do
		for col = 0, colCount - 1 do
			local id = key(row, col)
			if id then
				local col2 = col
				while col2 + 1 < colCount and key(row, col2 + 1) == id do
					col2 += 1
				end
				local row2 = row
				while row2 + 1 < rowCount do
					local same = true
					for c = col, col2 do
						if key(row2 + 1, c) ~= id then
							same = false
							break
						end
					end
					if not same then
						break
					end
					row2 += 1
				end
				for r = row, row2 do
					for c = col, col2 do
						used[r * 100 + c] = true
					end
				end
				table.insert(out, { key = id, x1 = L.x(col), x2 = L.x(col2 + 1), z1 = L.z(row), z2 = L.z(row2 + 1), row = row, col = col })
			end
		end
	end
	return out
end

local function newFolder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

---------------------------------------------------------------------------------------------------
-- Piezas del aeropuerto

-- Tubo fluorescente en el techo: farol con la etiqueta NightLamp (Atmosphere decide si parpadea o está roto; NightLights lo anima)
local function tube(parent, position, range, brightness, alongZ)
	local bulb = deco(block(parent, "Tubo", alongZ and Vector3.new(0.9, 0.3, 5) or Vector3.new(5, 0.3, 0.9), position, P.tube, Enum.Material.Neon))
	local light = Instance.new("SpotLight")
	light.Name = "Luz"
	light.Face = Enum.NormalId.Bottom
	light.Angle = 140
	light.Color = P.tube
	light.Brightness = brightness or 2.2
	light.Range = range or 34
	light.Shadows = false
	light.Parent = bulb
	CollectionService:AddTag(bulb, "NightLamp")
	return bulb
end

-- Foco de la plataforma sobre un mástil (exterior)
local function mast(parent, x, z)
	deco(pole(parent, "Mastil", Vector3.new(x, 0, z), 18, 0.7, P.steel))
	local bulb = deco(block(parent, "FocoMastil", Vector3.new(2.4, 0.5, 1.4), Vector3.new(x, 18.2, z), P.mast, Enum.Material.Neon))
	local light = Instance.new("SpotLight")
	light.Name = "Luz"
	light.Face = Enum.NormalId.Bottom
	light.Angle = 130
	light.Color = P.mast
	light.Brightness = 2.6
	light.Range = 46
	light.Shadows = false
	light.Parent = bulb
	CollectionService:AddTag(bulb, "NightLamp")
	return bulb
end

-- Cartel colgante de aeropuerto (amarillo y negro, con la franja del color de la ruta). `facing` = hacia dónde mira el cartel.
local function hangSign(parent, position, facing, width, text, color)
	local size = Vector3.new(width, width * 0.2, 0.4)
	local cf = CFrame.lookAt(position, position + facing)
	local _, gui = blankBoard(parent, "CartelColgante", size, cf, RHO_BLACK, 40)
	boardRect(gui, 0.012, 0.08, 0.976, 0.84, P.signYellow)
	if color then
		boardRect(gui, 0.012, 0.08, 0.07, 0.84, color)
	end
	boardText(gui, text, color and 0.105 or 0.04, 0.16, color and 0.87 or 0.92, 0.68, RHO_BLACK)
	local hang = WALL_H - (position.Y + size.Y / 2)
	if hang > 0.2 then
		for _, side in { -1, 1 } do
			deco(block(parent, "CartelTirante", Vector3.new(0.15, hang, 0.15), cf * CFrame.new(side * (width / 2 - 0.6), size.Y / 2 + hang / 2, 0), P.dark, Enum.Material.Metal))
		end
	end
end

-- Línea de color pintada en el suelo (la guía de ruta). De (x1, z1) a (x2, z2), recta en X o en Z.
local function floorLine(parent, x1, z1, x2, z2, color)
	local length = math.abs(x2 - x1) + math.abs(z2 - z1)
	local size = x1 == x2 and Vector3.new(0.7, 0.06, length) or Vector3.new(length, 0.06, 0.7)
	local line = deco(block(parent, "LineaRuta", size, Vector3.new((x1 + x2) / 2, FLOOR_TOP + 0.04, (z1 + z2) / 2), color, Enum.Material.SmoothPlastic))
	return line
end

local function counter(parent, x, z, width, depth, color)
	return block(parent, "Mostrador", Vector3.new(width, 3.6, depth), Vector3.new(x, 1.8, z), color or P.steel, Enum.Material.SmoothPlastic)
end

-- Fila de asientos de espera (8 de largo): cobertura baja. `alongZ` = la fila corre en Z.
local function seats(parent, x, z, alongZ)
	local size = alongZ and Vector3.new(2.2, 1.6, 9) or Vector3.new(9, 1.6, 2.2)
	block(parent, "Asientos", size, Vector3.new(x, 0.8, z), P.seat, Enum.Material.SmoothPlastic)
	local back = alongZ and Vector3.new(0.4, 2, 9) or Vector3.new(9, 2, 0.4)
	deco(block(parent, "AsientosRespaldo", back, Vector3.new(x, 2.6, z), P.seat, Enum.Material.SmoothPlastic))
end

-- Cinta de recogida de equipaje: base con colisión, banda oscura y maletas encima
local function carousel(parent, x, z, sizeX, sizeZ, rng)
	block(parent, "CintaEquipaje", Vector3.new(sizeX, 2.6, sizeZ), Vector3.new(x, 1.3, z), P.steel, Enum.Material.Metal)
	deco(block(parent, "CintaBanda", Vector3.new(sizeX - 1.4, 0.2, sizeZ - 1.4), Vector3.new(x, 2.7, z), P.dark, Enum.Material.Rubber))
	local long = math.max(sizeX, sizeZ)
	for i = 1, 3 do
		local along = (i - 2) * long * 0.28 + rng:NextNumber(-1.5, 1.5)
		local offset = sizeX > sizeZ and Vector3.new(along, 0, 0) or Vector3.new(0, 0, along)
		local colors = { C.cobalto, C.terracota, C.oscuro, C.lima, C.mostaza }
		deco(block(parent, "Maleta", Vector3.new(2.2, 1.4, 1.5), CFrame.new(Vector3.new(x, 3.5, z) + offset) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), colors[rng:NextInteger(1, #colors)], Enum.Material.SmoothPlastic))
	end
end

-- Carrito de equipaje (4 × 3 × 7) con maletas: cobertura baja
local function cart(parent, x, z, angle, rng)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(angle or 0), 0)
	block(parent, "Carrito", Vector3.new(4, 1.4, 7), base * CFrame.new(0, 1.3, 0), P.steel, Enum.Material.Metal)
	deco(block(parent, "CarritoRuedas", Vector3.new(3.6, 0.8, 5.6), base * CFrame.new(0, 0.4, 0), P.dark, Enum.Material.Rubber))
	local colors = { C.cobalto, C.terracota, C.lima, C.mostaza, C.salmon }
	for i = -1, 1 do
		deco(block(parent, "Maleta", Vector3.new(3.2, 1.6, 1.8), base * CFrame.new(0, 2.8, i * 2.1) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), colors[rng:NextInteger(1, #colors)], Enum.Material.SmoothPlastic))
	end
end

-- Autobús de traslado (9 × 8.5 × 19): cobertura alta. `alongX` = a lo largo de X.
local function shuttle(parent, x, z, alongX, color)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, alongX and math.pi / 2 or 0, 0)
	block(parent, "Autobus", Vector3.new(9, 7.3, 19), base * CFrame.new(0, 4.85, 0), color or C.blanco, Enum.Material.Metal)
	deco(block(parent, "AutobusVentanas", Vector3.new(9.1, 2.4, 15), base * CFrame.new(0, 6.2, -0.6), P.dark, Enum.Material.Glass))
	deco(block(parent, "AutobusFranja", Vector3.new(9.12, 0.6, 19.04), base * CFrame.new(0, 3.4, 0), P.blue, Enum.Material.SmoothPlastic))
	for _, dz in { -6, 6 } do
		deco(block(parent, "AutobusRuedas", Vector3.new(9.2, 2.4, 2.4), base * CFrame.new(0, 1.2, dz), P.dark, Enum.Material.Rubber))
	end
end

-- Barrera de hormigón de la acera (cobertura baja). `alongX` = a lo largo de X.
local function barrier(parent, x, z, alongX)
	block(parent, "Barrera", alongX and Vector3.new(8, 3, 1.6) or Vector3.new(1.6, 3, 8), Vector3.new(x, 1.5, z), C.concreto, Enum.Material.Concrete)
end

local function column(parent, x, z)
	return pole(parent, "Columna", Vector3.new(x, 0, z), WALL_H, 3, P.wall, Enum.Material.Concrete)
end

local function sofa(parent, x, z, alongZ)
	local size = alongZ and Vector3.new(3, 1.8, 8) or Vector3.new(8, 1.8, 3)
	block(parent, "Sofa", size, Vector3.new(x, 0.9, z), C.terracota, Enum.Material.Fabric)
end

-- Puerta de AirportLayout.DOORS: la hoja (GameState la abre y la cierra) y el dintel fijo de encima
local function makeDoor(parent, id, name)
	local d = L.DOORS[id]
	local row, col1, col2 = d[1], d[2], d[3]
	local x1, x2, z1, z2 = L.x(col1), L.x(col2 + 1), L.z(row), L.z(row + 1)
	local center = Vector3.new((x1 + x2) / 2, 0, (z1 + z2) / 2)
	local crossX = cell(row - 1, col1) == "#" and cell(row + 1, col1) == "#" -- la puerta se cruza caminando en X
	local size = crossX and Vector3.new(2, DOOR_H, z2 - z1) or Vector3.new(x2 - x1, DOOR_H, 2)
	local leaf = block(parent, name, size, center + Vector3.new(0, DOOR_H / 2, 0), P.door, Enum.Material.DiamondPlate)
	block(parent, "Dintel", Vector3.new(x2 - x1, WALL_H - DOOR_H, z2 - z1), center + Vector3.new(0, (WALL_H + DOOR_H) / 2, 0), P.wall)
	return leaf
end

---------------------------------------------------------------------------------------------------
-- Estructura: pisos, muros, techos, vallas y puntos de aparición, desde la cuadrícula

local function buildShell(map, spawnRoot)
	local shell = newFolder(map, "Estructura")

	for _, r in rects(function(ch)
		return ch == "#" and "wall" or nil
	end) do
		slab(shell, "Muro", r.x1, r.x2, r.z1, r.z2, WALL_H, P.wall)
	end
	for _, r in rects(function(ch)
		return ch == "F" and "fence" or nil
	end) do
		slab(shell, "Valla", r.x1, r.x2, r.z1, r.z2, 10, P.fence, Enum.Material.DiamondPlate)
	end

	-- Interior: piso por banda y techo encima
	local floorColors = { Service = P.serviceFloor, Concourse = P.tile, Apron = P.tile }
	for _, r in rects(function(ch, _, col)
		return (ch == "." or ch == "s") and band(col) or nil
	end) do
		floor(shell, "Piso" .. r.key, r.x1, r.x2, r.z1, r.z2, floorColors[r.key], r.key == "Service" and Enum.Material.Concrete or Enum.Material.SmoothPlastic)
		block(shell, "Techo", Vector3.new(r.x2 - r.x1, 1, r.z2 - r.z1), Vector3.new((r.x1 + r.x2) / 2, WALL_H + 0.5, (r.z1 + r.z2) / 2), P.ceiling, Enum.Material.SmoothPlastic)
	end
	-- Exterior: asfalto (también bajo los vehículos)
	for _, r in rects(function(ch)
		return (ch == "," or ch == "x" or ch == "B") and "apron" or nil
	end) do
		floor(shell, "Asfalto", r.x1, r.x2, r.z1, r.z2, P.asphalt, Enum.Material.Asphalt)
	end

	-- Puntos de aparición, cada uno en la carpeta de su zona
	local folders = {}
	for zone in L.ZONES do
		folders[zone] = newFolder(spawnRoot, zone)
	end
	for row = 0, #ROWS - 1 do
		for col = 0, #ROWS[1] - 1 do
			local ch = cell(row, col)
			if ch == "s" or ch == "x" then
				for zone, range in L.ZONES do
					if row >= range[1] and row <= range[2] then
						marker(folders[zone], L.center(row, col))
					end
				end
			end
		end
	end
	return shell, folders
end

-- Luces: tubos fluorescentes en el terminal (más juntos) y en los túneles (pocos: la linterna importa), mástiles fuera
local function buildLights(map)
	local lights = newFolder(map, "Luces")
	for row = 0, #ROWS - 1 do
		for col = 0, #ROWS[1] - 1 do
			local ch = cell(row, col)
			local center = L.center(row, col)
			if ch == "." or ch == "s" then
				local zone = band(col)
				if zone == "Concourse" and row % 3 == 1 and (col == 11 or col == 15) then
					tube(lights, center + Vector3.new(5, WALL_H - 0.2, 0), 36, 2.4)
				elseif zone ~= "Concourse" and (row * 7 + col * 3) % 9 == 0 then
					tube(lights, center + Vector3.new(0, WALL_H - 0.2, 0), 30, 1.6, true)
				end
			elseif ch == "," and row % 5 == 2 and (col == 20 or col == 25 or (row >= 78 and (col == 3 or col == 9 or col == 15))) then
				mast(lights, center.X, center.Z)
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Lobby: Lost & Found (x -40..40, z -440..-400)

-- Plano del aeropuerto con las tres rutas (rótulo en inglés)
local function routesBoard(parent, cframe)
	local _, gui = blankBoard(parent, "CartelRutas", Vector3.new(14, 10, 0.3), cframe, RHO_BLACK, 60)
	boardRect(gui, 0, 0, 1, 0.26, P.signYellow)
	boardText(gui, "RHM", 0.043, 0.035, 0.3, 0.055, RHO_BLACK)
	boardText(gui, "CHOOSE YOUR ROUTE", 0.5, 0.035, 0.457, 0.055, RHO_BLACK, Enum.TextXAlignment.Right)
	boardText(gui, "LAST CALL", 0.043, 0.085, 0.9, 0.16, RHO_BLACK)
	for i, card in { { "01", "SERVICE", P.yellow }, { "02", "CONCOURSE", P.red }, { "03", "APRON", P.blue } } do
		local x = 0.043 + (i - 1) * 0.313
		boardRect(gui, x, 0.31, 0.288, 0.54, card[3])
		boardText(gui, card[1], x + 0.022, 0.33, 0.2, 0.15, RHO_BLACK)
		boardRect(gui, x + 0.021, 0.728, 0.245, 0.005, RHO_BLACK)
		boardText(gui, card[2], x + 0.021, 0.74, 0.25, 0.09, RHO_BLACK)
	end
	boardRect(gui, 0.043, 0.9, 0.914, 0.003, P.signYellow)
	boardText(gui, "RHOMULUS INTERNATIONAL AIRPORT", 0.043, 0.92, 0.6, 0.045, P.signYellow)
	boardText(gui, "ALL FLIGHTS CANCELLED", 0.6, 0.92, 0.357, 0.045, P.signYellow, Enum.TextXAlignment.Right)
end

local function buildLobby(map, refs, rng)
	local lobby = newFolder(map, "Lobby")
	refs.lobbyDoor = makeDoor(lobby, "lobby", "LobbyDoor")
	refs.extraLobbyDoors = { makeDoor(lobby, "lobbyWest", "LobbyDoorW"), makeDoor(lobby, "lobbyEast", "LobbyDoorE") }
	refs.lobbySpawn = CFrame.lookAt(Vector3.new(0, 3, -424), Vector3.new(0, 3, -400))

	tube(lobby, Vector3.new(-18, WALL_H - 0.2, -420), 40, 3)
	tube(lobby, Vector3.new(18, WALL_H - 0.2, -420), 40, 3)

	-- Estanterías de objetos perdidos con maletas (pared norte, a la derecha de la puerta) y el plano a la izquierda
	local colors = { C.cobalto, C.terracota, C.lima, C.mostaza, C.salmon, C.oscuro }
	for _, x in { 20, 30 } do
		block(lobby, "Estanteria", Vector3.new(8, 9, 2.4), Vector3.new(x, 4.5, -401.4), C.madera, Enum.Material.Wood)
		for shelf = 0, 2 do
			for slot = -1, 1 do
				deco(block(lobby, "Maleta", Vector3.new(2, 1.5, 1.4), Vector3.new(x + slot * 2.5, 1.8 + shelf * 2.9, -402.9), colors[rng:NextInteger(1, #colors)], Enum.Material.SmoothPlastic))
			end
		end
	end
	routesBoard(lobby, CFrame.lookAt(Vector3.new(-25, 9, -400.2), Vector3.new(-25, 9, -420)))
	hangSign(lobby, Vector3.new(0, 16.4, -400.6), -Vector3.zAxis, 16, "↑ CONCOURSE", P.red)
	hangSign(lobby, Vector3.new(-39.6, 16.4, -425), Vector3.xAxis, 13, "↑ SERVICE", P.yellow)
	hangSign(lobby, Vector3.new(39.6, 16.4, -425), -Vector3.xAxis, 13, "↑ APRON", P.blue)

	-- Mesa con la radio vieja, montón de maletas sin dueño y un carrito
	block(lobby, "Mesa", Vector3.new(6, 3, 3), Vector3.new(-33, 1.5, -437), C.madera, Enum.Material.Wood)
	deco(block(lobby, "RadioVieja", Vector3.new(2.4, 1.4, 1.2), Vector3.new(-33, 3.7, -437), P.dark, Enum.Material.Metal))
	deco(block(lobby, "RadioAntena", Vector3.new(0.1, 2, 0.1), Vector3.new(-32.2, 5.4, -437), C.concreto))
	cart(lobby, 33, -434, 20, rng)
	for i = 1, 6 do
		deco(block(lobby, "Maleta", Vector3.new(2.4, 1.5, 1.6), CFrame.new(24 + rng:NextNumber(-3, 3), 0.75 + (i % 2) * 1.5, -436 + rng:NextNumber(-2, 2)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), colors[rng:NextInteger(1, #colors)], Enum.Material.SmoothPlastic))
	end
end

---------------------------------------------------------------------------------------------------
-- Sector 1: Arrivals (z -400..-190)

local function addCans(refs, parent, position, amount)
	local model, pilePrompt = canPile(parent, position)
	table.insert(refs.canPiles, { model = model, prompt = pilePrompt, amount = amount })
end

local function addMedkit(refs, parent, position)
	local model, kitPrompt = medkitPickup(parent, position)
	table.insert(refs.medkits, { model = model, prompt = kitPrompt })
end

-- Emboscada sobre un rango de celdas (fila1, col1, fila2, col2); los zombies salen de las celdas `points` ({ fila, columna })
local function addAmbush(list, parent, name, row1, col1, row2, col2, points, size, tank)
	local positions = {}
	for _, point in points do
		table.insert(positions, L.center(point[1], point[2]))
	end
	table.insert(list, { volume = volume(parent, "Emboscada" .. name, L.x(col1), L.x(col2 + 1), L.z(row1), L.z(row2 + 1), 12), points = positions, size = size, tank = tank })
end

local function buildArrivals(map, refs, rng)
	local s = newFolder(map, "Sector1")

	-- CONCOURSE: recogida de equipaje (z -390..-320), aduana (z -320..-310) y salón de llegadas (z -310..-200)
	carousel(s, -24, -356, 7, 34, rng)
	carousel(s, 24, -356, 7, 34, rng)
	carousel(s, 0, -334, 24, 7, rng)
	for _, z in { -382, -300, -268, -236, -206 } do
		column(s, -15, z)
		column(s, 15, z)
	end
	hangSign(s, Vector3.new(0, 16.4, -391), -Vector3.zAxis, 20, "BAGGAGE CLAIM", P.red)
	hangSign(s, Vector3.new(-10, 16.4, -321), -Vector3.zAxis, 18, "CUSTOMS  ·  EXIT", P.red)
	hangSign(s, Vector3.new(30, 16.4, -321), -Vector3.zAxis, 18, "NOTHING TO DECLARE", P.red)
	-- Mostradores de alquiler de autos (pared este) con su rótulo
	for i, z in { -300, -280, -222 } do
		counter(s, 35.5, z, 3, 12, P.steel)
		local names = { "RENT-A-CAR", "RHO WHEELS", "TAXI DESK" }
		hangSign(s, Vector3.new(39.6, 10, z), -Vector3.xAxis, 11, names[i])
	end
	for _, z in { -272, -232 } do
		seats(s, -6, z, true)
		seats(s, 6, z, true)
	end
	pole(s, "MostradorInfo", Vector3.new(0, 0, -212), 3.6, 9, P.steel, Enum.Material.SmoothPlastic)
	hangSign(s, Vector3.new(0, 15, -212), -Vector3.zAxis, 12, "INFORMATION")
	floorLine(s, 0, -390, 0, -190, P.red)
	hangSign(s, Vector3.new(0, 16.4, -202), -Vector3.zAxis, 22, "↑ SKY LOUNGE  ·  DEPARTURES", P.red)
	addCans(refs, s, Vector3.new(34, 0, -386))

	-- SERVICE: muelle de carga (z -440..-410), salas de equipaje A (z -360..-330) y B (z -280..-250) y pasillos estrechos
	crates(s, -84, -436)
	cart(s, -58, -414, 90, rng)
	block(s, "CintaServicio", Vector3.new(4, 3, 20), Vector3.new(-96, 1.5, -345), P.steel, Enum.Material.Metal)
	crates(s, -115, -356)
	cart(s, -68, -336, 0, rng)
	block(s, "CintaServicio", Vector3.new(28, 3, 4), Vector3.new(-98, 1.5, -264), P.steel, Enum.Material.Metal)
	cart(s, -78, -256, 30, rng)
	block(s, "Mesa", Vector3.new(5, 3, 3), Vector3.new(-116, 1.5, -253), C.madera, Enum.Material.Wood)
	addMedkit(refs, s, Vector3.new(-116, 3, -253))
	addCans(refs, s, Vector3.new(-116, 0, -334))
	addCans(refs, s, Vector3.new(-96, 0, -305), 75) -- el fondo del cuartito (riesgo: de ahí salen zombies)
	barrel(s, -62, -437, C.lonaAzul)
	-- Tuberías a lo largo de los pasillos
	for _, run in { { -74, -410, -360 }, { -106, -330, -280 }, { -84, -250, -200 } } do
		local pipe = deco(block(s, "Tuberia", Vector3.new(run[3] - run[2], 1, 1), CFrame.new(run[1], WALL_H - 1.6, (run[2] + run[3]) / 2) * CFrame.Angles(0, math.pi / 2, 0), C.oxido, Enum.Material.Metal))
		pipe.Shape = Enum.PartType.Cylinder
	end
	floorLine(s, -75, -410, -75, -360, P.yellow)
	floorLine(s, -105, -330, -105, -280, P.yellow)
	floorLine(s, -85, -250, -85, -195, P.yellow)
	floorLine(s, -85, -195, -40, -195, P.yellow)
	hangSign(s, Vector3.new(-75, 16.4, -409), -Vector3.zAxis, 9, "→ BAGGAGE", P.yellow)
	addAmbush(refs.ambushes, s, "SalaA", 9, 2, 11, 7, { { 6, 3 }, { 14, 5 } })
	addAmbush(refs.ambushes, s, "SalaB", 17, 2, 19, 6, { { 14, 5 }, { 21, 2 } })

	-- APRON: acera de llegadas (junto al terminal) con taxis, buses de traslado y el estacionamiento al fondo
	deco(block(s, "Acera", Vector3.new(8, 0.12, 250), Vector3.new(54, FLOOR_TOP + 0.06, -315), P.sidewalk, Enum.Material.Concrete))
	for _, spot in { { 64, -428, 4 }, { 65, -404, -8 }, { 64, -330, 0 }, { 66, -264, 12 }, { 63, -226, 0 } } do
		car(s, spot[1], spot[2], spot[3], P.taxi)
	end
	for _, spot in { { 108, -432, 90, C.cobalto }, { 122, -408, 0, C.concreto }, { 106, -392, 80, C.terracota }, { 120, -322, 0, C.blanco }, { 104, -318, 12, C.turquesa }, { 118, -246, 0, C.oscuro }, { 100, -214, 96, C.lima } } do
		car(s, spot[1], spot[2], spot[3], spot[4])
	end
	for _, r in rects(function(ch, row)
		return ch == "B" and row < 26 and "bus" or nil
	end) do
		shuttle(s, (r.x1 + r.x2) / 2, (r.z1 + r.z2) / 2, r.row % 2 == 1, C.blanco)
	end
	for _, z in { -380, -344, -310, -276, -240 } do
		barrier(s, 76, z, false)
	end
	barrier(s, 96, -338, true)
	barrier(s, 112, -270, true)
	floorLine(s, 60, -430, 60, -195, P.blue)
	addCans(refs, s, Vector3.new(124, 0, -362))
	addCans(refs, s, Vector3.new(125, 0, -206), 75)
	addMedkit(refs, s, Vector3.new(104, 0, -296))
	addAmbush(refs.ambushes, s, "Estacionamiento", 12, 19, 17, 26, { { 12, 26 }, { 22, 26 } })

	-- Tienda 1: Newsstand, hueco de la pared oeste del salón de llegadas (columnas 7 a 9, filas 15 y 16)
	MapKit.buildShop(map, refs, { zone = "Zone1", origin = Vector3.new(-40, 0, -290), forward = -Vector3.xAxis, width = 20, depth = 30, title = "NEWSSTAND" })
end

---------------------------------------------------------------------------------------------------
-- Punto seguro 1: Sky Lounge (x -30..30, z -180..-140)

-- Pantalla de vuelos: todo cancelado
local function flightBoard(parent, cframe)
	local _, gui = blankBoard(parent, "PantallaVuelos", Vector3.new(14, 7, 0.3), cframe, RHO_BLACK, 50)
	boardText(gui, "DEPARTURES", 0.04, 0.04, 0.6, 0.12, P.signYellow)
	boardRect(gui, 0.04, 0.18, 0.92, 0.008, P.signYellow)
	for i, flight in { { "RM-2", "SAN REMO" }, { "RH-118", "PUERTO ALBA" }, { "LC-07", "VILLA ESPERANZA" }, { "RM-31", "COSTA BRAVA" }, { "RH-404", "NOWHERE" } } do
		local y = 0.2 + (i - 1) * 0.155
		boardText(gui, flight[1], 0.04, y + 0.02, 0.2, 0.1, C.blanco)
		boardText(gui, flight[2], 0.26, y + 0.02, 0.4, 0.1, C.blanco)
		boardText(gui, "CANCELLED", 0.66, y + 0.02, 0.3, 0.1, C.rojo, Enum.TextXAlignment.Right)
	end
end

local function buildLounge(map, refs)
	local lounge = newFolder(map, "SkyLounge")
	refs.safeEntryDoor = makeDoor(lounge, "loungeEntry", "SafeEntryDoor")
	refs.safeExitDoor = makeDoor(lounge, "loungeExit", "SafeExitDoor")
	refs.safeExtraExits = { makeDoor(lounge, "loungeWest", "SafeExitDoorW"), makeDoor(lounge, "loungeEast", "SafeExitDoorE") }
	refs.safeVolume = volume(lounge, "SafeVolume", -30, 30, -180, -140, 12)
	refs.safeSpawn = CFrame.lookAt(Vector3.new(0, 3, -164), Vector3.new(0, 3, -140))

	tube(lounge, Vector3.new(-14, WALL_H - 0.2, -160), 36, 2.6)
	tube(lounge, Vector3.new(14, WALL_H - 0.2, -160), 36, 2.6)
	hangSign(lounge, Vector3.new(0, 16.4, -190.4), -Vector3.zAxis, 18, "SKY LOUNGE  ·  MEMBERS ONLY")
	sofa(lounge, -26, -172, true)
	sofa(lounge, -26, -148, true)
	sofa(lounge, 26, -172, true)
	sofa(lounge, -16, -177, false)
	counter(lounge, 20, -146, 16, 3, C.madera) -- la barra
	flightBoard(lounge, CFrame.lookAt(Vector3.new(20, 10, -179.8), Vector3.new(20, 10, -160)))
	addMedkit(refs, lounge, Vector3.new(20, 3.6, -146))
	hangSign(lounge, Vector3.new(0, 16.4, -140.6), -Vector3.zAxis, 14, "↑ DEPARTURES", P.red)
	hangSign(lounge, Vector3.new(-29.6, 16.4, -155), Vector3.xAxis, 9, "↑ SERVICE", P.yellow)
	hangSign(lounge, Vector3.new(29.6, 16.4, -155), -Vector3.xAxis, 9, "↑ APRON", P.blue)
end

---------------------------------------------------------------------------------------------------
-- Sector 2 (Departures), Fire Station, sector 3 (Gates & Hangars) y la plataforma: de momento solo lo que necesita la partida
-- (puertas, volúmenes, Tiendas, radio); los muebles y los eventos llegan en las fases siguientes.

local function buildDepartures(map, refs)
	local s = newFolder(map, "Sector2")
	-- La puerta del control de seguridad (la abre el evento del sector) y su lector de tarjetas
	refs.gate = makeDoor(s, "security", "SecurityGate")
	refs.gateText = { label = "SECURITY", open = "open the security checkpoint", run = "through security" }
	local reader = block(s, "LectorTarjetas", Vector3.new(1.6, 4.4, 1.6), Vector3.new(14, 2.2, 117), P.dark, Enum.Material.Metal)
	deco(block(s, "LectorLuz", Vector3.new(1, 0.5, 0.2), Vector3.new(14, 3.6, 116.1), C.rojo, Enum.Material.Neon))
	label(reader, "CARD READER", P.signYellow, 26)
	refs.gateReader = reader
	refs.gatePrompt = prompt(reader, "Open security", 3)
	hangSign(s, Vector3.new(0, 16.4, 119.4), -Vector3.zAxis, 22, "SECURITY CHECKPOINT  ·  STAFF ONLY")
	floorLine(s, 0, -130, 0, 120, P.red)

	-- Tienda 2: Duty Free, hueco de la pared este del terminal (columnas 18 a 20, filas 48 y 49)
	MapKit.buildShop(map, refs, { zone = "Zone2", origin = Vector3.new(40, 0, 40), forward = Vector3.xAxis, width = 20, depth = 30, title = "DUTY FREE" })
end

local function buildFireStation(map, refs)
	local station = newFolder(map, "FireStation")
	refs.safe2 = {
		volume = volume(station, "FireStationVolume", -30, 30, 130, 170, 12),
		exitDoor = makeDoor(station, "stationExit", "StationExitDoor"),
		extraExits = { makeDoor(station, "stationWest", "StationExitDoorW"), makeDoor(station, "stationEast", "StationExitDoorE") },
		spawn = CFrame.lookAt(Vector3.new(0, 3, 146), Vector3.new(0, 3, 170)),
	}
	tube(station, Vector3.new(-14, WALL_H - 0.2, 150), 36, 2.6)
	tube(station, Vector3.new(14, WALL_H - 0.2, 150), 36, 2.6)
	hangSign(station, Vector3.new(0, 16.4, 169.4), -Vector3.zAxis, 14, "↑ GATES", P.red)
end

local function buildGates(map, refs, config)
	local s = newFolder(map, "Sector3")
	floorLine(s, 0, 180, 0, 330, P.red)

	-- Tienda 3: Ground Crew Workshop, hueco del lado oeste del hangar (columnas 1 a 3, filas 70 y 71)
	MapKit.buildShop(map, refs, { zone = "Zone3", origin = Vector3.new(-100, 0, 260), forward = -Vector3.xAxis, width = 20, depth = 30, title = "WORKSHOP" })

	-- Plataforma de la extracción (z 330..410): torre de control con la radio al pie y la pista al norte
	local tarmac = newFolder(map, "Plataforma")
	block(tarmac, "TorreFuste", Vector3.new(14, 44, 14), Vector3.new(-105, WALL_H + 22, 365), P.wall)
	block(tarmac, "TorreCabina", Vector3.new(26, 9, 26), Vector3.new(-105, WALL_H + 48.5, 365), P.dark, Enum.Material.Glass)
	deco(block(tarmac, "TorreTecho", Vector3.new(28, 1.2, 28), Vector3.new(-105, WALL_H + 53.6, 365), P.steel, Enum.Material.Metal))
	hangSign(tarmac, Vector3.new(-89.7, 15, 365), Vector3.xAxis, 16, "CONTROL TOWER")
	local radioModel, radio = PropModel.build(Radio, Vector3.new(-84, 0, 365), yawFacing(Vector3.xAxis))
	radio.Name = "Radio"
	radioModel.Parent = tarmac
	refs.radio = radio
	refs.radioModel = radioModel
	refs.radioPrompt = prompt(radio, "Use the radio", config.RadioHoldTime)
	label(radio, "RADIO", Color3.fromRGB(110, 225, 150))

	-- La pista sigue hacia el norte, fuera del límite jugable
	floor(tarmac, "Pista", -700, 700, 410, 480, P.asphalt, Enum.Material.Asphalt)
	for x = -660, 660, 60 do
		deco(block(tarmac, "PistaRaya", Vector3.new(24, 0.06, 1.6), Vector3.new(x, FLOOR_TOP + 0.04, 445), C.blanco, Enum.Material.SmoothPlastic))
	end

	refs.extractionArea = volume(tarmac, "ExtractionArea", -130, 130, 330, 410, 40) -- toda la plataforma: basta con que el equipo esté en ella
	refs.extractionGoal = volume(tarmac, "ExtractionGoal", -70, -30, 345, 385, 12) -- destino de la guía
	-- Provisional hasta que exista Remo One: la furgoneta entra por la pista
	refs.vanStart = CFrame.new(-30, 0, 470)
	refs.vanStop = CFrame.new(-30, 0, 392)
	refs.vanVolume = volume(tarmac, "VanVolume", -44, -16, 378, 406, 14)
	refs.boxSpots.Extraction = { { Vector3.new(-60, 0, 340), Vector3.new(40, 0, 345), Vector3.new(100, 0, 380) } }
end

---------------------------------------------------------------------------------------------------
-- Límites: paredes invisibles en el perímetro y un suelo de seguridad bajo todo el mapa

local function buildLimits(map)
	local folder = newFolder(map, "Limites")
	local function invisible(size, position)
		local part = Instance.new("Part")
		part.Name = "Limite"
		part.Anchored = true
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Size = size
		part.Position = position
		part.Parent = folder
	end
	local H = 90
	invisible(Vector3.new(2, H, 870), Vector3.new(-131, H / 2, -20)) -- oeste
	invisible(Vector3.new(2, H, 870), Vector3.new(131, H / 2, -20)) -- este
	invisible(Vector3.new(284, H, 2), Vector3.new(0, H / 2, -441)) -- sur (detrás del lobby)
	invisible(Vector3.new(284, H, 2), Vector3.new(0, H / 2, 411)) -- norte: la pista no se pisa (el avión aterriza ahí)
	invisible(Vector3.new(300, 3, 960), Vector3.new(0, -1.5, 20)) -- suelo de seguridad (cara superior a ras de y = 0)
end

function MapBuilderAirport.build(config, options)
	options = options or {}
	for _, name in { "Map", "SpawnPoints" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	local spawnRoot = Instance.new("Folder")
	spawnRoot.Name = "SpawnPoints"
	spawnRoot.Parent = workspace

	local rng = Random.new(config.Seed + 2)
	local refs = { ammoStations = {}, pharmacySpots = {}, boxSpots = {}, ambushes = {}, ambushesZone2 = {}, ambushesZone3 = {}, canPiles = {}, medkits = {} }
	-- Textos de la partida que cambian con el mapa (GameState usa los de Morro Esperanza si faltan)
	refs.texts = {
		zone1 = "Cross Arrivals to the Sky Lounge",
		zone3 = "Cross the gates to the runway",
		zone3Label = "RUNWAY",
	}

	buildShell(map, spawnRoot)
	buildLights(map)
	buildLobby(map, refs, rng)
	buildArrivals(map, refs, rng)
	buildLounge(map, refs)
	buildDepartures(map, refs)
	buildFireStation(map, refs)
	buildGates(map, refs, config)
	buildLimits(map)

	-- Aviso si un lugar de la caja de armas quedó tapado por un obstáculo
	local params = OverlapParams.new()
	params.RespectCanCollide = true
	for _, groups in refs.boxSpots do
		for _, group in groups do
			for _, spotValue in group do
				local spot = typeof(spotValue) == "CFrame" and spotValue.Position or spotValue
				if #workspace:GetPartBoundsInBox(CFrame.new(spot + Vector3.new(0, 4, 0)), Vector3.new(7, 6, 7), params) > 0 then
					warn(`MapBuilderAirport: el lugar de la caja de armas {spot} está tapado`)
				end
			end
		end
	end
	return refs
end

return MapBuilderAirport
