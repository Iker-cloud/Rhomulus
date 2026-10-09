-- Prueba de acción al revivir (cliente): un aro con una zona buena y una aguja que lo recorre. Se pulsa Espacio (o se toca
-- el aro en celular) cuando la aguja pasa por la zona. El servidor (server/SkillCheck + Revive) manda los números y decide;
-- aquí solo se dibuja y se avisa cuándo se pulsó. Con la prueba activa, Espacio no salta.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SIZE = 170 -- diámetro del aro (px)
local ARM_STEP = 2.5 -- grados entre una rayita de la zona y la siguiente
local MAX_ARMS = 48
local WHITE = Color3.fromRGB(245, 245, 245)
local RED = Color3.fromRGB(235, 50, 45)
local GREEN = Color3.fromRGB(110, 235, 130)
local ACTION = "SkillCheckPress"

local SkillCheck = {}

function SkillCheck.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SkillCheck"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.42)
	root.Size = UDim2.fromOffset(SIZE, SIZE)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root

	-- Fondo oscuro y aro
	local disc = Instance.new("Frame")
	disc.Size = UDim2.fromScale(1, 1)
	disc.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	disc.BackgroundTransparency = 0.25
	disc.BorderSizePixel = 0
	disc.Parent = root
	Instance.new("UICorner", disc).CornerRadius = UDim.new(1, 0)
	local ring = Instance.new("UIStroke")
	ring.Color = WHITE
	ring.Thickness = 3
	ring.Transparency = 0.1
	ring.Parent = disc

	-- Zona buena: rayitas radiales (se colocan al empezar cada prueba)
	local arms = {}
	for i = 1, MAX_ARMS do
		local arm = Instance.new("Frame")
		arm.Size = UDim2.fromScale(1, 1)
		arm.BackgroundTransparency = 1
		arm.Visible = false
		arm.Parent = root
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.Position = UDim2.fromOffset(SIZE / 2, 1)
		bar.Size = UDim2.fromOffset(6, 20)
		bar.BackgroundColor3 = WHITE
		bar.BorderSizePixel = 0
		bar.Parent = arm
		arms[i] = arm
	end

	-- Aguja
	local needleHolder = Instance.new("Frame")
	needleHolder.Size = UDim2.fromScale(1, 1)
	needleHolder.BackgroundTransparency = 1
	needleHolder.Visible = false
	needleHolder.Parent = root
	local needle = Instance.new("Frame")
	needle.AnchorPoint = Vector2.new(0.5, 1)
	needle.Position = UDim2.fromScale(0.5, 0.5)
	needle.Size = UDim2.fromOffset(3, SIZE / 2 - 8)
	needle.BackgroundColor3 = RED
	needle.BorderSizePixel = 0
	needle.Parent = needleHolder

	-- Tecla en el centro, como en el aviso de cualquier prueba de acción: "[ESPACIO]"
	local keyBox = Instance.new("Frame")
	keyBox.AnchorPoint = Vector2.new(0.5, 0.5)
	keyBox.Position = UDim2.fromScale(0.5, 0.5)
	keyBox.Size = UDim2.fromOffset(74, 34)
	keyBox.BackgroundColor3 = Color3.fromRGB(26, 26, 30)
	keyBox.BorderSizePixel = 0
	keyBox.Parent = root
	Instance.new("UICorner", keyBox).CornerRadius = UDim.new(0, 8)
	local keyStroke = Instance.new("UIStroke")
	keyStroke.Color = WHITE
	keyStroke.Thickness = 1.5
	keyStroke.Parent = keyBox
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Size = UDim2.fromScale(1, 1)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.TextSize = 15
	keyLabel.TextColor3 = WHITE
	keyLabel.Text = "ESPACIO"
	keyLabel.Parent = keyBox

	-- En celular: tocar el aro
	local tap = Instance.new("TextButton")
	tap.Size = UDim2.fromScale(1, 1)
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.ZIndex = 5
	tap.Parent = root

	local check = nil -- { id, start, period, pressed, ending }
	local connection = nil

	local function setRingColor(color)
		ring.Color = color
		keyStroke.Color = color
	end

	local function hide()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		ContextActionService:UnbindAction(ACTION)
		check = nil
		root.Visible = false
	end

	local function press()
		if not check or check.pressed then
			return
		end
		check.pressed = true
		Remotes.SkillCheckPress:FireServer(check.id, workspace:GetServerTimeNow())
		keyBox.BackgroundColor3 = Color3.fromRGB(70, 70, 76) -- la aguja se queda donde estaba hasta que llegue el resultado
	end
	tap.Activated:Connect(press)

	local function begin(id, startTime, period, zoneStart, zoneSize)
		hide()
		check = { id = id, start = startTime, period = period, pressed = false }
		setRingColor(WHITE)
		keyBox.BackgroundColor3 = Color3.fromRGB(26, 26, 30)
		for i, arm in arms do
			local offset = (i - 1) * ARM_STEP
			arm.Visible = offset <= zoneSize
			arm.Rotation = zoneStart + offset
		end
		needleHolder.Visible = false
		root.Visible = true
		scale.Scale = 0.7
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

		-- Mientras dura la prueba, Espacio solo sirve para esto (no salta)
		ContextActionService:BindActionAtPriority(ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then
				press()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space)

		connection = RunService.RenderStepped:Connect(function()
			if not check or check.pressed then
				return
			end
			local elapsed = workspace:GetServerTimeNow() - check.start
			if elapsed < 0 then
				return -- la aguja todavía no sale
			end
			needleHolder.Visible = true
			needleHolder.Rotation = math.clamp(elapsed / check.period, 0, 1) * 360
			if elapsed > check.period + Config.SkillCheck.Tolerance + 0.2 then
				hide() -- no pulsó: el servidor ya lo marca como fallo
			end
		end)
	end

	local function result(ok)
		if connection then
			connection:Disconnect()
			connection = nil
		end
		ContextActionService:UnbindAction(ACTION)
		check = nil
		setRingColor(ok and GREEN or RED)
		keyLabel.Text = ok and "¡BIEN!" or "¡FALLÓ!"
		keyLabel.TextColor3 = ok and GREEN or RED
		task.delay(0.6, function()
			keyLabel.Text = "ESPACIO"
			keyLabel.TextColor3 = WHITE
			if not check then
				root.Visible = false
			end
		end)
	end

	Remotes.SkillCheck.OnClientEvent:Connect(function(kind, ...)
		if kind == "start" then
			begin(...)
		elseif kind == "result" then
			result(...)
		elseif kind == "cancel" then
			hide()
		end
	end)
end

return SkillCheck
