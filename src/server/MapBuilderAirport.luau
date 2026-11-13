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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local AirportArt = require(script.Parent.AirportArt)
local AirportDetail = require(script.Parent.AirportDetail)
local AirportLayout = require(script.Parent.AirportLayout)
local PlaneLayout = require(ReplicatedStorage.Shared.PlaneLayout)
local MapKit = require(script.Parent.MapKit)
local PropModel = require(script.Parent.PropModel)
local Radio = require(script.Parent.ZombieData.Radio)
local AvionAparcado = require(script.Parent.ZombieData.AvionAparcado)

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
local HALL_H = 32 -- techo de los salones del CONCOURSE (llegadas, facturación, embarque): cerchas y tragaluces
local RUNWAY_Z = 436 -- eje de la pista (Remo One rueda por aquí)
local PLAY_NORTH = 425 -- hasta dónde se puede pisar hacia la pista: llega al pie de la escalerilla, no bajo el fuselaje
local DOOR_H = 14
local DECK = 11 -- altura de las pasarelas (el segundo piso del sector 2 y los fingers del sector 3)

-- Paleta del aeropuerto: fría y gris, con los tres colores de ruta
local P = {
	wall = hex("#7E8287"),
	plaster = hex("#A59C8E"), -- revestimiento del terminal (yeso crema)
	trim = hex("#2B2926"), -- zócalos y molduras (granito oscuro)
	servicePaint = hex("#4B5C4E"), -- pintura verde de los túneles de servicio (mitad baja)
	tile = hex("#7A746A"), -- terrazo del terminal
	serviceFloor = hex("#45493F"), -- concreto pintado de los túneles de servicio
	asphalt = hex("#3C3F45"),
	sidewalk = hex("#7B7F85"),
	ceiling = hex("#8E9296"),
	roof = hex("#2F3236"), -- techo alto de los salones (se pierde en la oscuridad)
	truss = hex("#8B9298"),
	fence = hex("#474C52"),
	steel = hex("#6E757D"),
	dark = Color3.fromRGB(34, 36, 40),
	seat = hex("#2F4E79"),
	taxi = hex("#E7B416"),
	signYellow = hex("#F2C230"),
	tube = Color3.fromRGB(255, 214, 165), -- luz del terminal (ámbar)
	serviceTube = Color3.fromRGB(190, 255, 205), -- fluorescente verdoso de los túneles
	mast = Color3.fromRGB(205, 222, 255), -- focos de la plataforma (fríos)
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

-- Salones de techo alto: el CONCOURSE de los tres sectores (no el lobby ni los puntos seguros)
local HALL_ROWS = { { 6, 25 }, { 32, 56 }, { 63, 77 } }
local function isHall(row, col)
	local ch = cell(row, col)
	if band(col) ~= "Concourse" or (ch ~= "." and ch ~= "s") then
		return false
	end
	for _, range in HALL_ROWS do
		if row >= range[1] and row <= range[2] then
			return true
		end
	end
	return false
end

-- Muro de la fachada este que da a la plataforma: se hace de vidrio (AirportArt.structure)
local function isFacade(row, col)
	return cell(row, col) == "#" and isHall(row, col - 1) and cell(row, col + 1) == ","
end

-- Altura del techo en un punto del mapa
local function ceilingAt(position)
	local col = math.floor((position.X - L.X0) / L.CELL)
	local row = math.floor((position.Z - L.Z0) / L.CELL)
	return isHall(row, col) and HALL_H or WALL_H
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
local function tube(parent, position, range, brightness, alongZ, color)
	color = color or P.tube
	local bulb = deco(block(parent, "Tubo", alongZ and Vector3.new(0.9, 0.3, 5) or Vector3.new(5, 0.3, 0.9), position, color, Enum.Material.Neon))
	-- En un techo más alto, el tubo cuelga de dos varillas
	local roof = ceilingAt(position)
	if roof - position.Y > 1 then
		for _, side in { -1, 1 } do
			local offset = alongZ and Vector3.new(0, 0, side * 2) or Vector3.new(side * 2, 0, 0)
			deco(block(parent, "TuboVarilla", Vector3.new(0.1, roof - position.Y, 0.1), position + offset + Vector3.new(0, (roof - position.Y) / 2, 0), P.dark, Enum.Material.Metal))
		end
	end
	local light = Instance.new("SpotLight")
	light.Name = "Luz"
	light.Face = Enum.NormalId.Bottom
	light.Angle = 140
	light.Color = color
	light.Brightness = (brightness or 1.2) * 0.6
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
	light.Brightness = 3.2
	light.Range = 60
	light.Shadows = false
	light.Parent = bulb
	CollectionService:AddTag(bulb, "NightLamp")
	-- Luz roja de obstáculo en la punta (client/Beacons)
	AirportDetail.beacon(parent, Vector3.new(x, 19.1, z), Color3.fromRGB(255, 50, 40), 2.4, ((x + z) % 7) / 7, 0.3, nil, Vector3.new(0.8, 0.8, 0.8))
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
	local hang = ceilingAt(position) - (position.Y + size.Y / 2)
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

-- Autobús de traslado (9 × 8.5 × 19): cobertura alta. `alongX` = a lo largo de X. Parabrisas, ventanillas, puerta, ruedas,
-- letrero de destino y equipo de aire en el techo.
local function shuttle(parent, x, z, alongX, color)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, alongX and math.pi / 2 or 0, 0)
	block(parent, "Autobus", Vector3.new(9, 7.3, 19), base * CFrame.new(0, 4.85, 0), color or C.blanco, Enum.Material.Metal)
	local windows = deco(block(parent, "AutobusVentanas", Vector3.new(9.1, 2.4, 14), base * CFrame.new(0, 6.2, 0.6), P.dark, Enum.Material.Glass))
	windows.Reflectance = 0.2
	deco(block(parent, "AutobusParabrisas", Vector3.new(8.2, 3.4, 0.2), base * CFrame.new(0, 5.9, -9.55), P.dark, Enum.Material.Glass)).Reflectance = 0.2
	deco(block(parent, "AutobusFranja", Vector3.new(9.12, 0.6, 19.04), base * CFrame.new(0, 3.4, 0), P.blue, Enum.Material.SmoothPlastic))
	deco(block(parent, "AutobusPuerta", Vector3.new(0.15, 5.6, 2.6), base * CFrame.new(4.55, 4.1, -6.5), P.dark, Enum.Material.Glass))
	deco(block(parent, "AutobusParachoques", Vector3.new(9.2, 0.9, 19.4), base * CFrame.new(0, 1.65, 0), P.dark, Enum.Material.SmoothPlastic))
	deco(block(parent, "AutobusTechoAire", Vector3.new(5, 0.9, 6), base * CFrame.new(0, 8.95, 2), P.steel, Enum.Material.Metal))
	local _, gui = blankBoard(parent, "AutobusDestino", Vector3.new(6, 0.9, 0.15), base * CFrame.new(0, 7.9, -9.62) * CFrame.Angles(0, math.pi, 0), RHO_BLACK, 50)
	gui.LightInfluence = 0
	boardText(gui, "TERMINAL · OUT OF SERVICE", 0.03, 0.1, 0.94, 0.8, Color3.fromRGB(255, 170, 40), Enum.TextXAlignment.Center)
	for _, sx in { -1, 1 } do
		for _, sz in { -6, 6 } do
			local wheel = deco(block(parent, "AutobusRueda", Vector3.new(1, 3, 3), base * CFrame.new(sx * 4.3, 1.5, sz), P.dark, Enum.Material.Rubber))
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
end

