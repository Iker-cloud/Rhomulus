-- Menú de Rhomulus: título -> menú principal -> crear / unirse.
-- Diseño en 1920x1080, escalado a la pantalla. Las salas son de muestra:
-- falta conectar el código, la lista de jugadores y el teletransporte.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

-- Pantalla táctil sin ratón (celular o tableta): el lienzo se ajusta mejor a la pantalla y los botones son más altos
local TOUCH = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RED = Color3.fromRGB(198, 21, 26)
local DARK = Color3.fromRGB(110, 0, 0)
local LIGHT = Color3.fromRGB(222, 70, 74)
local BLACK = Color3.new(0, 0, 0)
local OSW_BOLD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
-- Anton no existe en Roblox: el titular usa Oswald en negrita, lo más parecido
local ANTON = OSW_BOLD
local OSW = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Regular)
local OSW_LIGHT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Light)

local MAPS = {
	{ id = "Prueba", name = "PRUEBA" },
	{ id = "Morro", name = "MORRO ESPERANZA" },
}
local function mapName(id)
	for _, m in MAPS do
		if m.id == id then
			return m.name
		end
	end
	return id
end

local Difficulties = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Difficulties"))
local HelpContent = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HelpContent")).get(TOUCH)
local request = ReplicatedStorage:WaitForChild("MenuRequest")
local roomUpdate = ReplicatedStorage:WaitForChild("RoomUpdate")
local roomState -- última foto de la sala en la que estamos (nil = ninguna)
local busy = false

-- El cursor siempre libre y sin interfaz de Roblox encima
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)
Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
RunService:BindToRenderStep("MenuCursor", Enum.RenderPriority.Last.Value, function()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end)

-- string.upper no pasa a mayúsculas las letras con tilde (UTF-8)
local ACCENTS = { ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ", ["ü"] = "Ü" }
local function upperEs(str)
	return (string.gsub(string.upper(str), "[Ã][¡©­³º±¼]", function(c)
		return ACCENTS[c] or c
	end))
end

local function spaced(str, gap)
	local out = {}
	for _, cp in utf8.codes(str) do
		table.insert(out, utf8.char(cp) .. string.rep("\u{2009}", gap or 1))
	end
	return table.concat(out)
end

-- Pantalla base ---------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Menu"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui

-- Música del menú (Places.MenuMusic): en bucle, entra con un fundido y la tecla M la silencia
do
	local Places = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Places"))
	local id = Places.MenuMusic
	if type(id) == "number" and id > 0 then
		local music = Instance.new("Sound")
		music.Name = "MenuMusic"
		music.SoundId = "rbxassetid://" .. id
		music.Looped = true
		music.Volume = 0
		music.Parent = gui
		music:Play()
		local TARGET_VOLUME = 0.45
		local muted = false
		TweenService:Create(music, TweenInfo.new(2.5), { Volume = TARGET_VOLUME }):Play()
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed or input.KeyCode ~= Enum.KeyCode.M then
				return
			end
			muted = not muted
			TweenService:Create(music, TweenInfo.new(0.3), { Volume = muted and 0 or TARGET_VOLUME }):Play()
		end)
	end
end

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = RED
bg.BorderSizePixel = 0
bg.Parent = gui

local root = Instance.new("Frame") -- lienzo de 1920x1080 centrado
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromOffset(1920, 1080)
root.BackgroundTransparency = 1
root.Parent = bg
local uiScale = Instance.new("UIScale")
uiScale.Parent = root
local function fit()
	local v = bg.AbsoluteSize
	if v.X > 0 and v.Y > 0 then
		if TOUCH then
			-- el contenido queda entre x 120 y 1800 e y 124 y 980: se recortan los márgenes vacíos para que todo salga más grande
			uiScale.Scale = math.min(v.X / 1800, v.Y / 960)
		else
			uiScale.Scale = math.min(v.X / 1920, v.Y / 1080)
		end
	end
end
fit()
bg:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

-- Utilidades ------------------------------------------------------------
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

-- Roblox limita TextSize y TextScaled a 100: el texto más grande se hace a 100 y se amplía con un UIScale
local function text(parent, str, font, size, pos, props)
	props = props or {}
	local factor = math.max(1, size / 100)
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Text = str,
		FontFace = font,
		TextSize = math.min(size, 100),
		TextColor3 = props.color or BLACK,
		AnchorPoint = props.anchor or Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		Size = UDim2.fromOffset((props.width or 900) / factor, (factor > 1 and 100 or size) + 20),
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		TextTransparency = props.transparency or 0,
	}, parent)
	if factor > 1 then
		make("UIScale", { Scale = factor }, label)
	end
	return label
end

local function rule(parent, x, y, w, dashed, h)
	if not dashed then
		return make("Frame", {
			BackgroundColor3 = BLACK, BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h or 2),
		}, parent)
	end
	local f = make("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 2),
	}, parent)
	for dx = 0, w - 8, 14 do
		make("Frame", { BackgroundColor3 = BLACK, BorderSizePixel = 0,
			Position = UDim2.fromOffset(dx, 0), Size = UDim2.fromOffset(8, 2) }, f)
	end
	return f
end

