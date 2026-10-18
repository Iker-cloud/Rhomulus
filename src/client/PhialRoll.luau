-- Panel PHIAL ROLL: la ruleta de Phials (las jeringas de la farmacia) en la interfaz de quien compra. Se abre al pulsar E en una vitrina
-- libre (el servidor manda Remotes.PhialUi "open"); el botón ROLL pide girar y cobrar ("roll"), las cartas giran y se detienen en el efecto que
-- sorteó el servidor ("spin"), y al salir ("ready") el botón pasa a INYECTAR ("take"). El resto de jugadores ve el nombre en la vitrina.
-- Mientras está abierto el jugador tiene el atributo "UiOpen" (el ratón queda libre, como en la tienda). Se cierra con SALIR, Esc o al alejarse.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Parent.Sfx)
local CanIcon = require(script.Parent.CanIcon)
local PhialIcon = require(script.Parent.PhialIcon)
local UiFit = require(script.Parent.UiFit)

local player = Players.LocalPlayer
local P = Config.Pharmacy

local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local OSWALD_LIGHT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Regular)
local BG = Color3.fromRGB(13, 13, 15)
local CARD = Color3.fromRGB(22, 22, 24)
local EDGE = Color3.fromRGB(44, 44, 48)
local RED = Color3.fromRGB(196, 26, 30)
local CREAM = Color3.fromRGB(236, 230, 218)
local GRAY = Color3.fromRGB(132, 130, 126)
local GOLD = Color3.fromRGB(246, 196, 70)

local WIDTH, HEIGHT = 1000, 690
local CARD_W, CARD_H, PITCH = 206, 290, 220
local STRIP_H = 314
local CLOSE_DISTANCE = 24

local PhialRoll = {}

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

local function circle(parent, diameter, position, color)
	local f = box(parent, UDim2.fromOffset(diameter, diameter), position, color)
	Instance.new("UICorner", f).CornerRadius = UDim.new(0.5, 0)
	return f
end

local function darken(color, k)
	return Color3.new(color.R * k, color.G * k, color.B * k)
end

-- Efectos en orden de la lista con su probabilidad en %
local function odds()
	local total = 0
	for _, id in P.Order do
		total += P.Effects[id].Weight or 1
	end
	local list = {}
	for _, id in P.Order do
		list[id] = math.floor((P.Effects[id].Weight or 1) / total * 100 + 0.5)
	end
	return list, total
end

local function pickWeighted(total)
	local roll = math.random() * total
	for _, id in P.Order do
		roll -= P.Effects[id].Weight or 1
		if roll <= 0 then
			return id
		end
	end
	return P.Order[1]
end

