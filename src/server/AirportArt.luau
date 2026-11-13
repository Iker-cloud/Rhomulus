-- Pase de arte de Last Call (arquitectura y ambiente): lo que hace que el aeropuerto deje de verse cuadrado. Lo llama
-- server/MapBuilderAirport con sus ayudantes en `kit` (cuadrícula, paleta, tubo, cartel colgante...). No toca la lógica: casi todo
-- es decoración sin colisión, y lo que choca (vidrios de la fachada, marquesina, sacos, vehículos) se comprobó con PathfindingService.
--   structure: revestimiento de muros (yeso con zócalo en el terminal, pintura verde con franja amarilla en servicio), salones del
--              CONCOURSE a HALL_H con cerchas y tragaluces, franja alta alrededor de cada salón y fachada este de vidrio con montantes.
--   terrain:   pasto y tierra con Terrain fuera del asfalto (GameState.loadMap borra el terreno antes de cada mapa).
--   lobby, arrivals: el lobby (Lost & Found) y el sector 1 (Arrivals). Las demás zonas siguen en server/AirportDetail.
-- Lo que se mueve lo anima el cliente (client/MapMotion) por etiquetas: Spin, Shuttle, Drift, SparkCable y FlightBoard.
-- Rótulos solo en inglés (son del terminal: no se traducen).
local CollectionService = game:GetService("CollectionService")

local AirportLayout = require(script.Parent.AirportLayout)
local MapKit = require(script.Parent.MapKit)

local AirportArt = {}

local L = AirportLayout
local C = MapKit.C
local FLOOR_TOP = MapKit.FLOOR_TOP
local RHO_BLACK = MapKit.RHO_BLACK
local block = MapKit.block
local deco = MapKit.deco
local pole = MapKit.pole
local boardText = MapKit.boardText
local boardRect = MapKit.boardRect
local blankBoard = MapKit.blankBoard

local GLASS = Color3.fromRGB(28, 40, 56)
local NEON_WARM = Color3.fromRGB(255, 196, 120)
local NEON_RED = Color3.fromRGB(255, 60, 50)
local NEON_CYAN = Color3.fromRGB(110, 220, 255)
local OLIVE = Color3.fromRGB(78, 86, 58)
local PAPER = Color3.fromRGB(226, 220, 204)
local TAPE = Color3.fromRGB(240, 196, 40)

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function tag(part, name, attributes)
	for key, value in attributes or {} do
		part:SetAttribute(key, value)
	end
	CollectionService:AddTag(part, name)
	return part
end

local function glass(part, transparency)
	part.Material = Enum.Material.Glass
	part.Transparency = transparency or 0.5
	part.Reflectance = 0.15
	part.CastShadow = false
	return part
end

-- Pieza inclinada: `cf` es el centro
local function decoAt(parent, name, size, cf, color, material)
	return deco(block(parent, name, size, cf, color, material))
end

---------------------------------------------------------------------------------------------------
-- Estructura

-- Recorre las caras entre celdas: llama a fn(r, c, r2, c2, dir) para cada par de vecinas (dir = "x" si cambia la columna)
local function eachEdge(fn)
	for row = -1, #L.ROWS do
		for col = -1, #L.ROWS[1] do
			fn(row, col, row, col + 1, "x")
			fn(row, col, row + 1, col, "z")
		end
	end
end

