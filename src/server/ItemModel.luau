-- Modelos 3D de los objetos del inventario, reconstruidos con piezas nativas a partir del "Kit de piezas modulares GDL"
-- (KIT_Granada, KIT_Molotov, KIT_PistolaBengala, KIT_Vendas; scripts de ArchiCAD). Las medidas del kit se toman como studs.
-- Ejes del kit: Z arriba, frente = -Y, cañón de la pistola hacia +X. Aquí: G(x, y, z) = (x, z, y) en Roblox (Y arriba).
--   ItemModel.build(kind)       modelo con PrimaryPart "Root" (una bola invisible con colisión, en el centro del objeto);
--                               kind = "Grenade", "Molotov", "FlareGun", "Bandage" o "Flare" (la bengala disparada)
--   ItemModel.setLid(modelo, abrir, segundos) abre o cierra la tapa del botiquín
--   ItemModel.hold(player, kind) lo pone en la mano derecha (y esconde el arma activa); devuelve una función que lo quita
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ItemModel = {}

local function G(x, y, z)
	return Vector3.new(x, z, y)
end

local function rgb(r, g, b)
	return Color3.new(r, g, b)
end

-- Una pieza del modelo ya soldada al Root (sin colisión, sin masa: solo adorno)
local function part(model, root, name, shape, size, cframe, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	return p
end

-- Cilindro vertical (eje Z del kit) desde z0, de alto h y radio r, centrado en (x, y)
local function vcyl(model, root, name, x, y, z0, h, r, color, material, transparency)
	local cf = CFrame.new(G(x, y, z0 + h / 2)) * CFrame.Angles(0, 0, math.pi / 2)
	return part(model, root, name, Enum.PartType.Cylinder, Vector3.new(h, r * 2, r * 2), cf, color, material, transparency)
end

-- Elipsoide (esfera estirada) centrado en `center`
local function ellipsoid(model, root, name, center, size, color, material, transparency)
	local p = part(model, root, name, Enum.PartType.Block, size, CFrame.new(center), color, material, transparency)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.one
	mesh.Parent = p
	return p
end

local function newModel(kind, diameter)
	local model = Instance.new("Model")
	model.Name = kind
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Shape = Enum.PartType.Ball
	root.Size = Vector3.one * diameter
	root.CFrame = CFrame.identity
	root.Transparency = 1
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model
	model.PrimaryPart = root
	return model, root
end

local BUILDERS = {}

-- Granada de fragmentación (piña): 0.63 x 0.70 x 0.83. Centro en z = 0.4
function BUILDERS.Grenade()
	local model, root = newModel("Granada", 0.7)
	local base = Vector3.new(0, 0, -0.4) -- el centro del objeto queda en el origen
	local function at(x, y, z)
		return G(x, y, z) + G(base.X, base.Y, base.Z)
	end
	local body = rgb(0.33, 0.38, 0.22)
	local metal = rgb(0.55, 0.55, 0.53)
	local brass = rgb(0.78, 0.72, 0.55)
	local zc, rb, ez = 0.355, 0.30, 1.18
	ellipsoid(model, root, "Cuerpo", at(0, 0, zc), Vector3.new(rb * 2, rb * 2 * ez, rb * 2), body, Enum.Material.SmoothPlastic)
	for i = -2, 2 do
		local h = i * 0.11
		local r = math.sqrt(rb ^ 2 - (h / ez) ^ 2) + 0.012
		local cf = CFrame.new(at(0, 0, zc + h)) * CFrame.Angles(0, 0, math.pi / 2)
		part(model, root, "Anillo", Enum.PartType.Cylinder, Vector3.new(0.03, r * 2, r * 2), cf, body, Enum.Material.SmoothPlastic)
	end
	for k = 0, 3 do -- costillas: discos delgados girados cada 45 grados
		local cf = CFrame.new(at(0, 0, zc)) * CFrame.Angles(0, math.rad(k * 45), 0)
		local rib = part(model, root, "Costilla", Enum.PartType.Block, Vector3.new(rb * 2 + 0.024, rb * 2 * ez, 0.05), cf, body, Enum.Material.SmoothPlastic)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = rib
	end
	local function vc(name, z0, h, r, color, material)
		local cf = CFrame.new(at(0, 0, z0 + h / 2)) * CFrame.Angles(0, 0, math.pi / 2)
		return part(model, root, name, Enum.PartType.Cylinder, Vector3.new(h, r * 2, r * 2), cf, color, material)
	end
	vc("Espoleta", 0.68, 0.10, 0.09, metal, Enum.Material.Metal)
	vc("Tapa", 0.78, 0.05, 0.075, metal, Enum.Material.Metal)
	-- Palanca (cuchara): tramo superior y tramo lateral en +X
	part(model, root, "Palanca", Enum.PartType.Block, Vector3.new(0.35, 0.025, 0.12), CFrame.new(at(0.155, 0, 0.7975)), metal, Enum.Material.Metal)
	part(model, root, "PalancaLado", Enum.PartType.Block, Vector3.new(0.025, 0.51, 0.12), CFrame.new(at(0.3175, 0, 0.555)), metal, Enum.Material.Metal)
	-- Pasador hacia el frente (-Y) y anilla (hexágono de 6 tramos en el plano XZ)
	part(model, root, "Pasador", Enum.PartType.Cylinder, Vector3.new(0.22, 0.024, 0.024), CFrame.new(at(0, -0.11, 0.73)) * CFrame.Angles(0, math.pi / 2, 0), brass, Enum.Material.Metal)
	local R = 0.08
	for j = 0, 5 do
		local a = math.rad(j * 60)
		local cx, cz = R * math.cos(a), R * math.sin(a)
		local cf = CFrame.new(at(cx, -0.30, 0.73 + cz)) * CFrame.Angles(0, 0, a + math.pi / 2)
		part(model, root, "Anilla", Enum.PartType.Block, Vector3.new(0.09, 0.028, 0.028), cf, brass, Enum.Material.Metal)
	end
	return model
end

-- Botella con trapo encendido: 0.57 x 0.57 x 1.85 (la botella mide 1.30; con la llama, 1.85). Centro en z = 0.65
function BUILDERS.Molotov()
	local model, root = newModel("Molotov", 0.8)
	local function at(x, y, z)
		return G(x, y, z - 0.65)
	end
	local glass = rgb(0.30, 0.52, 0.28)
	local function vc(name, x, y, z0, h, r, color, material, transparency)
		local cf = CFrame.new(at(x, y, z0 + h / 2)) * CFrame.Angles(0, 0, math.pi / 2)
		return part(model, root, name, Enum.PartType.Cylinder, Vector3.new(h, r * 2, r * 2), cf, color, material, transparency)
	end
	-- Botella: cuerpo, hombro, cuello y labio (el perfil revolucionado del kit, en tramos)
	vc("Botella", 0, 0, 0, 0.75, 0.285, glass, Enum.Material.Glass, 0.35)
	vc("Hombro", 0, 0, 0.75, 0.22, 0.20, glass, Enum.Material.Glass, 0.35)
	vc("Cuello", 0, 0, 0.97, 0.33, 0.088, glass, Enum.Material.Glass, 0.35)
	vc("Labio", 0, 0, 1.27, 0.03, 0.10, glass, Enum.Material.Glass, 0.35)
	vc("Liquido", 0, 0, 0.03, 0.55, 0.255, rgb(0.88, 0.60, 0.20), Enum.Material.SmoothPlastic, 0.1)
	vc("Etiqueta", 0, 0, 0.25, 0.25, 0.29, rgb(0.91, 0.89, 0.84), Enum.Material.SmoothPlastic)
	-- Trapo: vuelta en el cuello, tapón saliente y tira colgante
	local rag = rgb(0.55, 0.42, 0.28)
	vc("TrapoCuello", 0, 0, 1.17, 0.11, 0.14, rag, Enum.Material.Fabric)
	vc("TrapoTapon", 0, 0, 1.31, 0.12, 0.06, rag, Enum.Material.Fabric)
	part(model, root, "TrapoTira", Enum.PartType.Block, Vector3.new(0.03, 0.47, 0.10), CFrame.new(at(0.105, -0.0, 0.955)) * CFrame.Angles(0, 0, math.rad(-8)), rag, Enum.Material.Fabric)
	-- Llama: lengua exterior y núcleo, con luz y un poco de fuego
	local outer = ellipsoid(model, root, "Llama", at(0, 0, 1.62), Vector3.new(0.26, 0.55, 0.26), rgb(0.91, 0.42, 0.11), Enum.Material.Neon)
	ellipsoid(model, root, "LlamaNucleo", at(0, 0, 1.58), Vector3.new(0.15, 0.34, 0.15), rgb(0.95, 0.79, 0.30), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 60)
	light.Brightness = 1.5
	light.Range = 9
	light.Parent = outer
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Rate = 14
	fire.Lifetime = NumberRange.new(0.3, 0.6)
	fire.Speed = NumberRange.new(0.5, 1.5)
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 190, 60), Color3.fromRGB(230, 60, 20))
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	fire.LightEmission = 0.8
	fire.Parent = outer
	return model
