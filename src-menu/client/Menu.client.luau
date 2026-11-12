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
	{ id = "LastCall", name = "LAST CALL" },
	{ id = "Survival", name = "STADIUM" }, -- las arenas de Survival salen con su nombre; el modo va en la línea de la dificultad
	{ id = "LastCallSurvival", name = "HANGAR 7" },
}
-- Cada mapa de historia tiene su arena de Survival: el id de la sala es el del mapa (historia) o el de su arena (Survival)
local ARENA_OF = { Morro = "Survival", LastCall = "LastCallSurvival" }
local PLACE_OF = { Survival = "Morro", LastCallSurvival = "LastCall" }
local function isSurvival(id)
	return PLACE_OF[id] ~= nil
end
local function placeOf(id)
	return PLACE_OF[id] or id
end
local function mapFor(place, survival)
	return survival and ARENA_OF[place] or place
end
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
local Missions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Missions"))
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
	-- Destello al pulsar: la zona se tiñe un instante y vuelve (la respuesta se siente al momento)
	b.BackgroundColor3 = Color3.fromRGB(255, 244, 228)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.06), { BackgroundTransparency = 0.82 }):Play()
	end)
	local function release()
		TweenService:Create(b, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	end
	b.MouseButton1Up:Connect(release)
	b.MouseLeave:Connect(release)
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
		-- La que sale se desvanece rápido y se corre un poco a la izquierda
		local old = current
		TweenService:Create(old, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			GroupTransparency = 1, Position = UDim2.fromOffset(-28, 0),
		}):Play()
		task.delay(0.15, function()
			if current ~= old then
				old.Visible = false
				old.Position = UDim2.fromOffset(0, 0)
			end
		end)
	end
	local s = screens[name]
	current = s
	-- La que entra espera un instante, llega deslizándose desde la derecha y se aclara (sin que se encimen las dos)
	s.Position = UDim2.fromOffset(36, 0)
	s.GroupTransparency = 1
	s.Visible = true
	TweenService:Create(s, TweenInfo.new(0.34, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false, 0.08), {
		GroupTransparency = 0, Position = UDim2.fromOffset(0, 0),
	}):Play()
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
local PROFILE_FRAME = 290 -- tamaño de la imagen del marco; el hueco mide Cosmetics.FrameHole de eso
local PROFILE_AVATAR = math.floor(PROFILE_FRAME * Cosmetics.FrameHole + 0.5)
local profileAvatar = make("Frame", {
	BackgroundColor3 = PANEL, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(AVATAR_X, AVATAR_Y), Size = UDim2.fromOffset(PROFILE_AVATAR, PROFILE_AVATAR), ClipsDescendants = true,
}, main)
local profileRing = make("ImageLabel", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ScaleType = Enum.ScaleType.Fit,
	Position = UDim2.fromOffset(AVATAR_X, AVATAR_Y), Size = UDim2.fromOffset(PROFILE_FRAME, PROFILE_FRAME), ZIndex = 2,
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
	profileRing.Image = (frame and frame.Image) or ""
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

local cratesLink = text(main, spaced("CRATES", 4) .. " →", ANTON, 40, Vector2.new(TEXT_RIGHT, 612), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 500, color = INK })
button(main, TEXT_RIGHT - 340, 582, 340, 60, function()
	setStatus(nil)
	show("crates")
end).Name = "Cajas"
text(main, spaced("WARDROBE", 4) .. " →", ANTON, 40, Vector2.new(TEXT_RIGHT, 672), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 500, color = INK })
button(main, TEXT_RIGHT - 340, 642, 340, 60, function()
	setStatus(nil)
	show("wardrobe")
end).Name = "Armario"
text(main, spaced("MISSIONS", 4) .. " →", ANTON, 40, Vector2.new(TEXT_RIGHT, 732), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 500, color = INK })
button(main, TEXT_RIGHT - 340, 702, 340, 60, function()
	setStatus(nil)
	show("missions")
end).Name = "Misiones"
local function refreshCrates()
	local boxes = (player:GetAttribute("Crates") or 0) + (player:GetAttribute("CratesBarrio") or 0)
	cratesLink.TextColor3 = boxes > 0 and RED or INK
	cratesLink.Text = spaced(boxes > 0 and `CRATES ×{boxes}` or "CRATES", 4) .. " →"
