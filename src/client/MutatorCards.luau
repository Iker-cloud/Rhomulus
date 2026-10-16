-- Tarjetas de los mutadores de la ronda (shared/Mutators): al llegar al lobby aparece una por mutador, con su color, su nombre, lo que
-- cambia y el XP extra, y se retiran solas. Después queda la etiqueta pequeña de DifficultyVote bajo la dificultad.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Mutators = require(ReplicatedStorage.Shared.Mutators)
local Sfx = require(script.Parent.Sfx)
local UiFit = require(script.Parent.UiFit)

local player = Players.LocalPlayer

local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local OSWALD_LIGHT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Regular)
local DARK = Color3.fromRGB(14, 13, 13)
local SHOW_TIME = 7

local MutatorCards = {}

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	for key, value in props do
		l[key] = value
	end
	l.Parent = parent
	return l
end

-- Monograma del mutador: las dos primeras letras en un cuadro de su color
local function badge(parent, id)
	local m = Mutators[id]
	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(44, 44)
	box.Position = UDim2.fromOffset(16, 14)
	box.BackgroundColor3 = m.Color
	box.BorderSizePixel = 0
	box.Parent = parent
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
	local letters = text(box, {
		Size = UDim2.fromScale(1, 1),
		Text = string.sub(m.Upper, 1, 2),
		FontFace = OSWALD,
		TextSize = 24,
		TextColor3 = DARK,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	letters.TextWrapped = false
end

function MutatorCards.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MutatorCards"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.Parent = player:WaitForChild("PlayerGui")

	local row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.fromScale(0.5, 0.2)
	row.Size = UDim2.fromOffset(0, 0)
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.BackgroundTransparency = 1
	row.Parent = gui
	UiFit.scale(row)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 14)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = row

	local shownFor = nil -- los mutadores para los que ya salieron las tarjetas
	local token = 0

	local function show(ids)
		token += 1
		local mine = token
		row:ClearAllChildren()
		layout.Parent = row
		Sfx.play("Select", 0.2)
		for index, id in ids do
			local m = Mutators[id]
			local card = Instance.new("CanvasGroup")
			card.LayoutOrder = index
			card.Size = UDim2.fromOffset(280, 112)
			card.BackgroundColor3 = DARK
			card.BackgroundTransparency = 0.1
			card.BorderSizePixel = 0
			card.GroupTransparency = 1
			card.Parent = row
			local stroke = Instance.new("UIStroke")
			stroke.Color = m.Color
			stroke.Thickness = 2
			stroke.Parent = card
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
			badge(card, id)
			text(card, { Position = UDim2.fromOffset(72, 8), Size = UDim2.new(1, -84, 0, 28), Text = m.Upper, FontFace = OSWALD, TextSize = 24, TextColor3 = m.Color })
			text(card, { Position = UDim2.fromOffset(72, 38), Size = UDim2.new(1, -84, 0, 52), Text = m.Description, FontFace = OSWALD_LIGHT, TextSize = 15, TextColor3 = Color3.fromRGB(220, 215, 208) })
			local bonus = math.floor(m.Bonus * 100 + 0.5)
			text(card, { Position = UDim2.new(0, 72, 1, -26), Size = UDim2.new(1, -84, 0, 20), Text = bonus > 0 and `+{bonus} % XP` or "SIN BONO", FontFace = OSWALD, TextSize = 16, TextColor3 = Color3.fromRGB(245, 200, 70) })
			task.delay((index - 1) * 0.35, function()
				if mine == token and card.Parent then
					TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
				end
			end)
		end
		task.delay(SHOW_TIME, function()
			if mine ~= token then
				return
			end
			for _, card in row:GetChildren() do
				if card:IsA("CanvasGroup") then
					TweenService:Create(card, TweenInfo.new(0.6), { GroupTransparency = 1 }):Play()
				end
			end
			task.wait(0.7)
			if mine == token then
				row:ClearAllChildren()
				layout.Parent = row
			end
		end)
	end

	local function update()
		local stage = workspace:GetAttribute("Stage")
		local ids = Mutators.parse(workspace:GetAttribute("Mutators"))
		if stage ~= "Lobby" then
			if stage ~= nil and stage ~= "Vote" then
				token += 1
				row:ClearAllChildren()
				layout.Parent = row
			end
			if stage == "Vote" then
				shownFor = nil
			end
			return
		end
		local key = Mutators.serialize(ids)
		if #ids > 0 and shownFor ~= key then
			shownFor = key
			show(ids)
		end
	end
	workspace:GetAttributeChangedSignal("Stage"):Connect(update)
	workspace:GetAttributeChangedSignal("Mutators"):Connect(update)
	update()
end

return MutatorCards
