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

-- Idioma: el texto del menú está en inglés; quien tiene Roblox en español lo ve traducido (shared/Lang)
local Lang = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Lang"))
Lang.watch()

-- Diseño v2: fondo casi negro, texto crema y el rojo como acento (el negro queda para el texto sobre las casillas rojas)
local RED = Color3.fromRGB(200, 22, 28)
local BLACK = Color3.new(0, 0, 0)
local INK = Color3.fromRGB(240, 232, 220) -- el crema de los textos
local DIM = Color3.fromRGB(122, 118, 112) -- textos apagados
local LINE = Color3.fromRGB(52, 48, 46) -- líneas finas y bordes
local PANEL = Color3.fromRGB(20, 19, 19) -- fondo de tarjetas y casillas
local BGCOL = Color3.fromRGB(9, 9, 9)
local OSW_BOLD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
-- Anton no existe en Roblox: el titular usa Oswald en negrita, lo más parecido
local ANTON = OSW_BOLD
local OSW = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Regular)
local OSW_LIGHT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Light)

local MAPS = {
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
local Progress = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Progress"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cosmetics"))
local profileRequest = ReplicatedStorage:WaitForChild("ProfileRequest")
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

-- Mayúsculas (con tilde en español) del texto ya traducido
local function upperEs(str)
	return Lang.upper(Lang.tr(str))
end

local function spaced(str, gap)
	str = Lang.tr(str) -- se traduce antes de separar las letras
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
bg.BackgroundColor3 = BGCOL
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
		Text = Lang.tr(str),
		FontFace = font,
		TextSize = math.min(size, 100),
		TextColor3 = props.color or INK,
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
			BackgroundColor3 = (h and h >= 4) and RED or LINE, BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h or 2),
		}, parent)
	end
	local f = make("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 2),
	}, parent)
	for dx = 0, w - 8, 14 do
		make("Frame", { BackgroundColor3 = LINE, BorderSizePixel = 0,
			Position = UDim2.fromOffset(dx, 0), Size = UDim2.fromOffset(8, 2) }, f)
	end
	return f
end

local function outline(parent, x, y, w, h, thick)
	local f = make("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
	}, parent)
	make("UIStroke", { Color = LINE, Thickness = thick or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
	return f
end

local function fade(obj, t, goal)
	TweenService:Create(obj, TweenInfo.new(t), goal):Play()
end

-- Sonidos de la interfaz (clic al pulsar y un tic suave al pasar el ratón). Mismos sonidos que usa la partida para sus ajustes.
local SoundService = game:GetService("SoundService")
local UI_SOUNDS = {
	Click = { "rbxassetid://110948579458469", 0.5, 1 },
	Hover = { "rbxassetid://106984966606682", 0.25, 1.6 },
}
local lastUiSound = {}
local function uiSound(kind)
	local now = os.clock()
	if now - (lastUiSound[kind] or -math.huge) < 0.06 then
		return
	end
	lastUiSound[kind] = now
	local def = UI_SOUNDS[kind]
	local sound = Instance.new("Sound")
	sound.SoundId = def[1]
	sound.Volume = def[2]
	sound.PlaybackSpeed = def[3]
	sound.Parent = SoundService
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 3)
end

local function button(parent, x, y, w, h, onClick)
	local b = make("TextButton", {
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = 5,
	}, parent)
	b.Activated:Connect(function(...)
		uiSound("Click")
		onClick(...)
	end)
	if not TOUCH then
		b.MouseEnter:Connect(function()
			uiSound("Hover")
		end)
	end
	return b
end

-- Fondo y adornos --------------------------------------------------------
-- Resplandor rojo (círculos concéntricos casi transparentes: sumados hacen un degradado radial)
local function glow(parent, cx, cy, radius, color, steps, alpha)
	for i = 1, steps do
		local r = radius * (1 - (i - 1) / steps * 0.9)
		local f = make("Frame", {
			BackgroundColor3 = color, BackgroundTransparency = alpha, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(r * 2, r * 2),
		}, parent)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
	end
end

-- Mancha de sangre: un charco con varios círculos y gotas sueltas alrededor
local function splat(parent, cx, cy, size, seed)
	local random = Random.new(seed)
	local color = Color3.fromRGB(58, 4, 6)
	local function blob(x, y, d, transparency)
		local f = make("Frame", {
			BackgroundColor3 = color, BackgroundTransparency = transparency, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(d, d * (0.7 + random:NextNumber() * 0.5)),
		}, parent)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
		f.Rotation = random:NextInteger(0, 180)
	end
	blob(cx, cy, size, 0.25)
	for _ = 1, 7 do
		local angle = random:NextNumber() * math.pi * 2
		local dist = size * (0.35 + random:NextNumber() * 0.35)
		blob(cx + math.cos(angle) * dist, cy + math.sin(angle) * dist, size * (0.18 + random:NextNumber() * 0.28), 0.3)
	end
	for _ = 1, 9 do
		local angle = random:NextNumber() * math.pi * 2
		local dist = size * (0.75 + random:NextNumber() * 0.6)
		blob(cx + math.cos(angle) * dist, cy + math.sin(angle) * dist, size * (0.03 + random:NextNumber() * 0.07), 0.35)
	end
end

local decor = make("Frame", { Name = "Adornos", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, root)
glow(decor, 1500, 560, 760, Color3.fromRGB(110, 4, 6), 10, 0.955)
glow(decor, 360, 1020, 520, Color3.fromRGB(70, 2, 4), 7, 0.965)
splat(decor, 1560, 360, 170, 11)
splat(decor, 1030, 800, 120, 23)
splat(decor, 1700, 920, 90, 5)

-- Sangre que gotea bajo una línea roja: lista de { x, largo }
local function drips(parent, x, y, list)
	for _, d in list do
		local drop = make("Frame", {
			BackgroundColor3 = RED, BorderSizePixel = 0, Position = UDim2.fromOffset(x + d[1], y), Size = UDim2.fromOffset(d[3] or 12, d[2]),
		}, parent)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, drop)
	end
end

-- Elementos fijos (todas las pantallas): "DAY 01" arriba a la izquierda y "SURVIVE" en rojo arriba a la derecha
text(root, spaced("DAY 01", 4), OSW_BOLD, 30, Vector2.new(120, 130), { width = 500, color = INK })
text(root, spaced("SURVIVE", 5), OSW_BOLD, 30, Vector2.new(1800, 130), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, color = RED, width = 700 })