end
player:GetAttributeChangedSignal("Crates"):Connect(refreshCrates)
player:GetAttributeChangedSignal("CratesBarrio"):Connect(refreshCrates)
refreshCrates()

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
		local holeSize = math.floor(150 * Cosmetics.FrameHole + 0.5)
		local hole = make("Frame", { BackgroundColor3 = PANEL, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(holeSize, holeSize) }, s)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, hole)
		local ring = make("ImageLabel", { BackgroundTransparency = 1, Image = f.Image or "", ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(150, 150), ZIndex = 2 }, s)
		local label = text(s, "", OSW_BOLD, 24, Vector2.new(cx, cy + 92), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 180 })
		local locked = level < f.Level
		label.Text = locked and spaced(`LEVEL {f.Level}`, 2) or spaced(upperEs(f.Name), 2)
		label.TextColor3 = locked and DIM or INK
		ring.ImageTransparency = locked and 0.7 or 0
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

-- 5b) Misiones diarias: 3 por día (fácil, media y difícil) que pagan Rhoms al terminar la ronda ---------------------------------------
-- Las elige shared/Missions según el jugador y el día UTC; la partida cuenta el progreso y lo guarda (server/PlayerProgress). Aquí solo se
-- muestran: el servidor del menú pone los atributos MissionDay, MissionProg, MissionDone y MissionStreak.
local missionsScreen = newScreen("missions")
local missionConns = {}
builders.missions = function()
	local s = missionsScreen
	for _, c in missionConns do
		c:Disconnect()
	end
	table.clear(missionConns)
	clear(s)
	header(s, "DAILY MISSIONS")
	local today = Missions.today()
	local fresh = player:GetAttribute("MissionDay") == today
	local prog = fresh and string.split(player:GetAttribute("MissionProg") or "0,0,0", ",") or { "0", "0", "0" }
	local done = fresh and string.split(player:GetAttribute("MissionDone") or "0,0,0", ",") or { "0", "0", "0" }
	local picked = Missions.pick(player.UserId, today)
	local tierNames = { "EASY", "MEDIUM", "HARD" }
	for i, mission in picked do
		local y = 390 + 150 * (i - 1)
		local count = math.min(mission.Target, tonumber(prog[i]) or 0)
		local finished = done[i] == "1"
		text(s, spaced(tierNames[i], 4), OSW_BOLD, 22, Vector2.new(140, y - 40), { width = 400, color = finished and DIM or RED })
		text(s, upperEs(Missions.text(mission)), ANTON, 54, Vector2.new(140, y), { width = 1100, color = finished and DIM or INK })
		local back = make("Frame", { BackgroundColor3 = Color3.fromRGB(40, 38, 36), BorderSizePixel = 0, Position = UDim2.fromOffset(140, y + 42), Size = UDim2.fromOffset(1000, 12) }, s)
		make("Frame", { BackgroundColor3 = finished and DIM or RED, BorderSizePixel = 0, Size = UDim2.fromScale(count / mission.Target, 1) }, back)
		text(s, spaced(`{count} / {mission.Target}`, 2), OSW_BOLD, 26, Vector2.new(1170, y + 48), { width = 300, color = INK })
		text(s, finished and spaced("DONE", 3) or spaced(`+{mission.Rhoms} RHOMS`, 3), ANTON, 44, Vector2.new(1800, y),
			{ anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 520, color = finished and DIM or RED })
		rule(s, 120, y + 92, 1680)
	end
	local resets = text(s, "", OSW_BOLD, 30, Vector2.new(1800, 205), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 900, color = RED })
	local function tick()
		local left = Missions.secondsLeft()
		resets.Text = spaced(`RESETS IN {string.format("%02d:%02d:%02d", left // 3600, left % 3600 // 60, left % 60)}`, 2)
	end
	tick()
	local lastTick = os.clock()
	table.insert(missionConns, RunService.Heartbeat:Connect(function()
		if os.clock() - lastTick >= 1 then
			lastTick = os.clock()
			tick()
		end
	end))
	local streak = player:GetAttribute("MissionStreak") or 0
	text(s, spaced(`STREAK {streak} / {Missions.StreakCycle}`, 3), OSW_BOLD, 30, Vector2.new(140, 842), { width = 800, color = streak > 0 and RED or INK })
	text(s, spaced(`DAY 3: +{Missions.StreakBonus[3]} RHOMS · DAY {Missions.StreakCycle}: +{Missions.StreakBonus[7]} RHOMS`, 2), OSW, 24, Vector2.new(140, 878),
		{ width = 1200, color = DIM })
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
	local module = meleeData:FindFirstChild("Melee" .. (skin.Base or skin.Id)) -- las variantes de las cajas usan el modelo de su arma base
	if not module then
		return view, function() end, 0
	end
	local data = require(module)
	local model = WeaponModel.build(data, 1)
	Cosmetics.tintModel(model, skin)
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

	-- Solo se ven las que se pueden comprar y las que ya tiene (las de las cajas aparecen al sacarlas). La lista se desplaza.
	local CW, CH, GAP = 520, 160, 18
	local scroll = make("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(110, 345), Size = UDim2.fromOffset(1090, 545),
		ScrollBarThickness = 6, ScrollBarImageColor3 = RED, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, s)
	scroll.Name = "SkinList"
	local shown = 0
	for _, skin in Cosmetics.MeleeSkins do
		if not skin.Crate or ownedNow(skin.Id) then
			shown += 1
			local i = shown
			local col, row = (i - 1) % 2, (i - 1) // 2
			local x, y = 12 + (CW + 20) * col, 15 + (CH + GAP) * row
			local frame = make("Frame", { BackgroundColor3 = PANEL, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(CW, CH), ClipsDescendants = true }, scroll)
			local stroke = make("UIStroke", { Color = LINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
			local _, sway = weaponView(frame, 0, 0, CW, CH - 30, skin)
			table.insert(swayers, sway)
			local tag = make("TextLabel", {
				BackgroundColor3 = INK, BorderSizePixel = 0, Position = UDim2.fromOffset(14, CH - 46), Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X,
				Text = `{string.format("%02d", i)} · {upperEs(skin.Name)}`, FontFace = OSW_BOLD, TextSize = 22, TextColor3 = BLACK,
			}, frame)
			make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, tag)
			local state = text(frame, "", OSW_BOLD, 28, Vector2.new(CW - 16, CH - 30), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 200, color = INK })
			-- una franja del color de la rareza en el borde izquierdo
			make("Frame", { BackgroundColor3 = Cosmetics.Rarities[skin.Rarity].Color, BorderSizePixel = 0, Size = UDim2.new(0, 6, 1, 0) }, frame)
			cards[skin.Id] = { skin = skin, frame = frame, stroke = stroke, state = state }
			button(scroll, x, y, CW, CH, function()
				selected = skin.Id
				showDetail()
				paint()
			end).Name = "Skin_" .. skin.Id
		end
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