-- Barrera de hormigón de la acera (cobertura baja). `alongX` = a lo largo de X.
local function barrier(parent, x, z, alongX)
	block(parent, "Barrera", alongX and Vector3.new(8, 3, 1.6) or Vector3.new(1.6, 3, 8), Vector3.new(x, 1.5, z), C.concreto, Enum.Material.Concrete)
end

-- Columna redonda de metal pintado hasta el techo, con basa y capitel
local function column(parent, x, z)
	local height = ceilingAt(Vector3.new(x, 0, z))
	local shaft = pole(parent, "Columna", Vector3.new(x, 0, z), height, 2.6, P.plaster, Enum.Material.Metal)
	deco(pole(parent, "ColumnaBasa", Vector3.new(x, 0, z), 1.2, 3.4, P.trim, Enum.Material.Granite))
	deco(pole(parent, "ColumnaCapitel", Vector3.new(x, height - 1.6, z), 1.6, 3.6, P.truss, Enum.Material.Metal))
	return shaft
end

local function sofa(parent, x, z, alongZ)
	local size = alongZ and Vector3.new(3, 1.8, 8) or Vector3.new(8, 1.8, 3)
	block(parent, "Sofa", size, Vector3.new(x, 0.9, z), C.terracota, Enum.Material.Fabric)
end

-- Altura: piso de pasarela (cara superior en DECK)
local function deck(parent, x1, x2, z1, z2, name)
	return block(parent, name or "Pasarela", Vector3.new(x2 - x1, 0.8, z2 - z1), Vector3.new((x1 + x2) / 2, DECK - 0.4, (z1 + z2) / 2), P.steel, Enum.Material.DiamondPlate)
end

-- Barandilla de vidrio de (x1, z1) a (x2, z2), recta en X o en Z: frena a quien camina, no a las balas
local function rail(parent, x1, z1, x2, z2)
	local length = math.abs(x2 - x1) + math.abs(z2 - z1)
	local size = x1 == x2 and Vector3.new(0.4, 3.4, length) or Vector3.new(length, 3.4, 0.4)
	local part = block(parent, "Barandilla", size, Vector3.new((x1 + x2) / 2, DECK + 1.7, (z1 + z2) / 2), Color3.fromRGB(40, 52, 66), Enum.Material.Glass)
	part.Transparency = 0.45
	part.CanQuery = false
	part.CastShadow = false
	return part
end

-- Rampa de cuña (escalera mecánica parada) del punto `bottom` al punto `top`, de `width` de ancho, con paneles a los lados
-- (`sides`: -1 y 1; mirando hacia arriba, 1 es la izquierda)
local function rampTo(parent, bottom, top, width, sides)
	local flat = Vector3.new(top.X - bottom.X, 0, top.Z - bottom.Z)
	local run, rise = flat.Magnitude, top.Y - bottom.Y
	local dir = flat.Unit
	local center = Vector3.new((bottom.X + top.X) / 2, bottom.Y + rise / 2, (bottom.Z + top.Z) / 2)
	local wedge = Instance.new("WedgePart")
	wedge.Name = "RampaMecanica"
	wedge.Anchored = true
	wedge.Size = Vector3.new(width, rise, run)
	wedge.CFrame = CFrame.lookAt(center, center - dir) -- la cuña sube hacia su +Z
	wedge.Color = P.dark
	wedge.Material = Enum.Material.DiamondPlate
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	wedge.Parent = parent
	local right = dir:Cross(Vector3.yAxis)
	local slope = top - bottom
	for _, side in sides or { -1, 1 } do
		local mid = (bottom + top) / 2 - right * side * (width / 2 - 0.2) + Vector3.new(0, 1.8, 0)
		local panel = block(parent, "RampaPanel", Vector3.new(0.4, 3.4, slope.Magnitude), CFrame.lookAt(mid, mid + slope), P.steel, Enum.Material.Metal)
		panel.CanQuery = false
		deco(block(parent, "RampaPasamanos", Vector3.new(0.6, 0.3, slope.Magnitude), CFrame.lookAt(mid, mid + slope) * CFrame.new(0, 1.85, 0), P.signYellow, Enum.Material.SmoothPlastic))
	end
	return wedge
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
	-- Marco: dos jambas y el cabecero, de acero oscuro (por las dos caras)
	local across = crossX and Vector3.new(0, 0, 1) or Vector3.new(1, 0, 0)
	local width = crossX and (z2 - z1) or (x2 - x1)
	local depth = crossX and (x2 - x1) or (z2 - z1)
	local frameSize = crossX and Vector3.new(depth + 0.6, DOOR_H + 0.8, 0.8) or Vector3.new(0.8, DOOR_H + 0.8, depth + 0.6)
	for _, side in { -1, 1 } do
		deco(block(parent, "MarcoPuerta", frameSize, center + across * side * (width / 2 - 0.4) + Vector3.new(0, (DOOR_H + 0.8) / 2, 0), P.trim, Enum.Material.Metal))
	end
	local headSize = crossX and Vector3.new(depth + 0.6, 0.8, width) or Vector3.new(width, 0.8, depth + 0.6)
	deco(block(parent, "MarcoPuerta", headSize, center + Vector3.new(0, DOOR_H + 0.4, 0), P.trim, Enum.Material.Metal))
	return leaf
end

---------------------------------------------------------------------------------------------------
-- Estructura: pisos, muros, techos, vallas y puntos de aparición, desde la cuadrícula