-- Junta tramos de cara consecutivos con la misma clave en una sola pieza. `edges[key] = { line, from, to, ...extra }` se
-- arma con addEdge; devuelve la lista de tramos { key, dir, line, a, b, side, data }.
local function mergeEdges(list)
	table.sort(list, function(p, q)
		if p.key ~= q.key then
			return p.key < q.key
		end
		return p.a < q.a
	end)
	local out = {}
	for _, e in list do
		local last = out[#out]
		if last and last.key == e.key and math.abs(last.b - e.a) < 0.01 then
			last.b = e.b
		else
			table.insert(out, { key = e.key, dir = e.dir, line = e.line, a = e.a, b = e.b, side = e.side, data = e.data })
		end
	end
	return out
end

-- Pieza vertical pegada a una cara: tramo de `a` a `b` sobre la línea `line` (x si dir == "x", z si dir == "z"), separada
-- `offset` hacia `side` (+1/-1), de `thick` de grosor y de y1 a y2
local function facePart(parent, name, e, offset, thick, y1, y2, color, material)
	local len = e.b - e.a
	local mid = (e.a + e.b) / 2
	local size, pos
	if e.dir == "x" then -- la cara es perpendicular a X: corre en Z
		size = Vector3.new(thick, y2 - y1, len)
		pos = Vector3.new(e.line + e.side * offset, (y1 + y2) / 2, mid)
	else
		size = Vector3.new(len, y2 - y1, thick)
		pos = Vector3.new(mid, (y1 + y2) / 2, e.line + e.side * offset)
	end
	return block(parent, name, size, pos, color, material)
end

function AirportArt.structure(map, kit)
	local P, cell, band, isHall, isFacade = kit.P, kit.cell, kit.band, kit.isHall, kit.isFacade
	local WALL_H, HALL_H = kit.WALL_H, kit.HALL_H
	local root = folder(map, "Arquitectura")
	local interior = function(ch)
		return ch == "." or ch == "s"
	end

	-- 1. Revestimiento: cada cara de muro que da a un interior, según la banda del interior
	local faces, rings = {}, {}
	eachEdge(function(r, c, r2, c2, dir)
		local a, b = cell(r, c), cell(r2, c2)
		-- side: hacia dónde queda el interior (+1 = hacia la celda 2)
		local function add(list, key, side, data)
			local line = dir == "x" and L.x(c2) or L.z(r2)
			local from = dir == "x" and L.z(r) or L.x(c)
			table.insert(list, { key = key, dir = dir, line = line, a = from, b = from + L.CELL, side = side, data = data })
		end
		local wallA, wallB = (a == "#" or a == "J"), (b == "#" or b == "J")
		if interior(a) and wallB and not isFacade(r2, c2) then
			local kind = b == "J" and "J" or band(c)
			add(faces, `{dir}|{L.x(c2)}|{L.z(r2)}|{kind}|-1`, -1, kind)
		elseif interior(b) and wallA and not isFacade(r, c) then
			local kind = a == "J" and "J" or band(c2)
			add(faces, `{dir}|{L.x(c2)}|{L.z(r2)}|{kind}|1`, 1, kind)
		end
		-- Franja alta de los salones: entre una celda de salón y otra que no lo es; va hacia fuera del salón
		local hallA, hallB = isHall(r, c), isHall(r2, c2)
		if hallA ~= hallB then
			local outRow, outCol = hallA and r2 or r, hallA and c2 or c
			local kind = isFacade(outRow, outCol) and "glass" or "wall"
			add(rings, `{dir}|{L.x(c2)}|{L.z(r2)}|{kind}|{hallA and 1 or -1}`, hallA and 1 or -1, kind)
		end
	end)
	-- La clave de cada cara incluye la línea y el lado; para unir tramos consecutivos se reemplaza por (dir, línea, tipo, lado)
	local function regroup(list)
		for _, e in list do
			e.key = `{e.dir}|{e.line}|{e.data}|{e.side}`
		end
		return mergeEdges(list)
	end
	local cladding = folder(root, "Revestimiento")
	for _, e in regroup(faces) do
		if e.data == "Service" then
			-- Pintura verde hasta 7 y franja amarilla; arriba queda el concreto
			deco(facePart(cladding, "PinturaServicio", e, 0.15, 0.3, 0, 7, P.servicePaint, Enum.Material.Concrete))
			deco(facePart(cladding, "FranjaServicio", e, 0.2, 0.35, 7, 7.5, P.signYellow, Enum.Material.SmoothPlastic))
		elseif e.data == "J" then
			deco(facePart(cladding, "Zocalo", e, 0.25, 0.5, 0, 1.3, P.trim, Enum.Material.Granite))
		else
			deco(facePart(cladding, "Yeso", e, 0.15, 0.3, 0, WALL_H, P.plaster, Enum.Material.Plaster))
			deco(facePart(cladding, "Zocalo", e, 0.3, 0.6, 0, 1.3, P.trim, Enum.Material.Granite))
			deco(facePart(cladding, "Moldura", e, 0.3, 0.6, 12.6, 13.1, P.trim, Enum.Material.Granite))
		end
	end

	-- 2. Salones altos: franja de muro de WALL_H a HALL_H alrededor, o vidrio con montantes sobre la fachada este
	local halls = folder(root, "Salones")
	for _, e in regroup(rings) do
		-- side apunta hacia el salón: la franja va hacia el otro lado (fuera), de 1 de grosor
		local out = { dir = e.dir, line = e.line, a = e.a, b = e.b, side = -e.side }
		if e.data == "glass" then
			glass(facePart(halls, "Claraboya", out, 0.5, 0.6, WALL_H, HALL_H + 1, GLASS, Enum.Material.Glass), 0.45)
			for along = e.a, e.b, 5 do
				local m = { dir = e.dir, line = e.line, a = along - 0.3, b = along + 0.3, side = out.side }
				deco(facePart(halls, "Montante", m, 0.5, 0.9, WALL_H, HALL_H + 1, P.trim, Enum.Material.Metal))
			end
			deco(facePart(halls, "Travesano", out, 0.5, 0.9, WALL_H + 5.5, WALL_H + 6, P.trim, Enum.Material.Metal))
		else
			facePart(halls, "MuroAlto", out, 0.5, 1, WALL_H, HALL_H + 1, P.wall, Enum.Material.Concrete)
			deco(facePart(halls, "YesoAlto", out, -0.15, 0.3, WALL_H, HALL_H, P.plaster, Enum.Material.Plaster))
		end
	end
	-- Techo alto por tramos de 20: techo oscuro y un tragaluz de 6 al final de cada tramo; una cercha en cada junta
	for _, r in kit.rects(function(ch, row, col)
		return interior(ch) and isHall(row, col) and "hall" or nil
	end) do
		local width = r.x2 - r.x1
		local cx = (r.x1 + r.x2) / 2
		local z = r.z1
		while z < r.z2 - 0.01 do
			local nextZ = math.min(r.z2, (math.floor(z / 20) + 1) * 20)
			local len = nextZ - z
			if len >= 14 then
				block(halls, "TechoAlto", Vector3.new(width, 1, len - 6), Vector3.new(cx, HALL_H + 0.5, z + (len - 6) / 2), P.roof, Enum.Material.Metal)
				glass(block(halls, "Tragaluz", Vector3.new(width, 1, 6), Vector3.new(cx, HALL_H + 0.5, nextZ - 3), GLASS, Enum.Material.Glass), 0.35)
			else
				block(halls, "TechoAlto", Vector3.new(width, 1, len), Vector3.new(cx, HALL_H + 0.5, z + len / 2), P.roof, Enum.Material.Metal)
			end
			-- Cercha en arco rebajado sobre la junta (solo si el salón es ancho)
			if nextZ < r.z2 - 0.01 and width >= 30 then
				local low, high = HALL_H - 6, HALL_H - 0.4
				decoAt(halls, "CerchaCordon", Vector3.new(width, 0.6, 0.6), CFrame.new(cx, low, nextZ), P.truss, Enum.Material.Metal)
				local half = width / 2
				local rise = high - low
				local slantLen = math.sqrt(half * half + rise * rise)
				local angle = math.atan2(rise, half)
				for _, s in { -1, 1 } do
					local mid = Vector3.new(cx + s * half / 2, low + rise / 2, nextZ)
					decoAt(halls, "CerchaArco", Vector3.new(slantLen, 0.7, 0.7), CFrame.new(mid) * CFrame.Angles(0, 0, s * -angle), P.truss, Enum.Material.Metal)
					decoAt(halls, "CerchaMontante", Vector3.new(0.4, rise / 2, 0.4), CFrame.new(cx + s * half / 2, low + rise / 4, nextZ), P.truss, Enum.Material.Metal)
				end
				decoAt(halls, "CerchaMontante", Vector3.new(0.4, rise, 0.4), CFrame.new(cx, low + rise / 2, nextZ), P.truss, Enum.Material.Metal)
			end
			z = nextZ
		end
	end

	-- 3. Fachada este de vidrio: dos hojas de vidrio con montantes, antepecho y dintel (choca como el muro que reemplaza)
	local facade = folder(root, "Fachada")
	local runs = {}
	for row = 0, #L.ROWS - 1 do
		for col = 0, #L.ROWS[1] - 1 do
			if isFacade(row, col) then
				local last = runs[#runs]
				if last and last.col == col and last.row2 == row - 1 then
					last.row2 = row
				else
					table.insert(runs, { col = col, row1 = row, row2 = row })
				end
			end
		end
	end
	for _, run in runs do
		local x1, x2, z1, z2 = L.x(run.col), L.x(run.col + 1), L.z(run.row1), L.z(run.row2 + 1)
		local cx, cz, len = (x1 + x2) / 2, (z1 + z2) / 2, z2 - z1
		block(facade, "Antepecho", Vector3.new(x2 - x1, 3, len), Vector3.new(cx, 1.5, cz), P.wall, Enum.Material.Concrete)
		block(facade, "DintelFachada", Vector3.new(x2 - x1, 4, len), Vector3.new(cx, WALL_H - 2, cz), P.wall, Enum.Material.Concrete)
		for _, x in { x1 + 0.3, x2 - 0.3 } do
			glass(block(facade, "Ventanal", Vector3.new(0.4, WALL_H - 7, len), Vector3.new(x, 3 + (WALL_H - 7) / 2, cz), GLASS, Enum.Material.Glass), 0.55)
			deco(block(facade, "VentanalTravesano", Vector3.new(0.7, 0.5, len), Vector3.new(x, 9.5, cz), P.trim, Enum.Material.Metal))
		end
		for z = z1, z2, 5 do
			deco(block(facade, "VentanalMontante", Vector3.new(0.7, WALL_H - 7, 0.5), Vector3.new(x1 + 0.3, 3 + (WALL_H - 7) / 2, z), P.trim, Enum.Material.Metal))
			if (z - z1) % 10 == 0 then
				deco(block(facade, "VentanalMontante", Vector3.new(0.7, WALL_H - 7, 0.5), Vector3.new(x2 - 0.3, 3 + (WALL_H - 7) / 2, z), P.trim, Enum.Material.Metal))
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Terreno: pasto y tierra alrededor del aeropuerto (bajo el nivel del asfalto, para no asomar dentro)

function AirportArt.terrain(kit)
	local terrain = workspace.Terrain
	local top = -0.6
	local depth = 10
	local function fill(x1, x2, z1, z2, material)
		terrain:FillBlock(CFrame.new((x1 + x2) / 2, top - depth / 2, (z1 + z2) / 2), Vector3.new(x2 - x1, depth, z2 - z1), material)
	end
	local W, E, S, N = -145, 145, -455, kit.PLAY_NORTH
	fill(-650, 650, 462, 900, Enum.Material.Grass) -- al norte de la pista
	fill(-650, 650, -820, S, Enum.Material.Grass) -- al sur del lobby
	fill(E, 650, S, 462, Enum.Material.Grass)
	fill(-650, W, S, 462, Enum.Material.Grass)
	fill(-650, -700 + 50, 410, 462, Enum.Material.Grass)
	-- Manchas de tierra y lomas suaves (sin tapar la pista ni el asfalto)
	local rng = Random.new(77)
	for _ = 1, 26 do
		local x, z
		repeat
			x, z = rng:NextNumber(-600, 600), rng:NextNumber(-780, 860)
		until not (x > W - 20 and x < E + 20 and z > S - 20 and z < 480)
		terrain:FillBall(Vector3.new(x, top - rng:NextNumber(3, 6), z), rng:NextNumber(14, 34), rng:NextNumber() < 0.4 and Enum.Material.Ground or Enum.Material.LeafyGrass)
	end
	for _ = 1, 14 do
		local x, z = rng:NextNumber(-600, 600), rng:NextNumber(520, 860)
		terrain:FillBall(Vector3.new(x, top - 4, z), rng:NextNumber(20, 40), Enum.Material.Grass)
	end
end

---------------------------------------------------------------------------------------------------
-- Piezas comunes del pase de arte

-- Letrero de neón (texto que brilla sin luz del mundo) con marco de neón que parpadea como un farol (etiqueta NightLamp)
function AirportArt.neonSign(parent, size, cf, text, color, range)
	local board, gui = blankBoard(parent, "LetreroNeon", size, cf, Color3.fromRGB(14, 14, 16), 40)
	gui.LightInfluence = 0
	gui.Brightness = 2.2
	boardText(gui, text, 0.03, 0.12, 0.94, 0.76, color, Enum.TextXAlignment.Center)
	local frame = deco(block(parent, "LetreroNeonMarco", Vector3.new(size.X + 0.3, 0.25, 0.25), cf * CFrame.new(0, -size.Y / 2 - 0.2, -0.1), color, Enum.Material.Neon))
	local light = Instance.new("PointLight")
	light.Name = "Luz"
	light.Color = color
	light.Range = range or 18
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = frame
	CollectionService:AddTag(frame, "NightLamp")
	return board, gui
end

-- Cinta de cuarentena entre postes: de `a` a `b` (a nivel del suelo); amarilla y negra, sin colisión
function AirportArt.tape(parent, a, b)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local mid = (a + b) / 2 + Vector3.new(0, 3, 0)
	for _, p in { a, b } do
		deco(pole(parent, "PosteCinta", p, 3.4, 0.35, TAPE, Enum.Material.SmoothPlastic))
	end
	local _, gui = blankBoard(parent, "Cinta", Vector3.new(0.05, 0.5, flat.Magnitude), CFrame.lookAt(mid, mid + flat) * CFrame.Angles(0, math.pi / 2, 0), TAPE, 30)
	for i = 0, 9 do
		boardRect(gui, i * 0.1 + 0.02, 0, 0.05, 1, RHO_BLACK, 0)
	end
end

-- Toldo de triaje abierto: techo a dos aguas sobre 4 postes, piso de lona, catres, porta-sueros y cruz roja
function AirportArt.triage(parent, x, z, alongZ, rng)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, alongZ and 0 or math.pi / 2, 0)
	local w, d, h = 9, 12, 6.5
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			block(parent, "ToldoPoste", Vector3.new(0.4, h, 0.4), base * CFrame.new(sx * (w / 2 - 0.2), h / 2, sz * (d / 2 - 0.2)), C.blanco, Enum.Material.Metal).CanQuery = false
		end
	end
	for _, s in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "ToldoTecho"
		wedge.Anchored = true
		wedge.Size = Vector3.new(d, 2, w / 2)
		wedge.CFrame = base * CFrame.new(s * w / 4, h + 1, 0) * CFrame.Angles(0, s * math.pi / 2, 0)
		wedge.Color = Color3.fromRGB(228, 230, 226)
		wedge.Material = Enum.Material.Fabric
		wedge.Parent = parent
		deco(wedge)
	end
	decoAt(parent, "ToldoCruz", Vector3.new(0.1, 1.6, 1.6), base * CFrame.new(0, h + 1.2, d / 2 + 0.05) * CFrame.Angles(0, math.pi / 2, 0), NEON_RED, Enum.Material.SmoothPlastic)
	decoAt(parent, "ToldoLona", Vector3.new(w, 0.06, d), base * CFrame.new(0, FLOOR_TOP + 0.03, 0), Color3.fromRGB(70, 84, 72), Enum.Material.Fabric)
	for _, s in { -1, 1 } do
		local cot = base * CFrame.new(s * 2.4, 0, rng:NextNumber(-1.5, 1.5))
		block(parent, "Catre", Vector3.new(2.4, 1.6, 6.5), cot * CFrame.new(0, 0.8, 0), Color3.fromRGB(60, 74, 58), Enum.Material.Fabric)
		decoAt(parent, "CatreManta", Vector3.new(2.2, 0.3, 3.2), cot * CFrame.new(0, 1.75, 1.2) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), Color3.fromRGB(150, 156, 170), Enum.Material.Fabric)
		decoAt(parent, "PortaSuero", Vector3.new(0.15, 5.5, 0.15), cot * CFrame.new(s * 1.6, 2.75, -2.6), C.blanco, Enum.Material.Metal)
		decoAt(parent, "Suero", Vector3.new(0.5, 0.8, 0.3), cot * CFrame.new(s * 1.6, 5.2, -2.6), Color3.fromRGB(190, 230, 255), Enum.Material.Glass)
	end
	decoAt(parent, "CajaMedica", Vector3.new(2, 1.4, 1.4), base * CFrame.new(0, 0.7, -d / 2 + 1), C.blanco, Enum.Material.SmoothPlastic)
	decoAt(parent, "CajaMedicaCruz", Vector3.new(0.6, 0.6, 0.05), base * CFrame.new(0, 0.8, -d / 2 + 0.28), NEON_RED, Enum.Material.SmoothPlastic)
