-- Contador de latas del equipo: el círculo con la lata (client/CanIcon) y la cuenta en una píldora.
-- Animado: el número sube/baja contando, rebota al ganar, tiembla al gastar y suelta un "+25" flotante.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CanIcon = require(script.Parent.CanIcon)
local UiFit = require(script.Parent.UiFit)
local player = Players.LocalPlayer

local YELLOW = Color3.fromRGB(255, 196, 30)
local BLACK = Color3.fromRGB(18, 18, 18)

local LatasHud = {}

local italic = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

function LatasHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LatasHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Círculo con la lata y, a su lado, la cuenta en una píldora ("× 0")
	local CREAM = Color3.fromRGB(214, 208, 196)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -24, 0, 90) -- debajo de la barra de vida de Roblox
	frame.Size = UDim2.fromOffset(190, 72)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	UiFit.scale(frame, 0.75) -- más chico: no tape la partida

	local pill = Instance.new("Frame")
	pill.Position = UDim2.fromOffset(48, 13)
	pill.Size = UDim2.fromOffset(140, 46)
	pill.BackgroundColor3 = Color3.fromRGB(28, 26, 24)
	pill.BorderSizePixel = 0
	pill.Parent = frame
	Instance.new("UICorner", pill).CornerRadius = UDim.new(0.5, 0)
	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color = CREAM
	pillStroke.Thickness = 5
	pillStroke.Parent = pill

	local badge = Instance.new("Frame")
	badge.Size = UDim2.fromOffset(72, 72)
	badge.BackgroundColor3 = Color3.fromRGB(28, 26, 24)
	badge.BorderSizePixel = 0
	badge.ZIndex = 2
	badge.Parent = frame
	Instance.new("UICorner", badge).CornerRadius = UDim.new(0.5, 0)
	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = CREAM
	badgeStroke.Thickness = 5
	badgeStroke.Parent = badge
	local can = CanIcon.make(badge, 44)
	can.ZIndex = 3
	for _, child in can:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 3
		end
	end

	local inner = pill -- el texto va dentro de la píldora

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(34, 0)
	title.Size = UDim2.fromOffset(24, 46)
	title.FontFace = OSWALD
	title.TextSize = 26
	title.TextColor3 = CREAM
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "×"
	title.Parent = inner

	local number = Instance.new("TextLabel")
	number.AnchorPoint = Vector2.new(0, 0.5)
	number.BackgroundTransparency = 1
	number.Position = UDim2.new(0, 62, 0.5, 0)
	number.Size = UDim2.fromOffset(70, 46)
	number.FontFace = OSWALD
	number.TextSize = 34
	number.TextColor3 = Color3.new(1, 1, 1)
	number.TextXAlignment = Enum.TextXAlignment.Left
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
