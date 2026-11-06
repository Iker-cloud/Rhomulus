-- Mapa 1, Morro Esperanza (barrio de Rhomulus), en bloques de colores generados por código.
-- Diseño: docs/mapa-1-barrio.md y docs/prompts-mapa-claude-design.md (Prompt 0 = escala y reglas; partes 2 a 14).
-- Se elige en la votación del lobby (server/VoteRoom, Config.Maps).
--
-- Hecho hasta ahora: lobby (la cochera, z -400..-350) -> tramo 1, rutas Calle (roja, z -350..-130) y Callejón
-- (amarilla, x -120..-60) y Escalera (azul, x 60..120) -> punto seguro 1
-- (la tienda, z -130..-90) -> tramo 2, ruta Calle (plaza con el generador, z -90..160) -> punto seguro 2 (la iglesia,
-- z 160..200) -> tramo 3, ruta Calle (la terminal, z 200..330) -> estadio y extracción (z 330..400). Las rutas Callejón
-- (avenida) y Escalera (andenes) del tramo 3 salen de la explanada tras la iglesia.
-- La Baseplate de Studio solo llega hasta z = -256: todo lo que se pisa lleva su propio piso.
-- Ejes: X lateral, Y altura (suelo en 0), Z avance. Devuelve las mismas referencias que MapBuilder.build.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Atmosphere = require(script.Parent.Atmosphere)
local PropModel = require(script.Parent.PropModel)
local CajaMunicion = require(script.Parent.ZombieData.CajaMunicion)
local Generador = require(script.Parent.ZombieData.Generador)
local Radio = require(script.Parent.ZombieData.Radio)
local CarroAbandonado = require(script.Parent.ZombieData.CarroAbandonado)
local FavelaVerde = require(script.Parent.ZombieData.FavelaVerde)
local FavelaRosa = require(script.Parent.ZombieData.FavelaRosa)
local FavelaAzul = require(script.Parent.ZombieData.FavelaAzul)
local FavelaAmarilla = require(script.Parent.ZombieData.FavelaAmarilla)
local FavelaNaranja = require(script.Parent.ZombieData.FavelaNaranja)

local MapBuilderBarrio = {}

local function hex(value)
	return Color3.fromHex(value)
end

-- Paleta del Prompt 0
local C = {
	terracota = hex("#C4572F"),
	mostaza = hex("#E0A526"),
	turquesa = hex("#2FA8A0"),
	salmon = hex("#E8836A"),
	lima = hex("#9BC53D"),
	cobalto = hex("#2F5DA8"),
	blanco = hex("#E9E4D6"),
	concreto = hex("#8A8A86"),
	oxido = hex("#8C4A2F"),
	asfalto = hex("#3A3A40"),
	acera = hex("#6B6B6F"),
	lonaAzul = hex("#2B6CB0"),
	lonaNaranja = hex("#E86A1C"),
	lonaVerde = hex("#3E8E41"),
	grafiti = hex("#D6336C"),
	tierra = hex("#8B6B43"),
	pastoSeco = hex("#6E7F3A"),
	oscuro = Color3.fromRGB(35, 32, 36),
	madera = Color3.fromRGB(120, 85, 50),
	rojo = hex("#D64545"), -- ruta Calle
	amarillo = hex("#F2C94C"), -- ruta Callejón
	azul = hex("#3B82F6"), -- ruta Escalera
}
local HOUSE_COLORS = { C.terracota, C.mostaza, C.turquesa, C.salmon, C.lima, C.cobalto, C.blanco }
local ROOF_COLORS = { C.oxido, C.concreto }
-- Ayudas visuales apagadas: el jugador explora solo (carteles de marcador, flechas del suelo, franjas de ruta en las paredes)
local SHOW = { signs = false, floorArrows = false, routeStripes = false }
local FLOOR_TOP = 0.05 -- los pisos de color quedan apenas sobre la Baseplate (sin parpadeo)

-- Las cajas de armas, estaciones de munición y vitrinas ahora viven solo en las Tiendas (buildShop); con true vuelven los lugares viejos
local LEGACY_SHOPS = false

local CROSSINGS = { -310, -240, -170 } -- pasajes hacia Callejón (oeste) y Escalera (este); por ahora nichos cerrados

---------------------------------------------------------------------------------------------------
-- Piezas básicas