end

-- Auto (sedán o taxi) con cabina de vidrio, ruedas, faros y calaveras. `wreck` = chocado: ladeado, sin un vidrio y con el capó
-- levantado. Choca como un bloque bajo (cobertura).
function AirportArt.sedan(parent, x, z, angle, color, opts)
	opts = opts or {}
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(angle), 0)
	if opts.wreck then
		base *= CFrame.Angles(0, 0, math.rad(opts.roll or 4))
	end
	block(parent, "Auto", Vector3.new(5, 1.8, 11), base * CFrame.new(0, 1.6, 0), color, Enum.Material.Metal)
	decoAt(parent, "AutoParachoques", Vector3.new(5.1, 0.6, 11.3), base * CFrame.new(0, 0.95, 0), Color3.fromRGB(30, 30, 32), Enum.Material.SmoothPlastic)
	local cabin = decoAt(parent, "AutoCabina", Vector3.new(4.4, 1.6, 5.4), base * CFrame.new(0, 3.3, 0.6), Color3.fromRGB(20, 26, 32), Enum.Material.Glass)
	cabin.Transparency = opts.wreck and 0.2 or 0.1
	decoAt(parent, "AutoTecho", Vector3.new(4.6, 0.25, 4.4), base * CFrame.new(0, 4.2, 0.6), color, Enum.Material.Metal)
	for _, sx in { -1, 1 } do
		for _, sz in { -3.6, 3.4 } do
			local wheel = decoAt(parent, "AutoRueda", Vector3.new(0.9, 2.2, 2.2), base * CFrame.new(sx * 2.35, 1.1, sz), Color3.fromRGB(22, 22, 24), Enum.Material.Rubber)
			wheel.Shape = Enum.PartType.Cylinder
		end
		decoAt(parent, "AutoFaro", Vector3.new(0.9, 0.5, 0.2), base * CFrame.new(sx * 1.7, 1.9, -5.55), opts.wreck and Color3.fromRGB(80, 80, 80) or Color3.fromRGB(255, 244, 210), opts.wreck and Enum.Material.Glass or Enum.Material.Neon)
		decoAt(parent, "AutoCalavera", Vector3.new(0.9, 0.5, 0.2), base * CFrame.new(sx * 1.7, 1.9, 5.55), Color3.fromRGB(150, 20, 20), Enum.Material.SmoothPlastic)
	end
	if opts.taxi then
		decoAt(parent, "TaxiLetrero", Vector3.new(1.8, 0.6, 0.6), base * CFrame.new(0, 4.6, 0.6), Color3.fromRGB(255, 230, 120), Enum.Material.Neon)
		decoAt(parent, "TaxiFranja", Vector3.new(5.06, 0.4, 7), base * CFrame.new(0, 2.1, 0), RHO_BLACK, Enum.Material.SmoothPlastic)
	end
	if opts.wreck then
		decoAt(parent, "AutoCapo", Vector3.new(4.8, 0.2, 3.2), base * CFrame.new(0, 3.1, -4.1) * CFrame.Angles(math.rad(-38), 0, 0), color, Enum.Material.Metal)
	end
	if opts.burning then
		local fire = Instance.new("Fire")
		fire.Size = 7
		fire.Heat = 12
		local smoke = Instance.new("Smoke")
		smoke.Color = Color3.fromRGB(40, 40, 40)
		smoke.Opacity = 0.35
		smoke.RiseVelocity = 6
		smoke.Size = 6
		local core = decoAt(parent, "AutoFuego", Vector3.new(2, 1, 2), base * CFrame.new(0, 2.6, -3.6), Color3.fromRGB(30, 30, 30), Enum.Material.CorrodedMetal)
		core.Transparency = 1
		fire.Parent = core
		smoke.Parent = core
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 140, 60)
		light.Range = 26
		light.Brightness = 2.2
		light.Parent = core
	end