-- 6b) Cajas: Arsenal (skins de cuerpo a cuerpo) y Barrio (accesorios del superviviente) ----------------------------------------------
-- Se abren con una caja que ya tiene (premio al terminar una ronda) o, si no tiene, con Rhoms. El servidor sortea (ProfileRequest
-- "openCrate", tipo); aquí solo se anima: una tira de cartas que gira bajo una marca roja y se detiene en el resultado. Las
-- probabilidades se ven siempre (Cosmetics.Crates.<tipo>.Weights). Los accesorios se ponen en el ARMARIO (6c).
local Accessories = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Accessories"))

local CRATE_INFO = {
	Arsenal = {
		Title = "ARSENAL CRATE", Desc = "MELEE WEAPON SKINS. DUPLICATES GIVE RHOMS BACK.", BoxAttr = "Crates",
		Wood = Color3.fromRGB(70, 58, 44), Lid = Color3.fromRGB(96, 80, 60),
	},
	Barrio = {
		Title = "BARRIO CRATE", Desc = "SURVIVOR ACCESSORIES: CAPS, SHADES, PACKS AND PATCHES. DUPLICATES GIVE RHOMS BACK.", BoxAttr = "CratesBarrio",
		Wood = Color3.fromRGB(34, 58, 62), Lid = Color3.fromRGB(52, 88, 92),
	},
}
-- Desde dónde se mira cada accesorio suelto (hacia el centro del modelo)
local SLOT_VIEW = { Head = Vector3.new(0.55, 0.3, -1), Face = Vector3.new(0.45, 0.2, -1), Back = Vector3.new(-0.55, 0.25, 1), Shoulder = Vector3.new(1, 0.3, -0.45) }

-- Dibuja una cosa de una caja en un visor: el arma (kind "Arsenal") o el accesorio ("Barrio"). Devuelve el visor y `sway(t)`.
local function previewItem(parent, x, y, w, h, kind, item)
	if kind == "Arsenal" then
		local view, sway = weaponView(parent, x, y, w, h, item)
		return view, sway
	end
	local view = make("ViewportFrame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		Ambient = Color3.fromRGB(150, 146, 140), LightColor = Color3.fromRGB(255, 244, 228), LightDirection = Vector3.new(-0.5, -0.8, -0.6),
	}, parent)
	local model = Accessories.build(item.Id)
	if not model then
		return view, function() end
	end
	model.Parent = view
	local cf, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z)
	local dist = radius / (2 * math.tan(math.rad(12.5))) * 1.35
	local dir = SLOT_VIEW[item.Slot] or Vector3.new(0.5, 0.3, -1)
	view.CurrentCamera = make("Camera", { FieldOfView = 25, CFrame = CFrame.lookAt(cf.Position + dir.Unit * dist, cf.Position) }, view)
	local function sway(t)
		model:PivotTo(CFrame.Angles(0, math.sin(t * 0.9) * 0.5, 0))
	end
	return view, sway