local function outline(parent, x, y, w, h, thick)
	local f = make("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
	}, parent)
	make("UIStroke", { Color = BLACK, Thickness = thick or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
	return f
end

local function fade(obj, t, goal)
	TweenService:Create(obj, TweenInfo.new(t), goal):Play()
end

local function button(parent, x, y, w, h, onClick)
	local b = make("TextButton", {
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = 5,
	}, parent)
	b.Activated:Connect(onClick)
	return b
end

-- Elementos fijos --------------------------------------------------------
local cornerL = text(root, spaced("DÍA 01", 2), OSW_BOLD, 34, Vector2.new(120, 124), { transparency = 1 })
local cornerR = text(root, spaced("SOBREVIVE", 2), OSW_BOLD, 34, Vector2.new(1800, 124),
	{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, transparency = 1 })
local version = text(root, spaced("v0.1", 1), OSW, 32, Vector2.new(1800, 960),
	{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 300, transparency = 1 })

-- Logo (con capas de sombra solo en la pantalla de título)
local logo = make("Frame", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromOffset(120, 661), Size = UDim2.fromOffset(1700, 470),
}, root)
local logoScale = make("UIScale", { Scale = 1.05 }, logo)
local layers = {}
for _, l in { { DARK, -10, "shadow" }, { LIGHT, 10, "shadow" }, { BLACK, 0, "main" } } do
	local t = make("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(1700 / 4.4, 100),
		Position = UDim2.new(0, l[2], 0.5, 0), TextSize = 100, TextYAlignment = Enum.TextYAlignment.Center,
		Text = "RHOMULUS", TextColor3 = l[1], FontFace = ANTON,
		TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1,
	}, logo)
	make("UIScale", { Scale = 4.4 }, t)
	table.insert(layers, { label = t, kind = l[3], target = l[3] == "shadow" and 0.15 or 0 })
end

-- Pantallas --------------------------------------------------------------
local screens = {}
local current
local function newScreen(name)
	screens[name] = make("CanvasGroup", {
		Name = "Pantalla_" .. name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Visible = false,
	}, root)
	return screens[name]
end

local builders = {} -- se arman al entrar (así la sala siempre sale limpia)

local function show(name)
	if builders[name] then
		builders[name]()
	end
	if current then
		local old = current
		fade(old, 0.2, { GroupTransparency = 1 })
		task.delay(0.2, function()
			if current ~= old then
				old.Visible = false
			end
		end)
	end
	local s = screens[name]
	current = s
	s.Visible = true
	fade(s, 0.3, { GroupTransparency = 0 })

	-- logo, versión y línea del pie solo en el menú principal
	local isMain = name == "main"
	fade(version, 0.3, { TextTransparency = isMain and 0 or 1, TextColor3 = isMain and LIGHT or BLACK })
	fade(cornerR, 0.3, { TextColor3 = isMain and LIGHT or BLACK })
	for _, l in layers do
		if l.kind == "main" then
			fade(l.label, 0.3, { TextTransparency = isMain and 0 or 1 })
		end
	end
end

local function clear(s)
	for _, c in s:GetChildren() do
		c:Destroy()
	end
end

local function header(s, title)
	text(s, title, ANTON, 112, Vector2.new(120, 220), { width = 1500 })
	rule(s, 120, 282, 1680)
end

local function backButton(s, target, leaveRoom)
	text(s, "←", OSW, 70, Vector2.new(130, 935), { width = 70 })
	text(s, "VOLVER", ANTON, 66, Vector2.new(212, 930), { width = 400 })
	button(s, 120, 890, 320, 80, function()
		if leaveRoom then
			roomState = nil
			task.spawn(function()
				request:InvokeServer("leave")
			end)
		end
		show(target)
	end)
end

local function smallVersion(s, rightX, y)
	text(s, spaced("v0.1", 1), OSW, 32, Vector2.new(rightX, y),
		{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 200 })
end

-- 1) Principal -----------------------------------------------------------
local main = newScreen("main")
local DEFAULT_STATUS = spaced("1–4 JUGADORES · COOPERATIVO", 2)
local status = text(main, DEFAULT_STATUS, OSW_BOLD, 34, Vector2.new(120, 960), { width = 1400 })
local function setStatus(msg)
	status.Text = msg and spaced(string.upper(msg), 2) or DEFAULT_STATUS
end
rule(main, 120, 912, 1680)
local DESCRIPTIONS = {
	"Mira las salas abiertas y entra a una. Las privadas llevan candado y piden su código.",
	"Crea tu sala, pública o privada, y elige el mapa y la dificultad.",
	"El objetivo, los controles, las dificultades y consejos para sobrevivir.",
}
local desc = text(main, "", OSW, 40, Vector2.new(120, 874), { width = 1100, transparency = 1 })
local arrow = text(main, "▶", OSW, 38, Vector2.new(52, 520), { width = 40, transparency = 1 })
local items = {
	{ "JUGAR", function()
		setStatus(nil)
		show("list")
	end },
	{ "CREAR PARTIDA", function()
		setStatus(nil)
		show("setup")
	end },
	{ "CÓMO JUGAR", function()
		setStatus(nil)
		show("help")
	end },
}
for i, item in items do
	local y = 404 + 112 * (i - 1)
	text(main, spaced(item[1], 0), ANTON, 94, Vector2.new(120, y + 57), { width = 1000 })
	rule(main, 120, y + 112, 900)
	local b = button(main, 40, y, 980, 112, item[2])
	b.Name = "Item" .. i
	b.MouseEnter:Connect(function()
		arrow.Position = UDim2.fromOffset(52, y + 62)
		arrow.TextTransparency = 0
		desc.Text = DESCRIPTIONS[i]
		desc.TextTransparency = 1
		fade(desc, 0.2, { TextTransparency = 0 })
	end)
	b.MouseLeave:Connect(function()
		arrow.TextTransparency = 1
		fade(desc, 0.15, { TextTransparency = 1 })
	end)
end

-- 4) Cómo jugar ------------------------------------------------------------
-- Cuatro pestañas: objetivo, controles, consejos y dificultades. Los textos de las dificultades salen de shared/Difficulties.
local help = newScreen("help")

