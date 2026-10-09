-- Mapa 1, Morro Esperanza (barrio de Rhomulus), en bloques de colores generados por código.
-- Diseño: docs/mapa-1-barrio.md y docs/prompts-mapa-claude-design.md (Prompt 0 = escala y reglas; partes 2 a 10).
-- Se activa con Config.Game.UseNewMap; mientras tanto el mapa de siempre (MapBuilder) sigue intacto.
--
-- Hecho hasta ahora: lobby (la cochera, z -400..-350) -> tramo 1, rutas Calle (roja, z -350..-130) y Callejón
-- (amarilla, x -120..-60) y Escalera (azul, x 60..120) -> punto seguro 1
-- (la tienda, z -130..-90) -> tramo 2, ruta Calle (plaza con el generador, z -90..160) -> punto seguro 2 (la iglesia,
-- z 160..200) -> vestíbulo de salida provisional (z 200..212), que termina la prueba con victoria.
-- La Baseplate de Studio solo llega hasta z = -256: todo lo que se pisa lleva su propio piso.
-- Ejes: X lateral, Y altura (suelo en 0), Z avance. Devuelve las mismas referencias que MapBuilder.build.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Atmosphere = require(script.Parent.Atmosphere)
local PropModel = require(script.Parent.PropModel)
local CajaMunicion = require(script.Parent.ZombieData.CajaMunicion)
local Generador = require(script.Parent.ZombieData.Generador)

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
	sign(map, "CartelRendir", "AQUÍ NO SE RINDE NADIE", Vector3.new(14, 4, 0.4), CFrame.new(44.7, 9, -387.5) * CFrame.Angles(0, math.pi / 2, 0), C.terracota)
	sign(map, "CartelEscalera", "↑ ESCALERA", Vector3.new(12, 5, 0.4), CFrame.new(44.7, 17, -374) * CFrame.Angles(0, math.pi / 2, 0), C.azul)

	-- Radio sobre una mesa, carro viejo sin ruedas, llantas, bidones y cajas
	block(map, "Mesa", Vector3.new(6, 3, 3), Vector3.new(-32, 1.5, -391), C.madera, Enum.Material.Wood)
	deco(block(map, "RadioVieja", Vector3.new(2.4, 1.4, 1.2), Vector3.new(-32, 3.7, -391), C.oscuro, Enum.Material.Metal))
	deco(block(map, "RadioAntena", Vector3.new(0.1, 2, 0.1), Vector3.new(-31.2, 5.4, -391), C.concreto))
	car(map, 30, -362, 12, C.turquesa)
	block(map, "Gato", Vector3.new(5, 0.6, 10), CFrame.new(30, 0.3, -362) * CFrame.Angles(0, math.rad(12), 0), C.oxido) -- el carro va sobre bloques
	for i = 0, 2 do
		local tire = block(map, "Llanta", Vector3.new(1.2, 3, 3), CFrame.new(-38, 0.6 + i * 1.2, -362) * CFrame.Angles(0, 0, math.pi / 2), C.oscuro, Enum.Material.Rubber)
		tire.Shape = Enum.PartType.Cylinder
	end
	barrel(map, 38, -391, C.lonaAzul)
	barrel(map, 41, -389)
	crates(map, -38, -386)
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
			deco(block(map, "Franja", Vector3.new(0.3, 1, segEnd - segStart), Vector3.new(faceX - side * 0.2, 6, (segStart + segEnd) / 2), stripeColor, Enum.Material.SmoothPlastic))
			for _, cornerZ in { segStart + 2, segEnd - 2 } do
				deco(block(map, "EsquinaRoja", Vector3.new(0.3, 1, 4), Vector3.new(faceX - side * 0.2, 3, cornerZ), C.rojo, Enum.Material.SmoothPlastic))
			end
		end

		-- Pasajes de cruce abiertos: al oeste hacia el Callejón y al este hacia la Escalera
		for _, z in CROSSINGS do
			if side == -1 then
				floor(map, "PasajePiso", -60, -35, z - 4, z + 4, C.acera)
				floorArrow(map, Vector3.new(-40, 0, z), C.amarillo, -math.pi / 2)
				sign(map, "CartelCallejon", "← CALLEJÓN", Vector3.new(8, 3, 0.4), CFrame.new(-34.5, 9, z + 9) * CFrame.Angles(0, -math.pi / 2, 0), C.amarillo, C.oscuro)
			else
				floor(map, "PasajePiso", 35, 60, z - 4, z + 4, C.acera)
				floorArrow(map, Vector3.new(40, 0, z), C.azul, math.pi / 2)
				sign(map, "CartelEscalera", "ESCALERA →", Vector3.new(8, 3, 0.4), CFrame.new(34.5, 9, z + 9) * CFrame.Angles(0, math.pi / 2, 0), C.azul)
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

