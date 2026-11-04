-- Tarjeta compacta de "caído": cinta roja, calavera, la cuenta atrás de la sangre y qué hacer.
-- Es chica a propósito: quien está caído sigue disparando la pistola y necesita ver la pantalla.
local TweenService = game:GetService("TweenService")

local Icons = require(script.Parent.Icons)

local RED = Color3.fromRGB(226, 66, 54)
local DARK = Color3.fromRGB(14, 13, 13)

local DownedHud = {}

function DownedHud.create(gui)
	local card = Instance.new("CanvasGroup")
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 12)
	card.Size = UDim2.fromOffset(340, 64)
	card.BackgroundColor3 = DARK
	card.BorderSizePixel = 0
	card.GroupTransparency = 1
	card.Visible = false
	card.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = RED
	stroke.Transparency = 0.4
	stroke.Parent = card
	local scale = Instance.new("UIScale")
	scale.Parent = card

	Icons.tape(card, UDim2.new(1, 0, 0, 6), UDim2.fromOffset(0, 0), RED, Color3.fromRGB(20, 12, 12))

	-- Calavera en un círculo
	local circle = Instance.new("Frame")
	circle.Position = UDim2.fromOffset(10, 14)
	circle.Size = UDim2.fromOffset(40, 40)
	circle.BackgroundColor3 = Color3.fromRGB(20, 14, 14)
	circle.BorderSizePixel = 0
	circle.Parent = card
	Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
	local ring = Instance.new("UIStroke")
	ring.Color = RED
	ring.Thickness = 2.5
	ring.Parent = circle
	Icons.skull(circle, 1.2)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(60, 10)
	title.Size = UDim2.fromOffset(200, 24)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 20
	title.TextColor3 = RED
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "YOU'RE DOWN"
	title.Parent = card

	local seconds = Instance.new("TextLabel")
	seconds.BackgroundTransparency = 1
	seconds.AnchorPoint = Vector2.new(1, 0)
	seconds.Position = UDim2.new(1, -12, 0, 8)
	seconds.Size = UDim2.fromOffset(70, 26)
	seconds.Font = Enum.Font.GothamBlack
	seconds.TextSize = 24
	seconds.TextColor3 = Color3.new(1, 1, 1)
	seconds.TextXAlignment = Enum.TextXAlignment.Right
	seconds.Parent = card

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(60, 34)
	hint.Size = UDim2.fromOffset(270, 16)
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 13
	hint.TextColor3 = Color3.fromRGB(200, 196, 190)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = card

	-- Barra de sangre que se vacía
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 60, 1, -9)
	back.Size = UDim2.new(1, -72, 0, 4)
	back.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = card
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = RED
	fill.BorderSizePixel = 0
	fill.Parent = back

	local api = { shown = false }

	function api.set(secondsLeft, ratio, hintText)
		if not api.shown then
			api.shown = true
			card.Visible = true
			scale.Scale = 0.85
			TweenService:Create(card, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
			TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		seconds.Text = `{math.ceil(secondsLeft)}s`
		fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		hint.Text = hintText
		-- Con poco tiempo, la cuenta atrás late
		local urgent = secondsLeft <= 10
		seconds.TextColor3 = urgent and RED or Color3.new(1, 1, 1)
		stroke.Transparency = urgent and 0.4 - 0.3 * (0.5 + 0.5 * math.sin(os.clock() * 8)) or 0.4
	end

	function api.hide()
		if api.shown then
			api.shown = false
			TweenService:Create(card, TweenInfo.new(0.2), { GroupTransparency = 1 }):Play()
			task.delay(0.22, function()
				if not api.shown then
					card.Visible = false
				end
			end)
		end
	end

	return api
end

return DownedHud