local function buildShell(map, spawnRoot)
	local shell = newFolder(map, "Estructura")

	for _, r in rects(function(ch, row, col)
		return ch == "#" and not isFacade(row, col) and "wall" or nil
	end) do
		slab(shell, "Muro", r.x1, r.x2, r.z1, r.z2, WALL_H, P.wall)
	end
	for _, r in rects(function(ch)
		return ch == "F" and "fence" or nil
	end) do
		slab(shell, "Valla", r.x1, r.x2, r.z1, r.z2, 10, P.fence, Enum.Material.DiamondPlate)
	end

	-- Paso alto de un finger (J): el muro deja un hueco de 6 de ancho a la altura de la pasarela
	for row = 0, #ROWS - 1 do
		for col = 0, #ROWS[1] - 1 do
			if cell(row, col) == "J" then
				local x1, x2, z1, z2 = L.x(col), L.x(col + 1), L.z(row), L.z(row + 1)
				local cx = (x1 + x2) / 2
				slab(shell, "Muro", x1, x2, z1, z2, DECK - 0.8, P.wall)
				block(shell, "Muro", Vector3.new(x2 - x1, WALL_H - DECK - 8, z2 - z1), Vector3.new(cx, (WALL_H + DECK + 8) / 2, (z1 + z2) / 2), P.wall)
				for _, z in { z1 + 1, z2 - 1 } do
					block(shell, "Muro", Vector3.new(x2 - x1, 8.8, 2), Vector3.new(cx, DECK + 3.6, z), P.wall)
				end
			end
		end
	end

	-- Interior: piso por banda (terrazo en el terminal, concreto pintado en servicio)
	local floorColors = { Service = P.serviceFloor, Concourse = P.tile, Apron = P.tile }
	for _, r in rects(function(ch, _, col)
		return (ch == "." or ch == "s") and band(col) or nil
	end) do
		floor(shell, "Piso" .. r.key, r.x1, r.x2, r.z1, r.z2, floorColors[r.key], r.key == "Service" and Enum.Material.Concrete or Enum.Material.Marble)
	end
	-- Techos: bajos (20) en pasillos y salas; los salones del CONCOURSE suben a HALL_H con tragaluces (AirportArt.structure)
	for _, r in rects(function(ch, row, col)
		return (ch == "." or ch == "s") and not isHall(row, col) and "low" or nil
	end) do
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
					-- En los salones altos los tubos cuelgan a 25 (de las varillas); en salas bajas van al techo
					local y = isHall(row, col) and HALL_H - 7 or WALL_H - 0.2
					tube(lights, center + Vector3.new(5, y, 0), 36, isHall(row, col) and 1.5 or 1.2)
				elseif zone ~= "Concourse" and (row * 7 + col * 3) % 9 == 0 then
					tube(lights, center + Vector3.new(0, WALL_H - 0.2, 0), 30, 0.9, true, zone == "Service" and P.serviceTube or nil)
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

	tube(lobby, Vector3.new(-18, WALL_H - 0.2, -420), 40, 1.4)
	tube(lobby, Vector3.new(18, WALL_H - 0.2, -420), 40, 1.4)

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
	-- (los autos los pone AirportArt.arrivals)
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
		boardText(gui, "CANCELLED", 0.66, y + 0.02, 0.3, 0.1, C.rojo, Enum.TextXAlignment.Right).Name = "Status"
	end
	CollectionService:AddTag(gui.Parent, "FlightBoard") -- parpadea y cambia los estados (client/MapMotion)
end

local function buildLounge(map, refs)
	local lounge = newFolder(map, "SkyLounge")
	refs.safeEntryDoor = makeDoor(lounge, "loungeEntry", "SafeEntryDoor")
	refs.safeExitDoor = makeDoor(lounge, "loungeExit", "SafeExitDoor")
	refs.safeExtraExits = { makeDoor(lounge, "loungeWest", "SafeExitDoorW"), makeDoor(lounge, "loungeEast", "SafeExitDoorE") }
	refs.safeVolume = volume(lounge, "SafeVolume", -30, 30, -180, -140, 12)
	refs.safeSpawn = CFrame.lookAt(Vector3.new(0, 3, -164), Vector3.new(0, 3, -140))

	tube(lounge, Vector3.new(-14, WALL_H - 0.2, -160), 36, 1.3)
	tube(lounge, Vector3.new(14, WALL_H - 0.2, -160), 36, 1.3)
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
-- Piezas de los sectores 2 y 3

-- Isla de facturación: mostrador largo con la cinta detrás y su rótulo
local function checkIn(parent, x, z, name)
	counter(parent, x, z, 22, 3.5, P.steel)
	deco(block(parent, "CheckInCinta", Vector3.new(22, 1.2, 3), Vector3.new(x, 0.6, z + 3.4), P.dark, Enum.Material.Rubber))
	hangSign(parent, Vector3.new(x, 13, z), -Vector3.zAxis, 14, name)
end

-- Mesa redonda de la zona de comida con dos bancos
local function foodTable(parent, x, z)
	pole(parent, "MesaComida", Vector3.new(x, 0, z), 3, 5, C.blanco, Enum.Material.SmoothPlastic)
	for _, dx in { -4.2, 4.2 } do
		deco(block(parent, "BancoComida", Vector3.new(1.6, 1.6, 4), Vector3.new(x + dx, 0.8, z), C.terracota, Enum.Material.SmoothPlastic))
	end
end

-- Carril del control: arco detector (se pasa por dentro) y máquina de rayos X al lado (cobertura)
local function securityLane(parent, x, z)
	for _, dx in { -2.2, 2.2 } do
		block(parent, "ArcoPoste", Vector3.new(0.8, 8, 2), Vector3.new(x + dx, 4, z), P.steel, Enum.Material.Metal)
	end
	deco(block(parent, "ArcoDintel", Vector3.new(5.2, 0.8, 2), Vector3.new(x, 8.4, z), P.steel, Enum.Material.Metal))
	block(parent, "RayosX", Vector3.new(3.4, 3.4, 10), Vector3.new(x + 5.6, 1.7, z), P.dark, Enum.Material.Metal)
end

-- Contenedor de carga aérea (6 × 6 × 6): cobertura alta
local function cargo(parent, x, z, angle)
	block(parent, "ContenedorCarga", Vector3.new(6, 6, 6), CFrame.new(x, 3, z) * CFrame.Angles(0, math.rad(angle or 0), 0), hex("#B9C0C7"), Enum.Material.Metal)
end

-- Tractor de equipaje con su tren de carritos, en fila hacia +Z
local function baggageTrain(parent, x, z, carts, rng)
	block(parent, "Tractor", Vector3.new(4, 3, 6), Vector3.new(x, 1.7, z), P.signYellow, Enum.Material.Metal)
	deco(block(parent, "TractorRuedas", Vector3.new(4.4, 1.4, 4.6), Vector3.new(x, 0.7, z), P.dark, Enum.Material.Rubber))
	for i = 1, carts do
		cart(parent, x, z + i * 9, 0, rng)
	end
end

-- Camión de combustible (8 × 9 × 19) con cisterna cilíndrica: cobertura alta. `alongX` = a lo largo de X.
local function fuelTruck(parent, x, z, alongX)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, alongX and math.pi / 2 or 0, 0)
	block(parent, "CamionCabina", Vector3.new(8, 7, 5), base * CFrame.new(0, 4, -7), C.rojo, Enum.Material.Metal)
	block(parent, "CamionChasis", Vector3.new(8, 2.4, 19), base * CFrame.new(0, 1.8, 0), P.dark, Enum.Material.Metal)
	local tank = block(parent, "CamionCisterna", Vector3.new(13, 6.4, 6.4), base * CFrame.new(0, 6, 2.6) * CFrame.Angles(0, math.pi / 2, 0), hex("#C9CED3"), Enum.Material.Metal)
	tank.Shape = Enum.PartType.Cylinder
end

-- Motor de avión sobre su caballete (taller del hangar): cobertura
local function engineStand(parent, x, z, alongX)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, alongX and math.pi / 2 or 0, 0)
	block(parent, "Caballete", Vector3.new(4, 2.4, 8), base * CFrame.new(0, 1.2, 0), P.signYellow, Enum.Material.Metal)
	local engine = block(parent, "MotorAvion", Vector3.new(10, 5, 5), base * CFrame.new(0, 4.9, 0) * CFrame.Angles(0, math.pi / 2, 0), P.steel, Enum.Material.Metal)
	engine.Shape = Enum.PartType.Cylinder
end

-- Puerta de embarque: mostrador, rótulo y dos filas de asientos en su sala (x1..x2, z1..z2)
local function gateBay(parent, x1, x2, z1, z2, name)
	local cx = (x1 + x2) / 2
	local inner = math.abs(x1) < math.abs(x2) and x1 or x2 -- el lado que da al pasillo
	local outer = inner == x1 and x2 or x1
	seats(parent, cx, z1 + 3, false)
	seats(parent, cx, z2 - 3, false)
	local sign = math.sign(outer - inner)
	counter(parent, outer - sign * 2.5, (z1 + z2) / 2, 3, 6, P.steel)
	hangSign(parent, Vector3.new(outer - sign * 0.4, 12, (z1 + z2) / 2), Vector3.new(-sign, 0, 0), 8, name)