end

-- Pistola de bengalas naranja: 1.36 x 0.27 x 0.79, cañón hacia +X. Centro en (0.51, 0, 0.45)
function BUILDERS.FlareGun()
	local model, root = newModel("PistolaBengala", 0.8)
	local function at(x, y, z)
		return G(x - 0.17 - 0.51, y, z - 0.45)
	end
	local orange = rgb(0.91, 0.42, 0.11)
	local black = rgb(0.16, 0.16, 0.18)
	local metal = rgb(0.55, 0.55, 0.53)
	-- Cañón (cilindro a lo largo de X), refuerzo de boca y ánima
	part(model, root, "Canon", Enum.PartType.Cylinder, Vector3.new(1.0, 0.24, 0.24), CFrame.new(at(0.75, 0, 0.62)), orange)
	part(model, root, "Boca", Enum.PartType.Cylinder, Vector3.new(0.12, 0.27, 0.27), CFrame.new(at(1.19, 0, 0.62)), orange)
	part(model, root, "Anima", Enum.PartType.Cylinder, Vector3.new(0.02, 0.15, 0.15), CFrame.new(at(1.26, 0, 0.62)), black)
	part(model, root, "Alza", Enum.PartType.Block, Vector3.new(0.06, 0.05, 0.03), CFrame.new(at(1.13, 0, 0.765)), orange)
	-- Armazón / recámara y bisagra
	part(model, root, "Armazon", Enum.PartType.Block, Vector3.new(0.35, 0.28, 0.20), CFrame.new(at(0.225, 0, 0.62)), orange)
	part(model, root, "Bisagra", Enum.PartType.Cylinder, Vector3.new(0.03, 0.22, 0.22), CFrame.new(at(0.36, 0.125, 0.52)) * CFrame.Angles(0, math.pi / 2, 0), metal, Enum.Material.Metal)
	-- Empuñadura inclinada hacia atrás, con cachas y culata
	local grip = CFrame.new(at(0.20, 0, 0.27)) * CFrame.Angles(0, 0, math.rad(18))
	part(model, root, "Empunadura", Enum.PartType.Block, Vector3.new(0.22, 0.54, 0.19), grip, orange)
	part(model, root, "Cachas", Enum.PartType.Block, Vector3.new(0.16, 0.40, 0.21), grip * CFrame.new(0.03, 0, 0), black)
	part(model, root, "Culata", Enum.PartType.Block, Vector3.new(0.22, 0.04, 0.19), grip * CFrame.new(0, -0.27, 0), black)
	-- Guardamonte, gatillo y martillo
	part(model, root, "Guardamonte", Enum.PartType.Block, Vector3.new(0.26, 0.03, 0.06), CFrame.new(at(0.31, 0, 0.375)), orange)
	part(model, root, "GuardamonteFrente", Enum.PartType.Block, Vector3.new(0.03, 0.13, 0.06), CFrame.new(at(0.425, 0, 0.425)), orange)
	part(model, root, "Gatillo", Enum.PartType.Block, Vector3.new(0.03, 0.09, 0.04), CFrame.new(at(0.335, 0, 0.445)) * CFrame.Angles(0, 0, math.rad(15)), black)
	part(model, root, "Martillo", Enum.PartType.Block, Vector3.new(0.05, 0.14, 0.06), CFrame.new(at(0.045, 0, 0.77)) * CFrame.Angles(0, 0, math.rad(-25)), black)
	return model