function PhialRoll.start()
	local percent, totalWeight = odds()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PhialRoll"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 45
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	panel.BackgroundColor3 = BG
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	UiFit.fitPanel(panel, WIDTH, HEIGHT)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(8, 8, 9)
	panelStroke.Thickness = 3
	panelStroke.Parent = panel

	-- Cabecera: la cruz roja, el título y las latas del equipo
	local cross = box(panel, UDim2.fromOffset(52, 52), UDim2.fromOffset(20, 14), RED)
	box(cross, UDim2.fromOffset(30, 10), UDim2.fromOffset(11, 21), CREAM)
	box(cross, UDim2.fromOffset(10, 30), UDim2.fromOffset(21, 11), CREAM)
	label(panel, P.Ui.Title, UDim2.fromOffset(330, 52), UDim2.fromOffset(88, 14), 46, CREAM)
	label(panel, P.Ui.Subtitle, UDim2.fromOffset(520, 26), UDim2.fromOffset(380, 28), 20, Color3.fromRGB(150, 148, 144), nil, OSWALD)
	local coins = box(panel, UDim2.fromOffset(168, 52), UDim2.fromOffset(812, 14), CARD)
	local coinsStroke = Instance.new("UIStroke")
	coinsStroke.Color = EDGE
	coinsStroke.Thickness = 2
	coinsStroke.Parent = coins
	local coinHolder = box(coins, UDim2.fromOffset(34, 40), UDim2.fromOffset(8, 6), CARD, 1)
	CanIcon.make(coinHolder, 34)
	local coinsLabel = label(coins, "0", UDim2.fromOffset(110, 52), UDim2.fromOffset(46, 0), 32, CREAM)
	box(panel, UDim2.new(1, 0, 0, 4), UDim2.fromOffset(0, 80), RED)

	-- La ruleta: una tira de cartas que pasa bajo la marca del centro
	local view = box(panel, UDim2.fromOffset(WIDTH, STRIP_H), UDim2.fromOffset(0, 84), Color3.fromRGB(17, 17, 19))
	view.ClipsDescendants = true
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.fromOffset(100, STRIP_H)
	strip.Parent = view
	for _, side in { 0, 1 } do
		local fade = box(view, UDim2.fromOffset(140, STRIP_H), UDim2.fromOffset(side == 0 and 0 or WIDTH - 140, 0), Color3.fromRGB(17, 17, 19))
		fade.ZIndex = 3
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new(side == 0 and { NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) } or { NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.05) })
		gradient.Parent = fade
	end
	local line = box(view, UDim2.fromOffset(2, STRIP_H), UDim2.fromOffset(WIDTH / 2 - 1, 0), RED, 0.25)
	line.ZIndex = 5
	for _, y in { 0, STRIP_H } do
		local marker = box(view, UDim2.fromOffset(20, 20), UDim2.fromOffset(WIDTH / 2, y), RED)
		marker.AnchorPoint = Vector2.new(0.5, 0.5)
		marker.Rotation = 45
		marker.ZIndex = 6
	end
	local frame = box(view, UDim2.fromOffset(CARD_W + 20, CARD_H + 20), UDim2.fromOffset(WIDTH / 2, STRIP_H / 2), Color3.new(0, 0, 0), 1)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.ZIndex = 4
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Thickness = 3
	frameStroke.Color = CREAM
	frameStroke.Parent = frame

	-- Franja de aviso bajo la ruleta
	local banner = box(panel, UDim2.fromOffset(WIDTH, 52), UDim2.fromOffset(0, 402), Color3.fromRGB(15, 15, 17))
	local bannerText = label(banner, "", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 25, CREAM, Enum.TextXAlignment.Center)
	bannerText.RichText = true
	local epicPercent = 0
	for _, id in P.Order do
		if P.Effects[id].Rarity == "Epic" then
			epicPercent += percent[id]
		end
	end
	local DEFAULT_BANNER = `<font color="#F6C446">{epicPercent} %</font> DE PROBABILIDAD DE SACAR UNA PHIAL <font color="#BE6CFF">ÉPICA</font> <font color="#847E78" size="17">· SOLO UNA ACTIVA A LA VEZ</font>`
	bannerText.Text = DEFAULT_BANNER

	-- Lista de probabilidades (3 × 3)
	for index, id in P.Order do
		local def = P.Effects[id]
		local col, row = (index - 1) % 3, (index - 1) // 3
		local chip = box(panel, UDim2.fromOffset(212, 62), UDim2.fromOffset(12 + col * 220, 466 + row * 70), Color3.fromRGB(18, 18, 20))
		local chipStroke = Instance.new("UIStroke")
		chipStroke.Color = EDGE
		chipStroke.Thickness = 2
		chipStroke.Parent = chip
		box(chip, UDim2.fromOffset(18, 18), UDim2.fromOffset(12, 22), def.Color)
		label(chip, def.Upper, UDim2.fromOffset(130, 28), UDim2.fromOffset(40, 4), 22, CREAM)
		label(chip, def.Desc, UDim2.fromOffset(150, 20), UDim2.fromOffset(40, 33), 13, GRAY, nil, OSWALD_LIGHT)
		label(chip, `{percent[id]}%`, UDim2.fromOffset(60, 62), UDim2.fromOffset(146, 0), 24, P.Rarities[def.Rarity].Color, Enum.TextXAlignment.Right)
	end

	-- Botones
	local roll = Instance.new("TextButton")
	roll.AutoButtonColor = false
	roll.Size = UDim2.fromOffset(300, 126)
	roll.Position = UDim2.fromOffset(688, 466)
	roll.BackgroundColor3 = RED
	roll.BorderSizePixel = 0
	roll.Text = ""
	roll.Parent = panel
	local rollStroke = Instance.new("UIStroke")
	rollStroke.Color = Color3.fromRGB(8, 8, 9)
	rollStroke.Thickness = 3
	rollStroke.Parent = roll
	local rollText = label(roll, "ROLL", UDim2.fromOffset(150, 126), UDim2.fromOffset(26, 0), 58, CREAM)
	local priceBadge = box(roll, UDim2.fromOffset(112, 40), UDim2.fromOffset(176, 43), Color3.fromRGB(120, 12, 16))
	local priceCoin = box(priceBadge, UDim2.fromOffset(24, 32), UDim2.fromOffset(6, 4), CARD, 1)
	CanIcon.make(priceCoin, 28)
	local priceText = label(priceBadge, "250", UDim2.fromOffset(70, 40), UDim2.fromOffset(36, 0), 24, CREAM)

	local exit = Instance.new("TextButton")
	exit.AutoButtonColor = false
	exit.Size = UDim2.fromOffset(300, 64)
	exit.Position = UDim2.fromOffset(688, 604)
	exit.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
	exit.BorderSizePixel = 0
	exit.FontFace = OSWALD
	exit.TextSize = 30
	exit.TextColor3 = CREAM
	exit.Text = "SALIR"
	exit.Parent = panel
	local exitStroke = Instance.new("UIStroke")
	exitStroke.Color = EDGE
	exitStroke.Thickness = 2
	exitStroke.Parent = exit

	-- Cartas -----------------------------------------------------------------------------------------------------------------------------
	local cards = {} -- { id, frame }

	local function makeCard(id, index)
		local def = P.Effects[id]
		local rarity = P.Rarities[def.Rarity]
		local card = box(strip, UDim2.fromOffset(CARD_W, CARD_H), UDim2.fromOffset(10 + (index - 1) * PITCH, (STRIP_H - CARD_H) / 2), CARD)
		local stroke = Instance.new("UIStroke")
		stroke.Color = EDGE
		stroke.Thickness = 2
		stroke.Parent = card
		label(card, def.Category, UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 10), 15, GRAY, Enum.TextXAlignment.Center)
		label(card, `{percent[id]}%`, UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 27), 28, CREAM, Enum.TextXAlignment.Center)
		local outer = circle(card, 146, UDim2.fromOffset((CARD_W - 146) / 2, 66), darken(def.Color, 0.30))
		local inner = circle(outer, 112, UDim2.fromOffset(17, 17), darken(def.Color, 0.5))
		inner.BackgroundTransparency = 0.25
		PhialIcon.make(outer, def.Color, 118)
		local name = label(card, def.Upper, UDim2.new(1, -12, 0, 34), UDim2.fromOffset(6, 216), 30, CREAM, Enum.TextXAlignment.Center)
		name.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 30
		limit.Parent = name
		label(card, rarity.Text, UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 255), 17, rarity.Color, Enum.TextXAlignment.Center)
		return card
	end

	local function clearStrip()
		for _, c in cards do
			c.frame:Destroy()
		end
		table.clear(cards)
	end

	-- Centro de la carta `index` dentro de la tira
	local function cardCenter(index)
		return 10 + (index - 1) * PITCH + CARD_W / 2
	end
	local function stripXFor(index)
		return WIDTH / 2 - cardCenter(index)
	end
	local function centerIndex(stripX)
		return math.clamp(math.floor((WIDTH / 2 - stripX - 10) / PITCH) + 1, 1, #cards)
	end

	local function buildStrip(count, targetIndex, targetId)
		clearStrip()
		strip.Size = UDim2.fromOffset(20 + count * PITCH, STRIP_H)
		local last
		for i = 1, count do
			local id
			if i == targetIndex and targetId then
				id = targetId
			else
				repeat
					id = pickWeighted(totalWeight)
				until id ~= last
			end
			last = id
			table.insert(cards, { id = id, frame = makeCard(id, i) })
		end
	end

	local function paintFrame(index)
		local c = cards[index]
		if c then
			frameStroke.Color = P.Rarities[P.Effects[c.id].Rarity].Color:Lerp(P.Effects[c.id].Color, 0.6)
		end
	end

	-- Estado ------------------------------------------------------------------------------------------------------------------------------
	local state = "closed" -- "idle", "spinning", "ready"
	local machineKey, machinePosition, price = nil, nil, 0
	local spinStart, spinDuration, spinFrom, spinTo, spinTarget = 0, 0, 0, 0, 0
	local readyEnd = 0
	local lastTick = 0
	local connection = nil
	local notice = nil -- aviso temporal en la franja

	local function say(text, seconds)
		notice = { text = text, untilTime = os.clock() + (seconds or 2.5) }
		bannerText.Text = `<font color="#E0463C">{text}</font>`
	end

	local function setIdleStrip()
		buildStrip(15, 8)
		strip.Position = UDim2.fromOffset(stripXFor(8), 0)
		paintFrame(8)
	end

	local function setOpen(open)
		panel.Visible = open
		player:SetAttribute("UiOpen", open or nil)
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if not open then
			state = "closed"
			return
		end
		connection = RunService.RenderStepped:Connect(function()
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not root or (root.Position - machinePosition).Magnitude > CLOSE_DISTANCE or player:GetAttribute("State") ~= "Normal" then
				setOpen(false)
				return
			end
			local points = workspace:GetAttribute("Points") or 0
			coinsLabel.Text = tostring(points)
			priceText.Text = tostring(price)
			if notice and os.clock() > notice.untilTime then
				notice = nil
				bannerText.Text = DEFAULT_BANNER
			end

			if state == "landed" then
				rollText.Text = "..."
				roll.BackgroundColor3 = Color3.fromRGB(70, 20, 22)
			elseif state == "spinning" then
				local t = math.clamp((os.clock() - spinStart) / spinDuration, 0, 1)
				local eased = 1 - (1 - t) ^ 4
				local x = spinFrom + (spinTo - spinFrom) * eased
				strip.Position = UDim2.fromOffset(x, 0)
				local index = centerIndex(x)
				if index ~= lastTick then
					lastTick = index
					paintFrame(index)
					Sfx.play("Select", 0.05)
				end
				rollText.Text = "..."
				roll.BackgroundColor3 = Color3.fromRGB(70, 20, 22)
			elseif state == "ready" then
				local left = math.max(0, readyEnd - os.clock())
				rollText.Text = "GUARDAR"
				rollText.TextSize = 38
				priceText.Text = `{math.ceil(left)} s`
				priceCoin.Visible = false
				priceText.Position = UDim2.fromOffset(10, 0)
				roll.BackgroundColor3 = Color3.fromRGB(34, 160, 88)
			else
				priceCoin.Visible = true
				priceText.Position = UDim2.fromOffset(36, 0)
				rollText.Text = "ROLL"
				rollText.TextSize = 58
				local affordable = points >= price
				roll.BackgroundColor3 = affordable and RED or Color3.fromRGB(86, 40, 42)
			end
		end)
	end

	local function open(key, position, cost)
		if panel.Visible then
			setOpen(false)
			return
		end
		machineKey, machinePosition, price = key, position, cost
		state = "idle"
		notice = nil
		bannerText.Text = DEFAULT_BANNER
		setIdleStrip()
		setOpen(true)
		Sfx.play("Confirm", 0.1)
	end

	roll.Activated:Connect(function()
		if state == "idle" then
			if (workspace:GetAttribute("Points") or 0) < price then
				say("FALTAN LATAS", 2)
				Sfx.play("SkillFail", 0.3)
				return
			end
			Remotes.PhialUi:FireServer("roll", machineKey)
		elseif state == "ready" then
			Remotes.PhialUi:FireServer("take", machineKey)
		end
	end)
	exit.Activated:Connect(function()
		setOpen(false)
	end)
	UserInputService.InputBegan:Connect(function(input)
		if panel.Visible and input.KeyCode == Enum.KeyCode.Escape then
			setOpen(false)
		end
	end)

	Remotes.PhialUi.OnClientEvent:Connect(function(action, key, a, b, c)
		if action == "open" then
			open(key, a, b)
		elseif action == "denied" then
			if panel.Visible then
				say(key or "NO SE PUEDE", 2) -- aquí `key` trae el texto
				Sfx.play("SkillFail", 0.3)
			end
		elseif not panel.Visible or key ~= machineKey then
			return
		elseif action == "spin" then
			-- a = efecto que salió, b = segundos girando
			local target = 36
			buildStrip(44, target, a)
			spinFrom = stripXFor(6)
			spinTo = stripXFor(target)
			spinDuration, spinStart, spinTarget = b, os.clock(), target
			lastTick = 0
			strip.Position = UDim2.fromOffset(spinFrom, 0)
			state = "spinning"
			task.delay(b, function()
				if state == "spinning" then
					state = "landed"
					strip.Position = UDim2.fromOffset(spinTo, 0)
					paintFrame(spinTarget)
					TweenService:Create(frameStroke, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Thickness = 7 }):Play()
					task.delay(0.2, function()
						TweenService:Create(frameStroke, TweenInfo.new(0.3), { Thickness = 3 }):Play()
					end)
					Sfx.play("Confirm", 0.1)
				end
			end)
		elseif action == "ready" then
			state = "ready"
			readyEnd = os.clock() + b
			local def = P.Effects[a]
			bannerText.Text = `<font color="#{def.Color:ToHex()}">{def.Upper}</font>  {def.Desc}  <font color="#847E78" size="17">· LUEGO: {def.CrashDesc}</font>`
		elseif action == "lost" then
			state = "idle"
			say("SE PERDIÓ LA PHIAL", 3)
			Sfx.play("SkillFail", 0.3)
		elseif action == "taken" then
			setOpen(false)
		end
	end)
end

return PhialRoll