-- Párrafo con salto de línea automático (la esquina superior izquierda va en `pos`)
local function paragraph(parent, str, font, size, pos, width, height, props)
	props = props or {}
	return make("TextLabel", {
		BackgroundTransparency = 1, Text = str, FontFace = font, TextSize = size, TextColor3 = props.color or BLACK,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = props.lineHeight or 1.1, Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(width, height),
	}, parent)
end

-- Casilla de tecla: fondo negro y letras rojas. Devuelve su ancho.
local function keycap(parent, x, y, label)
	local w = math.max(64, 19 * (utf8.len(label) or #label) + 28)
	make("Frame", { BackgroundColor3 = BLACK, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 52) }, parent)
	text(parent, label, ANTON, 36, Vector2.new(x + w / 2, y + 27),
		{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = w, color = RED })
	return w
end

-- 1.5 -> "1,5"; 1 -> "1"; 1.25 -> "1,25"
local function ratio(n)
	local s = string.format("%.2f", n)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	s = string.gsub(s, "%.", ",")
	return s
end

local HELP_TABS = { { HelpContent.Tabs[1], 200 }, { HelpContent.Tabs[2], 240 }, { HelpContent.Tabs[3], 220 }, { HelpContent.Tabs[4], 290 } }

local STEPS, CONTROLS, TIPS = HelpContent.Steps, HelpContent.Controls, HelpContent.Tips

local buildHelpTab = {}

buildHelpTab[1] = function(c)
	paragraph(c, HelpContent.Headline, ANTON, 92, Vector2.new(120, 322), 740, 210, { lineHeight = 1.0 })
	rule(c, 120, 548, 120, false, 6)
	paragraph(c, HelpContent.Objective[1], OSW, 38, Vector2.new(120, 580), 720, 140)
	paragraph(c, HelpContent.Objective[2], OSW_BOLD, 38, Vector2.new(120, 735), 720, 100)
	for i, step in STEPS do
		local y = 322 + 104 * (i - 1)
		text(c, string.format("%02d", i), OSW_BOLD, 40, Vector2.new(900, y + 28), { width = 70 })
		text(c, step[1], ANTON, 48, Vector2.new(990, y + 28), { width = 800 })
		text(c, step[2], OSW, TOUCH and 38 or 32, Vector2.new(990, y + 74), { width = 810 })
		if i < #STEPS then
			rule(c, 900, y + 100, 900)
		end
	end
end

buildHelpTab[2] = function(c)
	for col, group in CONTROLS do
		local x = 120 + 580 * (col - 1)
		text(c, spaced(group[1], 3), OSW_BOLD, 36, Vector2.new(x, 345), { width = 520 })
		rule(c, x, 376, 520)
		for i, row in group[2] do
			local y = 400 + 68 * (i - 1)
			keycap(c, x, y, row[1])
			text(c, row[2], OSW_BOLD, 32, Vector2.new(x + 246, y + 27), { width = 300 })
		end
	end
	text(c, HelpContent.ControlsNote, OSW, 30, Vector2.new(120, 822), { width = 1300 })
	text(c, spaced(HelpContent.ControlsSide, 2), OSW_BOLD, 28, Vector2.new(1800, 822),
		{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 600 })
end

buildHelpTab[3] = function(c)
	for i, tip in TIPS do
		local col = (i - 1) // 4
		local row = (i - 1) % 4
		local x = 120 + 870 * col
		local y = 322 + 130 * row
		text(c, string.format("%02d", i), OSW_BOLD, 36, Vector2.new(x, y + 24), { width = 70 })
		text(c, tip[1], ANTON, 46, Vector2.new(x + 76, y + 24), { width = 720 })
		paragraph(c, tip[2], OSW, 31, Vector2.new(x + 76, y + 54), 720, 68)
		rule(c, x, y + 124, 810)
	end
end

buildHelpTab[4] = function(c)
	for i, id in Difficulties.Order do
		local d = Difficulties[id]
		local y = 322 + 134 * (i - 1)
		text(c, string.format("%02d", i), OSW_BOLD, 36, Vector2.new(120, y + 30), { width = 70 })
		text(c, d.Upper, ANTON, 64, Vector2.new(190, y + 34), { width = 400 })
		for k = 1, #Difficulties.Order do -- medidor: cuadros negros llenos hasta el nivel de esta dificultad
			local box = make("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = (k <= i) and 0 or 1, BorderSizePixel = 0,
				Position = UDim2.fromOffset(194 + (k - 1) * 40, y + 84), Size = UDim2.fromOffset(32, 14) }, c)
			make("UIStroke", { Color = BLACK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
		end
		paragraph(c, d.Description, OSW, 30, Vector2.new(600, y + 6), 740, 100)
		text(c, "VIDA ×" .. ratio(d.Health) .. "    DAÑO ×" .. ratio(d.Damage), OSW_BOLD, 30, Vector2.new(1390, y + 32), { width = 430 })
		text(c, "PRECIOS ×" .. ratio(d.Cost) .. "    LATAS ×" .. ratio(d.Reward), OSW_BOLD, 30, Vector2.new(1390, y + 74), { width = 430 })
		if i < #Difficulties.Order then
			rule(c, 120, y + 118, 1680)
		end
	end
end

builders.help = function()
	local s = help
	clear(s)
	header(s, "CÓMO JUGAR")
	local holder = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, s)
	local tabs = {}
	local function paintTabs(active)
		for i, t in tabs do
			t.box.BackgroundTransparency = (i == active) and 0 or 1
			t.label.TextColor3 = (i == active) and RED or BLACK
		end
	end
	local function showTab(i)
		for _, child in holder:GetChildren() do
			child:Destroy()
		end
		local content = make("CanvasGroup", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), GroupTransparency = 1 }, holder)
		buildHelpTab[i](content)
		fade(content, 0.25, { GroupTransparency = 0 })
		paintTabs(i)
	end
	local x = 802
	local tabY, tabH = TOUCH and 180 or 190, TOUCH and 84 or 62 -- en celular las pestañas son más altas para tocarlas
	for i, tab in HELP_TABS do
		local w = tab[2]
		local box = make("Frame", { BackgroundColor3 = BLACK, Position = UDim2.fromOffset(x, tabY), Size = UDim2.fromOffset(w, tabH), BorderSizePixel = 0 }, s)
		make("UIStroke", { Color = BLACK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
		local label = text(s, tab[1], ANTON, 40, Vector2.new(x + w / 2, tabY + tabH / 2),
			{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = w })
		button(s, x, tabY, w, tabH, function()
			showTab(i)
		end)
		tabs[i] = { box = box, label = label }
		x += w + 16
	end
	rule(s, 120, 857, 1680)
	backButton(s, "main")
	smallVersion(s, 1800, 932)
	showTab(1)
end

-- Salas -----------------------------------------------------------------------------------------------------------------------
-- Avatares: la cara de cada jugador (miniatura de Roblox), con una caché para no pedirla dos veces
local avatarCache = {} -- [userId] = imagen
local shownAvatars = {} -- [userId] = true: ya salieron en la sala actual (los nuevos aparecen con una animación)

local function loadAvatar(image, userId)
	if avatarCache[userId] then
		image.Image = avatarCache[userId]
		return
	end
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and content then
			avatarCache[userId] = content
			if image.Parent then
				image.Image = content
			end
		end
	end)
end

-- Círculo con la cara de `userId` (centro en x, y). animate: que aparezca creciendo si es nuevo en la sala.
local function avatarCircle(parent, x, y, size, userId, animate)
	local frame = make("Frame", {
		BackgroundColor3 = BLACK, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), ClipsDescendants = true,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, frame)
	make("UIStroke", { Color = BLACK, Thickness = math.max(3, size * 0.07), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	local image = make("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop }, frame)
	loadAvatar(image, userId)
	if animate and not shownAvatars[userId] then
		local scale = make("UIScale", { Scale = 0.1 }, frame)
		TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	if animate then
		shownAvatars[userId] = true
	end
	return frame
end

-- Entrar a una sala (devuelta por el servidor): el anfitrión va a su sala y los demás a la sala de espera
local function enterRoom(st)
	shownAvatars = {}
	roomState = st
	setStatus(nil)
	show(st.isHost and "create" or "joined")
end

-- Casillas de elección: la elegida se rellena de negro. items = { { id, etiqueta, ancho }, ... }. Devuelve la función que las repinta.
local function choiceRow(s, x, y, h, items, textSize, isOn, onPick)
	local boxes = {}
	local function paint()
		for _, b in boxes do
			local on = isOn(b.id)
			b.box.BackgroundTransparency = on and 0 or 1
			b.label.TextColor3 = on and RED or BLACK
		end
	end
	for _, item in items do
		local w = item[3]
		local box = make("Frame", { BackgroundColor3 = BLACK, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BorderSizePixel = 0 }, s)
		make("UIStroke", { Color = BLACK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
		local label = text(s, item[2], ANTON, textSize, Vector2.new(x + w / 2, y + h / 2),
			{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = w })
		button(s, x, y, w, h, function()
			onPick(item[1])
			paint()
		end).Name = `Opcion{y}_{tostring(item[1])}`
		table.insert(boxes, { id = item[1], box = box, label = label })
		x += w + 16
	end
	paint()
	return paint
end

-- Candado dibujado con rectángulos (la fuente no tiene el símbolo)
local function lockIcon(parent, x, y, size, color)
	local shackle = make("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(x + size * 0.2, y), Size = UDim2.fromOffset(size * 0.6, size * 0.8),
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, shackle)
	make("UIStroke", { Color = color, Thickness = math.max(3, size * 0.12), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, shackle)
	local body = make("Frame", {
		BackgroundColor3 = color, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y + size * 0.4), Size = UDim2.fromOffset(size, size * 0.62),
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, body)
	make("Frame", {
		BackgroundColor3 = RED, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x + size / 2, y + size * 0.71), Size = UDim2.fromOffset(size * 0.16, size * 0.26),
	}, parent)
end

local function difficultyName(id)
	return Difficulties.get(id).Upper
end

-- 2) Lista de salas ----------------------------------------------------------------------------------------------------------
local list = newScreen("list")
local listToken = 0

-- Intenta entrar a una sala. Devuelve true, o false + motivo + si el código estaba mal.
local function tryJoin(item, pass)
	if busy then
		return false, "Espera un momento"
	end
	busy = true
	local ok, r = pcall(function()
		return request:InvokeServer("join", item.id, pass)
	end)
	busy = false
	if not ok or not r then
		return false, "No se pudo conectar. Intenta de nuevo"
	end
	if r.room then
		enterRoom(r.room)
		return true
	end
	return false, r.error or "No se pudo entrar", r.wrongCode
end

-- Ventana para escribir el código de una sala privada
local function askCode(s, item)
	local layer = make("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), Active = true }, s)
	local panel = make("Frame", { BackgroundColor3 = RED, Position = UDim2.fromOffset(330, 200), Size = UDim2.fromOffset(1260, 700), BorderSizePixel = 0 }, layer)
	make("UIStroke", { Color = BLACK, Thickness = 6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)
	lockIcon(panel, 60, 62, 70, BLACK)
	text(panel, "SALA PRIVADA", ANTON, 84, Vector2.new(160, 100), { width = 900 })
	text(panel, spaced(upperEs(item.name), 2), OSW_BOLD, 34, Vector2.new(60, 190), { width = 1100 })
	rule(panel, 60, 222, 1140)

	local slots = {}
	for i = 1, 4 do
		local x = 150 + 270 * (i - 1)
		local slotBox = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(x, 260), Size = UDim2.fromOffset(220, 260) }, panel)
		make("UIStroke", { Color = BLACK, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, slotBox)
		slots[i] = text(panel, "", ANTON, 250, Vector2.new(x + 110, 395), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 220 })
	end
	local caption = text(panel, spaced("ESCRIBE EL CÓDIGO DE 4 LETRAS", 3), OSW_BOLD, 32, Vector2.new(630, 568),
		{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 1100 })

	local enterBox = make("Frame", { BackgroundColor3 = BLACK, BorderSizePixel = 0, Position = UDim2.fromOffset(760, 600), Size = UDim2.fromOffset(440, 80) }, panel)
	local enterLabel = text(panel, "ENTRAR", ANTON, 62, Vector2.new(980, 640),
		{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 440, color = RED, transparency = 0.5 })
	outline(panel, 60, 600, 440, 80, 4)
	text(panel, "CANCELAR", ANTON, 62, Vector2.new(280, 640), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 440 })
	enterBox.Name = "EnterBox"

	-- La TextBox invisible recibe lo que se escribe (también el teclado del celular)
	local box = make("TextBox", {
		BackgroundTransparency = 1, Text = "", TextTransparency = 1, ClearTextOnFocus = false, PlaceholderText = "",
		Position = UDim2.fromOffset(150, 260), Size = UDim2.fromOffset(1020, 260), ZIndex = 25,
	}, panel)
	local function submit()
		if #box.Text ~= 4 then
			return
		end
		caption.Text = spaced("COMPROBANDO…", 3)
		local ok, why, wrong = tryJoin(item, box.Text)
		if ok then
			layer:Destroy()
		else
			caption.Text = spaced(string.upper(why or "NO SE PUDO ENTRAR"), 2)
			if wrong then
				box.Text = ""
			end
		end
	end
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local t = string.sub(string.gsub(string.upper(box.Text), "[^A-Z]", ""), 1, 4)
		if t ~= box.Text then
			box.Text = t
			return
		end
		for i = 1, 4 do
			slots[i].Text = string.sub(t, i, i)
		end
		enterLabel.TextTransparency = (#t == 4) and 0 or 0.5
		if #t == 4 and TOUCH then
			box:ReleaseFocus() -- el teclado de la pantalla tapa los botones
		end
	end)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
	button(panel, 760, 600, 440, 80, submit).ZIndex = 26
	button(panel, 60, 600, 440, 80, function()
		layer:Destroy()
	end).ZIndex = 26
	task.delay(0.2, function()
		if box.Parent then
			box:CaptureFocus()
		end
	end)
end

builders.list = function()
	local s = list
	clear(s)
	listToken += 1
	local token = listToken
	header(s, "SALAS")

	-- Crear una sala nueva (arriba a la derecha)
	make("Frame", { BackgroundColor3 = BLACK, BorderSizePixel = 0, Position = UDim2.fromOffset(1340, 186), Size = UDim2.fromOffset(460, 76) }, s)
	text(s, "CREAR SALA", ANTON, 56, Vector2.new(1570, 224), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 460, color = RED })
	button(s, 1340, 186, 460, 76, function()
		show("setup")
	end).Name = "CrearSala"

	rule(s, 120, 857, 1680)
	backButton(s, "main")
	smallVersion(s, 1800, 932)

	local scroller = make("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(120, 310), Size = UDim2.fromOffset(1680, 480),
		CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8,
		ScrollBarImageColor3 = BLACK, ScrollingDirection = Enum.ScrollingDirection.Y, ElasticBehavior = Enum.ElasticBehavior.Never,
	}, s)
	local emptyTitle = text(s, spaced("NO HAY SALAS ABIERTAS", 3), ANTON, 64, Vector2.new(960, 520),
		{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 1500 })
	local emptyHint = text(s, spaced("CREA LA TUYA CON EL BOTÓN DE ARRIBA", 2), OSW, 38, Vector2.new(960, 600),
		{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 1500 })
	emptyTitle.Visible, emptyHint.Visible = false, false
	local note = text(s, "", OSW_BOLD, 32, Vector2.new(120, 818), { width = 1680 })

	local lastKey = nil
	local function render(items)
		local parts = {}
		for _, item in items do
			table.insert(parts, `{item.id}:{item.count}:{tostring(item.public)}:{item.map}:{item.difficulty}:{item.name}`)
		end
		local key = table.concat(parts, "|")
		if key == lastKey then
			return
		end
		lastKey = key
		local position = scroller.CanvasPosition
		for _, c in scroller:GetChildren() do
			c:Destroy()
		end
		emptyTitle.Visible, emptyHint.Visible = #items == 0, #items == 0
		for i, item in items do
			local y = (i - 1) * 112
			local full = item.count >= item.max
			local alpha = full and 0.55 or 0
			local row = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, y + 4), Size = UDim2.fromOffset(1636, 100) }, scroller)
			row.Name = "Fila" .. i
			make("UIStroke", { Color = BLACK, Thickness = 3, Transparency = alpha, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, row)
			local nameX = 36
			if not item.public then
				lockIcon(row, 36, 28, 46, BLACK)
				nameX = 106
			end
			text(row, upperEs(item.name), ANTON, 54, Vector2.new(nameX, 50), { width = 800, transparency = alpha })
			text(row, string.upper(mapName(item.map)), OSW_BOLD, 32, Vector2.new(930, 30), { width = 300, transparency = alpha })
			text(row, difficultyName(item.difficulty), OSW, 32, Vector2.new(930, 72), { width = 300, transparency = alpha })
			text(row, `{item.count}/{item.max}`, ANTON, 64, Vector2.new(1600, 40),
				{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 220, transparency = alpha })
			if full then
				text(row, spaced("LLENA", 2), OSW_BOLD, 26, Vector2.new(1600, 84),
					{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 200 })
			end
			-- caras de quienes ya están dentro
			for k, userId in item.ids or {} do
				if k <= 4 then
					local face = avatarCircle(row, 1262 + (k - 1) * 58, 50, 52, userId, false)
					if full then
						face.BackgroundTransparency = 0.45
					end
				end
			end
			local click = make("TextButton", {
				BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), ZIndex = 5,
			}, row)
			click.Name = "Sala" .. i
			click.Activated:Connect(function()
				if full then
					note.Text = spaced("ESA SALA ESTÁ LLENA", 2)
				elseif item.public then
					note.Text = ""
					local ok, why = tryJoin(item)
					if not ok then
						note.Text = spaced(string.upper(why or "NO SE PUDO ENTRAR"), 2)
					end
				else
					note.Text = ""
					askCode(s, item)
				end
			end)
		end
		scroller.CanvasPosition = position
	end

	-- La lista se refresca sola mientras esta pantalla está abierta
	task.spawn(function()
		task.wait()
		while listToken == token and current == s do
			local ok, r = pcall(function()
				return request:InvokeServer("list")
			end)
			if listToken ~= token or current ~= s then
				break
			end
			if ok and r and r.rooms then
				render(r.rooms)
			elseif ok and r and r.error then
				note.Text = spaced(string.upper(r.error), 2)
			end
			task.wait(3)
		end
	end)