end

-- Rollo de venda de pie con banda roja (el rollo pequeño del kit): d 0.44 x alto 0.40
function BUILDERS.Bandage()
	local model, root = newModel("Vendas", 0.5)
	local function vc(name, z0, h, r, color, material)
		local cf = CFrame.new(G(0, 0, z0 + h / 2 - 0.2)) * CFrame.Angles(0, 0, math.pi / 2)
		return part(model, root, name, Enum.PartType.Cylinder, Vector3.new(h, r * 2, r * 2), cf, color, material)
	end
	vc("Rollo", 0, 0.40, 0.22, rgb(0.93, 0.91, 0.86), Enum.Material.Fabric)
	vc("Nucleo", 0.17, 0.06, 0.225, rgb(0.55, 0.53, 0.50), Enum.Material.SmoothPlastic)
	vc("NucleoBajo", 0.17 - 0.17, 0.06, 0.225, rgb(0.55, 0.53, 0.50), Enum.Material.SmoothPlastic)
	vc("Banda", 0.17, 0.06, 0.225, rgb(0.84, 0.27, 0.27), Enum.Material.Fabric)
	-- Tira que cuelga
	part(model, root, "Tira", Enum.PartType.Block, Vector3.new(0.02, 0.32, 0.18), CFrame.new(G(0.23, 0, 0.0)), rgb(0.93, 0.91, 0.86), Enum.Material.Fabric)
	return model