-- Pantallas --------------------------------------------------------------
local screens = {}
local current
local function newScreen(name)
	screens[name] = make("CanvasGroup", {
		Name = "Pantalla_" .. name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Visible = false, ZIndex = 2,
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
end

local function clear(s)
	for _, c in s:GetChildren() do
		c:Destroy()
	end
end

-- Cabecera de las pantallas interiores: el título en grande y una línea roja con gotas de sangre
local function header(s, title)
	text(s, title, ANTON, 112, Vector2.new(120, 232), { width = 1500, color = INK })
	rule(s, 120, 311, 1680, false, 6)
	drips(s, 120, 317, { { 62, 38 }, { 330, 20, 10 }, { 560, 56 } })
end

local function backButton(s, target, leaveRoom)
	text(s, "←", OSW, 70, Vector2.new(130, 950), { width = 70, color = INK })
	text(s, "BACK", ANTON, 66, Vector2.new(212, 945), { width = 400, color = INK })
	button(s, 120, 905, 320, 85, function()
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
		{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 200, color = DIM })
end

-- 1) Principal -----------------------------------------------------------
local main = newScreen("main")
local DEFAULT_STATUS = spaced("1–4 PLAYERS · CO-OP", 3)
local status = text(main, DEFAULT_STATUS, OSW_BOLD, 30, Vector2.new(120, 973), { width = 1400, color = INK })
local function setStatus(msg)
	status.Text = msg and spaced(string.upper(msg), 3) or DEFAULT_STATUS
end
smallVersion(main, 1800, 973)
rule(main, 120, 925, 1680)

-- El logo: rojo con un resplandor y la sangre que gotea de la línea de abajo
local logoLabel = text(main, "RHOMULUS", ANTON, 330, Vector2.new(116, 290), { width = 1500, color = RED })
make("UIStroke", { Color = RED, Thickness = 4, Transparency = 0.9, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, logoLabel)
make("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Position = UDim2.fromOffset(120, 416), Size = UDim2.fromOffset(960, 10) }, main)
drips(main, 120, 426, { { 70, 66, 12 }, { 250, 36, 10 }, { 480, 116, 14 }, { 540, 46, 10 }, { 760, 82, 12 }, { 912, 34, 10 } })

-- Perfil del jugador (arriba a la derecha): su avatar, su nombre y su nivel con la barra de lo que le falta para el siguiente.
-- El nivel lo guarda la partida; aquí solo se muestra. Sin datos (Studio sin publicar) se ve el avatar y el nombre sin nivel.
local AVATAR_X, AVATAR_Y = 1700, 292
local profileRing = make("Frame", {
	BackgroundColor3 = RED, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(AVATAR_X, AVATAR_Y), Size = UDim2.fromOffset(190, 190),
}, main)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, profileRing)
local profileAvatar = make("Frame", {
	BackgroundColor3 = PANEL, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(AVATAR_X - 6, AVATAR_Y + 4), Size = UDim2.fromOffset(168, 168), ClipsDescendants = true,
}, main)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, profileAvatar)
local profileImage = make("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop }, profileAvatar)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, profileImage)
task.spawn(function()
	local ok, content = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok and content then
		profileImage.Image = content
	end
end)
local TEXT_RIGHT = 1575 -- los textos terminan a la izquierda del avatar
local profileName = text(main, upperEs(player.DisplayName), ANTON, 58, Vector2.new(TEXT_RIGHT, 246),
	{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 640, color = INK })
local levelText = text(main, "", OSW_BOLD, 28, Vector2.new(TEXT_RIGHT, 313), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 500, color = RED })
local levelBack = make("Frame", {
	BackgroundColor3 = Color3.fromRGB(40, 38, 36), BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromOffset(TEXT_RIGHT, 343), Size = UDim2.fromOffset(420, 8),
}, main)
local levelFill = make("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, levelBack)
local levelXp = text(main, "", OSW_BOLD, 22, Vector2.new(TEXT_RIGHT, 373), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 500, color = DIM })
local function refreshLevel()
	local total = player:GetAttribute("ProgXP")
	local show = typeof(total) == "number"
	levelText.Visible, levelBack.Visible, levelXp.Visible = show, show, show
	if not show then
		return
	end
	local level, into, need = Progress.fromTotal(total)
	levelText.Text = spaced(`LEVEL {level}`, 4)
	levelFill.Size = UDim2.fromScale(need > 0 and into / need or 1, 1)
	levelXp.Text = need > 0 and spaced(`{into} / {need} XP TO LEVEL {level + 1}`, 2) or spaced("MAX LEVEL", 2)
end
player:GetAttributeChangedSignal("ProgXP"):Connect(refreshLevel)
refreshLevel()

-- Título y marco que lleva puestos (se eligen en PROFILE), y las Rhoms que tiene. Sin datos guardados no se ven.
local profileTitle = text(main, "", OSW_BOLD, 26, Vector2.new(TEXT_RIGHT, 190), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 640, color = RED })
local rhomsText = text(main, "", OSW_BOLD, 30, Vector2.new(TEXT_RIGHT, 436), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 500, color = INK })
local profileLink = text(main, spaced("PROFILE", 4) .. " →", ANTON, 40, Vector2.new(TEXT_RIGHT, 492), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 500, color = INK })
local function refreshLook()
	local frame = Cosmetics.get("frame", player:GetAttribute("FrameId"))
	local title = Cosmetics.get("title", player:GetAttribute("TitleId"))
	profileRing.BackgroundColor3 = frame and frame.Color or RED
	profileTitle.Text = title and spaced(upperEs(title.Name), 3) or ""
	local coins = player:GetAttribute("Rhoms")
	rhomsText.Visible = typeof(coins) == "number"
	rhomsText.Text = typeof(coins) == "number" and spaced(`{coins} RHOMS`, 3) or ""
end
for _, name in { "FrameId", "TitleId", "Rhoms" } do
	player:GetAttributeChangedSignal(name):Connect(refreshLook)
end
refreshLook()
button(main, TEXT_RIGHT - 340, 462, 340, 60, function()
	setStatus(nil)
	show("profile")
end).Name = "Perfil"
text(main, spaced("ARMORY", 4) .. " →", ANTON, 40, Vector2.new(TEXT_RIGHT, 552), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 500, color = INK })
button(main, TEXT_RIGHT - 340, 522, 340, 60, function()
	setStatus(nil)
	show("armory")
end).Name = "Armeria"