end

-- 3) Nueva sala: pública o privada, mapa y dificultad ----------------------------------------------------------------------------
local setup = newScreen("setup")
local setupState = { public = true, map = "Morro", difficulty = Difficulties.Default }

builders.setup = function()
	local s = setup
	clear(s)
	header(s, "NUEVA SALA")

	-- Vista previa: así se verá tu sala en la lista (se actualiza al cambiar las opciones)
	text(s, spaced("ASÍ APARECERÁ EN LA LISTA", 3), OSW_BOLD, 30, Vector2.new(1000, 336), { width = 800 })
	local previewHolder = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(1000, 366), Size = UDim2.fromOffset(800, 330) }, s)
	local function drawPreview()
		for _, c in previewHolder:GetChildren() do
			c:Destroy()
		end
		local row = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(796, 150) }, previewHolder)
		make("UIStroke", { Color = BLACK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, row)
		local nameX = 28
		if not setupState.public then
			lockIcon(row, 28, 24, 52, BLACK)
			nameX = 100
		end
		text(row, upperEs("Sala de " .. (player.DisplayName ~= "" and player.DisplayName or player.Name)), ANTON, 54, Vector2.new(nameX, 52), { width = 560 })
		text(row, spaced(upperEs(mapName(setupState.map)), 1), OSW_BOLD, 34, Vector2.new(28, 106), { width = 520 })
		text(row, "1/4", ANTON, 70, Vector2.new(770, 52), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 200 })
		text(row, spaced(difficultyName(setupState.difficulty), 1), OSW, 32, Vector2.new(770, 112),
			{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 330 })
		text(previewHolder, setupState.public and "Entra cualquiera con un toque." or "Pedirá un código de 4 letras que te daremos al crear la sala.",
			OSW, 30, Vector2.new(4, 186), { width = 790 })
	end
	drawPreview()

	text(s, spaced("QUIÉN PUEDE ENTRAR", 3), OSW_BOLD, 36, Vector2.new(120, 336), { width = 800 })
	local visibilityText = text(s, "", OSW, 36, Vector2.new(120, 478), { width = 1500 })
	local function describeVisibility()
		visibilityText.Text = setupState.public and "Aparece en la lista y entra cualquiera con un toque. No lleva código."
			or "Aparece en la lista con candado: solo entra quien tenga el código de 4 letras que te damos."
	end
	choiceRow(s, 120, 366, 90, { { true, "PÚBLICA", 380 }, { false, "PRIVADA", 380 } }, 60, function(id)
		return setupState.public == id
	end, function(id)
		setupState.public = id
		describeVisibility()
		drawPreview()
	end)
	describeVisibility()

	text(s, spaced("MAPA", 3), OSW_BOLD, 36, Vector2.new(120, 548), { width = 500 })
	choiceRow(s, 120, 578, 80, { { "Prueba", "PRUEBA", 260 }, { "Morro", "MORRO ESPERANZA", 520 } }, 52, function(id)
		return setupState.map == id
	end, function(id)
		setupState.map = id
		drawPreview()
	end)

	text(s, spaced("DIFICULTAD", 3), OSW_BOLD, 36, Vector2.new(120, 700), { width = 500 })
	local difficultyDesc = text(s, "", OSW_LIGHT, 28, Vector2.new(120, 822), { width = 1680 })
	local function describeDifficulty()
		difficultyDesc.Text = Difficulties.get(setupState.difficulty).Description
	end
	local items = {}
	for _, id in Difficulties.Order do
		table.insert(items, { id, Difficulties[id].Upper, 206 })
	end
	choiceRow(s, 120, 730, 70, items, 40, function(id)
		return setupState.difficulty == id
	end, function(id)
		setupState.difficulty = id
		describeDifficulty()
		drawPreview()
	end)
	describeDifficulty()

	rule(s, 120, 857, 1680)
	backButton(s, "list")
	local errorText = text(s, "", OSW_BOLD, 30, Vector2.new(1340, 932), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 900 })
	make("Frame", { BackgroundColor3 = BLACK, BorderSizePixel = 0, Position = UDim2.fromOffset(1385, 880), Size = UDim2.fromOffset(415, 100) }, s)
	text(s, "CREAR", ANTON, 84, Vector2.new(1592, 932), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 415, color = RED })
	local createButton
	createButton = button(s, 1385, 880, 415, 100, function()
		if busy then
			return
		end
		busy = true
		errorText.Text = spaced("CREANDO LA SALA…", 2)
		local ok, r = pcall(function()
			return request:InvokeServer("create", { map = setupState.map, difficulty = setupState.difficulty, public = setupState.public })
		end)
		busy = false
		if ok and r and r.room then
			enterRoom(r.room)
		else
			errorText.Text = spaced(upperEs((ok and r and r.error) or "NO SE PUDO CREAR LA SALA"), 2)
		end
	end)
	createButton.Name = "Crear"