end

-- Hoja de papel que vuela con el viento (client/MapMotion la mueve: etiqueta Drift)
function AirportArt.paper(parent, origin, direction, length, rng)
	local sheet = decoAt(parent, "Papel", Vector3.new(1, 0.04, 1.3), origin + Vector3.new(0, 0.3, 0), PAPER, Enum.Material.SmoothPlastic)
	return tag(sheet, "Drift", { Dir = direction.Unit, Length = length, Speed = rng:NextNumber(6, 11), Phase = rng:NextNumber() })
end

-- Cable suelto colgando del techo que echa chispas (client/MapMotion: etiqueta SparkCable)
function AirportArt.sparkCable(parent, top, length)
	decoAt(parent, "CableSuelto", Vector3.new(0.18, length, 0.18), CFrame.new(top - Vector3.new(0, length / 2, 0)) * CFrame.Angles(0, 0, math.rad(9)), RHO_BLACK, Enum.Material.Rubber)
	local tip = decoAt(parent, "CableChispas", Vector3.new(0.3, 0.3, 0.3), top - Vector3.new(-length * 0.16, length, 0), Color3.fromRGB(255, 220, 140), Enum.Material.Neon)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), Color3.fromRGB(255, 150, 40))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.18, 0)
	emitter.Speed = NumberRange.new(8, 18)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Lifetime = NumberRange.new(0.3, 0.8)
	emitter.Acceleration = Vector3.new(0, -60, 0)
	emitter.Parent = tip
	return tag(tip, "SparkCable")