-- Las tres opciones: numeradas, y la elegida (la de debajo del ratón) se rellena de rojo con una flecha
local items = {
	{ "PLAY", function()
		setStatus(nil)
		show("list")
	end },
	{ "CREATE GAME", function()
		setStatus(nil)
		show("setup")
	end },
	{ "HOW TO PLAY", function()
		setStatus(nil)
		show("help")
	end },
}
local rows = {}
local selected = 1
local function paintRows()
	for i, r in rows do
		local on = i == selected
		fade(r.fill, 0.12, { BackgroundTransparency = on and 0 or 1 })
		r.title.TextColor3 = on and BLACK or INK
		r.number.TextColor3 = on and BLACK or RED
		r.arrow.TextTransparency = on and 0 or 1
		r.line.BackgroundTransparency = on and 1 or 0
	end
end
for i, item in items do
	local y = 560 + 106 * (i - 1)
	local fill = make("Frame", { BackgroundColor3 = RED, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(120, y), Size = UDim2.fromOffset(880, 106) }, main)
	local number = text(main, spaced(string.format("%02d", i), 3), OSW_BOLD, 28, Vector2.new(148, y + 53), { width = 80, color = RED })
	local title = text(main, item[1], ANTON, 96, Vector2.new(206, y + 53), { width = 700, color = INK })
	local arrow = text(main, "→", OSW, 70, Vector2.new(970, y + 53), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 100, color = BLACK, transparency = 1 })
	local line = rule(main, 120, y + 105, 880)
	rows[i] = { fill = fill, title = title, number = number, arrow = arrow, line = line }
	local b = button(main, 120, y, 880, 106, item[2])
	b.Name = "Item" .. i
	b.MouseEnter:Connect(function()
		selected = i
		paintRows()
	end)
end
paintRows()

-- 4) Cómo jugar ------------------------------------------------------------
-- Cuatro pestañas: objetivo, controles, consejos y dificultades. Los textos de las dificultades salen de shared/Difficulties.
local help = newScreen("help")

-- Párrafo con salto de línea automático (la esquina superior izquierda va en `pos`)
local function paragraph(parent, str, font, size, pos, width, height, props)
	props = props or {}
	return make("TextLabel", {
		BackgroundTransparency = 1, Text = str, FontFace = font, TextSize = size, TextColor3 = props.color or INK,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = props.lineHeight or 1.1, Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(width, height),
	}, parent)
end

-- Casilla de tecla: una tecla crema con sombra (roja en la columna de objetos). Devuelve su ancho.
local function keycap(parent, x, y, label, red)
	local w = math.max(50, 19 * (utf8.len(label) or #label) + 30)
	make("Frame", { BackgroundColor3 = red and Color3.fromRGB(110, 8, 10) or Color3.fromRGB(150, 142, 130), BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y + 5), Size = UDim2.fromOffset(w, 52) }, parent)
	make("Frame", { BackgroundColor3 = red and RED or INK, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 52) }, parent)
	text(parent, label, ANTON, 36, Vector2.new(x + w / 2, y + 27),
		{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = w, color = red and INK or Color3.fromRGB(26, 24, 22) })
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

local HELP_TABS = { { HelpContent.Tabs[1], 174 }, { HelpContent.Tabs[2], 190 }, { HelpContent.Tabs[3], 184 }, { HelpContent.Tabs[4], 218 } }

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
		text(c, spaced(group[1], 5), OSW_BOLD, 24, Vector2.new(x, 361), { width = 520, color = RED })
		rule(c, x, 390, 520)
		for i, row in group[2] do
			local y = 406 + 67 * (i - 1)
			keycap(c, x, y, row[1], col == 3)
			text(c, row[2], OSW_BOLD, 32, Vector2.new(x + 246, y + 27), { width = 300 })
		end
	end
	text(c, HelpContent.ControlsNote, OSW, 24, Vector2.new(120, 840), { width = 1300, color = DIM })
	text(c, spaced(HelpContent.ControlsSide, 4), OSW_BOLD, 20, Vector2.new(1800, 840),
		{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 800, color = DIM })
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
			local box = make("Frame", { BackgroundColor3 = RED, BackgroundTransparency = (k <= i) and 0 or 1, BorderSizePixel = 0,
				Position = UDim2.fromOffset(194 + (k - 1) * 40, y + 84), Size = UDim2.fromOffset(32, 14) }, c)
			make("UIStroke", { Color = RED, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
		end
		paragraph(c, d.Description, OSW, 30, Vector2.new(600, y + 6), 740, 100)
		text(c, "HEALTH ×" .. ratio(d.Health) .. "    DAMAGE ×" .. ratio(d.Damage), OSW_BOLD, 30, Vector2.new(1390, y + 32), { width = 430 })
		text(c, "PRICES ×" .. ratio(d.Cost) .. "    CANS ×" .. ratio(d.Reward), OSW_BOLD, 30, Vector2.new(1390, y + 74), { width = 430 })
		if i < #Difficulties.Order then
			rule(c, 120, y + 118, 1680)
		end
	end
end

builders.help = function()
	local s = help
	clear(s)
	header(s, "HOW TO PLAY")
	local holder = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, s)
	local tabs = {}
	local function paintTabs(active)
		for i, t in tabs do
			t.box.BackgroundTransparency = (i == active) and 0 or 1
			t.label.TextColor3 = (i == active) and BLACK or INK
			t.box.UIStroke.Color = (i == active) and RED or LINE
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
	local x = 1004
	local tabY, tabH = TOUCH and 196 or 204, TOUCH and 84 or 66 -- en celular las pestañas son más altas para tocarlas
	for i, tab in HELP_TABS do
		local w = tab[2]
		local box = make("Frame", { BackgroundColor3 = RED, Position = UDim2.fromOffset(x, tabY), Size = UDim2.fromOffset(w, tabH), BorderSizePixel = 0 }, s)
		make("UIStroke", { Color = LINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
		local label = text(s, tab[1], ANTON, 40, Vector2.new(x + w / 2, tabY + tabH / 2),
			{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = w })
		button(s, x, tabY, w, tabH, function()
			showTab(i)
		end)
		tabs[i] = { box = box, label = label }
		x += w + 10
	end
	rule(s, 120, 889, 1680)
	backButton(s, "main")
	smallVersion(s, 1800, 960)
	showTab(1)
end

-- 5) Perfil: marco del avatar y título --------------------------------------------------------------------------------------------
-- Se desbloquean con el nivel (shared/Cosmetics). Tocar uno que ya se tiene lo pone; el servidor vuelve a comprobar el nivel.
local profileScreen = newScreen("profile")
local profileConns = {} -- las conexiones de la pantalla actual (se sueltan al volver a armarla)
builders.profile = function()
	local s = profileScreen
	for _, c in profileConns do
		c:Disconnect()
	end
	table.clear(profileConns)
	clear(s)
	header(s, "PROFILE")
	local level = player:GetAttribute("ProgLevel") or 1
	local note = text(s, "", OSW_BOLD, 28, Vector2.new(1800, 960), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 900, color = RED })
	local function equip(kind, id)
		task.spawn(function()
			local okCall, done, why = pcall(function()
				return profileRequest:InvokeServer("equip", kind, id)
			end)
			note.Text = (okCall and done) and "" or spaced(string.upper((okCall and why) or "Couldn't connect. Try again"), 2)
		end)
	end

	text(s, spaced("FRAMES", 5), OSW_BOLD, 26, Vector2.new(120, 366), { width = 600, color = RED })
	rule(s, 120, 392, 780)
	local frameParts = {}
	for i, f in Cosmetics.Frames do
		local col, row = (i - 1) % 4, (i - 1) // 4
		local cx, cy = 195 + 195 * col, 490 + 235 * row
		local ring = make("Frame", { BackgroundColor3 = f.Color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(130, 130) }, s)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
		local hole = make("Frame", { BackgroundColor3 = PANEL, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(106, 106) }, s)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, hole)
		local label = text(s, "", OSW_BOLD, 24, Vector2.new(cx, cy + 92), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 180 })
		local locked = level < f.Level
		label.Text = locked and spaced(`LEVEL {f.Level}`, 2) or spaced(upperEs(f.Name), 2)
		label.TextColor3 = locked and DIM or INK
		ring.BackgroundTransparency = locked and 0.7 or 0
		frameParts[f.Id] = hole
		button(s, cx - 90, cy - 70, 180, 190, function()
			equip("frame", f.Id)
		end).Name = "Marco_" .. f.Id
	end

	text(s, spaced("TITLES", 5), OSW_BOLD, 26, Vector2.new(1000, 366), { width = 600, color = RED })
	rule(s, 1000, 392, 800)
	local titleRows = {}
	for i, t in Cosmetics.Titles do
		local y = 438 + 50 * (i - 1)
		local locked = level < t.Level
		local label = text(s, spaced(upperEs(t.Name), 2), ANTON, 38, Vector2.new(1020, y), { width = 560, color = locked and DIM or INK })
		local state = text(s, locked and spaced(`LEVEL {t.Level}`, 2) or "", OSW_BOLD, 24, Vector2.new(1800, y),
			{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 220, color = DIM })
		titleRows[t.Id] = { label = label, state = state, locked = locked }
		button(s, 1000, y - 24, 800, 48, function()
			equip("title", t.Id)
		end).Name = "Titulo_" .. t.Id
	end

	-- Lo que lleva puesto: el marco con un punto central rojo y el título con ✔
	local function paintLook()
		local frameId = player:GetAttribute("FrameId")
		local titleId = player:GetAttribute("TitleId")
		for id, hole in frameParts do
			hole.BackgroundColor3 = id == frameId and RED or PANEL
		end
		for id, r in titleRows do
			if not r.locked then
				r.state.Text = id == titleId and spaced("EQUIPPED", 2) or ""
				r.state.TextColor3 = RED
				r.label.TextColor3 = id == titleId and RED or INK
			end
		end
	end
	paintLook()
	for _, name in { "FrameId", "TitleId" } do
		table.insert(profileConns, player:GetAttributeChangedSignal(name):Connect(paintLook))
	end

	local coins = player:GetAttribute("Rhoms")
	if typeof(coins) == "number" then
		text(s, spaced(`{coins} RHOMS`, 3), ANTON, 44, Vector2.new(1800, 205), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 600, color = INK })
	end
	text(s, spaced(`LEVEL {level}`, 3), OSW_BOLD, 30, Vector2.new(1800, 262), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 600, color = RED })
	backButton(s, "main")
	smallVersion(s, 1800, 1010)