end

-- Datos comunes de la sala: acceso (código o pública) y jugadores ----------------------------------------------------------------
local function codeText(s, st)
	if st.public then
		text(s, spaced("ACCESO", 3), OSW_BOLD, 36, Vector2.new(120, 342), { width = 500 })
		text(s, "PÚBLICA", ANTON, 200, Vector2.new(120, 515), { width = 900 })
		text(s, spaced("CUALQUIERA PUEDE ENTRAR DESDE LA LISTA", 1), OSW_LIGHT, 34, Vector2.new(120, 681), { width = 800 })
	else
		text(s, spaced("CÓDIGO", 3), OSW_BOLD, 36, Vector2.new(120, 342), { width = 500 })
		text(s, spaced(st.code or "", 0), ANTON, 350, Vector2.new(120, 515), { width = 1100 })
		text(s, spaced("COMPÁRTELO CON TU GRUPO", 1), OSW_LIGHT, 34, Vector2.new(120, 681), { width = 700 })
	end
end

local function playerList(s, names, hostIdx, youIdx, ids)
	text(s, spaced("JUGADORES " .. #names .. "/4", 3), OSW_BOLD, 36, Vector2.new(876, 342), { width = 700 })
	for i = 1, 4 do
		local y = 407 + 72 * (i - 1)
		text(s, string.format("%02d", i), OSW_BOLD, 34, Vector2.new(876, y + 2), { width = 60 })
		if names[i] then
			if ids and ids[i] then
				avatarCircle(s, 970, y, 58, ids[i], true)
			end
			text(s, upperEs(names[i]), ANTON, 62, Vector2.new(1022, y), { width = 600 })
			rule(s, 876, y + 36, 924)
			if i == hostIdx then
				outline(s, 1634, y - 22, 166, 44, 2)
				text(s, spaced("ANFITRIÓN", 1), OSW_BOLD, 26, Vector2.new(1717, y),
					{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 166 })
			elseif i == youIdx then
				make("Frame", { BackgroundColor3 = BLACK, BorderSizePixel = 0,
					Position = UDim2.fromOffset(1738, y - 23), Size = UDim2.fromOffset(62, 46) }, s)
				text(s, spaced("TÚ", 1), OSW_BOLD, 28, Vector2.new(1769, y),
					{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 62, color = RED })
			end
		else
			-- hueco libre: círculo vacío
			local empty = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(970, y), Size = UDim2.fromOffset(58, 58) }, s)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, empty)
			make("UIStroke", { Color = BLACK, Thickness = 2, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, empty)
			text(s, spaced("ESPERANDO…", 2), OSW_LIGHT, 38, Vector2.new(1022, y), { width = 600 })
			rule(s, 876, y + 36, 924, true)
		end
	end
end

-- 4) Tu sala (anfitrión): cambia el acceso, el mapa y la dificultad, y empieza ----------------------------------------------------
local create = newScreen("create")
builders.create = function()
	local s = create
	clear(s)
	local st = roomState
	if not st then
		return
	end
	header(s, upperEs(st.name or "TU SALA"))
	codeText(s, st)
	playerList(s, st.names, st.hostIndex, nil, st.ids)

	-- Quién puede entrar (arriba a la derecha)
	local function hostRequest(action, arg, rebuild)
		task.spawn(function()
			local ok, r = pcall(function()
				return request:InvokeServer(action, arg)
			end)
			if ok and r and r.room then
				roomState = r.room
				if rebuild then
					builders.create()
				end
			end
		end)
	end
	choiceRow(s, 1340, 188, 70, { { true, "PÚBLICA", 222 }, { false, "PRIVADA", 222 } }, 40, function(id)
		return st.public == id
	end, function(id)
		if st.public ~= id then
			st.public = id
			hostRequest("setPublic", id, true)
		end
	end)

	text(s, spaced("MAPA", 3), OSW_BOLD, 36, Vector2.new(876, 714), { width = 400 })
	choiceRow(s, 876, 748, 87, { { "Prueba", "PRUEBA", 211 }, { "Morro", "MORRO ESPERANZA", 433 } }, 56, function(id)
		return st.map == id
	end, function(id)
		st.map = id
		hostRequest("setMap", id)
	end)

	-- Dificultad (izquierda, bajo el acceso): cuatro casillas y la descripción de la elegida
	text(s, spaced("DIFICULTAD", 3), OSW_BOLD, 36, Vector2.new(120, 714), { width = 500 })
	local diffH = TOUCH and 66 or 56 -- casillas más altas en celular
	local diffDesc = text(s, "", OSW_LIGHT, 24, Vector2.new(120, 748 + diffH + 6), { width = 700 })
	diffDesc.AnchorPoint = Vector2.new(0, 0)
	diffDesc.Size = UDim2.fromOffset(700, 48)
	diffDesc.TextWrapped = true
	diffDesc.TextYAlignment = Enum.TextYAlignment.Top
	local function describeDifficulty()
		diffDesc.Text = Difficulties.get(st.difficulty).Description
	end
	local diffItems = {}
	for _, id in Difficulties.Order do
		table.insert(diffItems, { id, Difficulties[id].Upper, 166 })
	end
	local x = 120
	-- (casillas más estrechas que las de "Nueva sala": comparten la columna con el código)
	choiceRow(s, x, 748, diffH, diffItems, 38, function(id)
		return st.difficulty == id
	end, function(id)
		st.difficulty = id
		describeDifficulty()
		hostRequest("setDifficulty", id)
	end)
	describeDifficulty()

	rule(s, 120, 857, 1680)
	backButton(s, "main", true)
	smallVersion(s, 1340, 932)
	make("Frame", { BackgroundColor3 = BLACK, BorderSizePixel = 0,
		Position = UDim2.fromOffset(1385, 880), Size = UDim2.fromOffset(415, 100) }, s)
	text(s, spaced(st.started and "EMPEZANDO…" or "EMPEZAR", 0), ANTON, 84, Vector2.new(1592, 932),
		{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 415, color = RED })
	button(s, 1385, 880, 415, 100, function()
		if not st.started then
			task.spawn(function()
				request:InvokeServer("start")
			end)
		end
	end)
