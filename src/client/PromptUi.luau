-- Interfaz propia de los ProximityPrompt: tecla amarilla + placa oscura inclinada con el texto,
-- el precio debajo (ObjectText) y una barra que se llena mientras se mantiene la tecla.
-- Solo se aplica a los prompts con Style = Custom (los crea el servidor).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local Slant = require(script.Parent.Slant)

local player = Players.LocalPlayer

local YELLOW = Color3.fromRGB(245, 200, 70)
local PLATE = Color3.fromRGB(14, 17, 22)
local HEIGHT = 52
local SLANT = 12

local PromptUi = {}

local function label(parent, size, color, position)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.FontFace = Slant.FONT
	text.TextSize = size
	text.TextColor3 = color
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Position = position
	text.ZIndex = 5
	text.Parent = parent
	return text
end

local function show(prompt)
	local gui = Instance.new("BillboardGui")
	gui.Adornee = prompt.Parent
	gui.Size = UDim2.fromOffset(460, 90 + math.abs(prompt.UIOffset.Y) * 2)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.AlwaysOnTop = true
	gui.ResetOnSpawn = false
	gui.MaxDistance = 1000

	local group = Instance.new("CanvasGroup")
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.new(0.5, prompt.UIOffset.X - 30, 0.5, prompt.UIOffset.Y)
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Parent = group

	-- Tecla
	local keyHolder = Instance.new("Frame")
	keyHolder.BackgroundTransparency = 1
	keyHolder.AnchorPoint = Vector2.new(0, 0.5)
	keyHolder.Position = UDim2.new(0, 14, 0.5, 0)
	keyHolder.Parent = group
	Slant.fill(keyHolder, 52, HEIGHT, SLANT, YELLOW)
	local keyLabel = label(keyHolder, 28, Color3.fromRGB(20, 20, 20), UDim2.fromOffset(SLANT / 2, 0))
	keyLabel.Size = UDim2.fromOffset(52 - SLANT, HEIGHT)
	keyLabel.TextXAlignment = Enum.TextXAlignment.Center
	keyLabel.Text = prompt.KeyboardKeyCode.Name

	-- Placa de texto
	local plateHolder = Instance.new("Frame")
	plateHolder.BackgroundTransparency = 1
	plateHolder.AnchorPoint = Vector2.new(0, 0.5)
	plateHolder.Position = UDim2.new(0, 14 + 52 + 2, 0.5, 0)
	plateHolder.Parent = group

	local action = label(plateHolder, 22, Color3.fromRGB(240, 240, 240), UDim2.fromOffset(SLANT + 12, 0))
	local object = label(plateHolder, 14, YELLOW, UDim2.fromOffset(SLANT + 12, 0))

	-- Barra de mantener presionado
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = YELLOW
	fill.BackgroundTransparency = 0.55
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromOffset(0, HEIGHT)
	fill.ZIndex = 4
	fill.Parent = plateHolder
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = YELLOW
	bar.BorderSizePixel = 0
	bar.Size = UDim2.fromOffset(0, 6)
	bar.ZIndex = 6
	bar.Parent = plateHolder

	local function render()
		local actionText = Slant.upper(prompt.ActionText)
		local objectText = Slant.upper(prompt.ObjectText)
		local width = math.max(Slant.textWidth(actionText, 22), Slant.textWidth(objectText, 14)) + SLANT + 40
		Slant.fill(plateHolder, width, HEIGHT, SLANT, PLATE)

		action.Text = actionText
		object.Text = objectText
		if objectText == "" then
			action.Size = UDim2.fromOffset(width, HEIGHT)
			object.Size = UDim2.fromOffset(0, 0)
		else
			action.Size = UDim2.fromOffset(width, HEIGHT - 16)
			object.Size = UDim2.fromOffset(width, 16)
			object.Position = UDim2.fromOffset(SLANT + 12, HEIGHT - 20)
		end
		bar.Position = UDim2.fromOffset(SLANT / 2, HEIGHT - 6)
		bar.Size = UDim2.fromOffset(0, 6)
		fill.Position = UDim2.fromOffset(SLANT / 2, 0)
		fill.Size = UDim2.fromOffset(0, HEIGHT)
	end
	render()

	local connections = {}
	table.insert(connections, prompt:GetPropertyChangedSignal("ActionText"):Connect(render))
	table.insert(connections, prompt:GetPropertyChangedSignal("ObjectText"):Connect(render))

	table.insert(connections, prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration > 0 then
			local full = plateHolder.AbsoluteSize.X - SLANT
			TweenService:Create(bar, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromOffset(full, 6) }):Play()
			TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromOffset(full, HEIGHT) }):Play()
		end
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
	end))
	table.insert(connections, prompt.PromptButtonHoldEnded:Connect(function()
		TweenService:Create(bar, TweenInfo.new(0.12), { Size = UDim2.fromOffset(0, 6) }):Play()
		TweenService:Create(fill, TweenInfo.new(0.12), { Size = UDim2.fromOffset(0, HEIGHT) }):Play()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end))
	table.insert(connections, prompt.Triggered:Connect(function()
		scale.Scale = 1.15
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end))

	-- Aparece deslizándose desde la izquierda
	gui.Parent = player:WaitForChild("PlayerGui")
	TweenService:Create(group, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		GroupTransparency = 0,
		Position = UDim2.new(0.5, prompt.UIOffset.X, 0.5, prompt.UIOffset.Y),
	}):Play()

	-- Se quita al ocultarse el prompt, y también si se apaga, se destruye o el jugador se aleja (por si PromptHidden no llega)
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		for _, connection in connections do
			connection:Disconnect()
		end
		TweenService:Create(group, TweenInfo.new(0.15), { GroupTransparency = 1 }):Play()
		task.delay(0.16, function()
			gui:Destroy()
		end)
	end
	prompt.PromptHidden:Once(close)
	table.insert(connections, prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not prompt.Enabled then
			close()
		end
	end))
	table.insert(connections, prompt.AncestryChanged:Connect(function()
		if not prompt:IsDescendantOf(workspace) then
			close()
		end
	end))
	task.spawn(function()
		while not closed do
			task.wait(0.5)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local part = prompt.Parent
			if not (root and part and part:IsA("BasePart")) or (root.Position - part.Position).Magnitude > prompt.MaxActivationDistance + 8 then
				close()
			end
		end
	end)
end

function PromptUi.start()
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			show(prompt)
		end
	end)
end

return PromptUi