end

-- 6) Armería: las armas cuerpo a cuerpo --------------------------------------------------------------------------------------------
-- El cuchillo es el básico y las demás se compran con Rhoms; todas hacen lo mismo en la partida, solo cambia cómo se ven y suenan
-- (shared/Cosmetics). Se elige una tarjeta y el panel de la derecha la muestra en 3D con su botón: comprar (el servidor cobra y
-- comprueba), poner o ya puesta. Los modelos son los mismos de la partida (Shared.MeleeData + Shared.WeaponModel) dibujados en un ViewportFrame.
local WeaponModel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponModel"))
local meleeData = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MeleeData")
local MELEE_TILT = math.rad(-55) -- la cabeza del arma queda arriba a la derecha

-- Dibuja el modelo de la skin en un visor del tamaño dado. Devuelve el visor, `sway(t)` (lo hace girar despacio) y el largo del arma.
local function weaponView(parent, x, y, w, h, skin)
	local view = make("ViewportFrame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		Ambient = Color3.fromRGB(150, 146, 140), LightColor = Color3.fromRGB(255, 244, 228), LightDirection = Vector3.new(-0.5, -0.8, -0.6),
	}, parent)
	local module = meleeData:FindFirstChild("Melee" .. skin.Id)
	if not module then
		return view, function() end, 0
	end
	local data = require(module)
	local model = WeaponModel.build(data, 1)
	model.Parent = view
	local length = data.bounds.max.Y - data.bounds.min.Y
	local fov = 25
	local aspect = w / h
	local dist = math.max(length * 0.9 / aspect, length * 0.68) / (2 * math.tan(math.rad(fov / 2))) * 1.22
	local camera = make("Camera", { FieldOfView = fov, CFrame = CFrame.lookAt(Vector3.new(0, 0, dist), Vector3.zero) }, view)
	view.CurrentCamera = camera
	local function sway(t)
		model:PivotTo(CFrame.Angles(0, math.sin(t * 0.9) * 0.45, 0) * CFrame.Angles(0, 0, MELEE_TILT))
	end
	sway(0)
	return view, sway, length
end