end

-- 5) Sala de espera (los demás jugadores) -------------------------------------------------------------------------------------
local joined = newScreen("joined")
builders.joined = function()
	local s = joined
	clear(s)
	local st = roomState
	if not st then
		return
	end
	header(s, upperEs(st.name or "SALA"))
	codeText(s, st)
	playerList(s, st.names, st.hostIndex, st.youIndex, st.ids)
	text(s, spaced("MAPA: " .. mapName(st.map), 3), OSW_BOLD, 44, Vector2.new(876, 728), { width = 900 })
	text(s, spaced("DIFICULTAD: " .. Difficulties.get(st.difficulty).Upper, 3), OSW_BOLD, 44,
		Vector2.new(876, 790), { width = 900 })
	rule(s, 120, 872, 1680)
	backButton(s, "main", true)
	text(s, spaced(st.started and "EMPEZANDO…" or "ESPERANDO AL ANFITRIÓN", 2), ANTON, 66, Vector2.new(1800, 940),
		{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 900 })
end

-- Actualizaciones de la sala (cada pocos segundos) -------------------------
local lastKey
roomUpdate.OnClientEvent:Connect(function(st)
	roomState = st
	if not st then
		lastKey = nil
		if current == screens.create or current == screens.joined then
			setStatus("La sala se cerró")
			show("main")
		end
		return
	end
	local key = table.concat({ st.id, st.name or "", table.concat(st.ids or {}, ","), tostring(st.public), st.code or "", st.map, st.difficulty or "", table.concat(st.names, ","), st.hostIndex, st.youIndex, tostring(st.started) }, "|")
	if key == lastKey then
		return
	end
	lastKey = key
	if st.isHost and current == screens.joined then
		show("create") -- el anfitrión se fue y ahora la sala es tuya
	elseif not st.isHost and current == screens.create then
		show("joined")
	elseif current == screens.create then
		builders.create()
	elseif current == screens.joined then
		builders.joined()
	end
end)