end

-- Gotera: gotas que caen del techo a un charco (partículas: no necesita al cliente)
function AirportArt.leak(parent, position, height)
	local source = decoAt(parent, "Gotera", Vector3.new(1, 0.2, 1), position + Vector3.new(0, height, 0), RHO_BLACK, Enum.Material.SmoothPlastic)
	source.Transparency = 1
	local drops = Instance.new("ParticleEmitter")
	drops.Texture = "rbxasset://textures/particles/smoke_main.dds"
	drops.EmissionDirection = Enum.NormalId.Bottom
	drops.Orientation = Enum.ParticleOrientation.VelocityParallel
	drops.Rate = 7
	drops.Speed = NumberRange.new(2, 4)
	drops.Acceleration = Vector3.new(0, -70, 0)
	drops.Lifetime = NumberRange.new(height / 26, height / 22)
	drops.Size = NumberSequence.new(0.2)
	drops.Squash = NumberSequence.new(-2.5)
	drops.Color = ColorSequence.new(Color3.fromRGB(190, 210, 235))
	drops.Transparency = NumberSequence.new(0.3)
	drops.LightEmission = 0.4
	drops.Parent = source
	local disc = decoAt(parent, "Charco", Vector3.new(0.04, 5, 5), CFrame.new(position.X, FLOOR_TOP + 0.03, position.Z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(18, 22, 28), Enum.Material.SmoothPlastic)
	disc.Shape = Enum.PartType.Cylinder
	disc.Reflectance = 0.35
end

-- Vapor que sale de una rejilla del suelo (partículas)
function AirportArt.steam(parent, position)
	decoAt(parent, "Rejilla", Vector3.new(3, 0.08, 3), position + Vector3.new(0, FLOOR_TOP + 0.04, 0), Color3.fromRGB(40, 42, 44), Enum.Material.DiamondPlate)
	local source = decoAt(parent, "VaporFuente", Vector3.new(2, 0.2, 2), position + Vector3.new(0, 0.3, 0), RHO_BLACK, Enum.Material.SmoothPlastic)
	source.Transparency = 1
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 9
	smoke.Speed = NumberRange.new(3, 6)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.Lifetime = NumberRange.new(2.2, 3.4)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 6) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(210, 220, 225))
	smoke.RotSpeed = NumberRange.new(-20, 20)
	smoke.Parent = source
end

-- Reja de seguridad bajada a medias sobre un hueco: de y = top hasta y = bottom, de `width` de ancho
function AirportArt.shutter(parent, cf, width, top, bottom)
	decoAt(parent, "RejaCaja", Vector3.new(width + 0.6, 1.2, 1.4), cf * CFrame.new(0, top + 0.6, 0), Color3.fromRGB(70, 74, 78), Enum.Material.Metal)
	for y = bottom, top - 0.5, 0.9 do
		decoAt(parent, "RejaLama", Vector3.new(width, 0.7, 0.3), cf * CFrame.new(0, y + 0.35, 0), Color3.fromRGB(116, 118, 112), Enum.Material.CorrodedMetal)
	end
end

-- Póster de desaparecido (pista de la historia) o cartel de papel
local function poster(gui, x, y, w, h, title, name)
	boardRect(gui, x, y, w, h, PAPER, (x * 37 + y * 11) % 7 - 3)
	boardText(gui, title, x + w * 0.08, y + h * 0.05, w * 0.84, h * 0.16, C.rojo, Enum.TextXAlignment.Center)
	boardRect(gui, x + w * 0.2, y + h * 0.25, w * 0.6, h * 0.45, Color3.fromRGB(150, 146, 136))
	boardText(gui, name, x + w * 0.08, y + h * 0.76, w * 0.84, h * 0.14, RHO_BLACK, Enum.TextXAlignment.Center)
end

---------------------------------------------------------------------------------------------------
-- Lobby: Lost & Found (x -40..40, z -440..-400). Los maniquíes están en z -434 (x -8..8): el mostrador va a la izquierda.

