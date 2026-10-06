-- Barra de vida de los zombies y los maniquíes: nombre arriba, calavera en un círculo, barra inclinada y el número de vida.
-- Solo aparece sobre los zombies heridos y cercanos. Se dibuja en el cliente a partir de Humanoid.DisplayName.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Icons = require(script.Parent.Icons)
local Slant = require(script.Parent.Slant)

local player = Players.LocalPlayer

local BAR_WIDTH = 112
local BAR_HEIGHT = 14
local SLANT = 8
local SHOW_DISTANCE = 60

local BLOOD = Color3.fromRGB(226, 75, 60)
local LOW = Color3.fromRGB(255, 142, 50)
local LOW_RATIO = 0.35
local BAR_BACK = Color3.fromRGB(16, 16, 18)
local BONE = Color3.fromRGB(235, 228, 210)

local EnemyBars = {}

local bars = {} -- [Model] = { gui, humanoid, root, ... }

local function rect(parent, size, position, color, rotation)
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Rotation = rotation or 0
	frame.Parent = parent
	return frame
end

local function build(model)
	if bars[model] then
		return
	end
	local humanoid = model:WaitForChild("Humanoid", 5)
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if not (humanoid and root) then
		return
	end
	task.wait(0.5) -- espera a que lleguen todas las piezas para medir el alto del modelo
	if not model.Parent then
		return
	end

	local boxCFrame, boxSize = model:GetBoundingBox()
	local height = boxCFrame.Position.Y + boxSize.Y / 2 - root.Position.Y + 1.2

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 80)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.Adornee = root
	gui.AlwaysOnTop = false
	gui.MaxDistance = SHOW_DISTANCE + 20
	gui.Enabled = false
	gui.ResetOnSpawn = false

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.new(0.5, 6, 0, 6)
	name.Size = UDim2.fromOffset(240, 18)
	name.Font = Enum.Font.GothamBlack
	name.TextSize = 15
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.35
	name.Text = Slant.upper(humanoid.DisplayName)
	name.Parent = gui

	-- Barra inclinada: fondo oscuro y relleno que se acorta con la vida
	local back = Instance.new("Frame")
	back.BackgroundTransparency = 1
	back.Position = UDim2.fromOffset(78, 36)
	back.ZIndex = 1
	back.Parent = gui
	Slant.fill(back, BAR_WIDTH, BAR_HEIGHT, SLANT, BAR_BACK)

	local fill = Instance.new("Frame")
	fill.BackgroundTransparency = 1
	fill.Position = UDim2.fromOffset(78, 36)
	fill.ZIndex = 2
	fill.Parent = gui

	-- Círculo con la calavera
	local circle = Instance.new("Frame")
	circle.Size = UDim2.fromOffset(32, 32)
	circle.Position = UDim2.fromOffset(60, 27)
	circle.BackgroundColor3 = BAR_BACK
	circle.BorderSizePixel = 0
	circle.ZIndex = 5
	circle.Parent = gui
	Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
	local ring = Instance.new("UIStroke")
	ring.Thickness = 2.5
	ring.Parent = circle
	Icons.skull(circle, 1)

	local number = Instance.new("TextLabel")
	number.BackgroundTransparency = 1
	number.Position = UDim2.fromOffset(78 + BAR_WIDTH + 6, 36)
	number.Size = UDim2.fromOffset(44, BAR_HEIGHT)
	number.Font = Enum.Font.GothamBlack
	number.TextSize = 15
	number.TextXAlignment = Enum.TextXAlignment.Left
	number.TextStrokeTransparency = 0.5
	number.Parent = gui

	gui.Parent = root
	bars[model] = {
		gui = gui,
		humanoid = humanoid,
		root = root,
		fill = fill,
		ring = ring,
		number = number,
		displayed = humanoid.Health / humanoid.MaxHealth,
		drawnWidth = -1,
		drawnColor = nil,
	}
	model.Destroying:Connect(function()
		bars[model] = nil
	end)
end

local function update(bar, dt)
	local humanoid = bar.humanoid
	local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
	bar.displayed += (ratio - bar.displayed) * math.min(1, dt * 12)

	local color = ratio <= LOW_RATIO and LOW or BLOOD
	local width = math.floor(BAR_WIDTH * bar.displayed + 0.5)
	-- Solo se redibuja si cambió el ancho o el color (son 10 franjas)
	if width ~= bar.drawnWidth or color ~= bar.drawnColor then
		bar.drawnWidth = width
		bar.drawnColor = color
		if width > SLANT then
			Slant.fill(bar.fill, width, BAR_HEIGHT, SLANT, color)
		else
			Slant.fill(bar.fill, 0, BAR_HEIGHT, SLANT, color)
		end
		bar.ring.Color = color
		bar.number.TextColor3 = color
	end
	bar.number.Text = tostring(math.ceil(humanoid.Health))
end

local function watch(folder)
	for _, model in folder:GetChildren() do
		task.spawn(build, model)
	end
	folder.ChildAdded:Connect(function(model)
		task.spawn(build, model)
	end)
end

function EnemyBars.start()
	watch(workspace:WaitForChild("Zombies"))
	watch(workspace:WaitForChild("Dummies"))

	RunService.Heartbeat:Connect(function(dt)
		local camera = workspace.CurrentCamera
		for _, bar in bars do
			local humanoid = bar.humanoid
			local damaged = humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth
			local near = (bar.root.Position - camera.CFrame.Position).Magnitude <= SHOW_DISTANCE
			local visible = damaged and near
			-- Se apaga por completo (la transparencia sola no oculta bien los carteles)
			if bar.gui.Enabled ~= visible then
				bar.gui.Enabled = visible
			end
			if visible then
				update(bar, dt)
			end
		end
	end)
end

return EnemyBars
