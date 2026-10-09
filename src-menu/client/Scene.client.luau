-- Fondo del menú: una calle de noche con niebla, faroles que parpadean y siluetas de zombies.
-- Se arma en el cliente, lejos del origen, y la cámara se mueve despacio.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ORIGIN = Vector3.new(0, 600, 0)
local rng = Random.new(11)

-- Luz y niebla ---------------------------------------------------------------
Lighting.ClockTime = 0
Lighting.Brightness = 0.6
Lighting.Ambient = Color3.fromRGB(30, 36, 60)
Lighting.OutdoorAmbient = Color3.fromRGB(36, 44, 72)
Lighting.ExposureCompensation = -0.2
Lighting.FogColor = Color3.fromRGB(34, 18, 20)
Lighting.FogStart = 20
Lighting.FogEnd = 240
for _, c in Lighting:GetChildren() do
	if c:IsA("Atmosphere") or c:IsA("Sky") or c:IsA("SunRaysEffect") then
		c:Destroy()
	end
end
for _, c in Lighting:GetChildren() do
	if c:IsA("PostEffect") then
		c:Destroy()
	end
end
local grade = Instance.new("ColorCorrectionEffect")
grade.Contrast = 0.14
grade.Saturation = -0.12
grade.TintColor = Color3.fromRGB(255, 232, 232)
grade.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.55
bloom.Size = 28
bloom.Threshold = 0.95
bloom.Parent = Lighting
local dof = Instance.new("DepthOfFieldEffect")
dof.FarIntensity = 0.3
dof.FocusDistance = 28
dof.InFocusRadius = 45
dof.NearIntensity = 0
dof.Parent = Lighting
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Offset = 0
atmosphere.Color = Color3.fromRGB(60, 36, 40)
atmosphere.Decay = Color3.fromRGB(30, 18, 24)
atmosphere.Glare = 0
atmosphere.Haze = 2
atmosphere.Parent = Lighting

-- Escena ---------------------------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = "MenuScene"
folder.Parent = Workspace

