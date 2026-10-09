-- Mapa 1, Morro Esperanza (barrio de Rhomulus), en bloques de colores generados por código.
-- Diseño: docs/mapa-1-barrio.md y docs/prompts-mapa-claude-design.md (Prompt 0 = escala y reglas; partes 2, 3 y 6).
-- Se activa con Config.Game.UseNewMap; mientras tanto el mapa de siempre (MapBuilder) sigue intacto.
--
-- Hecho hasta ahora: lobby (la cochera, z -400..-350) -> tramo 1, rutas Calle (roja, z -350..-130) y Callejón
-- (amarilla, x -120..-60) -> punto seguro 1
-- (la tienda, z -130..-90) -> vestíbulo de salida provisional (z -90..-78), que termina la prueba con victoria.
-- La Baseplate de Studio solo llega hasta z = -256: todo lo que se pisa lleva su propio piso.
-- Ejes: X lateral, Y altura (suelo en 0), Z avance. Devuelve las mismas referencias que MapBuilder.build.
local CollectionService = game:GetService("CollectionService")

local Atmosphere = require(script.Parent.Atmosphere)
local PropModel = require(script.Parent.PropModel)
local CajaMunicion = require(script.Parent.ZombieData.CajaMunicion)

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
	oscuro = Color3.fromRGB(35, 32, 36),
	madera = Color3.fromRGB(120, 85, 50),
	rojo = hex("#D64545"), -- ruta Calle
	amarillo = hex("#F2C94C"), -- ruta Callejón
	azul = hex("#3B82F6"), -- ruta Escalera
}
local HOUSE_COLORS = { C.terracota, C.mostaza, C.turquesa, C.salmon, C.lima, C.cobalto, C.blanco }
local ROOF_COLORS = { C.oxido, C.concreto }
local FLOOR_TOP = 0.05 -- los pisos de color quedan apenas sobre la Baseplate (sin parpadeo)

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
local function sign(parent, name, text, size, cframe, background, textColor)
	local board = deco(block(parent, name, size, cframe, background, Enum.Material.SmoothPlastic))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
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
	block(parent, "Autobus", Vector3.new(30, 8, 11), Vector3.new(cx, 4, z), C.mostaza, Enum.Material.Metal)
	deco(block(parent, "AutobusVentanas", Vector3.new(24, 0.2, 2.4), Vector3.new(cx + 1.5, 8.1, z - 1.5), C.oscuro, Enum.Material.Glass))
	deco(block(parent, "AutobusFranja", Vector3.new(30.1, 0.6, 11.1), Vector3.new(cx, 4, z), C.oscuro))
	deco(block(parent, "AutobusRueda", Vector3.new(2, 2.4, 1.2), Vector3.new(cx - 9, 4, z + 6), C.oscuro))
	deco(block(parent, "AutobusRueda", Vector3.new(2, 2.4, 1.2), Vector3.new(cx + 9, 4, z + 6), C.oscuro))
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

