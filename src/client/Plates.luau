-- Placas de señalética sobre los objetivos (Munición, Caja de armas, Radio, Generador).
-- El servidor marca la parte con el tag "Plate" y los atributos PlateText, PlateColor, PlateRange (y PlateHeight opcional).
-- Aparecen con un pequeño rebote al acercarte y se desvanecen al alejarte.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Slant = require(script.Parent.Slant)

local player = Players.LocalPlayer

local TEXT_SIZE = 20
local HEIGHT = 38
local SLANT = 12
local CLOSE = 10 -- a esta distancia o menos no se revisa la línea de vista

local Plates = {}

local plates = {} -- [Part] = { shown, group, scale, ... }

local function layout(plate, part)
	local text = Slant.upper(part:GetAttribute("PlateText") or "")
	local color = part:GetAttribute("PlateColor") or Color3.fromRGB(245, 200, 70)
	local width = math.ceil(Slant.textWidth(text, TEXT_SIZE)) + 36
	Slant.fill(plate.holder, width, HEIGHT, SLANT, color)
	plate.label.Text = text
	plate.label.Size = UDim2.fromOffset(width - SLANT, HEIGHT)
end

local function build(part)
	if plates[part] then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(420, 70)
	gui.StudsOffset = Vector3.new(0, part:GetAttribute("PlateHeight") or part.Size.Y / 2 + 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 1000
	gui.Adornee = part
	gui.Enabled = false -- apagada hasta que te acerques (la transparencia sola no la oculta del todo)

	local group = Instance.new("CanvasGroup")
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.5)
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = group

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Parent = group

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.FontFace = Slant.FONT
	label.TextSize = TEXT_SIZE
	label.TextColor3 = Color3.fromRGB(20, 20, 20)
	label.ZIndex = 5
	label.Parent = holder

	local plate = { gui = gui, group = group, scale = scale, holder = holder, label = label, shown = false }
	plates[part] = plate
	gui.Parent = part
	layout(plate, part)

	for _, attribute in { "PlateText", "PlateColor" } do
		part:GetAttributeChangedSignal(attribute):Connect(function()
			layout(plate, part)
		end)
	end
	part.Destroying:Connect(function()
		plates[part] = nil
	end)
end

local function setShown(plate, shown)
	if plate.shown == shown then
		return
	end
	plate.shown = shown
	if shown then
		plate.gui.Enabled = true
		TweenService:Create(plate.scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(plate.group, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
	else
		TweenService:Create(plate.scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.7 }):Play()
		TweenService:Create(plate.group, TweenInfo.new(0.18), { GroupTransparency = 1 }):Play()
		task.delay(0.2, function()
			if not plate.shown then
				plate.gui.Enabled = false
			end
		end)
	end
end

-- Solo se muestra si no hay una pared u obstáculo entre tu cámara y el objetivo
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function hasLineOfSight(part)
	local camera = workspace.CurrentCamera
	local filter = { workspace:FindFirstChild("Zombies") }
	if player.Character then
		table.insert(filter, player.Character)
	end
	sightParams.FilterDescendantsInstances = filter

	local origin = camera.CFrame.Position
	local hit = workspace:Raycast(origin, part.Position - origin, sightParams)
	if not hit then
		return true
	end
	if hit.Instance == part then
		return true
	end
	-- Objetos formados por varias partes (la caja de armas)
	return part.Parent:IsA("Model") and hit.Instance:IsDescendantOf(part.Parent)
end

function Plates.start()
	for _, part in CollectionService:GetTagged("Plate") do
		task.spawn(build, part)
	end
	CollectionService:GetInstanceAddedSignal("Plate"):Connect(function(part)
		task.spawn(build, part)
	end)

	task.spawn(function()
		while true do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			for part, plate in plates do
				local range = part:GetAttribute("PlateRange") or 20
				local distance = root and (root.Position - part.Position).Magnitude or math.huge
				-- Muy cerca siempre se ve; más lejos solo si no hay una pared en medio
				setShown(plate, distance <= range and (distance <= CLOSE or hasLineOfSight(part)))
			end
			task.wait(0.1)
		end
	end)
end

return Plates