function AirportArt.lobby(map, refs, rng, kit)
	local P = kit.P
	local f = folder(map, "ArteLobby")
	-- Mostrador de objetos perdidos con su ventanilla de vidrio y el letrero de neón
	block(f, "MostradorObjetos", Vector3.new(12, 3.6, 3), Vector3.new(-22, 1.8, -437.5), C.madera, Enum.Material.Wood)
	decoAt(f, "MostradorTapa", Vector3.new(12.4, 0.3, 3.4), Vector3.new(-22, 3.75, -437.5), P.trim, Enum.Material.Granite)
	glass(decoAt(f, "MostradorVidrio", Vector3.new(12, 5, 0.2), Vector3.new(-22, 6.4, -436.2), GLASS, Enum.Material.Glass), 0.6)
	decoAt(f, "Timbre", Vector3.new(0.5, 0.3, 0.5), Vector3.new(-19, 4.05, -436.4), Color3.fromRGB(200, 180, 90), Enum.Material.Metal)
	AirportArt.neonSign(f, Vector3.new(12, 2.4, 0.3), CFrame.lookAt(Vector3.new(-22, 11.5, -439.6), Vector3.new(-22, 11.5, -430)), "LOST & FOUND", NEON_WARM, 20)
	-- Postes de fila con cinta (sin colisión)
	for i, x in { -28, -16 } do
		local a, b = Vector3.new(x, 0, -431), Vector3.new(x, 0, -426)
		deco(pole(f, "PosteFila", a, 3, 0.4, P.steel, Enum.Material.Metal))
		deco(pole(f, "PosteFila", b, 3, 0.4, P.steel, Enum.Material.Metal))
		decoAt(f, "CintaFila", Vector3.new(0.1, 0.4, 5), Vector3.new(x, 2.7, -428.5), i == 1 and C.rojo or C.azul, Enum.Material.Fabric)
	end
	-- Muro de desaparecidos (oeste): la historia en fotos
	local _, wall = blankBoard(f, "MuroDesaparecidos", Vector3.new(14, 7, 0.2), CFrame.lookAt(Vector3.new(-39.7, 8, -414), Vector3.new(-30, 8, -414)), Color3.fromRGB(58, 48, 38), 36)
	boardText(wall, "HAVE YOU SEEN THEM?", 0.05, 0.02, 0.9, 0.13, PAPER, Enum.TextXAlignment.Center)
	local names = { "ANA R.", "TOMAS", "LUCIA", "CAPT. REYES", "MATEO", "SOFIA", "PILOT 2", "D. VEGA", "NICO", "MARTA" }
	for i, name in names do
		local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
		poster(wall, 0.04 + col * 0.19, 0.2 + row * 0.4, 0.15, 0.36, "MISSING", name)
	end
	-- Catre de alguien que durmió aquí, reloj parado y una alfombra en la puerta
	block(f, "Catre", Vector3.new(3, 1.4, 7), Vector3.new(-35, 0.7, -423), Color3.fromRGB(70, 82, 64), Enum.Material.Fabric)
	decoAt(f, "Manta", Vector3.new(2.8, 0.3, 4), CFrame.new(-35, 1.55, -421.5) * CFrame.Angles(0, 0.15, 0), Color3.fromRGB(120, 60, 50), Enum.Material.Fabric)
	decoAt(f, "Mochila", Vector3.new(1.6, 2, 1), Vector3.new(-35, 1, -428), C.cobalto, Enum.Material.Fabric)
	local clock = decoAt(f, "Reloj", Vector3.new(0.3, 3, 3), Vector3.new(39.75, 13, -420), C.blanco, Enum.Material.SmoothPlastic)
	clock.Shape = Enum.PartType.Cylinder
	decoAt(f, "RelojAguja", Vector3.new(0.1, 1.1, 0.15), CFrame.new(39.55, 13, -420) * CFrame.Angles(math.rad(40), 0, 0) * CFrame.new(0, 0.45, 0), RHO_BLACK, Enum.Material.SmoothPlastic)
	decoAt(f, "RelojAguja", Vector3.new(0.1, 0.8, 0.15), CFrame.new(39.55, 13, -420) * CFrame.Angles(math.rad(-110), 0, 0) * CFrame.new(0, 0.32, 0), RHO_BLACK, Enum.Material.SmoothPlastic)
	decoAt(f, "AlfombraPuerta", Vector3.new(16, 0.08, 6), Vector3.new(0, FLOOR_TOP + 0.04, -404), Color3.fromRGB(40, 36, 34), Enum.Material.Carpet)
	-- Reja de seguridad bajada a medias sobre las puertas laterales (por encima de la cabeza)
	AirportArt.shutter(f, CFrame.new(-40, 0, -425) * CFrame.Angles(0, math.pi / 2, 0), 10, 14, 11.5)
	AirportArt.shutter(f, CFrame.new(40, 0, -425) * CFrame.Angles(0, math.pi / 2, 0), 10, 14, 11.2)
	-- Papeles en el suelo y una gotera
	for _ = 1, 8 do
		decoAt(f, "PapelSuelto", Vector3.new(1, 0.04, 1.3), CFrame.new(rng:NextNumber(-36, 36), FLOOR_TOP + 0.04, rng:NextNumber(-418, -402)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), PAPER, Enum.Material.SmoothPlastic)
	end
	AirportArt.leak(f, Vector3.new(26, 0, -416), kit.WALL_H - 0.3)
end

---------------------------------------------------------------------------------------------------
-- Sector 1: Arrivals (z -400..-190)

