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
		if f.window then
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