end

-- La bengala ya disparada: un cartucho rojo con la punta encendida (no viene en el kit)
function BUILDERS.Flare()
	local model, root = newModel("Bengala", 0.6)
	local cf = CFrame.Angles(0, 0, math.pi / 2) -- de pie
	part(model, root, "Cuerpo", Enum.PartType.Cylinder, Vector3.new(0.7, 0.14, 0.14), cf, rgb(0.89, 0.24, 0.19), Enum.Material.Neon)
	local tip = part(model, root, "Punta", Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 0.38, 0), rgb(1, 0.85, 0.5), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 80, 60)
	light.Brightness = 2
	light.Range = 14
	light.Parent = tip
	local sparks = Instance.new("ParticleEmitter")
	sparks.Rate = 30
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Speed = NumberRange.new(2, 5)
	sparks.SpreadAngle = Vector2.new(40, 40)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 150, 80))
	sparks.Size = NumberSequence.new(0.25, 0)
	sparks.LightEmission = 1
	sparks.Parent = tip
	return model
end

-- Botiquín: maletín rojo con cruz blanca, asa y cierres, 1.0 x 0.64 x 0.5 (frente = -Z, bisagra atrás = +Z). La tapa gira en una
-- Motor6D ("Tapa" dentro de la pieza "Tapa"); ItemModel.setLid la abre y la cierra. Dentro lleva gasas, un frasco y una cajita.
local LID_HINGE = Vector3.new(0, 0.02, 0.25) -- el borde de atrás de la base, donde gira la tapa
local LID_OPEN = math.rad(112)