end

-- Piezas del avión aparcado que chocan (el resto es adorno); las ventanillas no se ponen (menos piezas)
local PARKED_SOLID = {
	Fuselage_Main = true, Fuselage_Nose = true, Fuselage_TailCone = true, Wing_Left = true, Wing_Right = true,
	Engine_Left_Nacelle = true, Engine_Right_Nacelle = true, Tail_Fin = true, HStab_Left = true, HStab_Right = true,
}
local function parkedPlane(parent, position, yaw)
	local model = MapKit.placeModel(parent, AvionAparcado, position, yaw, PARKED_SOLID, nil, function(name)
		return string.find(name, "Window_", 1, true) ~= nil
	end)
	model.Name = "AvionAparcado"
	return model
end

---------------------------------------------------------------------------------------------------
-- Sector 2: Departures (z -130..120). Facturación, zona de comida y el control de seguridad, donde se juntan las tres rutas.

local function buildDepartures(map, refs, rng)
	local s = newFolder(map, "Sector2")

	-- CONCOURSE: facturación (z -130..0)
	for i, spot in { { -20, -104 }, { 20, -104 }, { -20, -62 }, { 20, -62 }, { -20, -20 } } do
		checkIn(s, spot[1], spot[2], "CHECK-IN " .. string.char(64 + i))
	end
	cart(s, 24, -24, 70, rng)
	cart(s, 6, -84, 10, rng)
	hangSign(s, Vector3.new(0, 16.4, -129.4), -Vector3.zAxis, 22, "DEPARTURES  ·  CHECK-IN", P.red)
	addCans(refs, s, Vector3.new(-26, 0, -126))

	-- ALTURA: la pasarela del segundo piso sobre el salón de facturación. Se sube por la escalera mecánica del suroeste, se
	-- recorre el balcón oeste, se cruza por el puente y se baja por la del noreste (hacia el oeste, delante del último mostrador). Los dos fondos sin salida tienen premio.
	deck(s, -40, -32, -106, -4)
	deck(s, 32, 40, -106, -4)
	deck(s, -32, 32, -44, -36)
	rampTo(s, Vector3.new(-36, 0, -128), Vector3.new(-36, DECK, -106), 8, { 1 })
	rampTo(s, Vector3.new(10, 0, -7), Vector3.new(32, DECK, -7), 6)
	for _, x in { -32, 32 } do
		rail(s, x, -106, x, -44)
	end
	rail(s, -32, -36, -32, -4)
	rail(s, 32, -36, 32, -10) -- el hueco de z -10 a -4 es la boca de la rampa noreste
	rail(s, -40, -4, -32, -4)
	rail(s, 32, -106, 40, -106)
	rail(s, 32, -4, 40, -4)
	rail(s, -32, -44, 32, -44)
	rail(s, -32, -36, 32, -36)
	for row = 32, 44 do -- donde el muro tiene un hueco, la pasarela lleva barandilla
		local z1, z2 = math.max(L.z(row), -106), math.min(L.z(row + 1), -4)
		if z2 > z1 then
			if cell(row, 9) ~= "#" then
				rail(s, -40, z1, -40, z2)
			end
			if cell(row, 18) ~= "#" then
				rail(s, 40, z1, 40, z2)
			end
		end
	end
	for _, spot in { { -32.6, -90 }, { -32.6, -66 }, { -32.6, -20 }, { 32.6, -90 }, { 32.6, -66 }, { 32.6, -20 }, { -12, -40 }, { 12, -40 } } do
		deco(pole(s, "PasarelaPata", Vector3.new(spot[1], 0, spot[2]), DECK - 0.8, 1.2, P.steel))
	end
	hangSign(s, Vector3.new(-36, 16.4, -127.4), -Vector3.zAxis, 7, "↑ UPPER LEVEL")
	addCans(refs, s, Vector3.new(-36, DECK, -8), 75)
	addMedkit(refs, s, Vector3.new(36, DECK, -102))

	-- Zona de comida (z 10..100): mesas al centro, locales en la pared oeste; la Tienda 2 (Duty Free) se abre en la pared este
	hangSign(s, Vector3.new(-20, 16.4, -0.6), -Vector3.zAxis, 16, "↑ FOOD COURT", P.red)
	hangSign(s, Vector3.new(20, 16.4, -0.6), -Vector3.zAxis, 16, "DUTY FREE →", P.red)
	for _, spot in { { -14, 24 }, { 8, 30 }, { -8, 52 }, { 16, 62 }, { -16, 80 }, { 6, 88 } } do
		foodTable(s, spot[1], spot[2])
	end
	for i, z in { 22, 44 } do
		counter(s, -35.5, z, 3, 12, C.terracota)
		local names = { "BURGERS", "COFFEE" }
		hangSign(s, Vector3.new(-39.6, 10, z), Vector3.xAxis, 10, names[i])
	end
	addMedkit(refs, s, Vector3.new(-35.5, 3.6, 44))
	addCans(refs, s, Vector3.new(34, 0, 94))
	-- Control de seguridad (z 100..120): carriles con arcos y rayos X
	for _, x in { -30, -16, 22 } do
		securityLane(s, x, 106)
	end
	-- La puerta del control (la abre el evento del sector) y su lector de tarjetas
	refs.gate = makeDoor(s, "security", "SecurityGate")
	refs.gateText = { label = "SECURITY", open = "open the security checkpoint", run = "through security" }
	local reader = block(s, "LectorTarjetas", Vector3.new(1.6, 4.4, 1.6), Vector3.new(14, 2.2, 117), P.dark, Enum.Material.Metal)
	deco(block(s, "LectorLuz", Vector3.new(1, 0.5, 0.2), Vector3.new(14, 3.6, 116.1), C.rojo, Enum.Material.Neon))
	label(reader, "CARD READER", P.signYellow, 26)
	refs.gateReader = reader
	refs.gatePrompt = prompt(reader, "Swipe the access cards", Config.CrewCall.ReaderHoldTime)
	hangSign(s, Vector3.new(0, 16.4, 119.4), -Vector3.zAxis, 22, "SECURITY CHECKPOINT  ·  STAFF ONLY")
	floorLine(s, 0, -130, 0, 120, P.red)

	-- SERVICE: salas de equipaje D (z -130..-100), E (la de la cinta, z -60..-10) y F (z 50..80) unidas por pasillos estrechos
	cart(s, -112, -110, 90, rng)
	crates(s, -66, -106)
	block(s, "CintaServicio", Vector3.new(44, 3, 4), Vector3.new(-98, 1.5, -46), P.steel, Enum.Material.Metal)
	block(s, "CintaServicio", Vector3.new(44, 3, 4), Vector3.new(-92, 1.5, -22), P.steel, Enum.Material.Metal)
	block(s, "CintaServicio", Vector3.new(4, 3, 20), Vector3.new(-124, 1.5, -34), P.steel, Enum.Material.Metal)
	crates(s, -66, -16)
	cart(s, -68, -54, 0, rng)
	crates(s, -114, 56)
	cart(s, -64, 71, 20, rng)
	block(s, "Mesa", Vector3.new(5, 3, 3), Vector3.new(-116, 1.5, 77), C.madera, Enum.Material.Wood)
	addMedkit(refs, s, Vector3.new(-116, 3, 77))
	addCans(refs, s, Vector3.new(-66, 0, -75), 75) -- el cuartito del pasillo (de ahí salen zombies)
	addCans(refs, s, Vector3.new(-126, 0, -14))
	for _, run in { { -94, -100, -60 }, { -106, -10, 50 }, { -74, 80, 100 } } do
		local pipe = deco(block(s, "Tuberia", Vector3.new(run[3] - run[2], 1, 1), CFrame.new(run[1], WALL_H - 1.6, (run[2] + run[3]) / 2) * CFrame.Angles(0, math.pi / 2, 0), C.oxido, Enum.Material.Metal))
		pipe.Shape = Enum.PartType.Cylinder
	end
	floorLine(s, -95, -100, -95, -60, P.yellow)
	floorLine(s, -105, -10, -105, 50, P.yellow)
	floorLine(s, -75, 80, -75, 110, P.yellow)
	floorLine(s, -75, 110, -40, 110, P.yellow)
	addAmbush(refs.ambushesZone2, s, "SalaE", 39, 1, 43, 7, { { 37, 8 }, { 46, 5 } })
	addAmbush(refs.ambushesZone2, s, "SalaF", 50, 2, 52, 7, { { 46, 5 }, { 53, 9 } })

	-- APRON: la plataforma junto a las puertas de la planta baja, con camiones, contenedores y trenes de equipaje
	for _, r in rects(function(ch, row)
		return ch == "B" and row > 31 and row < 57 and "truck" or nil
	end) do
		if r.row == 35 then
			fuelTruck(s, (r.x1 + r.x2) / 2, (r.z1 + r.z2) / 2, false)
		else
			shuttle(s, (r.x1 + r.x2) / 2, (r.z1 + r.z2) / 2, true, C.blanco)
		end
	end
	baggageTrain(s, 64, -122, 2, rng)
	baggageTrain(s, 112, 84, 2, rng)
	for _, spot in { { 112, -112, 0 }, { 119, -112, 8 }, { 114, -64, 0 }, { 121, -60, 30 }, { 68, 6, 0 }, { 104, 34, 12 }, { 110, 34, 0 }, { 120, 58, 0 }, { 64, 84, 20 } } do
		cargo(s, spot[1], spot[2], spot[3])
	end
	car(s, 66, -6, 4, C.blanco)
	for _, z in { -70, -46, 74, 98 } do
		barrier(s, 78, z, false)
	end
	for _, line in { { 60, -130, 60, 14 }, { 60, 14, 90, 14 }, { 90, 14, 90, 66 }, { 60, 66, 90, 66 }, { 60, 66, 60, 110 }, { 45, 110, 60, 110 } } do
		floorLine(s, line[1], line[2], line[3], line[4], P.blue)
	end
	addCans(refs, s, Vector3.new(125, 0, -125))
	addCans(refs, s, Vector3.new(125, 0, 114), 75)
	addMedkit(refs, s, Vector3.new(86, 0, 72))
	addAmbush(refs.ambushesZone2, s, "Rampa", 37, 19, 44, 26, { { 36, 26 }, { 45, 26 } })

	-- Crew Call: el puesto de cada tripulante (uno por ruta) y los puntos de donde sale la horda que atrae cada caída
	refs.crew = {
		members = {
			{ id = "Captain", home = Vector3.new(0, 0, -45) }, -- CONCOURSE: entre los mostradores de facturación
			{ id = "Attendant", home = Vector3.new(-95, 0, -34) }, -- SERVICE: la sala de la cinta de equipaje
			{ id = "Security", home = Vector3.new(104, 0, -8) }, -- APRON: la plataforma
		},
		hordePoints = {},
	}

	-- Tienda 2: Duty Free, hueco de la pared este del terminal (columnas 18 a 20, filas 48 y 49)
	MapKit.buildShop(map, refs, { zone = "Zone2", origin = Vector3.new(40, 0, 40), forward = Vector3.xAxis, width = 20, depth = 30, title = "DUTY FREE" })