local function part(size, offset, color, material, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Position = ORIGIN + offset
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = folder
	return p
end

part(Vector3.new(300, 1, 400), Vector3.new(0, -0.5, -150), Color3.fromRGB(26, 26, 30), Enum.Material.Asphalt)
part(Vector3.new(60, 0.4, 400), Vector3.new(0, 0.1, -150), Color3.fromRGB(20, 20, 24), Enum.Material.Asphalt)
for z = 10, -300, -14 do -- línea central
	part(Vector3.new(0.6, 0.05, 6), Vector3.new(0, 0.35, z), Color3.fromRGB(150, 130, 60), Enum.Material.SmoothPlastic)
end

local flickers = {}

local function lamp(x, z)
	part(Vector3.new(0.7, 14, 0.7), Vector3.new(x, 7, z), Color3.fromRGB(18, 18, 20), Enum.Material.Metal)
	local head = part(Vector3.new(3, 0.5, 1.2), Vector3.new(x - math.sign(x) * 1.4, 14.2, z),
		Color3.fromRGB(240, 190, 110), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 110)
	light.Range = 34
	light.Brightness = 2.4
	light.Shadows = false
	light.Parent = head
	table.insert(flickers, { head = head, light = light, base = light.Brightness, phase = rng:NextNumber(0, 10), dead = rng:NextNumber() < 0.3 })
end

local function building(side, z)
	local h = rng:NextInteger(26, 52)
	local depth = rng:NextInteger(26, 34)
	local x = side * (30 + 14)
	local shade = rng:NextInteger(14, 26)
	part(Vector3.new(28, h, depth), Vector3.new(x, h / 2, z), Color3.fromRGB(shade, shade, shade + 4))
	-- ventanas hacia la calle: casi todas apagadas, alguna con luz
	for row = 1, math.floor(h / 8) do
		for col = -1, 1 do
			local lit = rng:NextNumber() < 0.12
			local w = part(Vector3.new(0.3, 3.4, 4),
				Vector3.new(side * 30 - side * 0.1, row * 8 - 2, z + col * 8),
				lit and Color3.fromRGB(255, 200, 120) or Color3.fromRGB(8, 8, 12),
				lit and Enum.Material.Neon or Enum.Material.Glass)
			if lit and rng:NextNumber() < 0.5 then
				table.insert(flickers, { head = w, base = 0, phase = rng:NextNumber(0, 10), window = true })
			end
		end
	end
end

for i = 0, 11 do
	local z = 10 - i * 30
	building(-1, z)
	building(1, z)
	if i % 2 == 0 then
		lamp(-27, z - 10)
		lamp(27, z - 25)
	end
end

-- Autos chocados y escombros (cajas oscuras)
for _, c in {
	{ -14, -42, 12 }, { 11, -78, -20 }, { -9, -118, 35 }, { 16, -150, 8 },
} do
	local car = part(Vector3.new(6, 2.4, 12), Vector3.new(c[1], 1.2, c[2]), Color3.fromRGB(32, 20, 20), Enum.Material.Metal)
	car.Orientation = Vector3.new(0, c[3], 0)
	local top = part(Vector3.new(5, 1.8, 6), Vector3.new(c[1], 3.1, c[2]), Color3.fromRGB(14, 16, 18), Enum.Material.Glass)
	top.Orientation = Vector3.new(0, c[3], 0)
end

-- Zombies: siluetas inmóviles que se balancean
local zombies = {}
local function zombie(x, z, scale)
	local model = Instance.new("Model")
	local skin = Color3.fromRGB(14, 16, 14)
	local function limb(size, off)
		local p = part(size * scale, (off * scale) + Vector3.new(x, 0, z), skin, Enum.Material.SmoothPlastic)
		p.Parent = model
		return p
	end
	limb(Vector3.new(1.6, 2.4, 0.9), Vector3.new(0, 3.6, 0)) -- torso
	limb(Vector3.new(1.1, 1.1, 1.1), Vector3.new(0.2, 5.4, 0)) -- cabeza
	limb(Vector3.new(0.6, 2.4, 0.6), Vector3.new(-1.1, 3.6, 0.8)) -- brazos al frente
	limb(Vector3.new(0.6, 2.4, 0.6), Vector3.new(1.1, 3.4, 0.9))
	limb(Vector3.new(0.7, 2.4, 0.7), Vector3.new(-0.45, 1.2, 0)) -- piernas
	limb(Vector3.new(0.7, 2.4, 0.7), Vector3.new(0.5, 1.2, 0))
	for _, ex in { -0.1, 0.5 } do
		local eye = limb(Vector3.new(0.18, 0.1, 0.1), Vector3.new(ex, 5.5, 0.56))
		eye.Material = Enum.Material.Neon
		eye.Color = Color3.fromRGB(220, 30, 30)
	end
	model.Parent = folder
	table.insert(zombies, { model = model, base = model:GetPivot(), phase = rng:NextNumber(0, 6) })
end
zombie(-6, -60, 1)
zombie(7, -82, 1.05)
zombie(-2, -104, 1)
zombie(10, -126, 1.1)
zombie(-11, -140, 1)
zombie(3, -165, 1.1)

-- Más detalle ---------------------------------------------------------------
-- Aceras elevadas
for _, side in { -1, 1 } do
	part(Vector3.new(14, 0.8, 400), Vector3.new(side * 22.5, 0.4, -150), Color3.fromRGB(40, 40, 44), Enum.Material.Concrete)
	part(Vector3.new(1, 1, 400), Vector3.new(side * 15.5, 0.5, -150), Color3.fromRGB(58, 58, 62), Enum.Material.Concrete)
end
-- Charcos que reflejan las luces
for _, c in { { -8, -20, 7 }, { 6, -38, 9 }, { -3, -64, 11 }, { 9, -92, 8 }, { -9, -120, 12 } } do
	local puddle = part(Vector3.new(0.05, c[3] * 0.6, c[3]), Vector3.new(c[1], 0.38, c[2]), Color3.fromRGB(10, 14, 22), Enum.Material.Glass)
	puddle.Reflectance = 0.55
	puddle.Shape = Enum.PartType.Cylinder
	puddle.Orientation = Vector3.new(0, 0, 90)
end

-- Carteles de tienda, en español, con neón que parpadea
local function sign(side, z, y, word, color)
	local board = part(Vector3.new(0.5, 3.2, 11), Vector3.new(side * 29.4, y, z), Color3.fromRGB(14, 14, 16), Enum.Material.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Face = side > 0 and Enum.NormalId.Left or Enum.NormalId.Right
	gui.LightInfluence = 0
	gui.Brightness = 3
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = word
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.Parent = gui
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 14
	glow.Brightness = 1.4
	glow.Parent = board
	table.insert(flickers, { sign = gui, glow = glow, phase = rng:NextNumber(0, 10), dead = rng:NextNumber() < 0.4 })
end
sign(1, -30, 8, "FARMACIA", Color3.fromRGB(80, 255, 140))
sign(-1, -52, 9, "TALLER", Color3.fromRGB(255, 70, 60))
sign(1, -78, 7, "BAR", Color3.fromRGB(255, 120, 60))
sign(-1, -102, 8, "TIENDA", Color3.fromRGB(255, 200, 90))
sign(1, -130, 9, "REFUGIO", Color3.fromRGB(110, 190, 255))

-- Tanques de agua en las azoteas
for i = 0, 11 do
	local z = 10 - i * 30
	for _, side in { -1, 1 } do
		if rng:NextNumber() < 0.6 then
			local tank = part(Vector3.new(5, 6, 6), Vector3.new(side * 44, 55 + rng:NextInteger(0, 4), z + rng:NextInteger(-6, 6)), Color3.fromRGB(22, 22, 26), Enum.Material.Metal)
			tank.Shape = Enum.PartType.Cylinder
			tank.Orientation = Vector3.new(0, 0, 90)
		end
	end
end

-- Barril encendido: fuego, humo, brasas y luz naranja que tiembla
local barrel = part(Vector3.new(3.4, 2.6, 2.6), Vector3.new(12, 1.7, -16), Color3.fromRGB(30, 22, 18), Enum.Material.Metal)
barrel.Shape = Enum.PartType.Cylinder
barrel.Orientation = Vector3.new(0, 0, 90)
local fire = Instance.new("Fire")
fire.Size = 6
fire.Heat = 9
fire.Color = Color3.fromRGB(255, 140, 40)
fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
fire.Parent = barrel
local smoke = Instance.new("Smoke")
smoke.Size = 6
smoke.Opacity = 0.35
smoke.RiseVelocity = 4
smoke.Color = Color3.fromRGB(60, 60, 60)
smoke.Parent = barrel
local fireLight = Instance.new("PointLight")
fireLight.Color = Color3.fromRGB(255, 140, 60)
fireLight.Range = 36
fireLight.Brightness = 3.2
fireLight.Shadows = false
fireLight.Parent = barrel
table.insert(flickers, { fireLight = fireLight, base = 3.2, phase = 3 })
local embers = Instance.new("ParticleEmitter")
embers.Rate = 14
embers.Lifetime = NumberRange.new(2, 3.5)
embers.Speed = NumberRange.new(5, 9)
embers.SpreadAngle = Vector2.new(25, 25)
embers.EmissionDirection = Enum.NormalId.Right
embers.Size = NumberSequence.new(0.14, 0)
embers.Color = ColorSequence.new(Color3.fromRGB(255, 170, 70))
embers.LightEmission = 1
embers.Acceleration = Vector3.new(0, 1.5, 0)
embers.Parent = barrel

-- Faros encendidos de un auto y balizas de otro
local headlights = part(Vector3.new(4.4, 0.8, 0.4), Vector3.new(11, 1.9, -84), Color3.fromRGB(255, 250, 215), Enum.Material.Neon)
headlights.Orientation = Vector3.new(0, -20, 0)
local beam = Instance.new("PointLight")
beam.Color = Color3.fromRGB(255, 245, 210)
beam.Range = 30
beam.Brightness = 2.2
beam.Shadows = false
beam.Parent = headlights
local hazard = part(Vector3.new(0.6, 0.6, 0.6), Vector3.new(-14, 2.6, -48), Color3.fromRGB(255, 130, 20), Enum.Material.Neon)
local hazardLight = Instance.new("PointLight")
hazardLight.Color = Color3.fromRGB(255, 130, 20)
hazardLight.Range = 16
hazardLight.Brightness = 2
hazardLight.Parent = hazard
table.insert(flickers, { hazard = hazard, hazardLight = hazardLight, phase = 0 })

-- Polvo y ceniza flotando por toda la calle
local dustBox = part(Vector3.new(70, 24, 130), Vector3.new(0, 12, -35), Color3.new(), Enum.Material.SmoothPlastic, { Transparency = 1 })
local dust = Instance.new("ParticleEmitter")
dust.Rate = 40
dust.Lifetime = NumberRange.new(8, 12)
dust.Speed = NumberRange.new(0.3, 1.2)
dust.Shape = Enum.ParticleEmitterShape.Box
dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
dust.SpreadAngle = Vector2.new(180, 180)
dust.Size = NumberSequence.new(0.18)
dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(0.8, 0.55), NumberSequenceKeypoint.new(1, 1) })
dust.Color = ColorSequence.new(Color3.fromRGB(190, 170, 165))
dust.LightEmission = 0.2
dust.Acceleration = Vector3.new(0.4, 0.1, 0)
dust.Parent = dustBox

