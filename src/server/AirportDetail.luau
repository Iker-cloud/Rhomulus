-- Pase de arte de Last Call (el aeropuerto): todo lo que no cambia por dónde se camina. Carteles de ruta en cada paso entre
-- rutas, avisos de cuarentena, pantallas de vuelos, pistas sueltas de la historia (notas, pizarras, pintadas), ventanales,
-- máquinas, maletas y sangre, charcos en la plataforma, balizas (pista, torre, puntos seguros) y los altavoces de la megafonía.
-- Lo llama server/MapBuilderAirport al final, con sus ayudantes en `kit`. Casi todo es decoración sin colisión.
-- Rótulos solo en inglés (son del terminal: no se traducen).
local CollectionService = game:GetService("CollectionService")

local AirportLayout = require(script.Parent.AirportLayout)
local MapKit = require(script.Parent.MapKit)

local AirportDetail = {}

local L = AirportLayout
local C = MapKit.C
local FLOOR_TOP = MapKit.FLOOR_TOP
local RHO_BLACK = MapKit.RHO_BLACK
local block = MapKit.block
local deco = MapKit.deco
local boardText = MapKit.boardText
local boardRect = MapKit.boardRect
local blankBoard = MapKit.blankBoard

local PAPER = Color3.fromRGB(226, 216, 190)
local INK = Color3.fromRGB(40, 34, 30)
local BLOOD = Color3.fromRGB(96, 14, 14)
local WHITE = Color3.fromRGB(232, 234, 236)
local AMBER = Color3.fromRGB(255, 170, 40)
local RED_LIGHT = Color3.fromRGB(255, 50, 40)

-- Tablero en una pared: `position` es su centro y `facing` hacia dónde mira
local function wallBoard(parent, name, size, position, facing, color, pixels)
	return blankBoard(parent, name, size, CFrame.lookAt(position, position + facing), color, pixels)
end

-- Aviso de cuarentena (amarillo y negro, 6 × 8)
local function quarantine(parent, position, facing, kit)
	local _, gui = wallBoard(parent, "AvisoCuarentena", Vector3.new(6, 8, 0.2), position, facing, kit.P.signYellow, 40)
	boardRect(gui, 0, 0, 1, 0.2, RHO_BLACK)
	boardText(gui, "NOTICE", 0.08, 0.035, 0.84, 0.13, kit.P.signYellow, Enum.TextXAlignment.Center)
	boardText(gui, "QUARANTINE", 0.06, 0.26, 0.88, 0.17, RHO_BLACK, Enum.TextXAlignment.Center)
	boardText(gui, "IN EFFECT", 0.06, 0.43, 0.88, 0.17, RHO_BLACK, Enum.TextXAlignment.Center)
	boardRect(gui, 0.08, 0.64, 0.84, 0.012, RHO_BLACK)
	boardText(gui, "DO NOT LEAVE THE TERMINAL", 0.08, 0.68, 0.84, 0.08, RHO_BLACK, Enum.TextXAlignment.Center)
	boardText(gui, "REPORT ANY BITE TO STAFF", 0.08, 0.77, 0.84, 0.08, RHO_BLACK, Enum.TextXAlignment.Center)
	boardText(gui, "RHM AIRPORT AUTHORITY", 0.08, 0.89, 0.84, 0.06, RHO_BLACK, Enum.TextXAlignment.Center)
end

-- Pantalla de vuelos (14 × 7): { vuelo, destino, estado }
local function flightScreen(parent, position, facing, title, flights)
	local _, gui = wallBoard(parent, "PantallaVuelos", Vector3.new(14, 7, 0.3), position, facing, RHO_BLACK, 50)
	boardText(gui, title, 0.04, 0.04, 0.6, 0.12, Color3.fromRGB(242, 194, 48))
	boardRect(gui, 0.04, 0.18, 0.92, 0.008, Color3.fromRGB(242, 194, 48))
	for i, flight in flights do
		local y = 0.2 + (i - 1) * 0.155
		boardText(gui, flight[1], 0.04, y + 0.02, 0.2, 0.1, C.blanco)
		boardText(gui, flight[2], 0.26, y + 0.02, 0.4, 0.1, C.blanco)
		boardText(gui, flight[3], 0.62, y + 0.02, 0.34, 0.1, C.rojo, Enum.TextXAlignment.Right)
	end