end

---------------------------------------------------------------------------------------------------
-- Punto seguro 2: Fire Station, el cuartel de bomberos del aeropuerto (x -30..30, z 130..170)

local function buildFireStation(map, refs)
	local station = newFolder(map, "FireStation")
	refs.safe2 = {
		volume = volume(station, "FireStationVolume", -30, 30, 130, 170, 12),
		exitDoor = makeDoor(station, "stationExit", "StationExitDoor"),
		extraExits = { makeDoor(station, "stationWest", "StationExitDoorW"), makeDoor(station, "stationEast", "StationExitDoorE") },
		spawn = CFrame.lookAt(Vector3.new(0, 3, 146), Vector3.new(0, 3, 170)),
	}
	tube(station, Vector3.new(-14, WALL_H - 0.2, 150), 36, 1.3)
	tube(station, Vector3.new(14, WALL_H - 0.2, 150), 36, 1.3)
	-- Camioneta de bomberos, taquillas, literas y un banco con el botiquín
	block(station, "CamionetaBomberos", Vector3.new(16, 6, 7), Vector3.new(20, 3.6, 137), C.rojo, Enum.Material.Metal)
	deco(block(station, "CamionetaRuedas", Vector3.new(12, 2, 7.2), Vector3.new(20, 1, 137), P.dark, Enum.Material.Rubber))
	deco(block(station, "CamionetaBaliza", Vector3.new(3, 0.6, 1), Vector3.new(24, 6.9, 137), C.azul, Enum.Material.Neon))
	for i = 0, 3 do
		block(station, "Taquilla", Vector3.new(3, 8, 2), Vector3.new(-27 + i * 3.2, 4, 168.8), P.steel, Enum.Material.Metal)
	end
	for _, y in { 1.5, 5 } do
		block(station, "Litera", Vector3.new(4, 0.8, 9), Vector3.new(-27.6, y, 138), C.cobalto, Enum.Material.Fabric)
	end
	block(station, "Banco", Vector3.new(8, 2, 2.4), Vector3.new(20, 1, 168.4), C.madera, Enum.Material.Wood)
	addMedkit(refs, station, Vector3.new(20, 2, 168.4))
	hangSign(station, Vector3.new(0, 16.4, 130.6), Vector3.zAxis, 16, "AIRPORT FIRE STATION")
	hangSign(station, Vector3.new(0, 16.4, 169.4), -Vector3.zAxis, 14, "↑ GATES", P.red)
	hangSign(station, Vector3.new(-29.6, 16.4, 155), Vector3.xAxis, 9, "↑ HANGARS", P.yellow)
	hangSign(station, Vector3.new(29.6, 16.4, 155), -Vector3.xAxis, 9, "↑ APRON", P.blue)
end

---------------------------------------------------------------------------------------------------
-- Sector 3: Gates & Hangars (z 180..330) y la plataforma de la extracción (z 330..410)