-- Botiquín que se recoge con E (server/Medkits). `position` es el centro de la base (sobre una mesa o el suelo).
local function medkitPickup(parent, position)
	local model = Instance.new("Model")
	model.Name = "Botiquin"
	local box = deco(block(model, "BotiquinCaja", Vector3.new(1.6, 1, 1.2), position + Vector3.new(0, 0.5, 0), C.blanco, Enum.Material.SmoothPlastic))
	deco(block(model, "BotiquinCruz", Vector3.new(1.62, 0.25, 0.7), box.Position, C.rojo, Enum.Material.SmoothPlastic))
	deco(block(model, "BotiquinCruz", Vector3.new(1.62, 0.7, 0.25), box.Position, C.rojo, Enum.Material.SmoothPlastic))
	local hitbox = deco(block(model, "Hitbox", Vector3.new(2.5, 2.5, 2.5), position + Vector3.new(0, 1, 0)))
	hitbox.Transparency = 1
	label(hitbox, "BOTIQUÍN", C.rojo, 14)
	model.Parent = parent
	return model, prompt(hitbox, "Tomar botiquín", 0.3)
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

-- Parte 5: tramo 1, ruta Escalera (azul). Franja de x 60 a 120, entre las casas de la calle y el borde del mapa.
-- Pasajes con tramos de escalones bajos y una cancha de barrio abierta en el centro (emboscada grande al pisarla).
-- Recorrido: puerta este del lobby -> patio -> pasaje B1 -> B2 -> B3 -> cancha -> B4 -> rellano -> B5 -> embudo de la tienda.
-- Los fondos de los callejones laterales (T1, T2, T3) son los puntos de aparición y guardan las latas grandes.
local STAIRS = {
	{ "Patio", 60, 86, -382, -366 },
	{ "B1", 68, 78, -366, -300 },
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
		deco(block(map, "FranjaAzul", stripe[1], stripe[2], C.azul, Enum.Material.SmoothPlastic))
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
	local model, hitbox = PropModel.build(CajaMunicion, Vector3.new(76.5, 0, -325), math.rad(90))
	hitbox.Name = "AmmoStation"
	model.Parent = map
	label(hitbox, "MUNICIÓN", Color3.fromRGB(80, 165, 255), 18)
	table.insert(refs.ammoStations, { part = hitbox, model = model, prompt = prompt(hitbox, "Comprar munición", 0.5) })

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
	table.insert(refs.boxSpots.Zone1, { Vector3.new(88, 0, -250), Vector3.new(88, 0, -229.5), Vector3.new(80, 0, -175) })
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
	slab(map, "TiendaLadoW", -30, -28, -128, -122, 16, wall)
	slab(map, "TiendaLadoW", -30, -28, -110, -92, 16, wall)
	block(map, "TiendaDintelW", Vector3.new(2, 2, 12), Vector3.new(-29, 15, -116), wall)
	slab(map, "TiendaLadoE", 28, 30, -128, -122, 16, wall)
	slab(map, "TiendaLadoE", 28, 30, -110, -92, 16, wall)
	block(map, "TiendaDintelE", Vector3.new(2, 2, 12), Vector3.new(29, 15, -116), wall)
	block(map, "TiendaTecho", Vector3.new(60, 1, 40), Vector3.new(0, 16.5, -110), C.concreto, Enum.Material.CorrodedMetal)
	floor(map, "TiendaPiso", -28, 28, -128, -92, Color3.fromRGB(170, 160, 140), Enum.Material.Slate)

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
	refs.generatorPrompt = prompt(generator, "Encender generador", config.GeneratorHoldTime)
	label(generator, "GENERADOR", Color3.fromRGB(255, 155, 60))
	sandbags(map, 23, 34, 45)
	sandbags(map, 37, 47, 45)
	crates(map, 39, 33)

	-- Estación de munición (acera oeste de la plaza), botiquín en un puesto y caja de armas en la plaza
	local model, hitbox = PropModel.build(CajaMunicion, Vector3.new(-47.5, 0, 20), math.rad(-90))
	hitbox.Name = "AmmoStation"
	model.Parent = map
	label(hitbox, "MUNICIÓN", Color3.fromRGB(80, 165, 255), 18)
	table.insert(refs.ammoStations, { part = hitbox, model = model, prompt = prompt(hitbox, "Comprar munición", 0.5) })
	local kit, kitPrompt = medkitPickup(map, Vector3.new(-35, 3, 61.2))
	table.insert(refs.medkits, { model = kit, prompt = kitPrompt })
	refs.boxSpots.Zone2 = { { Vector3.new(-30, 0, 45), Vector3.new(0, 0, 95), Vector3.new(20, 0, 0) } }

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
	local wall = C.blanco
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
	block(map, "IglesiaTecho", Vector3.new(60, 1, 40), Vector3.new(0, 20.5, 180), C.oxido, Enum.Material.CorrodedMetal)
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
	refs.gateText = { label = "IGLESIA", open = "abrir la iglesia", run = "a la iglesia" }
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
		for _, x in { -27.8, 27.8 } do
			deco(block(map, "Vitral", Vector3.new(0.3, 6, 3), Vector3.new(x, 11, z), color, Enum.Material.Neon)).Transparency = 0.3
		end
	end

	-- Munición, radio con la segunda pista y el cartel del barrio
	local model, hitbox = PropModel.build(CajaMunicion, Vector3.new(25.5, 0, 170), math.rad(90))
	hitbox.Name = "AmmoStation"
	model.Parent = map
	label(hitbox, "MUNICIÓN", Color3.fromRGB(80, 165, 255), 18)
	table.insert(refs.ammoStations, { part = hitbox, model = model, prompt = prompt(hitbox, "Comprar munición", 0.5) })
	block(map, "MesaRadio", Vector3.new(4, 3, 2.5), Vector3.new(-25, 1.5, 166), C.madera, Enum.Material.Wood)
	deco(block(map, "RadioIglesia", Vector3.new(2.4, 1.4, 1.2), Vector3.new(-25, 3.7, 166), C.oscuro, Enum.Material.Metal))
	sign(map, "Pista2", "Rhomulus cayó, pero el Refugio Remo sigue en pie", Vector3.new(9, 4, 0.4), CFrame.new(-27.7, 8, 166) * CFrame.Angles(0, -math.pi / 2, 0), C.blanco, C.oscuro)
	sign(map, "CartelIglesia", "AQUÍ NADIE SE QUEDA ATRÁS", Vector3.new(20, 4, 0.4), Vector3.new(0, 17, 197.6), C.mostaza, C.oscuro)

	-- Luz cálida y estable (aquí se respira)
	for _, z in { 172, 188 } do
		local lamp = deco(block(map, "Lampara", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 17, z), Color3.fromRGB(255, 220, 160), Enum.Material.Neon))
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 140)
		light.Range = 30
		light.Brightness = 1.6
		light.Parent = lamp
	end

	-- Vestíbulo de salida provisional: cruzar la puerta de salida termina la prueba (hasta que exista el tramo 3)
	floor(map, "VestibuloPiso", -30, 30, 200, 212, C.acera)
	slab(map, "VestibuloFondo", -60, 60, 212, 214, 20, C.concreto)
	sign(map, "CartelFin", "PRÓXIMAMENTE: LA TERMINAL Y EL ESTADIO", Vector3.new(30, 4, 0.4), Vector3.new(0, 8, 211.7), C.rojo)
	refs.exitVolume = volume(map, "ExitVolume", -30, 30, 202, 212, 12)