function BUILDERS.Medkit()
	local model, root = newModel("Botiquin", 0.9)
	local red = rgb(0.78, 0.12, 0.11)
	local darkRed = rgb(0.58, 0.08, 0.08)
	local white = rgb(0.96, 0.96, 0.94)
	local black = rgb(0.13, 0.13, 0.15)
	local metal = rgb(0.72, 0.72, 0.70)
	local function vc(parent, name, x, y, z, h, r, color, material)
		return part(model, parent, name, Enum.PartType.Cylinder, Vector3.new(h, r * 2, r * 2), CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2), color, material)
	end

	-- Base abierta por arriba: caja, bandeja oscura y lo que lleva dentro
	part(model, root, "Base", Enum.PartType.Block, Vector3.new(1.0, 0.34, 0.5), CFrame.new(0, -0.15, 0), red)
	part(model, root, "Franja", Enum.PartType.Block, Vector3.new(1.02, 0.05, 0.52), CFrame.new(0, -0.30, 0), darkRed)
	part(model, root, "Bandeja", Enum.PartType.Block, Vector3.new(0.9, 0.02, 0.4), CFrame.new(0, 0.005, 0), rgb(0.16, 0.16, 0.18))
	vc(root, "Gasa1", -0.30, 0.095, -0.08, 0.17, 0.085, white, Enum.Material.Fabric)
	vc(root, "Gasa2", -0.12, 0.095, -0.08, 0.17, 0.085, white, Enum.Material.Fabric)
	vc(root, "GasaBanda", -0.30, 0.095, -0.08, 0.04, 0.09, rgb(0.84, 0.27, 0.27), Enum.Material.Fabric)
	vc(root, "Frasco", 0.14, 0.11, -0.05, 0.20, 0.07, rgb(0.25, 0.55, 0.85), Enum.Material.Glass)
	vc(root, "FrascoTapa", 0.14, 0.225, -0.05, 0.04, 0.05, white, Enum.Material.SmoothPlastic)
	part(model, root, "Cajita", Enum.PartType.Block, Vector3.new(0.22, 0.10, 0.16), CFrame.new(0.33, 0.06, -0.02), white)
	part(model, root, "CajitaCruz", Enum.PartType.Block, Vector3.new(0.10, 0.012, 0.03), CFrame.new(0.33, 0.112, -0.02), red)
	part(model, root, "Tubo", Enum.PartType.Block, Vector3.new(0.5, 0.05, 0.07), CFrame.new(0.05, 0.045, 0.16), rgb(0.88, 0.80, 0.55))
	-- Cierres a los lados del frente
	for _, x in { -0.32, 0.32 } do
		part(model, root, "CierreBase", Enum.PartType.Block, Vector3.new(0.14, 0.09, 0.035), CFrame.new(x, -0.02, -0.262), metal, Enum.Material.Metal)
	end

	-- Tapa: pieza con bisagra y todo lo que va pegado a ella
	local lid = part(model, root, "Tapa", Enum.PartType.Block, Vector3.new(1.0, 0.30, 0.5), CFrame.new(0, 0.17, 0), red)
	local weld = lid:FindFirstChildOfClass("WeldConstraint")
	weld:Destroy()
	local hinge = Instance.new("Motor6D")
	hinge.Name = "Bisagra"
	hinge.Part0 = root
	hinge.Part1 = lid
	hinge.C0 = CFrame.new(LID_HINGE)
	hinge.C1 = CFrame.new(LID_HINGE - lid.Position)
	hinge.Parent = lid
	part(model, lid, "TapaBorde", Enum.PartType.Block, Vector3.new(1.02, 0.05, 0.52), CFrame.new(0, 0.30, 0), darkRed)
	part(model, lid, "CruzH", Enum.PartType.Block, Vector3.new(0.36, 0.09, 0.016), CFrame.new(0, 0.17, -0.254), white)
	part(model, lid, "CruzV", Enum.PartType.Block, Vector3.new(0.09, 0.30, 0.016), CFrame.new(0, 0.17, -0.254), white)
	for _, x in { -0.32, 0.32 } do
		part(model, lid, "CierreTapa", Enum.PartType.Block, Vector3.new(0.14, 0.07, 0.035), CFrame.new(x, 0.065, -0.262), metal, Enum.Material.Metal)
	end
	-- Asa de goma sobre la tapa
	for _, x in { -0.20, 0.20 } do
		part(model, lid, "AsaPoste", Enum.PartType.Block, Vector3.new(0.07, 0.10, 0.09), CFrame.new(x, 0.37, 0), black)
	end
	part(model, lid, "Asa", Enum.PartType.Block, Vector3.new(0.47, 0.06, 0.11), CFrame.new(0, 0.44, 0), black)
	return model
end