local function buildGates(map, refs, config, rng, spawnRoot)
	local s = newFolder(map, "Sector3")

	-- CONCOURSE: el pasillo de las puertas de embarque, largo y recto (x -20..20), con una sala a cada lado
	gateBay(s, -40, -20, 200, 210, "GATE A1")
	gateBay(s, -40, -20, 280, 290, "GATE A3")

	-- ALTURA: los fingers de las puertas A2 y A4. De cada sala sube una rampa al hueco del muro (celda J) y el túnel, de techo
	-- bajo, sale sobre la plataforma hasta el morro de su avión. Una pasarela al aire une las dos cabezas (la ruta alta paralela a
	-- la APRON) y de ella baja una rampa de servicio a la plataforma, entre los dos aviones.
	local fingerWall = hex("#B9C0C7")
	for _, bay in { { z = 235, name = "GATE A2", open = 1 }, { z = 305, name = "GATE A4", open = -1 } } do
		local z = bay.z
		hangSign(s, Vector3.new(20.4, 16.4, z), -Vector3.xAxis, 8, bay.name)
		rampTo(s, Vector3.new(21, 0, z), Vector3.new(40, DECK, z), 6)
		deck(s, 40, 74, z - 3, z + 3, "Finger")
		block(s, "FingerTecho", Vector3.new(24, 0.6, 7), Vector3.new(62, DECK + 8.3, z), P.steel, Enum.Material.Metal)
		for _, side in { -1, 1 } do
			local x2 = side == bay.open and 68 or 74 -- el lado de la pasarela queda abierto al final
			block(s, "FingerPared", Vector3.new(x2 - 50, 3.4, 0.5), Vector3.new((50 + x2) / 2, DECK + 1.7, z + side * 3.25), fingerWall, Enum.Material.Metal)
			local glass = block(s, "FingerVidrio", Vector3.new(x2 - 50, 4.6, 0.3), Vector3.new((50 + x2) / 2, DECK + 5.7, z + side * 3.25), Color3.fromRGB(40, 52, 66), Enum.Material.Glass)
			glass.Transparency = 0.5
			glass.CanQuery = false
			glass.CastShadow = false
		end
		block(s, "FingerFondo", Vector3.new(0.5, 8, 7), Vector3.new(74.25, DECK + 4, z), P.dark, Enum.Material.Metal)
		for _, x in { 56, 71 } do
			deco(pole(s, "FingerPata", Vector3.new(x, 0, z), DECK - 0.8, 1.4, P.steel))
		end
		tube(s, Vector3.new(60, DECK + 7.8, z), 22, 0.8)
	end
	-- El fuelle de cada finger hacia la puerta de su avión (adorno)
	deco(block(s, "FingerFuelle", Vector3.new(5, 6.5, 7), Vector3.new(71, 7.4, 228.6), P.dark, Enum.Material.Fabric))
	deco(block(s, "FingerFuelle", Vector3.new(5, 6.5, 4), Vector3.new(71, 7.4, 300.4), P.dark, Enum.Material.Fabric))
	-- La pasarela entre las dos cabezas y la rampa de servicio
	deck(s, 68, 74, 238, 302)
	rail(s, 68, 238, 68, 302)
	rail(s, 74, 238, 74, 262)
	rail(s, 74, 268, 74, 302)
	rampTo(s, Vector3.new(96, 0, 265), Vector3.new(74, DECK, 265), 6)
	for _, z in { 250, 276, 292 } do
		deco(pole(s, "PasarelaPata", Vector3.new(68.6, 0, z), DECK - 0.8, 1, P.steel))
	end
	addCans(refs, s, Vector3.new(72, DECK, 233), 75)
	addMedkit(refs, s, Vector3.new(72, DECK, 307))
	seats(s, -9, 236, true)
	seats(s, 9, 262, true)
	seats(s, -9, 316, true)
	cart(s, 12, 196, 30, rng)
	hangSign(s, Vector3.new(0, 16.4, 181), -Vector3.zAxis, 20, "GATES A1 – A4  ·  RUNWAY ↑", P.red)
	hangSign(s, Vector3.new(0, 16.4, 322), -Vector3.zAxis, 16, "↑ RUNWAY", P.red)
	addCans(refs, s, Vector3.new(-36, 0, 286))
	floorLine(s, 0, 180, 0, 330, P.red)

	-- SERVICE: el hangar y sus talleres (x -100..-50, z 190..330), con motores desarmados, la grúa y poca luz
	engineStand(s, -86, 214, false)
	engineStand(s, -64, 246, true)
	engineStand(s, -88, 302, false)
	for _, x in { -97, -53 } do
		deco(pole(s, "GruaPoste", Vector3.new(x, 0, 272), 17, 1, P.signYellow))
	end
	deco(block(s, "GruaViga", Vector3.new(46, 1.4, 1.4), Vector3.new(-75, 17, 272), P.signYellow, Enum.Material.Metal))
	deco(block(s, "GruaGancho", Vector3.new(0.4, 6, 0.4), Vector3.new(-70, 13.4, 272), P.dark, Enum.Material.Metal))
	for _, z in { 198, 286 } do
		block(s, "CajonHerramientas", Vector3.new(2.4, 4, 5), Vector3.new(-51.6, 2, z), C.rojo, Enum.Material.Metal)
	end
	addMedkit(refs, s, Vector3.new(-51.6, 4, 198))
	crates(s, -94, 196)
	crates(s, -56, 314)
	barrel(s, -96, 240)
	barrel(s, -93, 243, C.lonaAzul)
	barrel(s, -55, 304)
	addCans(refs, s, Vector3.new(-116, 0, 205), 75) -- el fondo del taller (de ahí salen zombies)
	addCans(refs, s, Vector3.new(-96, 0, 314))
	floorLine(s, -65, 180, -65, 192, P.yellow)
	floorLine(s, -75, 192, -65, 192, P.yellow)
	floorLine(s, -75, 192, -75, 330, P.yellow)
	addAmbush(refs.ambushesZone3, s, "Hangar", 67, 4, 73, 8, { { 65, 1 }, { 74, 1 } }, Config.Ambush.FieldSize)

	-- APRON: la plataforma con dos aviones aparcados (se rodean; las alas cierran el paso) y el Tanque en el hueco entre ellos
	parkedPlane(s, Vector3.new(92, 0, 222), math.pi / 2)
	parkedPlane(s, Vector3.new(92, 0, 296), math.pi / 2)
	for _, spot in { { 56, 258, 0 }, { 124, 252, 10 }, { 118, 262, 0 }, { 60, 190, 0 } } do
		cargo(s, spot[1], spot[2], spot[3])
	end
	barrier(s, 86, 259, true)
	barrier(s, 100, 259, true)
	floorLine(s, 55, 180, 55, 330, P.blue)
	addMedkit(refs, s, Vector3.new(124, 0, 186))
	addCans(refs, s, Vector3.new(126, 0, 326), 75)
	addAmbush(refs.ambushesZone3, s, "Plataforma", 69, 19, 72, 26, { { 68, 26 }, { 76, 26 } }, Config.Ambush.TerminalSize, true)

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
	-- Cobertura alrededor de la radio y por la plataforma
	barrier(tarmac, -78, 354, true)
	barrier(tarmac, -78, 376, true)
	for _, spot in { { -40, 340, 0 }, { -34, 340, 0 }, { 30, 350, 15 }, { 84, 344, 0 }, { 90, 350, 0 }, { 110, 396, 0 }, { -110, 398, 0 }, { 20, 398, 30 } } do
		cargo(tarmac, spot[1], spot[2], spot[3])
	end
	fuelTruck(tarmac, 64, 372, true)
	baggageTrain(tarmac, -10, 342, 2, rng)
	addMedkit(refs, tarmac, Vector3.new(-80, 0, 347))
	addCans(refs, tarmac, Vector3.new(124, 0, 404))

	-- La pista sigue hacia el norte, fuera del límite jugable
	floor(tarmac, "Pista", -700, 700, 410, 462, P.asphalt, Enum.Material.Asphalt)
	floor(tarmac, "PistaHierba", -700, 700, 462, 620, hex("#2E3A2A"), Enum.Material.Grass)
	for x = -660, 660, 60 do
		deco(block(tarmac, "PistaRaya", Vector3.new(24, 0.06, 1.6), Vector3.new(x, FLOOR_TOP + 0.04, RUNWAY_Z), C.blanco, Enum.Material.SmoothPlastic))
	end

	-- Más entradas de zombies durante la extracción: las bocas de las tres rutas y las esquinas de la plataforma
	for _, point in { Vector3.new(0, 0, 322), Vector3.new(-75, 0, 322), Vector3.new(95, 0, 322), Vector3.new(125, 0, 336), Vector3.new(-124, 0, 402), Vector3.new(124, 0, 388) } do
		marker(spawnRoot.Extraction, point)
	end

	refs.extractionArea = volume(tarmac, "ExtractionArea", -130, 130, 330, PLAY_NORTH, 40) -- toda la plataforma: basta con que el equipo esté en ella
	refs.extractionGoal = volume(tarmac, "ExtractionGoal", -70, -30, 345, 385, 12) -- destino de la guía
	-- Remo One aterriza de oeste a este por la pista y para con la puerta delantera izquierda (y su escalerilla) hacia la plataforma
	refs.rescue = "Plane"
	refs.vanStop = CFrame.new(-40, 0, RUNWAY_Z) * CFrame.Angles(0, -math.pi / 2, 0)
	refs.vanStart = refs.vanStop * CFrame.new(0, Config.Plane.Height, Config.Plane.Approach)
	refs.boardPos = (refs.vanStop * CFrame.new(PlaneLayout.DoorX - 0.5 - PlaneLayout.StairRun, 0, PlaneLayout.DoorZ)).Position -- el pie de la escalerilla
	refs.boxSpots.Extraction = { { Vector3.new(-52, 0, 358), Vector3.new(44, 0, 340), Vector3.new(100, 0, 376) } }