-- Entrada: el logo aparece con desvanecido ---------------------------------
local slow = TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(logoScale, slow, { Scale = 1 }):Play()
for _, l in layers do
	TweenService:Create(l.label, slow, { TextTransparency = l.target }):Play()
end

local prompt = text(root, spaced(TOUCH and "TOCA LA PANTALLA" or "PRESIONA CUALQUIER TECLA", 4), OSW_BOLD, 38, Vector2.new(120, 947),
	{ color = DARK, width = 1100, transparency = 1 })
local titleRule = rule(root, 120, 886, 1680, false, 4)
titleRule.BackgroundTransparency = 1
task.delay(1.2, function()
	local info = TweenInfo.new(1.2)
	for _, o in { cornerL, cornerR, version } do
		TweenService:Create(o, info, { TextTransparency = 0 }):Play()
	end
	TweenService:Create(prompt, info, { TextTransparency = 0.1 }):Play()
	TweenService:Create(titleRule, info, { BackgroundTransparency = 0 }):Play()
end)

local ready, pressed = false, false
task.delay(2, function()
	ready = true
end)
task.spawn(function()
	while not pressed do
		if ready then
			fade(prompt, 0.8, { TextTransparency = 0.7 })
			task.wait(0.8)
			if pressed then
				break
			end
			fade(prompt, 0.8, { TextTransparency = 0.1 })
		end
		task.wait(0.8)
	end
end)

local conn
conn = UserInputService.InputBegan:Connect(function(input)
	local t = input.UserInputType
	if pressed or not ready then
		return
	end
	if t ~= Enum.UserInputType.Keyboard and t ~= Enum.UserInputType.MouseButton1
		and t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.Gamepad1 then
		return
	end
	pressed = true
	conn:Disconnect()
	fade(prompt, 0.3, { TextTransparency = 1 })
	fade(titleRule, 0.3, { BackgroundTransparency = 1 })
	for _, l in layers do
		if l.kind == "shadow" then
			fade(l.label, 0.4, { TextTransparency = 1 })
		end
	end
	-- el logo sube y se encoge a la cabecera
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
	TweenService:Create(logo, info, { Position = UDim2.fromOffset(120, 292) }):Play()
	TweenService:Create(logoScale, info, { Scale = 0.652 }):Play()
	task.delay(0.5, function()
		show("main")
	end)
end)