local armoryScreen = newScreen("armory")
local armoryConns = {}
builders.armory = function()
	local s = armoryScreen
	for _, c in armoryConns do
		c:Disconnect()
	end
	table.clear(armoryConns)
	clear(s)
	header(s, "ARMORY")
	local note = text(s, "", OSW_BOLD, 28, Vector2.new(1800, 960), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 900, color = RED })
	local coinsLabel = text(s, "", ANTON, 44, Vector2.new(1800, 205), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 600, color = INK })
	local cards = {}
	local swayers = {}
	local selected = Cosmetics.validMelee(player:GetAttribute("MeleeOwned"), player:GetAttribute("MeleeSkin"))

	local function ownedNow(id)
		return Cosmetics.ownsMelee(player:GetAttribute("MeleeOwned"), id)
	end
	local function equippedNow()
		return Cosmetics.validMelee(player:GetAttribute("MeleeOwned"), player:GetAttribute("MeleeSkin"))
	end

	-- Panel de detalle (derecha)
	local PX, PY, PW, PH = 1220, 360, 580, 516
	local detail = make("Frame", { BackgroundColor3 = PANEL, BorderSizePixel = 0, Position = UDim2.fromOffset(PX, PY), Size = UDim2.fromOffset(PW, PH) }, s)
	make("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 5) }, detail)
	local dEyebrow = text(detail, "", OSW_BOLD, 22, Vector2.new(35, 38), { width = 510, color = DIM })
	local dName = text(detail, "", ANTON, 76, Vector2.new(35, 94), { width = 510, color = INK })
	local dDesc = text(detail, "", OSW, 26, Vector2.new(35, 158), { width = 510, color = DIM })
	local dView, dSway
	local dRarity = text(detail, "", OSW_BOLD, 22, Vector2.new(35, 368), { width = 510 })
	text(detail, "ALL MELEE WEAPONS HIT THE SAME. ONLY LOOK AND SOUND CHANGE.", OSW, 18, Vector2.new(35, 408), { width = 510, color = DIM })
	local action = make("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Position = UDim2.fromOffset(35, 440), Size = UDim2.fromOffset(510, 64) }, detail)
	local actionLabel = text(action, "", ANTON, 38, Vector2.new(255, 32), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 500, color = BLACK })

	local function showDetail()
		local skin = Cosmetics.melee(selected)
		if dView then
			dView:Destroy()
		end
		local length
		dView, dSway, length = weaponView(detail, 35, 190, 510, 170, skin)
		local number = string.format("%02d", table.find(Cosmetics.MeleeSkins, skin) or 0)
		dEyebrow.Text = spaced(`{Lang.tr("NO.")} {number} · {string.format("%.1f", length)} STUDS`, 2)
		dName.Text = upperEs(skin.Name)
		dDesc.Text = Lang.tr(skin.Desc or "")
		local rarity = Cosmetics.Rarities[skin.Rarity]
		dRarity.Text = spaced(rarity.Text, 3)
		dRarity.TextColor3 = rarity.Color
	end

	local function paint()
		local coins = player:GetAttribute("Rhoms")
		coinsLabel.Text = typeof(coins) == "number" and spaced(`{coins} RHOMS`, 3) or ""
		local equipped = equippedNow()
		for id, card in cards do
			local skin = card.skin
			local owned = ownedNow(id)
			local isOn = id == equipped
			local isSel = id == selected
			card.frame.BackgroundColor3 = isSel and Color3.fromRGB(40, 11, 13) or PANEL
			card.stroke.Thickness = isSel and 4 or 2
			card.stroke.Color = isSel and RED or LINE
			card.state.TextColor3 = isOn and RED or INK
			if isOn then
				card.state.Text = spaced("EQUIPPED", 2)
			elseif owned then
				card.state.Text = spaced("OWNED", 2)
			elseif skin.Price <= 0 then
				card.state.Text = spaced("FREE", 2)
			else
				card.state.Text = spaced(`{skin.Price} RHOMS`, 1)
				card.state.TextColor3 = (typeof(coins) == "number" and coins >= skin.Price) and Color3.fromRGB(255, 196, 60) or DIM
			end
		end
		local skin = Cosmetics.melee(selected)
		if selected == equipped then
			actionLabel.Text = spaced("EQUIPPED", 3)
			action.BackgroundColor3 = LINE
		elseif ownedNow(selected) then
			actionLabel.Text = spaced("EQUIP", 3)
			action.BackgroundColor3 = RED
		else
			actionLabel.Text = spaced(`{Lang.tr("BUY")} · {skin.Price} RHOMS`, 2)
			action.BackgroundColor3 = RED
		end
	end

	local CW, CH, GAP = 520, 160, 18
	for i, skin in Cosmetics.MeleeSkins do
		local col, row = (i - 1) % 2, (i - 1) // 2
		local x, y = 120 + (CW + 20) * col, 360 + (CH + GAP) * row
		local frame = make("Frame", { BackgroundColor3 = PANEL, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(CW, CH), ClipsDescendants = true }, s)
		local stroke = make("UIStroke", { Color = LINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
		local _, sway = weaponView(frame, 0, 0, CW, CH - 30, skin)
		table.insert(swayers, sway)
		local tag = make("TextLabel", {
			BackgroundColor3 = INK, BorderSizePixel = 0, Position = UDim2.fromOffset(14, CH - 46), Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X,
			Text = `{string.format("%02d", i)} · {upperEs(skin.Name)}`, FontFace = OSW_BOLD, TextSize = 22, TextColor3 = BLACK,
		}, frame)
		make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, tag)
		local state = text(frame, "", OSW_BOLD, 28, Vector2.new(CW - 16, CH - 30), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 200, color = INK })
		cards[skin.Id] = { skin = skin, frame = frame, stroke = stroke, state = state }
		button(s, x, y, CW, CH, function()
			selected = skin.Id
			showDetail()
			paint()
		end).Name = "Skin_" .. skin.Id
	end

	button(s, PX + 35, PY + 440, 510, 64, function()
		if selected == equippedNow() then
			return
		end
		local id = selected
		task.spawn(function()
			local act = ownedNow(id) and "equipSkin" or "buySkin"
			local okCall, done, why = pcall(function()
				return profileRequest:InvokeServer(act, id)
			end)
			note.Text = (okCall and done) and "" or spaced(string.upper((okCall and why) or "Couldn't connect. Try again"), 2)
		end)
	end).Name = "SkinAction"

	showDetail()
	paint()
	for _, name in { "Rhoms", "MeleeOwned", "MeleeSkin" } do
		table.insert(armoryConns, player:GetAttributeChangedSignal(name):Connect(paint))
	end
	-- las armas giran despacio mientras la pantalla se ve
	table.insert(armoryConns, RunService.RenderStepped:Connect(function()
		if not s.Visible then
			return
		end
		local t = os.clock()
		for i, sway in swayers do
			sway(t + i * 0.7)
		end
		dSway(t)
	end))
	backButton(s, "main")
	smallVersion(s, 1800, 1010)
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
		BackgroundColor3 = PANEL, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), ClipsDescendants = true,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, frame)
	make("UIStroke", { Color = RED, Thickness = math.max(3, size * 0.07), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
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
-- `lockedLevel` (opcional): función(id) que devuelve el nivel que falta para poder elegir esa casilla (nil = libre). Las bloqueadas salen
-- atenuadas con "LEVEL N" debajo y no se pueden pulsar.
local function choiceRow(s, x, y, h, items, textSize, isOn, onPick, lockedLevel)
	local boxes = {}
	local function paint()
		for _, b in boxes do
			local need = lockedLevel and lockedLevel(b.id)
			local on = not need and isOn(b.id)
			b.box.BackgroundTransparency = on and 0 or 1
			b.label.TextColor3 = on and BLACK or INK
			b.box.UIStroke.Color = on and RED or LINE
			b.label.TextTransparency = need and 0.6 or 0
			b.box.UIStroke.Transparency = need and 0.6 or 0
			b.label.Position = need and UDim2.fromOffset(b.cx, b.y + h * 0.36) or UDim2.fromOffset(b.cx, b.y + h / 2)
			b.lock.Visible = need ~= nil
			if need then
				b.lock.Text = spaced(`LEVEL {need}`, 1)
			end
		end
	end
	for _, item in items do
		local w = item[3]
		local box = make("Frame", { BackgroundColor3 = RED, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BorderSizePixel = 0 }, s)
		make("UIStroke", { Color = LINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
		local label = text(s, item[2], ANTON, textSize, Vector2.new(x + w / 2, y + h / 2),
			{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = w })
		local lock = text(s, "", OSW_BOLD, math.max(22, math.floor(h * 0.3)), Vector2.new(x + w / 2, y + h * 0.78),
			{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = w })
		lock.Visible = false
		local itemX = x
		button(s, x, y, w, h, function()
			if lockedLevel and lockedLevel(item[1]) then
				return -- bloqueada: el "LEVEL N" de la casilla dice cuándo se desbloquea
			end
			onPick(item[1])
			paint()
		end).Name = `Opcion{y}_{tostring(item[1])}`
		table.insert(boxes, { id = item[1], box = box, label = label, lock = lock, cx = itemX + w / 2, y = y })
		x += w + 12
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
		BackgroundColor3 = BGCOL, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x + size / 2, y + size * 0.71), Size = UDim2.fromOffset(size * 0.16, size * 0.26),
	}, parent)
end

local function difficultyName(id)
	return Difficulties.get(id).Upper
end

-- Nivel que le falta al jugador para elegir esa dificultad (nil = ya puede). Sin datos de nivel se dejan todas.
local function difficultyLock(id)
	local total = player:GetAttribute("ProgXP")
	if Progress.isUnlocked(id, total) then
		return nil
	end
	return Progress.requiredLevel(id)
end

-- 2) Lista de salas ----------------------------------------------------------------------------------------------------------
local list = newScreen("list")
local listToken = 0