end

---------------------------------------------------------------------------------------------------
-- Survival: Hangar 7. Arena cerrada (x -100..100, z -80..80) con un avión aparcado en el centro, la Tienda en una oficina de la
-- pared oeste y 12 puntos de aparición fuera, tras cuatro puertas que solo cruzan los zombies (grupos de colisión Zombie y
-- GateWall, como el portón del estadio de Morro Esperanza). No se construye el resto del aeropuerto.

local HANGAR_H = 34

-- Lo que usan server/AirportDetail y server/AirportArt (el pase de arte) de este constructor
local KIT = {
	P = P, WALL_H = WALL_H, HALL_H = HALL_H, HALL_ROWS = HALL_ROWS, HANGAR_H = HANGAR_H, RUNWAY_Z = RUNWAY_Z, PLAY_NORTH = PLAY_NORTH, DECK = DECK,
	cell = cell, band = band, isHall = isHall, isFacade = isFacade, ceilingAt = ceilingAt, rects = rects,
	hangSign = hangSign, tube = tube, column = column, counter = counter, seats = seats, cart = cart, newFolder = newFolder,
}

local function buildHangarArena(map, refs, spawnRoot, rng)
	local arena = newFolder(map, "Hangar7")
	local wallColor, steel = P.wall, P.steel

	-- Suelos: el hangar, la oficina de la Tienda y las tres zonas de fuera por donde llegan los zombies
	floor(arena, "PisoHangar", -104, 104, -84, 84, P.serviceFloor, Enum.Material.Concrete)
	floor(arena, "PisoOficina", -132, -104, -12, 12, P.tile, Enum.Material.SmoothPlastic)
	floor(arena, "Asfalto", -108, 108, 84, 128, P.asphalt, Enum.Material.Asphalt) -- plataforma norte
	floor(arena, "Asfalto", -108, 108, -128, -84, P.asphalt, Enum.Material.Asphalt) -- patio sur
	floor(arena, "PisoTaller", 104, 136, -62, 62, P.serviceFloor, Enum.Material.Concrete) -- pasillo del taller, al este

	-- Muros del hangar con sus cuatro puertas: el portón norte (60 de ancho), dos puertas al sur y una al este
	local function wall(x1, x2, z1, z2, y1, y2)
		return block(arena, "Muro", Vector3.new(x2 - x1, y2 - y1, z2 - z1), Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2), wallColor)
	end
	wall(-104, -30, 80, 84, 0, HANGAR_H)
	wall(30, 104, 80, 84, 0, HANGAR_H)
	wall(-30, 30, 80, 84, 24, HANGAR_H) -- dintel del portón
	wall(-104, -70, -84, -80, 0, HANGAR_H)
	wall(-50, 50, -84, -80, 0, HANGAR_H)
	wall(70, 104, -84, -80, 0, HANGAR_H)
	wall(-70, -50, -84, -80, 14, HANGAR_H)
	wall(50, 70, -84, -80, 14, HANGAR_H)
	wall(100, 104, -80, -10, 0, HANGAR_H)
	wall(100, 104, 10, 80, 0, HANGAR_H)
	wall(100, 104, -10, 10, 14, HANGAR_H)
	wall(-104, -100, -80, -10, 0, HANGAR_H)
	wall(-104, -100, 10, 80, 0, HANGAR_H)
	wall(-104, -100, -10, 10, 20, HANGAR_H)
	block(arena, "Techo", Vector3.new(208, 1, 168), Vector3.new(0, HANGAR_H + 0.5, 0), P.ceiling, Enum.Material.Metal)
	for _, z in { -54, 0, 54 } do
		deco(block(arena, "Cercha", Vector3.new(200, 2, 1.2), Vector3.new(0, HANGAR_H - 1.2, z), steel, Enum.Material.Metal))
	end
	-- La oficina (hueco de la pared oeste): paredes y techo
	wall(-134, -104, 10, 12, 0, 20)
	wall(-134, -104, -12, -10, 0, 20)
	wall(-134, -132, -10, 10, 0, 20)
	block(arena, "Techo", Vector3.new(30, 1, 24), Vector3.new(-119, 20.5, 0), P.ceiling, Enum.Material.SmoothPlastic)
	-- El pasillo del taller (este): paredes y techo
	wall(136, 138, -62, 62, 0, 16)
	wall(104, 138, 62, 64, 0, 16)
	wall(104, 138, -64, -62, 0, 16)
	block(arena, "Techo", Vector3.new(34, 1, 128), Vector3.new(121, 16.5, 0), P.ceiling, Enum.Material.SmoothPlastic)
	-- Vallas de la plataforma y del patio (los zombies aparecen detrás de vehículos, fuera de la vista)
	for _, side in { 1, -1 } do
		block(arena, "Valla", Vector3.new(220, 10, 2), Vector3.new(0, 5, side * 129), P.fence, Enum.Material.DiamondPlate)
		for _, x in { -109, 109 } do
			block(arena, "Valla", Vector3.new(2, 10, 44), Vector3.new(x, 5, side * 106), P.fence, Enum.Material.DiamondPlate)
		end
	end

	-- Puertas solo para zombies
	MapKit.zombieGate(arena, Vector3.new(60, 24, 3), CFrame.new(0, 12, 82))
	MapKit.zombieGate(arena, Vector3.new(20, 14, 3), CFrame.new(-60, 7, -82))
	MapKit.zombieGate(arena, Vector3.new(20, 14, 3), CFrame.new(60, 7, -82))
	MapKit.zombieGate(arena, Vector3.new(3, 14, 20), CFrame.new(102, 7, 0))

	-- 12 puntos de aparición: 5 en la plataforma norte, 4 en el patio sur y 3 en el pasillo del taller
	local spawns = newFolder(spawnRoot, "Survival")
	for _, point in {
		Vector3.new(-72, 0, 110), Vector3.new(-36, 0, 114), Vector3.new(0, 0, 118), Vector3.new(36, 0, 114), Vector3.new(72, 0, 110),
		Vector3.new(-82, 0, -110), Vector3.new(-38, 0, -114), Vector3.new(38, 0, -114), Vector3.new(82, 0, -110),
		Vector3.new(124, 0, -44), Vector3.new(128, 0, 0), Vector3.new(124, 0, 44),
	} do
		marker(spawns, point)
	end
	-- Vehículos fuera, delante de donde aparecen
	shuttle(arena, -54, 104, true, C.blanco)
	fuelTruck(arena, 54, 104, true)
	baggageTrain(arena, -20, -118, 2, rng)
	cargo(arena, 60, -100, 10)
	cargo(arena, -60, -98, 0)

	-- El avión aparcado, en el centro (el morro hacia el sur), y cobertura alrededor: contenedores, motores, la grúa y cajones
	parkedPlane(arena, Vector3.new(0, 0, 8), 0)
	for _, spot in { { -74, -52, 0 }, { -68, -52, 8 }, { 72, 50, 0 }, { 66, 56, 0 }, { -66, 52, 20 }, { 62, -54, 0 }, { 84, -20, 0 }, { -84, 34, 0 } } do
		cargo(arena, spot[1], spot[2], spot[3])
	end
	engineStand(arena, -46, -8, false)
	engineStand(arena, 46, 22, true)
	for _, x in { -94, 94 } do
		deco(pole(arena, "GruaPoste", Vector3.new(x, 0, 60), 26, 1.2, P.signYellow))
	end
	deco(block(arena, "GruaViga", Vector3.new(190, 1.6, 1.6), Vector3.new(0, 26, 60), P.signYellow, Enum.Material.Metal))
	deco(block(arena, "GruaGancho", Vector3.new(0.5, 8, 0.5), Vector3.new(-24, 21.2, 60), P.dark, Enum.Material.Metal))
	crates(arena, 30, -66)
	crates(arena, -88, -66)
	crates(arena, 88, 70)
	for _, z in { -52, 44 } do
		block(arena, "CajonHerramientas", Vector3.new(2.4, 4, 5), Vector3.new(98.4, 2, z), C.rojo, Enum.Material.Metal)
	end
	barrel(arena, -92, 12)
	barrel(arena, -89, 15, C.lonaAzul)
	barrel(arena, 20, 72)
	cart(arena, -26, -44, 30, rng)

	-- Luces: tubos altos en el hangar, la oficina y el taller, y dos mástiles fuera
	for _, x in { -66, -22, 22, 66 } do
		for _, z in { -52, 0, 52 } do
			tube(arena, Vector3.new(x, HANGAR_H - 0.2, z), 60, 1.5)
		end
	end
	tube(arena, Vector3.new(-118, 19.8, 0), 30, 1.2, true)
	tube(arena, Vector3.new(121, 15.8, -30), 30, 0.9, true)
	tube(arena, Vector3.new(121, 15.8, 30), 30, 0.9, true)
	mast(arena, -90, 100)
	mast(arena, 90, 100)
	mast(arena, -90, -100)
	mast(arena, 90, -100)

	-- Rótulos
	hangSign(arena, Vector3.new(0, 27.5, 79.6), -Vector3.zAxis, 30, "HANGAR 7")
	hangSign(arena, Vector3.new(99.6, 17, 0), -Vector3.xAxis, 14, "WORKSHOP  ·  STAFF ONLY")

	-- La Tienda del modo: caja de armas, munición y farmacia en la oficina
	MapKit.buildShop(map, refs, { zone = "Survival", origin = Vector3.new(-100, 0, 0), forward = -Vector3.xAxis, width = 20, depth = 30, title = "HANGAR OFFICE" })

	AirportDetail.arena(arena, rng, KIT)

	refs.survivalSpawn = CFrame.lookAt(Vector3.new(0, 3, -62), Vector3.new(0, 3, 0))
	refs.texts.survivalStart = "Hold Hangar 7! The first wave is coming. Shop first"

	-- Suelo de seguridad (cara superior a ras de y = 0)
	local safety = block(arena, "Limite", Vector3.new(300, 3, 280), Vector3.new(0, -1.5, 0), P.dark)
	safety.Transparency = 1
	safety.CanQuery = false
	safety.CastShadow = false
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
	invisible(Vector3.new(284, H, 2), Vector3.new(0, H / 2, PLAY_NORTH + 1)) -- norte: la pista no se pisa (el avión aterriza ahí)
	invisible(Vector3.new(300, 3, 960), Vector3.new(0, -1.5, 20)) -- suelo de seguridad (cara superior a ras de y = 0)