function AirportArt.arrivals(map, refs, rng, kit)
	local P = kit.P
	local f = folder(map, "ArteSector1")

	-- CONCOURSE (salón de llegadas, techo alto)
	-- Letrero grande de neón en la franja alta del muro sur del salón
	AirportArt.neonSign(f, Vector3.new(30, 4.5, 0.3), CFrame.lookAt(Vector3.new(0, 25.5, -389.4), Vector3.new(0, 25.5, -380)), "WELCOME TO RHOMULUS", NEON_CYAN, 34)
	AirportArt.neonSign(f, Vector3.new(16, 3, 0.3), CFrame.lookAt(Vector3.new(-30, 15.5, -309.6), Vector3.new(-30, 15.5, -300)), "ARRIVALS", NEON_WARM, 26)
	-- Postes con el número de cada cinta
	for i, spot in { { -24, -376 }, { 24, -376 }, { 14, -334 } } do
		deco(pole(f, "PosteCinta", Vector3.new(spot[1], 0, spot[2]), 8, 0.5, P.trim, Enum.Material.Metal))
		local _, gui = blankBoard(f, "NumeroCinta", Vector3.new(3, 2, 0.3), CFrame.lookAt(Vector3.new(spot[1], 9, spot[2]), Vector3.new(spot[1], 9, spot[2] + 10)), RHO_BLACK, 50)
		boardText(gui, "BELT " .. i, 0.06, 0.15, 0.88, 0.7, P.signYellow, Enum.TextXAlignment.Center)
	end
	-- Una maleta que sigue dando vueltas sola sobre la cinta este
	local bag = decoAt(f, "MaletaSola", Vector3.new(2.2, 1.4, 1.5), Vector3.new(24, 3.5, -370), C.mostaza, Enum.Material.SmoothPlastic)
	tag(bag, "Shuttle", { A = Vector3.new(24, 3.5, -370), B = Vector3.new(24, 3.5, -342), Speed = 3 })
	-- Triaje: dos toldos con catres en el lado este del salón (el oeste es la entrada del Newsstand), con cinta de cuarentena
	AirportArt.triage(f, 23, -288, true, rng)
	AirportArt.triage(f, 23, -256, true, rng)
	for _, seg in { { 17.5, -296, 29, -296 }, { 17.5, -296, 17.5, -282 }, { 17.5, -262, 17.5, -248 } } do
		AirportArt.tape(f, Vector3.new(seg[1], 0, seg[2]), Vector3.new(seg[3], 0, seg[4]))
	end
	-- Bolsas de residuos médicos y bolsas negras alineadas junto al toldo
	for i = 0, 3 do
		decoAt(f, "BolsaNegra", Vector3.new(6, 0.9, 2.2), CFrame.new(23, 0.45, -278 + i * 2.8) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0), RHO_BLACK, Enum.Material.Fabric)
	end
	for i = 0, 2 do
		local bin = decoAt(f, "BolsaBiorriesgo", Vector3.new(1.8, 1.8, 1.8), Vector3.new(26 + i * 2, 0.9, -247), Color3.fromRGB(190, 40, 40), Enum.Material.Plastic)
		bin.Shape = Enum.PartType.Ball
	end
	-- Asientos tirados, carteles caídos y papeles (la huida)
	for _, spot in { { -10, -300, 80 }, { 12, -250, 100 } } do
		local cf = CFrame.new(spot[1], 1.1, spot[2]) * CFrame.Angles(0, math.rad(spot[3]), math.rad(90))
		decoAt(f, "AsientosTirados", Vector3.new(9, 1.6, 2.2), cf, P.seat, Enum.Material.SmoothPlastic)
	end
	for _ = 1, 22 do
		decoAt(f, "PapelSuelto", Vector3.new(1, 0.04, 1.3), CFrame.new(rng:NextNumber(-36, 36), FLOOR_TOP + 0.04, rng:NextNumber(-385, -195)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), PAPER, Enum.Material.SmoothPlastic)
	end
	-- Barricada de maletas y carritos a los lados de los pasos de la aduana (no tapa el paso)
	for i = 0, 5 do
		local x = -38 + (i % 3) * 2.4
		decoAt(f, "MaletaBarricada", Vector3.new(2.3, 1.5, 1.6), CFrame.new(x, 0.75 + math.floor(i / 3) * 1.5, -322.5) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), ({ C.cobalto, C.terracota, C.oscuro, C.mostaza })[i % 4 + 1], Enum.Material.SmoothPlastic)
	end
	kit.cart(f, -30, -324, 90, rng)
	kit.cart(f, 4, -324, 80, rng)
	-- Cable roto con chispas y una gotera bajo un tragaluz
	AirportArt.sparkCable(f, Vector3.new(-12, kit.HALL_H - 6, -340), 7)
	AirportArt.leak(f, Vector3.new(-6, 0, -343), kit.HALL_H - 0.5)
	AirportArt.leak(f, Vector3.new(18, 0, -223), kit.HALL_H - 0.5)
	-- Las pantallas de vuelos de la pared parpadean (client/MapMotion lee la etiqueta FlightBoard; ver AirportDetail)

	-- SERVICE: vapor, extintores, cajas eléctricas y bandejas de cables
	AirportArt.steam(f, Vector3.new(-75, 0, -386))
	AirportArt.steam(f, Vector3.new(-105, 0, -296))
	AirportArt.steam(f, Vector3.new(-85, 0, -226))
	for _, spot in { { -79.6, -380, -1 }, { -100.4, -312, 1 }, { -80.4, -236, 1 } } do
		local x = spot[1]
		decoAt(f, "CajaElectrica", Vector3.new(0.6, 3, 2.2), Vector3.new(x, 5, spot[2]), Color3.fromRGB(90, 96, 92), Enum.Material.Metal)
		decoAt(f, "CajaElectricaLuz", Vector3.new(0.65, 0.3, 0.3), Vector3.new(x, 6.2, spot[2] + 0.6), Color3.fromRGB(80, 255, 120), Enum.Material.Neon)
		local ext = decoAt(f, "Extintor", Vector3.new(1.6, 0.7, 0.7), Vector3.new(x - spot[3] * 0.2, 1.4, spot[2] + 4), C.rojo, Enum.Material.SmoothPlastic)
		ext.Shape = Enum.PartType.Cylinder
		ext.CFrame = CFrame.new(ext.Position) * CFrame.Angles(0, 0, math.pi / 2)
	end
	for _, run in { { -70.6, -410, -360 }, { -100.6, -330, -280 }, { -80.6, -250, -200 } } do
		decoAt(f, "BandejaCables", Vector3.new(1.4, 0.3, run[3] - run[2]), Vector3.new(run[1], 17, (run[2] + run[3]) / 2), Color3.fromRGB(70, 72, 70), Enum.Material.DiamondPlate)
		decoAt(f, "Cables", Vector3.new(1, 0.4, run[3] - run[2]), Vector3.new(run[1], 17.35, (run[2] + run[3]) / 2), RHO_BLACK, Enum.Material.Rubber)
	end
	AirportArt.leak(f, Vector3.new(-110, 0, -350), kit.WALL_H - 0.3)
	AirportArt.sparkCable(f, Vector3.new(-84, kit.WALL_H - 0.5, -224), 5)

	-- APRON: marquesina de la acera, autos chocados, ambulancia, puesto militar y estacionamiento
	local canopyZ1, canopyZ2 = -440, -196
	block(f, "Marquesina", Vector3.new(12, 0.8, canopyZ2 - canopyZ1), Vector3.new(56, 16.4, (canopyZ1 + canopyZ2) / 2), Color3.fromRGB(64, 68, 74), Enum.Material.Metal)
	decoAt(f, "MarquesinaFrente", Vector3.new(0.6, 1.6, canopyZ2 - canopyZ1), Vector3.new(62.2, 16.2, (canopyZ1 + canopyZ2) / 2), P.signYellow, Enum.Material.SmoothPlastic)
	for z = canopyZ1 + 12, canopyZ2 - 6, 30 do
		block(f, "MarquesinaColumna", Vector3.new(0.8, 16, 0.8), Vector3.new(61, 8, z), P.trim, Enum.Material.Metal)
		local lamp = decoAt(f, "MarquesinaLuz", Vector3.new(3, 0.3, 1), Vector3.new(56, 15.85, z + 15), NEON_WARM, Enum.Material.Neon)
		local light = Instance.new("SpotLight")
		light.Name = "Luz"
		light.Face = Enum.NormalId.Bottom
		light.Angle = 120
		light.Color = NEON_WARM
		light.Brightness = 1.6
		light.Range = 24
		light.Shadows = false
		light.Parent = lamp
		CollectionService:AddTag(lamp, "NightLamp")
	end
	local _, arr = blankBoard(f, "MarquesinaRotulo", Vector3.new(24, 1.5, 0.2), CFrame.lookAt(Vector3.new(62.6, 16.2, -330), Vector3.new(80, 16.2, -330)), RHO_BLACK, 40)
	boardText(arr, "ARRIVALS  ·  TAXI  ·  SHUTTLE", 0.03, 0.1, 0.94, 0.8, P.signYellow, Enum.TextXAlignment.Center)
	decoAt(f, "Bordillo", Vector3.new(0.6, 0.35, canopyZ2 - canopyZ1), Vector3.new(58.3, 0.18, (canopyZ1 + canopyZ2) / 2), Color3.fromRGB(200, 180, 60), Enum.Material.Concrete)
	-- Autos (sustituyen a los bloques): taxis en la acera, dos chocados de frente y uno ardiendo
	for _, spot in { { 66, -430, 4 }, { 67, -404, -8 }, { 66, -264, 12 }, { 65, -226, 0 } } do
		AirportArt.sedan(f, spot[1], spot[2], spot[3], P.taxi, { taxi = true })
	end
	AirportArt.sedan(f, 68, -336, 160, P.taxi, { taxi = true, wreck = true, roll = -5 })
	AirportArt.sedan(f, 70, -324, -15, C.blanco, { wreck = true, roll = 6 })
	for _, spot in { { 108, -432, 90, C.cobalto }, { 122, -408, 0, C.concreto }, { 106, -392, 80, C.terracota }, { 120, -322, 0, C.blanco }, { 104, -318, 12, C.turquesa }, { 118, -246, 0, C.oscuro } } do
		AirportArt.sedan(f, spot[1], spot[2], spot[3], spot[4])
	end
	AirportArt.sedan(f, 100, -214, 96, C.lima, { wreck = true, burning = true, roll = 3 })
	-- Ambulancia con balizas
	local amb = CFrame.new(68, 0, -298) * CFrame.Angles(0, math.rad(-6), 0)
	block(f, "Ambulancia", Vector3.new(6, 6.5, 14), amb * CFrame.new(0, 4.2, 1.5), C.blanco, Enum.Material.Metal)
	block(f, "AmbulanciaCabina", Vector3.new(6, 4.4, 4.5), amb * CFrame.new(0, 3.1, -7.7), C.blanco, Enum.Material.Metal)
	decoAt(f, "AmbulanciaVidrio", Vector3.new(5.6, 1.8, 0.2), amb * CFrame.new(0, 4.6, -10), GLASS, Enum.Material.Glass)
	decoAt(f, "AmbulanciaFranja", Vector3.new(6.05, 0.8, 18.6), amb * CFrame.new(0, 3, -0.8), C.rojo, Enum.Material.SmoothPlastic)
	for _, sx in { -1, 1 } do
		for _, sz in { -6.5, 5 } do
			local wheel = decoAt(f, "AmbulanciaRueda", Vector3.new(0.9, 2.4, 2.4), amb * CFrame.new(sx * 2.9, 1.2, sz), Color3.fromRGB(22, 22, 24), Enum.Material.Rubber)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	local Beacon = require(script.Parent.AirportDetail).beacon
	Beacon(f, (amb * CFrame.new(-1.6, 5.6, -7.6)).Position, Color3.fromRGB(255, 50, 40), 0.7, 0, 0.5, 22, Vector3.new(1.2, 0.5, 0.6))
	Beacon(f, (amb * CFrame.new(1.6, 5.6, -7.6)).Position, Color3.fromRGB(60, 120, 255), 0.7, 0.5, 0.5, 22, Vector3.new(1.2, 0.5, 0.6))
	-- Puesto militar abandonado al norte del estacionamiento: sacos, tienda, foco, barrera y cartel
	local mil = folder(f, "PuestoMilitar")
	for _, spot in { { 88, -232, 0 }, { 92, -232, 0 }, { 96, -232, 0 }, { 86, -228, 90 }, { 86, -224, 90 }, { 118, -232, 0 }, { 122, -232, 0 } } do
		MapKit.sandbags(mil, spot[1], spot[2], spot[3])
		decoAt(mil, "SacosArriba", Vector3.new(3.6, 1.4, 3.6), CFrame.new(spot[1], 2.7, spot[2]) * CFrame.Angles(0, math.rad(spot[3] + 8), 0), C.tierra, Enum.Material.Fabric)
	end
	block(mil, "TiendaMilitar", Vector3.new(10, 0.4, 8), Vector3.new(114, 7, -216), OLIVE, Enum.Material.Fabric).CanQuery = false
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			block(mil, "TiendaPoste", Vector3.new(0.4, 7, 0.4), Vector3.new(114 + sx * 4.6, 3.5, -216 + sz * 3.6), OLIVE, Enum.Material.Metal).CanQuery = false
		end
	end
	block(mil, "CajaMunicion", Vector3.new(3, 1.6, 2), Vector3.new(112, 0.8, -217), OLIVE, Enum.Material.Metal)
	block(mil, "CajaMunicion", Vector3.new(3, 1.6, 2), Vector3.new(116, 0.8, -215), OLIVE, Enum.Material.Metal)
	MapKit.floodLight(mil, Vector3.new(124, 9, -236), Vector3.new(100, 0, -260), 50, 1.4)
	deco(pole(mil, "FocoTripode", Vector3.new(124, 0, -236), 9, 0.5, P.trim, Enum.Material.Metal))
	deco(pole(mil, "BarreraPoste", Vector3.new(102, 0, -232), 3, 0.8, C.rojo, Enum.Material.Metal))
	decoAt(mil, "BarreraBrazo", Vector3.new(14, 0.5, 0.5), CFrame.new(102, 3.2, -232) * CFrame.Angles(0, 0, math.rad(-12)) * CFrame.new(-7, 0, 0), C.blanco, Enum.Material.SmoothPlastic)
	local _, sign = blankBoard(mil, "CartelMilitar", Vector3.new(8, 3.4, 0.2), CFrame.lookAt(Vector3.new(96, 4.4, -233.6), Vector3.new(96, 4.4, -260)), OLIVE, 40)
	boardText(sign, "MILITARY CHECKPOINT", 0.05, 0.08, 0.9, 0.36, PAPER, Enum.TextXAlignment.Center)
	boardText(sign, "SHOW YOUR ARMS · NO BITES", 0.05, 0.55, 0.9, 0.3, NEON_RED, Enum.TextXAlignment.Center)
	-- Rayas del estacionamiento
	for z = -436, -250, 9 do
		decoAt(f, "RayaEstacionamiento", Vector3.new(12, 0.06, 0.4), Vector3.new(114, FLOOR_TOP + 0.04, z), C.blanco, Enum.Material.SmoothPlastic)
	end
	local _, park = blankBoard(f, "LetreroP", Vector3.new(3, 3, 0.2), CFrame.lookAt(Vector3.new(128, 9, -380), Vector3.new(110, 9, -380)), C.azul, 40)
	boardText(park, "P", 0.1, 0.05, 0.8, 0.9, C.blanco, Enum.TextXAlignment.Center)
	deco(pole(f, "LetreroPPoste", Vector3.new(128, 0, -380), 7.5, 0.3, P.steel, Enum.Material.Metal))
	-- Papeles que se lleva el viento por la acera y la plataforma
	for i = 1, 8 do
		AirportArt.paper(f, Vector3.new(70 + rng:NextNumber(0, 50), 0, -420 + i * 26), Vector3.new(0.4, 0, 1), 60, rng)
	end
end

return AirportArt