end

local function lookupItem(kind, id)
	return kind == "Arsenal" and Cosmetics.melee(id) or Accessories.get(id)
end

local cratesScreen = newScreen("crates")
local cratesConns = {}
local cratesKind = "Arsenal" -- la pestaña que se ve (se recuerda al volver)
builders.crates = function()
	local s = cratesScreen
	for _, c in cratesConns do
		c:Disconnect()
	end
	table.clear(cratesConns)
	clear(s)
	header(s, "CRATES")
	local busy = false
	local note = text(s, "", OSW_BOLD, 28, Vector2.new(1800, 960), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 900, color = RED })
	local coinsLabel = text(s, "", ANTON, 44, Vector2.new(1800, 205), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 600, color = INK })

	-- Panel de la caja (izquierda), con las dos pestañas arriba
	local box = make("Frame", { BackgroundColor3 = PANEL, BorderSizePixel = 0, Position = UDim2.fromOffset(120, 360), Size = UDim2.fromOffset(560, 520) }, s)
	make("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 5) }, box)
	local tabs = {}
	for i, kind in { "Arsenal", "Barrio" } do
		local tabFrame = make("Frame", { BackgroundColor3 = LINE, BorderSizePixel = 0, Position = UDim2.fromOffset(20 + (i - 1) * 270, 22), Size = UDim2.fromOffset(250, 46) }, box)
		local tabLabel = text(tabFrame, "", ANTON, 30, Vector2.new(125, 23), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 240, color = INK })
		tabs[kind] = { frame = tabFrame, label = tabLabel }
	end
	local crateArt = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(170, 90), Size = UDim2.fromOffset(220, 170) }, box)
	local artBody = make("Frame", { BackgroundColor3 = CRATE_INFO.Arsenal.Wood, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 40), Size = UDim2.fromOffset(220, 130) }, crateArt)
	local artLid = make("Frame", { BackgroundColor3 = CRATE_INFO.Arsenal.Lid, BorderSizePixel = 0, Size = UDim2.fromOffset(220, 46) }, crateArt)
	make("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Position = UDim2.fromOffset(96, 0), Size = UDim2.fromOffset(28, 170) }, crateArt)
	make("Frame", { BackgroundColor3 = Color3.fromRGB(30, 26, 22), BorderSizePixel = 0, Position = UDim2.fromOffset(0, 84), Size = UDim2.fromOffset(220, 8) }, crateArt)
	local titleLabel = text(box, "", ANTON, 50, Vector2.new(280, 296), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 520, color = INK })
	local descLabel = text(box, "", OSW, 20, Vector2.new(280, 340), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 500, color = DIM })
	local ownedLabel = text(box, "", OSW_BOLD, 28, Vector2.new(280, 388), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 520, color = RED })
	local openBtn = make("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Position = UDim2.fromOffset(35, 432), Size = UDim2.fromOffset(490, 64) }, box)
	local openLabel = text(openBtn, "", ANTON, 38, Vector2.new(245, 32), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 480, color = BLACK })

	-- Probabilidades (derecha, abajo)
	local odds = make("Frame", { BackgroundColor3 = PANEL, BorderSizePixel = 0, Position = UDim2.fromOffset(720, 700), Size = UDim2.fromOffset(1080, 180) }, s)
	text(odds, spaced("ODDS", 4), OSW_BOLD, 24, Vector2.new(30, 30), { width = 300, color = DIM })
	local oddsLabels = {}
	for i, name in { "Common", "Rare", "Epic", "Legendary" } do
		local rarity = Cosmetics.Rarities[name]
		local x = 30 + (i - 1) * 255
		text(odds, spaced(rarity.Text, 2), OSW_BOLD, 22, Vector2.new(x, 80), { width = 240, color = rarity.Color })
		oddsLabels[name] = text(odds, "", ANTON, 52, Vector2.new(x, 128), { width = 240, color = INK })
	end
	local pityLabel = text(s, "", OSW, 20, Vector2.new(720, 905), { width = 1000, color = DIM })

	-- La tira (derecha, arriba): ventana con cartas que giran y una marca roja en el centro
	local WIN_X, WIN_Y, WIN_W, WIN_H = 720, 360, 1080, 200
	local window = make("Frame", { BackgroundColor3 = PANEL, BorderSizePixel = 0, Position = UDim2.fromOffset(WIN_X, WIN_Y), Size = UDim2.fromOffset(WIN_W, WIN_H), ClipsDescendants = true }, s)
	local strip = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(10, 160) }, window)
	make("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(4, WIN_H), ZIndex = 4 }, window)
	local CARD_W, CARD_GAP = 190, 14

	local function addCard(item, index)
		local rarity = Cosmetics.Rarities[item.Rarity]
		local card = make("Frame", { BackgroundColor3 = Color3.fromRGB(26, 24, 22), BorderSizePixel = 0, Position = UDim2.fromOffset((index - 1) * (CARD_W + CARD_GAP) + 10, 0), Size = UDim2.fromOffset(CARD_W, 160), ClipsDescendants = true }, strip)
		make("Frame", { BackgroundColor3 = rarity.Color, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -8), Size = UDim2.new(1, 0, 0, 8) }, card)
		previewItem(card, 0, 0, CARD_W, 122, cratesKind, item)
		make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -38), Size = UDim2.new(1, 0, 0, 28), Text = upperEs(item.Name), FontFace = OSW_BOLD, TextSize = 18, TextColor3 = rarity.Color }, card)
	end

	-- Resultado (derecha, en el centro)
	local resultName = text(s, "", ANTON, 56, Vector2.new(720, 612), { width = 1000, color = INK })
	local resultNote = text(s, "", OSW_BOLD, 26, Vector2.new(720, 664), { width = 1000, color = DIM })

	local function showKind()
		local info = CRATE_INFO[cratesKind]
		local crate = Cosmetics.Crates[cratesKind]
		for kind, tab in tabs do
			local on = kind == cratesKind
			tab.frame.BackgroundColor3 = on and RED or LINE
			tab.label.Text = spaced(kind == "Arsenal" and "ARSENAL" or "BARRIO", 2)
			tab.label.TextColor3 = on and BLACK or INK
		end
		artBody.BackgroundColor3, artLid.BackgroundColor3 = info.Wood, info.Lid
		titleLabel.Text = spaced(info.Title, 1)
		descLabel.Text = Lang.tr(info.Desc)
		for name, label in oddsLabels do
			label.Text = `{crate.Weights[name]}%`
		end
		pityLabel.Text = Lang.tr(`GUARANTEED EPIC EVERY {crate.Pity.Epic} CRATES · LEGENDARY EVERY {crate.Pity.Legendary}`)
		strip:ClearAllChildren()
		strip.Position = UDim2.fromOffset(0, 20)
		-- al principio, una muestra de lo que puede salir
		local pool = Cosmetics.cratePool(cratesKind)
		for i = 1, 6 do
			addCard(pool[(i * 3 - 2) % #pool + 1], i)
		end
		resultName.Text, resultNote.Text = "", ""
	end

	local function paint()
		local info = CRATE_INFO[cratesKind]
		local crate = Cosmetics.Crates[cratesKind]
		local coins = player:GetAttribute("Rhoms")
		coinsLabel.Text = typeof(coins) == "number" and spaced(`{coins} RHOMS`, 3) or ""
		local boxes = player:GetAttribute(info.BoxAttr) or 0
		ownedLabel.Text = spaced(`{Lang.tr("YOU HAVE")} {boxes} {Lang.tr(boxes == 1 and "CRATE" or "CRATES")}`, 2)
		if busy then
			openLabel.Text = spaced("OPENING…", 1)
			openBtn.BackgroundColor3 = LINE
		elseif boxes > 0 then
			openLabel.Text = spaced("OPEN · 1 CRATE", 1)
			openBtn.BackgroundColor3 = RED
		else
			openLabel.Text = spaced(`OPEN · {crate.Price} RHOMS`, 1)
			openBtn.BackgroundColor3 = (typeof(coins) == "number" and coins >= crate.Price) and RED or LINE
		end
	end

	-- Anima la tira hasta lo sorteado
	local function spinTo(item)
		strip:ClearAllChildren()
		strip.Position = UDim2.fromOffset(0, 20)
		local pool = Cosmetics.cratePool(cratesKind)
		local FINAL = 34
		for i = 1, FINAL + 4 do
			addCard(i == FINAL and item or pool[math.random(#pool)], i)
		end
		local centerOfFinal = (FINAL - 1) * (CARD_W + CARD_GAP) + 10 + CARD_W / 2
		local goal = WIN_W / 2 - centerOfFinal + math.random(-60, 60)
		local tween = TweenService:Create(strip, TweenInfo.new(5.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(goal, 20) })
		tween:Play()
		tween.Completed:Wait()
	end

	for kind, tab in tabs do
		button(box, tab.frame.Position.X.Offset, tab.frame.Position.Y.Offset, 250, 46, function()
			if busy or cratesKind == kind then
				return
			end
			cratesKind = kind
			note.Text = ""
			showKind()
			paint()
		end).Name = "Tab_" .. kind
	end

	button(box, 35, 432, 490, 64, function()
		if busy then
			return
		end
		busy = true
		note.Text = ""
		resultName.Text, resultNote.Text = "", ""
		paint()
		local kind = cratesKind
		task.spawn(function()
			local okCall, done, id, refund = pcall(function()
				return profileRequest:InvokeServer("openCrate", kind)
			end)
			if not okCall or not done then
				-- si falló, el segundo valor trae el motivo
				note.Text = spaced(string.upper((okCall and typeof(id) == "string" and id) or "Couldn't connect. Try again"), 2)
				busy = false
				paint()
				return
			end
			local item = lookupItem(kind, id)
			spinTo(item)
			local rarity = Cosmetics.Rarities[item.Rarity]
			resultName.Text = upperEs(item.Name)
			resultName.TextColor3 = rarity.Color
			if (refund or 0) > 0 then
				resultNote.Text = spaced(`{Lang.tr("DUPLICATE")} · +{refund} RHOMS`, 2)
				resultNote.TextColor3 = DIM
			else
				resultNote.Text = spaced(`{Lang.tr("NEW")} · {rarity.Text}`, 2)
				resultNote.TextColor3 = rarity.Color
			end
			busy = false
			paint()
		end)
	end).Name = "OpenCrate"

	showKind()
	paint()
	for _, name in { "Rhoms", "Crates", "CratesBarrio" } do
		table.insert(cratesConns, player:GetAttributeChangedSignal(name):Connect(paint))
	end
	backButton(s, "main")
	smallVersion(s, 1800, 1010)
end

-- 6c) Armario: los accesorios que ya tienes, por ranura ------------------------------------------------------------------------------
-- Eliges un accesorio de la ranura (cabeza, cara, espalda u hombro) y se pone; "NONE" la deja vacía. Se ve en la partida (server/AccessoryRig).
local wardrobeScreen = newScreen("wardrobe")
local wardrobeConns = {}
local wardrobeSlot = "Head"
builders.wardrobe = function()
	local s = wardrobeScreen
	for _, c in wardrobeConns do
		c:Disconnect()
	end
	table.clear(wardrobeConns)
	clear(s)
	header(s, "WARDROBE")
	local note = text(s, "", OSW_BOLD, 28, Vector2.new(1800, 960), { anchor = Vector2.new(1, 0.5), align = Enum.TextXAlignment.Right, width = 900, color = RED })
	local swayers = {}

	local function ownedNow(id)
		return table.find(string.split(player:GetAttribute("AccOwned") or "", ","), id) ~= nil
	end
	local function wornNow()
		return Accessories.decode(player:GetAttribute("AccEquipped"))
	end

	-- Pestañas de ranura (arriba)
	local tabButtons = {}
	for i, slot in Accessories.Slots do
		local frame = make("Frame", { BackgroundColor3 = LINE, BorderSizePixel = 0, Position = UDim2.fromOffset(120 + (i - 1) * 220, 346), Size = UDim2.fromOffset(204, 46) }, s)
		local label = text(frame, "", ANTON, 30, Vector2.new(102, 23), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 196, color = INK })
		tabButtons[slot] = { frame = frame, label = label }
	end

	-- Lista de la ranura (izquierda) con scroll
	local scroll = make("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(110, 410), Size = UDim2.fromOffset(1090, 480),
		ScrollBarThickness = 6, ScrollBarImageColor3 = RED, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, s)
	scroll.Name = "AccList"

	-- Panel de lo que llevas (derecha)
	local panel = make("Frame", { BackgroundColor3 = PANEL, BorderSizePixel = 0, Position = UDim2.fromOffset(1240, 410), Size = UDim2.fromOffset(560, 480) }, s)
	make("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 5) }, panel)
	text(panel, spaced("YOU WEAR", 4), OSW_BOLD, 24, Vector2.new(30, 40), { width = 400, color = DIM })
	local wearRows = {}
	for i, slot in Accessories.Slots do
		local y = 96 + (i - 1) * 74
		text(panel, spaced(Accessories.SlotNames[slot], 2), OSW_BOLD, 22, Vector2.new(30, y), { width = 160, color = DIM })
		wearRows[slot] = text(panel, "", ANTON, 34, Vector2.new(200, y), { width = 340, color = INK })
	end
	local collected = text(panel, "", OSW_BOLD, 22, Vector2.new(30, 440), { width = 500, color = DIM })

	local cards = {}
	local function buildList()
		scroll:ClearAllChildren()
		table.clear(cards)
		table.clear(swayers)
		local entries = { false } -- false = "NONE"
		for _, item in Accessories.Items do
			if item.Slot == wardrobeSlot and ownedNow(item.Id) then
				table.insert(entries, item)
			end
		end
		local CW, CH, GAP = 340, 190, 16
		for i, item in entries do
			local col, row = (i - 1) % 3, (i - 1) // 3
			local x, y = 12 + (CW + GAP) * col, 12 + (CH + GAP) * row
			local frame = make("Frame", { BackgroundColor3 = PANEL, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(CW, CH), ClipsDescendants = true }, scroll)
			local stroke = make("UIStroke", { Color = LINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
			local id = item and item.Id or ""
			if item then
				local _, sway = previewItem(frame, 0, 0, CW, CH - 40, "Barrio", item)
				table.insert(swayers, sway)
				make("Frame", { BackgroundColor3 = Cosmetics.Rarities[item.Rarity].Color, BorderSizePixel = 0, Size = UDim2.new(0, 6, 1, 0) }, frame)
			else
				text(frame, spaced("NONE", 3), ANTON, 44, Vector2.new(CW / 2, 70), { anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = CW, color = DIM })
			end
			make("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(16, CH - 38), Size = UDim2.fromOffset(CW - 32, 30), TextXAlignment = Enum.TextXAlignment.Left,
				Text = item and upperEs(item.Name) or "", FontFace = OSW_BOLD, TextSize = 22, TextColor3 = item and Cosmetics.Rarities[item.Rarity].Color or INK,
			}, frame)
			cards[id] = { frame = frame, stroke = stroke }
			button(scroll, x, y, CW, CH, function()
				task.spawn(function()
					local okCall, done, why = pcall(function()
						return profileRequest:InvokeServer("equipAcc", wardrobeSlot, id)
					end)
					note.Text = (okCall and done) and "" or spaced(string.upper((okCall and why) or "Couldn't connect. Try again"), 2)
				end)
			end).Name = "Acc_" .. (id == "" and "None" or id)
		end
	end

	local function paint()
		local worn = wornNow()
		for slot, tab in tabButtons do
			local on = slot == wardrobeSlot
			tab.frame.BackgroundColor3 = on and RED or LINE
			tab.label.Text = spaced(Accessories.SlotNames[slot], 2)
			tab.label.TextColor3 = on and BLACK or INK
			local item = worn[slot] and Accessories.get(worn[slot])
			wearRows[slot].Text = item and upperEs(item.Name) or "—"
			wearRows[slot].TextColor3 = item and Cosmetics.Rarities[item.Rarity].Color or DIM
		end
		for id, card in cards do
			local on = (id == "" and worn[wardrobeSlot] == nil) or worn[wardrobeSlot] == id
			card.frame.BackgroundColor3 = on and Color3.fromRGB(40, 11, 13) or PANEL
			card.stroke.Color = on and RED or LINE
			card.stroke.Thickness = on and 4 or 2
		end
		local own = string.split(player:GetAttribute("AccOwned") or "", ",")
		local count = 0
		for _, id in own do
			if id ~= "" then
				count += 1
			end
		end
		collected.Text = Lang.tr("COLLECTED") .. ` {count} / {#Accessories.Items}`
	end

	for slot, tab in tabButtons do
		button(s, tab.frame.Position.X.Offset, tab.frame.Position.Y.Offset, 204, 46, function()
			wardrobeSlot = slot
			buildList()
			paint()
		end).Name = "Slot_" .. slot
	end

	buildList()
	paint()
	for _, name in { "AccOwned", "AccEquipped" } do
		table.insert(wardrobeConns, player:GetAttributeChangedSignal(name):Connect(function()
			if name == "AccOwned" then
				buildList()
			end
			paint()
		end))
	end
	-- los accesorios giran despacio mientras la pantalla se ve
	table.insert(wardrobeConns, RunService.RenderStepped:Connect(function()
		if not s.Visible then
			return
		end
		local t = os.clock()
		for i, sway in swayers do
			sway(t + i * 0.7)
		end
	end))
	backButton(s, "main")
	smallVersion(s, 1800, 1010)
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
			text(row, spaced(isSurvival(item.map) and "SURVIVAL" or difficultyName(item.difficulty), 3), OSW_BOLD, 22, Vector2.new(740, 72), { width = 480, color = DIM, transparency = alpha })
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
		text(card, spaced(isSurvival(setupState.map) and "SURVIVAL" or difficultyName(setupState.difficulty), 3), OSW_BOLD, 20, Vector2.new(745, 128),
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

	tag(s, "MODE", 120, 550)
	local describeDifficultyAgain = nil -- se asigna más abajo: al cambiar de modo se actualiza el texto de la dificultad
	choiceRow(s, 120, 574, 84, { { false, "STORY", 300 }, { true, "SURVIVAL", 380 } }, 52, function(id)
		return isSurvival(setupState.map) == id
	end, function(id)
		setupState.map = mapFor(placeOf(setupState.map), id)
		if id then
			setupState.difficulty = Difficulties.Default
		end
		drawPreview()
		if describeDifficultyAgain then
			describeDifficultyAgain()
		end
		task.defer(builders.setup) -- los nombres de la fila MAP cambian con el modo
	end)

	-- El mapa (historia) o la arena (Survival), a la derecha, bajo la vista previa
	tag(s, "MAP", 1020, 698)
	local arenaNames = isSurvival(setupState.map)
	choiceRow(s, 1020, 722, 80, arenaNames and { { "Morro", "STADIUM", 384 }, { "LastCall", "HANGAR 7", 384 } }
		or { { "Morro", "MORRO ESPERANZA", 384 }, { "LastCall", "LAST CALL", 384 } }, 40, function(id)
		return placeOf(setupState.map) == id
	end, function(id)
		setupState.map = mapFor(id, isSurvival(setupState.map))
		drawPreview()
	end)

	-- Los mutadores se encienden o apagan después, en la sala del anfitrión (aquí se crea con ellos activados)

	tag(s, "DIFFICULTY", 120, 698)
	local difficultyDesc = text(s, "", OSW_LIGHT, 24, Vector2.new(120, 830), { width = 1000, color = DIM })
	local function describeDifficulty()
		difficultyDesc.Text = isSurvival(setupState.map) and "Survival ignores this: the horde gets harder by itself every wave."
			or Difficulties.get(setupState.difficulty).Description
	end
	describeDifficultyAgain = describeDifficulty
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

	if not isSurvival(st.map) then -- Survival no sortea mutaciones
		tag(s, "MUTATIONS", 1368, 703)
		choiceRow(s, 1368, 728, 80, { { true, "YES", 110 }, { false, "NO", 110 } }, 54, function(id)
			return st.mutators ~= false == id
		end, function(id)
			st.mutators = id
			hostRequest("setMutators", id)
		end)
	end

	tag(s, "MODE", 900, 703)
	choiceRow(s, 900, 728, 62, { { false, "STORY", 190 }, { true, "SURVIVAL", 238 } }, 40, function(id)
		return isSurvival(st.map) == id
	end, function(id)
		st.map = mapFor(placeOf(st.map), id)
		hostRequest("setMap", st.map, true) -- se redibuja: los nombres de la fila de abajo cambian con el modo
	end)
	-- El mapa (historia) o la arena (Survival)
	choiceRow(s, 900, 798, 62, isSurvival(st.map) and { { "Morro", "STADIUM", 190 }, { "LastCall", "HANGAR 7", 238 } }
		or { { "Morro", "MORRO ESPERANZA", 238 }, { "LastCall", "LAST CALL", 190 } }, 28, function(id)
		return placeOf(st.map) == id
	end, function(id)
		st.map = mapFor(id, isSurvival(st.map))
		hostRequest("setMap", st.map, true)
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
		diffDesc.Text = isSurvival(st.map) and "Survival ignores this: the horde gets harder by itself every wave."
			or Difficulties.get(st.difficulty).Description
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
	local survival = isSurvival(st.map)
	text(s, spaced(survival and "ENDLESS" or Difficulties.get(st.difficulty).Upper, 3), ANTON, 54, Vector2.new(120, 725), { width = 700 })
	text(s, survival and (st.map == "LastCallSurvival" and "Waves of zombies that never stop. Hold Hangar 7 for as long as you can."
		or "Waves of zombies that never stop. Hold the stadium for as long as you can.") or Difficulties.get(st.difficulty).Description,
		OSW_LIGHT, 24, Vector2.new(120, 790), { width = 700, color = DIM })
	tag(s, "MODE", 900, 703)
	text(s, upperEs(mapName(st.map)), ANTON, 54, Vector2.new(900, 765), { width = 460 })
	if not survival then
		tag(s, "MUTATIONS", 1368, 703)
		text(s, st.mutators ~= false and "YES" or "NO", ANTON, 54, Vector2.new(1368, 765), { width = 300 })
	end
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