local function block(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = typeof(cframe) == "Vector3" and CFrame.new(cframe) or cframe
	part.Color = color or C.concreto
	part.Material = material or Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Bloque apoyado en el suelo entre x1..x2 y z1..z2
local function slab(parent, name, x1, x2, z1, z2, height, color, material)
	return block(parent, name, Vector3.new(x2 - x1, height, z2 - z1), Vector3.new((x1 + x2) / 2, height / 2, (z1 + z2) / 2), color, material)
end

-- Decoración: sin colisión, no frena balas ni rutas de los zombies
local function deco(part)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- Piso de color (cara superior en FLOOR_TOP)
local function floor(parent, name, x1, x2, z1, z2, color, material)
	return block(parent, name, Vector3.new(x2 - x1, 1, z2 - z1), Vector3.new((x1 + x2) / 2, FLOOR_TOP - 0.5, (z1 + z2) / 2), color, material)
end

-- Cilindro vertical (Roblox los orienta en X: se gira para ponerlo de pie)
local function pole(parent, name, position, height, diameter, color, material)
	local part = block(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material or Enum.Material.Metal
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function volume(parent, name, x1, x2, z1, z2, height)
	local part = deco(slab(parent, name, x1, x2, z1, z2, height))
	part.Transparency = 1
	return part
end

local function marker(parent, position)
	local part = deco(block(parent, "SpawnPoint", Vector3.one, position + Vector3.new(0, 0.5, 0)))
	part.Transparency = 1
	return part
end

-- Puerta de reja: GameState la abre (transparente y sin colisión) o la cierra
local function door(parent, name, z, width, height)
	local part = block(parent, name, Vector3.new(width, height, 2), Vector3.new(0, height / 2, z), Color3.fromRGB(150, 110, 60), Enum.Material.DiamondPlate)
	return part
end

local function prompt(part, action, holdTime)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.HoldDuration = holdTime
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom -- la interfaz la dibuja PromptUi.luau
	p.Enabled = false
	p.Parent = part
	return p
end

-- Placa de señalética sobre un objeto: el cliente la dibuja (ver Plates.luau) y solo se ve de cerca
local function label(part, text, color, range)
	CollectionService:AddTag(part, "Plate")
	part:SetAttribute("PlateText", text)
	part:SetAttribute("PlateColor", color)
	part:SetAttribute("PlateRange", range or 20)
end

-- Cartel pintado a mano: placa con texto en la cara frontal (-Z local). `cframe` es el centro del cartel.
local function signBoard(parent, name, text, size, cframe, background, textColor)
	local board = deco(block(parent, name, size, cframe, background, Enum.Material.SmoothPlastic))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0.3
	gui.Parent = board
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(0.92, 0.84)
	textLabel.Position = UDim2.fromScale(0.04, 0.08)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.PermanentMarker
	textLabel.TextScaled = true
	textLabel.TextColor3 = textColor or C.blanco
	textLabel.Text = text
	textLabel.Parent = gui
	return board, gui
end

-- Cartel de marcador: apagado con SHOW.signs (los carteles con tipografía Oswald usan signBoard a través de blankBoard)
local function sign(...)
	if SHOW.signs then
		return signBoard(...)
	end
	return nil, nil
end

-- Flecha pintada en el suelo (6 × 2.5), brilla un poco. `angle` = giro en Y; 0 apunta hacia +Z.
local function floorArrow(parent, position, color, angle)
	if not SHOW.floorArrows then
		return
	end
	local base = CFrame.new(position.X, FLOOR_TOP + 0.04, position.Z) * CFrame.Angles(0, angle or 0, 0)
	local parts = {
		block(parent, "Flecha", Vector3.new(1.1, 0.08, 4), base * CFrame.new(0, 0, -1)),
		block(parent, "Flecha", Vector3.new(0.9, 0.08, 2.6), base * CFrame.new(-0.75, 0, 1.75) * CFrame.Angles(0, math.rad(45), 0)),
		block(parent, "Flecha", Vector3.new(0.9, 0.08, 2.6), base * CFrame.new(0.75, 0, 1.75) * CFrame.Angles(0, math.rad(-45), 0)),
	}
	for _, part in parts do
		deco(part)
		part.Color = color
		part.Material = Enum.Material.Neon
		part.Transparency = 0.25
	end
end

---------------------------------------------------------------------------------------------------
-- Kit de piezas (Prompt 1, versión gris)

-- Carro chocado (6 × 4.5 × 12)
local function car(parent, x, z, angle, color)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(angle), 0)
	block(parent, "Carro", Vector3.new(6, 2.5, 12), base * CFrame.new(0, 1.5, 0), color, Enum.Material.Metal)
	block(parent, "CarroCabina", Vector3.new(5.4, 1.8, 6), base * CFrame.new(0, 3.65, 0.5), C.oscuro, Enum.Material.Glass)
	deco(block(parent, "CarroRueda", Vector3.new(6.2, 1.2, 1.6), base * CFrame.new(0, 0.6, -3.8), C.oscuro))
	deco(block(parent, "CarroRueda", Vector3.new(6.2, 1.2, 1.6), base * CFrame.new(0, 0.6, 3.8), C.oscuro))
end

-- Autobús escolar volcado sobre un costado (8 × 11 × 30 de pie; tumbado queda de 11 de ancho y 8 de alto)
local function busOnSide(parent, x1, z)
	local cx = x1 + 15
	local body = block(parent, "Autobus", Vector3.new(30, 8, 11), Vector3.new(cx, 4, z), C.mostaza, Enum.Material.Metal)
	CollectionService:AddTag(body, "ClimbableBus") -- los zombies pueden trepar a su techo (server/Zombies)
	deco(block(parent, "AutobusVentanas", Vector3.new(24, 0.2, 2.4), Vector3.new(cx + 1.5, 8.1, z - 1.5), C.oscuro, Enum.Material.Glass))
	deco(block(parent, "AutobusFranja", Vector3.new(30.1, 0.6, 11.1), Vector3.new(cx, 4, z), C.oscuro))
	deco(block(parent, "AutobusRueda", Vector3.new(2, 2.4, 1.2), Vector3.new(cx - 9, 4, z + 6), C.oscuro))
	deco(block(parent, "AutobusRueda", Vector3.new(2, 2.4, 1.2), Vector3.new(cx + 9, 4, z + 6), C.oscuro))
	-- Ventanillas, puerta, luces y letrero de destino
	for i = -4, 3 do
		deco(block(parent, "AutobusVentanilla", Vector3.new(2.4, 0.15, 2.2), Vector3.new(cx + 2 + i * 3, 8.12, z + 1.8), C.oscuro, Enum.Material.Glass))
	end
	deco(block(parent, "AutobusPuerta", Vector3.new(3, 0.15, 5), Vector3.new(cx + 12.5, 8.1, z + 0.5), C.oxido, Enum.Material.Metal))
	for _, dz in { -3.2, 3.2 } do
		deco(block(parent, "AutobusFaro", Vector3.new(0.2, 1, 1.6), Vector3.new(cx + 15.1, 2.5, z + dz), Color3.fromRGB(255, 232, 170), Enum.Material.Neon))
		deco(block(parent, "AutobusLuzTrasera", Vector3.new(0.2, 1, 1.4), Vector3.new(cx - 15.1, 2.5, z + dz), C.rojo, Enum.Material.Neon))
	end
	deco(block(parent, "AutobusLetrero", Vector3.new(0.2, 1.8, 6.5), Vector3.new(cx + 15.1, 6.2, z), C.oscuro, Enum.Material.SmoothPlastic))
	deco(block(parent, "AutobusLetreroLuz", Vector3.new(0.25, 0.7, 5.4), Vector3.new(cx + 15.12, 6.2, z), Color3.fromRGB(255, 176, 50), Enum.Material.Neon))
end

-- Puesto de feria abandonado (8 × 9 × 6): mesa con colisión, toldo y cajas de fruta de adorno
local function stall(parent, x, z, canvas)
	block(parent, "PuestoMesa", Vector3.new(7, 3, 4), Vector3.new(x, 1.5, z), C.madera, Enum.Material.Wood)
	for _, corner in { Vector3.new(-3.6, 0, -2.6), Vector3.new(3.6, 0, -2.6), Vector3.new(-3.6, 0, 2.6), Vector3.new(3.6, 0, 2.6) } do
		deco(pole(parent, "PuestoPalo", Vector3.new(x, 0, z) + corner, 8.6, 0.3, C.concreto))
	end
	deco(block(parent, "PuestoToldo", Vector3.new(8, 0.4, 6), CFrame.new(x, 8.7, z) * CFrame.Angles(math.rad(6), 0, 0), canvas, Enum.Material.Fabric))
	for i = -1, 1 do
		deco(block(parent, "PuestoFruta", Vector3.new(1.6, 0.8, 1.2), Vector3.new(x + i * 2.2, 3.4, z), i == 0 and C.lima or C.lonaNaranja, Enum.Material.SmoothPlastic))
	end
end

-- Cobertura baja
local function container(parent, x, z, angle)
	block(parent, "Contenedor", Vector3.new(4, 4, 3), CFrame.new(x, 2, z) * CFrame.Angles(0, math.rad(angle or 0), 0), C.lonaVerde, Enum.Material.Metal)
end

local function crates(parent, x, z)
	block(parent, "PilaCajas", Vector3.new(6, 3, 6), Vector3.new(x, 1.5, z), C.madera, Enum.Material.WoodPlanks)
	block(parent, "PilaCajas", Vector3.new(3, 3, 3), Vector3.new(x - 1.4, 4.5, z + 1.2), C.madera, Enum.Material.WoodPlanks)
end

local function sandbags(parent, x, z, angle)
	block(parent, "Sacos", Vector3.new(4, 2, 4), CFrame.new(x, 1, z) * CFrame.Angles(0, math.rad(angle or 0), 0), C.tierra, Enum.Material.Fabric)
end

local function barrel(parent, x, z, color)
	pole(parent, "Barril", Vector3.new(x, 0, z), 3, 2, color or C.oxido)
end

---------------------------------------------------------------------------------------------------
-- Casas favela (modelos propios de ZombieData/Favela*): reemplazan las casas de colores de la calle principal. Cada casa
-- es un bloque sólido (colisión y balas) con el modelo encima como decoración sin colisión, alineado a la fachada y
-- estirado al ancho y al fondo disponibles. Versión "ligera": se omiten las piezas muy pequeñas (rejas, pernos, cables).

local FAVELA_SCALE = 2.6 -- studs por metro del modelo (con esto la puerta mide 5.3, como un jugador)
local FAVELA_WALL = Color3.fromRGB(120, 114, 108)
local FAVELA_FONT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

local function favelaInfo(data)
	local floorPiece
	for _, piece in data.parts do
		if piece.name:find("_piso_0$") then
			floorPiece = piece
			break
		end
	end
	local size = floorPiece.size
	local wallColor = FAVELA_WALL
	for _, piece in data.parts do
		if piece.name:find("_revoque_0$") then
			wallColor = piece.color
			break
		end
	end
	local top = 0
	for _, piece in data.parts do
		if piece.size.X > size.X * 0.6 and piece.size.Z > size.Z * 0.6 and piece.size.Y < 1 then
			top = math.max(top, piece.cf.Y + piece.size.Y / 2)
		end
	end
	return { w = size.X, d = size.Z, frontZ = floorPiece.cf.Z - size.Z / 2, cx = floorPiece.cf.X, top = top, floors = math.round(top / 3), wallColor = wallColor }
end

local FAVELAS = {}
for _, data in { FavelaVerde, FavelaRosa, FavelaAzul, FavelaAmarilla, FavelaNaranja } do
	table.insert(FAVELAS, { data = data, info = favelaInfo(data) })
end
local favelaRng = Random.new(2026) -- elige el modelo de cada casa (build() lo reinicia con la semilla)
local lastFavela = nil

-- Elige el modelo cuyo ancho natural se parece más al frente disponible; las casas altas (26) prefieren 3+ pisos
local function pickFavela(length, height)
	local tall = height >= 24
	local candidates = {}
	for _, entry in FAVELAS do
		local ratio = (length - 0.4) / (entry.info.w * FAVELA_SCALE)
		if ratio >= 0.7 and ratio <= 1.45 and entry ~= lastFavela and (tall == (entry.info.floors >= 3)) then
			table.insert(candidates, entry)
		end
	end
	if #candidates == 0 then -- sin coincidencia: el de ancho más parecido
		local best, bestDiff = FAVELAS[1], math.huge
		for _, entry in FAVELAS do
			local diff = math.abs((length - 0.4) / (entry.info.w * FAVELA_SCALE) - 1)
			if diff < bestDiff and entry ~= lastFavela then
				best, bestDiff = entry, diff
			end
		end
		return best
	end
	return candidates[favelaRng:NextInteger(1, #candidates)]
end

-- Texto sobre una pieza del modelo (rótulos y pintadas que en el modelo original eran imágenes)
local function favelaText(part, text, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- el frente del modelo mira a -Z local
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.BackgroundTransparency = 1
	label.FontFace = FAVELA_FONT
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = gui
end

local function favelaLook(piece)
	local name, mat = piece.name, piece.mat
	local color, material = piece.color, Enum.Material.Concrete
	if piece.neon then
		material = Enum.Material.Neon
	elseif mat == "hormigon" then
		color = Color3.fromRGB(138, 134, 128)
	elseif mat and (mat:find("ladrillo") or mat:find("peso")) then
		color, material = Color3.fromRGB(176, 84, 52), Enum.Material.Brick
	elseif mat == "zinc" then
		color, material = Color3.fromRGB(150, 156, 150), Enum.Material.CorrodedMetal
	elseif name:find("reja") or name:find("varilla") or name:find("antena") or name:find("escalera") or name:find("baranda") then
		material = Enum.Material.Metal
	elseif name:find("toldo") or name:find("ropa") or name:find("tendedero") then
		material = Enum.Material.Fabric
	elseif name:find("hoja") then
		material = Enum.Material.WoodPlanks
	end
	return color, material
end

-- Una casa favela alineada a la fachada (faceX) que da a la calle (faceDir = hacia dónde mira la fachada)
local function placeFavela(parent, entry, x1, x2, z1, z2, faceX, faceDir)
	local info, data = entry.info, entry.data
	local S = FAVELA_SCALE
	local xs = math.clamp((z2 - z1 - 0.4) / info.w, S * 0.65, S * 1.4) -- ancho (a lo largo de la calle)
	local zs = math.clamp((x2 - x1 - 0.6) / info.d, 1, S * 1.35) -- fondo
	local R = CFrame.Angles(0, -faceDir * math.pi / 2, 0)
	local target = Vector3.new(faceX + faceDir * 0.15, 0, (z1 + z2) / 2)
	local origin = CFrame.new(target - R:VectorToWorldSpace(Vector3.new(info.cx * xs, 0, info.frontZ * zs))) * R

	local folder = Instance.new("Folder")
	folder.Name = "Favela"
	for _, piece in data.parts do
		local s = piece.size
		local sorted = { s.X, s.Y, s.Z }
		table.sort(sorted)
		local keep = piece.neon or piece.mat or s.X * s.Y * s.Z > 0.02 or sorted[3] * sorted[2] > 0.15
		if keep then
			local rot = piece.cf - piece.cf.Position
			local axes = { rot.RightVector, rot.UpVector, -rot.LookVector }
			local size = Vector3.new(
				s.X * Vector3.new(axes[1].X * xs, axes[1].Y * S, axes[1].Z * zs).Magnitude,
				s.Y * Vector3.new(axes[2].X * xs, axes[2].Y * S, axes[2].Z * zs).Magnitude,
				s.Z * Vector3.new(axes[3].X * xs, axes[3].Y * S, axes[3].Z * zs).Magnitude
			)
			size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
			local p = piece.cf.Position
			local cf = origin * CFrame.new(p.X * xs, p.Y * S, p.Z * zs) * rot
			local color, material = favelaLook(piece)
			local part = deco(block(folder, piece.name, size, cf, color, material))
			if piece.shape == "Ball" then
				part.Shape = Enum.PartType.Ball
			elseif piece.shape == "Cylinder" then
				part.Shape = Enum.PartType.Cylinder
			end
			local mat = piece.mat
			if mat and mat:find("letrero") then
				part.Color = Color3.fromRGB(226, 178, 30)
				favelaText(part, "BAR", Color3.fromRGB(16, 16, 16))
			elseif mat and mat:find("pintada") then
				part.Transparency = 1
				if mat:find("naranja") then
					favelaText(part, "RHOMULUS", Color3.fromRGB(198, 21, 26))
				else
					favelaText(part, "MORRO", Color3.fromRGB(16, 16, 16))
				end
			end
		end
	end
	folder.Parent = parent
end

-- Fachada de casa o edificio (bloque sólido de x1..x2, z1..z2) con puerta, ventanas, techo y 1 o 2 detalles.
-- faceX = x de la fachada que da a la calle; faceDir = hacia dónde mira (+1 = +X, -1 = -X).
local function building(parent, rng, x1, x2, z1, z2, height, faceX, faceDir)
	-- Casa favela: bloque sólido (colisión y balas) con el modelo encima. Se gasta el mismo azar que la casa antigua
	-- para que el resto del mapa no cambie de sitio.
	rng:NextInteger(1, #HOUSE_COLORS)
	rng:NextInteger(1, 2)
	rng:NextInteger(3, math.max(3, math.floor(z2 - z1) - 3))
	rng:NextInteger(1, 4)
	local entry = pickFavela(z2 - z1, height)
	lastFavela = entry
	local wallHeight = entry.info.top * FAVELA_SCALE
	slab(parent, "Casa", x1, x2, z1, z2, wallHeight, entry.info.wallColor):SetAttribute("Favela", true)
	placeFavela(parent, entry, x1, x2, z1, z2, faceX, faceDir)
end

---------------------------------------------------------------------------------------------------
-- Partes del mapa

-- Parte 2: el lobby (la cochera). Cuarto cerrado de 120 × 50 × 20, interior libre de 90 × 40.
---------------------------------------------------------------------------------------------------
-- Lobby (la cochera): modelo del carro abandonado, carteles de las imágenes de Carteles.zip hechos con texto vivo y
-- detalles de pared, techo y suelo (todo decoración sin colisión, salvo el carro). Unas 250 piezas.

local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local RHO_RED = Color3.fromRGB(198, 21, 26)
local RHO_YELLOW = Color3.fromRGB(226, 178, 30)
local RHO_BLUE = Color3.fromRGB(46, 110, 198)
local RHO_BLACK = Color3.fromRGB(12, 12, 12)

local function boardText(parent, text, x, y, w, h, color, align, rotation)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(x, y)
	l.Size = UDim2.fromScale(w, h)
	l.FontFace = OSWALD
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Rotation = rotation or 0
	l.Parent = parent
	return l
end

local function boardRect(parent, x, y, w, h, color, rotation)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	f.Rotation = rotation or 0
	f.Parent = parent
	return f
end

-- Tablero sin texto: se pinta encima con boardText/boardRect
local function blankBoard(parent, name, size, cframe, background, pixelsPerStud)
	local board, gui = signBoard(parent, name, "", size, cframe, background)
	gui:FindFirstChildOfClass("TextLabel"):Destroy()
	gui.PixelsPerStud = pixelsPerStud or 60
	return board, gui
end

-- Cartel de una ruta (mismo estilo que el cartel de rutas): marco negro, tarjeta de color, número, línea y nombre
local function routeSign(parent, name, cframe, size, number, text, color)
	local _, gui = blankBoard(parent, name, size, cframe, RHO_BLACK, 60)
	boardRect(gui, 0.03, 0.08, 0.94, 0.84, color)
	boardText(gui, number, 0.07, 0.12, 0.22, 0.36, RHO_BLACK)
	boardText(gui, "RUTA", 0.55, 0.15, 0.38, 0.14, RHO_BLACK, Enum.TextXAlignment.Right)
	boardRect(gui, 0.07, 0.5, 0.86, 0.014, RHO_BLACK)
	boardText(gui, text, 0.07, 0.53, 0.86, 0.4, RHO_BLACK)
end

-- Cartel "ELIGE TU RUTA" (cartel_rutas_1400x1000.png): 14 × 10
local function routesBoard(parent, cframe)
	local _, gui = blankBoard(parent, "CartelRutas", Vector3.new(14, 10, 0.3), cframe, RHO_BLACK, 60)
	boardRect(gui, 0, 0, 1, 0.26, RHO_RED)
	boardText(gui, "DÍA 01", 0.043, 0.035, 0.3, 0.055, RHO_BLACK)
	boardText(gui, "ELIGE TU RUTA", 0.55, 0.035, 0.407, 0.055, RHO_BLACK, Enum.TextXAlignment.Right)
	boardText(gui, "MORRO ESPERANZA", 0.043, 0.085, 0.9, 0.16, RHO_BLACK)
	for i, card in { { "01", "CALLEJÓN", RHO_YELLOW }, { "02", "CALLE", RHO_RED }, { "03", "ESCALERA", RHO_BLUE } } do
		local x = 0.043 + (i - 1) * 0.313
		boardRect(gui, x, 0.31, 0.288, 0.54, card[3])
		boardText(gui, card[1], x + 0.022, 0.33, 0.2, 0.15, RHO_BLACK)
		boardRect(gui, x + 0.021, 0.728, 0.245, 0.005, RHO_BLACK)
		boardText(gui, card[2], x + 0.021, 0.74, 0.25, 0.09, RHO_BLACK)
	end
	boardRect(gui, 0.043, 0.9, 0.914, 0.003, RHO_RED)
	boardText(gui, "ACÉRCATE Y PRESIONA E", 0.043, 0.92, 0.5, 0.045, RHO_RED)
	boardText(gui, "SOBREVIVE", 0.6, 0.92, 0.357, 0.045, RHO_RED, Enum.TextXAlignment.Right)
end

-- Pancarta "AQUÍ NO SE RINDE NADIE" (pancarta_2000x560.png): proporción 3.57
local function banner(parent, cframe, width)
	local _, gui = blankBoard(parent, "Pancarta", Vector3.new(width, width / 3.57, 0.3), cframe, RHO_RED, math.min(60, 1500 / width))
	boardRect(gui, 0.03, -0.02, 0.09, 0.075, Color3.fromRGB(222, 184, 168), -4)
	boardRect(gui, 0.88, -0.02, 0.09, 0.075, Color3.fromRGB(222, 184, 168), 4)
	boardText(gui, "MORRO ESPERANZA", 0.04, 0.1, 0.3, 0.09, RHO_BLACK)
	boardText(gui, "DÍA 01", 0.7, 0.1, 0.26, 0.09, RHO_BLACK, Enum.TextXAlignment.Right)
	boardRect(gui, 0.04, 0.2, 0.92, 0.004, RHO_BLACK)
	boardText(gui, "AQUÍ NO SE RINDE NADIE", 0.06, 0.28, 0.88, 0.46, RHO_BLACK, Enum.TextXAlignment.Center, -2)
	for _, drip in { { 0.18, 0.7, 0.04 }, { 0.34, 0.69, 0.025 }, { 0.57, 0.72, 0.05 }, { 0.78, 0.7, 0.03 } } do
		boardRect(gui, drip[1], drip[2], 0.003, drip[3], RHO_BLACK)
	end
	boardRect(gui, 0.04, 0.84, 0.92, 0.004, RHO_BLACK)
	boardText(gui, "SOBREVIVE", 0.04, 0.87, 0.3, 0.08, RHO_BLACK)
	boardText(gui, "RHOMULUS", 0.7, 0.87, 0.26, 0.08, RHO_BLACK, Enum.TextXAlignment.Right)
end

-- Pone un modelo de ZombieData como piezas fijas (sin soldaduras). Solo colisionan las piezas de `solid`.
local GLASS_NAMES = { "parabrisas", "luneta", "ventana", "vidrio", "cristales" }
local METAL_NAMES = { "cromo", "parachoques", "parrilla", "tapacubo", "manija", "baca", "cuerpo", "capo", "maletero", "cabina", "techo", "pilar", "puerta_panel", "guardabarros", "chasis", "escape" }
local CAR_BODY = Color3.fromRGB(47, 156, 132) -- color de la carrocería del carro abandonado
local CAR_BODY_DARK = Color3.fromRGB(31, 107, 91)
local function placeModel(parent, data, position, yaw, solid, bodyColor)
	local origin = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local model = Instance.new("Model")
	model.Name = data.rig
	for _, piece in data.parts do
		local color = piece.color
		if bodyColor and color == CAR_BODY then
			color = bodyColor
		elseif bodyColor and color == CAR_BODY_DARK then
			color = bodyColor:Lerp(Color3.new(0, 0, 0), 0.3)
		end
		local part = block(model, piece.name, piece.size, origin * piece.cf, color, Enum.Material.SmoothPlastic)
		if piece.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif piece.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		local name = piece.name
		if piece.neon then
			part.Material = Enum.Material.Neon
		elseif name:find("oxido") then
			part.Material = Enum.Material.CorrodedMetal
		elseif name:find("llanta") then
			part.Material = Enum.Material.Rubber
		elseif name:find("asiento") or name:find("respaldo") or name:find("bulto") or name:find("maleta") or name:find("cuerda") then
			part.Material = Enum.Material.Fabric
		else
			for _, key in METAL_NAMES do
				if name:find(key) then
					part.Material = Enum.Material.Metal
				end
			end
			for _, key in GLASS_NAMES do
				if name:find(key) then
					part.Material = Enum.Material.Glass
					part.Transparency = 0.45
				end
			end
		end
		if solid[name] then
			part.CanCollide = true
		else
			deco(part)
		end
	end
	model.Parent = parent
	return model
end

local LOBBY_SOLID = { chasis = true, cuerpo = true, capo = true, maletero = true, cabina_base = true, techo = true, llanta_0 = true, llanta_1 = true, llanta_2 = true, llanta_3 = true }

-- CFrame sobre la superficie interior de una pared del lobby, con el frente (-Z local) hacia el interior de la sala
local function lobbyWall(wall, along, y)
	if wall == "back" then
		return CFrame.new(along, y, -395) * CFrame.Angles(0, math.pi, 0)
	elseif wall == "east" then
		return CFrame.new(45, y, along) * CFrame.Angles(0, math.pi / 2, 0)
	elseif wall == "west" then
		return CFrame.new(-45, y, along) * CFrame.Angles(0, -math.pi / 2, 0)
	end
	return CFrame.new(along, y, -355) -- "front"
end

local function lobbyDetails(map, rng)
	local folder = Instance.new("Folder")
	folder.Name = "LobbyDetalles"
	folder.Parent = map
	local plaster = C.blanco
	local dark = Color3.fromRGB(60, 54, 50)

	-- Carteles del Carteles.zip
	routesBoard(folder, lobbyWall("back", 0, 11.5) * CFrame.new(0, 0, -0.3))
	banner(folder, lobbyWall("east", -387.5, 11) * CFrame.new(0, 0, -0.3), 13.5)
	banner(folder, lobbyWall("west", -387.5, 11) * CFrame.new(0, 0, -0.3), 13.5)

	-- Pilastras con zócalo y capitel en el fondo, a los lados de las puertas y en el frente
	local function pilaster(wall, along)
		deco(block(folder, "Pilastra", Vector3.new(1.8, 20, 0.8), lobbyWall(wall, along, 10) * CFrame.new(0, 0, -0.4), C.concreto, Enum.Material.Concrete))
		deco(block(folder, "PilastraBase", Vector3.new(2.4, 1.6, 1.2), lobbyWall(wall, along, 0.8) * CFrame.new(0, 0, -0.6), dark, Enum.Material.Concrete))
		deco(block(folder, "PilastraCapitel", Vector3.new(2.4, 1, 1.2), lobbyWall(wall, along, 19.4) * CFrame.new(0, 0, -0.6), dark, Enum.Material.Concrete))
	end
	for _, x in { -38, -24, -11, 11, 24, 38 } do
		pilaster("back", x)
	end
	for _, wall in { "east", "west" } do
		pilaster(wall, -356.8)
	end
	for _, x in { -40, -22, 22, 40 } do
		pilaster("front", x)
	end

	-- Marcos oscuros de las puertas laterales
	for _, wall in { "east", "west" } do
		for _, z in { -380.4, -367.6 } do
			deco(block(folder, "MarcoPuerta", Vector3.new(0.9, 14.6, 0.8), lobbyWall(wall, z, 7.3) * CFrame.new(0, 0, -0.45), dark, Enum.Material.Concrete))
		end
		deco(block(folder, "MarcoPuertaDintel", Vector3.new(13.6, 0.9, 0.8), lobbyWall(wall, -374, 14.4) * CFrame.new(0, 0, -0.45), dark, Enum.Material.Concrete))
	end

	-- Moldura oscura bajo el techo y franja roja a 16 de alto
	for _, strip in {
		{ "back", 0, 90 }, { "front", -30, 30 }, { "front", 30, 30 },
		{ "east", -387.5, 15 }, { "east", -361.5, 13 }, { "west", -387.5, 15 }, { "west", -361.5, 13 },
	} do
		deco(block(folder, "Moldura", Vector3.new(strip[3], 0.7, 0.35), lobbyWall(strip[1], strip[2], 18.4) * CFrame.new(0, 0, -0.18), dark, Enum.Material.Concrete))
		deco(block(folder, "FranjaAlta", Vector3.new(strip[3], 0.4, 0.2), lobbyWall(strip[1], strip[2], 16.2) * CFrame.new(0, 0, -0.1), RHO_RED, Enum.Material.SmoothPlastic))
	end

	-- Ladrillo a la vista donde se cayó el yeso: base, juntas y trozos de yeso en los bordes
	local joint = Color3.fromRGB(190, 180, 165)
	local function brickPatch(wall, along, y, w, h)
		local cf = lobbyWall(wall, along, y)
		deco(block(folder, "Ladrillo", Vector3.new(w, h, 0.15), cf * CFrame.new(0, 0, -0.08), C.terracota, Enum.Material.Brick))
		for row = 1, 3 do
			deco(block(folder, "LadrilloJunta", Vector3.new(w, 0.12, 0.05), cf * CFrame.new(0, -h / 2 + row * h / 4, -0.17), joint, Enum.Material.Concrete))
		end
		for col = 1, 4 do
			deco(block(folder, "LadrilloJunta", Vector3.new(0.1, h / 4, 0.05), cf * CFrame.new(-w / 2 + col * w / 5, -h / 2 + (col % 2 + 0.5) * h / 4, -0.17), joint, Enum.Material.Concrete))
		end
		for _ = 1, 3 do
			local up = rng:NextNumber() < 0.5 and -h / 2 - 0.4 or h / 2 + 0.4
			deco(block(folder, "YesoCaido", Vector3.new(rng:NextNumber(0.8, 1.8), rng:NextNumber(0.6, 1.4), 0.12), cf * CFrame.new(rng:NextNumber(-w / 2, w / 2), up, -0.1), plaster, Enum.Material.Concrete))
		end
		for _ = 1, 2 do -- escombro al pie
			deco(block(folder, "Escombro", Vector3.new(rng:NextNumber(0.6, 1.2), 0.5, rng:NextNumber(0.6, 1.2)), cf * CFrame.new(rng:NextNumber(-w / 2, w / 2), -y + 0.3, -rng:NextNumber(0.8, 2.4)) * CFrame.Angles(0, rng:NextNumber() * 3, 0), C.terracota, Enum.Material.Brick))
		end
	end
	brickPatch("back", -30, 10, 7, 5)
	brickPatch("back", 31, 9, 8, 4.5)
	brickPatch("front", -28, 12, 6, 4)
	brickPatch("east", -362, 12, 5, 4)

	-- Grietas
	local function crack(wall, along, y, length, tilt)
		local cf = lobbyWall(wall, along, y)
		local offsetX, offsetY = 0, 0
		for i = 1, 3 do
			local angle = tilt + (i % 2 == 0 and 0.5 or -0.4)
			local seg = length / 3
			deco(block(folder, "Grieta", Vector3.new(0.14, seg, 0.04), cf * CFrame.new(offsetX, offsetY + seg / 2, -0.05) * CFrame.Angles(0, 0, angle), RHO_BLACK, Enum.Material.SmoothPlastic))
			offsetX -= math.sin(angle) * seg
			offsetY += math.cos(angle) * seg
		end
	end
	crack("back", -17, 3, 9, 0.1)
	crack("back", 18, 8, 7, -0.2)
	crack("front", 33, 4, 8, 0.15)
	crack("west", -388, 5, 7, 0.1)
	crack("east", -360, 4, 9, -0.1)

	-- Manchas de humedad que chorrean del techo
	for _, stain in { { "back", -3, 14 }, { "back", 40, 12 }, { "back", -43, 12 }, { "front", 20, 16 }, { "east", -392, 12 }, { "west", -364, 14 } } do
		local s = deco(block(folder, "Humedad", Vector3.new(rng:NextNumber(1.4, 2.6), stain[3], 0.08), lobbyWall(stain[1], stain[2], 20 - stain[3] / 2) * CFrame.new(0, 0, -0.06), Color3.fromRGB(120, 110, 96), Enum.Material.Concrete))
		s.Transparency = 0.6
	end

	local yellow = Color3.fromRGB(225, 190, 50)
	-- Conteo de días (cuatro rayas y una cruzada, tres veces) en el fondo
	for group = 0, 2 do
		for stroke = 0, 3 do
			deco(block(folder, "Raya", Vector3.new(0.18, 2.2, 0.05), lobbyWall("back", -43.5 + group * 2.6 + stroke * 0.4, 6) * CFrame.new(0, 0, -0.07), yellow, Enum.Material.SmoothPlastic))
		end
		deco(block(folder, "RayaCruz", Vector3.new(0.18, 2.6, 0.05), lobbyWall("back", -43.5 + group * 2.6 + 0.6, 6) * CFrame.new(0, 0, -0.08) * CFrame.Angles(0, 0, 1.2), yellow, Enum.Material.SmoothPlastic))
	end

	-- Estantería metálica con latas y cajas junto al fondo
	do
		local base = lobbyWall("back", 14, 0)
		for _, dx in { -4.6, 4.6 } do
			for _, dz in { -0.4, -2.4 } do
				deco(block(folder, "EstantePoste", Vector3.new(0.3, 11, 0.3), base * CFrame.new(dx, 5.5, dz), C.concreto, Enum.Material.Metal))
			end
		end
		for level = 1, 3 do
			local y = level * 3.4
			deco(block(folder, "EstanteTabla", Vector3.new(10, 0.3, 2.4), base * CFrame.new(0, y, -1.4), C.madera, Enum.Material.WoodPlanks))
			for i = 1, 5 do
				if rng:NextNumber() < 0.8 then
					if level == 2 then
						deco(block(folder, "EstanteCaja", Vector3.new(1.5, 1.2, 1.4), base * CFrame.new(-4 + i * 1.5, y + 0.75, -1.4) * CFrame.Angles(0, rng:NextNumber() * 0.4, 0), C.madera, Enum.Material.Cardboard))
					else
						deco(pole(folder, "EstanteLata", (base * CFrame.new(-4 + i * 1.5, y + 0.15, -1.4)).Position, 1, 0.7, ({ C.rojo, C.lima, C.lonaNaranja, C.mostaza })[rng:NextInteger(1, 4)]))
					end
				end
			end
		end
	end

	-- Tablero de herramientas en el muro oeste y reloj parado a las 3:15 en el fondo
	do
		local cf = lobbyWall("west", -388, 8)
		deco(block(folder, "TableroHerramientas", Vector3.new(8, 5, 0.3), cf * CFrame.new(0, 0, -0.25), C.madera, Enum.Material.WoodPlanks))
		deco(block(folder, "Martillo", Vector3.new(0.3, 2.4, 0.2), cf * CFrame.new(-2.6, 0.2, -0.5), C.concreto, Enum.Material.Metal))
		deco(block(folder, "MartilloCabeza", Vector3.new(1.2, 0.6, 0.3), cf * CFrame.new(-2.6, 1.5, -0.5), C.oscuro, Enum.Material.Metal))
		deco(block(folder, "Llave", Vector3.new(0.35, 3, 0.15), cf * CFrame.new(-0.6, 0, -0.45) * CFrame.Angles(0, 0, 0.2), C.concreto, Enum.Material.Metal))
		deco(block(folder, "Serrucho", Vector3.new(3.8, 0.9, 0.1), cf * CFrame.new(1.8, -0.8, -0.45), C.concreto, Enum.Material.Metal))
		deco(block(folder, "SerruchoMango", Vector3.new(0.9, 1.1, 0.2), cf * CFrame.new(3.4, -0.8, -0.45), C.oxido, Enum.Material.Wood))
		deco(block(folder, "Destornillador", Vector3.new(0.25, 2, 0.2), cf * CFrame.new(2.6, 1.3, -0.45), C.rojo, Enum.Material.Plastic))
		local clock = lobbyWall("back", -17, 14.5) * CFrame.new(0, 0, -0.25)
		local face = deco(pole(folder, "RelojCara", Vector3.zero, 0.3, 3, C.blanco, Enum.Material.SmoothPlastic))
		face.CFrame = clock * CFrame.Angles(0, math.pi / 2, 0) -- el cilindro mira hacia la sala
		deco(block(folder, "RelojManecilla", Vector3.new(0.12, 1.1, 0.06), clock * CFrame.new(0.3, 0.2, -0.3) * CFrame.Angles(0, 0, -1.2), RHO_BLACK))
		deco(block(folder, "RelojManecilla", Vector3.new(0.1, 1.2, 0.06), clock * CFrame.new(0, 0.5, -0.3), RHO_BLACK))
	end

	-- Caja de fusibles con cables que bajan al suelo (muro este, junto al frente)
	do
		local cf = lobbyWall("east", -358.5, 9)
		deco(block(folder, "CajaFusibles", Vector3.new(2.6, 3.4, 0.9), cf * CFrame.new(0, 0, -0.5), Color3.fromRGB(110, 118, 112), Enum.Material.Metal))
		deco(block(folder, "CajaFusiblesPuerta", Vector3.new(2.2, 3, 0.1), cf * CFrame.new(0, 0, -1), Color3.fromRGB(125, 133, 126), Enum.Material.Metal))
		deco(block(folder, "FusibleLuz", Vector3.new(0.3, 0.3, 0.1), cf * CFrame.new(0.7, 1, -1.08), RHO_RED, Enum.Material.Neon))
		for i = 1, 3 do
			deco(block(folder, "Cable", Vector3.new(0.14, 8 + i, 0.14), cf * CFrame.new(-0.6 + i * 0.5, -5.5, -0.6) * CFrame.Angles(0, 0, 0.05 * i), C.oscuro))
		end
	end

	-- Ventanas altas con barrotes en el fondo
	for _, x in { -30, 30 } do
		local cf = lobbyWall("back", x, 15.5)
		deco(block(folder, "VentanaMarco", Vector3.new(6.4, 3.8, 0.3), cf * CFrame.new(0, 0, -0.2), dark, Enum.Material.Concrete))
		local glass = deco(block(folder, "VentanaVidrio", Vector3.new(5.6, 3, 0.15), cf * CFrame.new(0, 0, -0.35), Color3.fromRGB(30, 40, 60), Enum.Material.Glass))
		glass.Transparency = 0.3
		for i = -2, 2 do
			deco(block(folder, "VentanaBarrote", Vector3.new(0.18, 3, 0.18), cf * CFrame.new(i * 1.1, 0, -0.5), C.oscuro, Enum.Material.Metal))
		end
	end

	-- Techo: vigas, tuberías y focos apagados colgando
	for _, x in { -37.5, -22.5, -7.5, 7.5, 22.5, 37.5 } do
		deco(block(folder, "Viga", Vector3.new(1.2, 1.2, 50), Vector3.new(x, 19.4, -375), dark, Enum.Material.Concrete))
	end
	for _, pipe in { { -388, C.oxido }, { -372, C.lonaAzul }, { -360, C.oxido } } do
		deco(pole(folder, "Tuberia", Vector3.new(0, 0, pipe[1]), 90, 0.8, pipe[2], Enum.Material.Metal)).CFrame = CFrame.new(0, 18.4, pipe[1])
	end
	for _, x in { -20, 20 } do
		deco(block(folder, "FocoCable", Vector3.new(0.1, 3, 0.1), Vector3.new(x, 18.3, -380), C.oscuro))
		deco(block(folder, "FocoApagado", Vector3.new(0.9, 0.9, 0.9), Vector3.new(x, 16.4, -380), Color3.fromRGB(200, 190, 160), Enum.Material.Glass))
	end

	-- Suelo: manchas de aceite, charco, marcas del puesto del carro y basura
	for _, spot in { { 26, -366, 4 }, { -14, -372, 3 }, { 8, -390, 2.4 } } do
		deco(pole(folder, "ManchaAceite", Vector3.new(spot[1], FLOOR_TOP + 0.02, spot[2]), 0.03, spot[3], Color3.fromRGB(18, 18, 20), Enum.Material.SmoothPlastic))
	end
	deco(pole(folder, "Charco", Vector3.new(-8, FLOOR_TOP + 0.03, -361), 0.03, 5, Color3.fromRGB(30, 44, 58), Enum.Material.Glass)).Transparency = 0.3
	for _, x in { 22.5, 37.5 } do
		deco(block(folder, "LineaPuesto", Vector3.new(0.5, 0.05, 14), Vector3.new(x, FLOOR_TOP + 0.04, -366), RHO_YELLOW, Enum.Material.SmoothPlastic))
	end
	for i = 1, 26 do
		local x, z = rng:NextNumber(-42, 42), rng:NextNumber(-393, -357)
		local yaw = rng:NextNumber() * math.pi * 2
		local kind = i % 4
		if kind == 0 then
			deco(block(folder, "Papeles", Vector3.new(1.2, 0.04, 0.9), CFrame.new(x, FLOOR_TOP + 0.03, z) * CFrame.Angles(0, yaw, 0), C.blanco, Enum.Material.SmoothPlastic))
		elseif kind == 1 then
			deco(pole(folder, "LataTirada", Vector3.new(x, FLOOR_TOP, z), 0.9, 0.6, ({ C.rojo, C.lima, C.mostaza })[rng:NextInteger(1, 3)]))
		elseif kind == 2 then
			deco(block(folder, "Escombro", Vector3.new(rng:NextNumber(0.5, 1.1), 0.5, rng:NextNumber(0.5, 1.1)), CFrame.new(x, 0.3, z) * CFrame.Angles(0, yaw, 0), C.concreto, Enum.Material.Concrete))
		else
			deco(block(folder, "RopaSuelo", Vector3.new(1.6, 0.05, 1.2), CFrame.new(x, FLOOR_TOP + 0.03, z) * CFrame.Angles(0, yaw, 0), ({ C.lonaAzul, C.grafiti, C.mostaza })[rng:NextInteger(1, 3)], Enum.Material.Fabric))
		end
	end

	-- Rincón de los sobrevivientes: colchón, manta, mochila, linterna y garrafones de agua (muro este, al fondo)
	do
		local at = Vector3.new(40.5, 0, -383.5)
		deco(block(folder, "Colchon", Vector3.new(3.6, 0.8, 6.6), at + Vector3.new(0, 0.4, 0), Color3.fromRGB(210, 196, 160), Enum.Material.Fabric))
		deco(block(folder, "Manta", Vector3.new(3.7, 0.25, 4), at + Vector3.new(0, 0.9, 1), C.lonaAzul, Enum.Material.Fabric))
		deco(block(folder, "Almohada", Vector3.new(2, 0.5, 1.2), at + Vector3.new(0, 1, -2.6), C.blanco, Enum.Material.Fabric))
		deco(block(folder, "Mochila", Vector3.new(1.6, 2, 1.1), at + Vector3.new(-3.4, 1, -2), C.lonaVerde, Enum.Material.Fabric))
		deco(pole(folder, "Linterna", at + Vector3.new(-3, 0, 1.6), 1.2, 0.7, C.mostaza, Enum.Material.Metal))
		for i = 1, 2 do
			deco(pole(folder, "Garrafon", at + Vector3.new(2.6 + i * 0.1, 0, -2.8 + i * 1.6), 2.4, 1.6, Color3.fromRGB(110, 170, 220), Enum.Material.Glass)).Transparency = 0.45
		end
	end

	-- Extintor en una pilastra
	deco(pole(folder, "Extintor", Vector3.new(-11, 0, -394.2), 3, 0.9, RHO_RED, Enum.Material.Metal))
	deco(block(folder, "ExtintorBoquilla", Vector3.new(0.3, 0.4, 0.4), Vector3.new(-11, 3.2, -394.2), C.oscuro))

	-- Carro abandonado (modelo propio) sobre el puesto marcado
	placeModel(folder, CarroAbandonado, Vector3.new(30, FLOOR_TOP, -366), math.rad(90), LOBBY_SOLID).Name = "CarroAbandonado"
end

local function buildLobby(map, refs)
	local wall = C.blanco
	slab(map, "LobbyFondo", -60, 60, -400, -395, 20, wall)
	-- Pared oeste con la puerta del Callejón (12 × 14, z -380..-368)
	slab(map, "LobbyLadoW", -60, -45, -395, -380, 20, wall)
	slab(map, "LobbyLadoW", -60, -45, -368, -355, 20, wall)
	block(map, "LobbyDintelW", Vector3.new(15, 6, 12), Vector3.new(-52.5, 17, -374), wall)
	floor(map, "LobbyPisoW", -60, -45, -380, -368, C.concreto)
	-- Pared este con la puerta de la Escalera (simétrica a la oeste)
	slab(map, "LobbyLadoE", 45, 60, -395, -380, 20, wall)
	slab(map, "LobbyLadoE", 45, 60, -368, -355, 20, wall)
	block(map, "LobbyDintelE", Vector3.new(15, 6, 12), Vector3.new(52.5, 17, -374), wall)
	floor(map, "LobbyPisoE", 45, 60, -380, -368, C.concreto)
	slab(map, "LobbyFrenteW", -60, -15, -355, -350, 20, wall)
	slab(map, "LobbyFrenteE", 15, 60, -355, -350, 20, wall)
	block(map, "LobbyDintel", Vector3.new(30, 6, 5), Vector3.new(0, 17, -352.5), wall)
	block(map, "LobbyTecho", Vector3.new(120, 1, 50), Vector3.new(0, 20.5, -375), C.oxido, Enum.Material.CorrodedMetal)
	floor(map, "LobbyPiso", -45, 45, -395, -350, C.concreto) -- incluye el vano de la puerta (la Baseplate no llega hasta aquí)

	-- Franja baja de terracota en las paredes interiores
	for _, strip in {
		{ Vector3.new(90, 3, 0.2), Vector3.new(0, 1.5, -394.9) },
		{ Vector3.new(0.2, 3, 15), Vector3.new(-44.9, 1.5, -387.5) },
		{ Vector3.new(0.2, 3, 13), Vector3.new(-44.9, 1.5, -361.5) },
		{ Vector3.new(0.2, 3, 15), Vector3.new(44.9, 1.5, -387.5) },
		{ Vector3.new(0.2, 3, 13), Vector3.new(44.9, 1.5, -361.5) },
		{ Vector3.new(30, 3, 0.2), Vector3.new(-30, 1.5, -355.1) },
		{ Vector3.new(30, 3, 0.2), Vector3.new(30, 1.5, -355.1) },
	} do
		deco(block(map, "FranjaTerracota", strip[1], strip[2], C.terracota))
	end

	-- Puerta enrollable de 30 × 14 hacia la calle
	refs.lobbyDoor = door(map, "LobbyDoor", -351, 30, 14)
	refs.lobbyDoor.Material = Enum.Material.CorrodedMetal
	local westDoor = block(map, "LobbyDoorW", Vector3.new(2, 14, 12), Vector3.new(-46, 7, -374), Color3.fromRGB(150, 110, 60), Enum.Material.CorrodedMetal)
	local eastDoor = block(map, "LobbyDoorE", Vector3.new(2, 14, 12), Vector3.new(46, 7, -374), Color3.fromRGB(150, 110, 60), Enum.Material.CorrodedMetal)
	refs.extraLobbyDoors = { westDoor, eastDoor }
	refs.lobbySpawn = CFrame.lookAt(Vector3.new(0, 3, -375), Vector3.new(0, 3, -350))

	-- Foco colgado (luz cálida)
	local bulb = deco(block(map, "Foco", Vector3.new(1, 1, 1), Vector3.new(0, 17, -375), Color3.fromRGB(255, 220, 160), Enum.Material.Neon))
	deco(block(map, "FocoCable", Vector3.new(0.1, 3, 0.1), Vector3.new(0, 18.5, -375), C.oscuro))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 140)
	light.Range = 50
	light.Brightness = 2
	light.Shadows = true
	light.Parent = bulb
	CollectionService:AddTag(bulb, "NightLamp") -- de noche parpadea (client/NightLights)
	bulb:SetAttribute("Flicker", true)

	-- Cartel de la ruta sobre la puerta (se ve desde dentro) y flecha en la calle
	routeSign(map, "CartelCalle", CFrame.new(0, 17, -355.4), Vector3.new(12, 5, 0.4), "02", "↑ CALLE", RHO_RED)
	routeSign(map, "CartelCallejon", CFrame.new(-44.7, 17, -374) * CFrame.Angles(0, -math.pi / 2, 0), Vector3.new(12, 5, 0.4), "01", "↑ CALLEJÓN", RHO_YELLOW)
	routeSign(map, "CartelEscalera", CFrame.new(44.7, 17, -374) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(12, 5, 0.4), "03", "↑ ESCALERA", RHO_BLUE)

	-- Radio sobre una mesa, llantas, bidones y cajas (el carro y los detalles van en lobbyDetails)
	block(map, "Mesa", Vector3.new(6, 3, 3), Vector3.new(-32, 1.5, -391), C.madera, Enum.Material.Wood)
	deco(block(map, "RadioVieja", Vector3.new(2.4, 1.4, 1.2), Vector3.new(-32, 3.7, -391), C.oscuro, Enum.Material.Metal))
	deco(block(map, "RadioAntena", Vector3.new(0.1, 2, 0.1), Vector3.new(-31.2, 5.4, -391), C.concreto))
	for i = 0, 2 do
		local tire = block(map, "Llanta", Vector3.new(1.2, 3, 3), CFrame.new(-38, 0.6 + i * 1.2, -362) * CFrame.Angles(0, 0, math.pi / 2), C.oscuro, Enum.Material.Rubber)
		tire.Shape = Enum.PartType.Cylinder
	end
	barrel(map, 38, -391, C.lonaAzul)
	barrel(map, 41, -389)
	crates(map, -38, -386)
	lobbyDetails(map, Random.new(11))
end

-- Parte 3: tramo 1, ruta Calle (roja). Calle de 60 (x -30..30) con aceras de 5 y fachadas hasta x = ±60.
local function buildStreet(map, refs, rng)
	floor(map, "Asfalto", -30, 30, -350, -150, C.asfalto, Enum.Material.Asphalt)
	floor(map, "Asfalto", -20, 20, -150, -130, C.asfalto, Enum.Material.Asphalt)
	floor(map, "AceraW", -35, -30, -350, -150, C.acera)
	floor(map, "AceraE", 30, 35, -350, -150, C.acera)

	-- Línea central amarilla gastada
	for z = -344, -160, 12 do
		if rng:NextNumber() > 0.25 then
			deco(block(map, "Linea", Vector3.new(0.5, 0.05, 5), Vector3.new(0, FLOOR_TOP + 0.03, z), C.mostaza, Enum.Material.SmoothPlastic))
		end
	end

	-- Fachadas a ambos lados, cortadas por los pasajes de cruce (nichos de 8 × 12 que acaban en muro)
	for _, side in { -1, 1 } do
		local faceX = 35 * side
		local x1, x2 = math.min(35 * side, 60 * side), math.max(35 * side, 60 * side)
		local stripeColor = side == -1 and C.amarillo or C.azul -- marcan las otras rutas
		local edges = { -350 }
		for _, z in CROSSINGS do
			table.insert(edges, z - 4)
			table.insert(edges, z + 4)
		end
		table.insert(edges, -150)

		for i = 1, #edges, 2 do
			local segStart, segEnd = edges[i], edges[i + 1]
			-- Casas pegadas de 12 a 22 de largo
			local z = segStart
			while z < segEnd do
				local length = math.min(rng:NextInteger(12, 22), segEnd - z)
				if segEnd - (z + length) < 8 then
					length = segEnd - z -- sin trozos pequeños al final
				end
				local height = rng:NextNumber() < 0.35 and 26 or 17
				building(map, rng, x1, x2, z, z + length, height, faceX, -side)
				z += length
			end
			-- Franja de la otra ruta a 6 de alto y esquinas rojas a 3 de alto
			if SHOW.routeStripes then
				deco(block(map, "Franja", Vector3.new(0.3, 1, segEnd - segStart), Vector3.new(faceX - side * 0.2, 6, (segStart + segEnd) / 2), stripeColor, Enum.Material.SmoothPlastic))
			end
			for _, cornerZ in { segStart + 2, segEnd - 2 } do
				deco(block(map, "EsquinaRoja", Vector3.new(0.3, 1, 4), Vector3.new(faceX - side * 0.2, 3, cornerZ), C.rojo, Enum.Material.SmoothPlastic))
			end
		end

		-- Pasajes de cruce abiertos: al oeste hacia el Callejón y al este hacia la Escalera
		for _, z in CROSSINGS do
			if side == -1 then
				floor(map, "PasajePiso", -60, -35, z - 4, z + 4, C.acera)
				floorArrow(map, Vector3.new(-40, 0, z), C.amarillo, -math.pi / 2)
				routeSign(map, "CartelCallejon", CFrame.new(-34.5, 9, z + 9) * CFrame.Angles(0, -math.pi / 2, 0), Vector3.new(8, 3.2, 0.4), "01", "← CALLEJÓN", RHO_YELLOW)
			else
				floor(map, "PasajePiso", 35, 60, z - 4, z + 4, C.acera)
				floorArrow(map, Vector3.new(40, 0, z), C.azul, math.pi / 2)
				routeSign(map, "CartelEscalera", CFrame.new(34.5, 9, z + 9) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(8, 3.2, 0.4), "03", "ESCALERA →", RHO_BLUE)
			end
		end

		-- Franjas rojas verticales a ambos lados de la entrada de la ruta
		deco(block(map, "EntradaRoja", Vector3.new(0.3, 12, 1.5), Vector3.new(faceX - side * 0.2, 6, -348.5), C.rojo, Enum.Material.SmoothPlastic))

		-- Postes de luz con cables en la acera
		local previous
		for z = -340, -160, 36 do
			local top = Vector3.new(33 * side, 17, z)
			deco(pole(map, "Poste", Vector3.new(33 * side, 0, z), 18, 0.8, C.concreto, Enum.Material.Concrete))
			deco(block(map, "PosteBrazo", Vector3.new(3, 0.3, 0.3), top + Vector3.new(-side * 1.5, 0, 0), C.concreto))
			Atmosphere.bulb(map, top + Vector3.new(-side * 3, -0.4, 0))
			if previous then
				local mid = (previous + top) / 2 - Vector3.new(0, 1, 0)
				deco(block(map, "Cable", Vector3.new(0.12, 0.12, (top - previous).Magnitude), CFrame.lookAt(mid, top), C.oscuro))
			end
			previous = top
		end
	end

	-- Embudo hacia la tienda: la calle se estrecha a 40 (zona de espera exterior de 40 × 20)
	-- El Callejón llega a la zona de espera por un pasaje de 9 (z -148..-139) que cruza el bloque oeste
	slab(map, "EmbudoW", -60, -20, -150, -148, 18, C.salmon)
	slab(map, "EmbudoW", -60, -20, -139, -130, 18, C.salmon)
	floor(map, "PasajeCallejon", -60, -20, -148, -139, C.acera)
	floorArrow(map, Vector3.new(-40, 0, -143.5), C.amarillo, math.pi / 2)
	-- La Escalera llega igual por el bloque este
	slab(map, "EmbudoE", 20, 60, -150, -148, 18, C.turquesa)
	slab(map, "EmbudoE", 20, 60, -139, -130, 18, C.turquesa)
	floor(map, "PasajeEscalera", 20, 60, -148, -139, C.acera)
	floorArrow(map, Vector3.new(40, 0, -143.5), C.azul, -math.pi / 2)
	deco(block(map, "EsquinaRoja", Vector3.new(0.3, 1, 9), Vector3.new(-19.8, 3, -134.5), C.rojo, Enum.Material.SmoothPlastic))
	deco(block(map, "EsquinaRoja", Vector3.new(0.3, 1, 9), Vector3.new(19.8, 3, -134.5), C.rojo, Enum.Material.SmoothPlastic))
	sandbags(map, -12, -138, 0)
	sandbags(map, 13, -141, 90)

	-- Obstáculos (huecos de 10 o más para pasar)
	placeModel(map, CarroAbandonado, Vector3.new(-14, FLOOR_TOP, -325), math.rad(25 + 90), LOBBY_SOLID, C.cobalto).Name = "CarroAbandonado"
	placeModel(map, CarroAbandonado, Vector3.new(17, FLOOR_TOP, -296), math.rad(-15 + 90), LOBBY_SOLID, C.terracota).Name = "CarroAbandonado"

	stall(map, -24, -282, C.lonaAzul)
	crates(map, -22, -300)
	-- Autobús escolar volcado en z = -258: deja un paso de 12 (x -5..7) y otro de 10 junto a la acera este
	busOnSide(map, -35, -258)
	car(map, 13, -258, 90, C.blanco)
	crates(map, 22, -258)
	container(map, -27, -226, 10)
	sandbags(map, 2, -214, 20)
	car(map, -10, -200, 70, C.lima)
	stall(map, 24, -204, C.lonaNaranja)
	car(map, 12, -176, -30, C.terracota)
	barrel(map, -32, -315)
	barrel(map, 32, -268, C.lonaVerde)
	barrel(map, -32, -188)
	-- Poste caído con su cable (decoración)
	deco(block(map, "PosteCaido", Vector3.new(18, 0.8, 0.8), CFrame.new(-18, 0.4, -236) * CFrame.Angles(0, math.rad(35), 0), C.concreto))

	-- Guía: flechas rojas en el suelo
	floorArrow(map, Vector3.new(0, 0, -342), C.rojo)
	floorArrow(map, Vector3.new(0, 0, -275), C.rojo)
	floorArrow(map, Vector3.new(0, 0, -230), C.rojo)
	floorArrow(map, Vector3.new(0, 0, -158), C.rojo)

	-- Estación de munición en la acera este (z = -220), mirando hacia la calle
	if LEGACY_SHOPS then
		local model, hitbox = PropModel.build(CajaMunicion, Vector3.new(31.5, 0, -220), math.rad(90))
		hitbox.Name = "AmmoStation"
		model.Parent = map
		label(hitbox, "AMMO", Color3.fromRGB(80, 165, 255), 18)
		table.insert(refs.ammoStations, { part = hitbox, model = model, prompt = prompt(hitbox, "Buy ammo", 0.5) })
	end

	-- Lugares posibles de la caja de armas de la ruta Calle (libres de obstáculos); una caja por ruta
	if LEGACY_SHOPS then
	table.insert(refs.boxSpots.Zone1, { Vector3.new(0, 0, -286), Vector3.new(-18, 0, -212), Vector3.new(-8, 0, -168) })
	end
end

-- Casa genérica (bloque sólido) con puerta y ventanas en las caras que dan a un lugar transitable.
-- `isOpen(x, z)` dice si ese punto del suelo es transitable.
local function houseBlock(parent, rng, x1, x2, z1, z2, isOpen)
	local height = rng:NextNumber() < 0.35 and 26 or 17
	slab(parent, "Casa", x1, x2, z1, z2, height, HOUSE_COLORS[rng:NextInteger(1, #HOUSE_COLORS)])
	local roof = deco(slab(parent, "Techo", x1, x2, z1, z2, 0.6, ROOF_COLORS[rng:NextInteger(1, 2)], Enum.Material.CorrodedMetal))
	roof.Position += Vector3.new(0, height, 0)

	local anyOpen = false
	for _, face in {
		{ axis = "X", at = x2, dir = 1, a1 = z1, a2 = z2 },
		{ axis = "X", at = x1, dir = -1, a1 = z1, a2 = z2 },
		{ axis = "Z", at = z2, dir = 1, a1 = x1, a2 = x2 },
		{ axis = "Z", at = z1, dir = -1, a1 = x1, a2 = x2 },
	} do
		local length = face.a2 - face.a1
		-- Pieza pegada a la fachada: `t` = posición a lo largo de la cara
		local function facePart(name, t, y, width, tall, color, material)
			local size = face.axis == "X" and Vector3.new(0.3, tall, width) or Vector3.new(width, tall, 0.3)
			local out = face.at + face.dir * 0.15
			local position = face.axis == "X" and Vector3.new(out, y, t) or Vector3.new(t, y, out)
			deco(block(parent, name, size, position, color, material))
		end
		local function outside(t)
			if face.axis == "X" then
				return isOpen(face.at + face.dir * 0.5, t)
			end
			return isOpen(t, face.at + face.dir * 0.5)
		end
		if length >= 6 and (outside(face.a1 + length * 0.25) or outside(face.a1 + length * 0.5) or outside(face.a1 + length * 0.75)) then
			anyOpen = true
			local doorT = face.a1 + rng:NextInteger(3, math.max(3, math.floor(length) - 3))
			facePart("Puerta", doorT, 3.5, 4, 7, C.oscuro, Enum.Material.Wood)
			for level = 1, height >= 24 and 3 or 2 do
				local t = face.a1 + 3
				while t <= face.a2 - 3 do
					if level > 1 or math.abs(t - doorT) > 4 then
						facePart("Ventana", t, 4.5 + (level - 1) * 8, 3, 3, C.oscuro, Enum.Material.Glass)
					end
					t += 8
				end
			end
		end
	end

	if anyOpen and rng:NextNumber() < 0.3 then
		deco(pole(parent, "TanqueAgua", Vector3.new((x1 + x2) / 2, height + 0.6, (z1 + z2) / 2), 4, 4, C.cobalto, Enum.Material.Plastic))
	end
end

-- Montón de latas sueltas: se recoge con E (CanPiles). Devuelve el modelo y su prompt.
local function canPile(parent, position)
	local model = Instance.new("Model")
	model.Name = "Latas"
	deco(block(model, "LatasCaja", Vector3.new(2.6, 1.2, 2.6), position + Vector3.new(0, 0.6, 0), C.madera, Enum.Material.WoodPlanks))
	local colors = { C.rojo, C.lima, C.lonaNaranja, C.azul, C.mostaza }
	for i, color in colors do
		local angle = i * math.pi * 2 / #colors
		deco(pole(model, "Lata", position + Vector3.new(math.cos(angle) * 0.75, 1.2, math.sin(angle) * 0.75), 1, 0.7, color))
	end
	deco(pole(model, "Lata", position + Vector3.new(0, 2.2, 0), 1, 0.7, C.concreto))
	local hitbox = deco(block(model, "Hitbox", Vector3.new(3, 3, 3), position + Vector3.new(0, 1.5, 0)))
	hitbox.Transparency = 1
	label(hitbox, "CANS", C.mostaza, 16)
	model.Parent = parent
	return model, prompt(hitbox, "Pick up cans", 0.5)
end

-- Botiquín que se recoge con E (server/Medkits). `position` es el centro de la base (sobre una mesa o el suelo).
local function medkitPickup(parent, position)
	local model = Instance.new("Model")
	model.Name = "Botiquin"
	local box = deco(block(model, "BotiquinCaja", Vector3.new(1.6, 1, 1.2), position + Vector3.new(0, 0.5, 0), C.blanco, Enum.Material.SmoothPlastic))
	deco(block(model, "BotiquinCruz", Vector3.new(1.62, 0.25, 0.7), box.Position, C.rojo, Enum.Material.SmoothPlastic))
	deco(block(model, "BotiquinCruz", Vector3.new(1.62, 0.7, 0.25), box.Position, C.rojo, Enum.Material.SmoothPlastic))
	local hitbox = deco(block(model, "Hitbox", Vector3.new(2.5, 2.5, 2.5), position + Vector3.new(0, 1, 0)))
	hitbox.Transparency = 1
	label(hitbox, "MEDKIT", C.rojo, 14)
	model.Parent = parent
	return model, prompt(hitbox, "Take medkit", 0.3)
end

-- Parte 4: tramo 1, ruta Callejón (amarilla). Franja de x -120 a -60, entre el borde del mapa y las casas de la calle.
-- El trazado son rectángulos transitables { nombre, x1, x2, z1, z2 }; el resto de la franja se rellena con casas.
-- Recorrido: puerta oeste del lobby -> patio -> plazoleta 1 -> plazoleta 2 -> cruce 2 -> plazoleta 3 -> embudo de la tienda.
-- Los fondos de los callejones laterales (S1, S2, S3) son los puntos de aparición.
local ALLEY = {
	{ "Patio", -86, -60, -382, -366 },
	{ "A1", -77, -68, -366, -306 },
	{ "C1", -68, -60, -314, -306 }, -- cruce 1 hacia la calle
	{ "P1", -88, -68, -306, -286 }, -- plazoleta 1
	{ "L1", -97, -88, -298, -289 },
	{ "A2", -106, -97, -320, -246 }, -- de z -320 a -298 era el callejón lateral S1: ahora entra a la Tienda 1
	{ "T1", -115, -97, -346, -298 }, -- la Tienda del tramo 1 (buildShop)
	{ "P2", -106, -86, -246, -226 }, -- plazoleta 2
	{ "C2", -86, -60, -244, -236 }, -- cruce 2 hacia la calle (también es parte del recorrido)
	{ "S2", -106, -97, -226, -206 }, -- callejón lateral S2
	{ "A3", -77, -68, -236, -180 },
	{ "P3", -88, -68, -180, -160 }, -- plazoleta 3
	{ "C3", -68, -60, -174, -166 }, -- cruce 3 hacia la calle
	{ "S3", -106, -88, -176, -168 }, -- callejón lateral S3
	{ "A4", -77, -68, -160, -148 },
	{ "E", -77, -60, -148, -139 }, -- salida hacia el embudo de la tienda
}
local ALLEY_BAND = { x1 = -120, x2 = -60, z1 = -400, z2 = -130 }
local PLAZAS = { P1 = true, P2 = true, P3 = true }

local function inRects(list, x, z)
	for _, r in list do
		if x > r[2] and x < r[3] and z > r[4] and z < r[5] then
			return true
		end
	end
	return false
end

-- Rellena una franja del mapa con casas: todo lo que no es transitable (`walkable`) se agrupa en rectángulos de
-- celdas de 1 stud, de mayor a menor, y se parte en casas. `isOpen(x, z)` decide en qué caras van puertas y ventanas.
local function fillHouses(map, rng, band, walkable, isOpen)
	local width, depth = band.x2 - band.x1, band.z2 - band.z1
	local used = {}
	local function solid(i, j)
		return not used[i * 1000 + j] and not inRects(walkable, band.x1 + i - 0.5, band.z1 + j - 0.5)
	end
	for j = 1, depth do
		for i = 1, width do
			if solid(i, j) then
				local i2 = i
				while i2 < width and solid(i2 + 1, j) do
					i2 += 1
				end
				local j2 = j
				while j2 < depth do
					local rowSolid = true
					for k = i, i2 do
						if not solid(k, j2 + 1) then
							rowSolid = false
							break
						end
					end
					if not rowSolid then
						break
					end
					j2 += 1
				end
				for a = i, i2 do
					for b = j, j2 do
						used[a * 1000 + b] = true
					end
				end
				-- Partir en casas de 12 a 22 de largo y como mucho 22 de fondo
				local x1, x2 = band.x1 + i - 1, band.x1 + i2
				local z1, z2 = band.z1 + j - 1, band.z1 + j2
				local columns = math.ceil((x2 - x1) / 22)
				local z = z1
				while z < z2 do
					local length = math.min(rng:NextInteger(12, 22), z2 - z)
					if z2 - (z + length) < 8 then
						length = z2 - z
					end
					for c = 0, columns - 1 do
						local cx1 = x1 + (x2 - x1) * c / columns
						local cx2 = x1 + (x2 - x1) * (c + 1) / columns
						houseBlock(map, rng, cx1, cx2, z, z + length, isOpen)
					end
					z += length
				end
			end
		end
	end

end

---------------------------------------------------------------------------------------------------
-- La Tienda: un rincón (callejón sin salida o patio) donde se junta todo lo que se paga con latas: la caja de armas, la estación de
-- munición y objetos y la vitrina de la farmacia, bajo un cartel grande que dice TIENDA. Hay una por tramo.
-- `cfg.origin` = centro de la entrada (en el suelo), `cfg.forward` = hacia dónde se entra (un eje), `cfg.width` el ancho, `cfg.depth`
-- el fondo y `cfg.zone` la zona de la caja ("Zone1".."Zone3"). Las coordenadas locales son (u a la derecha, v hacia dentro).
local SHOP_FLOOR = Color3.fromRGB(176, 150, 112)
local SHOP_FLOOR_DARK = Color3.fromRGB(104, 84, 60)
local SHOP_GOLD = Color3.fromRGB(246, 196, 58)
local SHOP_WARM = Color3.fromRGB(255, 205, 140)
local SHOP_BULB = Color3.fromRGB(170, 124, 78) -- el neón de los focos va apagado: la luz de la tienda es tenue

local function yawFacing(direction)
	return math.atan2(-direction.X, -direction.Z)
end

local function shopAwning(map, base, u, v, width, depth, color)
	local function at(du, dv, y)
		return base * CFrame.new(u + du, y, -(v + dv))
	end
	for _, corner in { { -width / 2, -depth / 2 }, { width / 2, -depth / 2 }, { -width / 2, depth / 2 }, { width / 2, depth / 2 } } do
		deco(pole(map, "ToldoPalo", at(corner[1], corner[2], 0).Position, 10, 0.4, C.madera, Enum.Material.Wood))
	end
	-- Toldo a rayas (lona de dos colores) un poco inclinado hacia el frente
	local slats = 6
	for i = 1, slats do
		local du = -width / 2 + (i - 0.5) * width / slats
		deco(block(map, "ToldoLona", Vector3.new(width / slats, 0.35, depth + 1.2), at(du, 0, 10.3) * CFrame.Angles(math.rad(5), 0, 0), i % 2 == 0 and C.blanco or color, Enum.Material.Fabric))
	end
	-- Bombillo cálido bajo el toldo
	local bulb = deco(block(map, "ToldoFoco", Vector3.new(0.6, 0.6, 0.6), at(0, 0, 9.4), SHOP_BULB, Enum.Material.Neon))
	bulb.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = SHOP_WARM
	light.Brightness = 0.28
	light.Range = 12
	light.Parent = bulb
end

local function buildShop(map, refs, cfg)
	local f = cfg.forward
	local right = Vector3.new(-f.Z, 0, f.X)
	local W, D = cfg.width, cfg.depth
	local base = CFrame.lookAt(cfg.origin, cfg.origin + f)
	local function at(u, v, y)
		return base * CFrame.new(u, y or 0, -v)
	end
	local folder = Instance.new("Folder")
	folder.Name = "Tienda"
	folder.Parent = map

	-- Piso: baldosas cálidas con borde oscuro y una alfombra roja al centro que lleva a la caja
	deco(block(folder, "TiendaPiso", Vector3.new(W, 0.1, D), at(0, D / 2, FLOOR_TOP + 0.08), SHOP_FLOOR, Enum.Material.Slate))
	for _, side in { -1, 1 } do
		deco(block(folder, "TiendaBorde", Vector3.new(0.8, 0.12, D), at(side * (W / 2 - 0.4), D / 2, FLOOR_TOP + 0.09), SHOP_FLOOR_DARK, Enum.Material.Slate))
	end
	deco(block(folder, "TiendaBorde", Vector3.new(W, 0.12, 0.8), at(0, D - 0.4, FLOOR_TOP + 0.09), SHOP_FLOOR_DARK, Enum.Material.Slate))
	deco(block(folder, "TiendaAlfombra", Vector3.new(4, 0.12, D - 6), at(0, (D - 6) / 2 + 1, FLOOR_TOP + 0.1), C.rojo, Enum.Material.Fabric))

	-- Pórtico de entrada con el cartel TIENDA
	local gantryHeight = 14
	for _, side in { -1, 1 } do
		deco(pole(folder, "PorticoPoste", at(side * (W / 2 - 0.8), 0.6).Position, gantryHeight, 0.9, C.concreto, Enum.Material.Concrete))
	end
	deco(block(folder, "PorticoViga", Vector3.new(W, 0.9, 0.9), at(0, 0.6, gantryHeight), C.concreto, Enum.Material.Concrete))
	local signWidth = cfg.signWidth or math.min(W - 2, 18)
	local signU = cfg.signU or 0 -- desplazamiento lateral del cartel (para centrarlo sobre la boca de la entrada)
	local signSize = Vector3.new(signWidth, signWidth * 0.3, 0.4)
	local signPosition = at(signU, 0.55, gantryHeight - signSize.Y / 2 - 0.5).Position
	local _, gui = blankBoard(folder, "CartelTienda", signSize, CFrame.lookAt(signPosition, signPosition - f), RHO_BLACK, 55)
	boardRect(gui, 0.025, 0.07, 0.95, 0.86, SHOP_GOLD)
	boardText(gui, "TIENDA", 0.06, 0.07, 0.88, 0.62, RHO_BLACK, Enum.TextXAlignment.Center)
	boardRect(gui, 0.06, 0.72, 0.88, 0.012, RHO_BLACK)
	boardText(gui, "WEAPONS  ·  AMMO  ·  PHARMACY", 0.06, 0.745, 0.88, 0.17, RHO_BLACK, Enum.TextXAlignment.Center)
	for _, side in { -1, 1 } do
		deco(block(folder, "CartelCadena", Vector3.new(0.15, 1.6, 0.15), at(signU + side * (signWidth / 2 - 1), 0.6, gantryHeight - 0.8), C.oscuro, Enum.Material.Metal))
	end

	-- Guirnaldas de focos de pared a pared
	for _, v in { D * 0.3, D * 0.68 } do
		for _, side in { -1, 1 } do
			deco(pole(folder, "GuirnaldaPoste", at(side * (W / 2 - 0.3), v).Position, 11, 0.3, C.concreto))
		end
		local count = math.max(6, math.floor(W / 3))
		for i = 0, count do
			local u = -W / 2 + 0.3 + (W - 0.6) * i / count
			local sag = math.sin(i / count * math.pi) * 1.3
			local bulb = deco(block(folder, "GuirnaldaFoco", Vector3.new(0.5, 0.5, 0.5), at(u, v, 10.8 - sag), SHOP_BULB, Enum.Material.Neon))
			bulb.Shape = Enum.PartType.Ball
		end
		local lamp = deco(block(folder, "GuirnaldaLuz", Vector3.one * 0.5, at(0, v, 10.5)))
		lamp.Transparency = 1
		local light = Instance.new("PointLight")
		light.Color = SHOP_WARM
		light.Brightness = 0.3
		light.Range = 18
		light.Parent = lamp
	end

	-- Centro de la Tienda: la guía de pantalla la señala (GameState publica Workspace.ShopPos en cada zona)
	refs.shopPositions = refs.shopPositions or {}
	refs.shopPositions[cfg.zone] = at(0, D / 2).Position

	-- Caja de armas al fondo, mirando a la entrada, sobre una tarima
	local boxCenter = at(0, D - 4)
	deco(block(folder, "TarimaCaja", Vector3.new(9, 0.5, 6), boxCenter * CFrame.new(0, 0.25, 0), C.madera, Enum.Material.WoodPlanks))
	local boxPosition = (boxCenter * CFrame.new(0, 0.5, 0)).Position
	refs.boxSpots[cfg.zone] = { { CFrame.new(boxPosition) * CFrame.Angles(0, yawFacing(-f), 0) } }
	shopAwning(folder, base, 0, D - 4, 11, 8, C.lonaNaranja)

	-- Estación de munición y objetos en la pared derecha, mirando al centro
	local stationAt = at(W / 2 - 3.2, D * 0.42)
	local model, hitbox = PropModel.build(CajaMunicion, stationAt.Position, yawFacing(-right))
	hitbox.Name = "AmmoStation"
	model.Parent = folder
	label(hitbox, "AMMO AND ITEMS", Color3.fromRGB(80, 165, 255), 22)
	table.insert(refs.ammoStations, { part = hitbox, model = model, prompt = prompt(hitbox, "Buy ammo", 0.5) })
	shopAwning(folder, base, W / 2 - 3.6, D * 0.42, 6, 7, C.lonaAzul)

	-- Vitrina de la farmacia en la pared izquierda, mirando al centro (separada de la pared para que se vea de frente)
	local pharmacyYaw = yawFacing(right)
	local pharmacyCenter = at(-(W / 2 - 5.4), D * 0.42).Position
	local centerOffset = CFrame.Angles(0, pharmacyYaw, 0) * Vector3.new(0.245, 0, 0.67) -- el centro del modelo no es su origen
	table.insert(refs.pharmacySpots, { pharmacyCenter - centerOffset, math.deg(pharmacyYaw) })
	shopAwning(folder, base, -(W / 2 - 5.4), D * 0.42, 6, 9, C.lonaVerde)

	-- Cajas y barriles contra las paredes del fondo, sin tapar el paso ni la caja de armas
	for _, side in { -1, 1 } do
		local crate = at(side * (W / 2 - 1.8), D - 1.8)
		block(folder, "CajaTienda", Vector3.new(3, 3, 3), crate * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(side * 12), 0), C.madera, Enum.Material.WoodPlanks)
		block(folder, "CajaTienda", Vector3.new(2, 2, 2), crate * CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(-side * 20), 0), C.madera, Enum.Material.WoodPlanks)
		local drum = at(side * (W / 2 - 1.5), D * 0.78).Position
		barrel(folder, drum.X, drum.Z, side == 1 and C.lonaVerde or C.oxido)
	end
	return folder
end

local function buildAlley(map, refs, rng, spawns)
	local rects = {}
	for _, r in ALLEY do
		rects[r[1]] = r
	end
	-- Lugares transitables vecinos fuera de la franja (pasajes de la calle y puerta del lobby), para las fachadas
	local neighbors = { { "Puerta", -60, -45, -380, -368 }, { "Embudo", -60, -20, -148, -139 } }
	for _, z in CROSSINGS do
		table.insert(neighbors, { "Cruce", -60, -35, z - 4, z + 4 })
	end
	local function isOpen(x, z)
		return inRects(ALLEY, x, z) or inRects(neighbors, x, z)
	end

	-- Pisos
	for _, r in ALLEY do
		local plaza = PLAZAS[r[1]]
		local color = plaza and Color3.fromRGB(150, 140, 125) or C.acera
		floor(map, "Piso" .. r[1], r[2], r[3], r[4], r[5], color, plaza and Enum.Material.Cobblestone or Enum.Material.Concrete)
	end

	-- Relleno de casas
	fillHouses(map, rng, ALLEY_BAND, ALLEY, isOpen)

	-- La Tienda del tramo 1: el callejón lateral del fondo, con la caja de armas, la munición y la vitrina
	buildShop(map, refs, { origin = Vector3.new(-106, 0, -300), forward = Vector3.new(0, 0, -1), width = 18, depth = 44, zone = "Zone1", signU = 4.5, signWidth = 12 })

	-- Franjas amarillas en las paredes del recorrido
	for _, stripe in {
		{ Vector3.new(0.3, 1, 60), Vector3.new(-76.85, 6, -336) }, -- A1, pared oeste
		{ Vector3.new(0.3, 1, 43), Vector3.new(-97.15, 6, -267.5) }, -- A2, pared este
		{ Vector3.new(0.3, 1, 56), Vector3.new(-76.85, 6, -208) }, -- A3, pared oeste
	} do
		if SHOW.routeStripes then
			deco(block(map, "FranjaAmarilla", stripe[1], stripe[2], C.amarillo, Enum.Material.SmoothPlastic))
		end
	end

	-- Murales con frases en español (en las paredes de las plazoletas)
	sign(map, "Mural", "ESPERANZA", Vector3.new(16, 7, 0.4), Vector3.new(-78, 8, -286.3), C.grafiti, C.blanco)
	sign(map, "Mural", "AQUÍ VIVE GENTE", Vector3.new(14, 7, 0.4), CFrame.new(-105.7, 8, -236) * CFrame.Angles(0, -math.pi / 2, 0), C.turquesa, C.blanco)
	sign(map, "Mural", "NADIE SE QUEDA ATRÁS", Vector3.new(10, 5, 0.4), Vector3.new(-82.5, 10, -160.3), C.mostaza, C.oscuro)

	-- Flechas amarillas del recorrido y rojas en los cruces hacia la calle
	for _, arrow in {
		{ -64, -374, -math.pi / 2 },
		{ -72.5, -358, 0 },
		{ -72.5, -330, 0 },
		{ -93, -293.5, -math.pi / 2 },
		{ -101.5, -265, 0 },
		{ -82, -240, math.pi / 2 },
		{ -72.5, -222, 0 },
		{ -72.5, -154, 0 },
		{ -66, -143.5, math.pi / 2 },
	} do
		floorArrow(map, Vector3.new(arrow[1], 0, arrow[2]), C.amarillo, arrow[3])
	end
	floorArrow(map, Vector3.new(-64, 0, -310), C.rojo, math.pi / 2)
	floorArrow(map, Vector3.new(-64, 0, -170), C.rojo, math.pi / 2)

	-- Tendederos que cruzan de lado a lado a 9 de alto
	for _, line in { { -72.5, -340, 9 }, { -101.5, -272, 9 }, { -72.5, -205, 9 }, { -73, -377, 26 } } do
		local x, z, length = line[1], line[2], line[3]
		deco(block(map, "Tendedero", Vector3.new(length, 0.1, 0.1), Vector3.new(x, 9, z), C.blanco))
		for i, cloth in { C.lonaAzul, C.grafiti, C.mostaza, C.lima } do
			deco(block(map, "Ropa", Vector3.new(1.6, 2, 0.1), Vector3.new(x - length / 2 + i * length / 5, 8, z), cloth, Enum.Material.Fabric))
		end
	end

	-- Lámparas de pared (de noche son las únicas luces del callejón; algunas parpadean o están rotas)
	for _, lamp in { { -76.4, -345 }, { -68.4, -296 }, { -105.6, -280 }, { -86.4, -230 }, { -76.4, -215 }, { -87.6, -163 }, { -68.4, -152 } } do
		Atmosphere.bulb(map, Vector3.new(lamp[1], 11, lamp[2]))
	end

	-- Cobertura baja y detalles (el paso nunca queda en menos de 6)
	barrel(map, -76, -350)
	barrel(map, -69, -222, C.lonaVerde)
	barrel(map, -105, -262, C.lonaAzul)
	block(map, "Caja", Vector3.new(3, 3, 3), Vector3.new(-83, 1.5, -379), C.madera, Enum.Material.WoodPlanks)
	sandbags(map, -71, -298, 0)
	sandbags(map, -96, -238, 90)
	sandbags(map, -80, -171, 0)
	for _, moto in { { -70.5, -328, 80 }, { -103, -243, 20 } } do
		local cf = CFrame.new(moto[1], 0.6, moto[2]) * CFrame.Angles(0, math.rad(moto[3]), 0)
		deco(block(map, "Moto", Vector3.new(1.8, 1.2, 5.5), cf, C.rojo, Enum.Material.Metal))
	end

	-- Puntos de aparición al fondo de los callejones laterales
	local S1, S2, S3 = Vector3.new(-72.5, 0, -336), Vector3.new(-101.5, 0, -209), Vector3.new(-104, 0, -172) -- S1 ahora está en el callejón de entrada (el fondo es la Tienda)
	for _, point in { S2, S3 } do
		marker(spawns, point)
	end

	-- Emboscadas: al entrar por primera vez en cada plazoleta salen zombies del callejón lateral más cercano
	local ambushPoints = {
		P1 = { S1, Vector3.new(-101.5, 0, -262) },
		P2 = { S2, Vector3.new(-72.5, 0, -200) },
		P3 = { S3, Vector3.new(-72.5, 0, -200) },
	}
	for name, points in ambushPoints do
		local r = rects[name]
		table.insert(refs.ambushes, { volume = volume(map, "Emboscada" .. name, r[2], r[3], r[4], r[5], 12), points = points })
	end

	-- Latas sueltas (una por plazoleta) y caja de armas (en una de las plazoletas, al azar)
	for _, position in { Vector3.new(-85, 0, -289), Vector3.new(-104, 0, -236), Vector3.new(-80, 0, -178) } do
		local model, pilePrompt = canPile(map, position)
		table.insert(refs.canPiles, { model = model, prompt = pilePrompt })
	end
	if LEGACY_SHOPS then
	table.insert(refs.boxSpots.Zone1, { Vector3.new(-78, 0, -290), Vector3.new(-92, 0, -230), Vector3.new(-83, 0, -164) })
	end
end

-- Altura (segunda pasada, solo ruta Escalera): azoteas de 10 de alto junto a los pasillos azules, a las que se sube por
-- rampas de cuña de unos 22° (no se tocan los pasillos de abajo: son un desvío opcional con ventaja de tiro y recompensa).
local ROOF_HEIGHT = 10

-- Rampa de cuña azul de x1..x2, z1..z2; `upAtZ2` = lo alto queda en z2 (si no, en z1)
local function ramp(map, x1, x2, z1, z2, upAtZ2)
	local wedge = Instance.new("WedgePart")
	wedge.Name = "Rampa"
	wedge.Anchored = true
	wedge.Size = Vector3.new(x2 - x1, ROOF_HEIGHT, z2 - z1)
	local center = Vector3.new((x1 + x2) / 2, ROOF_HEIGHT / 2, (z1 + z2) / 2)
	wedge.CFrame = upAtZ2 and CFrame.new(center) or CFrame.new(center) * CFrame.Angles(0, math.pi, 0)
	wedge.Color = C.azul
	wedge.Material = Enum.Material.SmoothPlastic
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	wedge.Parent = map
	-- Franjas blancas pintadas sobre la pendiente, como las escalinatas del barrio
	local length = z2 - z1
	local angle = math.atan(ROOF_HEIGHT / length)
	for t = 1, length - 2, 3 do
		local along = upAtZ2 and z1 + t + 0.6 or z2 - t - 0.6
		local height = ROOF_HEIGHT * (t + 0.6) / length
		deco(block(map, "RampaFranja", Vector3.new(x2 - x1 - 0.4, 0.1, 1.3 / math.cos(angle)), CFrame.new((x1 + x2) / 2, height + 0.06, along) * CFrame.Angles(upAtZ2 and -angle or angle, 0, 0), C.blanco, Enum.Material.SmoothPlastic))
	end
	return wedge
end

-- Azotea: bloque macizo de ROOF_HEIGHT con parapeto de 3 en el borde este, un farol y un tanque de agua
local function azotea(map, x1, x2, z1, z2)
	slab(map, "Azotea", x1, x2, z1, z2, ROOF_HEIGHT, C.concreto)
	block(map, "Parapeto", Vector3.new(0.6, 3, z2 - z1), Vector3.new(x2 - 0.3, ROOF_HEIGHT + 1.5, (z1 + z2) / 2), C.concreto)
	deco(pole(map, "FarolAzotea", Vector3.new(x2 - 2, ROOF_HEIGHT, z1 + 2), 9, 0.5, C.oscuro))
	Atmosphere.bulb(map, Vector3.new(x2 - 2, ROOF_HEIGHT + 9.3, z1 + 2))
	deco(pole(map, "TanqueAgua", Vector3.new(x2 - 3, ROOF_HEIGHT, z2 - 3), 4, 3.5, C.cobalto, Enum.Material.Plastic))
end

-- Parte 5: tramo 1, ruta Escalera (azul). Franja de x 60 a 120, entre las casas de la calle y el borde del mapa.
-- Pasajes con tramos de escalones bajos y una cancha de barrio abierta en el centro (emboscada grande al pisarla).
-- Recorrido: puerta este del lobby -> patio -> pasaje B1 -> B2 -> B3 -> cancha -> B4 -> rellano -> B5 -> embudo de la tienda.
-- Los fondos de los callejones laterales (T1, T2, T3) son los puntos de aparición y guardan las latas grandes.
local STAIRS = {
	{ "Patio", 60, 86, -382, -366 },
	{ "B1", 68, 78, -366, -300 },
	{ "RampaT1a", 78, 86, -364, -340 }, -- azotea: rampa de subida, terraza y rampa de bajada
	{ "AzoteaT1", 78, 100, -340, -322 },
	{ "RampaT1b", 78, 86, -322, -300 },
	{ "C1", 60, 68, -314, -306 }, -- cruce 1 hacia la calle
	{ "B2", 68, 104, -300, -290 },
	{ "T3", 86, 94, -322, -300 }, -- callejón lateral (sin salida)
	{ "B3", 94, 104, -290, -255 },
	{ "Cancha", 66, 106, -255, -225 },
	{ "C2", 60, 66, -244, -236 }, -- cruce 2 hacia la calle
	{ "T2", 72, 80, -275, -255 }, -- callejón lateral (sin salida)
	{ "T1", 96, 104, -225, -205 }, -- callejón lateral (sin salida)
	{ "B4", 68, 78, -225, -185 },
	{ "Rellano", 68, 92, -185, -165 },
	{ "C3", 60, 68, -174, -166 }, -- cruce 3 hacia la calle
	{ "B5", 82, 92, -165, -148 },
	{ "E", 60, 92, -148, -139 }, -- salida hacia el embudo de la tienda
}
local STAIRS_BAND = { x1 = 60, x2 = 120, z1 = -400, z2 = -130 }

-- Tramo de escalones que sube y baja (0.5 por escalón, 3 escalones, 2 de huella), atravesando un pasaje en Z
local function stairs(map, x1, x2, z1)
	for step = 1, 3 do
		local inset = (step - 1) * 2
		local part = block(map, "Escalon", Vector3.new(x2 - x1, 0.5, 16 - inset * 2), Vector3.new((x1 + x2) / 2, FLOOR_TOP + (step - 0.5) * 0.5, z1 + 8), step % 2 == 1 and C.azul or C.blanco, Enum.Material.Concrete)
		part.TopSurface = Enum.SurfaceType.Smooth
	end
end

-- Arco de fútbol (sin colisión): dos postes y el travesaño, a lo ancho en X
local function goal(map, x, z)
	for _, dx in { -4, 4 } do
		deco(pole(map, "Arco", Vector3.new(x + dx, 0, z), 5, 0.4, C.blanco))
	end
	deco(block(map, "Arco", Vector3.new(8.4, 0.4, 0.4), Vector3.new(x, 5, z), C.blanco, Enum.Material.Metal))
end

local function buildStairs(map, refs, rng, spawns)
	local rects = {}
	for _, r in STAIRS do
		rects[r[1]] = r
	end
	local neighbors = { { "Puerta", 45, 60, -380, -368 }, { "Embudo", 20, 60, -148, -139 } }
	for _, z in CROSSINGS do
		table.insert(neighbors, { "Cruce", 35, 60, z - 4, z + 4 })
	end
	local function isOpen(x, z)
		return inRects(STAIRS, x, z) or inRects(neighbors, x, z)
	end

	-- Pisos (la cancha es de tierra)
	for _, r in STAIRS do
		local field = r[1] == "Cancha"
		floor(map, "Piso" .. r[1], r[2], r[3], r[4], r[5], field and C.tierra or C.acera, field and Enum.Material.Ground or Enum.Material.Concrete)
	end

	fillHouses(map, rng, STAIRS_BAND, STAIRS, isOpen)

	-- Azotea de 10 de alto junto a B1: se sube por una rampa, se baja por otra; arriba hay latas y cobertura
	ramp(map, 78, 86, -364, -340, true)
	azotea(map, 78, 100, -340, -322)
	ramp(map, 78, 86, -322, -300, false)
	do
		local roofPile, roofPrompt = canPile(map, Vector3.new(96, ROOF_HEIGHT, -331))
		table.insert(refs.canPiles, { model = roofPile, prompt = roofPrompt, amount = Config.CanPiles.BigAmount })
		block(map, "CoberturaAzotea", Vector3.new(4, 2, 2), Vector3.new(88, ROOF_HEIGHT + 1, -331), C.tierra, Enum.Material.Fabric)
		local kit, kitPrompt = medkitPickup(map, Vector3.new(92, ROOF_HEIGHT, -337)) -- botiquín del tramo 1, en la azotea
		table.insert(refs.medkits, { model = kit, prompt = kitPrompt })
	end

	-- Escalones bajos de verdad, pintados de azul y blanco
	stairs(map, 68, 78, -352)
	stairs(map, 94, 104, -288)
	stairs(map, 68, 78, -217)

	-- Cancha: líneas, arcos en los extremos, el autobús escolar volcado como cobertura y dos reflectores
	for _, line in {
		{ Vector3.new(40, 0.05, 0.4), Vector3.new(86, FLOOR_TOP + 0.03, -240) }, -- línea central
		{ Vector3.new(0.4, 0.05, 30), Vector3.new(66.6, FLOOR_TOP + 0.03, -240) },
		{ Vector3.new(0.4, 0.05, 30), Vector3.new(105.4, FLOOR_TOP + 0.03, -240) },
	} do
		deco(block(map, "LineaCancha", line[1], line[2], C.blanco, Enum.Material.SmoothPlastic))
	end
	goal(map, 86, -254)
	goal(map, 86, -226)
	busOnSide(map, 76, -240)
	for _, light in { { 67, -254 }, { 105, -226 } } do
		deco(pole(map, "Reflector", Vector3.new(light[1], 0, light[2]), 18, 0.8, C.concreto))
		Atmosphere.bulb(map, Vector3.new(light[1], 18.3, light[2]))
	end

	-- Franjas azules en las paredes del recorrido
	for _, stripe in {
		{ Vector3.new(0.3, 1, 66), Vector3.new(77.85, 6, -333) }, -- B1, pared este
		{ Vector3.new(0.3, 1, 35), Vector3.new(94.15, 6, -272.5) }, -- B3, pared oeste
		{ Vector3.new(0.3, 1, 40), Vector3.new(77.85, 6, -205) }, -- B4, pared este
	} do
		if SHOW.routeStripes then
			deco(block(map, "FranjaAzul", stripe[1], stripe[2], C.azul, Enum.Material.SmoothPlastic))
		end
	end

	-- Murales
	sign(map, "Mural", "SUBE SIN MIEDO", Vector3.new(12, 6, 0.4), CFrame.new(68.3, 8, -340) * CFrame.Angles(0, -math.pi / 2, 0), C.cobalto, C.blanco)
	sign(map, "Mural", "LA CANCHA ES DE TODOS", Vector3.new(9, 6, 0.4), CFrame.new(105.7, 8, -250) * CFrame.Angles(0, math.pi / 2, 0), C.lima, C.oscuro)
	sign(map, "Mural", "EL BARRIO RESISTE", Vector3.new(12, 6, 0.4), Vector3.new(76, 8, -164.7), C.terracota, C.blanco)

	-- Flechas azules del recorrido y rojas en los cruces hacia la calle
	for _, arrow in {
		{ 64, -374, math.pi / 2 },
		{ 73, -360, 0 },
		{ 73, -322, 0 },
		{ 82, -295, math.pi / 2 },
		{ 99, -268, 0 },
		{ 72, -248, 0 },
		{ 73, -200, 0 },
		{ 80, -175, math.pi / 2 },
		{ 87, -156, 0 },
		{ 72, -143.5, -math.pi / 2 },
	} do
		floorArrow(map, Vector3.new(arrow[1], 0, arrow[2]), C.azul, arrow[3])
	end
	floorArrow(map, Vector3.new(64, 0, -310), C.rojo, -math.pi / 2)
	floorArrow(map, Vector3.new(64, 0, -170), C.rojo, -math.pi / 2)

	-- Lámparas de pared
	for _, lamp in { { 77.6, 11, -330 }, { 82, 11, -289.6 }, { 66.4, 13, -230 }, { 77.6, 11, -200 }, { 70, 12.5, -165.4 }, { 75, 11, -139.4 } } do
		Atmosphere.bulb(map, Vector3.new(lamp[1], lamp[2], lamp[3]))
	end

	-- Detalles: tendederos, motos y barriles (el paso nunca queda en menos de 6)
	for _, line in { { 73, -310, 10 }, { 99, -275, 10 }, { 73, -195, 10 } } do
		local x, z, length = line[1], line[2], line[3]
		deco(block(map, "Tendedero", Vector3.new(length, 0.1, 0.1), Vector3.new(x, 9, z), C.blanco))
		for i, cloth in { C.lonaNaranja, C.turquesa, C.blanco, C.grafiti } do
			deco(block(map, "Ropa", Vector3.new(1.6, 2, 0.1), Vector3.new(x - length / 2 + i * length / 5, 8, z), cloth, Enum.Material.Fabric))
		end
	end
	barrel(map, 69, -296, C.lonaAzul)
	barrel(map, 103, -262)
	barrel(map, 91, -168, C.lonaVerde)
	for _, moto in { { 70, -235, 70 }, { 88, -180, 10 } } do
		local cf = CFrame.new(moto[1], 0.6, moto[2]) * CFrame.Angles(0, math.rad(moto[3]), 0)
		deco(block(map, "Moto", Vector3.new(1.8, 1.2, 5.5), cf, C.cobalto, Enum.Material.Metal))
	end

	-- Estación de munición en el pasaje B1 (pared este, mirando al pasaje)
	if LEGACY_SHOPS then
		local model, hitbox = PropModel.build(CajaMunicion, Vector3.new(76.5, 0, -325), math.rad(90))
		hitbox.Name = "AmmoStation"
		model.Parent = map
		label(hitbox, "AMMO", Color3.fromRGB(80, 165, 255), 18)
		table.insert(refs.ammoStations, { part = hitbox, model = model, prompt = prompt(hitbox, "Buy ammo", 0.5) })
	end

	-- Puntos de aparición al fondo de los callejones laterales que rodean la cancha
	local T1, T2, T3 = Vector3.new(100, 0, -209), Vector3.new(76, 0, -271), Vector3.new(90, 0, -318)
	for _, point in { T1, T2, T3 } do
		marker(spawns, point)
	end

	-- Emboscada grande: al pisar la cancha por primera vez salen zombies de los tres callejones a la vez
	local field = rects.Cancha
	table.insert(refs.ambushes, {
		volume = volume(map, "EmboscadaCancha", field[2], field[3], field[4], field[5], 12),
		points = { T1, T2, T3 },
		size = Config.Ambush.FieldSize,
	})

	-- Latas grandes en mitad de cada callejón lateral (cerca de donde salen los zombies: más riesgo, más latas)
	for _, position in { Vector3.new(100, 0, -216), Vector3.new(76, 0, -264), Vector3.new(90, 0, -310) } do
		local pileModel, pilePrompt = canPile(map, position)
		table.insert(refs.canPiles, { model = pileModel, prompt = pilePrompt, amount = Config.CanPiles.BigAmount })
	end

	-- Caja de armas junto a la cancha (uno de estos lugares, al azar)
	if LEGACY_SHOPS then
	table.insert(refs.boxSpots.Zone1, { Vector3.new(88, 0, -250), Vector3.new(88, 0, -229.5), Vector3.new(80, 0, -175) })
	end
end

---------------------------------------------------------------------------------------------------
-- Puntos seguros: la tienda (z -130..-90) y la iglesia (z 160..200). Aquí se respira: luz cálida y estable, materiales
-- nobles (madera, azulejo, tela) y marcos verdes en las puertas. Todo es decoración sin colisión.

local SAFE_WALL = Color3.fromRGB(236, 222, 194)
local SAFE_TEAL = Color3.fromRGB(44, 110, 96)
local SAFE_WOOD = Color3.fromRGB(86, 58, 38)
local SAFE_GREEN = Color3.fromRGB(90, 230, 130)
local SAFE_GOLD = Color3.fromRGB(214, 170, 70)
local PRODUCTS = { C.rojo, C.lima, C.mostaza, C.lonaAzul, C.terracota, C.blanco, C.turquesa, C.lonaNaranja }

-- Cartel pequeño con texto (marco negro y tarjeta clara), mismo estilo que los de los puestos del mercado
local function noticeBoard(parent, cframe, text)
	local _, gui = blankBoard(parent, "Aviso", Vector3.new(9, 3.6, 0.2), cframe, RHO_BLACK, 50)
	boardRect(gui, 0.03, 0.08, 0.94, 0.84, C.blanco)
	boardText(gui, text, 0.06, 0.12, 0.88, 0.76, RHO_BLACK, Enum.TextXAlignment.Center).TextWrapped = true
end

local function safeBall(parent, position, diameter, color, material)
	local b = deco(block(parent, "Bola", Vector3.new(diameter, diameter, diameter), position, color, material or Enum.Material.SmoothPlastic))
	b.Shape = Enum.PartType.Ball
	return b
end

-- Planta en maceta
local function pottedPlant(parent, x, z, rng)
	deco(pole(parent, "Maceta", Vector3.new(x, 0, z), 1.4, 1.9, C.terracota, Enum.Material.Pebble))
	for i = 1, 3 do
		safeBall(parent, Vector3.new(x + rng:NextNumber(-0.5, 0.5), 2.2 + i * 0.5, z + rng:NextNumber(-0.5, 0.5)), 1.6 - i * 0.2, C.lonaVerde, Enum.Material.Grass)
	end
end

-- Hilera de productos sobre una tabla de estante (frascos, cajas y latas de colores)
local function stockRow(parent, centerCf, length, rng)
	local x = -length / 2 + 0.8
	while x < length / 2 - 0.6 do
		local w = rng:NextNumber(0.9, 1.6)
		local h = rng:NextNumber(0.7, 1.7)
		local kind = rng:NextInteger(1, 3)
		local color = PRODUCTS[rng:NextInteger(1, #PRODUCTS)]
		local material = kind == 1 and Enum.Material.Glass or kind == 2 and Enum.Material.Cardboard or Enum.Material.Metal
		local piece = deco(block(parent, "Producto", Vector3.new(w, h, 1.2), centerCf * CFrame.new(x + w / 2, h / 2, 0), color, material))
		if kind == 1 then
			piece.Transparency = 0.2
		end
		x += w + 0.25
	end
end

---------------------------------------------------------------------------------------------------
-- Tienda: interior x ±28, z -128..-92, techo a 16

-- CFrame sobre la superficie interior de una pared de la tienda, con el frente (-Z local) hacia dentro
local function shopWall(wall, along, y)
	if wall == "front" then
		return CFrame.new(along, y, -128) * CFrame.Angles(0, math.pi, 0)
	elseif wall == "back" then
		return CFrame.new(along, y, -92)
	elseif wall == "west" then
		return CFrame.new(-28, y, along) * CFrame.Angles(0, -math.pi / 2, 0)
	end
	return CFrame.new(28, y, along) * CFrame.Angles(0, math.pi / 2, 0) -- "east"
end

local function shopDetails(map, rng)
	local folder = Instance.new("Folder")
	folder.Name = "TiendaDetalles"
	folder.Parent = map
	local on = function(wall, along, y, depth)
		return shopWall(wall, along, y) * CFrame.new(0, 0, -(depth or 0))
	end

	-- Dado de azulejos, remate, moldura de madera y rodapié en cada tramo de pared
	for _, seg in {
		{ "front", -20, 16 }, { "front", 20, 16 }, { "back", -20, 16 }, { "back", 20, 16 },
		{ "west", -125, 6 }, { "west", -101, 18 }, { "east", -125, 6 }, { "east", -101, 18 },
	} do
		local wall, along, len = seg[1], seg[2], seg[3]
		deco(block(folder, "Azulejo", Vector3.new(len, 4.6, 0.15), on(wall, along, 2.3, 0.08), SAFE_TEAL, Enum.Material.Marble))
		deco(block(folder, "AzulejoRemate", Vector3.new(len, 0.35, 0.28), on(wall, along, 4.75, 0.14), C.blanco, Enum.Material.SmoothPlastic))
		deco(block(folder, "Rodapie", Vector3.new(len, 0.5, 0.3), on(wall, along, 0.25, 0.15), SAFE_WOOD, Enum.Material.Wood))
		deco(block(folder, "Moldura", Vector3.new(len, 0.7, 0.35), on(wall, along, 15.2, 0.18), SAFE_WOOD, Enum.Material.Wood))
	end
	-- Pilastras a los lados de las puertas y en las esquinas
	for _, p in { { "front", -27 }, { "front", -13 }, { "front", 13 }, { "front", 27 }, { "back", -27 }, { "back", -13 }, { "back", 13 }, { "back", 27 } } do
		deco(block(folder, "Pilastra", Vector3.new(1.4, 16, 0.7), on(p[1], p[2], 8, 0.35), SAFE_WALL:Lerp(C.concreto, 0.35), Enum.Material.Concrete))
	end

	-- Piso de damero (baldosas oscuras sobre el piso claro) y un tapete rojo en la zona de descanso
	for ix = 0, 13 do
		for iz = 0, 8 do
			local cx, cz = -28 + ix * 4 + 2, -128 + iz * 4 + 2
			local underRug = math.abs(cx) <= 6 and cz >= -114 and cz <= -106
			if (ix + iz) % 2 == 0 and not underRug then
				deco(block(folder, "Baldosa", Vector3.new(4, 0.05, 4), Vector3.new(cx, FLOOR_TOP + 0.03, cz), Color3.fromRGB(150, 86, 62), Enum.Material.Slate))
			end
		end
	end
	deco(block(folder, "Tapete", Vector3.new(12, 0.06, 8), Vector3.new(0, FLOOR_TOP + 0.05, -110), Color3.fromRGB(140, 36, 34), Enum.Material.Fabric))
	for _, edge in { { 11.2, 0.5, 0, -113.6 }, { 11.2, 0.5, 0, -106.4 }, { 0.5, 7.2, -5.6, -110 }, { 0.5, 7.2, 5.6, -110 } } do
		deco(block(folder, "TapeteBorde", Vector3.new(edge[1], 0.07, edge[2]), Vector3.new(edge[3], FLOOR_TOP + 0.06, edge[4]), C.blanco, Enum.Material.Fabric))
	end
	deco(block(folder, "TapeteRombo", Vector3.new(3, 0.07, 3), CFrame.new(0, FLOOR_TOP + 0.07, -110) * CFrame.Angles(0, math.rad(45), 0), RHO_YELLOW, Enum.Material.Fabric))

	-- Techo: vigas de madera, tubos de luz y dos ventiladores
	for _, z in { -124, -116, -108, -100, -94 } do
		deco(block(folder, "VigaTienda", Vector3.new(56, 0.9, 0.9), Vector3.new(0, 15.6, z), SAFE_WOOD, Enum.Material.Wood))
	end
	for _, x in { -14, 14 } do
		local tube = deco(block(folder, "TuboLuz", Vector3.new(5, 0.25, 0.6), Vector3.new(x, 15.3, -110), Color3.fromRGB(150, 120, 90), Enum.Material.SmoothPlastic))
		local fan = folder
		deco(pole(fan, "VentiladorVarilla", Vector3.new(x, 13.4, -118), 2.2, 0.25, C.concreto, Enum.Material.Metal))
		deco(pole(fan, "VentiladorCentro", Vector3.new(x, 13.1, -118), 0.5, 1, C.oscuro, Enum.Material.Metal))
		for k = 0, 3 do
			deco(block(fan, "VentiladorPala", Vector3.new(4.4, 0.12, 0.9), CFrame.new(x, 13.2, -118) * CFrame.Angles(0, k * math.pi / 4 + 0.3, 0), SAFE_WOOD, Enum.Material.Wood))
		end
		local lampLight = Instance.new("PointLight") -- luz cálida y estable (aquí se respira)
		lampLight.Color = Color3.fromRGB(255, 214, 160)
		lampLight.Range = 14
		lampLight.Brightness = 0.15 -- tenue: la luz buena la dan las antorchas y la estufa
		lampLight.Parent = tube
	end

	-- Mostrador: caja registradora, balanza, frascos de dulces y guirnalda de bolsas de papas
	local top = 4
	deco(block(folder, "CajaRegistradora", Vector3.new(1.6, 1, 1.4), Vector3.new(-21, top + 0.5, -114.2), C.oscuro, Enum.Material.Metal))
	deco(block(folder, "CajaRegistradoraPantalla", Vector3.new(1, 0.7, 0.15), CFrame.new(-21, top + 1.4, -114.2) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(90, 220, 140), Enum.Material.Neon))
	deco(block(folder, "BalanzaBase", Vector3.new(1.4, 0.5, 1.4), Vector3.new(-21, top + 0.25, -109), C.concreto, Enum.Material.Metal))
	deco(pole(folder, "BalanzaPlato", Vector3.new(-21, top + 0.5, -109), 0.2, 1.8, C.concreto, Enum.Material.Metal))
	for i, z in { -104.5, -105.8, -116.3 } do
		deco(pole(folder, "FrascoDulces", Vector3.new(-21.4 + (i == 3 and 0.6 or 0), top, z), 1, 0.9, ({ C.rojo, C.mostaza, C.lima })[i], Enum.Material.Glass)).Transparency = 0.3
	end
	deco(block(folder, "GuirnaldaCuerda", Vector3.new(0.1, 0.1, 14), Vector3.new(-21, 9.5, -110), C.oscuro))
	for i = 1, 7 do
		deco(block(folder, "BolsaPapas", Vector3.new(0.9, 1.3, 0.2), Vector3.new(-21, 8.8, -116 + i * 1.8), PRODUCTS[(i % #PRODUCTS) + 1], Enum.Material.Fabric))
	end

	-- Estantes surtidos: el metálico del este y dos unidades en la pared del fondo
	for level = 0, 3 do
		local y = 1.6 + level * 2
		deco(block(folder, "TablaEstante", Vector3.new(1.6, 0.2, 10), Vector3.new(24.9, y, -100), C.madera, Enum.Material.WoodPlanks))
		stockRow(folder, CFrame.new(24.6, y + 0.1, -105) * CFrame.Angles(0, math.pi / 2, 0), 10, rng)
	end
	for _, ux in { -20, 20 } do
		local base = on("back", ux, 0)
		for _, dx in { -5.8, 5.8 } do
			for _, dz in { -0.4, -2.2 } do
				deco(block(folder, "EstantePoste", Vector3.new(0.3, 10, 0.3), base * CFrame.new(dx, 5, dz), C.concreto, Enum.Material.Metal))
			end
		end
		for level = 1, 3 do
			local y = level * 2.9
			deco(block(folder, "TablaEstante", Vector3.new(12, 0.25, 2.4), base * CFrame.new(0, y, -1.3), C.madera, Enum.Material.WoodPlanks))
			stockRow(folder, base * CFrame.new(0, y + 0.12, -1.3), 12, rng)
		end
	end

	-- Refrigeradores con puerta de vidrio, botellas y tira de luz
	for _, z in { -96, -124 } do
		deco(block(folder, "RefriVidrio", Vector3.new(0.1, 5.8, 2.5), Vector3.new(-23.9, 3.7, z), Color3.fromRGB(150, 220, 235), Enum.Material.Glass)).Transparency = 0.45
		deco(block(folder, "RefriLuz", Vector3.new(0.15, 0.2, 2.4), Vector3.new(-24, 6.7, z), Color3.fromRGB(150, 235, 255), Enum.Material.Neon))
		for level = 0, 1 do
			for i = 1, 3 do
				deco(pole(folder, "Botella", Vector3.new(-24.6, 1.6 + level * 2.2, z - 1.2 + i * 0.7), 1.1, 0.5, PRODUCTS[rng:NextInteger(1, #PRODUCTS)], Enum.Material.Glass))
			end
		end
	end

	-- Ventanas con cortinas en la pared sur, cuadros en las laterales
	for _, x in { -20, 20 } do
		local cf = on("front", x, 10)
		deco(block(folder, "VentanaMarco", Vector3.new(5.4, 4.4, 0.4), cf * CFrame.new(0, 0, -0.25), SAFE_WOOD, Enum.Material.Wood))
		deco(block(folder, "VentanaVidrio", Vector3.new(4.4, 3.4, 0.15), cf * CFrame.new(0, 0, -0.45), Color3.fromRGB(30, 44, 70), Enum.Material.Glass)).Transparency = 0.3
		deco(block(folder, "VentanaTravesano", Vector3.new(4.4, 0.18, 0.2), cf * CFrame.new(0, 0, -0.55), SAFE_WOOD, Enum.Material.Wood))
		for _, dx in { -2.6, 2.6 } do
			deco(block(folder, "Cortina", Vector3.new(1.2, 4.6, 0.25), cf * CFrame.new(dx, -0.1, -0.7), C.rojo, Enum.Material.Fabric))
		end
	end
	for _, pic in { { "east", -98, 11.5 }, { "west", -97, 11.5 }, { "west", -123, 9 } } do
		local cf = on(pic[1], pic[2], pic[3])
		deco(block(folder, "CuadroMarco", Vector3.new(5.4, 4.2, 0.3), cf * CFrame.new(0, 0, -0.2), SAFE_WOOD, Enum.Material.Wood))
		deco(block(folder, "CuadroCielo", Vector3.new(4.6, 3.4, 0.1), cf * CFrame.new(0, 0, -0.38), Color3.fromRGB(120, 170, 220), Enum.Material.SmoothPlastic))
		deco(block(folder, "CuadroCerro", Vector3.new(4.6, 1.3, 0.1), cf * CFrame.new(0, -1.05, -0.43), C.lonaVerde, Enum.Material.SmoothPlastic))
		deco(pole(folder, "CuadroSol", Vector3.zero, 0.1, 1, RHO_YELLOW, Enum.Material.Neon)).CFrame = cf * CFrame.new(1.2, 0.8, -0.45) * CFrame.Angles(0, math.pi / 2, 0)
	end

	-- Rincón de descanso: estufa de barril con fuego, taburetes y una mesita con farol; plantas en las esquinas
	deco(pole(folder, "BarrilEstufa", Vector3.new(10, 0, -96), 3, 2.2, C.oxido, Enum.Material.CorrodedMetal))
	local flame = deco(block(folder, "LlamaEstufa", Vector3.new(1, 1.4, 1), CFrame.new(10, 3.5, -96) * CFrame.Angles(0, 0.5, 0), C.lonaNaranja, Enum.Material.Neon))
	deco(block(folder, "LlamaEstufa", Vector3.new(0.6, 1, 0.6), CFrame.new(10.2, 3.4, -96.2) * CFrame.Angles(0.2, 1.1, 0.2), RHO_YELLOW, Enum.Material.Neon))
	local fire = Instance.new("PointLight")
	fire.Color = Color3.fromRGB(255, 150, 70)
	fire.Range = 22
	fire.Brightness = 1.1
	fire.Parent = flame
	for _, stool in { { 4, -101 }, { -4, -101 } } do
		deco(pole(folder, "Taburete", Vector3.new(stool[1], 0, stool[2]), 1.8, 1.4, C.madera, Enum.Material.Wood))
	end
	deco(pole(folder, "MesitaPata", Vector3.new(0, 0, -100), 2, 0.5, SAFE_WOOD, Enum.Material.Wood))
	deco(pole(folder, "MesitaTapa", Vector3.new(0, 2, -100), 0.2, 2.4, SAFE_WOOD, Enum.Material.Wood))
	deco(pole(folder, "Farol", Vector3.new(0, 2.2, -100), 0.9, 0.7, C.mostaza, Enum.Material.Metal))
	deco(block(folder, "FarolLlama", Vector3.new(0.4, 0.4, 0.4), Vector3.new(0, 3.3, -100), Color3.fromRGB(255, 220, 150), Enum.Material.Neon))
	for _, spot in { { 27, -93.5 }, { -27, -93.5 }, { 12.5, -126 }, { -12.5, -126 } } do
		pottedPlant(folder, spot[1], spot[2], rng)
	end

	-- Marcos verdes de zona segura alrededor de las puertas
	local function trim(position, size)
		deco(block(folder, "MarcoSeguro", size, position, SAFE_GREEN, Enum.Material.Neon)).Transparency = 0.15
	end
	for _, z in { -128.7, -91.3 } do -- puertas norte y sur
		trim(Vector3.new(-12.3, 7, z), Vector3.new(0.35, 14, 0.4))
		trim(Vector3.new(12.3, 7, z), Vector3.new(0.35, 14, 0.4))
		trim(Vector3.new(0, 14.2, z), Vector3.new(24.6, 0.35, 0.4))
	end
	for _, x in { -28.7, 28.7 } do -- puertas laterales
		trim(Vector3.new(x, 7, -122.2), Vector3.new(0.4, 14, 0.35))
		trim(Vector3.new(x, 7, -109.8), Vector3.new(0.4, 14, 0.35))
		trim(Vector3.new(x, 14.2, -116), Vector3.new(0.4, 0.35, 12.4))
	end

	-- Avisos del interior
	noticeBoard(folder, on("west", -102, 8, 0.2), "El comandante dijo que el Refugio Remo todavía resiste")

	-- Fachada: rótulo, toldo a rayas, dado de azulejos, jardineras y dos anuncios pintados
	local _, signGui = blankBoard(folder, "RotuloTienda", Vector3.new(24, 4.5, 0.4), CFrame.new(0, 17.6, -130.3), RHO_BLACK, 40)
	boardRect(signGui, 0.02, 0.08, 0.96, 0.84, RHO_YELLOW)
	boardText(signGui, "ABARROTES DOÑA ROSA", 0.04, 0.1, 0.92, 0.8, RHO_BLACK, Enum.TextXAlignment.Center)
	for i = 0, 11 do
		deco(block(folder, "ToldoTienda", Vector3.new(2.2, 0.3, 4.4), CFrame.new(-12.1 + i * 2.2, 14.6 - 0.2, -132) * CFrame.Angles(math.rad(-18), 0, 0), i % 2 == 0 and C.rojo or C.blanco, Enum.Material.Fabric))
	end
	for _, seg in { -20, 20 } do
		deco(block(folder, "AzulejoExterior", Vector3.new(16, 5, 0.15), Vector3.new(seg, 2.5, -130.15), SAFE_TEAL, Enum.Material.Marble))
		deco(block(folder, "AzulejoExteriorRemate", Vector3.new(16, 0.35, 0.28), Vector3.new(seg, 5.1, -130.2), C.blanco, Enum.Material.SmoothPlastic))
		deco(block(folder, "AnuncioPintado", Vector3.new(6, 5, 0.12), Vector3.new(seg, 10, -130.14), seg < 0 and C.terracota or C.lima, Enum.Material.SmoothPlastic))
		deco(pole(folder, "AnuncioBotella", Vector3.new(seg - 1, 8, -130.3), 3.4, 1.1, C.blanco, Enum.Material.Glass))
		deco(pole(folder, "AnuncioBotella", Vector3.new(seg + 1, 8, -130.3), 3.4, 1.1, C.oscuro, Enum.Material.Glass))
		deco(block(folder, "Jardinera", Vector3.new(4, 1.3, 1.4), Vector3.new(seg * 0.84, 0.65, -131.2), C.madera, Enum.Material.WoodPlanks))
		for k = -1, 1 do
			safeBall(folder, Vector3.new(seg * 0.84 + k * 1.1, 2, -131.2), 1.3, C.lonaVerde, Enum.Material.Grass)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Iglesia: interior x ±28, z 162..198, techo a 20

local function churchWall(wall, along, y)
	if wall == "front" then
		return CFrame.new(along, y, 162) * CFrame.Angles(0, math.pi, 0)
	elseif wall == "back" then
		return CFrame.new(along, y, 198)
	elseif wall == "west" then
		return CFrame.new(-28, y, along) * CFrame.Angles(0, -math.pi / 2, 0)
	end
	return CFrame.new(28, y, along) * CFrame.Angles(0, math.pi / 2, 0)
end

local function churchDetails(map, rng)
	local folder = Instance.new("Folder")
	folder.Name = "IglesiaDetalles"
	folder.Parent = map
	local on = function(wall, along, y, depth)
		return churchWall(wall, along, y) * CFrame.new(0, 0, -(depth or 0))
	end

	-- Paneles de madera en la parte baja, cornisa y zócalo
	for _, seg in { { "west", 180, 36 }, { "east", 180, 36 }, { "front", -20, 16 }, { "front", 20, 16 }, { "back", -20, 16 }, { "back", 20, 16 } } do
		deco(block(folder, "PanelMadera", Vector3.new(seg[3], 4.6, 0.2), on(seg[1], seg[2], 2.3, 0.1), SAFE_WOOD, Enum.Material.WoodPlanks))
		deco(block(folder, "PanelRemate", Vector3.new(seg[3], 0.4, 0.35), on(seg[1], seg[2], 4.8, 0.18), SAFE_GOLD, Enum.Material.Wood))
		deco(block(folder, "Cornisa", Vector3.new(seg[3], 0.9, 0.5), on(seg[1], seg[2], 19.2, 0.25), SAFE_WOOD, Enum.Material.Wood))
	end

	-- Columnas adosadas entre los vitrales, con base y capitel dorados
	for _, wall in { "west", "east" } do
		for _, z in { 166.5, 175.5, 188.5, 194.5 } do
			deco(block(folder, "Columna", Vector3.new(1.6, 20, 1.2), on(wall, z, 10, 0.6), C.concreto, Enum.Material.Concrete))
			deco(block(folder, "ColumnaBase", Vector3.new(2.2, 0.8, 1.7), on(wall, z, 0.4, 0.85), SAFE_GOLD, Enum.Material.Metal))
			deco(block(folder, "ColumnaCapitel", Vector3.new(2.2, 0.8, 1.7), on(wall, z, 18.6, 0.85), SAFE_GOLD, Enum.Material.Metal))
		end
	end

	-- Marcos de los vitrales: marco de piedra, travesaños y remate en punta
	for _, wall in { "west", "east" } do
		for _, z in { 170, 182, 194 } do
			local cf = on(wall, z, 11)
			deco(block(folder, "VitralMarco", Vector3.new(4.4, 7.6, 0.4), cf * CFrame.new(0, 0, -0.15), C.concreto, Enum.Material.Concrete))
			deco(block(folder, "VitralTravesano", Vector3.new(3.6, 0.22, 0.2), cf * CFrame.new(0, 0, -0.45), SAFE_WOOD, Enum.Material.Wood))
			deco(block(folder, "VitralTravesano", Vector3.new(3.6, 0.22, 0.2), cf * CFrame.new(0, 1.9, -0.45), SAFE_WOOD, Enum.Material.Wood))
			deco(block(folder, "VitralMontante", Vector3.new(0.22, 6, 0.2), cf * CFrame.new(0, 0, -0.45), SAFE_WOOD, Enum.Material.Wood))
			for _, dx in { -1, 1 } do
				deco(block(folder, "VitralPunta", Vector3.new(0.4, 2.7, 0.35), cf * CFrame.new(dx * 0.95, 4, -0.15) * CFrame.Angles(0, 0, -dx * math.rad(32)), C.concreto, Enum.Material.Concrete))
			end
		end
	end

	-- Alfombra roja con bordes dorados por la nave, y franjas de madera clara en el suelo
	deco(block(folder, "Alfombra", Vector3.new(6, 0.06, 31), Vector3.new(0, FLOOR_TOP + 0.04, 178.5), Color3.fromRGB(128, 28, 32), Enum.Material.Fabric))
	for _, x in { -2.8, 2.8 } do
		deco(block(folder, "AlfombraBorde", Vector3.new(0.4, 0.07, 31), Vector3.new(x, FLOOR_TOP + 0.05, 178.5), SAFE_GOLD, Enum.Material.Fabric))
	end
	for _, x in { -3.7, 3.7 } do
		deco(block(folder, "TablaClara", Vector3.new(0.4, 0.05, 36), Vector3.new(x, FLOOR_TOP + 0.03, 180), Color3.fromRGB(176, 136, 90), Enum.Material.WoodPlanks))
	end

	-- Espaldares de las bancas
	for i, z in { 172, 178, 184, 190 } do
		local cf = CFrame.new(-21.5, 0, z) * CFrame.Angles(0, math.rad(({ 0, 12, -8, 25 })[i]), 0)
		deco(block(folder, "BancaRespaldo", Vector3.new(9, 1.8, 0.3), cf * CFrame.new(0, 2.1, -0.9), C.madera, Enum.Material.Wood))
	end
	for i, z in { 182, 188 } do
		local cf = CFrame.new(21.5, 0, z) * CFrame.Angles(0, math.rad(({ -15, 6 })[i]), 0)
		deco(block(folder, "BancaRespaldo", Vector3.new(9, 1.8, 0.3), cf * CFrame.new(0, 2.1, -0.9), C.madera, Enum.Material.Wood))
	end

	-- Candelabros de pie junto a la nave
	for _, spot in { { -9, 174 }, { 9, 174 }, { -9, 186 }, { 9, 186 } } do
		deco(pole(folder, "CandelabroPie", Vector3.new(spot[1], 0, spot[2]), 4.2, 0.35, C.oscuro, Enum.Material.Metal))
		deco(pole(folder, "CandelabroBase", Vector3.new(spot[1], 0, spot[2]), 0.3, 1.6, C.oscuro, Enum.Material.Metal))
		deco(block(folder, "CandelabroBrazo", Vector3.new(2.4, 0.2, 0.2), Vector3.new(spot[1], 4.3, spot[2]), C.oscuro, Enum.Material.Metal))
		for _, dx in { -1.1, 0, 1.1 } do
			deco(pole(folder, "CandelabroVela", Vector3.new(spot[1] + dx, 4.4, spot[2]), 0.8, 0.28, Color3.fromRGB(240, 230, 200), Enum.Material.SmoothPlastic))
			deco(block(folder, "CandelabroLlama", Vector3.new(0.2, 0.35, 0.2), Vector3.new(spot[1] + dx, 5.4, spot[2]), Color3.fromRGB(255, 200, 120), Enum.Material.Neon))
		end
	end

	-- Araña de luz en el centro de la nave
	do
		local at = Vector3.new(0, 15.2, 180)
		deco(block(folder, "AranaCadena", Vector3.new(0.15, 4.4, 0.15), at + Vector3.new(0, 2.7, 0), C.oscuro, Enum.Material.Metal))
		deco(pole(folder, "AranaAro", at, 0.3, 6, SAFE_GOLD, Enum.Material.Metal))
		for k = 0, 7 do
			local a = k * math.pi / 4
			local p = at + Vector3.new(math.cos(a) * 2.9, 0, math.sin(a) * 2.9)
			deco(pole(folder, "AranaVela", p + Vector3.new(0, 0.2, 0), 0.7, 0.26, Color3.fromRGB(240, 230, 200), Enum.Material.SmoothPlastic))
			deco(block(folder, "AranaLlama", Vector3.new(0.2, 0.3, 0.2), p + Vector3.new(0, 1.1, 0), Color3.fromRGB(255, 200, 120), Enum.Material.Neon))
		end
	end

	-- Techo: vigas de madera
	for z = 166, 194, 6 do
		deco(block(folder, "VigaIglesia", Vector3.new(56, 1.1, 1.1), Vector3.new(0, 19.4, z), SAFE_WOOD, Enum.Material.Wood))
	end

	-- Fondo: gran cruz dorada con rayos y tapices a los lados de la puerta
	do
		local cf = on("back", 0, 17.2, 0.5)
		deco(block(folder, "CruzFondo", Vector3.new(0.9, 5.5, 0.4), cf, SAFE_GOLD, Enum.Material.Metal))
		deco(block(folder, "CruzFondo", Vector3.new(3.4, 0.9, 0.4), cf * CFrame.new(0, 0.9, 0), SAFE_GOLD, Enum.Material.Metal))
		for k = 0, 11 do
			deco(block(folder, "CruzRayo", Vector3.new(0.18, 2.6, 0.1), cf * CFrame.new(0, 0, 0.2) * CFrame.Angles(0, 0, k * math.pi / 6) * CFrame.new(0, 4.6, 0), Color3.fromRGB(255, 214, 120), Enum.Material.Neon)).Transparency = 0.35
		end
	end
	for _, x in { -18, 18 } do
		local cf = on("back", x, 9)
		deco(block(folder, "TapizFondo", Vector3.new(4.4, 9.5, 0.2), cf * CFrame.new(0, 0, -0.15), Color3.fromRGB(128, 28, 32), Enum.Material.Fabric))
		deco(block(folder, "TapizBordeDorado", Vector3.new(4.6, 0.5, 0.25), cf * CFrame.new(0, 4.8, -0.17), SAFE_GOLD, Enum.Material.Fabric))
		deco(block(folder, "TapizBordeDorado", Vector3.new(4.6, 0.5, 0.25), cf * CFrame.new(0, -4.8, -0.17), SAFE_GOLD, Enum.Material.Fabric))
		deco(block(folder, "TapizEscudo", Vector3.new(1.6, 2.2, 0.15), cf * CFrame.new(0, 0.5, -0.3), SAFE_GOLD, Enum.Material.Metal))
	end

	-- Pila de agua bendita junto a la entrada y avisos
	deco(pole(folder, "PilaPie", Vector3.new(-22, 0, 164), 2.6, 1, C.concreto, Enum.Material.Concrete))
	deco(pole(folder, "PilaBol", Vector3.new(-22, 2.6, 164), 0.7, 2, C.concreto, Enum.Material.Concrete))
	deco(pole(folder, "PilaAgua", Vector3.new(-22, 3.25, 164), 0.1, 1.6, Color3.fromRGB(60, 110, 150), Enum.Material.Glass)).Transparency = 0.3
	-- (sin carteles en la nave: el aviso y el lema atravesaban columnas, vitrales y los rayos de la cruz)

	-- Marcos verdes de zona segura (puerta de entrada y de salida)
	for _, z in { 160.7, 199.3 } do
		for _, x in { -12.3, 12.3 } do
			deco(block(folder, "MarcoSeguro", Vector3.new(0.35, 14, 0.4), Vector3.new(x, 7, z), SAFE_GREEN, Enum.Material.Neon)).Transparency = 0.15
		end
		deco(block(folder, "MarcoSeguro", Vector3.new(24.6, 0.35, 0.4), Vector3.new(0, 14.2, z), SAFE_GREEN, Enum.Material.Neon)).Transparency = 0.15
	end

	-- Fachada: rosetón de colores sobre la puerta y contrafuertes
	do
		local center = Vector3.new(0, 24, 159.7)
		local ring = deco(block(folder, "RosetonAro", Vector3.new(7.6, 7.6, 0.4), CFrame.new(center) * CFrame.Angles(0, math.pi / 2, 0), C.concreto, Enum.Material.Concrete))
		ring.Shape = Enum.PartType.Cylinder
		local glass = deco(block(folder, "RosetonVidrio", Vector3.new(6.4, 6.4, 0.3), CFrame.new(center + Vector3.new(0, 0, -0.1)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(30, 44, 80), Enum.Material.Glass))
		glass.Shape = Enum.PartType.Cylinder
		for k = 0, 11 do
			local a = k * math.pi / 6
			deco(block(folder, "RosetonPetalo", Vector3.new(0.9, 2.4, 0.2), CFrame.new(center + Vector3.new(0, 0, -0.35)) * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.9, 0), ({ C.rojo, C.azul, C.mostaza, C.lima })[k % 4 + 1], Enum.Material.Neon)).Transparency = 0.25
		end
		for _, x in { -14.5, 14.5 } do
			deco(block(folder, "Contrafuerte", Vector3.new(2, 24, 1.4), Vector3.new(x, 12, 159.3), C.concreto, Enum.Material.Concrete))
		end
	end
end

-- Parte 6: punto seguro 1, la tienda de barrio (60 × 40 × 16) con reja de entrada y de salida de 24 × 14.
-- Antorcha de pared: soporte, palo inclinado hacia el cuarto, trapo, llama con fuego y luz cálida. `normal` apunta de la pared al interior.
local function flameOn(parent, flame, range, brightness)
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Rate = 16
	fire.Lifetime = NumberRange.new(0.4, 0.8)
	fire.Speed = NumberRange.new(1, 2.5)
	fire.SpreadAngle = Vector2.new(12, 12)
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(230, 70, 20))
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	fire.LightEmission = 0.8
	fire.Parent = flame
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 150, 70)
	glow.Range = range
	glow.Brightness = brightness
	glow.Parent = flame
end

local function wallTorch(parent, position, normal)
	local cf = CFrame.lookAt(position, position + normal)
	deco(block(parent, "AntorchaSoporte", Vector3.new(0.6, 0.35, 0.5), cf * CFrame.new(0, 0, -0.2), C.oscuro, Enum.Material.Metal))
	deco(block(parent, "AntorchaPalo", Vector3.new(0.35, 2.2, 0.35), cf * CFrame.new(0, 0.9, -0.4) * CFrame.Angles(math.rad(-20), 0, 0), SAFE_WOOD, Enum.Material.Wood))
	deco(block(parent, "AntorchaTrapo", Vector3.new(0.62, 0.7, 0.62), cf * CFrame.new(0, 2.05, -0.85) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(58, 40, 28), Enum.Material.Fabric))
	local flame = deco(block(parent, "AntorchaLlama", Vector3.one * 0.85, cf * CFrame.new(0, 2.75, -0.95), C.lonaNaranja, Enum.Material.Neon))
	flame.Shape = Enum.PartType.Ball
	local core = deco(block(parent, "AntorchaNucleo", Vector3.one * 0.5, cf * CFrame.new(0, 2.7, -0.95), RHO_YELLOW, Enum.Material.Neon))
	core.Shape = Enum.PartType.Ball
	flameOn(parent, flame, 20, 1.1)
end

-- Antorcha de poste clavada en el suelo (exteriores): luz más amplia
local function postTorch(parent, x, z, y)
	deco(pole(parent, "PosteAntorcha", Vector3.new(x, y, z), 4.4, 0.45, SAFE_WOOD, Enum.Material.Wood))
	deco(block(parent, "PosteTrapo", Vector3.new(0.9, 0.9, 0.9), Vector3.new(x, y + 4.7, z), Color3.fromRGB(58, 40, 28), Enum.Material.Fabric))
	local flame = deco(block(parent, "PosteLlama", Vector3.one * 1.1, Vector3.new(x, y + 5.5, z), C.lonaNaranja, Enum.Material.Neon))
	flame.Shape = Enum.PartType.Ball
	local core = deco(block(parent, "PosteNucleo", Vector3.one * 0.65, Vector3.new(x, y + 5.4, z), RHO_YELLOW, Enum.Material.Neon))
	core.Shape = Enum.PartType.Ball
	flameOn(parent, flame, 28, 1.3)
end

-- Vela: cuerpo de cera, llama pequeña y luz tenue
local function candle(parent, x, y, z)
	deco(pole(parent, "Vela", Vector3.new(x, y, z), 0.7, 0.3, Color3.fromRGB(240, 226, 196), Enum.Material.SmoothPlastic))
	local flame = deco(block(parent, "VelaLlama", Vector3.one * 0.2, Vector3.new(x, y + 0.82, z), RHO_YELLOW, Enum.Material.Neon))
	flame.Shape = Enum.PartType.Ball
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 190, 110)
	glow.Range = 9
	glow.Brightness = 0.7
	glow.Parent = flame
end

local function buildSafePoint(map, refs)
	local wall = SAFE_WALL
	-- Fachada sur (más alta para el rótulo), lados y fondo
	slab(map, "TiendaFrenteW", -30, -12, -130, -128, 21, wall)
	slab(map, "TiendaFrenteE", 12, 30, -130, -128, 21, wall)
	block(map, "TiendaDintel", Vector3.new(24, 7, 2), Vector3.new(0, 17.5, -129), wall)
	slab(map, "TiendaFondoW", -30, -12, -92, -90, 16, wall)
	slab(map, "TiendaFondoE", 12, 30, -92, -90, 16, wall)
	block(map, "TiendaFondoDintel", Vector3.new(24, 2, 2), Vector3.new(0, 15, -91), wall)
	slab(map, "TiendaLadoW", -30, -28, -128, -122, 16, wall)
	slab(map, "TiendaLadoW", -30, -28, -110, -92, 16, wall)
	block(map, "TiendaDintelW", Vector3.new(2, 2, 12), Vector3.new(-29, 15, -116), wall)
	slab(map, "TiendaLadoE", 28, 30, -128, -122, 16, wall)
	slab(map, "TiendaLadoE", 28, 30, -110, -92, 16, wall)
	block(map, "TiendaDintelE", Vector3.new(2, 2, 12), Vector3.new(29, 15, -116), wall)
	block(map, "TiendaTecho", Vector3.new(60, 1, 38), Vector3.new(0, 16.5, -109), C.concreto, Enum.Material.CorrodedMetal) -- de z -128 a -90: sin tocar el plano de la fachada (z -130)
	floor(map, "TiendaPiso", -28, 28, -128, -92, Color3.fromRGB(214, 198, 166), Enum.Material.Slate)

	-- Bloques a los lados de la tienda (por aquí llegarán luego el callejón y la escalera)
	slab(map, "TiendaBloqueW", -60, -30, -130, -122, 20, C.mostaza)
	slab(map, "TiendaBloqueW", -60, -30, -110, -90, 20, C.mostaza)
	floor(map, "TiendaSalidaW", -60, -28, -122, -110, C.acera)
	slab(map, "TiendaBloqueE", 30, 60, -130, -122, 20, C.lima)
	slab(map, "TiendaBloqueE", 30, 60, -110, -90, 20, C.lima)
	floor(map, "TiendaSalidaE", 28, 60, -122, -110, C.acera)

	refs.safeEntryDoor = door(map, "SafeEntryDoor", -129, 24, 14)
	refs.safeExitDoor = door(map, "SafeExitDoor", -91, 24, 14)
	-- Salida oeste al Callejón del tramo 2 (se abre a la vez que la del norte)
	refs.safeExtraExits = { block(map, "SafeExitDoorW", Vector3.new(2, 14, 12), Vector3.new(-29, 7, -116), Color3.fromRGB(150, 110, 60), Enum.Material.DiamondPlate), block(map, "SafeExitDoorE", Vector3.new(2, 14, 12), Vector3.new(29, 7, -116), Color3.fromRGB(150, 110, 60), Enum.Material.DiamondPlate) }
	sign(map, "CartelCallejon2", "← CALLEJÓN", Vector3.new(8, 3, 0.4), Vector3.new(-20, 11, -92.3), C.amarillo, C.oscuro)
	sign(map, "CartelCalle2", "CALLE ↑", Vector3.new(8, 3, 0.4), Vector3.new(20, 11, -92.3), C.rojo)
	sign(map, "CartelEscalera2", "ESCALERA →", Vector3.new(8, 3, 0.4), CFrame.new(27.7, 11, -116) * CFrame.Angles(0, math.pi / 2, 0), C.azul)
	refs.safeVolume = volume(map, "SafeVolume", -28, 28, -128, -92, 12)
	refs.safeSpawn = CFrame.lookAt(Vector3.new(0, 3, -112), Vector3.new(0, 3, -90))

	-- Rótulos de la fachada (los anuncios van entre la puerta y el embudo, x de 12 a 20)
	sign(map, "RotuloTienda", "ABARROTES DOÑA ROSA", Vector3.new(26, 4.5, 0.4), Vector3.new(0, 17.6, -130.3), C.cobalto, C.blanco)
	sign(map, "AnuncioGaseosa", "GASEOSA HELADA", Vector3.new(7, 4, 0.4), Vector3.new(-16, 9, -130.3), C.terracota, C.blanco)
	sign(map, "AnuncioFrutas", "FRUTAS Y VERDURAS", Vector3.new(7, 4, 0.4), Vector3.new(16, 9, -130.3), C.lima, C.oscuro)

	-- Interior: mostrador, estantes, refrigeradores y costales (zona de descanso libre en el centro)
	block(map, "Mostrador", Vector3.new(3, 4, 14), Vector3.new(-21, 2, -110), C.madera, Enum.Material.Wood)
	block(map, "Estante", Vector3.new(2, 8, 10), Vector3.new(26, 4, -100), C.concreto, Enum.Material.Metal)
	block(map, "Refrigerador", Vector3.new(3, 7, 3), Vector3.new(-25.5, 3.5, -96), C.blanco, Enum.Material.SmoothPlastic)
	block(map, "Refrigerador", Vector3.new(3, 7, 3), Vector3.new(-25.5, 3.5, -124), C.blanco, Enum.Material.SmoothPlastic)
	sandbags(map, 24, -124, 0)
	crates(map, 21, -100)

	-- Botiquines sobre el mostrador (2 por punto seguro)
	for _, z in { -113, -107 } do
		local kit, kitPrompt = medkitPickup(map, Vector3.new(-21, 4, z))
		table.insert(refs.medkits, { model = kit, prompt = kitPrompt })
	end

	-- Estación de munición
	if LEGACY_SHOPS then
		local model, hitbox = PropModel.build(CajaMunicion, Vector3.new(25, 0, -108), math.rad(90))
		hitbox.Name = "AmmoStation"
		model.Parent = map
		label(hitbox, "AMMO", Color3.fromRGB(80, 165, 255), 18)
		table.insert(refs.ammoStations, { part = hitbox, model = model, prompt = prompt(hitbox, "Buy ammo", 0.5) })
	end

	-- Radio con la primera pista
	block(map, "MesaRadio", Vector3.new(4, 3, 2.5), Vector3.new(-25, 1.5, -102), C.madera, Enum.Material.Wood)
	deco(block(map, "RadioTienda", Vector3.new(2.4, 1.4, 1.2), Vector3.new(-25, 3.7, -102), C.oscuro, Enum.Material.Metal))
	sign(map, "Pista1", "El comandante dijo que el Refugio Remo todavía resiste", Vector3.new(9, 4, 0.4), CFrame.new(-27.7, 8, -102) * CFrame.Angles(0, -math.pi / 2, 0), C.blanco, C.oscuro)

	-- Luz interior: tenue (la lámpara y los tubos del techo dan poca luz) y antorchas en las paredes
	local lamp = deco(block(map, "Lampara", Vector3.new(4, 0.4, 1), Vector3.new(0, 15.7, -110), Color3.fromRGB(150, 120, 90), Enum.Material.SmoothPlastic))
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 0.25
	light.Color = Color3.fromRGB(255, 220, 180)
	light.Parent = lamp

	for _, x in { -16, 16 } do
		wallTorch(map, Vector3.new(x, 9.5, -127.4), Vector3.new(0, 0, 1)) -- pared norte (entrada), a los lados de la puerta
		wallTorch(map, Vector3.new(x, 9.5, -92.6), Vector3.new(0, 0, -1)) -- pared sur (salida)
	end
	wallTorch(map, Vector3.new(-27.4, 9.5, -125), Vector3.new(1, 0, 0)) -- paredes laterales, junto a las salidas
	wallTorch(map, Vector3.new(27.4, 9.5, -125), Vector3.new(-1, 0, 0))

	shopDetails(map, Random.new(31))

	-- Baliza de 30 de alto sobre el techo, con luz azul visible desde lejos
	deco(pole(map, "Baliza", Vector3.new(0, 17, -100), 27, 1, C.concreto))
	local beacon = deco(block(map, "BalizaLuz", Vector3.new(2.5, 3, 2.5), Vector3.new(0, 45.5, -100), C.azul, Enum.Material.Neon))
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = C.azul
	beaconLight.Range = 40
	beaconLight.Brightness = 3
	beaconLight.Parent = beacon
end

-- Cruce abierto hacia el Callejón desde la calle, la plaza o el atrio (fachada en faceX, hasta x = -60)
local function openCrossing(map, faceX, z)
	floor(map, "CrucePiso", -60, faceX, z - 4, z + 4, C.acera)
	floorArrow(map, Vector3.new(faceX - 5, 0, z), C.amarillo, -math.pi / 2)
	sign(map, "CartelCallejon", "← CALLEJÓN", Vector3.new(8, 3, 0.4), CFrame.new(faceX + 0.5, 9, z + 9) * CFrame.Angles(0, -math.pi / 2, 0), C.amarillo, C.oscuro)
end

-- Cruce abierto hacia la Escalera desde la calle, la plaza o el atrio (fachada en faceX, hasta x = 62)
local function openCrossingE(map, faceX, z)
	floor(map, "CrucePiso", faceX, 62, z - 4, z + 4, C.acera)
	floorArrow(map, Vector3.new(faceX + 5, 0, z), C.azul, math.pi / 2)
	sign(map, "CartelEscalera", "ESCALERA →", Vector3.new(8, 3, 0.4), CFrame.new(faceX - 0.5, 9, z + 9) * CFrame.Angles(0, math.pi / 2, 0), C.azul)
end

-- Parte 7: tramo 2, ruta Calle (roja). La calle sigue tras la tienda (z -90..-10), se abre en la plaza del generador
-- (z -10..110, x -50..50) y termina en el atrio de la iglesia (z 110..160). Los cruces hacia el Callejón y la Escalera
-- del tramo 2 (z -40, 40 y 120) están abiertos.
-- El generador abre la iglesia (punto seguro 2): GameState lo trata como el portón del mapa de siempre (refs.gate).

-- Fila de casas pegadas de 12 a 22 de largo entre z1 y z2, con la fachada en faceX mirando hacia faceDir
local function sideRow(map, rng, x1, x2, z1, z2, faceX, faceDir)
	local z = z1
	while z < z2 do
		local length = math.min(rng:NextInteger(12, 22), z2 - z)
		if z2 - (z + length) < 8 then
			length = z2 - z
		end
		building(map, rng, x1, x2, z, z + length, rng:NextNumber() < 0.35 and 26 or 17, faceX, faceDir)
		z += length
	end
end

-- Farol de plaza (12 de alto)
local function plazaLamp(map, x, z)
	deco(pole(map, "FarolPlaza", Vector3.new(x, 0, z), 12, 0.6, C.oscuro))
	Atmosphere.bulb(map, Vector3.new(x, 12.3, z))
end

local function bench(map, x, z, angle)
	block(map, "Banca", Vector3.new(6, 1.6, 1.6), CFrame.new(x, 0.8, z) * CFrame.Angles(0, math.rad(angle), 0), C.madera, Enum.Material.Wood)
end

local function deadTree(map, x, z)
	pole(map, "Arbol", Vector3.new(x, 0, z), 9, 1.4, C.tierra, Enum.Material.Wood)
	for i, angle in { 30, 150, 260 } do
		local cf = CFrame.new(x, 7 + i * 0.6, z) * CFrame.Angles(0, math.rad(angle), math.rad(40)) * CFrame.new(1.5, 0, 0)
		deco(block(map, "Rama", Vector3.new(3.5, 0.5, 0.5), cf, C.tierra, Enum.Material.Wood))
	end
end

local function buildTramo2Calle(map, refs, rng, spawns, config)
	-- Calle desde la tienda hasta la plaza
	floor(map, "Asfalto2", -30, 30, -90, -10, C.asfalto, Enum.Material.Asphalt)
	floor(map, "Acera2W", -35, -30, -90, -10, C.acera)
	floor(map, "Acera2E", 30, 35, -90, -10, C.acera)
	for _, side in { -1, 1 } do
		local x1, x2 = math.min(35 * side, 60 * side), math.max(35 * side, 60 * side)
		sideRow(map, rng, x1, x2, -90, -44, 35 * side, -side)
		sideRow(map, rng, x1, x2, -36, -10, 35 * side, -side)
		if side == -1 then
			openCrossing(map, -35, -40)
		else
			openCrossingE(map, 35, -40)
		end
		for _, z in { -70, -22 } do
			local top = Vector3.new(33 * side, 17, z)
			deco(pole(map, "Poste", Vector3.new(33 * side, 0, z), 18, 0.8, C.concreto, Enum.Material.Concrete))
			deco(block(map, "PosteBrazo", Vector3.new(3, 0.3, 0.3), top + Vector3.new(-side * 1.5, 0, 0), C.concreto))
			Atmosphere.bulb(map, top + Vector3.new(-side * 3, -0.4, 0))
		end
	end
	car(map, -12, -62, 20, C.mostaza)
	crates(map, 21, -52)
	container(map, -24, -28, 15)
	car(map, 14, -24, -70, C.cobalto)

	-- Plaza: adoquín, casas alrededor y cruces en z = 40
	floor(map, "Plaza", -50, 50, -10, 110, Color3.fromRGB(165, 160, 150), Enum.Material.Cobblestone)
	for _, side in { -1, 1 } do
		local x1, x2 = math.min(50 * side, 60 * side), math.max(50 * side, 60 * side)
		sideRow(map, rng, x1, x2, -10, 36, 50 * side, -side)
		sideRow(map, rng, x1, x2, 44, 110, 50 * side, -side)
		if side == -1 then
			openCrossing(map, -50, 40)
		else
			openCrossingE(map, 50, 40)
		end
	end
	-- Fuente rota en el centro
	pole(map, "Fuente", Vector3.new(0, 0, 50), 2, 12, C.concreto, Enum.Material.Concrete)
	deco(pole(map, "FuenteAgua", Vector3.new(0, 1.95, 50), 0.2, 10.4, Color3.fromRGB(28, 40, 46), Enum.Material.Glass))
	pole(map, "FuenteColumna", Vector3.new(0, 0, 50), 6, 1.6, C.blanco, Enum.Material.Concrete)
	deco(block(map, "FuenteTrozo", Vector3.new(2, 1, 1.4), CFrame.new(3.5, 2.5, 47.5) * CFrame.Angles(0.4, 0.6, 0.2), C.blanco))
	-- Monumento, bancas, árboles secos, faroles, kiosco, carros y puestos abandonados
	block(map, "Pedestal", Vector3.new(4, 4, 4), Vector3.new(-30, 2, 85), C.concreto)
	block(map, "Estatua", Vector3.new(1.6, 5, 1.6), Vector3.new(-30, 6.5, 85), C.oxido, Enum.Material.Metal)
	for _, b in { { -14, 36, 0 }, { 14, 36, 0 }, { -14, 64, 0 }, { 14, 64, 0 }, { -22, 50, 90 }, { 22, 50, 90 } } do
		bench(map, b[1], b[2], b[3])
	end
	deadTree(map, -40, 30)
	deadTree(map, 40, 72)
	deadTree(map, -40, 72)
	for _, lamp in { { -40, 10 }, { 40, 10 }, { -40, 92 }, { 40, 92 } } do
		plazaLamp(map, lamp[1], lamp[2])
	end
	block(map, "Kiosco", Vector3.new(8, 3, 8), Vector3.new(36, 1.5, 100), C.turquesa)
	deco(block(map, "KioscoTecho", Vector3.new(9, 0.5, 9), Vector3.new(36, 9, 100), C.oxido, Enum.Material.CorrodedMetal))
	for _, corner in { Vector3.new(-3.8, 0, -3.8), Vector3.new(3.8, 0, -3.8), Vector3.new(-3.8, 0, 3.8), Vector3.new(3.8, 0, 3.8) } do
		deco(pole(map, "KioscoPalo", Vector3.new(36, 0, 100) + corner, 9, 0.3, C.concreto))
	end
	car(map, -20, 15, 30, C.salmon)
	car(map, 18, 85, -20, C.lima)
	stall(map, -35, 60, C.lonaVerde)
	stall(map, 8, 10, C.lonaAzul)

	-- Generador (abre la iglesia) con cobertura alrededor
	local generatorModel, generator = PropModel.build(Generador, Vector3.new(30, 0, 40), 0)
	generator.Name = "Generator"
	generatorModel.Parent = map
	refs.generator = generator
	refs.generatorModel = generatorModel
	refs.generatorPrompt = prompt(generator, "Start generator", config.GeneratorHoldTime)
	label(generator, "GENERATOR", Color3.fromRGB(255, 155, 60))
	sandbags(map, 23, 34, 45)
	sandbags(map, 37, 47, 45)
	crates(map, 39, 33)

	-- Estación de munición (acera oeste de la plaza), botiquín en un puesto y caja de armas en la plaza
	if LEGACY_SHOPS then
		local model, hitbox = PropModel.build(CajaMunicion, Vector3.new(-47.5, 0, 20), math.rad(-90))
		hitbox.Name = "AmmoStation"
		model.Parent = map
		label(hitbox, "AMMO", Color3.fromRGB(80, 165, 255), 18)
		table.insert(refs.ammoStations, { part = hitbox, model = model, prompt = prompt(hitbox, "Buy ammo", 0.5) })
	end
	local kit, kitPrompt = medkitPickup(map, Vector3.new(-35, 3, 61.2))
	table.insert(refs.medkits, { model = kit, prompt = kitPrompt })
	if LEGACY_SHOPS then
	refs.boxSpots.Zone2 = { { Vector3.new(-30, 0, 45), Vector3.new(0, 0, 95), Vector3.new(20, 0, 0) } }
	end

	-- Atrio de la iglesia con su escalinata y cruces en z = 120
	floor(map, "Atrio", -30, 30, 110, 160, Color3.fromRGB(185, 180, 170), Enum.Material.Slate)
	for _, side in { -1, 1 } do
		local x1, x2 = math.min(30 * side, 60 * side), math.max(30 * side, 60 * side)
		sideRow(map, rng, x1, x2, 110, 116, 30 * side, -side)
		if side == -1 then
			openCrossing(map, -30, 120)
		else
			openCrossingE(map, 30, 120)
		end
		sideRow(map, rng, x1, x2, 124, 160, 30 * side, -side)
		plazaLamp(map, 25 * side, 132)
	end
	stairs(map, -20, 20, 126)

	-- Flechas rojas hacia la plaza y la iglesia
	for _, z in { -80, -30, 100, 150 } do
		floorArrow(map, Vector3.new(0, 0, z), C.rojo)
	end
end

-- Parte 10: punto seguro 2, la iglesia (z 160..200, x -30..30, 20 de alto, fachada de 30 y campanario de 40).
-- La reja de entrada (refs.gate) solo se abre al encender el generador.
local function buildChurch(map, refs)
	local wall = SAFE_WALL
	slab(map, "IglesiaFachadaW", -30, -12, 160, 162, 30, wall)
	slab(map, "IglesiaFachadaE", 12, 30, 160, 162, 30, wall)
	block(map, "IglesiaDintel", Vector3.new(24, 16, 2), Vector3.new(0, 22, 161), wall)
	deco(block(map, "Cruz", Vector3.new(1, 6, 0.6), Vector3.new(0, 33, 160.4), C.oscuro))
	deco(block(map, "Cruz", Vector3.new(4, 1, 0.6), Vector3.new(0, 34, 160.4), C.oscuro))
	slab(map, "IglesiaLadoW", -30, -28, 162, 198, 20, wall)
	slab(map, "IglesiaLadoE", 28, 30, 162, 198, 20, wall)
	slab(map, "IglesiaFondoW", -30, -12, 198, 200, 20, wall)
	slab(map, "IglesiaFondoE", 12, 30, 198, 200, 20, wall)
	block(map, "IglesiaFondoDintel", Vector3.new(24, 6, 2), Vector3.new(0, 17, 199), wall)
	block(map, "IglesiaTecho", Vector3.new(60, 1, 38), Vector3.new(0, 20.5, 181), C.oxido, Enum.Material.CorrodedMetal) -- de z 162 a 200: sin tocar el plano de la fachada (z 160), que parpadeaba
	floor(map, "IglesiaPiso", -28, 28, 162, 198, Color3.fromRGB(120, 90, 60), Enum.Material.WoodPlanks)
	slab(map, "IglesiaBloqueW", -60, -30, 160, 214, 20, C.salmon)
	slab(map, "IglesiaBloqueE", 30, 60, 160, 214, 20, C.turquesa)

	-- Campanario de 40 con la campana y la baliza azul encima
	slab(map, "Campanario", 31, 41, 149, 161, 40, wall)
	deco(pole(map, "Campana", Vector3.new(36, 40, 155), 3, 3, Color3.fromRGB(180, 140, 60), Enum.Material.Metal))
	deco(pole(map, "Baliza", Vector3.new(36, 43, 155), 24, 1, C.concreto))
	local beacon = deco(block(map, "BalizaLuz", Vector3.new(2.5, 3, 2.5), Vector3.new(36, 68.5, 155), C.azul, Enum.Material.Neon))
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = C.azul
	beaconLight.Range = 40
	beaconLight.Brightness = 3
	beaconLight.Parent = beacon

	refs.gate = door(map, "ChurchEntryDoor", 161, 24, 14)
	refs.gateText = { label = "IGLESIA", open = "open the iglesia", run = "to the iglesia" }
	refs.church = {
		exitDoor = door(map, "ChurchExitDoor", 199, 24, 14),
		volume = volume(map, "ChurchVolume", -28, 28, 162, 198, 12),
		spawn = CFrame.lookAt(Vector3.new(0, 3, 180), Vector3.new(0, 3, 200)),
	}

	-- Interior: altar con velas, bancas tiradas a los lados, vitrales; la nave central queda libre para descansar
	block(map, "Altar", Vector3.new(8, 3, 3), Vector3.new(0, 1.5, 194), wall)
	deco(block(map, "AltarMantel", Vector3.new(8.2, 0.1, 3.2), Vector3.new(0, 3.02, 194), C.rojo, Enum.Material.Fabric))
	for _, x in { -3.8, -0.6, 0.6, 3.8 } do
		deco(pole(map, "Vela", Vector3.new(x, 3, 195), 0.7, 0.3, Color3.fromRGB(255, 220, 150), Enum.Material.Neon))
	end
	for _, x in { -2.5, 2.5 } do
		local kit, kitPrompt = medkitPickup(map, Vector3.new(x, 3, 193.8))
		table.insert(refs.medkits, { model = kit, prompt = kitPrompt })
	end
	for i, z in { 172, 178, 184, 190 } do
		block(map, "Banca", Vector3.new(9, 1.6, 2), CFrame.new(-21.5, 0.8, z) * CFrame.Angles(0, math.rad(({ 0, 12, -8, 25 })[i]), 0), C.madera, Enum.Material.Wood)
	end
	for i, z in { 182, 188 } do
		block(map, "Banca", Vector3.new(9, 1.6, 2), CFrame.new(21.5, 0.8, z) * CFrame.Angles(0, math.rad(({ -15, 6 })[i]), 0), C.madera, Enum.Material.Wood)
	end
	for i, z in { 170, 182, 194 } do
		local color = ({ C.rojo, C.azul, C.amarillo })[i]
		for _, x in { -27.7, 27.7 } do -- el cristal sobresale 0.1 del marco de piedra (a 27.8 compartía plano con él y parpadeaba)
			deco(block(map, "Vitral", Vector3.new(0.3, 6, 3), Vector3.new(x, 11, z), color, Enum.Material.Neon)).Transparency = 0.3
		end
	end

	-- Munición, radio con la segunda pista y el cartel del barrio
	if LEGACY_SHOPS then
		local model, hitbox = PropModel.build(CajaMunicion, Vector3.new(25.5, 0, 170), math.rad(90))
		hitbox.Name = "AmmoStation"
		model.Parent = map
		label(hitbox, "AMMO", Color3.fromRGB(80, 165, 255), 18)
		table.insert(refs.ammoStations, { part = hitbox, model = model, prompt = prompt(hitbox, "Buy ammo", 0.5) })
	end
	block(map, "MesaRadio", Vector3.new(4, 3, 2.5), Vector3.new(-25, 1.5, 166), C.madera, Enum.Material.Wood)
	deco(block(map, "RadioIglesia", Vector3.new(2.4, 1.4, 1.2), Vector3.new(-25, 3.7, 166), C.oscuro, Enum.Material.Metal))
	sign(map, "Pista2", "Rhomulus cayó, pero el Refugio Remo sigue en pie", Vector3.new(9, 4, 0.4), CFrame.new(-27.7, 8, 166) * CFrame.Angles(0, -math.pi / 2, 0), C.blanco, C.oscuro)
	sign(map, "CartelIglesia", "AQUÍ NADIE SE QUEDA ATRÁS", Vector3.new(20, 4, 0.4), Vector3.new(0, 17, 197.6), C.mostaza, C.oscuro)

	churchDetails(map, Random.new(47))

	-- Luz cálida y estable (aquí se respira)
	for _, z in { 172, 188 } do
		local lamp = deco(block(map, "Lampara", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 17, z), Color3.fromRGB(255, 220, 160), Enum.Material.Neon))
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 140)
		light.Range = 30
		light.Brightness = 1.6
		light.Parent = lamp
	end
end

-- Parte 8: tramo 2, ruta Callejón (amarilla): la feria. Franja de x -120 a -60 entre la tienda y la iglesia.
-- Recorrido: salida oeste de la tienda -> patio -> callejón D1 -> mercado cubierto (las garrafas) -> D2 -> patio junto
-- al atrio de la iglesia. Cruces abiertos a la calle en z = -40, 40 (plaza) y 120 (atrio).
local MARKET_ROUTE = {
	{ "Patio2", -86, -60, -124, -108 },
	{ "D1", -86, -77, -108, -30 },
	{ "C1b", -77, -60, -44, -36 }, -- cruce hacia la calle
	{ "S4", -118, -86, -88, -60 }, -- callejón lateral: la Tienda del tramo 2 (buildShop)
	{ "Mercado", -118, -68, -30, 76 }, -- el mercado entero (muros, techo y puestos se ponen aparte)
	{ "C2b", -68, -60, 36, 44 }, -- cruce hacia la plaza
	{ "D2", -95, -86, 76, 112 },
	{ "S5", -112, -95, 80, 88 }, -- callejón lateral (sin salida)
	{ "Atrio2", -104, -60, 112, 128 }, -- patio junto al atrio (cruce en z = 120)
}
local MARKET_BAND = { x1 = -120, x2 = -60, z1 = -130, z2 = 214 }

-- Garrafa de gas naranja (1.5 × 3.5) con asa; se carga con E (server/GasCans)
local function gasCan(parent, position)
	local model = Instance.new("Model")
	model.Name = "Garrafa"
	local body = pole(model, "Cuerpo", position, 3.5, 1.5, C.lonaNaranja, Enum.Material.Metal)
	body.CanCollide = false
	body.CanTouch = false
	block(model, "Asa", Vector3.new(0.9, 0.4, 0.2), position + Vector3.new(0, 3.7, 0), C.oscuro, Enum.Material.Metal).CanCollide = false
	block(model, "Valvula", Vector3.new(0.4, 0.4, 0.4), position + Vector3.new(0, 3.6, 0.35), C.concreto, Enum.Material.Metal).CanCollide = false
	model.PrimaryPart = body
	label(body, "GAS CAN", C.lonaNaranja, 18)
	model.Parent = parent
	return model, body, prompt(body, "Carry gas can", 0.8)
end

---------------------------------------------------------------------------------------------------
-- Mercado cubierto (tramo 2, ruta Callejón): puestos temáticos con toldos rayados y carteles, mercancía, estantes
-- surtidos, vigas, tragaluces con haces de luna, guirnaldas de luces, banderines y un mosaico en el cruce central.
-- Todo es decoración sin colisión salvo los mostradores y los muros de siempre.

local MARKET_PLASTER = Color3.fromRGB(184, 146, 104)
local MARKET_DARK = Color3.fromRGB(58, 48, 44)
local MARKET_GLOW = { Color3.fromRGB(255, 214, 140), Color3.fromRGB(255, 214, 140), Color3.fromRGB(255, 214, 140), Color3.fromRGB(255, 120, 150), Color3.fromRGB(130, 220, 255), Color3.fromRGB(190, 240, 120) }
local FABRICS = { C.lonaAzul, C.grafiti, C.mostaza, C.terracota, C.turquesa, C.lima, C.salmon }

local function ball(parent, name, position, diameter, color, material)
	local b = deco(block(parent, name, Vector3.new(diameter, diameter, diameter), position, color, material or Enum.Material.SmoothPlastic))
	b.Shape = Enum.PartType.Ball
	return b
end

-- Cartel de puesto: marco negro, tarjeta de color y el nombre en Oswald (mismo estilo que los de ruta)
local function stallSign(parent, cframe, width, text, color)
	local _, gui = blankBoard(parent, "CartelPuesto", Vector3.new(width, 1.8, 0.2), cframe, RHO_BLACK, 60)
	boardRect(gui, 0.03, 0.1, 0.94, 0.8, color)
	boardText(gui, text, 0.05, 0.1, 0.9, 0.8, RHO_BLACK, Enum.TextXAlignment.Center)
end

-- Mercancía sobre el mostrador de un puesto, repartida en `slots` huecos a lo largo de z
local function stallGoods(folder, kind, x, z1, z2, canvas, rng)
	local length = z2 - z1
	local slots = math.max(2, math.floor((length - 1) / 2.5))
	local top = 3.15
	for k = 1, slots do
		local z = z1 + 1.4 + (k - 1) * (length - 2.8) / (slots - 1)
		local side = (k % 2 == 0) and 1.2 or -1.2
		if kind == "fruta" then
			deco(block(folder, "CajaFruta", Vector3.new(1.9, 0.9, 1.9), Vector3.new(x + side, top + 0.45, z), C.madera, Enum.Material.WoodPlanks))
			for i = 1, 3 do
				ball(folder, "Fruta", Vector3.new(x + side + rng:NextNumber(-0.5, 0.5), top + 1.05, z + rng:NextNumber(-0.5, 0.5)), 0.85, ({ C.rojo, C.lonaNaranja, C.lima, C.mostaza })[rng:NextInteger(1, 4)])
			end
		elseif kind == "verdura" then
			deco(pole(folder, "Canasta", Vector3.new(x + side, top, z), 0.8, 1.7, C.madera, Enum.Material.Wood))
			ball(folder, "Repollo", Vector3.new(x + side - 0.3, top + 1.1, z), 1.1, C.lonaVerde, Enum.Material.Grass)
			ball(folder, "Tomate", Vector3.new(x + side + 0.4, top + 1, z + 0.3), 0.8, C.rojo)
			deco(block(folder, "Zanahoria", Vector3.new(0.3, 0.3, 1.5), CFrame.new(x - side, top + 0.2, z) * CFrame.Angles(0, rng:NextNumber() * 0.6, 0), C.lonaNaranja, Enum.Material.SmoothPlastic))
		elseif kind == "telas" then
			deco(pole(folder, "RolloTela", Vector3.new(x + side, top, z), 2.6, 0.9, FABRICS[rng:NextInteger(1, #FABRICS)], Enum.Material.Fabric))
			deco(pole(folder, "RolloTela", Vector3.new(x + side * 0.2, top, z + 0.8), 1.8, 0.8, FABRICS[rng:NextInteger(1, #FABRICS)], Enum.Material.Fabric))
			deco(block(folder, "TelaColgada", Vector3.new(0.15, 3.2, 1.1), Vector3.new(x + (k % 2 == 0 and 3.2 or -3.2), 6, z), FABRICS[rng:NextInteger(1, #FABRICS)], Enum.Material.Fabric))
		elseif kind == "ceramica" then
			deco(pole(folder, "Olla", Vector3.new(x + side, top, z), 1.2, 1.5, C.terracota, Enum.Material.Pebble))
			deco(pole(folder, "Olla", Vector3.new(x + side, top + 1.2, z), 0.9, 1.1, C.salmon, Enum.Material.Pebble))
			deco(pole(folder, "Plato", Vector3.new(x - side, top, z), 0.15, 1.8, C.blanco, Enum.Material.SmoothPlastic))
		elseif kind == "especias" then
			for i = 1, 3 do
				deco(pole(folder, "Especia", Vector3.new(x + (i - 2) * 1.4, top, z + (i - 2) * 0.1), 0.5, 1.2, ({ C.rojo, C.mostaza, C.lima, C.terracota })[rng:NextInteger(1, 4)], Enum.Material.Sand))
			end
			deco(block(folder, "Aji", Vector3.new(0.25, 2.2, 0.25), Vector3.new(x + side * 2, 7, z), C.rojo, Enum.Material.SmoothPlastic))
		elseif kind == "gas" then
			deco(pole(folder, "GasDecoracion", Vector3.new(x + side, top, z), 2.2, 1, Color3.fromRGB(80, 118, 170), Enum.Material.Metal))
			deco(pole(folder, "GasCuello", Vector3.new(x + side, top + 2.2, z), 0.4, 0.5, C.concreto, Enum.Material.Metal))
		elseif kind == "abarrotes" then
			deco(block(folder, "Saco", Vector3.new(1.5, 1.9, 1.2), CFrame.new(x + side, top + 0.95, z) * CFrame.Angles(0, rng:NextNumber() * 0.5, 0), Color3.fromRGB(204, 184, 140), Enum.Material.Fabric))
			deco(pole(folder, "Lata", Vector3.new(x - side, top, z - 0.4), 0.7, 0.6, C.rojo))
			deco(pole(folder, "Lata", Vector3.new(x - side, top, z + 0.4), 0.7, 0.6, C.lima))
			deco(block(folder, "CajaCereal", Vector3.new(0.9, 1.3, 0.4), Vector3.new(x - side, top + 0.65, z + 0.9), C.mostaza, Enum.Material.Cardboard))
		elseif kind == "pan" then
			deco(block(folder, "Bandeja", Vector3.new(2.2, 0.2, 1.5), Vector3.new(x + side, top + 0.1, z), C.madera, Enum.Material.Wood))
			for i = -1, 1 do
				deco(block(folder, "Pan", Vector3.new(1.3, 0.6, 0.5), CFrame.new(x + side, top + 0.5, z + i * 0.45) * CFrame.Angles(0, 0.1 * i, 0), Color3.fromRGB(196, 136, 64), Enum.Material.SmoothPlastic))
			end
		end
	end
end

-- Puesto del mercado: mostrador de largo `length` en Z (6 de ancho, 3 de alto), toldo rayado con postes, carteles y mercancía
local function marketStall(map, folder, x, z1, z2, canvas, kind, title, rng)
	local length = z2 - z1
	local zc = (z1 + z2) / 2
	block(map, "Mostrador", Vector3.new(6, 3, length), Vector3.new(x, 1.5, zc), C.madera, Enum.Material.WoodPlanks)
	deco(block(folder, "Mantel", Vector3.new(6.2, 0.15, length + 0.2), Vector3.new(x, 3.08, zc), canvas:Lerp(C.blanco, 0.35), Enum.Material.Fabric))
	for _, side in { -1, 1 } do
		deco(block(folder, "FaldonMostrador", Vector3.new(0.1, 1.7, length), Vector3.new(x + side * 3.05, 1.9, zc), canvas, Enum.Material.Fabric))
	end
	-- Toldo a rayas con postes
	local stripes = math.max(3, math.floor(length / 2.2))
	local span = length / stripes
	for i = 1, stripes do
		deco(block(folder, "ToldoRaya", Vector3.new(7.2, 0.25, span + 0.02), CFrame.new(x, 8.5, z1 + (i - 0.5) * span) * CFrame.Angles(0, 0, math.rad(8)), i % 2 == 1 and canvas or C.blanco, Enum.Material.Fabric))
	end
	for _, dx in { -3.4, 3.4 } do
		for _, dz in { z1 + 0.4, z2 - 0.4 } do
			deco(pole(folder, "PuestoPalo", Vector3.new(x + dx, 0, dz), 8.7, 0.3, C.oxido, Enum.Material.Metal))
		end
	end
	-- Carteles en los dos extremos (se leen al caminar por el pasillo en cualquier sentido)
	stallSign(folder, CFrame.new(x, 7.3, z1 - 0.15), 6.4, title, canvas)
	stallGoods(folder, kind, x, z1, z2, canvas, rng)
end

-- Cuerda con bombillas de colores que cuelga de pared a pared (a lo ancho en X)
local function lightString(folder, z, xFrom, xTo, y, sag, count, rng)
	local points = {}
	for k = 0, count do
		local t = k / count
		points[k] = Vector3.new(xFrom + (xTo - xFrom) * t, y - sag * (1 - (2 * t - 1) ^ 2), z)
	end
	for k = 1, count do
		local a, b = points[k - 1], points[k]
		deco(block(folder, "CableLuces", Vector3.new(0.1, 0.1, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), C.oscuro))
		if k < count then
			deco(block(folder, "BombillaFeria", Vector3.new(0.5, 0.65, 0.5), b - Vector3.new(0, 0.4, 0), MARKET_GLOW[rng:NextInteger(1, #MARKET_GLOW)], Enum.Material.Neon))
		end
	end
end

-- Cuerda de banderines a lo largo de Z (rombos de colores)
local function pennants(folder, x, zFrom, zTo, y, rng)
	deco(block(folder, "CuerdaBanderines", Vector3.new(0.1, 0.1, zTo - zFrom), Vector3.new(x, y, (zFrom + zTo) / 2), C.oscuro))
	local colors = { C.rojo, C.mostaza, C.lonaAzul, C.lima, C.grafiti, C.turquesa }
	local i = 0
	for z = zFrom + 2, zTo - 1, 3.4 do
		i += 1
		deco(block(folder, "Banderin", Vector3.new(1.2, 1.2, 0.06), CFrame.new(x, y - 0.7, z) * CFrame.Angles(0, 0, math.rad(45)), colors[i % #colors + 1], Enum.Material.Fabric))
	end
end

-- Medidas del salón del mercado (más grande y con más espacio entre puestos)
local HALL = { x1 = -118, x2 = -68, z1 = -30, z2 = 76 }
HALL.cx = (HALL.x1 + HALL.x2) / 2
HALL.cz = (HALL.z1 + HALL.z2) / 2
HALL.width = HALL.x2 - HALL.x1
HALL.length = HALL.z2 - HALL.z1
local STALL_COLUMNS = { west = -102, east = -84 } -- ejes de las dos filas de puestos (mostradores de 6 de ancho)
local STALL_SEGMENTS = { { -22, -8 }, { 2, 16 }, { 26, 40 }, { 50, 64 } } -- cuatro puestos por fila, pasillos cruzados de 10

local function marketDetails(map, rng)
	local folder = Instance.new("Folder")
	folder.Name = "MercadoDetalles"
	folder.Parent = map

	-- Tragaluces: el techo se parte en paneles con rendijas por donde cae la luz de la luna (haces translúcidos)
	local roofY = 14.3
	local gaps = { -15, 5, 25, 45, 65 }
	local from = HALL.z1
	for _, gap in gaps do
		block(map, "MercadoTecho", Vector3.new(HALL.width, 0.6, gap - 2 - from), Vector3.new(HALL.cx, roofY, (from + gap - 2) / 2), C.oxido, Enum.Material.CorrodedMetal)
		from = gap + 2
		local shaft = deco(block(folder, "HazLuna", Vector3.new(HALL.width - 14, 14, 3.2), CFrame.new(HALL.cx, 7, gap) * CFrame.Angles(math.rad(10), 0, 0), Color3.fromRGB(170, 195, 255), Enum.Material.Neon))
		shaft.Transparency = 0.93
	end
	block(map, "MercadoTecho", Vector3.new(HALL.width, 0.6, HALL.z2 - from), Vector3.new(HALL.cx, roofY, (from + HALL.z2) / 2), C.oxido, Enum.Material.CorrodedMetal)

	-- Vigas del techo: cerchas con tirante y colgantes, y dos largueros
	for z = -22, 70, 12 do
		deco(block(folder, "Cercha", Vector3.new(HALL.width, 0.7, 0.8), Vector3.new(HALL.cx, 12.4, z), MARKET_DARK, Enum.Material.Metal))
		for _, dx in { -16, 0, 16 } do
			deco(block(folder, "CerchaColgante", Vector3.new(0.4, 1.5, 0.4), Vector3.new(HALL.cx + dx, 13.35, z), MARKET_DARK, Enum.Material.Metal))
		end
	end
	for _, x in { -108, -78 } do
		deco(block(folder, "Larguero", Vector3.new(0.9, 0.9, HALL.length - 4), Vector3.new(x, 13.4, HALL.cz), MARKET_DARK, Enum.Material.Metal))
	end

	-- Guirnaldas de bombillas (sobre los pasillos cruzados) y banderines
	for _, z in { -3, 21, 45 } do
		lightString(folder, z, HALL.x1 + 0.6, HALL.x2 - 0.6, 11.8, 1.8, 10, rng)
	end
	pennants(folder, -112, HALL.z1 + 4, HALL.z2 - 2, 10.6, rng)
	pennants(folder, -74, HALL.z1 + 4, 34, 10.6, rng)

	-- Farolillos (de noche son lo único que alumbra dentro): una cuadrícula sobre los pasillos
	for _, x in { -111, -93, -75 } do
		for _, z in { -24, 0, 21, 45, 70 } do
			Atmosphere.bulb(map, Vector3.new(x, 12.2, z))
		end
	end

	-- Dado de azulejos y moldura en los muros sur y norte; pilastras entre medio
	for _, wallSpec in {
		{ HALL.x1 + 2, -86, HALL.z1 + 2.1, 1 }, { -77, HALL.x2, HALL.z1 + 2.1, 1 },
		{ HALL.x1 + 2, -95, HALL.z2 - 0.1, -1 }, { -86, HALL.x2, HALL.z2 - 0.1, -1 },
	} do
		local x1, x2, z, dir = wallSpec[1], wallSpec[2], wallSpec[3], wallSpec[4]
		local cx, w = (x1 + x2) / 2, x2 - x1
		deco(block(folder, "Azulejo", Vector3.new(w, 3.4, 0.15), Vector3.new(cx, 1.7, z), Color3.fromRGB(44, 110, 96), Enum.Material.Marble))
		deco(block(folder, "AzulejoRemate", Vector3.new(w, 0.35, 0.25), Vector3.new(cx, 3.5, z), C.blanco, Enum.Material.SmoothPlastic))
		deco(block(folder, "FranjaMercado", Vector3.new(w, 0.5, 0.2), Vector3.new(cx, 11.5, z), C.terracota, Enum.Material.SmoothPlastic))
		for px = x1 + 2, x2 - 1, 10 do
			deco(block(folder, "Pilastra", Vector3.new(1.4, 14, 0.9), Vector3.new(px, 7, z - dir * 0.15), MARKET_PLASTER:Lerp(C.concreto, 0.5), Enum.Material.Concrete))
		end
	end

	-- Estantes surtidos en los muros oeste y este: tablas y hileras de frascos, cajas y latas
	local palette = { C.rojo, C.lima, C.mostaza, C.lonaAzul, C.terracota, C.blanco, C.turquesa }
	for _, wallSpec in { { -113.2, -26, 72 }, { -72.8, -26, 32 }, { -72.8, 48, 72 } } do
		local x, zFrom, zTo = wallSpec[1], wallSpec[2], wallSpec[3]
		for _, y in { 2.2, 4.4 } do
			deco(block(folder, "TablaEstante", Vector3.new(1.6, 0.2, zTo - zFrom), Vector3.new(x, y, (zFrom + zTo) / 2), C.madera, Enum.Material.WoodPlanks))
			for z = zFrom + 2, zTo - 2, 6 do
				local h = rng:NextNumber(0.7, 1.6)
				local kind = rng:NextInteger(1, 3)
				if kind == 1 then
					deco(block(folder, "FrascoHilera", Vector3.new(1, h, 3.4), Vector3.new(x, y + 0.1 + h / 2, z), palette[rng:NextInteger(1, #palette)], Enum.Material.Glass)).Transparency = 0.25
				elseif kind == 2 then
					deco(block(folder, "CajasHilera", Vector3.new(1.2, h, 3.6), Vector3.new(x, y + 0.1 + h / 2, z), palette[rng:NextInteger(1, #palette)], Enum.Material.Cardboard))
				else
					deco(block(folder, "LatasHilera", Vector3.new(0.9, h * 0.8, 3.2), Vector3.new(x, y + 0.1 + h * 0.4, z), palette[rng:NextInteger(1, #palette)], Enum.Material.Metal))
				end
			end
		end
	end

	-- Mosaico circular en el pasillo cruzado del centro y franjas de color en los pasillos laterales
	do
		local at = Vector3.new(HALL.cx - 1.5, FLOOR_TOP + 0.02, 21)
		for i, ring in { { 9, C.terracota }, { 7.4, C.blanco }, { 5.6, C.cobalto }, { 3.6, C.mostaza }, { 1.6, C.rojo } } do
			deco(pole(folder, "Mosaico", at + Vector3.new(0, i * 0.005, 0), 0.04, ring[1], ring[2], Enum.Material.SmoothPlastic))
		end
		for k = 0, 7 do
			deco(block(folder, "MosaicoRayo", Vector3.new(0.3, 0.05, 4), CFrame.new(at.X, at.Y + 0.05, at.Z) * CFrame.Angles(0, k * math.pi / 4, 0) * CFrame.new(0, 0, 2.6), C.blanco, Enum.Material.SmoothPlastic))
		end
		for _, x in { -111, -75 } do
			deco(block(folder, "FranjaPasillo", Vector3.new(0.5, 0.05, HALL.length - 8), Vector3.new(x, FLOOR_TOP + 0.03, HALL.cz), C.terracota, Enum.Material.SmoothPlastic))
		end
	end

	-- Suelo: charcos, cajas caídas con fruta, sacos y carretillas (todo en los pasillos, lejos de las garrafas)
	for _, spot in { { -112, -18, 4 }, { -76, 6, 3 }, { -93, 34, 4.5 }, { -110, 56, 3 }, { -74, 62, 3.5 }, { -93, -22, 3 } } do
		deco(pole(folder, "Charco", Vector3.new(spot[1], FLOOR_TOP + 0.03, spot[2]), 0.03, spot[3], Color3.fromRGB(32, 46, 62), Enum.Material.Glass)).Transparency = 0.3
	end
	local gasSpots = { Vector3.new(-113, 0, -3), Vector3.new(-113, 0, 45), Vector3.new(-93, 0, 10), Vector3.new(-93, 0, 58), Vector3.new(-73, 0, -3), Vector3.new(-73, 0, 32) }
	local aisles = { { -113, -108 }, { -96, -90 }, { -78, -72 } }
	local placed = 0
	for _ = 1, 60 do
		if placed >= 8 then
			break
		end
		local aisle = aisles[rng:NextInteger(1, #aisles)]
		local x, z = rng:NextNumber(aisle[1], aisle[2]), rng:NextNumber(-26, 72)
		local clear = (Vector3.new(x, 0, z) - Vector3.new(HALL.cx - 1.5, 0, 21)).Magnitude > 7.5
		for _, spot in gasSpots do
			if (Vector3.new(x, 0, z) - spot).Magnitude < 4 then
				clear = false
			end
		end
		if clear then
			placed += 1
			deco(block(folder, "CajaCaida", Vector3.new(1.8, 0.9, 1.8), CFrame.new(x, 0.45, z) * CFrame.Angles(0, rng:NextNumber() * 3, 0), C.madera, Enum.Material.WoodPlanks))
			ball(folder, "FrutaRodada", Vector3.new(x + rng:NextNumber(-1.5, 1.5), 0.4, z + rng:NextNumber(-1.5, 1.5)), 0.8, ({ C.rojo, C.lonaNaranja, C.lima })[rng:NextInteger(1, 3)])
		end
	end
	for _, cart in { { -112, 14, 90 }, { -73, 52, 80 }, { -112, -22, 100 } } do -- carretillas de mano
		local base = CFrame.new(cart[1], 0, cart[2]) * CFrame.Angles(0, math.rad(cart[3]), 0)
		deco(block(folder, "CarretillaCaja", Vector3.new(2.4, 1, 3.4), base * CFrame.new(0, 1.7, 0), C.lonaVerde, Enum.Material.Metal))
		deco(block(folder, "CarretillaMango", Vector3.new(0.2, 0.2, 3), base * CFrame.new(0, 2.3, 3) * CFrame.Angles(math.rad(-12), 0, 0), C.madera, Enum.Material.Wood))
		deco(pole(folder, "CarretillaRueda", Vector3.new(0, 0, 0), 0.5, 1.8, C.oscuro, Enum.Material.Rubber)).CFrame = base * CFrame.new(0, 0.9, -1.4) * CFrame.Angles(0, 0, math.pi / 2)
	end
	for _, sack in { { -114.5, -24 }, { -114.5, 70 }, { -70.8, 30 } } do
		deco(block(folder, "SacoPiso", Vector3.new(1.6, 1.8, 1.2), CFrame.new(sack[1], 0.9, sack[2]) * CFrame.Angles(0, rng:NextNumber() * 0.7, 0), Color3.fromRGB(204, 184, 140), Enum.Material.Fabric))
	end

	-- Entrada sur: rótulo grande y toldo de colores sobre la puerta
	do
		local _, gui = blankBoard(folder, "RotuloMercado", Vector3.new(24, 5.6, 0.4), CFrame.new(-102, 10, -30.3), RHO_BLACK, 40)
		boardRect(gui, 0.02, 0.06, 0.96, 0.88, RHO_YELLOW)
		boardText(gui, "MERCADO LA ESPERANZA", 0.04, 0.08, 0.92, 0.6, RHO_BLACK, Enum.TextXAlignment.Center)
		boardRect(gui, 0.06, 0.7, 0.88, 0.016, RHO_BLACK)
		boardText(gui, "FERIA DEL BARRIO · HOY SE VENDE DE TODO", 0.06, 0.74, 0.88, 0.18, RHO_BLACK, Enum.TextXAlignment.Center)
		for i = 0, 8 do
			deco(block(folder, "ToldoPuerta", Vector3.new(1, 0.25, 4), CFrame.new(-85.5 + i * 1, 10.2 - i * 0.02, -31.8) * CFrame.Angles(math.rad(-14), 0, 0), i % 2 == 0 and C.rojo or C.blanco, Enum.Material.Fabric))
		end
	end
end

local function buildMarket(map, refs, rng, spawns)
	local rects = {}
	for _, r in MARKET_ROUTE do
		rects[r[1]] = r
	end
	local neighbors = { { "Tienda", -60, -30, -122, -110 }, { "Cruce", -60, -35, -44, -36 }, { "Cruce", -60, -50, 36, 44 }, { "Cruce", -60, -30, 116, 124 } }
	local function isOpen(x, z)
		return inRects(MARKET_ROUTE, x, z) or inRects(neighbors, x, z)
	end

	for _, r in MARKET_ROUTE do
		local inside = r[1] == "Mercado"
		floor(map, "Piso" .. r[1], r[2], r[3], r[4], r[5], inside and Color3.fromRGB(104, 98, 92) or C.acera, inside and Enum.Material.Cobblestone or Enum.Material.Concrete)
	end
	fillHouses(map, rng, MARKET_BAND, MARKET_ROUTE, isOpen)
	buildShop(map, refs, { origin = Vector3.new(-87, 0, -74), forward = Vector3.new(-1, 0, 0), width = 28, depth = 30, zone = "Zone2" })

	-- Mercado cubierto: muros de 14 con tres puertas (sur, norte y este); el techo lo pone marketDetails
	local wall = MARKET_PLASTER
	slab(map, "MercadoMuro", HALL.x1, -86, HALL.z1, HALL.z1 + 2, 14, wall)
	slab(map, "MercadoMuro", -77, HALL.x2, HALL.z1, HALL.z1 + 2, 14, wall)
	block(map, "MercadoDintel", Vector3.new(9, 4, 2), Vector3.new(-81.5, 12, HALL.z1 + 1), wall)
	slab(map, "MercadoMuro", HALL.x1, -95, HALL.z2 - 2, HALL.z2, 14, wall)
	slab(map, "MercadoMuro", -86, HALL.x2, HALL.z2 - 2, HALL.z2, 14, wall)
	block(map, "MercadoDintel", Vector3.new(9, 4, 2), Vector3.new(-90.5, 12, HALL.z2 - 1), wall)
	slab(map, "MercadoMuro", HALL.x1, HALL.x1 + 2, HALL.z1 + 2, HALL.z2 - 2, 14, wall)
	slab(map, "MercadoMuro", HALL.x2 - 2, HALL.x2, HALL.z1 + 2, 36, 14, wall)
	slab(map, "MercadoMuro", HALL.x2 - 2, HALL.x2, 44, HALL.z2 - 2, 14, wall)
	block(map, "MercadoDintel", Vector3.new(2, 4, 8), Vector3.new(HALL.x2 - 1, 12, 40), wall)

	-- Dentro: estanterías en los muros, dos filas de puestos con 10 de separación y pasillos de 9 a 12 de ancho
	block(map, "Estanteria", Vector3.new(2, 6, 98), Vector3.new(-115, 3, HALL.cz - 3), C.madera, Enum.Material.WoodPlanks)
	block(map, "Estanteria", Vector3.new(2, 6, 58), Vector3.new(-71, 3, 3), C.madera, Enum.Material.WoodPlanks)
	block(map, "Estanteria", Vector3.new(2, 6, 24), Vector3.new(-71, 3, 60), C.madera, Enum.Material.WoodPlanks)
	local canvases = { C.lonaAzul, C.lonaNaranja, C.lonaVerde }
	local marketRng = Random.new(77)
	local stallFolder = Instance.new("Folder")
	stallFolder.Name = "MercadoPuestos"
	stallFolder.Parent = map
	local westStalls = { { "fruta", "FRUTAS · DOÑA ROSA" }, { "telas", "TELAS Y RETAZOS" }, { "ceramica", "CERÁMICA DEL VALLE" }, { "especias", "ESPECIAS Y ADEREZOS" } }
	local eastStalls = { { "verdura", "VERDURAS DEL DÍA" }, { "gas", "GAS · LA GARRAFA" }, { "abarrotes", "ABARROTES DON PEPE" }, { "pan", "PAN CALIENTE" } }
	for i, segment in STALL_SEGMENTS do
		marketStall(map, stallFolder, STALL_COLUMNS.west, segment[1], segment[2], canvases[i % 3 + 1], westStalls[i][1], westStalls[i][2], marketRng)
		marketStall(map, stallFolder, STALL_COLUMNS.east, segment[1], segment[2], canvases[(i + 1) % 3 + 1], eastStalls[i][1], eastStalls[i][2], marketRng)
	end
	-- Jaulas (adorno, no tapan los pasillos)
	for _, cage in { { -113, -26 }, { -72, 74 }, { -114, 74 } } do
		deco(block(map, "Jaula", Vector3.new(2, 2, 2), Vector3.new(cage[1], 1, cage[2]), C.concreto, Enum.Material.DiamondPlate)).Transparency = 0.4
	end

	-- Fuera: franjas amarillas, lámparas de pared, tendederos y un mural
	for _, stripe in {
		{ Vector3.new(0.3, 1, 64), Vector3.new(-77.15, 6, -76) }, -- D1, pared este (hasta el cruce)
		{ Vector3.new(0.3, 1, 60), Vector3.new(-86.15, 6, 82) }, -- D2, pared este
	} do
		if SHOW.routeStripes then
			deco(block(map, "FranjaAmarilla", stripe[1], stripe[2], C.amarillo, Enum.Material.SmoothPlastic))
		end
	end
	for _, lamp in { { -77.4, 11, -95 }, { -77.4, 11, -60 }, { -86.4, 11, 84 }, { -86.4, 11, 100 }, { -80, 11, 127.6 } } do
		Atmosphere.bulb(map, Vector3.new(lamp[1], lamp[2], lamp[3]))
	end
	for _, line in { { -81.5, -85, 9 }, { -90.5, 95, 9 } } do
		local x, z, length = line[1], line[2], line[3]
		deco(block(map, "Tendedero", Vector3.new(length, 0.1, 0.1), Vector3.new(x, 9, z), C.blanco))
		for i, cloth in { C.grafiti, C.lima, C.lonaAzul, C.mostaza } do
			deco(block(map, "Ropa", Vector3.new(1.6, 2, 0.1), Vector3.new(x - length / 2 + i * length / 5, 8, z), cloth, Enum.Material.Fabric))
		end
	end
	sign(map, "Mural", "EL GAS SE COMPARTE", Vector3.new(12, 6, 0.4), CFrame.new(-85.7, 8, -77) * CFrame.Angles(0, -math.pi / 2, 0), C.lonaNaranja, C.blanco)

	-- Flechas amarillas del recorrido
	for _, arrow in {
		{ -66, -116, -math.pi / 2 },
		{ -81.5, -100, 0 },
		{ -81.5, -55, 0 },
		{ -90, 9, 0 },
		{ -90.5, 60, 0 },
		{ -90.5, 104, 0 },
		{ -80, 120, math.pi / 2 },
	} do
		floorArrow(map, Vector3.new(arrow[1], 0, arrow[2]), C.amarillo, arrow[3])
	end

	marketDetails(map, marketRng)

	-- Puntos de aparición: dos en el mercado y dos al fondo de los callejones laterales
	for _, point in { Vector3.new(-81.5, 0, -100), Vector3.new(-108, 0, 84), Vector3.new(-112, 0, 58), Vector3.new(-76, 0, -24) } do
		marker(spawns, point)
	end

	-- Botiquín en un puesto del medio, caja de armas en un pasillo cruzado
	local kit, kitPrompt = medkitPickup(map, Vector3.new(STALL_COLUMNS.west, 3, 9))
	table.insert(refs.medkits, { model = kit, prompt = kitPrompt })
	if LEGACY_SHOPS then
	table.insert(refs.boxSpots.Zone2, { Vector3.new(-93, 0, -24), Vector3.new(-93, 0, 70) })
	end

	-- Garrafas: 3 en 6 lugares posibles de los pasillos (GasCans las reparte al azar en cada partida)
	local spots = {
		Vector3.new(-113, 0, -3), Vector3.new(-113, 0, 45),
		Vector3.new(-93, 0, 10), Vector3.new(-93, 0, 58),
		Vector3.new(-73, 0, -3), Vector3.new(-73, 0, 32),
	}
	refs.gas = { cans = {}, spots = spots, marketPos = Vector3.new(HALL.cx, 6, HALL.cz), hordePoints = {} }
	for i = 1, Config.Gas.Count do
		local model, body, canPrompt = gasCan(map, spots[i])
		table.insert(refs.gas.cans, { model = model, body = body, prompt = canPrompt })
	end
end

-- Parte 9: tramo 2, ruta Escalera (azul): detrás de la iglesia. Franja de x 60 a 120 entre la tienda y la iglesia.
-- Recorrido: salida este de la tienda -> patio -> pasaje F1 -> F2 -> F3 (con el cementerio a un lado) -> atrio lateral
-- de 40 × 40 junto a la iglesia, que se junta con el atrio de la calle. Cruces abiertos a la calle en z = -40, 40 y 120.
-- Pocos zombies (2 puntos de aparición), más latas, un botiquín y una emboscada pequeña en el atrio.
local ESC2_ROUTE = {
	{ "Patio3", 60, 86, -124, -108 },
	{ "F1", 68, 78, -108, -30 },
	{ "A1e", 78, 86, -90, -82 }, -- alcoba sin salida (aparición)
	{ "A3e", 78, 86, -60, -52 }, -- alcoba sin salida (latas)
	{ "C1e", 60, 68, -44, -36 }, -- cruce hacia la calle
	{ "J1", 68, 96, -34, -20 },
	{ "F2", 86, 96, -20, 50 },
	{ "C2e", 60, 86, 36, 44 }, -- cruce hacia la plaza
	{ "F3", 86, 96, 50, 118 },
	{ "A2e", 76, 86, 80, 88 }, -- alcoba sin salida (aparición)
	{ "Cementerio", 96, 116, 70, 90 },
	{ "Atrio3", 62, 102, 118, 158 }, -- atrio lateral 40 × 40
	{ "C3e", 60, 66, 116, 124 }, -- cruce hacia el atrio de la calle
	{ "RampaT2a", 96, 104, -18, 6 }, -- azotea: rampa de subida, terraza y rampa de bajada
	{ "AzoteaT2", 96, 118, 6, 26 },
	{ "RampaT2b", 96, 104, 26, 50 },
}
local ESC2_BAND = { x1 = 60, x2 = 120, z1 = -130, z2 = 214 }

-- Lápida (cobertura baja) y cruz de madera
local function gravestone(map, x, z, angle)
	block(map, "Lapida", Vector3.new(1.8, 3, 0.7), CFrame.new(x, 1.5, z) * CFrame.Angles(0, math.rad(angle or 0), 0), C.concreto, Enum.Material.Slate)
end

local function woodenCross(map, x, z)
	deco(pole(map, "Cruz", Vector3.new(x, 0, z), 4, 0.4, C.madera, Enum.Material.Wood))
	deco(block(map, "Cruz", Vector3.new(2.4, 0.4, 0.4), Vector3.new(x, 3.2, z), C.madera, Enum.Material.Wood))
end

local function buildEscalera2(map, refs, rng, spawns)
	local rects = {}
	for _, r in ESC2_ROUTE do
		rects[r[1]] = r
	end
	local neighbors = { { "Tienda", 30, 60, -122, -110 }, { "Cruce", 35, 60, -44, -36 }, { "Cruce", 50, 60, 36, 44 }, { "Cruce", 30, 60, 116, 124 } }
	local function isOpen(x, z)
		return inRects(ESC2_ROUTE, x, z) or inRects(neighbors, x, z)
	end

	for _, r in ESC2_ROUTE do
		local grave = r[1] == "Cementerio"
		local plaza = r[1] == "Atrio3"
		local color = grave and Color3.fromRGB(70, 82, 60) or plaza and Color3.fromRGB(150, 145, 135) or C.acera
		floor(map, "Piso" .. r[1], r[2], r[3], r[4], r[5], color, grave and Enum.Material.Grass or plaza and Enum.Material.Slate or Enum.Material.Concrete)
	end
	fillHouses(map, rng, ESC2_BAND, ESC2_ROUTE, isOpen)

	-- Azotea de 10 de alto junto a F2, con el botiquín y latas arriba
	ramp(map, 96, 104, -18, 6, true)
	azotea(map, 96, 118, 6, 26)
	ramp(map, 96, 104, 26, 50, false)
	do
		local roofPile, roofPrompt = canPile(map, Vector3.new(112, ROOF_HEIGHT, 12))
		table.insert(refs.canPiles, { model = roofPile, prompt = roofPrompt, amount = Config.CanPiles.BigAmount })
		block(map, "CoberturaAzotea", Vector3.new(4, 2, 2), Vector3.new(106, ROOF_HEIGHT + 1, 20), C.tierra, Enum.Material.Fabric)
	end

	-- Escalones bajos en los pasajes
	stairs(map, 68, 78, -100)
	stairs(map, 86, 96, 10)
	stairs(map, 86, 96, 96)

	-- Cementerio: capilla, lápidas, cruces de madera y niebla baja
	block(map, "Capilla", Vector3.new(8, 12, 12), Vector3.new(112, 6, 80), C.blanco, Enum.Material.Concrete)
	deco(block(map, "CapillaTecho", Vector3.new(9, 0.6, 13), Vector3.new(112, 12.3, 80), C.oxido, Enum.Material.CorrodedMetal))
	deco(block(map, "CapillaPuerta", Vector3.new(0.3, 7, 4), Vector3.new(107.85, 3.5, 80), C.oscuro, Enum.Material.Wood))
	deco(block(map, "CapillaCruz", Vector3.new(0.4, 4, 0.4), Vector3.new(112, 14.5, 80), C.oscuro))
	deco(block(map, "CapillaCruz", Vector3.new(0.4, 0.4, 2.4), Vector3.new(112, 15.5, 80), C.oscuro))
	for i, x in { 100, 104 } do
		for j, z in { 73, 78, 83, 88 } do
			if (i + j) % 3 ~= 0 then
				gravestone(map, x, z, rng:NextInteger(-12, 12))
			end
		end
	end
	woodenCross(map, 99, 80)
	woodenCross(map, 105.5, 75.5)
	woodenCross(map, 106, 86)
	deadTree(map, 114, 72)
	deadTree(map, 98, 71)
	local fog = deco(block(map, "NieblaCementerio", Vector3.new(20, 1, 20), Vector3.new(106, 0.8, 80), C.blanco))
	fog.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Rate = 3
	emitter.Lifetime = NumberRange.new(7, 10)
	emitter.Speed = NumberRange.new(0.5, 1.2)
	emitter.SpreadAngle = Vector2.new(180, 10)
	emitter.Size = NumberSequence.new(14, 18)
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 1) })
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 165, 190))
	emitter.LightInfluence = 0.4
	emitter.Parent = fog

	-- Atrio lateral: bancas, árboles secos, faroles y cobertura
	for _, b in { { 72, 124, 0 }, { 92, 124, 0 }, { 72, 152, 0 } } do
		bench(map, b[1], b[2], b[3])
	end
	deadTree(map, 98, 128)
	deadTree(map, 66, 148)
	plazaLamp(map, 100, 120)
	plazaLamp(map, 64, 156)
	crates(map, 99, 132)
	sandbags(map, 84, 154, 0)
	car(map, 74, 146, 75, C.mostaza)

	-- Murales y carteles
	sign(map, "Mural", "AQUÍ DESCANSAN LOS NUESTROS", Vector3.new(14, 5, 0.4), Vector3.new(106, 9, 89.7), C.cobalto, C.blanco)
	sign(map, "Mural", "LA CAPILLA SIGUE ABIERTA", Vector3.new(12, 5, 0.4), CFrame.new(101.7, 8, 138) * CFrame.Angles(0, math.pi / 2, 0), C.turquesa, C.blanco)
	sign(map, "Mural", "NO TODO ESTÁ PERDIDO", Vector3.new(12, 5, 0.4), CFrame.new(77.7, 8, -70) * CFrame.Angles(0, math.pi / 2, 0), C.salmon, C.oscuro)
	sign(map, "CartelEscalera", "→ ESCALERA", Vector3.new(10, 4, 0.4), CFrame.new(73, 9, -123.7) * CFrame.Angles(0, math.pi, 0), C.azul)

	-- Franjas azules, lámparas de pared (de noche son las únicas luces) y tendederos
	for _, stripe in {
		{ Vector3.new(0.3, 1, 70), Vector3.new(68.15, 6, -73) }, -- F1, pared oeste
		{ Vector3.new(0.3, 1, 68), Vector3.new(95.85, 6, 84) }, -- F3, pared este
	} do
		if SHOW.routeStripes then
			deco(block(map, "FranjaAzul", stripe[1], stripe[2], C.azul, Enum.Material.SmoothPlastic))
		end
	end
	for _, lamp in { { 77.4, 11, -95 }, { 68.6, 11, -60 }, { 86.6, 11, 0 }, { 95.4, 11, 30 }, { 86.6, 11, 100 }, { 101.4, 11, 145 }, { 107.6, 9, 90 } } do
		Atmosphere.bulb(map, Vector3.new(lamp[1], lamp[2], lamp[3]))
	end
	for _, line in { { 73, -80, 10 }, { 91, 30, 10 } } do
		local x, z, length = line[1], line[2], line[3]
		deco(block(map, "Tendedero", Vector3.new(length, 0.1, 0.1), Vector3.new(x, 9, z), C.blanco))
		for i, cloth in { C.lonaNaranja, C.turquesa, C.blanco, C.grafiti } do
			deco(block(map, "Ropa", Vector3.new(1.6, 2, 0.1), Vector3.new(x - length / 2 + i * length / 5, 8, z), cloth, Enum.Material.Fabric))
		end
	end
	for _, arrow in {
		{ 66, -116, math.pi / 2 },
		{ 73, -100, 0 },
		{ 73, -50, 0 },
		{ 82, -25, math.pi / 2 },
		{ 91, 0, 0 },
		{ 91, 60, 0 },
		{ 91, 108, 0 },
		{ 68, 120, -math.pi / 2 },
	} do
		floorArrow(map, Vector3.new(arrow[1], 0, arrow[2]), C.azul, arrow[3])
	end
	barrel(map, 70, -70, C.lonaAzul)
	barrel(map, 94, 40, C.lonaVerde)
	barrel(map, 88, 112)

	-- Estación de munición (pared este de F1), botiquín sobre una mesa en F2 y caja de armas en el atrio
	if LEGACY_SHOPS then
		local model, hitbox = PropModel.build(CajaMunicion, Vector3.new(76.5, 0, -80), math.rad(90))
		hitbox.Name = "AmmoStation"
		model.Parent = map
		label(hitbox, "AMMO", Color3.fromRGB(80, 165, 255), 18)
		table.insert(refs.ammoStations, { part = hitbox, model = model, prompt = prompt(hitbox, "Buy ammo", 0.5) })
	end
	local kit, kitPrompt = medkitPickup(map, Vector3.new(106, ROOF_HEIGHT, 14)) -- el botiquín está en la azotea
	table.insert(refs.medkits, { model = kit, prompt = kitPrompt })
	if LEGACY_SHOPS then
	table.insert(refs.boxSpots.Zone2, { Vector3.new(84, 0, 130), Vector3.new(94, 0, 142), Vector3.new(76, 0, 134) })
	end

	-- Pocos puntos de aparición: dos alcobas sin salida
	marker(spawns, Vector3.new(84, 0, -86))
	marker(spawns, Vector3.new(78, 0, 84))

	-- Latas grandes: una en una alcoba, una en el cementerio y una en el atrio
	for _, position in { Vector3.new(82, 0, -56), Vector3.new(100, 0, 75.5), Vector3.new(97, 0, 150) } do
		local pileModel, pilePrompt = canPile(map, position)
		table.insert(refs.canPiles, { model = pileModel, prompt = pilePrompt, amount = Config.CanPiles.BigAmount })
	end

	-- Emboscada pequeña al pisar el atrio: apagón y mini-horda desde las esquinas del fondo
	local atrio = rects.Atrio3
	table.insert(refs.ambushesZone2, {
		volume = volume(map, "EmboscadaAtrio", atrio[2], atrio[3], atrio[4], atrio[5], 12),
		points = { Vector3.new(64, 0, 156), Vector3.new(100, 0, 156), Vector3.new(66, 0, 140) },
	})
end

-- Partes 12 y 13: tramo 3, rutas Callejón (la avenida lateral) y Escalera (los andenes). Salen de la explanada que hay
-- tras la iglesia por dos pasajes (z 218..226) y se juntan con la terminal por los cruces de z = 240, 280 y 320; el
-- último queda junto a la puerta del estadio. Los trazados se declaran aquí para que buildTerminal rellene con casas
-- todo lo que no es camino.
local AVENUE_WALK = {
	{ "CruceW", -72, -30, 218, 226 }, -- pasaje desde la explanada
	{ "Avenida", -112, -72, 214, 330 }, -- 40 de ancho, abierta
}
local ANDEN_WALK = {
	{ "CruceE", 30, 72, 218, 226 }, -- pasaje desde la explanada
	{ "AndenA", 72, 84, 214, 330 }, -- pasillo A (12 de ancho)
	{ "AndenB", 100, 112, 214, 330 }, -- pasillo B (12 de ancho)
	{ "AndenLink", 84, 100, 214, 222 }, -- unen A y B al norte
	{ "AndenOp1", 84, 100, 246, 254 }, -- salidas laterales entre los dos pasillos
	{ "AndenOp2", 84, 100, 286, 294 },
	{ "RampaT3", 84, 92, 296, 320 }, -- azotea: rampa de subida y terraza (sin salida)
	{ "AzoteaT3", 84, 100, 320, 330 },
}

-- Valla publicitaria (20 × 6) sobre dos postes; `face` = +1 mira al este, -1 al oeste
local function billboard(map, x, z, text, color, face)
	for _, dz in { -8, 8 } do
		deco(pole(map, "PosteValla", Vector3.new(x, 0, z + dz), 7, 0.6, C.concreto))
	end
	sign(map, "Valla", text, Vector3.new(20, 6, 0.4), CFrame.new(x, 9, z) * CFrame.Angles(0, -face * math.pi / 2, 0), color, C.blanco)
end

local function suitcase(map, x, z, color)
	deco(block(map, "Maleta", Vector3.new(2, 1.4, 1.2), CFrame.new(x, 0.7, z) * CFrame.Angles(0, math.rad((x * 7 + z * 3) % 90), 0), color, Enum.Material.Fabric))
end

local function buildAvenue(map, refs, rng, spawns)
	-- Pasto seco con vallas rotas por los bordes
	floor(map, "Avenida", -112, -72, 214, 330, C.pastoSeco, Enum.Material.Grass)
	floor(map, "CruceWPiso", -72, -30, 218, 226, C.acera)
	deco(block(map, "AvenidaSendero", Vector3.new(6, 0.06, 116), Vector3.new(-92, FLOOR_TOP + 0.04, 272), C.tierra, Enum.Material.Ground))
	for z = 218, 326, 12 do
		if rng:NextNumber() > 0.35 then
			deco(block(map, "Valla", Vector3.new(0.4, 3, 7), CFrame.new(-111.5, 1.5, z) * CFrame.Angles(0, 0, math.rad(rng:NextInteger(-12, 12))), C.madera, Enum.Material.WoodPlanks))
		end
	end
	billboard(map, -110, 240, "REFRESCOS LA ESPERANZA — ¡SIEMPRE FRESCOS!", C.lonaNaranja, 1)
	billboard(map, -110, 285, "CERVECERÍA EL CERRO", C.cobalto, 1)

	-- Carros chocados en fila, motos tiradas, postes caídos y cobertura baja cada 20 studs (siempre a ≥ 8 de los cruces)
	for i, z in { 226, 246, 266 } do
		car(map, -104, z, 90 + rng:NextInteger(-12, 12), ({ C.terracota, C.cobalto, C.mostaza, C.salmon, C.lima })[i])
	end
	for i, z in { 228, 248, 268, 288, 308 } do
		local x = -97 + (i % 3) * 7
		if i % 3 == 0 then
			sandbags(map, x, z, rng:NextInteger(0, 90))
		elseif i % 3 == 1 then
			container(map, x, z, rng:NextInteger(-20, 20))
		else
			crates(map, x, z)
		end
	end
	for _, moto in { { -88, 256, 70 }, { -84, 232, 100 } } do
		local cf = CFrame.new(moto[1], 0.6, moto[2]) * CFrame.Angles(0, math.rad(moto[3]), 0)
		deco(block(map, "Moto", Vector3.new(1.8, 1.2, 5.5), cf, C.rojo, Enum.Material.Metal))
	end
	deco(block(map, "PosteCaido", Vector3.new(18, 0.8, 0.8), CFrame.new(-90, 0.4, 276) * CFrame.Angles(0, math.rad(65), 0), C.concreto))
	for _, lamp in { { -76, 226 }, { -76, 266 }, { -76, 306 }, { -108, 252 } } do
		plazaLamp(map, lamp[1], lamp[2])
	end

	-- Carteles y flechas amarillas
	sign(map, "CartelAvenida", "← CALLEJÓN", Vector3.new(10, 3, 0.4), CFrame.new(-45, 9, 218.3) * CFrame.Angles(0, math.pi, 0), C.amarillo, C.oscuro)
	floorArrow(map, Vector3.new(-36, 0, 222), C.amarillo, -math.pi / 2)
	floorArrow(map, Vector3.new(-60, 0, 222), C.amarillo, -math.pi / 2)
	for _, z in { 236, 262, 296 } do
		floorArrow(map, Vector3.new(-88, 0, z), C.amarillo, 0)
	end
	floorArrow(map, Vector3.new(-66, 0, 320), C.amarillo, math.pi / 2)
	sign(map, "Mural", "LA AVENIDA ES DE TODOS", Vector3.new(16, 5, 0.4), Vector3.new(-92, 8, 329.7), C.mostaza, C.oscuro)

	-- La Tienda del tramo 3, en el rincón suroeste de la avenida (junto a la puerta del estadio)
	buildShop(map, refs, { origin = Vector3.new(-100, 0, 292), forward = Vector3.new(0, 0, 1), width = 24, depth = 36, zone = "Zone3" })

	-- Botiquín en una mesa, caja de armas, 4 puntos de aparición y 2 montones de latas de 75
	block(map, "Mesa", Vector3.new(3, 3, 3), Vector3.new(-80, 1.5, 300), C.madera, Enum.Material.Wood)
	local kit, kitPrompt = medkitPickup(map, Vector3.new(-80, 3, 300))
	table.insert(refs.medkits, { model = kit, prompt = kitPrompt })
	if LEGACY_SHOPS then
	table.insert(refs.boxSpots.Zone3, { Vector3.new(-92, 0, 276), Vector3.new(-84, 0, 240), Vector3.new(-92, 0, 316) })
	end
	for _, point in { Vector3.new(-108, 0, 220), Vector3.new(-76, 0, 222), Vector3.new(-76, 0, 326), Vector3.new(-82, 0, 329) } do
		marker(spawns, point)
	end
	for _, position in { Vector3.new(-108, 0, 264), Vector3.new(-80, 0, 276) } do
		local model, pilePrompt = canPile(map, position)
		table.insert(refs.canPiles, { model = model, prompt = pilePrompt, amount = Config.CanPiles.BigAmount })
	end

	-- Emboscada grande a mitad de la avenida (expuesta): sin Tanque
	table.insert(refs.ambushesZone3, {
		volume = volume(map, "EmboscadaAvenida", -112, -72, 270, 290, 12),
		points = { Vector3.new(-108, 0, 220), Vector3.new(-76, 0, 222), Vector3.new(-76, 0, 326), Vector3.new(-82, 0, 329) },
		size = Config.Ambush.FieldSize,
	})
end

local function buildAndenes(map, refs, rng, spawns)
	floor(map, "AndenA", 72, 84, 214, 330, Color3.fromRGB(110, 108, 104), Enum.Material.Concrete)
	floor(map, "AndenB", 100, 112, 214, 330, Color3.fromRGB(110, 108, 104), Enum.Material.Concrete)
	floor(map, "AndenLink", 84, 100, 214, 222, Color3.fromRGB(110, 108, 104), Enum.Material.Concrete)
	floor(map, "AndenOp", 84, 100, 246, 254, C.acera)
	floor(map, "AndenOp", 84, 100, 286, 294, C.acera)
	floor(map, "CruceEPiso", 30, 72, 218, 226, C.acera)

	-- Techo de lámina a 12 sobre los dos pasillos, con pilares y lámparas
	for _, x in { 78, 106 } do
		deco(block(map, "AndenTecho", Vector3.new(12, 0.6, 116), Vector3.new(x, 12.3, 272), C.oxido, Enum.Material.CorrodedMetal))
		for _, z in { 224, 248, 272, 296, 320 } do
			deco(pole(map, "AndenPilar", Vector3.new(x + (x == 78 and -5.4 or 5.4), 0, z), 12, 0.6, C.concreto))
		end
		for _, z in { 236, 272, 308 } do
			Atmosphere.bulb(map, Vector3.new(x, 11.5, z))
		end
	end

	-- Azotea de 10 de alto junto al estadio, con el botiquín y latas arriba (se baja por la misma rampa)
	ramp(map, 84, 92, 296, 320, true)
	azotea(map, 84, 100, 320, 330)
	do
		local roofPile, roofPrompt = canPile(map, Vector3.new(96, ROOF_HEIGHT, 325))
		table.insert(refs.canPiles, { model = roofPile, prompt = roofPrompt, amount = Config.CanPiles.BigAmount })
	end

	-- Torniquetes rotos (con colisión), bancas, maletas y escalones azules y blancos
	for _, z in { 247.2, 292.8 } do
		block(map, "Torniquete", Vector3.new(3, 4, 1.5), Vector3.new(90, 2, z), C.oscuro, Enum.Material.Metal)
	end
	for _, b in { { 82, 238, 90 }, { 102, 262, 90 }, { 82, 304, 90 }, { 102, 318, 90 } } do
		bench(map, b[1], b[2], b[3])
	end
	for i, s in { { 76, 230 }, { 80, 258 }, { 108, 244 }, { 104, 274 }, { 108, 300 }, { 74, 316 } } do
		suitcase(map, s[1], s[2], ({ C.cobalto, C.terracota, C.turquesa })[i % 3 + 1])
	end
	stairs(map, 72, 84, 266)
	stairs(map, 100, 112, 296)

	-- Carteles y flechas azules
	sign(map, "CartelAndenes", "ESCALERA →", Vector3.new(10, 3, 0.4), CFrame.new(45, 9, 218.3) * CFrame.Angles(0, math.pi, 0), C.azul)
	floorArrow(map, Vector3.new(36, 0, 222), C.azul, math.pi / 2)
	floorArrow(map, Vector3.new(60, 0, 222), C.azul, math.pi / 2)
	for _, z in { 236, 262, 300 } do
		floorArrow(map, Vector3.new(78, 0, z), C.azul, 0)
	end
	floorArrow(map, Vector3.new(66, 0, 320), C.azul, -math.pi / 2)
	sign(map, "PanelAndenes", "ANDÉN 1 · ANDÉN 2 · SOLO PASAJEROS", Vector3.new(14, 3, 0.4), CFrame.new(111.7, 9, 280) * CFrame.Angles(0, math.pi / 2, 0), C.cobalto, C.blanco)
	if SHOW.routeStripes then
		deco(block(map, "FranjaAzul", Vector3.new(0.3, 1, 116), Vector3.new(72.15, 6, 272), C.azul, Enum.Material.SmoothPlastic))
	end

	-- Botiquín en una mesa, caja de armas, 3 puntos de aparición y 2 montones de latas de 75
	local kit, kitPrompt = medkitPickup(map, Vector3.new(90, ROOF_HEIGHT, 327)) -- el botiquín está en la azotea
	table.insert(refs.medkits, { model = kit, prompt = kitPrompt })
	if LEGACY_SHOPS then
	table.insert(refs.boxSpots.Zone3, { Vector3.new(106, 0, 236), Vector3.new(78, 0, 290), Vector3.new(106, 0, 326) })
	end
	for _, point in { Vector3.new(106, 0, 222), Vector3.new(106, 0, 326), Vector3.new(78, 0, 326) } do
		marker(spawns, point)
	end
	for _, position in { Vector3.new(110, 0, 250), Vector3.new(74, 0, 306) } do
		local model, pilePrompt = canPile(map, position)
		table.insert(refs.canPiles, { model = model, prompt = pilePrompt, amount = Config.CanPiles.BigAmount })
	end

	-- Emboscada lineal en mitad del pasillo A: salen zombies de los dos extremos a la vez (sin Tanque)
	table.insert(refs.ambushesZone3, {
		volume = volume(map, "EmboscadaAndenes", 72, 84, 262, 282, 12),
		points = { Vector3.new(78, 0, 222), Vector3.new(78, 0, 326), Vector3.new(106, 0, 222), Vector3.new(106, 0, 326) },
		size = Config.Ambush.Size,
	})
end

-- Parte 11: tramo 3, ruta Calle (roja): la terminal de buses (z 200..330). La calle sale de la iglesia (apron de 60 de
-- ancho), se abre en la terminal (x -60..60) con 8 buses chocados en zigzag y termina en un área abierta de 40 × 40 donde
-- hay una emboscada con Tanque. Los cruces hacia la avenida (oeste) y los andenes (este) en z = 240, 280 y 320 son
-- nichos cerrados hasta que existan esas rutas. Al final está la puerta sur del estadio.
---------------------------------------------------------------------------------------------------
-- Terminal (camino al estadio) y estadio: casas favela en las fachadas, mucha más luz (farolas de pared, guirnaldas,
-- reflectores con luz real) y detalles. Todo decoración sin colisión salvo lo que ya existía.

-- Reflector con luz estable que apunta a un punto (no parpadea ni se apaga: sirve para ver los combates)
local function floodLight(parent, position, target, range, brightness)
	local part = deco(block(parent, "Reflector", Vector3.new(1.4, 1.4, 0.5), CFrame.lookAt(position, target), Color3.fromRGB(255, 246, 225), Enum.Material.Neon))
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 80
	light.Range = range
	light.Brightness = brightness
	light.Color = Color3.fromRGB(255, 236, 205)
	light.Parent = part
	return part
end

-- Cambia las casas de colores que dan a la terminal (o a la explanada) por casas favela y les pone una lámpara de pared
local function skinTerminalHouses(map)
	local list = {}
	for _, casa in map:GetChildren() do
		if casa:IsA("BasePart") and casa.Name == "Casa" and not casa:GetAttribute("Favela") then
			table.insert(list, casa)
		end
	end
	local skinned = 0
	for _, casa in list do
		local p, s = casa.Position, casa.Size
		local x1, x2, z1, z2 = p.X - s.X / 2, p.X + s.X / 2, p.Z - s.Z / 2, p.Z + s.Z / 2
		local faceX, faceDir
		if z2 > 232 and z1 < 330 and math.abs(x1 - 60) < 0.01 then
			faceX, faceDir = 60, -1
		elseif z2 > 232 and z1 < 330 and math.abs(x2 + 60) < 0.01 then
			faceX, faceDir = -60, 1
		elseif z1 >= 199.9 and z2 <= 232.1 and math.abs(x1 - 30) < 0.01 then
			faceX, faceDir = 30, -1
		elseif z1 >= 199.9 and z2 <= 232.1 and math.abs(x2 + 30) < 0.01 then
			faceX, faceDir = -30, 1
		end
		if faceX and z2 - z1 >= 8 then
			-- Quita lo que la casa vieja ponía encima: puertas, ventanas, techo y tanque
			for _, d in map:GetChildren() do
				if d:IsA("BasePart") and d ~= casa then
					local n = d.Name
					local inside = d.Position.X > x1 - 0.3 and d.Position.X < x2 + 0.3 and d.Position.Z > z1 - 0.3 and d.Position.Z < z2 + 0.3
					if inside and (n == "Puerta" or n == "Ventana" or n == "Techo" or n == "TanqueAgua") and d.Position.Y <= s.Y + 5 then
						d:Destroy()
					end
				end
			end
			local height = s.Y
			casa:Destroy()
			local entry = pickFavela(z2 - z1, height)
			lastFavela = entry
			slab(map, "Casa", x1, x2, z1, z2, entry.info.top * FAVELA_SCALE, entry.info.wallColor):SetAttribute("Favela", true)
			placeFavela(map, entry, x1, x2, z1, z2, faceX, faceDir)
			Atmosphere.bulb(map, Vector3.new(faceX + faceDir * 1.4, 10.5, (z1 + z2) / 2))
			skinned += 1
		end
	end
	return skinned
end

-- Luz y detalles del camino: reflectores en la arena del Tanque, guirnaldas, botes, conos, charcos y la portada de la terminal
local function terminalDetails(map, rng)
	local folder = Instance.new("Folder")
	folder.Name = "TerminalDetalles"
	folder.Parent = map

	-- Cuatro torres de reflectores alrededor del área de combate (luz estable hacia el centro)
	for _, spot in { { -24, 292 }, { 24, 292 }, { -24, 328 }, { 24, 328 } } do
		deco(pole(folder, "TorreLuz", Vector3.new(spot[1], 0, spot[2]), 16, 0.8, C.concreto, Enum.Material.Metal))
		deco(block(folder, "TorreLuzBrazo", Vector3.new(3.5, 0.4, 0.4), Vector3.new(spot[1] - math.sign(spot[1]) * 1.6, 16, spot[2]), C.concreto, Enum.Material.Metal))
		floodLight(folder, Vector3.new(spot[1] - math.sign(spot[1]) * 3, 16, spot[2]), Vector3.new(0, 1, 310), 60, 2.4)
	end

	-- Guirnaldas de bombillas sobre la terminal (de fachada a fachada)
	for _, z in { 246, 268, 290 } do
		lightString(folder, z, -58.5, 58.5, 15, 3, 14, rng)
	end

	-- Portada: pórtico con el rótulo de la terminal, visible al llegar desde la explanada
	do
		for _, x in { -15, 15 } do
			deco(block(folder, "PorticoPilar", Vector3.new(1.4, 17, 1.4), Vector3.new(x, 8.5, 234), C.concreto, Enum.Material.Concrete))
		end
		deco(block(folder, "PorticoViga", Vector3.new(32, 1.2, 1.6), Vector3.new(0, 17, 234), MARKET_DARK, Enum.Material.Concrete))
		local _, gui = blankBoard(folder, "RotuloTerminal", Vector3.new(26, 4.5, 0.4), CFrame.new(0, 14.2, 233.1), RHO_BLACK, 40)
		boardRect(gui, 0.02, 0.08, 0.96, 0.84, RHO_YELLOW)
		boardText(gui, "TERMINAL DE BUSES", 0.04, 0.1, 0.92, 0.8, RHO_BLACK, Enum.TextXAlignment.Center)
		for _, x in { -9, 0, 9 } do
			deco(block(folder, "PorticoLuz", Vector3.new(3, 0.3, 0.8), Vector3.new(x, 16.2, 232.8), Color3.fromRGB(255, 244, 220), Enum.Material.Neon))
		end
	end

	-- Caseta de boletos: toldo a rayas, ventanilla con marco y rótulo
	do
		local cx, cz = -45, 322
		for i = 0, 5 do
			deco(block(folder, "CasetaToldo", Vector3.new(1.5, 0.25, 3.2), CFrame.new(cx - 3.75 + i * 1.5, 7, cz - 5.2) * CFrame.Angles(math.rad(-14), 0, 0), i % 2 == 0 and C.rojo or C.blanco, Enum.Material.Fabric))
		end
		deco(block(folder, "CasetaMarco", Vector3.new(4.8, 3.2, 0.3), Vector3.new(cx, 4.5, cz - 4.1), SAFE_WOOD, Enum.Material.Wood))
		local _, gui = blankBoard(folder, "RotuloBoletos", Vector3.new(6, 1.6, 0.3), Vector3.new(cx, 8.3, cz - 4.2), RHO_BLACK, 50)
		boardRect(gui, 0.03, 0.1, 0.94, 0.8, RHO_YELLOW)
		boardText(gui, "BOLETOS", 0.05, 0.1, 0.9, 0.8, RHO_BLACK, Enum.TextXAlignment.Center)
		deco(block(folder, "CasetaLuz", Vector3.new(2.2, 0.3, 0.5), Vector3.new(cx, 8.8, cz - 4.4), Color3.fromRGB(255, 214, 150), Enum.Material.Neon))
	end

	-- Bordillo pintado a rayas rojas y blancas al pie de las fachadas, botes de basura, conos y charcos
	for _, side in { -1, 1 } do
		for z = 234, 326, 8 do
			deco(block(folder, "Bordillo", Vector3.new(0.7, 0.5, 4), Vector3.new(side * 59.4, 0.3, z + 2), C.blanco, Enum.Material.Concrete))
			deco(block(folder, "Bordillo", Vector3.new(0.7, 0.5, 4), Vector3.new(side * 59.4, 0.3, z + 6), C.rojo, Enum.Material.Concrete))
		end
	end
	for _, bin in { { -57, 245 }, { 57, 258 }, { -57, 296 }, { 57, 300 }, { -57, 318 }, { 57, 322 } } do
		deco(pole(folder, "Bote", Vector3.new(bin[1], 0, bin[2]), 2.6, 1.8, C.lonaVerde, Enum.Material.Metal))
		deco(pole(folder, "BoteTapa", Vector3.new(bin[1], 2.6, bin[2]), 0.3, 2, C.oscuro, Enum.Material.Metal))
	end
	for _, cone in { { -22, 238 }, { 22, 238 }, { -8, 250 }, { 8, 250 }, { -28, 300 }, { 28, 300 } } do
		deco(pole(folder, "Cono", Vector3.new(cone[1], 0, cone[2]), 1.8, 1.1, C.lonaNaranja, Enum.Material.SmoothPlastic))
		deco(pole(folder, "ConoBanda", Vector3.new(cone[1], 0.9, cone[2]), 0.35, 1.15, C.blanco, Enum.Material.SmoothPlastic))
	end
	for _, spot in { { -12, 240, 5 }, { 14, 262, 4 }, { -2, 282, 5 }, { 16, 304, 4 }, { -14, 318, 6 }, { 4, 326, 4 } } do
		deco(pole(folder, "Charco", Vector3.new(spot[1], FLOOR_TOP + 0.03, spot[2]), 0.03, spot[3], Color3.fromRGB(30, 44, 58), Enum.Material.Glass)).Transparency = 0.3
	end
	-- Líneas pintadas de las paradas de buses
	for _, z in { 238, 257, 276, 296, 316 } do
		deco(block(folder, "LineaParada", Vector3.new(112, 0.05, 0.5), Vector3.new(0, FLOOR_TOP + 0.04, z), C.blanco, Enum.Material.SmoothPlastic))
	end
end

---------------------------------------------------------------------------------------------------
-- Estadio

local function stadiumDetails(map, rng)
	local folder = Instance.new("Folder")
	folder.Name = "EstadioDetalles"
	folder.Parent = map
	local lineY = FLOOR_TOP + 0.13
	local white = C.blanco

	-- Marcas del campo: círculo central, áreas y líneas de fondo
	local function line(size, position)
		deco(block(folder, "LineaCampo", size, position, white, Enum.Material.SmoothPlastic))
	end
	for k = 0, 23 do
		local a = k * math.pi / 12
		deco(block(folder, "CirculoCentral", Vector3.new(0.5, 0.05, 2.6), CFrame.new(math.cos(a) * 8, lineY, 368 + math.sin(a) * 8) * CFrame.Angles(0, -a, 0), white, Enum.Material.SmoothPlastic))
	end
	deco(pole(folder, "PuntoCentral", Vector3.new(0, lineY - 0.02, 368), 0.05, 1.2, white, Enum.Material.SmoothPlastic))
	for _, side in { -1, 1 } do
		local endX = side * 79.8
		line(Vector3.new(0.5, 0.05, 60), Vector3.new(endX, lineY, 368))
		line(Vector3.new(16, 0.05, 0.5), Vector3.new(side * 72, lineY, 354)) -- área grande
		line(Vector3.new(16, 0.05, 0.5), Vector3.new(side * 72, lineY, 382))
		line(Vector3.new(0.5, 0.05, 28), Vector3.new(side * 64, lineY, 368))
		line(Vector3.new(6, 0.05, 0.5), Vector3.new(side * 76.9, lineY, 362)) -- área chica
		line(Vector3.new(6, 0.05, 0.5), Vector3.new(side * 76.9, lineY, 374))
		line(Vector3.new(0.5, 0.05, 12), Vector3.new(side * 73.9, lineY, 368))
		-- Red de la portería (la portería ya existe a x = ±78)
		local net = deco(block(folder, "RedPorteria", Vector3.new(2.4, 5, 8.2), Vector3.new(side * 79.4, 2.5, 368), white, Enum.Material.Fabric))
		net.Transparency = 0.8
		local netTop = deco(block(folder, "RedPorteria", Vector3.new(2.4, 0.1, 8.2), Vector3.new(side * 79, 5, 368), white, Enum.Material.Fabric))
		netTop.Transparency = 0.6
	end
	-- Banderines de córner
	for _, corner in { { -79, 339 }, { 79, 339 }, { -79, 397 }, { 79, 397 } } do
		deco(pole(folder, "BanderaCorner", Vector3.new(corner[1], 0, corner[2]), 3.4, 0.2, white, Enum.Material.Metal))
		deco(block(folder, "BanderaCornerTela", Vector3.new(0.1, 1, 1.4), Vector3.new(corner[1], 3, corner[2] + (corner[2] < 368 and 0.7 or -0.7)), C.rojo, Enum.Material.Fabric))
	end
	-- Manchas de tierra en las porterías y el centro, y charcos de barro
	for _, patch in { { -72, 368, 12 }, { 72, 368, 12 }, { 0, 368, 9 }, { -40, 350, 6 }, { 38, 386, 7 } } do
		deco(pole(folder, "TierraGastada", Vector3.new(patch[1], FLOOR_TOP + 0.1, patch[2]), 0.03, patch[3], C.tierra, Enum.Material.Ground))
	end
	for _, spot in { { -30, 372, 4 }, { 24, 356, 5 }, { 56, 378, 3 } } do
		deco(pole(folder, "Barro", Vector3.new(spot[1], FLOOR_TOP + 0.12, spot[2]), 0.03, spot[3], Color3.fromRGB(58, 44, 30), Enum.Material.Glass)).Transparency = 0.25
	end

	-- Gradas: asientos de colores por tramos, respaldos y barandas al fondo
	for _, side in { -1, 1 } do
		for row = 1, 4 do
			local a = 80 + (row - 1) * 10
			local seatX = side * (a + 4)
			for k = 0, 5 do
				deco(block(folder, "Asientos", Vector3.new(2, 0.35, 10.6), Vector3.new(seatX, 3 * row + 0.25, 336 + k * 11 + 5.5), (k + row) % 2 == 0 and C.terracota or C.cobalto, Enum.Material.SmoothPlastic))
			end
			deco(block(folder, "AsientosRespaldo", Vector3.new(0.5, 1, 64), Vector3.new(side * (a + 5.4), 3 * row + 0.7, 367), C.concreto, Enum.Material.Concrete))
		end
		-- Baranda en lo alto de cada lado y escaleras de pasillo
		deco(block(folder, "Baranda", Vector3.new(0.3, 0.3, 64), Vector3.new(side * 119, 14.2, 366), C.concreto, Enum.Material.Metal))
		for z = 338, 396, 12 do
			deco(block(folder, "BarandaPoste", Vector3.new(0.3, 1.8, 0.3), Vector3.new(side * 119, 13.2, z), C.concreto, Enum.Material.Metal))
		end
		for _, z in { 346, 368, 390 } do
			for row = 1, 4 do
				deco(block(folder, "EscalonPasillo", Vector3.new(9.4, 0.15, 1.6), Vector3.new(side * (80 + (row - 1) * 10 + 5), 3 * row + 0.2, z), white, Enum.Material.Concrete))
			end
		end
	end

	-- Estandartes colgando de los muros norte y sur, y pilastras
	for i, x in { -90, -66, -42, 42, 66, 90 } do
		for _, wall in { { 331.4, 1 }, { 398.6, -1 } } do
			local z, dir = wall[1], wall[2]
			local colors = { C.rojo, C.cobalto, C.mostaza, C.terracota, C.turquesa, C.lima }
			deco(block(folder, "Estandarte", Vector3.new(3, 10, 0.15), Vector3.new(x, 13, z), colors[(i % #colors) + 1], Enum.Material.Fabric))
			deco(block(folder, "EstandarteFranja", Vector3.new(3.1, 1.2, 0.2), Vector3.new(x, 11, z - dir * 0.05), C.blanco, Enum.Material.Fabric))
			deco(block(folder, "EstandarteFranja", Vector3.new(3.1, 1.2, 0.2), Vector3.new(x, 8.5, z - dir * 0.05), C.oscuro, Enum.Material.Fabric))
		end
	end
	for x = -108, 108, 18 do
		for _, wall in { { 331.2, 1 }, { 398.8, -1 } } do
			if math.abs(x) > 14 then
				deco(block(folder, "PilastraEstadio", Vector3.new(2, 20, 1), Vector3.new(x, 10, wall[1]), C.concreto, Enum.Material.Concrete))
			end
		end
	end

	-- Portones: pilares con franjas y rótulo (el sur da a la terminal; el norte es la entrada de la furgoneta)
	for _, gate in { { pillarZ = 329.4, signZ = 329.1, text = "ESTADIO EL COLOSO", y = 15, half = 10 }, { pillarZ = 397.4, signZ = 397.1, text = "REFUGIO REMO · RESCATE", y = 20, half = 12 } } do
		for _, x in { -gate.half - 0.9, gate.half + 0.9 } do
			deco(block(folder, "PortonPilar", Vector3.new(1.6, 18, 1.6), Vector3.new(x, 9, gate.pillarZ), C.concreto, Enum.Material.Concrete))
			deco(block(folder, "PortonFranja", Vector3.new(1.65, 1, 1.65), Vector3.new(x, 5, gate.pillarZ), C.rojo, Enum.Material.Concrete))
			deco(block(folder, "PortonFranja", Vector3.new(1.65, 1, 1.65), Vector3.new(x, 8, gate.pillarZ), C.blanco, Enum.Material.Concrete))
		end
		local _, gui = blankBoard(folder, "RotuloPorton", Vector3.new(20, 3.6, 0.3), CFrame.new(0, gate.y, gate.signZ), RHO_BLACK, 50)
		boardRect(gui, 0.02, 0.08, 0.96, 0.84, RHO_YELLOW)
		boardText(gui, gate.text, 0.04, 0.1, 0.92, 0.8, RHO_BLACK, Enum.TextXAlignment.Center)
	end

	-- Marcador sobre la grada este, mirando al campo
	do
		local _, gui = blankBoard(folder, "Marcador", Vector3.new(26, 9, 0.6), CFrame.new(119.2, 17, 366) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(14, 14, 16), 40)
		boardText(gui, "LOCAL    0 : 0    VISITA", 0.05, 0.12, 0.9, 0.34, RHO_RED, Enum.TextXAlignment.Center)
		boardText(gui, "ESTADIO EL COLOSO", 0.2, 0.55, 0.6, 0.22, Color3.fromRGB(235, 214, 160), Enum.TextXAlignment.Center)
		for _, x in { -11, 11 } do
			deco(block(folder, "MarcadorPata", Vector3.new(0.6, 8, 0.6), CFrame.new(119.2, 12, 366 + x), C.concreto, Enum.Material.Metal))
		end
	end

	-- Torres de reflectores: cabeza con paneles y dos focos con luz real hacia el campo; luz cálida bajo las gradas
	for _, corner in { { -76, 336 }, { 76, 336 }, { -76, 396 }, { 76, 396 } } do
		local head = Vector3.new(corner[1], 24, corner[2])
		deco(block(folder, "TorreCabeza", Vector3.new(7, 4, 0.8), CFrame.lookAt(head, Vector3.new(0, 1, 368)), MARKET_DARK, Enum.Material.Metal))
		for r = 0, 1 do
			for c = -1, 1 do
				local lamp = CFrame.lookAt(head, Vector3.new(0, 1, 368)) * CFrame.new(c * 2.2, (r - 0.5) * 1.6, -0.6)
				deco(block(folder, "TorrePanel", Vector3.new(1.8, 1.2, 0.3), lamp, Color3.fromRGB(255, 250, 235), Enum.Material.Neon))
			end
		end
		floodLight(folder, head + Vector3.new(0, -0.5, 0), Vector3.new(corner[1] * 0.2, 1, 368), 90, 0.8)
	end
	-- Luz de relleno sobre el campo (para que se vea la cancha entera de noche)
	for _, spot in { { -40, 350 }, { 40, 350 }, { -40, 386 }, { 40, 386 } } do
		local fill = deco(block(folder, "LuzCampo", Vector3.new(0.5, 0.5, 0.5), Vector3.new(spot[1], 20, spot[2]), Color3.fromRGB(255, 244, 225), Enum.Material.SmoothPlastic))
		fill.Transparency = 1
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 240, 215)
		light.Range = 40
		light.Brightness = 0.12
		light.Parent = fill
	end
	for _, spot in { { -102, 350 }, { -102, 386 }, { 102, 350 }, { 102, 386 } } do
		local lamp = deco(block(folder, "LuzGrada", Vector3.new(1.6, 0.5, 1.6), Vector3.new(spot[1], 15.5, spot[2]), Color3.fromRGB(255, 214, 160), Enum.Material.Neon))
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 205, 150)
		light.Range = 30
		light.Brightness = 0.5
		light.Parent = lamp
	end

	-- Antorchas de poste en el borde del campo y alrededor de la hoguera, y velas en la puerta de cada carpa
	local pitchY = FLOOR_TOP + 0.1
	for _, spot in { { -48, 344 }, { 48, 344 }, { -48, 392 }, { 48, 392 }, { -20, 343 }, { 20, 343 }, { -20, 393 }, { 20, 393 }, { -86, 368 }, { 86, 368 } } do
		postTorch(folder, spot[1], spot[2], pitchY)
	end
	for _, tent in { { -28, 394 }, { 28, 394 }, { -62, 394 }, { 62, 394 }, { -66, 338 }, { 66, 338 } } do
		candle(folder, tent[1] + 1.4, pitchY, tent[2] - 3.4)
	end
end

local function buildTerminal(map, refs, rng, spawns)
	local walkable = { { "Apron", -30, 30, 200, 232 }, { "Terminal", -60, 60, 232, 330 } }
	for _, side in { -1, 1 } do
		for _, z in { 240, 280, 320 } do
			table.insert(walkable, { "Nicho", side == -1 and -72 or 60, side == -1 and -60 or 72, z - 4, z + 4 })
		end
	end
	for _, r in AVENUE_WALK do
		table.insert(walkable, r)
	end
	for _, r in ANDEN_WALK do
		table.insert(walkable, r)
	end
	local function isOpen(x, z)
		return inRects(walkable, x, z)
	end

	floor(map, "Apron", -30, 30, 200, 232, C.asfalto, Enum.Material.Asphalt)
	floor(map, "Terminal", -60, 60, 232, 330, Color3.fromRGB(110, 108, 104), Enum.Material.Concrete)
	for _, r in walkable do
		if r[1] == "Nicho" then
			floor(map, "NichoPiso", r[2], r[3], r[4], r[5], C.acera)
		end
	end
	fillHouses(map, rng, { x1 = -120, x2 = 120, z1 = 214, z2 = 330 }, walkable, isOpen)
	skinTerminalHouses(map)

	-- Entrada: cartel rojo sobre la salida de la iglesia, flechas rojas y postes de luz
	sign(map, "CartelCalle3", "→ CALLE", Vector3.new(14, 4, 0.4), CFrame.new(0, 17.5, 200.4) * CFrame.Angles(0, math.pi, 0), C.rojo)
	for _, arrow in { { 0, 210, 0 }, { 0, 226, 0 }, { -5, 237, 0 }, { -10, 255.5, -math.pi / 2 }, { -40, 266, 0 }, { -35, 274.5, math.pi / 2 }, { 0, 284, 0 }, { 0, 300, 0 }, { 0, 316, 0 } } do
		floorArrow(map, Vector3.new(arrow[1], 0, arrow[2]), C.rojo, arrow[3])
	end
	for _, side in { -1, 1 } do
		for _, z in { 208, 224 } do
			local top = Vector3.new(27 * side, 17, z)
			deco(pole(map, "Poste", Vector3.new(27 * side, 0, z), 18, 0.8, C.concreto, Enum.Material.Concrete))
			deco(block(map, "PosteBrazo", Vector3.new(3, 0.3, 0.3), top + Vector3.new(-side * 1.5, 0, 0), C.concreto))
			Atmosphere.bulb(map, top + Vector3.new(-side * 3, -0.4, 0))
		end
	end

	-- 8 buses chocados en zigzag (huecos de 8 entre filas); el centro del fondo queda libre para el combate (x -20..20)
	for _, bus in { { -50, 246 }, { 10, 246 }, { -20, 265 }, { 30, 265 }, { -50, 284 }, { 20, 284 }, { -60, 306 }, { 30, 306 } } do
		busOnSide(map, bus[1], bus[2])
	end
	-- Andenes cubiertos: techo de lámina a 12 a los lados, con pilares
	for _, side in { -1, 1 } do
		local x1, x2 = side == -1 and -60 or 42, side == -1 and -42 or 60
		deco(block(map, "AndenTecho", Vector3.new(18, 0.6, 68), Vector3.new((x1 + x2) / 2, 12.3, 286), C.oxido, Enum.Material.CorrodedMetal))
		for _, z in { 254, 271, 288, 305, 318 } do
			deco(pole(map, "AndenPilar", Vector3.new(side * 43, 0, z), 12, 0.7, C.concreto))
		end
		for _, z in { 262, 300 } do
			Atmosphere.bulb(map, Vector3.new(side * 51, 11.5, z))
		end
	end

	-- Caseta de boletos, bancas, paneles de horarios y mesa con botiquín
	block(map, "Caseta", Vector3.new(8, 8, 8), Vector3.new(-45, 4, 322), C.turquesa)
	deco(block(map, "CasetaTecho", Vector3.new(9, 0.5, 9), Vector3.new(-45, 8.3, 322), C.oxido, Enum.Material.CorrodedMetal))
	deco(block(map, "CasetaVentanilla", Vector3.new(4, 2.5, 0.3), Vector3.new(-45, 4.5, 317.9), C.oscuro, Enum.Material.Glass))
	sign(map, "Boletos", "BOLETOS", Vector3.new(6, 1.5, 0.4), Vector3.new(-45, 7, 317.7), C.mostaza, C.oscuro)
	for _, b in { { 52, 252, 0 }, { 52, 292, 0 }, { -52, 316, 0 }, { 12, 326, 0 } } do
		bench(map, b[1], b[2], b[3])
	end
	sign(map, "PanelHorarios", "SALIDAS HOY: CENTRO 6:00 · CERRO 7:30 · REFUGIO REMO: SIN SERVICIO", Vector3.new(20, 4, 0.4), CFrame.new(59.7, 9, 262) * CFrame.Angles(0, math.pi / 2, 0), C.cobalto, C.blanco)
	sign(map, "PanelTerminal", "TERMINAL DE BUSES", Vector3.new(16, 4, 0.4), CFrame.new(-59.7, 9, 250) * CFrame.Angles(0, -math.pi / 2, 0), C.terracota, C.blanco)
	block(map, "Mesa", Vector3.new(3, 3, 3), Vector3.new(-54, 1.5, 266), C.madera, Enum.Material.Wood)
	local kit, kitPrompt = medkitPickup(map, Vector3.new(-54, 3, 266))
	table.insert(refs.medkits, { model = kit, prompt = kitPrompt })

	-- Área de combate de 40 × 40 con poca cobertura; estación de munición contra la pared oeste
	sandbags(map, -14, 316, 0)
	sandbags(map, 14, 302, 90)
	container(map, 8, 320, 10)
	if LEGACY_SHOPS then
		local model, hitbox = PropModel.build(CajaMunicion, Vector3.new(-57.5, 0, 258), math.rad(-90))
		hitbox.Name = "AmmoStation"
		model.Parent = map
		label(hitbox, "AMMO", Color3.fromRGB(80, 165, 255), 18)
		table.insert(refs.ammoStations, { part = hitbox, model = model, prompt = prompt(hitbox, "Buy ammo", 0.5) })
	end
	if LEGACY_SHOPS then
	refs.boxSpots.Zone3 = { { Vector3.new(0, 0, 298), Vector3.new(-8, 0, 308), Vector3.new(4, 0, 312) } }
	end

	terminalDetails(map, Random.new(58))

	-- 5 puntos de aparición entre buses y detrás de las casetas
	for _, point in { Vector3.new(-56, 0, 256), Vector3.new(56, 0, 270), Vector3.new(55, 0, 314), Vector3.new(-52, 0, 326), Vector3.new(52, 0, 326) } do
		marker(spawns, point)
	end

	-- Emboscada con Tanque al pisar por primera vez el área de combate
	table.insert(refs.ambushesZone3, {
		volume = volume(map, "EmboscadaTerminal", -20, 20, 290, 330, 12),
		points = { Vector3.new(-55, 0, 312), Vector3.new(55, 0, 314), Vector3.new(-52, 0, 326), Vector3.new(52, 0, 326), Vector3.new(0, 0, 238) },
		size = Config.Ambush.TerminalSize,
		tank = true,
	})
end

-- Parte 14: el estadio y la extracción (z 330..400, x -120..120). Los jugadores entran por la puerta sur (x -10..10);
-- la furgoneta entra por el portón norte (x -12..12, 18 de alto) hacia -Z y frena en la cancha en (0, 0, 365).
-- Campamento del Refugio Remo sobre la cancha y las gradas (unas 110 piezas, todo decoración sin colisión).
-- Deja libre el pasillo central de la furgoneta (|x| < 16).
local function buildStadiumCamp(map, rng, options)
	local BLOOD = Color3.fromRGB(105, 16, 16)
	local folder = Instance.new("Folder")
	folder.Name = "Campamento"
	folder.Parent = map
	local y = FLOOR_TOP + 0.14 -- sobre la cancha

	-- Carpas de lona
	local tentColors = { C.lonaAzul, C.lonaNaranja, C.lonaVerde, C.mostaza, C.lonaAzul, C.terracota }
	for i, spot in { { -28, 394 }, { 28, 394 }, { -62, 394 }, { 62, 394 }, { -66, 338 }, { 66, 338 } } do
		local cx, cz = spot[1], spot[2]
		if options.survival and cx == -28 and cz == 394 then
			continue -- ahí va la Tienda del modo Survival
		end
		local color = tentColors[i]
		for _, side in { -1, 1 } do
			deco(block(folder, "CarpaLona", Vector3.new(0.15, 3.9, 5), CFrame.new(cx + side * 1.25, y + 1.5, cz) * CFrame.Angles(0, 0, side * math.rad(39.8)), color, Enum.Material.Fabric))
		end
		deco(block(folder, "CarpaEntrada", Vector3.new(1.6, 2, 0.1), Vector3.new(cx, y + 1, cz - 2.55), C.oscuro, Enum.Material.Fabric))
		deco(block(folder, "CarpaCama", Vector3.new(1.4, 0.3, 3), Vector3.new(cx + rng:NextNumber(-0.8, 0.8), y + 0.15, cz + 0.4), C.blanco, Enum.Material.Fabric))
	end

	-- Hoguera con troncos de asiento y una luz cálida
	local fireX, fireZ = -24, 384
	deco(pole(folder, "HogueraPiedras", Vector3.new(fireX, y, fireZ), 0.5, 3.4, C.concreto, Enum.Material.Slate))
	local flame = deco(block(folder, "Llama", Vector3.new(0.9, 1.6, 0.9), CFrame.new(fireX, y + 1.2, fireZ) * CFrame.Angles(0, 0.6, 0), C.lonaNaranja, Enum.Material.Neon))
	deco(block(folder, "Llama", Vector3.new(0.6, 1, 0.6), CFrame.new(fireX + 0.2, y + 1.1, fireZ - 0.2) * CFrame.Angles(0.2, 1.2, 0.2), C.amarillo, Enum.Material.Neon))
	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 150, 70)
	fireLight.Range = 24
	fireLight.Brightness = 1.6
	fireLight.Parent = flame
	for k = 0, 3 do
		local angle = k * math.pi / 2 + 0.4
		deco(block(folder, "Tronco", Vector3.new(0.9, 0.9, 2.2), CFrame.new(fireX + math.cos(angle) * 3.2, y + 0.45, fireZ + math.sin(angle) * 3.2) * CFrame.Angles(0, -angle, 0), C.madera, Enum.Material.Wood))
	end

	-- Mantas y bultos de gente que se refugió en las gradas
	for _ = 1, 20 do
		local side = rng:NextInteger(0, 1) == 0 and -1 or 1
		local row = rng:NextInteger(1, 4)
		local px = side * (80 + (row - 1) * 10 + rng:NextNumber(1.5, 8.5))
		local pz = rng:NextNumber(335, 395)
		deco(block(folder, "Manta", Vector3.new(2, 0.12, 2.6), CFrame.new(px, 3 * row + 0.08, pz) * CFrame.Angles(0, rng:NextNumber() * 3, 0), ({ C.lonaAzul, C.grafiti, C.mostaza, C.lonaVerde, C.blanco })[rng:NextInteger(1, 5)], Enum.Material.Fabric))
	end

	-- Carteles de los refugiados en los muros norte y sur
	local notes = {
		{ "NIÑOS Y ABUELOS PRIMERO", -45, 398, false },
		{ "AGUA: 1 LATA", 45, 398, false },
		{ "NO DISPAREN, ESTAMOS VIVOS", -80, 398, false },
		{ "REFUGIO REMO: SIGAN VIVOS", 80, 398, false },
		{ "SI LEES ESTO, CORRE", -45, 332, true },
		{ "LA RADIO SIGUE SALIENDO", 45, 332, true },
	}
	for i, note in notes do
		local z = note[4] and note[3] + 0.25 or note[3] - 0.25
		local facing = note[4] and CFrame.new(note[2], 9 + (i % 2) * 3, z) * CFrame.Angles(0, math.pi, 0) or CFrame.new(note[2], 9 + (i % 2) * 3, z)
		sign(folder, "CartelRefugio", note[1], Vector3.new(11, 2.6, 0.2), facing, ({ C.blanco, C.mostaza, C.terracota })[i % 3 + 1], C.oscuro)
	end

	-- Basura, ropa, balones y sangre estilizada por la cancha (sin invadir el pasillo de la furgoneta)
	local function spot()
		local x = rng:NextNumber(-76, 76)
		if math.abs(x) < 16 then
			x = x < 0 and x - 18 or x + 18
		end
		return x, rng:NextNumber(336, 396)
	end
	for i = 1, 34 do
		local x, z = spot()
		local yaw = rng:NextNumber() * math.pi * 2
		local kind = i % 4
		if kind == 0 then
			deco(block(folder, "RopaSuelo", Vector3.new(1.6, 0.05, 1.2), CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0), ({ C.lonaAzul, C.grafiti, C.mostaza, C.blanco, C.lima })[rng:NextInteger(1, 5)], Enum.Material.Fabric))
		elseif kind == 1 then
			deco(block(folder, "Bolsa", Vector3.new(1.1, 0.9, 1.1), CFrame.new(x, 0.5, z) * CFrame.Angles(0, yaw, 0), C.oscuro, Enum.Material.Fabric))
		elseif kind == 2 then
			deco(block(folder, "CajaCarton", Vector3.new(1.4, 1, 1.4), CFrame.new(x, 0.6, z) * CFrame.Angles(0, yaw, 0), C.madera, Enum.Material.Cardboard))
		else
			deco(pole(folder, "Llanta", Vector3.new(x, y, z), 0.7, 2.4, C.oscuro, Enum.Material.Rubber))
		end
	end
	for _ = 1, 3 do
		local x, z = spot()
		local ball = deco(block(folder, "Balon", Vector3.new(1.1, 1.1, 1.1), Vector3.new(x, y + 0.55, z), C.blanco, Enum.Material.SmoothPlastic))
		ball.Shape = Enum.PartType.Ball
	end
	for _ = 1, 12 do
		local x, z = spot()
		deco(pole(folder, "Charco", Vector3.new(x, y, z), 0.04, rng:NextNumber(1.2, 3.2), BLOOD, Enum.Material.SmoothPlastic))
	end
	for _ = 1, 4 do
		local x, z = spot()
		local yaw = rng:NextNumber() * math.pi * 2
		deco(block(folder, "BolsaCuerpo", Vector3.new(1.4, 0.7, 3.2), CFrame.new(x, y + 0.35, z) * CFrame.Angles(0, yaw, 0), C.oscuro, Enum.Material.Fabric))
		deco(block(folder, "CintaPolicia", Vector3.new(0.3, 0.05, 1.2), CFrame.new(x, y + 0.72, z) * CFrame.Angles(0, yaw + 0.8, 0), C.mostaza, Enum.Material.SmoothPlastic))
	end
end

local function buildStadium(map, refs, rng, spawns, config, options)
	local wall = C.concreto
	floor(map, "EstadioPiso", -120, 120, 330, 400, Color3.fromRGB(125, 122, 118), Enum.Material.Concrete)
	-- Cancha de tierra y pasto seco (160 × 60), apenas más alta que el piso
	block(map, "Cancha", Vector3.new(160, 1, 60), Vector3.new(0, FLOOR_TOP + 0.06 - 0.5, 368), C.tierra, Enum.Material.Ground)
	for i = 1, 8 do
		deco(block(map, "Pasto", Vector3.new(14, 0.05, 54), Vector3.new(-70 + (i - 1) * 20, FLOOR_TOP + 0.09, 368), i % 2 == 0 and Color3.fromRGB(96, 120, 50) or Color3.fromRGB(122, 140, 64), Enum.Material.Grass))
	end
	for _, line in { { Vector3.new(0.5, 0.05, 60), Vector3.new(0, FLOOR_TOP + 0.12, 368) }, { Vector3.new(160, 0.05, 0.5), Vector3.new(0, FLOOR_TOP + 0.12, 338.2) }, { Vector3.new(160, 0.05, 0.5), Vector3.new(0, FLOOR_TOP + 0.12, 397.8) } } do
		deco(block(map, "LineaCal", line[1], line[2], C.blanco, Enum.Material.SmoothPlastic))
	end

	-- Muros, puerta sur, portón norte y rótulos
	slab(map, "EstadioMuroS", -120, -10, 330, 332, 20, wall)
	slab(map, "EstadioMuroS", 10, 120, 330, 332, 20, wall)
	block(map, "EstadioDintelS", Vector3.new(20, 6, 2), Vector3.new(0, 17, 331), wall)
	floor(map, "EstadioPuerta", -10, 10, 330, 332, C.concreto)
	slab(map, "EstadioMuroN", -120, -12, 398, 400, 24, wall)
	slab(map, "EstadioMuroN", 12, 120, 398, 400, 24, wall)
	block(map, "EstadioDintelN", Vector3.new(24, 6, 2), Vector3.new(0, 21, 399), wall)
	slab(map, "EstadioMuroW", -122, -120, 330, 400, 20, wall)
	slab(map, "EstadioMuroE", 120, 122, 330, 400, 20, wall)
	floor(map, "CarreteraNorte", -12, 12, 400, 450, C.asfalto, Enum.Material.Asphalt)
	sign(map, "CartelEstadio", "ESTADIO EL COLOSO", Vector3.new(18, 4, 0.4), Vector3.new(0, 17, 329.6), C.mostaza, C.oscuro)
	sign(map, "CartelRescate", "REFUGIO REMO → RESCATE", Vector3.new(20, 4, 0.4), Vector3.new(0, 21, 397.7), C.cobalto, C.blanco)

	-- Gradas: 4 filas de 10 de fondo (3 de alto cada una) en el lado oeste y el este
	for _, side in { -1, 1 } do
		for row = 1, 4 do
			local a, b = 80 + (row - 1) * 10, 80 + row * 10
			local part = slab(map, "Grada", math.min(side * a, side * b), math.max(side * a, side * b), 332, 398, 3 * row, wall)
			deco(block(map, "GradaFranja", Vector3.new(b - a - 0.4, 0.2, 66), Vector3.new(side * (a + b) / 2, 3 * row + 0.1, 365), row % 2 == 0 and C.terracota or C.cobalto, Enum.Material.Concrete))
			part.Name = "Grada"
		end
	end
	-- Banderines rotos sobre la cancha
	deco(block(map, "BanderinesCuerda", Vector3.new(150, 0.1, 0.1), Vector3.new(0, 8, 336), C.blanco))
	for i = 1, 14 do
		if rng:NextNumber() > 0.3 then
			deco(block(map, "Banderin", Vector3.new(2, 2.5, 0.1), CFrame.new(-70 + i * 10, 6.8, 336) * CFrame.Angles(0, 0, math.rad(rng:NextInteger(-20, 20))), ({ C.rojo, C.mostaza, C.cobalto, C.lima })[rng:NextInteger(1, 4)], Enum.Material.Fabric))
		end
	end

	-- Arcos oxidados, reflectores (uno en pie en cada esquina y dos caídos) y baliza de 40 con luz amarilla
	for _, x in { -78, 78 } do
		for _, dz in { -4, 4 } do
			deco(pole(map, "Arco", Vector3.new(x, 0, 368 + dz), 5, 0.4, C.oxido))
		end
		deco(block(map, "Arco", Vector3.new(0.4, 0.4, 8.4), Vector3.new(x, 5, 368), C.oxido, Enum.Material.Metal))
	end
	for _, corner in { { -76, 336 }, { 76, 336 }, { -76, 396 }, { 76, 396 } } do
		deco(pole(map, "Reflector", Vector3.new(corner[1], 0, corner[2]), 22, 0.9, C.concreto))
		Atmosphere.bulb(map, Vector3.new(corner[1], 22.3, corner[2]))
	end
	deco(block(map, "ReflectorCaido", Vector3.new(10, 0.8, 0.8), CFrame.new(30, 0.5, 388) * CFrame.Angles(0, math.rad(25), 0), C.concreto, Enum.Material.Metal))
	deco(block(map, "ReflectorCaido", Vector3.new(10, 0.8, 0.8), CFrame.new(-34, 0.5, 392) * CFrame.Angles(0, math.rad(-40), 0), C.concreto, Enum.Material.Metal))
	deco(pole(map, "Baliza", Vector3.new(-110, 12, 365), 28, 1, C.concreto))
	local beacon = deco(block(map, "BalizaLuz", Vector3.new(3, 3, 3), Vector3.new(-110, 41.5, 365), C.amarillo, Enum.Material.Neon))
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = C.amarillo
	beaconLight.Range = 60
	beaconLight.Brightness = 3
	beaconLight.Parent = beacon

	-- Cobertura baja repartida (fuera del pasillo de 16 hasta la furgoneta y del espacio de 28 × 28 donde frena)
	for _, b in { { -50, 345, 0 }, { 50, 345, 0 }, { -45, 392, 0 }, { 45, 392, 0 } } do
		if not (options.survival and b[1] == -45 and b[2] == 392) then -- ahí va la Tienda del modo Survival
			bench(map, b[1], b[2], b[3])
		end
	end
	car(map, -55, 380, 80, C.concreto)
	crates(map, 40, 372)
	sandbags(map, -34, 358, 90)
	sandbags(map, 34, 382, 0)
	container(map, 56, 360, 20)

	-- Caseta de la radio (oeste), con cobertura de sacos; estación de munición (este); botiquín sobre una mesa
	CollectionService:AddTag(block(map, "CasetaRadio", Vector3.new(8, 10, 12), Vector3.new(-76, 5, 352), C.salmon), "ClimbableBus") -- los zombies trepan a su techo (server/Zombies)
	deco(block(map, "CasetaRadioTecho", Vector3.new(9, 0.5, 13), Vector3.new(-76, 10.3, 352), C.oxido, Enum.Material.CorrodedMetal))
	local radioModel, radio = PropModel.build(Radio, Vector3.new(-67, 0, 352), 0)
	radio.Name = "Radio"
	radioModel.Parent = map
	refs.radio = radio
	refs.radioModel = radioModel
	refs.radioPrompt = prompt(radio, "Use the radio", config.RadioHoldTime)
	label(radio, "RADIO", Color3.fromRGB(110, 225, 150))
	sandbags(map, -62, 346, 90)
	sandbags(map, -62, 358, 90)
	if LEGACY_SHOPS then
		local model, hitbox = PropModel.build(CajaMunicion, Vector3.new(76, 0, 345), math.rad(-90))
		hitbox.Name = "AmmoStation"
		model.Parent = map
		label(hitbox, "AMMO", Color3.fromRGB(80, 165, 255), 18)
		table.insert(refs.ammoStations, { part = hitbox, model = model, prompt = prompt(hitbox, "Buy ammo", 0.5) })
	end
	block(map, "Mesa", Vector3.new(3, 3, 3), Vector3.new(70, 1.5, 392), C.madera, Enum.Material.Wood)
	local kit, kitPrompt = medkitPickup(map, Vector3.new(70, 3, 392))
	table.insert(refs.medkits, { model = kit, prompt = kitPrompt })
	if LEGACY_SHOPS then
	refs.boxSpots.Extraction = { { Vector3.new(-45, 0, 352), Vector3.new(45, 0, 358), Vector3.new(-25, 0, 390) } }
	end

	-- Llegada, furgoneta y 6 puntos de aparición de la extracción en el perímetro
	refs.stadiumVolume = volume(map, "StadiumVolume", -20, 20, 332, 346, 12) -- solo es el destino de la guía (la puerta)
	-- Para pasar a la radio basta con estar dentro del estadio: toda la cancha y las gradas. Con la franja de la puerta sola, si alguien
	-- ya había avanzado cuando llegaba el último, nunca estaban los 3 dentro a la vez.
	refs.stadiumInside = volume(map, "StadiumInside", -120, 120, 332, 398, 40)
	refs.vanStart = CFrame.new(0, 0, 430)
	refs.vanStop = CFrame.new(0, 0, 365)
	refs.vanVolume = volume(map, "VanVolume", -14, 14, 351, 379, 14)
	for _, point in { Vector3.new(-60, 0, 396), Vector3.new(60, 0, 396), Vector3.new(-78, 0, 342), Vector3.new(78, 0, 342), Vector3.new(-80, 0, 375), Vector3.new(80, 0, 375) } do
		marker(spawns, point)
	end

	-- Modo Survival: Tienda dentro del estadio (caja de armas, munición y objetos, farmacia), sitio de aparición del equipo y puntos por
	-- donde entran los zombies: la carretera norte (el portón queda abierto) y la calle junto a la puerta sur
	if options.survival then
		buildShop(map, refs, { origin = Vector3.new(-37, 0, 366), forward = Vector3.new(0, 0, 1), width = 20, depth = 30, zone = "Survival", signWidth = 14 })
		refs.survivalSpawn = CFrame.lookAt(Vector3.new(0, 1, 352), Vector3.new(0, 1, 380))
		for _, point in {
			Vector3.new(0, 0, 440), Vector3.new(-7, 0, 430), Vector3.new(7, 0, 430), Vector3.new(0, 0, 446),
			Vector3.new(-52, 0, 326), Vector3.new(52, 0, 326), Vector3.new(-76, 0, 326), Vector3.new(-82, 0, 329),
			Vector3.new(78, 0, 326), Vector3.new(55, 0, 314), Vector3.new(-56, 0, 256), Vector3.new(56, 0, 270),
		} do
			marker(options.survivalSpawns, point)
		end
	end

	buildStadiumCamp(map, Random.new(config.Seed + 303), options)
	stadiumDetails(map, Random.new(config.Seed + 404))
end

-- Pase de arte: detalles pequeños repartidos por los caminos (todo decoración sin colisión ni sombra, una pieza por
-- objeto, unas 500 en total): ropa y basura tiradas, llantas, cajas, maleza, cables entre casas, charcos y salpicaduras
-- de sangre estilizada, bolsas negras, vidrios rotos, grafitis y carteles pintados a mano sobre las paredes reales.
local BLOOD = Color3.fromRGB(105, 16, 16)
local PAINTS = { C.grafiti, C.turquesa, C.mostaza, C.cobalto, C.blanco, C.lima }
local HAND_SIGNS = {
	"SE VENDE",
	"NO HAY AGUA",
	"BUSCO A MI MADRE — CASA 14",
	"ABIERTO 24 HORAS (YA NO)",
	"NO PASEN",
	"CUIDADO: INFECTADOS",
	"CANAL 7: SIGAN AL REFUGIO REMO",
	"AQUÍ NO HAY NADIE. SIGAN",
	"DIOS NOS CUIDE",
	"SE RECIBEN DONACIONES",
	"EL BARRIO NO SE RINDE",
	"PERDIDO: PERRO CHICO",
	"VENDO MOTO (NO ARRANCA)",
	"LA ALCALDÍA SABÍA",
}

-- Todas las zonas transitables del mapa nuevo (sin rampas, azoteas ni nichos)
local function artAreas()
	local list = {}
	local function add(rects)
		for _, r in rects do
			if not (r[1]:find("^Rampa") or r[1]:find("^Azotea") or r[1]:find("^Nicho")) then
				table.insert(list, { r[2], r[3], r[4], r[5] })
			end
		end
	end
	add(ALLEY)
	add(STAIRS)
	add(MARKET_ROUTE)
	add(ESC2_ROUTE)
	add(AVENUE_WALK)
	add(ANDEN_WALK)
	for _, r in { { -30, 30, -350, -150 }, { -30, 30, -90, -10 }, { -50, 50, -10, 110 }, { -30, 30, 110, 160 }, { -30, 30, 200, 232 }, { -60, 60, 232, 330 } } do
		table.insert(list, r)
	end
	local total = 0
	for _, a in list do
		a.weight = (a[2] - a[1]) * (a[4] - a[3])
		total += a.weight
	end
	return list, total
end

local function randomPoint(areas, total, rng)
	local roll = rng:NextNumber() * total
	for _, a in areas do
		roll -= a.weight
		if roll <= 0 then
			return rng:NextNumber(a[1] + 0.8, a[2] - 0.8), rng:NextNumber(a[3] + 0.8, a[4] - 0.8), a
		end
	end
	local a = areas[1]
	return (a[1] + a[2]) / 2, (a[3] + a[4]) / 2, a
end

-- Busca la pared más cercana desde un punto en una de las 4 direcciones; devuelve posición y normal horizontal
local function wallHit(x, z, rng)
	local dirs = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }
	local dir = dirs[rng:NextInteger(1, 4)]
	local origin = Vector3.new(x, rng:NextNumber(3.5, 6), z)
	local result = workspace:Raycast(origin, dir * 14)
	if result and result.Instance.CanCollide and math.abs(result.Normal.Y) < 0.1 and result.Distance > 1.5 then
		local name = result.Instance.Name
		if (name == "Casa" and not result.Instance:GetAttribute("Favela")) or name:find("Muro") or name:find("Fachada") or name:find("Grada") then
			return result.Position, result.Normal
		end
	end
	return nil
end

local function buildArt(map, rng)
	local areas, total = artAreas()
	local folder = Instance.new("Folder")
	folder.Name = "Arte"
	folder.Parent = map
	local y = FLOOR_TOP + 0.03

	-- Basura y ropa tirada, llantas, cajas y bolsas
	for i = 1, 230 do
		local x, z = randomPoint(areas, total, rng)
		local yaw = rng:NextNumber() * math.pi * 2
		local kind = i % 5
		if kind == 0 then
			deco(block(folder, "RopaSuelo", Vector3.new(1.6, 0.05, 1.2), CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0), ({ C.lonaAzul, C.grafiti, C.mostaza, C.blanco, C.lima })[rng:NextInteger(1, 5)], Enum.Material.Fabric))
		elseif kind == 1 then
			deco(block(folder, "Bolsa", Vector3.new(1.1, 0.9, 1.1), CFrame.new(x, 0.45, z) * CFrame.Angles(0, yaw, 0), C.oscuro, Enum.Material.Fabric))
		elseif kind == 2 then
			deco(pole(folder, "Llanta", Vector3.new(x, 0, z), 0.7, 2.4, C.oscuro, Enum.Material.Rubber))
		elseif kind == 3 then
			deco(block(folder, "CajaCarton", Vector3.new(1.4, 1, 1.4), CFrame.new(x, 0.5, z) * CFrame.Angles(0, yaw, 0), C.madera, Enum.Material.Cardboard))
		else
			deco(block(folder, "Papeles", Vector3.new(1.2, 0.04, 0.9), CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0), C.blanco, Enum.Material.SmoothPlastic))
		end
	end

	-- Maleza y arbustos que invaden
	for i = 1, 70 do
		local x, z = randomPoint(areas, total, rng)
		local bush = i % 4 == 0
		deco(block(folder, bush and "Arbusto" or "Maleza", bush and Vector3.new(3, 2, 3) or Vector3.new(1.4, 0.9, 1.4), CFrame.new(x, bush and 1 or 0.45, z) * CFrame.Angles(0, rng:NextNumber() * 3, 0), bush and Color3.fromRGB(70, 96, 48) or C.pastoSeco, Enum.Material.Grass))
	end

	-- Cables que cuelgan de pared a pared en los pasajes estrechos
	local cables = 0
	for _ = 1, 400 do
		if cables >= 45 then
			break
		end
		local x, z, a = randomPoint(areas, total, rng)
		local width = a[2] - a[1]
		if width >= 6 and width <= 14 and a[4] - a[3] > width then
			local p1 = Vector3.new(a[1], rng:NextNumber(12, 15), z)
			local p2 = Vector3.new(a[2], rng:NextNumber(11, 14), z + rng:NextNumber(-3, 3))
			deco(block(folder, "CableColgante", Vector3.new(0.12, 0.12, (p2 - p1).Magnitude), CFrame.lookAt((p1 + p2) / 2, p2), C.oscuro, Enum.Material.SmoothPlastic))
			cables += 1
		end
	end

	-- Sangre estilizada: charcos en el suelo y bolsas negras (nada gráfico)
	for _ = 1, 35 do
		local x, z = randomPoint(areas, total, rng)
		deco(pole(folder, "Charco", Vector3.new(x, y - 0.01, z), 0.04, rng:NextNumber(1, 3), BLOOD, Enum.Material.SmoothPlastic))
	end
	for _ = 1, 8 do
		local x, z = randomPoint(areas, total, rng)
		local yaw = rng:NextNumber() * math.pi * 2
		deco(block(folder, "BolsaCuerpo", Vector3.new(1.4, 0.7, 3.2), CFrame.new(x, 0.35, z) * CFrame.Angles(0, yaw, 0), C.oscuro, Enum.Material.Fabric))
		deco(block(folder, "CintaPolicia", Vector3.new(0.3, 0.05, 1.2), CFrame.new(x, 0.72, z) * CFrame.Angles(0, yaw + 0.8, 0), C.mostaza, Enum.Material.SmoothPlastic))
	end
	for _ = 1, 6 do -- vidrios rotos (cuatro por montón)
		local x, z = randomPoint(areas, total, rng)
		for k = 1, 4 do
			local shard = deco(block(folder, "Vidrio", Vector3.new(0.8, 0.05, 0.6), CFrame.new(x + rng:NextNumber(-1.5, 1.5), y, z + rng:NextNumber(-1.5, 1.5)) * CFrame.Angles(0, rng:NextNumber() * 6, 0), Color3.fromRGB(170, 215, 225), Enum.Material.Glass))
			shard.Transparency = 0.35
			if k == 1 then
				shard.Name = "VidrioGrande"
			end
		end
	end

	-- Paredes reales: salpicaduras, grafitis y carteles pintados a mano (se buscan con rayos para que no floten)
	local splats, paints, signs = 0, 0, 0
	for _ = 1, 900 do
		if splats >= 15 and paints >= 40 and signs >= #HAND_SIGNS then
			break
		end
		local x, z = randomPoint(areas, total, rng)
		local position, normal = wallHit(x, z, rng)
		if position then
			local facing = CFrame.lookAt(position + normal * 0.1, position + normal * 1.1)
			if splats < 15 then
				splats += 1
				deco(block(folder, "Salpicadura", Vector3.new(rng:NextNumber(1, 3), rng:NextNumber(1, 2.5), 0.1), facing * CFrame.new(0, -1.2, 0), BLOOD, Enum.Material.SmoothPlastic))
			elseif signs < #HAND_SIGNS and rng:NextNumber() < 0.3 then
				signs += 1
				sign(folder, "CartelPintado", HAND_SIGNS[signs], Vector3.new(7, 2.4, 0.2), facing * CFrame.new(0, 0, 0.05), ({ C.blanco, C.mostaza, C.terracota })[signs % 3 + 1], C.oscuro)
			elseif paints < 40 then
				paints += 1
				deco(block(folder, "Grafiti", Vector3.new(rng:NextNumber(2, 6), rng:NextNumber(1.5, 4), 0.1), facing, PAINTS[rng:NextInteger(1, #PAINTS)], Enum.Material.SmoothPlastic))
			end
		end
	end
end

-- Límites invisibles: tapas sobre los edificios (no se puede subir a sus azoteas para saltarse una zona) y paredes en el
-- borde del mapa y a los lados de la salida de la furgoneta. Sin colisión con balas (CanQuery = false): solo frenan al jugador.
local CAP_NAMES = { "^Casa$", "^TiendaBloque", "^IglesiaBloque", "^EstadioMuro", "^MercadoMuro", "^LobbyLado", "^LobbyFondo", "^LobbyFrente", "^Iglesia[FL]", "^Tienda[FL]" }
local CAP_TOP = 60 -- las tapas llegan hasta esta altura: con saltos de 7 desde una azotea de 10 no se alcanza

local function buildLimits(map, options)
	local folder = Instance.new("Folder")
	folder.Name = "Limites"
	folder.Parent = map
	local function invisible(size, cframe)
		local part = Instance.new("Part")
		part.Name = "Limite"
		part.Anchored = true
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Size = size
		part.CFrame = cframe
		part.Parent = folder
	end

	local caps = 0
	for _, part in map:GetChildren() do
		if part:IsA("BasePart") and part.CanCollide and part.Size.Y < CAP_TOP - 2 then
			for _, pattern in CAP_NAMES do
				if part.Name:find(pattern) then
					local top = part.Position.Y + part.Size.Y / 2
					local height = CAP_TOP - top
					invisible(Vector3.new(part.Size.X, height, part.Size.Z), CFrame.new(part.Position.X, top + height / 2, part.Position.Z))
					caps += 1
					break
				end
			end
		end
	end

	-- Borde del mapa (alto de sobra) y salida de la furgoneta
	local H = 90
	invisible(Vector3.new(2, H, 860), CFrame.new(-125, H / 2, 20)) -- oeste
	invisible(Vector3.new(2, H, 860), CFrame.new(125, H / 2, 20)) -- este
	invisible(Vector3.new(256, H, 2), CFrame.new(0, H / 2, -403)) -- detrás del lobby
	invisible(Vector3.new(30, H, 2), CFrame.new(0, H / 2, 451)) -- fin de la carretera norte (el suelo llega a z 450)
	if not options.survival then -- en Survival los zombies entran por el portón norte
		invisible(Vector3.new(26, H, 2), CFrame.new(0, H / 2, 399)) -- cierra el portón norte del estadio (la furgoneta entra animada, no choca)
	end
	for _, side in { -1, 1 } do
		invisible(Vector3.new(3, H, 58), CFrame.new(side * 13.5, H / 2, 423)) -- a los lados de la carretera (z 394..452)
	end
	-- Suelo de seguridad bajo el estadio y la carretera: si hubiera un hueco, se pisa esto en vez de caer al vacío
	invisible(Vector3.new(250, 3, 126), CFrame.new(0, -1.5, 389)) -- su cara superior queda a ras del suelo (y = 0)
	return caps
end

-- options.survival = true arma el mapa para el modo Survival (Tienda en el estadio, portón norte abierto, puntos de aparición propios)
function MapBuilderBarrio.build(config, options)
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
	local zone1Spawns = Instance.new("Folder")
	zone1Spawns.Name = "Zone1"
	zone1Spawns.Parent = spawnRoot
	local zone2Spawns = Instance.new("Folder")
	zone2Spawns.Name = "Zone2"
	zone2Spawns.Parent = spawnRoot
	local zone3Spawns = Instance.new("Folder")
	zone3Spawns.Name = "Zone3"
	zone3Spawns.Parent = spawnRoot
	local extractionSpawns = Instance.new("Folder")
	extractionSpawns.Name = "Extraction"
	extractionSpawns.Parent = spawnRoot
	local survivalSpawns = Instance.new("Folder")
	survivalSpawns.Name = "Survival"
	survivalSpawns.Parent = spawnRoot
	options.survivalSpawns = survivalSpawns

	local rng = Random.new(config.Seed)
	favelaRng = Random.new(config.Seed + 2026)
	lastFavela = nil
	local refs = { ammoStations = {}, pharmacySpots = {}, boxSpots = { Zone1 = {} }, ambushes = {}, canPiles = {}, medkits = {}, ambushesZone2 = {}, ambushesZone3 = {} }

	buildLobby(map, refs)
	buildStreet(map, refs, rng)
	buildAlley(map, refs, rng, zone1Spawns)
	buildStairs(map, refs, rng, zone1Spawns)
	buildSafePoint(map, refs)
	buildTramo2Calle(map, refs, rng, zone2Spawns, config)
	buildChurch(map, refs)
	buildMarket(map, refs, rng, zone2Spawns)
	buildEscalera2(map, refs, rng, zone2Spawns)
	buildTerminal(map, refs, rng, zone3Spawns)
	buildAvenue(map, refs, rng, zone3Spawns)
	buildAndenes(map, refs, rng, zone3Spawns)
	buildStadium(map, refs, rng, extractionSpawns, config, options)
	buildArt(map, Random.new(config.Seed + 101))
	buildLimits(map, options)

	-- Las garrafas se entregan junto al generador; con cada entrega llegan zombies de la zona 2
	local generatorPosition = refs.generator.Position
	refs.gas.deliverPos = generatorPosition
	refs.gas.depositSpots = {
		generatorPosition + Vector3.new(-4.5, 0, -2),
		generatorPosition + Vector3.new(-4.5, 0, 0.5),
		generatorPosition + Vector3.new(-4.5, 0, 3),
	}
	for _, point in zone2Spawns:GetChildren() do
		table.insert(refs.gas.hordePoints, point.Position - Vector3.new(0, 0.5, 0))
	end

	-- Survival: nada de lo del modo historia se recoge ni estorba (botiquines, latas sueltas, rótulo de la entrada de la furgoneta)
	if options.survival then
		for _, list in { refs.medkits, refs.canPiles } do
			for _, item in list do
				item.model:Destroy()
			end
			table.clear(list)
		end
		for _, item in map:GetDescendants() do
			if item.Name == "CartelRescate" or (item.Name == "RotuloPorton" and item:IsA("BasePart") and item.Position.Z > 390)
				or ((item.Name == "PortonPilar" or item.Name == "PortonFranja") and item:IsA("BasePart") and item.Position.Z > 390) then
				item:Destroy()
			end
		end
	end

	-- Aviso si un lugar de la caja de armas quedó tapado por un obstáculo
	local params = OverlapParams.new()
	params.RespectCanCollide = true
	for _, groups in refs.boxSpots do -- cada zona tiene una lista de lugares por ruta
		for _, group in groups do
			for _, spotValue in group do
				local spot = typeof(spotValue) == "CFrame" and spotValue.Position or spotValue
				if #workspace:GetPartBoundsInBox(CFrame.new(spot + Vector3.new(0, 4, 0)), Vector3.new(9, 6, 7), params) > 0 then
					warn(`MapBuilderBarrio: el lugar de la caja de armas {spot} está tapado`)
				end
			end
		end
	end

	return refs
end

return MapBuilderBarrio