-- Intenta entrar a una sala. Devuelve true, o false + motivo + si el código estaba mal.
local function tryJoin(item, pass)
	if busy then
		return false, "Hold on a moment"
	end
	busy = true
	local ok, r = pcall(function()
		return request:InvokeServer("join", item.id, pass)
	end)
	busy = false
	if not ok or not r then
		return false, "Couldn't connect. Try again"
	end
	if r.room then
		enterRoom(r.room)
		return true
	end
	return false, r.error or "Couldn't join", r.wrongCode
end

-- Ventana para escribir el código de una sala privada
local function askCode(s, item)
	local layer = make("Frame", { BackgroundColor3 = BLACK, BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), Active = true }, s)
	local panel = make("Frame", { BackgroundColor3 = PANEL, Position = UDim2.fromOffset(330, 200), Size = UDim2.fromOffset(1260, 700), BorderSizePixel = 0 }, layer)
	make("UIStroke", { Color = RED, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)
	lockIcon(panel, 60, 62, 70, INK)
	text(panel, "PRIVATE ROOM", ANTON, 84, Vector2.new(160, 100), { width = 900 })
	text(panel, spaced(upperEs(item.name), 2), OSW_BOLD, 34, Vector2.new(60, 190), { width = 1100 })
	rule(panel, 60, 222, 1140)

	local slots = {}
	for i = 1, 4 do
		local x = 150 + 270 * (i - 1)
		local slotBox = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(x, 260), Size = UDim2.fromOffset(220, 260) }, panel)
		make("UIStroke", { Color = LINE, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, slotBox)
		slots[i] = text(panel, "", ANTON, 250, Vector2.new(x + 110, 395), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 220 })
	end
	local caption = text(panel, spaced("ENTER THE 4-LETTER CODE", 3), OSW_BOLD, 32, Vector2.new(630, 568),
		{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 1100 })

	local enterBox = make("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Position = UDim2.fromOffset(760, 600), Size = UDim2.fromOffset(440, 80) }, panel)
	local enterLabel = text(panel, "JOIN", ANTON, 62, Vector2.new(980, 640),
		{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 440, color = BLACK, transparency = 0.5 })
	outline(panel, 60, 600, 440, 80, 4)
	text(panel, "CANCEL", ANTON, 62, Vector2.new(280, 640), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 440 })
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
		caption.Text = spaced("CHECKING…", 3)
		local ok, why, wrong = tryJoin(item, box.Text)
		if ok then
			layer:Destroy()
		else
			caption.Text = spaced(string.upper(why or "COULDN'T JOIN"), 2)
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
	header(s, "ROOMS")

	-- Crear una sala nueva (arriba a la derecha)
	make("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Position = UDim2.fromOffset(1340, 200), Size = UDim2.fromOffset(460, 72) }, s)
	text(s, "CREATE ROOM", ANTON, 54, Vector2.new(1570, 236), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 460, color = BLACK })
	button(s, 1340, 200, 460, 72, function()
		show("setup")
	end).Name = "CrearSala"

	rule(s, 120, 869, 1680)
	backButton(s, "main")
	smallVersion(s, 1800, 949)

	local scroller = make("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(120, 350), Size = UDim2.fromOffset(1680, 480),
		CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8,
		ScrollBarImageColor3 = RED, ScrollingDirection = Enum.ScrollingDirection.Y, ElasticBehavior = Enum.ElasticBehavior.Never,
	}, s)
	local emptyTitle = text(s, spaced("NO OPEN ROOMS", 3), ANTON, 64, Vector2.new(960, 560),
		{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 1500 })
	local emptyHint = text(s, spaced("CREATE YOUR OWN WITH THE BUTTON ABOVE", 3), OSW, 34, Vector2.new(960, 640),
		{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 1500, color = DIM })
	emptyTitle.Visible, emptyHint.Visible = false, false
	local note = text(s, "", OSW_BOLD, 28, Vector2.new(120, 842), { width = 1680, color = RED })

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
			local row = make("Frame", { BackgroundColor3 = PANEL, BorderSizePixel = 0, Position = UDim2.fromOffset(4, y + 4), Size = UDim2.fromOffset(1636, 100) }, scroller)
			row.Name = "Fila" .. i
			make("UIStroke", { Color = LINE, Thickness = 2, Transparency = alpha, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, row)
			local nameX = 36
			if not item.public then
				lockIcon(row, 36, 28, 46, INK)
				nameX = 106
			end
			text(row, upperEs(item.name), ANTON, 54, Vector2.new(nameX, 50), { width = 800, transparency = alpha })
			text(row, spaced(string.upper(mapName(item.map)), 4), OSW_BOLD, 22, Vector2.new(740, 32), { width = 480, color = RED, transparency = alpha })
			text(row, spaced(difficultyName(item.difficulty), 3), OSW_BOLD, 22, Vector2.new(740, 72), { width = 480, color = DIM, transparency = alpha })
			text(row, `{item.count}/{item.max}`, ANTON, 64, Vector2.new(1600, 40),
				{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 220, transparency = alpha })
			if full then
				text(row, spaced("FULL", 3), OSW_BOLD, 22, Vector2.new(1600, 84),
					{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 200, color = RED })
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
				uiSound("Click")
				if full then
					note.Text = spaced("THAT ROOM IS FULL", 3)
				elseif item.public then
					note.Text = ""
					local ok, why = tryJoin(item)
					if not ok then
						note.Text = spaced(string.upper(why or "COULDN'T JOIN"), 3)
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
				note.Text = spaced(string.upper(r.error), 3)
			end
			task.wait(3)
		end
	end)