-- Fachada de casa o edificio (bloque sólido de x1..x2, z1..z2) con puerta, ventanas, techo y 1 o 2 detalles.
-- faceX = x de la fachada que da a la calle; faceDir = hacia dónde mira (+1 = +X, -1 = -X).
local function building(parent, rng, x1, x2, z1, z2, height, faceX, faceDir)
	local color = HOUSE_COLORS[rng:NextInteger(1, #HOUSE_COLORS)]
	slab(parent, "Casa", x1, x2, z1, z2, height, color)
	local roof = deco(slab(parent, "Techo", x1, x2, z1, z2, 0.6, ROOF_COLORS[rng:NextInteger(1, 2)], Enum.Material.CorrodedMetal))
	roof.Position += Vector3.new(0, height, 0)

	local length = z2 - z1
	local skin = faceX + faceDir * 0.15 -- las puertas y ventanas sobresalen apenas de la fachada
	local doorZ = z1 + rng:NextInteger(3, math.max(3, math.floor(length) - 3))
	deco(block(parent, "Puerta", Vector3.new(0.3, 7, 4), Vector3.new(skin, 3.5, doorZ), C.oscuro, Enum.Material.Wood))

	local floors = height >= 24 and 3 or 2
	for level = 1, floors do
		local y = 4.5 + (level - 1) * 8
		local z = z1 + 3
		while z <= z2 - 3 do
			if level > 1 or math.abs(z - doorZ) > 4 then
				deco(block(parent, "Ventana", Vector3.new(0.3, 3, 3), Vector3.new(skin, y, z), C.oscuro, Enum.Material.Glass))
			end
			z += 6
		end
	end

	-- Detalles: tanque de agua, antena, ropa tendida o grafiti
	local roofX = (x1 + x2) / 2
	local detail = rng:NextInteger(1, 4)
	if detail == 1 then
		deco(pole(parent, "TanqueAgua", Vector3.new(roofX, height + 0.6, (z1 + z2) / 2), 4, 4, C.cobalto, Enum.Material.Plastic))
	elseif detail == 2 then
		deco(pole(parent, "Antena", Vector3.new(roofX, height + 0.6, z1 + 2), 6, 0.3, C.concreto))
		deco(block(parent, "Antena", Vector3.new(0.2, 0.2, 3), Vector3.new(roofX, height + 5.5, z1 + 2), C.concreto))
	elseif detail == 3 and length >= 10 then
		local lineX = faceX + faceDir * 1.5
		deco(block(parent, "Tendedero", Vector3.new(0.1, 0.1, length - 4), Vector3.new(lineX, 10, (z1 + z2) / 2), C.blanco))
		for i, cloth in { C.lonaAzul, C.grafiti, C.mostaza } do
			deco(block(parent, "Ropa", Vector3.new(0.1, 2, 1.6), Vector3.new(lineX, 9, z1 + 2 + i * (length - 4) / 4), cloth, Enum.Material.Fabric))
		end
	else
		deco(block(parent, "Grafiti", Vector3.new(0.3, 2.5, math.min(6, length - 2)), Vector3.new(skin, 9, (z1 + z2) / 2), C.grafiti, Enum.Material.SmoothPlastic))
	end
end

---------------------------------------------------------------------------------------------------
-- Partes del mapa

-- Parte 2: el lobby (la cochera). Cuarto cerrado de 120 × 50 × 20, interior libre de 90 × 40.
local function buildLobby(map, refs)
	local wall = C.blanco
	slab(map, "LobbyFondo", -60, 60, -400, -395, 20, wall)
	-- Pared oeste con la puerta del Callejón (12 × 14, z -380..-368)
	slab(map, "LobbyLadoW", -60, -45, -395, -380, 20, wall)
	slab(map, "LobbyLadoW", -60, -45, -368, -355, 20, wall)
	block(map, "LobbyDintelW", Vector3.new(15, 6, 12), Vector3.new(-52.5, 17, -374), wall)
	floor(map, "LobbyPisoW", -60, -45, -380, -368, C.concreto)
	slab(map, "LobbyLadoE", 45, 60, -395, -355, 20, wall)
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
		{ Vector3.new(0.2, 3, 40), Vector3.new(44.9, 1.5, -375) },
		{ Vector3.new(30, 3, 0.2), Vector3.new(-30, 1.5, -355.1) },
		{ Vector3.new(30, 3, 0.2), Vector3.new(30, 1.5, -355.1) },
	} do
		deco(block(map, "FranjaTerracota", strip[1], strip[2], C.terracota))
	end

	-- Puerta enrollable de 30 × 14 hacia la calle
	refs.lobbyDoor = door(map, "LobbyDoor", -351, 30, 14)
	refs.lobbyDoor.Material = Enum.Material.CorrodedMetal
	local westDoor = block(map, "LobbyDoorW", Vector3.new(2, 14, 12), Vector3.new(-46, 7, -374), Color3.fromRGB(150, 110, 60), Enum.Material.CorrodedMetal)
	refs.extraLobbyDoors = { westDoor }
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

	-- Mapa del barrio en la pared del fondo (detrás de los maniquíes)
	local _, gui = sign(map, "MapaBarrio", "", Vector3.new(12, 8, 0.4), CFrame.new(0, 12, -394.7) * CFrame.Angles(0, math.pi, 0), C.blanco)
	gui:FindFirstChildOfClass("TextLabel"):Destroy()
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(0.9, 0.3)
	title.Position = UDim2.fromScale(0.05, 0.05)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.PermanentMarker
	title.TextScaled = true
	title.TextColor3 = C.oscuro
	title.Text = "MORRO ESPERANZA"
	title.Parent = gui
	for i, route in { { "CALLEJÓN", C.amarillo }, { "CALLE", C.rojo }, { "ESCALERA", C.azul } } do
		local bar = Instance.new("TextLabel")
		bar.Size = UDim2.fromScale(0.26, 0.5)
		bar.Position = UDim2.fromScale(0.05 + (i - 1) * 0.31, 0.42)
		bar.BackgroundColor3 = route[2]
		bar.BorderSizePixel = 0
		bar.Font = Enum.Font.PermanentMarker
		bar.TextScaled = true
		bar.TextColor3 = C.oscuro
		bar.Text = route[1]
		bar.Parent = gui
	end

	-- Cartel de la ruta sobre la puerta (se ve desde dentro) y flecha en la calle
	sign(map, "CartelCalle", "↑ CALLE", Vector3.new(12, 5, 0.4), Vector3.new(0, 17, -355.4), C.rojo)
	sign(map, "CartelCallejon", "↑ CALLEJÓN", Vector3.new(12, 5, 0.4), CFrame.new(-44.7, 17, -374) * CFrame.Angles(0, -math.pi / 2, 0), C.amarillo, C.oscuro)
	sign(map, "CartelPerro", "CUIDADO CON EL PERRO", Vector3.new(6, 3, 0.4), CFrame.new(-44.7, 8, -361) * CFrame.Angles(0, -math.pi / 2, 0), C.mostaza, C.oscuro)
	sign(map, "CartelRendir", "AQUÍ NO SE RINDE NADIE", Vector3.new(14, 4, 0.4), CFrame.new(44.7, 9, -378) * CFrame.Angles(0, math.pi / 2, 0), C.terracota)

	-- Radio sobre una mesa, carro viejo sin ruedas, llantas, bidones y cajas
	block(map, "Mesa", Vector3.new(6, 3, 3), Vector3.new(-32, 1.5, -391), C.madera, Enum.Material.Wood)
	deco(block(map, "RadioVieja", Vector3.new(2.4, 1.4, 1.2), Vector3.new(-32, 3.7, -391), C.oscuro, Enum.Material.Metal))
	deco(block(map, "RadioAntena", Vector3.new(0.1, 2, 0.1), Vector3.new(-31.2, 5.4, -391), C.concreto))
	car(map, 32, -372, 12, C.turquesa)
	block(map, "Gato", Vector3.new(5, 0.6, 10), CFrame.new(32, 0.3, -372) * CFrame.Angles(0, math.rad(12), 0), C.oxido) -- el carro va sobre bloques
	for i = 0, 2 do
		local tire = block(map, "Llanta", Vector3.new(1.2, 3, 3), CFrame.new(-38, 0.6 + i * 1.2, -362) * CFrame.Angles(0, 0, math.pi / 2), C.oscuro, Enum.Material.Rubber)
		tire.Shape = Enum.PartType.Cylinder
	end
	barrel(map, 38, -391, C.lonaAzul)
	barrel(map, 41, -389)
	crates(map, -38, -386)
end

-- Parte 3: tramo 1, ruta Calle (roja). Calle de 60 (x -30..30) con aceras de 5 y fachadas hasta x = ±60.
local function buildStreet(map, refs, rng, spawns)
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
			deco(block(map, "Franja", Vector3.new(0.3, 1, segEnd - segStart), Vector3.new(faceX - side * 0.2, 6, (segStart + segEnd) / 2), stripeColor, Enum.Material.SmoothPlastic))
			for _, cornerZ in { segStart + 2, segEnd - 2 } do
				deco(block(map, "EsquinaRoja", Vector3.new(0.3, 1, 4), Vector3.new(faceX - side * 0.2, 3, cornerZ), C.rojo, Enum.Material.SmoothPlastic))
			end
		end

		-- Pasajes de cruce: al oeste abiertos hacia el Callejón; al este, nichos con muro al fondo (hasta que exista
		-- la ruta Escalera) y punto de aparición
		for _, z in CROSSINGS do
			if side == -1 then
				floor(map, "PasajePiso", -60, -35, z - 4, z + 4, C.acera)
				floorArrow(map, Vector3.new(-40, 0, z), C.amarillo, -math.pi / 2)
				sign(map, "CartelCallejon", "← CALLEJÓN", Vector3.new(8, 3, 0.4), CFrame.new(-34.5, 9, z + 9) * CFrame.Angles(0, -math.pi / 2, 0), C.amarillo, C.oscuro)
				continue
			end
			local nx1, nx2 = math.min(35 * side, 47 * side), math.max(35 * side, 47 * side)
			floor(map, "PasajePiso", nx1, nx2, z - 4, z + 4, C.acera)
			local backX1, backX2 = math.min(47 * side, 60 * side), math.max(47 * side, 60 * side)
			slab(map, "PasajeMuro", backX1, backX2, z - 4, z + 4, 18, C.concreto)
			deco(block(map, "PasajeGrafiti", Vector3.new(0.3, 3, 5), Vector3.new(47 * side - side * 0.2, 5, z), C.grafiti, Enum.Material.SmoothPlastic))
			marker(spawns, Vector3.new(43 * side, 0, z))
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
	slab(map, "EmbudoE", 20, 60, -150, -130, 18, C.turquesa)
	deco(block(map, "EsquinaRoja", Vector3.new(0.3, 1, 9), Vector3.new(-19.8, 3, -134.5), C.rojo, Enum.Material.SmoothPlastic))
	deco(block(map, "EsquinaRoja", Vector3.new(0.3, 1, 18), Vector3.new(19.8, 3, -140), C.rojo, Enum.Material.SmoothPlastic))
	sandbags(map, -12, -138, 0)
	sandbags(map, 13, -141, 90)

	-- Obstáculos (huecos de 10 o más para pasar)
	car(map, -14, -325, 25, C.cobalto)
	car(map, 17, -296, -15, C.salmon)
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
	local model, hitbox = PropModel.build(CajaMunicion, Vector3.new(31.5, 0, -220), math.rad(90))
	hitbox.Name = "AmmoStation"
	model.Parent = map
	label(hitbox, "MUNICIÓN", Color3.fromRGB(80, 165, 255), 18)
	table.insert(refs.ammoStations, { part = hitbox, model = model, prompt = prompt(hitbox, "Comprar munición", 0.5) })

	-- Lugares posibles de la caja de armas de la ruta Calle (libres de obstáculos); una caja por ruta
	table.insert(refs.boxSpots.Zone1, { Vector3.new(0, 0, -286), Vector3.new(-18, 0, -212), Vector3.new(-8, 0, -168) })
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
					t += 6
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
	label(hitbox, "LATAS", C.mostaza, 16)
	model.Parent = parent
	return model, prompt(hitbox, "Recoger latas", 0.5)
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
	{ "A2", -106, -97, -320, -246 }, -- de z -320 a -298 es el callejón lateral S1
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

	-- Relleno de casas: rectángulos de celdas de 1 stud que no son transitables, partidos en casas
	local band = ALLEY_BAND
	local width, depth = band.x2 - band.x1, band.z2 - band.z1
	local used = {}
	local function solid(i, j)
		return not used[i * 1000 + j] and not inRects(ALLEY, band.x1 + i - 0.5, band.z1 + j - 0.5)
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

	-- Franjas amarillas en las paredes del recorrido
	for _, stripe in {
		{ Vector3.new(0.3, 1, 60), Vector3.new(-76.85, 6, -336) }, -- A1, pared oeste
		{ Vector3.new(0.3, 1, 43), Vector3.new(-97.15, 6, -267.5) }, -- A2, pared este
		{ Vector3.new(0.3, 1, 56), Vector3.new(-76.85, 6, -208) }, -- A3, pared oeste
	} do
		deco(block(map, "FranjaAmarilla", stripe[1], stripe[2], C.amarillo, Enum.Material.SmoothPlastic))
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
	local S1, S2, S3 = Vector3.new(-101.5, 0, -317), Vector3.new(-101.5, 0, -209), Vector3.new(-104, 0, -172)
	for _, point in { S1, S2, S3 } do
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
	table.insert(refs.boxSpots.Zone1, { Vector3.new(-78, 0, -290), Vector3.new(-92, 0, -230), Vector3.new(-83, 0, -164) })
end

-- Parte 6: punto seguro 1, la tienda de barrio (60 × 40 × 16) con reja de entrada y de salida de 24 × 14.
local function buildSafePoint(map, refs)
	local wall = C.blanco
	-- Fachada sur (más alta para el rótulo), lados y fondo
	slab(map, "TiendaFrenteW", -30, -12, -130, -128, 21, wall)
	slab(map, "TiendaFrenteE", 12, 30, -130, -128, 21, wall)
	block(map, "TiendaDintel", Vector3.new(24, 7, 2), Vector3.new(0, 17.5, -129), wall)
	slab(map, "TiendaFondoW", -30, -12, -92, -90, 16, wall)
	slab(map, "TiendaFondoE", 12, 30, -92, -90, 16, wall)
	block(map, "TiendaFondoDintel", Vector3.new(24, 2, 2), Vector3.new(0, 15, -91), wall)
	slab(map, "TiendaLadoW", -30, -28, -128, -92, 16, wall)
	slab(map, "TiendaLadoE", 28, 30, -128, -92, 16, wall)
	block(map, "TiendaTecho", Vector3.new(60, 1, 40), Vector3.new(0, 16.5, -110), C.concreto, Enum.Material.CorrodedMetal)
	floor(map, "TiendaPiso", -28, 28, -128, -92, Color3.fromRGB(170, 160, 140), Enum.Material.Slate)

	-- Bloques a los lados de la tienda (por aquí llegarán luego el callejón y la escalera)
	slab(map, "TiendaBloqueW", -60, -30, -130, -76, 20, C.mostaza)
	slab(map, "TiendaBloqueE", 30, 60, -130, -76, 20, C.lima)

	refs.safeEntryDoor = door(map, "SafeEntryDoor", -129, 24, 14)
	refs.safeExitDoor = door(map, "SafeExitDoor", -91, 24, 14)
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
	crates(map, 23, -114)

	-- Botiquines (el sistema todavía no existe: de momento son adorno, marcados con el atributo Medkit)
	for i, z in { -113, -107 } do
		local kit = deco(block(map, "Botiquin" .. i, Vector3.new(1.6, 1, 1.2), Vector3.new(-21, 4.5, z), C.blanco, Enum.Material.SmoothPlastic))
		kit:SetAttribute("Medkit", true)
		deco(block(map, "BotiquinCruz", Vector3.new(1.62, 0.25, 0.7), kit.Position, C.rojo, Enum.Material.SmoothPlastic))
		deco(block(map, "BotiquinCruz", Vector3.new(1.62, 0.7, 0.25), kit.Position, C.rojo, Enum.Material.SmoothPlastic))
	end

	-- Estación de munición
	local model, hitbox = PropModel.build(CajaMunicion, Vector3.new(25, 0, -108), math.rad(90))
	hitbox.Name = "AmmoStation"
	model.Parent = map
	label(hitbox, "MUNICIÓN", Color3.fromRGB(80, 165, 255), 18)
	table.insert(refs.ammoStations, { part = hitbox, model = model, prompt = prompt(hitbox, "Comprar munición", 0.5) })

	-- Radio con la primera pista
	block(map, "MesaRadio", Vector3.new(4, 3, 2.5), Vector3.new(-25, 1.5, -102), C.madera, Enum.Material.Wood)
	deco(block(map, "RadioTienda", Vector3.new(2.4, 1.4, 1.2), Vector3.new(-25, 3.7, -102), C.oscuro, Enum.Material.Metal))
	sign(map, "Pista1", "El comandante dijo que el Refugio Remo todavía resiste", Vector3.new(9, 4, 0.4), CFrame.new(-27.7, 8, -102) * CFrame.Angles(0, -math.pi / 2, 0), C.blanco, C.oscuro)

	-- Luz interior
	local lamp = deco(block(map, "Lampara", Vector3.new(4, 0.4, 1), Vector3.new(0, 15.7, -110), Color3.fromRGB(240, 245, 255), Enum.Material.Neon))
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 1.5
	light.Parent = lamp

	-- Baliza de 30 de alto sobre el techo, con luz azul visible desde lejos
	deco(pole(map, "Baliza", Vector3.new(0, 17, -100), 27, 1, C.concreto))
	local beacon = deco(block(map, "BalizaLuz", Vector3.new(2.5, 3, 2.5), Vector3.new(0, 45.5, -100), C.azul, Enum.Material.Neon))
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = C.azul
	beaconLight.Range = 40
	beaconLight.Brightness = 3
	beaconLight.Parent = beacon

	-- Vestíbulo de salida provisional: cruzar la puerta de salida termina la prueba (hasta que exista el tramo 2)
	floor(map, "VestibuloPiso", -30, 30, -90, -78, C.acera)
	slab(map, "VestibuloFondo", -60, 60, -78, -76, 20, C.concreto)
	sign(map, "CartelFin", "PRÓXIMAMENTE: LA PLAZA Y LA FERIA", Vector3.new(30, 4, 0.4), Vector3.new(0, 8, -78.3), C.rojo)
	refs.exitVolume = volume(map, "ExitVolume", -30, 30, -88, -78, 12)
end

function MapBuilderBarrio.build(config)
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

	local rng = Random.new(config.Seed)
	local refs = { ammoStations = {}, boxSpots = { Zone1 = {} }, ambushes = {}, canPiles = {} }

	buildLobby(map, refs)
	buildStreet(map, refs, rng, zone1Spawns)
	buildAlley(map, refs, rng, zone1Spawns)
	buildSafePoint(map, refs)

	-- Aviso si un lugar de la caja de armas quedó tapado por un obstáculo
	local params = OverlapParams.new()
	params.RespectCanCollide = true
	for _, group in refs.boxSpots.Zone1 do
		for _, spot in group do
			if #workspace:GetPartBoundsInBox(CFrame.new(spot + Vector3.new(0, 4, 0)), Vector3.new(9, 6, 7), params) > 0 then
				warn(`MapBuilderBarrio: el lugar de la caja de armas {spot} está tapado`)
			end
		end
	end

	return refs
end

return MapBuilderBarrio
