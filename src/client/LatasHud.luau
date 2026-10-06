-- Contador de latas del equipo: cartel con franjas de peligro, inclinado.
-- Animado: el número sube/baja contando, rebota al ganar, tiembla al gastar y suelta un "+25" flotante.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local YELLOW = Color3.fromRGB(255, 196, 30)
local BLACK = Color3.fromRGB(18, 18, 18)

local LatasHud = {}

local italic = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

function LatasHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LatasHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Marco con franjas amarillas y negras
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -24, 0, 90) -- debajo de la barra de vida de Roblox
	frame.Size = UDim2.fromOffset(210, 50)
	frame.Rotation = -3
	frame.BackgroundColor3 = YELLOW
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local stripes = {}
	local count = 9 -- máx. 20 puntos por degradado (2 por franja)
	for i = 0, count - 1 do
		local color = i % 2 == 0 and YELLOW or BLACK
		table.insert(stripes, ColorSequenceKeypoint.new(i / count, color))
		table.insert(stripes, ColorSequenceKeypoint.new(i == count - 1 and 1 or (i + 1) / count - 0.0001, color))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(stripes)
	gradient.Rotation = 45
	gradient.Parent = frame

	local inner = Instance.new("Frame")
	inner.Position = UDim2.fromOffset(5, 5)
	inner.Size = UDim2.new(1, -10, 1, -10)
	inner.BackgroundColor3 = BLACK
	inner.BorderSizePixel = 0
	inner.Parent = frame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 0)
	title.Size = UDim2.new(0.5, 0, 1, 0)
	title.FontFace = italic
	title.TextSize = 24
	title.TextColor3 = YELLOW
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "LATAS"
	title.Parent = inner

	local number = Instance.new("TextLabel")
	number.AnchorPoint = Vector2.new(1, 0.5)
	number.BackgroundTransparency = 1
	number.Position = UDim2.new(1, -12, 0.5, 0)
	number.Size = UDim2.new(0.5, 0, 1, 0)
	number.FontFace = italic
	number.TextSize = 32
	number.TextColor3 = Color3.new(1, 1, 1)
	number.TextXAlignment = Enum.TextXAlignment.Right
	number.Parent = inner
	local numberScale = Instance.new("UIScale")
	numberScale.Parent = number

	-- "+25" flotante
	local function popup(amount)
		local pop = Instance.new("TextLabel")
		pop.AnchorPoint = Vector2.new(1, 0)
		pop.BackgroundTransparency = 1
		pop.Position = UDim2.new(1, -30, 0, 142)
		pop.Size = UDim2.fromOffset(90, 28)
		pop.FontFace = italic
		pop.TextSize = 24
		pop.TextColor3 = amount > 0 and YELLOW or Color3.fromRGB(255, 90, 70)
		pop.TextStrokeTransparency = 0.4
		pop.TextXAlignment = Enum.TextXAlignment.Right
		pop.Text = amount > 0 and `+{amount}` or tostring(amount)
		pop.Parent = gui
		TweenService:Create(pop, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(1, -30, 0, 118),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		Debris:AddItem(pop, 1)
	end

	local target = workspace:GetAttribute("Points") or 0
	local displayed = target
	local shake = 0

	workspace:GetAttributeChangedSignal("Points"):Connect(function()
		local value = workspace:GetAttribute("Points") or 0
		local delta = value - target
		target = value
		if delta > 0 then
			popup(delta)
			numberScale.Scale = 1.4
			number.TextColor3 = YELLOW
		elseif delta < 0 then
			popup(delta)
			shake = 1
			number.TextColor3 = Color3.fromRGB(255, 90, 70)
		end
	end)

	local basePosition = frame.Position
	RunService.Heartbeat:Connect(function(dt)
		-- Cuenta hacia el valor real
		displayed += (target - displayed) * math.min(1, dt * 7)
		if math.abs(target - displayed) < 0.5 then
			displayed = target
		end
		number.Text = tostring(math.floor(displayed + 0.5))

		-- Rebote y color vuelven a lo normal
		numberScale.Scale += (1 - numberScale.Scale) * math.min(1, dt * 10)
		number.TextColor3 = number.TextColor3:Lerp(Color3.new(1, 1, 1), math.min(1, dt * 4))

		shake = math.max(0, shake - dt * 4)
		frame.Position = basePosition + UDim2.fromOffset((math.random() - 0.5) * 10 * shake, (math.random() - 0.5) * 10 * shake)
	end)
end

return LatasHud
