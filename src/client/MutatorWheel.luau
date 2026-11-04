-- Ruleta de mutaciones al principio de la partida: la rueda gira unos segundos y se detiene con el puntero de arriba y el de abajo sobre
-- las mutaciones de la ronda; a la derecha salen sus nombres, reglas y el bono de XP total. Las casillas son tan grandes como su
-- probabilidad (Mutators.slices): las comunes ocupan mucho, las épicas y la legendaria son tajadas finas con el borde de su color.
-- El servidor sortea con Mutators.roll y publica Workspace.Mutators (los ids) y Workspace.MutatorAngle (donde queda el puntero de arriba);
-- aquí solo se anima. Sale una vez por ronda, en el lobby, y se cierra sola, con CONTINUAR o con Esc.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Lang = require(ReplicatedStorage.Shared.Lang)
local Mutators = require(ReplicatedStorage.Shared.Mutators)
local Sfx = require(script.Parent.Sfx)
local UiFit = require(script.Parent.UiFit)

local player = Players.LocalPlayer

local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local OSWALD_LIGHT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Regular)
local BG = Color3.fromRGB(11, 12, 12)
local CARD = Color3.fromRGB(19, 22, 22)
local CREAM = Color3.fromRGB(240, 236, 226)
local GRAY = Color3.fromRGB(128, 128, 124)
local TEAL = Color3.fromRGB(64, 196, 182)
local RED = Color3.fromRGB(196, 26, 30)
local GOLD = Color3.fromRGB(246, 196, 70)

local WIDTH, HEIGHT = 1240, 760
local CX, CY, R = 332, 380, 300 -- centro y radio de la rueda dentro del panel
local STEP = 2 -- grados por cada tira del dibujo de la rueda
local SPIN_TIME = 6.4
local SHOW_AFTER = 9 -- segundos que se queda abierta después de detenerse

local MutatorWheel = {}