-- Dos zombies más cerca, bajo la luz
zombie(-9, -30, 1.05)
zombie(6, -44, 1)

-- Cámara ----------------------------------------------------------------------
local camera = Workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 62

local t0 = os.clock()
RunService:BindToRenderStep("MenuScene", Enum.RenderPriority.Camera.Value + 1, function()
	local t = os.clock() - t0
	camera.CameraType = Enum.CameraType.Scriptable
	local pos = ORIGIN + Vector3.new(math.sin(t * 0.12) * 3 + 6, 6.5 + math.sin(t * 0.3) * 0.15, 30 - (math.sin(t * 0.05) + 1) * 5)
	-- mira hacia el fondo de la calle, algo a la izquierda: la calle queda a la derecha de la pantalla
	local look = ORIGIN + Vector3.new(-26 + math.sin(t * 0.09) * 4, 7, -120)
	camera.CFrame = CFrame.lookAt(pos, look)

	for _, f in flickers do
		if f.sign then
			local on
			if f.dead then
				on = (math.sin(t * 9 + f.phase) > 0.6) or (math.sin(t * 1.3 + f.phase) > 0.5)
			else
				on = math.noise(t * 2, f.phase) > -0.45
			end
			f.sign.Enabled = on
			f.glow.Enabled = on
		elseif f.fireLight then
			f.fireLight.Brightness = f.base * (0.75 + 0.35 * math.noise(t * 5, f.phase))
		elseif f.hazard then
			local on = (t % 1.2) < 0.45
			f.hazard.Material = on and Enum.Material.Neon or Enum.Material.Metal
			f.hazardLight.Enabled = on
		elseif f.window then
			f.head.Material = (math.sin(t * 6 + f.phase) > 0.2) and Enum.Material.Neon or Enum.Material.Glass
		elseif f.light then
			local on = true
			if f.dead then
				on = (math.sin(t * 11 + f.phase) > 0.75) and (math.sin(t * 1.7 + f.phase) > 0.2)
			else
				local n = math.noise(t * 3, f.phase)
				on = n > -0.35
			end
			f.light.Enabled = on
			f.head.Material = on and Enum.Material.Neon or Enum.Material.Metal
		end
	end
	for _, z in zombies do
		local sway = math.sin(t * 0.8 + z.phase) * 0.05
		z.model:PivotTo(z.base * CFrame.Angles(sway * 0.6, sway, sway))
	end
end)
