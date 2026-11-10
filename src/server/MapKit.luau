-- MapKit: piezas y ayudantes comunes de los constructores de mapas (server/MapBuilderBarrio, server/MapBuilderAirport).
-- Bloques, pisos, postes, volúmenes, prompts, placas, carteles con texto vivo, modelos fijos de ZombieData, latas y botiquines
-- sueltos, cobertura (carros, cajas, barriles), rampas, focos y la Tienda (caja de armas, munición y farmacia).
-- Ejes: X lateral, Y altura (suelo en 0), Z avance.
local CollectionService = game:GetService("CollectionService")

local PropModel = require(script.Parent.PropModel)
local CajaMunicion = require(script.Parent.ZombieData.CajaMunicion)

local MapKit = {}

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

local FLOOR_TOP = 0.05 -- los pisos de color quedan apenas sobre la Baseplate (sin parpadeo)

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

-- Flecha pintada en el suelo (6 × 2.5), brilla un poco. `angle` = giro en Y; 0 apunta hacia +Z.
local function floorArrow(parent, position, color, angle)
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

-- Carro chocado (6 × 4.5 × 12)
local function car(parent, x, z, angle, color)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(angle), 0)
	block(parent, "Carro", Vector3.new(6, 2.5, 12), base * CFrame.new(0, 1.5, 0), color, Enum.Material.Metal)
	block(parent, "CarroCabina", Vector3.new(5.4, 1.8, 6), base * CFrame.new(0, 3.65, 0.5), C.oscuro, Enum.Material.Glass)
	deco(block(parent, "CarroRueda", Vector3.new(6.2, 1.2, 1.6), base * CFrame.new(0, 0.6, -3.8), C.oscuro))
	deco(block(parent, "CarroRueda", Vector3.new(6.2, 1.2, 1.6), base * CFrame.new(0, 0.6, 3.8), C.oscuro))
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

-- Carteles con texto vivo (tipografía Oswald y los colores de Rhomulus): un tablero en blanco y encima textos y rectángulos
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

-- Pone un modelo de ZombieData como piezas fijas (sin soldaduras). Solo colisionan las piezas de `solid`.
local GLASS_NAMES = { "parabrisas", "luneta", "ventana", "vidrio", "cristales" }
local METAL_NAMES = { "cromo", "parachoques", "parrilla", "tapacubo", "manija", "baca", "cuerpo", "capo", "maletero", "cabina", "techo", "pilar", "puerta_panel", "guardabarros", "chasis", "escape" }
local CAR_BODY = Color3.fromRGB(47, 156, 132) -- color de la carrocería del carro abandonado
local CAR_BODY_DARK = Color3.fromRGB(31, 107, 91)

local function placeModel(parent, data, position, yaw, solid, bodyColor, skip)
	local origin = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local model = Instance.new("Model")
	model.Name = data.rig
	for _, piece in data.parts do
		if skip and skip(piece.name) then -- piezas que no se ponen (p. ej. las ventanillas de un avión aparcado: menos piezas)
			continue
		end
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

-- La Tienda de cada tramo: caja de armas al fondo, estación de munición y objetos a la derecha y vitrina de Phials a la izquierda,
-- bajo un pórtico con su cartel. cfg = { zone, origin (centro de la entrada), forward (hacia el fondo), width, depth, title?, signWidth?, signU? }.
-- Deja refs.shopPositions[zone], refs.boxSpots[zone], una estación en refs.ammoStations y un lugar en refs.pharmacySpots.
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
	boardText(gui, cfg.title or "TIENDA", 0.06, 0.07, 0.88, 0.62, RHO_BLACK, Enum.TextXAlignment.Center)
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

-- Rampa de cuña de x1..x2, z1..z2; `upAtZ2` = lo alto queda en z2 (si no, en z1). Por defecto, azul y de 10 de alto
local function ramp(map, x1, x2, z1, z2, upAtZ2, height, color)
	height = height or 10
	color = color or C.azul
	local wedge = Instance.new("WedgePart")
	wedge.Name = "Rampa"
	wedge.Anchored = true
	wedge.Size = Vector3.new(x2 - x1, height, z2 - z1)
	local center = Vector3.new((x1 + x2) / 2, height / 2, (z1 + z2) / 2)
	wedge.CFrame = upAtZ2 and CFrame.new(center) or CFrame.new(center) * CFrame.Angles(0, math.pi, 0)
	wedge.Color = color
	wedge.Material = Enum.Material.SmoothPlastic
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	wedge.Parent = map
	-- Franjas blancas pintadas sobre la pendiente, como las escalinatas del barrio
	local length = z2 - z1
	local angle = math.atan(height / length)
	for t = 1, length - 2, 3 do
		local along = upAtZ2 and z1 + t + 0.6 or z2 - t - 0.6
		local height = height * (t + 0.6) / length
		deco(block(map, "RampaFranja", Vector3.new(x2 - x1 - 0.4, 0.1, 1.3 / math.cos(angle)), CFrame.new((x1 + x2) / 2, height + 0.06, along) * CFrame.Angles(upAtZ2 and -angle or angle, 0, 0), C.blanco, Enum.Material.SmoothPlastic))
	end
	return wedge
end

local function ball(parent, name, position, diameter, color, material)
	local b = deco(block(parent, name, Vector3.new(diameter, diameter, diameter), position, color, material or Enum.Material.SmoothPlastic))
	b.Shape = Enum.PartType.Ball
	return b
end

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
MapKit.C = C
MapKit.FLOOR_TOP = FLOOR_TOP
MapKit.RHO_RED = RHO_RED
MapKit.RHO_YELLOW = RHO_YELLOW
MapKit.RHO_BLUE = RHO_BLUE
MapKit.RHO_BLACK = RHO_BLACK
MapKit.OSWALD = OSWALD
MapKit.hex = hex
MapKit.block = block
MapKit.slab = slab
MapKit.deco = deco
MapKit.floor = floor
MapKit.pole = pole
MapKit.volume = volume
MapKit.marker = marker
MapKit.door = door
MapKit.prompt = prompt
MapKit.label = label
MapKit.signBoard = signBoard
MapKit.floorArrow = floorArrow
MapKit.car = car
MapKit.container = container
MapKit.crates = crates
MapKit.sandbags = sandbags
MapKit.barrel = barrel
MapKit.boardText = boardText
MapKit.boardRect = boardRect
MapKit.blankBoard = blankBoard
MapKit.placeModel = placeModel
MapKit.canPile = canPile
MapKit.medkitPickup = medkitPickup
MapKit.yawFacing = yawFacing
MapKit.shopAwning = shopAwning
MapKit.buildShop = buildShop
MapKit.ramp = ramp
MapKit.ball = ball
MapKit.floodLight = floodLight

return MapKit
