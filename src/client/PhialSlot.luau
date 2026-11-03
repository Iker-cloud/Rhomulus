-- Ranura de la Phial guardada: un panel a la izquierda de la pantalla con la Phial que el jugador sacó en la farmacia y todavía no usó
-- (atributo PhialId del jugador, lo pone server/Pharmacy al tomarla). Se usa cuando se quiera con la tecla Z o tocando el panel
-- (Remotes.PhialUi "use"); aparte del inventario de objetos. Se pierde al morir.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PhialIcon = require(script.Parent.PhialIcon)
local UiFit = require(script.Parent.UiFit)

local player = Players.LocalPlayer
local P = Config.Pharmacy

local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local OSWALD_LIGHT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Regular)
local BG = Color3.fromRGB(13, 13, 15)
local CREAM = Color3.fromRGB(236, 230, 218)
local GRAY = Color3.fromRGB(150, 148, 144)
local GOLD = Color3.fromRGB(246, 196, 70)

local PhialSlot = {}

local function label(parent, text, size, position, textSize, color, align, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.FontFace = font or OSWALD
	l.TextSize = textSize
	l.TextColor3 = color
	l.Text = text
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Parent = parent
	return l
end

function PhialSlot.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PhialSlot"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 12
	gui.Parent = player:WaitForChild("PlayerGui")

	local card = Instance.new("TextButton")
	card.AutoButtonColor = false
	card.AnchorPoint = Vector2.new(0, 0.5)
	card.Position = UDim2.new(0, 16, 0.42, 0)
	card.Size = UDim2.fromOffset(168, 218)
	card.BackgroundColor3 = BG
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.Text = ""
	card.Visible = false
	card.Parent = gui
	UiFit.scale(card)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = CREAM
	stroke.Parent = card
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

	label(card, "PHIAL", UDim2.fromOffset(100, 24), UDim2.fromOffset(12, 8), 20, GRAY, Enum.TextXAlignment.Left)
	local keyBadge = Instance.new("Frame")
	keyBadge.Size = UDim2.fromOffset(30, 26)
	keyBadge.Position = UDim2.new(1, -42, 0, 8)
	keyBadge.BackgroundColor3 = GOLD
	keyBadge.BorderSizePixel = 0
	keyBadge.Parent = card
	Instance.new("UICorner", keyBadge).CornerRadius = UDim.new(0, 5)
	label(keyBadge, "Z", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 20, Color3.fromRGB(16, 16, 16))

	local outer = Instance.new("Frame")
	outer.Size = UDim2.fromOffset(104, 104)
	outer.Position = UDim2.fromOffset(32, 42)
	outer.BorderSizePixel = 0
	outer.Parent = card
	Instance.new("UICorner", outer).CornerRadius = UDim.new(0.5, 0)
	local inner = Instance.new("Frame")
	inner.Size = UDim2.fromOffset(80, 80)
	inner.Position = UDim2.fromOffset(12, 12)
	inner.BorderSizePixel = 0
	inner.BackgroundTransparency = 0.25
	inner.Parent = outer
	Instance.new("UICorner", inner).CornerRadius = UDim.new(0.5, 0)

	local nameLabel = label(card, "", UDim2.new(1, -12, 0, 30), UDim2.fromOffset(6, 150), 26, CREAM)
	nameLabel.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 26
	limit.Parent = nameLabel
	local hint = label(card, "TAP OR PRESS Z", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 188), 15, GRAY, nil, OSWALD_LIGHT)

	local shownId = nil
	local icon = nil
	local function update()
		local id = player:GetAttribute("PhialId")
		local def = id and P.Effects[id]
		if not def then
			card.Visible = false
			shownId = nil
			return
		end
		card.Visible = true
		if shownId ~= id then
			shownId = id
			stroke.Color = def.Color
			outer.BackgroundColor3 = Color3.new(def.Color.R * 0.3, def.Color.G * 0.3, def.Color.B * 0.3)
			inner.BackgroundColor3 = Color3.new(def.Color.R * 0.5, def.Color.G * 0.5, def.Color.B * 0.5)
			if icon then
				icon:Destroy()
			end
			icon = PhialIcon.make(outer, def.Color, 92)
			nameLabel.Text = def.Upper
		end
		local usable = player:GetAttribute("State") == "Normal" and not player:GetAttribute("Injecting")
		card.BackgroundTransparency = usable and 0.08 or 0.5
		hint.Text = usable and "TAP OR PRESS Z" or "CAN'T DO THAT NOW"
	end

	local function use()
		if player:GetAttribute("PhialId") then
			Remotes.PhialUi:FireServer("use")
		end
	end
	card.Activated:Connect(use)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Z and not player:GetAttribute("UiOpen") then
			use()
		end
	end)
	for _, attribute in { "PhialId", "State", "Injecting" } do
		player:GetAttributeChangedSignal(attribute):Connect(update)
	end
	update()
end

return PhialSlot