end

-- 3) Nueva sala: pública o privada, mapa y dificultad ----------------------------------------------------------------------------
local setup = newScreen("setup")
local setupState = { public = true, map = "Morro", difficulty = Difficulties.Default, mutators = true }

-- Etiqueta roja de sección ("WHO CAN JOIN", "MAP"…)
local function tag(s, str, x, y)
	return text(s, spaced(str, 5), OSW_BOLD, 24, Vector2.new(x, y), { width = 900, color = RED })
end

builders.setup = function()
	local s = setup
	clear(s)
	header(s, "NEW ROOM")

	-- Vista previa: así se verá tu sala en la lista (se actualiza al cambiar las opciones)
	tag(s, "PREVIEW IN THE LIST", 1020, 356)
	local previewHolder = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(1020, 380), Size = UDim2.fromOffset(780, 260) }, s)
	local function drawPreview()
		for _, c in previewHolder:GetChildren() do
			c:Destroy()
		end
		local card = make("Frame", { BackgroundColor3 = PANEL, BorderSizePixel = 0, Size = UDim2.fromOffset(780, 174) }, previewHolder)
		make("UIStroke", { Color = LINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
		local nameX = 34
		if not setupState.public then
			lockIcon(card, 34, 36, 54, INK)
			nameX = 108
		end
		text(card, upperEs((player.DisplayName ~= "" and player.DisplayName or player.Name) .. "'s room"), ANTON, 60, Vector2.new(nameX, 68), { width = 560 })
		text(card, spaced(upperEs(mapName(setupState.map)), 5), OSW_BOLD, 22, Vector2.new(34, 130), { width = 520, color = RED })
		text(card, "1/4", ANTON, 78, Vector2.new(745, 70), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 200 })
		text(card, spaced(difficultyName(setupState.difficulty), 3), OSW_BOLD, 20, Vector2.new(745, 128),
			{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 330, color = DIM })
		text(previewHolder, setupState.public and "Anyone can join with a tap." or "Asks for a 4-letter code that we'll give you when you create the room.",
			OSW, 24, Vector2.new(2, 203), { width = 770, color = DIM })
	end
	drawPreview()

	tag(s, "WHO CAN JOIN", 120, 356)
	local visibilityText = text(s, "", OSW, 24, Vector2.new(120, 496), { width = 880, color = DIM })
	local function describeVisibility()
		visibilityText.Text = setupState.public and "Shows up in the list and anyone can join with a tap. No code needed."
			or "Shows up with a lock: only people with the 4-letter code we give you can join."
	end
	choiceRow(s, 120, 380, 88, { { true, "PUBLIC", 380 }, { false, "PRIVATE", 380 } }, 58, function(id)
		return setupState.public == id
	end, function(id)
		setupState.public = id
		describeVisibility()
		drawPreview()
	end)
	describeVisibility()

	tag(s, "MAP", 120, 550)
	choiceRow(s, 120, 574, 84, { { "Morro", "MORRO ESPERANZA", 520 } }, 52, function(id)
		return setupState.map == id
	end, function(id)
		setupState.map = id
		drawPreview()
	end)

	-- Los mutadores se encienden o apagan después, en la sala del anfitrión (aquí se crea con ellos activados)

	tag(s, "DIFFICULTY", 120, 698)
	local difficultyDesc = text(s, "", OSW_LIGHT, 24, Vector2.new(120, 830), { width = 1000, color = DIM })
	local function describeDifficulty()
		difficultyDesc.Text = Difficulties.get(setupState.difficulty).Description
	end
	local items = {}
	for _, id in Difficulties.Order do
		table.insert(items, { id, Difficulties[id].Upper, 190 })
	end
	choiceRow(s, 120, 722, 80, items, 38, function(id)
		return setupState.difficulty == id
	end, function(id)
		setupState.difficulty = id
		describeDifficulty()
		drawPreview()
	end, difficultyLock)
	describeDifficulty()

	rule(s, 120, 869, 1680)
	backButton(s, "list")
	local errorText = text(s, "", OSW_BOLD, 28, Vector2.new(1340, 948), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 900, color = RED })
	make("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Position = UDim2.fromOffset(1380, 896), Size = UDim2.fromOffset(420, 104) }, s)
	text(s, "CREATE", ANTON, 90, Vector2.new(1590, 948), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 420, color = BLACK })
	local createButton
	createButton = button(s, 1380, 896, 420, 104, function()
		if busy then
			return
		end
		busy = true
		errorText.Text = spaced("CREATING THE ROOM…", 3)
		local ok, r = pcall(function()
			return request:InvokeServer("create", { map = setupState.map, difficulty = setupState.difficulty, public = setupState.public, mutators = setupState.mutators })
		end)
		busy = false
		if ok and r and r.room then
			enterRoom(r.room)
		else
			errorText.Text = spaced(upperEs((ok and r and r.error) or "COULDN'T CREATE THE ROOM"), 3)
		end
	end)
	createButton.Name = "Crear"
end

