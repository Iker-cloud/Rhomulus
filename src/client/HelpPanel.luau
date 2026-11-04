-- Ayuda dentro de la partida:
--   * Panel "HOW TO PLAY" con cuatro pestañas (objetivo, controles, consejos, dificultades); se abre y se cierra con K (también con la X o
--     un clic fuera; Esc lo reserva Roblox para su menú; flechas izquierda/derecha cambian de pestaña). El juego sigue mientras se lee. Los textos son shared/HelpContent y
--     shared/Difficulties, los mismos que usa el menú.
--   * Tarjeta de bienvenida la primera vez que el jugador llega al lobby (server/HelpState guarda que ya la vio).
--   * Una pista pequeña "K · AYUDA" abajo al centro.
-- Con el panel abierto el jugador tiene el atributo "UiOpen" (CameraController libera el ratón, igual que la tienda).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Difficulties = require(ReplicatedStorage.Shared.Difficulties)
local HelpContentBase = require(ReplicatedStorage.Shared.HelpContent)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Controls = require(script.Parent.Controls)

-- Textos del dispositivo (teclas en PC, botones en celular); se eligen al abrir el juego
local HelpContent = HelpContentBase.get(Controls.isTouch())

local player = Players.LocalPlayer

-- Estilo "expediente": papel crema con cinta, máquina de escribir, sello rojo y teclas resaltadas con marcador amarillo
local TYPEWRITER = Font.fromEnum(Enum.Font.SpecialElite)
local HEAD = (function()
	local ok, font = pcall(function()
		return Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.ExtraBold)
	end)
	return ok and font or Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
end)()
local BOLD = HEAD
local REGULAR = TYPEWRITER
local HILITE = Color3.fromRGB(246, 196, 70) -- marcador amarillo (teclas)
local GOLD = Color3.fromRGB(176, 48, 44) -- acento (títulos, números, sello): rojo tinta
local DARK = Color3.fromRGB(36, 30, 24) -- tinta
local PANEL = Color3.fromRGB(228, 214, 178) -- papel
local PALE = Color3.fromRGB(104, 92, 76) -- tinta suave
local WHITE = Color3.fromRGB(36, 30, 24) -- texto principal (tinta)
local LIGHT = Color3.fromRGB(240, 232, 214) -- texto claro sobre fondos oscuros

local PANEL_W, PANEL_H = 1180, 700
local WELCOME_SECONDS = 30 -- la bienvenida se cierra sola pasado este tiempo
local COMBAT_DISTANCE = 30 -- con un zombie vivo más cerca que esto la ayuda no se abre y, si estaba abierta, se cierra sola

local HelpPanel = {}

-- Etiqueta con la esquina superior izquierda en (x, y); con `wrap` el texto salta de línea dentro de w × h
local function label(parent, str, x, y, w, h, size, color, font, props)
	props = props or {}
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h)
	l.FontFace = font or REGULAR
	l.TextSize = size
	l.TextColor3 = color or WHITE
	l.Text = str
	l.TextWrapped = props.wrap == true
	l.RichText = props.rich == true
	l.TextXAlignment = props.align or Enum.TextXAlignment.Left
	l.TextYAlignment = props.valign or Enum.TextYAlignment.Top
	l.LineHeight = props.lineHeight or 1.08
	l.Parent = parent
	return l
end