local function label(parent, text, size, position, textSize, color, align, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.FontFace = font or OSWALD
	l.TextSize = textSize
	l.TextColor3 = color
	l.Text = text
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function box(parent, size, position, color, transparency)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function darken(color, k)
	return Color3.new(color.R * k, color.G * k, color.B * k)
end

-- Las dos primeras letras de la mutación, para la casilla y la insignia (no hay íconos propios todavía)
local function monogram(id)
	local upper = Mutators[id].Upper
	local ok, text = pcall(function()
		return utf8.char(utf8.codepoint(upper, 1, 2))
	end)
	return ok and text or string.sub(upper, 1, 2)
end

local function spaced(text)
	text = Lang.tr(text) -- se traduce antes de separar las letras
	local chars = {}
	for _, codepoint in utf8.codes(text) do
		table.insert(chars, utf8.char(codepoint))
	end
	return table.concat(chars, " ")
end

function MutatorWheel.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MutatorWheel"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local dim = box(gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 0.4)
	dim.Active = true -- se come los clics mientras está abierta

	local panel = box(gui, UDim2.fromOffset(WIDTH, HEIGHT), UDim2.fromScale(0.5, 0.5), BG)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	UiFit.fitPanel(panel, WIDTH, HEIGHT)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(32, 34, 34)
	panelStroke.Thickness = 3
	panelStroke.Parent = panel

	local wheel = Instance.new("Frame")
	wheel.BackgroundTransparency = 1
	wheel.AnchorPoint = Vector2.new(0.5, 0.5)
	wheel.Position = UDim2.fromOffset(CX, CY)
	wheel.Size = UDim2.fromOffset(R * 2, R * 2)
	wheel.Parent = panel

	local rim = Instance.new("Frame")
	rim.BackgroundTransparency = 1
	rim.AnchorPoint = Vector2.new(0.5, 0.5)
	rim.Position = UDim2.fromOffset(CX, CY)
	rim.Size = UDim2.fromOffset(R * 2 + 18, R * 2 + 18)
	rim.ZIndex = 4
	rim.Parent = panel
	Instance.new("UICorner", rim).CornerRadius = UDim.new(0.5, 0)
	local rimStroke = Instance.new("UIStroke")
	rimStroke.Color = Color3.fromRGB(26, 26, 28)
	rimStroke.Thickness = 20
	rimStroke.Parent = rim

	-- Centro: cuántas mutaciones hay
	local hub = box(panel, UDim2.fromOffset(170, 170), UDim2.fromOffset(CX - 85, CY - 85), BG)
	hub.ZIndex = 6
	Instance.new("UICorner", hub).CornerRadius = UDim.new(0.5, 0)
	local hubStroke = Instance.new("UIStroke")
	hubStroke.Color = RED
	hubStroke.Thickness = 9
	hubStroke.Parent = hub
	local hubCount = label(hub, "×2", UDim2.new(1, 0, 0, 86), UDim2.fromOffset(0, 34), 76, CREAM, Enum.TextXAlignment.Center)
	hubCount.ZIndex = 7
	local hubText = label(hub, spaced("MUTATIONS"), UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 118), 14, GRAY, Enum.TextXAlignment.Center, OSWALD_LIGHT)
	hubText.ZIndex = 7

	-- Punteros (arriba y abajo)
	local pointers = {}
	for _, side in { -1, 1 } do
		local marker = box(panel, UDim2.fromOffset(34, 34), UDim2.fromOffset(CX, CY + side * (R + 8)), RED)
		marker.AnchorPoint = Vector2.new(0.5, 0.5)
		marker.Rotation = 45
		marker.ZIndex = 8
		pointers[side] = marker
	end

	-- Panel de la derecha
	local RX, RW = 700, 500
	label(panel, spaced("MATCH START"), UDim2.fromOffset(RW, 28), UDim2.fromOffset(RX, 56), 22, TEAL, nil, OSWALD_LIGHT)
	label(panel, "MUTATIONS", UDim2.fromOffset(RW, 100), UDim2.fromOffset(RX, 84), 96, CREAM)

	local cards = {}
	for index = 1, 2 do
		local card = box(panel, UDim2.fromOffset(RW, 184), UDim2.fromOffset(RX, 218 + (index - 1) * 204), CARD)
		card.Visible = false
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = card
		label(card, spaced(index == 1 and "TOP POINTER" or "BOTTOM POINTER"), UDim2.fromOffset(300, 22), UDim2.fromOffset(18, 14), 17, GRAY, nil, OSWALD_LIGHT)
		local badge = box(card, UDim2.fromOffset(64, 64), UDim2.fromOffset(18, 62), CREAM)
		Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 8)
		local badgeText = label(badge, "", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 32, BG, Enum.TextXAlignment.Center)
		local badgeImage = Instance.new("ImageLabel")
		badgeImage.BackgroundTransparency = 1
		badgeImage.Size = UDim2.fromScale(1, 1)
		badgeImage.ScaleType = Enum.ScaleType.Fit
		badgeImage.Visible = false
		badgeImage.Parent = badge
		local name = label(card, "", UDim2.fromOffset(300, 48), UDim2.fromOffset(100, 50), 42, CREAM)
		name.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 42
		limit.Parent = name
		local rarity = label(card, "", UDim2.fromOffset(300, 20), UDim2.fromOffset(100, 100), 16, GRAY)
		local desc = label(card, "", UDim2.fromOffset(250, 62), UDim2.fromOffset(100, 118), 19, Color3.fromRGB(190, 188, 182), nil, OSWALD_LIGHT)
		desc.TextWrapped = true
		desc.TextYAlignment = Enum.TextYAlignment.Top
		local bonus = label(card, "", UDim2.fromOffset(110, 60), UDim2.fromOffset(RW - 128, 52), 46, CREAM, Enum.TextXAlignment.Right)
		local fresh = label(card, "", UDim2.fromOffset(130, 44), UDim2.fromOffset(RW - 148, 122), 17, GOLD, Enum.TextXAlignment.Right)
		fresh.TextWrapped = true
		cards[index] = { frame = card, stroke = stroke, badge = badge, badgeText = badgeText, badgeImage = badgeImage, name = name, rarity = rarity, desc = desc, bonus = bonus, fresh = fresh }
	end

	box(panel, UDim2.fromOffset(RW, 2), UDim2.fromOffset(RX, 636), RED)
	label(panel, spaced("TOTAL XP BONUS"), UDim2.fromOffset(240, 60), UDim2.fromOffset(RX, 662), 20, GRAY, nil, OSWALD_LIGHT)
	local totalLabel = label(panel, "", UDim2.fromOffset(300, 70), UDim2.fromOffset(RX + RW - 300, 650), 62, CREAM, Enum.TextXAlignment.Right)

	local continue = Instance.new("TextButton")
	continue.AutoButtonColor = false
	continue.Size = UDim2.fromOffset(200, 46)
	continue.Position = UDim2.fromOffset(CX - 100, HEIGHT - 58)
	continue.BackgroundColor3 = RED
	continue.BorderSizePixel = 0
	continue.FontFace = OSWALD
	continue.TextSize = 26
	continue.TextColor3 = CREAM
	continue.Text = "CONTINUE"
	continue.Visible = false
	continue.ZIndex = 9
	continue.Parent = panel

	-- Estado ------------------------------------------------------------------------------------------------------------------------------
	local token = 0
	local connection = nil
	local lastKey = nil
	local isOpen = false

	local function closeWheel()
		token += 1
		isOpen = false
		gui.Enabled = false
		player:SetAttribute("UiOpen", nil)
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end

	local function seenSet()
		local set = {}
		for id in string.gmatch(player:GetAttribute("SeenMutators") or "", "[^,]+") do
			set[id] = true
		end
		return set
	end

	local function buildWheel(difficultyId)
		wheel:ClearAllChildren()
		local slices = Mutators.slices(difficultyId)
		local half = math.max(8, math.ceil(math.pi * R / (180 / STEP) * 1.5))
		for index = 0, 360 / STEP - 1 do
			local angle = index * STEP + STEP / 2
			local slice = Mutators.sliceAt(slices, angle)
			local def = Mutators[slice.id]
			local strip = Instance.new("Frame")
			local rad = math.rad(angle)
			strip.AnchorPoint = Vector2.new(0.5, 0.5) -- gira sobre su centro: va a media distancia entre el centro y el borde
			strip.Position = UDim2.fromOffset(R + math.sin(rad) * R / 2, R - math.cos(rad) * R / 2)
			strip.Size = UDim2.fromOffset(half, R)
			strip.Rotation = angle
			strip.BackgroundColor3 = darken(def.Color, 0.28)
			strip.BorderSizePixel = 0
			strip.Parent = wheel
			local edge = box(strip, UDim2.new(1, 0, 0, 14), UDim2.fromOffset(0, 0), Mutators.Rarities[def.Rarity].Color)
			edge.BackgroundTransparency = 0.05
		end
		for _, slice in slices do
			local line = Instance.new("Frame")
			local lineRad = math.rad(slice.from)
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.Position = UDim2.fromOffset(R + math.sin(lineRad) * R / 2, R - math.cos(lineRad) * R / 2)
			line.Size = UDim2.fromOffset(4, R)
			line.Rotation = slice.from
			line.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
			line.BorderSizePixel = 0
			line.ZIndex = 2
			line.Parent = wheel
			local mid = (slice.from + slice.to) / 2
			local rad = math.rad(mid)
			local size = math.clamp(slice.fraction * 360 * 1.5, 16, 44)
			local text = Instance.new("TextLabel")
			text.AnchorPoint = Vector2.new(0.5, 0.5)
			text.BackgroundTransparency = 1
			text.Position = UDim2.fromOffset(R + math.sin(rad) * R * 0.66, R - math.cos(rad) * R * 0.66)
			text.Size = UDim2.fromOffset(60, 50)
			text.Rotation = mid
			text.FontFace = OSWALD
			text.TextSize = size
			text.TextColor3 = Mutators[slice.id].Color
			text.Text = monogram(slice.id)
			text.ZIndex = 3
			text.Parent = wheel
			local sliceIcon = Mutators[slice.id].Icon
			if sliceIcon then
				text.Visible = false
				local image = Instance.new("ImageLabel")
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundTransparency = 1
				image.Position = text.Position
				image.Size = UDim2.fromOffset(size + 14, size + 14)
				image.Rotation = mid
				image.Image = sliceIcon
				image.ScaleType = Enum.ScaleType.Fit
				image.ZIndex = 3
				image.Parent = wheel
			end
		end
		return slices
	end

	local function fillCard(card, id, seen)
		local def = Mutators[id]
		local rarity = Mutators.Rarities[def.Rarity]
		card.stroke.Color = rarity.Color
		card.badge.BackgroundColor3 = def.Color
		card.badge.BackgroundTransparency = def.Icon and 1 or 0
		card.badgeText.Text = def.Icon and "" or monogram(id)
		card.badgeImage.Visible = def.Icon ~= nil
		card.badgeImage.Image = def.Icon or ""
		card.name.Text = def.Upper
		card.rarity.Text = spaced(rarity.Text)
		card.rarity.TextColor3 = rarity.Color
		card.desc.Text = def.Description
		local bonus = math.floor(def.Bonus * 100 + 0.5)
		card.bonus.Text = bonus > 0 and `+{bonus}%` or "0%"
		card.bonus.TextColor3 = bonus > 0 and rarity.Color or GRAY
		card.fresh.Text = seen[id] and "" or `NEW! +{Mutators.DiscoveryXp} XP`
	end

	local function show(ids, angle)
		closeWheel()
		token += 1
		local mine = token
		isOpen = true
		gui.Enabled = true
		player:SetAttribute("UiOpen", true)
		local difficultyId = workspace:GetAttribute("Difficulty")
		local slices = buildWheel(difficultyId)
		local seen = seenSet()
		local count = #ids
		hubCount.Text = `×{count}`
		hubText.Text = spaced(count == 1 and "MUTATION" or "MUTATIONS")
		pointers[1].Visible = count >= 2
		for index, card in cards do
			card.frame.Visible = false
			if ids[index] then
				fillCard(card, ids[index], seen)
			end
		end
		totalLabel.Text = ""
		continue.Visible = false
		wheel.Rotation = 0

		local finalRotation = 360 * 5 + ((-angle) % 360)
		local start = os.clock()
		local lastSlice = nil
		local landed = false
		connection = RunService.RenderStepped:Connect(function()
			if mine ~= token then
				return
			end
			local t = math.clamp((os.clock() - start) / SPIN_TIME, 0, 1)
			local eased = 1 - (1 - t) ^ 4
			local rotation = finalRotation * eased
			wheel.Rotation = rotation
			local under = Mutators.sliceAt(slices, -rotation)
			if under ~= lastSlice then
				lastSlice = under
				Sfx.play("Select", 0.06)
			end
			if t >= 1 and not landed then
				landed = true
				-- Se detuvo: salen las tarjetas, una tras otra, y el bono total
				local total = 0
				for index, id in ids do
					total += Mutators[id].Bonus
					task.delay((index - 1) * 0.45, function()
						if mine ~= token then
							return
						end
						cards[index].frame.Visible = true
						local rarity = Mutators[id].Rarity
						Sfx.play((rarity == "Epic" or rarity == "Legendary") and "Revived" or "Confirm", 0.1)
					end)
				end
				local percent = math.floor(total * 100 + 0.5)
				task.delay(#ids * 0.45 + 0.1, function()
					if mine == token then
						totalLabel.Text = `+{percent}% XP`
						continue.Visible = true
					end
				end)
				task.delay(SHOW_AFTER, function()
					if mine == token then
						closeWheel()
					end
				end)
			end
		end)
	end

	continue.Activated:Connect(closeWheel)
	UserInputService.InputBegan:Connect(function(input)
		if isOpen and input.KeyCode == Enum.KeyCode.Escape then
			closeWheel()
		end
	end)

	local function update()
		local stage = workspace:GetAttribute("Stage")
		if stage == "Vote" then
			lastKey = nil
		end
		if stage ~= "Lobby" then
			if isOpen and stage ~= nil then
				closeWheel()
			end
			return
		end
		local ids = Mutators.parse(workspace:GetAttribute("Mutators"))
		local angle = workspace:GetAttribute("MutatorAngle")
		if #ids == 0 or not angle then
			return
		end
		local key = `{Mutators.serialize(ids)}@{math.floor(angle * 100)}`
		if key ~= lastKey then
			lastKey = key
			show(ids, angle)
		end
	end
	workspace:GetAttributeChangedSignal("Stage"):Connect(update)
	workspace:GetAttributeChangedSignal("Mutators"):Connect(update)
	workspace:GetAttributeChangedSignal("MutatorAngle"):Connect(update)
	update()
end

return MutatorWheel