-- Jeringa de mano (no viene en el kit): de pie, con la aguja hacia +Y. El émbolo y el líquido se mueven con ItemModel.setSyringe.
local SK = 0.65 -- tamaño de la jeringa de mano respecto al dibujo base (se ve bien de lejos)
local SYR = { barrel = 1.5 * SK, radius = 0.17 * SK, rod = 1.4 * SK, stopper = 0.09 * SK, margin = 0.1 * SK, travel = 1.15 * SK }
function BUILDERS.Syringe(options)
	local color = options and options.color or Color3.fromRGB(220, 50, 55)
	local liquidColor = color:Lerp(Color3.new(0, 0, 0), 0.3) -- el neón se quema con la luz: un poco más oscuro
	local model, root = newModel("Jeringa", 0.5)
	local half = SYR.barrel / 2
	local function cyl(name, y, length, radius, c, material, transparency)
		return part(model, root, name, Enum.PartType.Cylinder, Vector3.new(length, radius * 2, radius * 2), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), c, material, transparency)
	end
	local white = rgb(0.92, 0.94, 0.96)
	-- Cuerpo de vidrio, con unas marcas de dosis, el cuello, la aguja y la aleta para los dedos
	cyl("Cuerpo", 0, SYR.barrel, SYR.radius, white, Enum.Material.Glass, 0.6)
	for i = 1, 4 do
		part(model, root, "Marca", Enum.PartType.Block, Vector3.new(0.012 * SK, 0.02 * SK, SYR.radius * 2.05), CFrame.new(0, -half + i * SYR.barrel / 5, 0), rgb(0.1, 0.1, 0.12))
	end
	cyl("Cuello", half + 0.075 * SK, 0.15 * SK, 0.085 * SK, white, Enum.Material.SmoothPlastic)
	cyl("Aguja", half + 0.4 * SK, 0.5 * SK, 0.022 * SK, rgb(0.78, 0.8, 0.84), Enum.Material.Metal)
	part(model, root, "Aleta", Enum.PartType.Block, Vector3.new(0.78 * SK, 0.07 * SK, 0.22 * SK), CFrame.new(0, -half - 0.03 * SK, 0), white)
	part(model, root, "Anillo", Enum.PartType.Cylinder, Vector3.new(0.07 * SK, 0.4 * SK, 0.4 * SK), CFrame.new(0, half - 0.05 * SK, 0) * CFrame.Angles(0, 0, math.pi / 2), liquidColor, Enum.Material.SmoothPlastic)

	-- Piezas que se mueven: el líquido y el émbolo (con su tapón de goma y el disco para el pulgar)
	local function moving(name, size, c, material, transparency)
		local p = part(model, root, name, Enum.PartType.Cylinder, size, CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), c, material, transparency)
		p:FindFirstChildOfClass("WeldConstraint"):Destroy()
		local motor = Instance.new("Motor6D")
		motor.Name = name .. "Motor"
		motor.Part0 = root
		motor.Part1 = p
		motor.Parent = root
		return p, motor
	end
	local rod = moving("Embolo", Vector3.new(SYR.rod, 0.14 * SK, 0.14 * SK), rgb(0.9, 0.91, 0.93), Enum.Material.SmoothPlastic)
	moving("Liquido", Vector3.new(1, SYR.radius * 1.5, SYR.radius * 1.5), liquidColor, Enum.Material.Neon, 0.05)
	local function addToRod(name, y, length, radius, c, material)
		local p = part(model, root, name, Enum.PartType.Cylinder, Vector3.new(length, radius * 2, radius * 2), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), c, material)
		local weld = p:FindFirstChildOfClass("WeldConstraint")
		weld.Part0 = rod
		return p
	end
	addToRod("Tapon", SYR.rod / 2 - SYR.stopper, 0.18 * SK, SYR.radius * 0.98, rgb(0.12, 0.12, 0.14), Enum.Material.Rubber)
	addToRod("Disco", -SYR.rod / 2, 0.06 * SK, 0.25 * SK, white, Enum.Material.SmoothPlastic)
	ItemModel.setSyringe(model, 0)
	return model
end

-- Posición del émbolo de la jeringa de mano: 0 = lleno, 1 = vaciado
function ItemModel.setSyringe(model, f)
	local root = model and model.PrimaryPart
	local liquid = model and model:FindFirstChild("Liquido")
	local rodMotor = root and root:FindFirstChild("EmboloMotor")
	local liquidMotor = root and root:FindFirstChild("LiquidoMotor")
	if not (rodMotor and liquidMotor and liquid) then
		return
	end
	f = math.clamp(f, 0, 1)
	local half = SYR.barrel / 2
	local stopperY = -half + SYR.margin + f * SYR.travel -- centro del tapón
	local up = CFrame.Angles(0, 0, math.pi / 2)
	rodMotor.C0 = CFrame.new(0, stopperY - SYR.rod / 2 + SYR.stopper, 0) * up
	rodMotor.Part1.CFrame = root.CFrame * rodMotor.C0
	local length = math.max(0.05 * SK, half - (stopperY + SYR.stopper))
	liquid.Size = Vector3.new(length, liquid.Size.Y, liquid.Size.Z)
	liquidMotor.C0 = CFrame.new(0, (half + stopperY + SYR.stopper) / 2, 0) * up
	liquid.CFrame = root.CFrame * liquidMotor.C0