end

-- Parte 8: tramo 2, ruta Callejón (amarilla): la feria. Franja de x -120 a -60 entre la tienda y la iglesia.
-- Recorrido: salida oeste de la tienda -> patio -> callejón D1 -> mercado cubierto (las garrafas) -> D2 -> patio junto
-- al atrio de la iglesia. Cruces abiertos a la calle en z = -40, 40 (plaza) y 120 (atrio).
local MARKET_ROUTE = {
	{ "Patio2", -86, -60, -124, -108 },
	{ "D1", -86, -77, -108, -30 },
	{ "C1b", -77, -60, -44, -36 }, -- cruce hacia la calle
	{ "S4", -112, -86, -70, -62 }, -- callejón lateral (sin salida)
	{ "Mercado", -112, -68, -30, 50 }, -- el mercado entero (muros, techo y puestos se ponen aparte)
	{ "C2b", -68, -60, 36, 44 }, -- cruce hacia la plaza
	{ "D2", -95, -86, 50, 112 },
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
	label(body, "GARRAFA", C.lonaNaranja, 18)
	model.Parent = parent
	return model, body, prompt(body, "Cargar garrafa", 0.8)
end

-- Puesto del mercado: mostrador de largo `length` en Z (6 de ancho, 3 de alto) con toldo y fruta
local function marketStall(map, x, z1, z2, canvas)
	local length = z2 - z1
	block(map, "Mostrador", Vector3.new(6, 3, length), Vector3.new(x, 1.5, (z1 + z2) / 2), C.madera, Enum.Material.Wood)
	deco(block(map, "Toldo", Vector3.new(7, 0.3, length), CFrame.new(x, 8.5, (z1 + z2) / 2) * CFrame.Angles(0, 0, math.rad(8)), canvas, Enum.Material.Fabric))
	for z = z1 + 1.5, z2 - 1.5, 3 do
		deco(block(map, "Fruta", Vector3.new(1.6, 0.8, 1.2), Vector3.new(x + (math.random() < 0.5 and -1.5 or 1.5), 3.4, z), ({ C.lima, C.lonaNaranja, C.rojo, C.mostaza })[math.random(4)], Enum.Material.SmoothPlastic))
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
		floor(map, "Piso" .. r[1], r[2], r[3], r[4], r[5], inside and Color3.fromRGB(95, 92, 88) or C.acera, inside and Enum.Material.Slate or Enum.Material.Concrete)
	end
	fillHouses(map, rng, MARKET_BAND, MARKET_ROUTE, isOpen)

	-- Mercado cubierto: muros de 14 con tres puertas (sur, norte y este) y techo de lámina
	local wall = C.concreto
	slab(map, "MercadoMuro", -112, -86, -30, -28, 14, wall)
	slab(map, "MercadoMuro", -77, -68, -30, -28, 14, wall)
	block(map, "MercadoDintel", Vector3.new(9, 4, 2), Vector3.new(-81.5, 12, -29), wall)
	slab(map, "MercadoMuro", -112, -95, 48, 50, 14, wall)
	slab(map, "MercadoMuro", -86, -68, 48, 50, 14, wall)
	block(map, "MercadoDintel", Vector3.new(9, 4, 2), Vector3.new(-90.5, 12, 49), wall)
	slab(map, "MercadoMuro", -112, -110, -28, 48, 14, wall)
	slab(map, "MercadoMuro", -70, -68, -28, 36, 14, wall)
	slab(map, "MercadoMuro", -70, -68, 44, 48, 14, wall)
	block(map, "MercadoDintel", Vector3.new(2, 4, 8), Vector3.new(-69, 12, 40), wall)
	block(map, "MercadoTecho", Vector3.new(44, 0.6, 80), Vector3.new(-90, 14.3, 10), C.oxido, Enum.Material.CorrodedMetal)
	sign(map, "CartelFeria", "FERIA DEL BARRIO — HOY SE VENDE DE TODO", Vector3.new(22, 4, 0.4), Vector3.new(-99, 9, -30.3), C.mostaza, C.oscuro)

	-- Dentro: estanterías en los muros, dos filas de puestos y pasillos de 8 (cruzados al sur, en medio y al norte)
	block(map, "Estanteria", Vector3.new(2, 6, 74), Vector3.new(-109, 3, 10), C.madera, Enum.Material.WoodPlanks)
	block(map, "Estanteria", Vector3.new(2, 6, 60), Vector3.new(-71, 3, 4), C.madera, Enum.Material.WoodPlanks)
	local canvases = { C.lonaAzul, C.lonaNaranja, C.lonaVerde }
	for i, segment in { { -20, -9 }, { -5, 6 }, { 12, 23 }, { 27, 40 } } do
		marketStall(map, -97, segment[1], segment[2], canvases[i % 3 + 1])
		marketStall(map, -83, segment[1], segment[2], canvases[(i + 1) % 3 + 1])
	end
	-- Jaulas y carros de mano (adorno, no tapan los pasillos)
	for _, cage in { { -104, -26 }, { -76, 46 }, { -106, 46 } } do
		deco(block(map, "Jaula", Vector3.new(2, 2, 2), Vector3.new(cage[1], 1, cage[2]), C.concreto, Enum.Material.DiamondPlate)).Transparency = 0.4
	end
	-- Lámparas colgadas (de noche son lo único que alumbra dentro)
	for _, lamp in { { -104, -10 }, { -76, -10 }, { -104, 30 }, { -76, 30 }, { -90, 9 } } do
		Atmosphere.bulb(map, Vector3.new(lamp[1], 12.5, lamp[2]))
	end

	-- Fuera: franjas amarillas, lámparas de pared, tendederos y un mural
	for _, stripe in {
		{ Vector3.new(0.3, 1, 64), Vector3.new(-77.15, 6, -76) }, -- D1, pared este (hasta el cruce)
		{ Vector3.new(0.3, 1, 60), Vector3.new(-86.15, 6, 82) }, -- D2, pared este
	} do
		deco(block(map, "FranjaAmarilla", stripe[1], stripe[2], C.amarillo, Enum.Material.SmoothPlastic))
	end
	for _, lamp in { { -77.4, 11, -95 }, { -77.4, 11, -60 }, { -86.4, 11, 70 }, { -86.4, 11, 100 }, { -80, 11, 127.6 } } do
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

	-- Puntos de aparición: dos en el mercado y dos al fondo de los callejones laterales
	for _, point in { Vector3.new(-108, 0, -66), Vector3.new(-108, 0, 84), Vector3.new(-104, 0, 44), Vector3.new(-76, 0, -24) } do
		marker(spawns, point)
	end

	-- Botiquín en un puesto del medio, caja de armas en un pasillo cruzado
	local kit, kitPrompt = medkitPickup(map, Vector3.new(-97, 3, 0))
	table.insert(refs.medkits, { model = kit, prompt = kitPrompt })
	table.insert(refs.boxSpots.Zone2, { Vector3.new(-90, 0, -24), Vector3.new(-90, 0, 44) })

	-- Garrafas: 3 en 6 lugares posibles de los pasillos (GasCans las reparte al azar en cada partida)
	local spots = {
		Vector3.new(-104, 0, -14), Vector3.new(-104, 0, 30),
		Vector3.new(-90, 0, -2), Vector3.new(-90, 0, 30),
		Vector3.new(-76, 0, -12), Vector3.new(-76, 0, 20),
	}
	refs.gas = { cans = {}, spots = spots, marketPos = Vector3.new(-90, 6, 10), hordePoints = {} }
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
		deco(block(map, "FranjaAzul", stripe[1], stripe[2], C.azul, Enum.Material.SmoothPlastic))
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
	local model, hitbox = PropModel.build(CajaMunicion, Vector3.new(76.5, 0, -80), math.rad(90))
	hitbox.Name = "AmmoStation"
	model.Parent = map
	label(hitbox, "MUNICIÓN", Color3.fromRGB(80, 165, 255), 18)
	table.insert(refs.ammoStations, { part = hitbox, model = model, prompt = prompt(hitbox, "Comprar munición", 0.5) })
	block(map, "Mesa", Vector3.new(3, 3, 3), Vector3.new(94.5, 1.5, 32), C.madera, Enum.Material.Wood)
	local kit, kitPrompt = medkitPickup(map, Vector3.new(94.5, 3, 32))
	table.insert(refs.medkits, { model = kit, prompt = kitPrompt })
	table.insert(refs.boxSpots.Zone2, { Vector3.new(84, 0, 130), Vector3.new(94, 0, 142), Vector3.new(76, 0, 134) })

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
	local zone2Spawns = Instance.new("Folder")
	zone2Spawns.Name = "Zone2"
	zone2Spawns.Parent = spawnRoot

	local rng = Random.new(config.Seed)
	local refs = { ammoStations = {}, boxSpots = { Zone1 = {} }, ambushes = {}, canPiles = {}, medkits = {}, ambushesZone2 = {} }

	buildLobby(map, refs)
	buildStreet(map, refs, rng)
	buildAlley(map, refs, rng, zone1Spawns)
	buildStairs(map, refs, rng, zone1Spawns)
	buildSafePoint(map, refs)
	buildTramo2Calle(map, refs, rng, zone2Spawns, config)
	buildChurch(map, refs)
	buildMarket(map, refs, rng, zone2Spawns)
	buildEscalera2(map, refs, rng, zone2Spawns)

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

	-- Aviso si un lugar de la caja de armas quedó tapado por un obstáculo
	local params = OverlapParams.new()
	params.RespectCanCollide = true
	for _, groups in refs.boxSpots do -- cada zona tiene una lista de lugares por ruta
		for _, group in groups do
			for _, spot in group do
				if #workspace:GetPartBoundsInBox(CFrame.new(spot + Vector3.new(0, 4, 0)), Vector3.new(9, 6, 7), params) > 0 then
					warn(`MapBuilderBarrio: el lugar de la caja de armas {spot} está tapado`)
				end
			end
		end
	end

	return refs
end

return MapBuilderBarrio