end

-- Nota de papel (pista de la historia): pocas líneas, se lee de cerca. `cframe` = centro; la cara escrita es la frontal (-Z).
local function note(parent, cframe, lines, size, color, ink)
	size = size or Vector3.new(3.2, 4, 0.08)
	local _, gui = blankBoard(parent, "Nota", size, cframe, color or PAPER, 70)
	local step = 0.84 / #lines
	for i, line in lines do
		local l = boardText(gui, line, 0.07, 0.08 + (i - 1) * step, 0.86, math.min(step * 0.82, 0.17), ink or INK)
		l.Font = Enum.Font.SpecialElite
	end
end

local function wallNote(parent, position, facing, lines, size, color, ink)
	note(parent, CFrame.lookAt(position, position + facing) * CFrame.Angles(0, 0, math.rad((position.X + position.Z) % 7 - 3)), lines, size, color, ink)
end

-- Pintada en la pared: letras de color sobre un tablero del color del muro
local function scrawl(parent, position, facing, size, lines, color, kit)
	local _, gui = wallBoard(parent, "Pintada", size, position, facing, kit.P.wall, 30)
	for i, line in lines do
		local l = boardText(gui, line, 0.03, (i - 1) / #lines + 0.04, 0.94, 1 / #lines - 0.08, color, Enum.TextXAlignment.Center, (i % 2 == 0) and 1.5 or -2)
		l.Font = Enum.Font.PermanentMarker
	end
end

-- Mancha de sangre estilizada en el suelo (disco plano) con salpicaduras
local function blood(parent, x, z, size, rng, y)
	y = (y or 0) + FLOOR_TOP + 0.03
	for i = 1, 3 do
		local d = i == 1 and size or size * rng:NextNumber(0.2, 0.45)
		local offset = i == 1 and Vector3.zero or Vector3.new(rng:NextNumber(-size, size) * 0.7, 0, rng:NextNumber(-size, size) * 0.7)
		local disc = deco(block(parent, "Sangre", Vector3.new(0.05, d, d), CFrame.new(Vector3.new(x, y, z) + offset) * CFrame.Angles(0, 0, math.pi / 2), BLOOD, Enum.Material.SmoothPlastic))
		disc.Shape = Enum.PartType.Cylinder
	end
end

-- Charco (disco oscuro que refleja)
local function puddle(parent, x, z, diameter)
	local disc = deco(block(parent, "Charco", Vector3.new(0.04, diameter, diameter), CFrame.new(x, FLOOR_TOP + 0.03, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(18, 22, 28), Enum.Material.SmoothPlastic))
	disc.Shape = Enum.PartType.Cylinder
	disc.Reflectance = 0.35
end

local LUGGAGE = { C.cobalto, C.terracota, C.lima, C.mostaza, C.salmon, C.oscuro }
local function luggage(parent, x, z, rng, y)
	local tipped = rng:NextNumber() < 0.5
	local size = tipped and Vector3.new(2.4, 0.9, 1.6) or Vector3.new(1.6, 2.2, 0.9)
	deco(block(parent, "Maleta", size, CFrame.new(x, (y or 0) + size.Y / 2 + FLOOR_TOP, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), LUGGAGE[rng:NextInteger(1, #LUGGAGE)], Enum.Material.SmoothPlastic))
end

-- Cartel de suelo mojado (un tablero amarillo inclinado)
local function wetFloor(parent, x, z, yaw, kit)
	local cf = CFrame.new(x, 1.25, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-12), 0, 0)
	local _, gui = blankBoard(parent, "SueloMojado", Vector3.new(1.5, 2.5, 0.12), cf, kit.P.signYellow, 50)
	boardText(gui, "CAUTION", 0.08, 0.12, 0.84, 0.22, RHO_BLACK, Enum.TextXAlignment.Center)
	boardText(gui, "WET", 0.08, 0.42, 0.84, 0.2, RHO_BLACK, Enum.TextXAlignment.Center)
	boardText(gui, "FLOOR", 0.08, 0.62, 0.84, 0.2, RHO_BLACK, Enum.TextXAlignment.Center)
end

-- Máquina expendedora (bloque con el frente de neón tenue). `facing` = hacia dónde da el frente.
local function vending(parent, position, facing, color)
	local cf = CFrame.lookAt(position, position + facing)
	block(parent, "Expendedora", Vector3.new(4, 7, 2.6), cf, Color3.fromRGB(30, 32, 36), Enum.Material.Metal)
	local front = deco(block(parent, "ExpendedoraFrente", Vector3.new(3.2, 5.4, 0.1), cf * CFrame.new(0, 0.4, -1.36), color, Enum.Material.Neon))
	front.Transparency = 0.35
end

-- Altavoz de la megafonía (client/Announcer suena por el más cercano)
local function speaker(parent, position)
	local part = deco(block(parent, "Altavoz", Vector3.new(1.6, 1, 1.6), position, Color3.fromRGB(26, 28, 30), Enum.Material.Metal))
	CollectionService:AddTag(part, "PaSpeaker")
	return part
end

-- Baliza que parpadea (client/Beacons). `light` = alcance de su luz (sin él, solo brilla la pieza).
local function beacon(parent, position, color, period, phase, duty, light, size)
	local part = deco(block(parent, "Baliza", size or Vector3.new(1, 1, 1), position, color, Enum.Material.Neon))
	part:SetAttribute("Period", period)
	part:SetAttribute("Phase", phase or 0)
	part:SetAttribute("Duty", duty or 0.5)
	if light then
		local glow = Instance.new("PointLight")
		glow.Color = color
		glow.Range = light
		glow.Brightness = 1.6
		glow.Shadows = false
		glow.Parent = part
	end
	CollectionService:AddTag(part, "Beacon")
	return part
end
AirportDetail.beacon = beacon

-- Luz fija de pista (pieza de neón sin luz propia: son muchas)
local function runwayLight(parent, x, z, color)
	deco(block(parent, "LuzPista", Vector3.new(1, 0.6, 1), Vector3.new(x, 0.35, z), color, Enum.Material.Neon))
end

---------------------------------------------------------------------------------------------------

-- Carteles de ruta sobre cada paso entre dos rutas (los puntos seguros y el lobby ya tienen los suyos). Filas de la cuadrícula
-- (x,5 = el paso ocupa dos filas). Bajo la pasarela del sector 2 (filas 32 a 44) cuelgan de su borde, más bajos.
local WEST_PASSES = { 10, 18, 25, 40, 51, 55.5, 66, 74 } -- SERVICE <-> CONCOURSE
local EAST_PASSES = { 9, 20, 25, 34, 42, 55.5, 69, 76 } -- CONCOURSE <-> APRON
local function routeSigns(folder, kit)
	local P = kit.P
	for _, row in WEST_PASSES do
		local z = L.z(row) + 5
		local under = row >= 32 and row <= 44
		local gates = row >= 63 -- en el sector 3 el pasillo es más estrecho
		kit.hangSign(folder, Vector3.new(under and -31.6 or (gates and -19.6 or -39.6), under and 8.6 or 14, z), Vector3.xAxis, 9, "↑ SERVICE", P.yellow)
		kit.hangSign(folder, Vector3.new(gates and -50.4 or -60.4, 14, z), -Vector3.xAxis, 9, "↑ CONCOURSE", P.red)
	end
	for _, row in EAST_PASSES do
		local z = L.z(row) + 5
		local under = row >= 32 and row <= 44
		kit.hangSign(folder, Vector3.new(under and 31.6 or 39.6, under and 8.6 or 14, z), -Vector3.xAxis, 9, "↑ APRON", P.blue)
		kit.hangSign(folder, Vector3.new(50.4, 14, z), Vector3.xAxis, 9, "↑ CONCOURSE", P.red)
	end
end

-- Ventanales altos (falsos) del terminal hacia la plataforma: una banda de vidrio oscuro por cada tramo del muro este
local function windows(folder, kit)
	local glass = Color3.fromRGB(26, 40, 62)
	local row = 5
	while row <= 77 do
		local function solid(r)
			local inside = kit.cell(r, 17)
			return kit.cell(r, 18) == "#" and (inside == "." or inside == "s") and kit.cell(r, 19) == ","
		end
		if solid(row) then
			local last = row
			while solid(last + 1) do
				last += 1
			end
			local z1, z2 = L.z(row) + 1.5, L.z(last + 1) - 1.5
			for _, x in { 39.92, 50.08 } do
				local pane = deco(block(folder, "Ventanal", Vector3.new(0.16, 4.4, z2 - z1), Vector3.new(x, 16.2, (z1 + z2) / 2), glass, Enum.Material.Glass))
				pane.Reflectance = 0.25
			end
			row = last + 1
		else
			row += 1
		end
	end
end

-- Charcos repartidos por el exterior (celdas de asfalto)
local function puddles(folder, kit, rng, amount)
	local cells = {}
	for row = 1, 85 do
		for col = 1, 26 do
			if kit.cell(row, col) == "," then
				table.insert(cells, { row, col })
			end
		end
	end
	for _ = 1, amount do
		local pick = cells[rng:NextInteger(1, #cells)]
		local center = L.center(pick[1], pick[2])
		puddle(folder, center.X + rng:NextNumber(-3, 3), center.Z + rng:NextNumber(-3, 3), rng:NextNumber(5, 13))
	end
end

function AirportDetail.build(map, refs, rng, kit)
	local P = kit.P
	local folder = Instance.new("Folder")
	folder.Name = "Detalle"
	folder.Parent = map
	local X, Z = Vector3.xAxis, Vector3.zAxis

	routeSigns(folder, kit)
	windows(folder, kit)
	puddles(folder, kit, rng, 34)

	-- Avisos de cuarentena
	quarantine(folder, Vector3.new(39.7, 5.6, -250), -X, kit)
	quarantine(folder, Vector3.new(-39.7, 5.6, -366), X, kit)
	quarantine(folder, Vector3.new(-39.7, 5.6, -74), X, kit)
	quarantine(folder, Vector3.new(39.7, 5.6, -40), -X, kit)
	quarantine(folder, Vector3.new(-19.7, 5.6, 255), X, kit)
	quarantine(folder, Vector3.new(50.3, 5.6, -65), X, kit) -- por fuera, en la plataforma
	quarantine(folder, Vector3.new(-72, 5.6, -439.7), Z, kit) -- muelle de carga

	-- Pantallas de vuelos
	flightScreen(folder, Vector3.new(-39.7, 10.5, -238), X, "ARRIVALS", {
		{ "RM-2", "SAN REMO", "QUARANTINED" }, { "RH-90", "PUERTO ALBA", "DIVERTED" }, { "LC-12", "VILLA ESPERANZA", "CANCELLED" },
		{ "RM-18", "COSTA BRAVA", "NO CONTACT" }, { "RH-7", "MORRO ESPERANZA", "CANCELLED" },
	})
	flightScreen(folder, Vector3.new(-39.7, 15.6, -64), X, "DEPARTURES", {
		{ "RM-2", "SAN REMO", "LAST CALL" }, { "RH-118", "PUERTO ALBA", "CANCELLED" }, { "LC-07", "VILLA ESPERANZA", "CANCELLED" },
		{ "RM-31", "COSTA BRAVA", "CANCELLED" }, { "REMO 1", "RUNWAY 09", "STANDBY" },
	})

	-- Pistas sueltas de la historia (de sur a norte)
	wallNote(folder, Vector3.new(-33, 6.4, -439.7), Z, { "LOST & FOUND", "Closed until further notice.", "If you can read this,", "head for the runway.", "— R." })
	note(folder, CFrame.new(0, 3.66, -212) * CFrame.Angles(0, math.rad(200), 0) * CFrame.Angles(math.rad(90), 0, 0), { "Captain Reyes kept", "his access card on him.", "He went back to check-in.", "He never came out." })
	wallNote(folder, Vector3.new(-129.7, 6.5, -34), X, { "She locked herself in", "with the conveyor.", "Still wearing the uniform.", "Still has her card." })
	wallNote(folder, Vector3.new(50.3, 5, -6), X, { "SECURITY LOG — 02:14", "Checkpoint sealed.", "Three cards open it.", "Chief is out on the ramp.", "Do not approach him." })
	do -- junto al lector del control
		local _, gui = wallBoard(folder, "AvisoControl", Vector3.new(8, 4.4, 0.2), Vector3.new(24, 6.4, 119.7), -Z, P.signYellow, 40)
		boardRect(gui, 0, 0, 1, 0.26, RHO_BLACK)
		boardText(gui, "CREW ONLY BEYOND THIS POINT", 0.04, 0.05, 0.92, 0.16, P.signYellow, Enum.TextXAlignment.Center)
		boardText(gui, "3 ACCESS CARDS REQUIRED", 0.04, 0.36, 0.92, 0.26, RHO_BLACK, Enum.TextXAlignment.Center)
		boardText(gui, "CAPTAIN · FLIGHT ATTENDANT · SECURITY CHIEF", 0.04, 0.7, 0.92, 0.14, RHO_BLACK, Enum.TextXAlignment.Center)
	end
	do -- pizarra de la Fire Station: el plan del avión de rescate
		local _, gui = wallBoard(folder, "Pizarra", Vector3.new(13, 6.4, 0.2), Vector3.new(20, 8, 169.7), -Z, WHITE, 40)
		local lines = { "REMO ONE — RUNWAY 09", "FUEL: OK      SEATS: 4", "CALL IT FROM THE TOWER RADIO", "IT WILL NOT WAIT FOR US" }
		for i, line in lines do
			local l = boardText(gui, line, 0.05, 0.06 + (i - 1) * 0.23, 0.9, 0.18, i == 4 and C.rojo or Color3.fromRGB(30, 60, 140))
			l.Font = Enum.Font.PermanentMarker
		end
	end
	scrawl(folder, Vector3.new(-39.7, 7.4, 285), X, Vector3.new(8, 3.4, 0.2), { "THEY BOARDED", "ANYWAY" }, C.rojo, kit)
	scrawl(folder, Vector3.new(-39.7, 9, -340), X, Vector3.new(9, 2.6, 0.2), { "STAY TOGETHER" }, C.rojo, kit)
	scrawl(folder, Vector3.new(50.3, 7, 200), X, Vector3.new(14, 3.4, 0.2), { "REMO ONE", "← LAST FLIGHT OUT" }, WHITE, kit)
	wallNote(folder, Vector3.new(-89.7, 5.2, 373), X, { "TOWER", "Remo One answers", "on this radio.", "When you call,", "they will hear it too." })

	-- Sangre, maletas abandonadas y suelo mojado
	for _, spot in { { 4, -330, 5 }, { -22, -214, 4 }, { -96, -262, 4 }, { 62, -300, 5 }, { -2, -48, 6 }, { -94, -30, 5 }, { 100, -6, 5 }, { 8, 108, 4 }, { -6, 284, 6 }, { -72, 268, 5 }, { 92, 262, 6 }, { -70, 362, 4 } } do
		blood(folder, spot[1], spot[2], spot[3], rng)
	end
	for _ = 1, 26 do
		local z = rng:NextNumber(-385, 315)
		if not (z > -195 and z < -128) and not (z > 96 and z < 182) then
			local half = z > 180 and 16 or 34
			luggage(folder, rng:NextNumber(-half, half), z, rng)
		end
	end
	for _, spot in { { -8, -300, 0.4 }, { 10, -150, 2.2 }, { -6, 64, 1.1 }, { 4, 208, 2.8 }, { -75, -396, 0.2 } } do
		wetFloor(folder, spot[1], spot[2], spot[3], kit)
	end

	-- Máquinas expendedoras
	vending(folder, Vector3.new(-38.6, 3.5, -306), X, C.cobalto)
	vending(folder, Vector3.new(38.6, 3.5, 74), -X, C.rojo)
	vending(folder, Vector3.new(18.6, 3.5, 274), -X, C.lima)

	-- Megafonía: altavoces en el techo del terminal y de los túneles, y bocinas en el muro de la plataforma y en la torre
	for _, z in { -360, -290, -220, -160, -100, -30, 40, 104, 150, 200, 260, 320 } do
		speaker(folder, Vector3.new(0, kit.WALL_H - 0.5, z))
	end
	for _, spot in { { -75, -385 }, { -105, -305 }, { -85, -225 }, { -95, -80 }, { -105, 20 }, { -75, 95 }, { -75, 215 }, { -75, 305 } } do
		speaker(folder, Vector3.new(spot[1], kit.WALL_H - 0.5, spot[2]))
	end
	for _, z in { -335, -205, -55, 65, 185, 285 } do
		speaker(folder, Vector3.new(50.8, 13, z))
	end
	speaker(folder, Vector3.new(-89.2, 18, 358))
	speaker(folder, Vector3.new(40, 16, 330.8))

	-- Balizas: luces fijas de la pista y de la plataforma, obstáculo y faro de la torre, y avisos de los puntos seguros y la radio
	local runwayNear, runwayFar = kit.RUNWAY_Z - 24, kit.RUNWAY_Z + 24
	for x = -650, 650, 50 do
		runwayLight(folder, x, runwayNear, WHITE)
		runwayLight(folder, x, runwayFar, WHITE)
	end
	for x = -117, 117, 26 do
		runwayLight(folder, x, kit.PLAY_NORTH - 17, Color3.fromRGB(60, 110, 255))
	end
	for i = 0, 5 do -- luces de aproximación: una ráfaga que corre hacia la pista (por donde llega Remo One)
		beacon(folder, Vector3.new(-700 + i * 34, 0.5, kit.RUNWAY_Z), WHITE, 1.5, -i / 8, 0.12, nil, Vector3.new(1.6, 0.8, 1.6))
	end
	beacon(folder, Vector3.new(-105, kit.WALL_H + 55, 365), RED_LIGHT, 2, 0, 0.5, 46, Vector3.new(1.6, 1.6, 1.6))
	beacon(folder, Vector3.new(-111, kit.WALL_H + 54.6, 359), Color3.fromRGB(90, 255, 140), 3, 0, 0.2, 30)
	beacon(folder, Vector3.new(-99, kit.WALL_H + 54.6, 371), WHITE, 3, 0.5, 0.2, 30)
	for _, pair in {
		{ Vector3.new(-11.6, 16.4, -190.5), Vector3.new(11.6, 16.4, -190.5) }, -- entrada del Sky Lounge
		{ Vector3.new(-13.6, 16.4, 119.5), Vector3.new(13.6, 16.4, 119.5) }, -- el control (entrada de la Fire Station)
		{ Vector3.new(-91, 20.5, 357), Vector3.new(-91, 20.5, 373) }, -- la torre: la radio
	} do
		beacon(folder, pair[1], AMBER, 1.4, 0, 0.5, 18)
		beacon(folder, pair[2], AMBER, 1.4, 0.5, 0.5, 18)
	end
	return folder
end

-- Detalle de la arena de Survival (Hangar 7): avisos, una pista, charcos fuera, altavoces y balizas del portón
function AirportDetail.arena(arena, rng, kit)
	local X, Z = Vector3.xAxis, Vector3.zAxis
	quarantine(arena, Vector3.new(-99.7, 5.6, 40), X, kit)
	quarantine(arena, Vector3.new(99.7, 5.6, -40), -X, kit)
	do
		local _, gui = wallBoard(arena, "Pizarra", Vector3.new(13, 6.4, 0.2), Vector3.new(-40, 8, -79.7), Z, WHITE, 40)
		local lines = { "HANGAR 7 — NIGHT SHIFT", "DOORS STAY SHUT", "NOBODY IS COMING", "HOLD THE LINE" }
		for i, line in lines do
			local l = boardText(gui, line, 0.05, 0.06 + (i - 1) * 0.23, 0.9, 0.18, i >= 3 and C.rojo or Color3.fromRGB(30, 60, 140))
			l.Font = Enum.Font.PermanentMarker
		end
	end
	scrawl(arena, Vector3.new(60, 9, 79.7), -Z, Vector3.new(16, 3.4, 0.2), { "THEY COME IN WAVES" }, C.rojo, kit)
	for _, spot in { { -30, 30, 6 }, { 40, -40, 5 }, { -70, -20, 4 }, { 76, 20, 5 } } do
		blood(arena, spot[1], spot[2], spot[3], rng)
	end
	for _ = 1, 10 do
		local side = rng:NextNumber() < 0.5 and -1 or 1
		puddle(arena, rng:NextNumber(-100, 100), side * rng:NextNumber(90, 124), rng:NextNumber(5, 12))
	end
	for _, spot in { { -50, -40 }, { 50, -40 }, { -50, 40 }, { 50, 40 } } do
		speaker(arena, Vector3.new(spot[1], kit.HANGAR_H - 0.5, spot[2]))
	end
	beacon(arena, Vector3.new(-32, 25, 79.5), AMBER, 1.4, 0, 0.5, 18)
	beacon(arena, Vector3.new(32, 25, 79.5), AMBER, 1.4, 0.5, 0.5, 18)
end

return AirportDetail