end

function ItemModel.setLid(model, open, duration)
	local lid = model and model:FindFirstChild("Tapa")
	local hinge = lid and lid:FindFirstChild("Bisagra")
	if not hinge then
		return
	end
	local goal = CFrame.new(LID_HINGE) * CFrame.Angles(open and LID_OPEN or 0, 0, 0)
	TweenService:Create(hinge, TweenInfo.new(duration or 0.4, open and Enum.EasingStyle.Back or Enum.EasingStyle.Quad, open and Enum.EasingDirection.Out or Enum.EasingDirection.In), { C0 = goal }):Play()
end

function ItemModel.build(kind)
	return BUILDERS[kind]()
end

-- Cómo se agarra cada objeto en la mano derecha. Mismo marco que Config.WeaponHold.HandGrip, con la pistola de bengalas
-- girada para que el cañón (+X) apunte hacia donde apunta el antebrazo.
local PALM = Vector3.new(0, -0.16, 0) -- la palma en el marco de RightHand (igual que Config.WeaponHold.HandGrip)
local FORWARD = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, -1, 0), Vector3.new(0, 0, -1)) -- cañón (+X) hacia los dedos, arriba hacia arriba
local UPRIGHT = CFrame.Angles(math.rad(-90), 0, 0) -- objetos de pie: la parte de arriba hacia arriba y el frente hacia delante
-- rot = orientación del objeto respecto a la mano; point = el punto del objeto (en su marco) que queda en la palma
local GRIPS = {
	Grenade = { rot = UPRIGHT, point = Vector3.zero },
	Molotov = { rot = UPRIGHT, point = Vector3.new(0, -0.25, 0) }, -- agarrada por la botella, la llama arriba
	FlareGun = { rot = FORWARD, point = Vector3.new(-0.48, -0.18, 0) }, -- por la empuñadura
	Bandage = { rot = UPRIGHT, point = Vector3.zero },
	Medkit = { rot = UPRIGHT, point = Vector3.new(0, 0.02, 0) }, -- por el canto de la base, con la tapa arriba
	Syringe = { rot = CFrame.Angles(math.pi, 0, 0), point = Vector3.new(0, -0.1, 0) }, -- por la parte baja del cuerpo, la aguja hacia delante
}

local HELD = { Grenade = "Grenade", Molotov = "Molotov", Flare = "FlareGun", Bandage = "Bandage", Medkit = "Medkit", Syringe = "Syringe" }

-- Muestra el objeto de `itemId` ("Grenade", "Molotov", "Flare", "Bandage", "Medkit") en la mano del jugador y esconde el arma activa.
-- Devuelve (una función que lo quita y restaura el arma, el modelo). Nil si el personaje no está listo.
function ItemModel.hold(player, itemId, options)
	local character = player.Character
	local hand = character and character:FindFirstChild("RightHand")
	local kind = HELD[itemId]
	if not (hand and kind) then
		return nil
	end
	local model = BUILDERS[kind](options)
	model.Name = "HandItem"
	local root = model.PrimaryPart
	root.CanCollide = false
	root.Massless = true
	local grip = GRIPS[kind]
	local c0 = CFrame.new(PALM) * grip.rot * CFrame.new(-grip.point)
	model:PivotTo(hand.CFrame * c0)
	local motor = Instance.new("Motor6D")
	motor.Name = "ItemGrip"
	motor.Part0 = hand
	motor.Part1 = root
	motor.C0 = c0
	motor.Parent = root
	model.Parent = character

	-- Esconde el arma activa mientras se usa el objeto
	local hidden = {}
	local weapon = character:FindFirstChild("HandWeapon")
	if weapon then
		for _, p in weapon:GetDescendants() do
			if p:IsA("BasePart") and p.Transparency < 1 and not p:FindFirstAncestor("MuzzleFlash") then
				hidden[p] = p.Transparency
				p.Transparency = 1
			end
		end
	end

	return function()
		model:Destroy()
		for p, transparency in hidden do
			if p.Parent then
				p.Transparency = transparency
			end
		end
	end, model
end

return ItemModel