local function box(parent, x, y, w, h, color, transparency)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.Parent = parent
	return f
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- Casilla de tecla (fondo dorado, letras oscuras); devuelve su ancho
local function keycap(parent, x, y, text)
	local w = math.max(52, 14 * (utf8.len(text) or #text) + 22)
	local f = box(parent, x, y, w, 40, HILITE)
	label(f, text, 0, 0, w, 40, 22, DARK, TYPEWRITER, { align = Enum.TextXAlignment.Center, valign = Enum.TextYAlignment.Center })
	return w
end

-- 1.5 -> "1,5"; 1 -> "1"; 1.25 -> "1,25"
local function onPaper(color)
	return color:Lerp(DARK, 0.42)
end

local function ratio(n)
	local s = string.format("%.2f", n)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	s = string.gsub(s, "%.", ",")
	return s
end

-- Contenido de cada pestaña (se arma sobre `c`, un marco de PANEL_W × (PANEL_H - 100) bajo la cabecera) ------------------

local buildTab = {}

buildTab[1] = function(c)
	label(c, HelpContent.Headline, 40, 24, 480, 140, 56, WHITE, BOLD, { lineHeight = 1.0 })
	box(c, 40, 172, 90, 5, GOLD)
	label(c, HelpContent.Objective[1], 40, 196, 490, 140, 19, PALE, REGULAR, { wrap = true })
	label(c, HelpContent.Objective[2], 40, 340, 490, 100, 21, WHITE, BOLD, { wrap = true })
	for i, step in HelpContent.Steps do
		local y = 20 + 98 * (i - 1)
		label(c, string.format("%02d", i), 580, y, 50, 40, 32, GOLD, BOLD)
		label(c, step[1], 640, y, 500, 34, 28, WHITE, BOLD)
		label(c, step[2], 640, y + 36, 500, 44, 16, PALE, REGULAR, { wrap = true })
		if i < #HelpContent.Steps then
			box(c, 580, y + 84, 560, 1, PALE, 0.75)
		end
	end
end

buildTab[2] = function(c)
	for col, group in HelpContent.Controls do
		local x = 40 + 380 * (col - 1)
		label(c, group[1], x, 16, 340, 30, 24, GOLD, BOLD)
		box(c, x, 50, 340, 2, GOLD)
		for i, row in group[2] do
			local y = 68 + 54 * (i - 1)
			keycap(c, x, y, row[1])
			label(c, row[2], x + 170, y, 170, 40, 21, WHITE, BOLD, { valign = Enum.TextYAlignment.Center })
		end
	end
	label(c, HelpContent.ControlsNote, 40, 410, 760, 30, 20, PALE, REGULAR)
	label(c, HelpContent.ControlsSide, 740, 410, 400, 30, 18, GOLD, BOLD, { align = Enum.TextXAlignment.Right })
end

buildTab[3] = function(c)
	for i, tip in HelpContent.Tips do
		local col = (i - 1) // 4
		local row = (i - 1) % 4
		local x = 40 + 570 * col
		local y = 14 + 106 * row
		label(c, string.format("%02d", i), x, y, 50, 36, 28, GOLD, BOLD)
		label(c, tip[1], x + 54, y, 480, 34, 26, WHITE, BOLD)
		label(c, tip[2], x + 54, y + 34, 470, 52, 20, PALE, REGULAR, { wrap = true })
		box(c, x, y + 92, 520, 1, PALE, 0.75)
	end
end

buildTab[4] = function(c)
	for i, id in Difficulties.Order do
		local d = Difficulties[id]
		local y = 8 + 110 * (i - 1)
		label(c, d.Upper, 40, y + 6, 240, 44, 38, onPaper(d.Color), BOLD)
		for k = 1, #Difficulties.Order do -- medidor: cuadros llenos hasta el nivel de esta dificultad
			local sq = box(c, 40 + (k - 1) * 34, y + 58, 28, 12, onPaper(d.Color), (k <= i) and 0 or 1)
			stroke(sq, onPaper(d.Color), 2)
		end
		label(c, d.Description, 290, y + 8, 460, 80, 20, PALE, REGULAR, { wrap = true })
		label(c, "HEALTH ×" .. ratio(d.Health) .. "    DAMAGE ×" .. ratio(d.Damage), 790, y + 14, 350, 30, 22, GOLD, BOLD)
		label(c, "PRICES ×" .. ratio(d.Cost) .. "    CANS ×" .. ratio(d.Reward), 790, y + 50, 350, 30, 22, GOLD, BOLD)
		if i < #Difficulties.Order then
			box(c, 40, y + 98, 1100, 1, PALE, 0.75)
		end
	end
end

function HelpPanel.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Help"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Parent = player:WaitForChild("PlayerGui")

	-- ===== Panel =====
	local dim = Instance.new("TextButton") -- fondo oscuro; un clic fuera del panel lo cierra
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.Visible = false
	dim.Parent = gui

	local panel = Instance.new("Frame")
	panel.Active = true -- no deja pasar los clics al juego
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
	panel.BackgroundColor3 = PANEL
	panel.BorderSizePixel = 0
	panel.Parent = dim
	stroke(panel, DARK, 3)
	panel.Rotation = -0.4
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function fit()
		local view = gui.AbsoluteSize
		if view.X > 0 and view.Y > 0 then
			scale.Scale = math.min(1, view.X / (PANEL_W + 80), view.Y / (PANEL_H + 80))
		end
	end
	fit()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	label(panel, "HOW TO PLAY", 32, 16, 360, 56, 42, GOLD, BOLD)
	box(panel, 0, 86, PANEL_W, 3, DARK)
	label(panel, Controls.isTouch() and "Tap outside to close  ·  Closes by itself if zombies are near" or "K or click outside to close  ·  Closes by itself if zombies are near", 32, PANEL_H - 36, 640, 26, 18, PALE, REGULAR)
	if not Controls.isTouch() then
		label(panel, "←  →  switch tab", 700, PANEL_H - 36, 448, 26, 18, PALE, REGULAR, { align = Enum.TextXAlignment.Right })
	end

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(0, 94)
	holder.Size = UDim2.fromOffset(PANEL_W, PANEL_H - 140)
	holder.ClipsDescendants = true
	holder.Parent = panel

	local tabButtons = {}
	local currentTab = 1
	local function showTab(i)
		currentTab = i
		for _, child in holder:GetChildren() do
			child:Destroy()
		end
		local content = Instance.new("CanvasGroup")
		content.BackgroundTransparency = 1
		content.Size = UDim2.fromScale(1, 1)
		content.GroupTransparency = 1
		content.Parent = holder
		buildTab[i](content)
		TweenService:Create(content, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
		for index, t in tabButtons do
			local active = index == i
			t.button.BackgroundColor3 = active and DARK or PANEL
			t.button.TextColor3 = active and HILITE or DARK
		end
	end

	local tabWidths = { 150, 170, 150, 200 }
	local x = 392
	for i, name in HelpContent.Tabs do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.FontFace = TYPEWRITER
		b.TextSize = 19
		b.Text = name
		b.Position = UDim2.fromOffset(x, 22)
		b.Size = UDim2.fromOffset(tabWidths[i], 44)
		b.BorderSizePixel = 0
		b.Parent = panel
		stroke(b, DARK, 2)
		b.Activated:Connect(function()
			showTab(i)
		end)
		tabButtons[i] = { button = b }
		x += tabWidths[i] + 10
	end
	local closeButton = Instance.new("TextButton")
	closeButton.AutoButtonColor = false
	closeButton.FontFace = BOLD
	closeButton.TextSize = 22
	closeButton.Text = "X"
	closeButton.TextColor3 = LIGHT
	closeButton.BackgroundColor3 = DARK
	closeButton.BorderSizePixel = 0
	closeButton.Position = UDim2.fromOffset(PANEL_W - 58, 24)
	closeButton.Size = UDim2.fromOffset(40, 40)
	closeButton.Parent = panel

	-- ===== Tarjeta de bienvenida: expediente de papel con cinta, sello y teclas resaltadas =====
	local WELCOME_W, WELCOME_H = 760, 590
	local welcome = Instance.new("Frame")
	welcome.Active = true
	welcome.AnchorPoint = Vector2.new(0.5, 0.5)
	welcome.Position = UDim2.fromScale(0.5, 0.5)
	welcome.Size = UDim2.fromOffset(WELCOME_W, WELCOME_H)
	welcome.BackgroundColor3 = Color3.new(1, 1, 1)
	welcome.BorderSizePixel = 0
	welcome.Rotation = -1.2
	welcome.Visible = false
	welcome.Parent = gui
	local paperShade = Instance.new("UIGradient")
	paperShade.Color = ColorSequence.new(Color3.fromRGB(238, 226, 194), Color3.fromRGB(212, 194, 156))
	paperShade.Rotation = 70
	paperShade.Parent = welcome
	stroke(welcome, Color3.new(0, 0, 0), 5).Transparency = 0.6
	local welcomeScale = Instance.new("UIScale")
	welcomeScale.Parent = welcome
	for _, tape in { { 36, -16, 200, 42, -3 }, { 536, -24, 170, 42, 2 } } do
		local strip = box(welcome, tape[1], tape[2], tape[3], tape[4], Color3.fromRGB(238, 232, 204), 0.12)
		strip.Rotation = tape[5]
		stroke(strip, Color3.fromRGB(190, 180, 150), 1)
	end
	label(welcome, "CASE FILE No. 07 · GROUND ZERO", 34, 34, 520, 26, 17, PALE, TYPEWRITER)
	label(welcome, HelpContent.Welcome.Title, 34, 70, 460, 130, 58, DARK, HEAD, { wrap = true, lineHeight = 0.95 })
	local stamp = box(welcome, 492, 44, 236, 84, PANEL, 1)
	stamp.Rotation = 5
	stroke(stamp, GOLD, 4).Transparency = 0.1
	label(stamp, "EVACUATION ORDER", 6, 6, 224, 72, 27, GOLD, HEAD, { wrap = true, align = Enum.TextXAlignment.Center, valign = Enum.TextYAlignment.Center, lineHeight = 0.95 })
	box(welcome, 34, 212, 692, 4, DARK)
	-- Las teclas de cada línea se resaltan con marcador amarillo
	local HILITES = { "Shift", "3 to 7", "3 a 7", "READY", "FIRE", "AIM", "RELOAD", "R", "E", "F", "Y" }
	local function highlight(text)
		for _, token in HILITES do
			text = string.gsub(text, "%f[%w]" .. token .. "%f[%W]", `<mark color="#f6c446" transparency="0.05">{token}</mark>`)
		end
		return text
	end
	for i, line in HelpContent.Welcome.Lines do
		local y = 236 + 64 * (i - 1)
		label(welcome, string.format("%02d.", i), 34, y, 60, 30, 23, GOLD, TYPEWRITER)
		label(welcome, highlight(Lang.tr(line)), 100, y, 620, 60, 20, DARK, TYPEWRITER, { wrap = true, rich = true, lineHeight = 1.2 })
	end
	local gotIt = Instance.new("TextButton")
	gotIt.AutoButtonColor = false
	gotIt.FontFace = HEAD
	gotIt.TextSize = 28
	gotIt.Text = "GOT IT"
	gotIt.TextColor3 = HILITE
	gotIt.BackgroundColor3 = DARK
	gotIt.BorderSizePixel = 0
	gotIt.Position = UDim2.fromOffset(34, 506)
	gotIt.Size = UDim2.fromOffset(250, 56)
	gotIt.Parent = welcome
	local more = Instance.new("TextButton")
	more.AutoButtonColor = false
	more.FontFace = TYPEWRITER
	more.TextSize = 20
	more.Text = Controls.isTouch() and "VIEW FULL HELP" or "K  ·  VIEW FULL HELP"
	more.TextColor3 = DARK
	more.BackgroundTransparency = 1
	more.BorderSizePixel = 0
	more.Position = UDim2.fromOffset(304, 506)
	more.Size = UDim2.fromOffset(422, 56)
	more.Parent = welcome
	stroke(more, DARK, 2).Transparency = 0.15

	-- ===== Pista "K · AYUDA" =====
	local hint = Instance.new("Frame")
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -12)
	hint.Size = UDim2.fromOffset(120, 30)
	hint.BackgroundTransparency = 1
	hint.Parent = gui
	local hintKey = box(hint, 0, 2, 26, 26, HILITE, 0.1)
	label(hintKey, "K", 0, 0, 26, 26, 18, DARK, HEAD, { align = Enum.TextXAlignment.Center, valign = Enum.TextYAlignment.Center })
	local hintText = label(hint, "HELP", 36, 0, 84, 30, 18, LIGHT, HEAD, { valign = Enum.TextYAlignment.Center })
	hintText.TextTransparency = 0.25

	-- ===== Lógica =====
	local panelOpen = false
	-- En celular la ayuda se abre con el botón "?" y no se muestra la tecla K
	hint.Visible = not Controls.isTouch()
	Controls.touchChanged:Connect(function()
		hint.Visible = not panelOpen and not Controls.isTouch()
	end)
	local welcomeOpen = false
	local welcomeShown = false -- ya se mostró en esta sesión (no se repite si se cierra)
	local function markSeen()
		if not player:GetAttribute("HelpSeen") then
			Remotes.HelpSeen:FireServer()
			player:SetAttribute("HelpSeen", true) -- no se vuelve a mostrar aunque el guardado falle
		end
	end

	local function setWelcome(open)
		if welcomeOpen == open then
			return
		end
		welcomeOpen = open
		if open then
			welcome.Visible = true
			local view = gui.AbsoluteSize
			local target = math.min(1, view.X / (WELCOME_W + 60), view.Y / (WELCOME_H + 60))
			-- cae sobre la pantalla como una carpeta lanzada: empieza más grande y torcida, y se asienta
			welcome.Rotation = -7
			welcomeScale.Scale = target * 1.12
			TweenService:Create(welcomeScale, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Scale = target }):Play()
			TweenService:Create(welcome, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Rotation = -1.2 }):Play()
		else
			welcome.Visible = false
			markSeen()
		end
	end

	-- Aviso breve en el centro de abajo ("Help closed: zombies nearby")
	local notice = label(gui, "", 0, 0, 640, 36, 24, HILITE, HEAD, { align = Enum.TextXAlignment.Center, valign = Enum.TextYAlignment.Center })
	notice.AnchorPoint = Vector2.new(0.5, 1)
	notice.Position = UDim2.new(0.5, 0, 1, -64)
	notice.TextStrokeTransparency = 0.4
	notice.TextTransparency = 1
	local noticeToken = 0
	local function showNotice(text)
		noticeToken += 1
		local token = noticeToken
		notice.Text = text
		notice.TextTransparency = 0
		task.delay(2.2, function()
			if noticeToken == token then
				TweenService:Create(notice, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			end
		end)
	end

	-- ¿Hay un zombie vivo cerca? (la ayuda no debe tapar la pantalla en plena horda)
	local function zombieNear()
		local zombies = workspace:FindFirstChild("Zombies")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (zombies and root) then
			return false
		end
		for _, model in zombies:GetChildren() do
			local zombieRoot = model:FindFirstChild("HumanoidRootPart")
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if zombieRoot and humanoid and humanoid.Health > 0 and (zombieRoot.Position - root.Position).Magnitude <= COMBAT_DISTANCE then
				return true
			end
		end
		return false
	end

	local function setPanel(open)
		if panelOpen == open then
			return
		end
		if open and player:GetAttribute("UiOpen") then
			return -- otra ventana (la tienda) ya tiene el ratón
		end
		if open and zombieNear() then
			showNotice("Zombies nearby: help opens when you're safe")
			return
		end
		panelOpen = open
		dim.Visible = open
		player:SetAttribute("UiOpen", open or nil)
		hint.Visible = not open and not Controls.isTouch()
		if open then
			setWelcome(false)
			showTab(currentTab)
		end
	end

	-- El botón "?" del celular (client/TouchControls)
	function HelpPanel.toggle()
		setPanel(not panelOpen)
	end

	gotIt.Activated:Connect(function()
		setWelcome(false)
	end)
	more.Activated:Connect(function()
		setWelcome(false)
		setPanel(true)
	end)
	closeButton.Activated:Connect(function()
		setPanel(false)
	end)
	dim.Activated:Connect(function()
		setPanel(false)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.K then
			setPanel(not panelOpen)
		elseif panelOpen and input.KeyCode == Enum.KeyCode.Escape then
			setPanel(false)
		elseif panelOpen and input.KeyCode == Enum.KeyCode.Left then
			showTab((currentTab - 2) % #HelpContent.Tabs + 1)
		elseif panelOpen and input.KeyCode == Enum.KeyCode.Right then
			showTab(currentTab % #HelpContent.Tabs + 1)
		elseif welcomeOpen and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter) then
			setWelcome(false)
		end
	end)

	-- Con el panel abierto: se cierra solo si se acercan zombies o si el jugador recibe daño
	task.spawn(function()
		while true do
			task.wait(0.4)
			if panelOpen and zombieNear() then
				setPanel(false)
				showNotice("Help closed: zombies nearby")
			end
		end
	end)
	local healthConnection = nil
	local function watchHealth(character)
		if healthConnection then
			healthConnection:Disconnect()
			healthConnection = nil
		end
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		local lastHealth = humanoid.Health
		healthConnection = humanoid.HealthChanged:Connect(function(health)
			if health < lastHealth and panelOpen then
				setPanel(false)
				showNotice("Help closed: you've been hurt")
			end
			lastHealth = health
		end)
	end
	player.CharacterAdded:Connect(watchHealth)
	if player.Character then
		task.spawn(watchHealth, player.Character)
	end

	-- Bienvenida: la primera vez que llega al lobby (se espera a que el servidor diga si ya la vio)
	local function refreshWelcome()
		local stage = workspace:GetAttribute("Stage")
		if stage == "Lobby" and player:GetAttribute("HelpReady") and not player:GetAttribute("HelpSeen") and not welcomeShown and not panelOpen then
			welcomeShown = true
			task.delay(1.5, function()
				if workspace:GetAttribute("Stage") == "Lobby" and not panelOpen and not player:GetAttribute("HelpSeen") then
					setWelcome(true)
					task.delay(WELCOME_SECONDS, function()
						setWelcome(false)
					end)
				end
			end)
		elseif welcomeOpen and stage ~= "Lobby" then
			setWelcome(false) -- empezó la partida: se cierra y queda como vista
		end
	end
	workspace:GetAttributeChangedSignal("Stage"):Connect(refreshWelcome)
	player:GetAttributeChangedSignal("HelpReady"):Connect(refreshWelcome)
	refreshWelcome()
end

return HelpPanel