end

-- Los rótulos del terminal van solo en inglés: shared/Lang no los traduce (los avisos y etiquetas de juego sí se traducen)
function MapBuilderAirport.literalSigns(map)
	for _, gui in map:GetDescendants() do
		if gui:IsA("SurfaceGui") then
			gui:SetAttribute("NoTranslate", true)
		end
	end
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
		hold = "Hold out until Remo One lands!",
		arriving = "Remo One is landing!",
		board = "Board Remo One! Hold E at the stairs",
		run = "Run to Remo One!",
		rescueLabel = "REMO ONE",
	}

	if options.survival then
		-- Survival: solo la arena del Hangar 7
		buildHangarArena(map, refs, spawnRoot, rng)
		MapBuilderAirport.literalSigns(map)
		return refs
	end

	buildShell(map, spawnRoot)
	AirportArt.structure(map, KIT) -- revestimiento de muros, salones altos con cerchas y tragaluces, fachada de vidrio
	AirportArt.terrain(KIT)
	buildLights(map)
	buildLobby(map, refs, rng)
	buildArrivals(map, refs, rng)
	local artRng = Random.new(config.Seed + 5) -- su propio azar: el pase de arte no cambia lo que se sortea en lo demás
	AirportArt.lobby(map, refs, artRng, KIT)
	AirportArt.arrivals(map, refs, artRng, KIT)
	buildLounge(map, refs)
	buildDepartures(map, refs, rng)
	buildFireStation(map, refs)
	buildGates(map, refs, config, rng, spawnRoot)
	buildLimits(map)
	AirportDetail.build(map, refs, rng, KIT) -- el pase de arte (lo último: no cambia lo que se sorteó antes)
	for _, point in spawnRoot.Zone2:GetChildren() do
		table.insert(refs.crew.hordePoints, point.Position - Vector3.new(0, 0.5, 0))
	end

	MapBuilderAirport.literalSigns(map)

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