-- Datos comunes de la sala: acceso (código o pública) y jugadores ----------------------------------------------------------------
local function codeText(s, st)
	if st.public then
		tag(s, "ACCESS", 120, 356)
		text(s, "PUBLIC", ANTON, 250, Vector2.new(126, 482), { width = 900, color = RED })
		text(s, "PUBLIC", ANTON, 250, Vector2.new(120, 476), { width = 900, color = INK })
		text(s, spaced("ANYONE CAN JOIN FROM THE LIST", 3), OSW_BOLD, 24, Vector2.new(120, 597), { width = 780 })
	else
		tag(s, "CODE", 120, 356)
		text(s, spaced(st.code or "", 0), ANTON, 290, Vector2.new(126, 482), { width = 780, color = RED })
		text(s, spaced(st.code or "", 0), ANTON, 290, Vector2.new(120, 476), { width = 780, color = INK })
		text(s, spaced("SHARE IT WITH YOUR GROUP", 3), OSW_BOLD, 24, Vector2.new(120, 597), { width = 780 })
	end
end

local function playerList(s, names, hostIdx, youIdx, ids)
	tag(s, `PLAYERS {#names}/4`, 900, 356)
	for i = 1, 4 do
		local y = 423 + 67 * (i - 1)
		text(s, string.format("%02d", i), OSW_BOLD, 32, Vector2.new(900, y), { width = 70, color = names[i] and RED or DIM })
		if names[i] then
			if ids and ids[i] then
				avatarCircle(s, 1000, y, 62, ids[i], true)
			end
			text(s, upperEs(names[i]), ANTON, 58, Vector2.new(1070, y), { width = 560 })
			rule(s, 900, y + 33, 900)
			if i == hostIdx then
				local tagBox = outline(s, 1640, y - 20, 160, 40, 2)
				tagBox.UIStroke.Color = RED
				text(s, spaced("HOST", 3), OSW_BOLD, 18, Vector2.new(1720, y),
					{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 160, color = RED })
			elseif i == youIdx then
				make("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Position = UDim2.fromOffset(1738, y - 21), Size = UDim2.fromOffset(62, 42) }, s)
				text(s, spaced("YOU", 2), OSW_BOLD, 24, Vector2.new(1769, y),
					{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 62, color = BLACK })
			end
		else
			-- hueco libre: círculo vacío
			local empty = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(1000, y), Size = UDim2.fromOffset(62, 62) }, s)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, empty)
			make("UIStroke", { Color = LINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, empty)
			text(s, spaced("WAITING…", 5), OSW_LIGHT, 28, Vector2.new(1064, y), { width = 600, color = DIM })
			rule(s, 900, y + 33, 900, true)
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
	header(s, upperEs(st.name or "YOUR ROOM"))
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
	choiceRow(s, 1348, 200, 70, { { true, "PUBLIC", 220 }, { false, "PRIVATE", 220 } }, 40, function(id)
		return st.public == id
	end, function(id)
		if st.public ~= id then
			st.public = id
			hostRequest("setPublic", id, true)
		end
	end)

	tag(s, "MUTATIONS", 1368, 703)
	choiceRow(s, 1368, 728, 80, { { true, "YES", 110 }, { false, "NO", 110 } }, 54, function(id)
		return st.mutators ~= false == id
	end, function(id)
		st.mutators = id
		hostRequest("setMutators", id)
	end)

	tag(s, "MAP", 900, 703)
	choiceRow(s, 900, 728, 80, { { "Morro", "MORRO ESPERANZA", 440 } }, 54, function(id)
		return st.map == id
	end, function(id)
		st.map = id
		hostRequest("setMap", id)
	end)

	-- Dificultad (izquierda, bajo el acceso): cuatro casillas y la descripción de la elegida
	tag(s, "DIFFICULTY", 120, 662)
	local diffH = TOUCH and 76 or 66 -- casillas más altas en celular
	local diffDesc = text(s, "", OSW_LIGHT, 24, Vector2.new(120, 686 + diffH + 8), { width = 700, color = DIM })
	diffDesc.AnchorPoint = Vector2.new(0, 0)
	diffDesc.Size = UDim2.fromOffset(700, 64)
	diffDesc.TextWrapped = true
	diffDesc.TextYAlignment = Enum.TextYAlignment.Top
	local function describeDifficulty()
		diffDesc.Text = Difficulties.get(st.difficulty).Description
	end
	local diffItems = {}
	for _, id in Difficulties.Order do
		table.insert(diffItems, { id, Difficulties[id].Upper, 165 })
	end
	choiceRow(s, 120, 686, diffH, diffItems, 34, function(id)
		return st.difficulty == id
	end, function(id)
		st.difficulty = id
		describeDifficulty()
		hostRequest("setDifficulty", id)
	end, difficultyLock)
	describeDifficulty()

	rule(s, 120, 869, 1680)
	backButton(s, "main", true)
	smallVersion(s, 1330, 949)
	make("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Position = UDim2.fromOffset(1380, 896), Size = UDim2.fromOffset(420, 104) }, s)
	text(s, spaced(st.started and "STARTING…" or "START", 0), ANTON, 90, Vector2.new(1590, 948),
		{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 420, color = BLACK })
	button(s, 1380, 896, 420, 104, function()
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
	header(s, upperEs(st.name or "ROOM"))
	codeText(s, st)
	playerList(s, st.names, st.hostIndex, st.youIndex, st.ids)
	-- Lo que eligió el anfitrión (solo se ve)
	tag(s, "DIFFICULTY", 120, 662)
	text(s, spaced(Difficulties.get(st.difficulty).Upper, 3), ANTON, 54, Vector2.new(120, 725), { width = 700 })
	text(s, Difficulties.get(st.difficulty).Description, OSW_LIGHT, 24, Vector2.new(120, 790), { width = 700, color = DIM })
	tag(s, "MAP", 900, 703)
	text(s, upperEs(mapName(st.map)), ANTON, 54, Vector2.new(900, 765), { width = 460 })
	tag(s, "MUTATIONS", 1368, 703)
	text(s, st.mutators ~= false and "YES" or "NO", ANTON, 54, Vector2.new(1368, 765), { width = 300 })
	rule(s, 120, 869, 1680)
	backButton(s, "main", true)
	text(s, spaced(st.started and "STARTING…" or "WAITING FOR THE HOST", 3), ANTON, 54, Vector2.new(1800, 948),
		{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 1000, color = RED })
end

-- Actualizaciones de la sala (cada pocos segundos) -------------------------
local lastKey
roomUpdate.OnClientEvent:Connect(function(st)
	roomState = st
	if not st then
		lastKey = nil
		if current == screens.create or current == screens.joined then
			setStatus("The room closed")
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

-- Entrada: directo al menú principal
show("main")
