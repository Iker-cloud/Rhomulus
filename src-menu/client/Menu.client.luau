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

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = RED
bg.BorderSizePixel = 0
bg.Parent = gui

-- Velo rojo que deja ver la escena 3D a la derecha (solo en el menú principal)
local side = Instance.new("Frame")
side.Size = UDim2.fromScale(1, 1)
side.BackgroundColor3 = RED
side.BackgroundTransparency = 1
side.BorderSizePixel = 0
side.Parent = bg
local sideGradient = Instance.new("UIGradient")
sideGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.4, 0.05),
	NumberSequenceKeypoint.new(0.75, 0.8),
	NumberSequenceKeypoint.new(1, 0.95),
})
sideGradient.Parent = side

local root = Instance.new("Frame") -- lienzo de 1920x1080 centrado
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromOffset(1920, 1080)
root.BackgroundTransparency = 1
root.Parent = bg
local uiScale = Instance.new("UIScale")
uiScale.Parent = root
local function fit()
	local v = Workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.min(v.X / 1920, v.Y / 1080)
end
fit()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

-- Utilidades ------------------------------------------------------------
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function text(parent, str, font, size, pos, props)
	props = props or {}
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Text = str,
		FontFace = font,
		TextSize = math.min(size, 100), -- Roblox limita TextSize a 100: lo grande se escala a la caja
		TextScaled = size > 100,
		TextColor3 = props.color or BLACK,
		AnchorPoint = props.anchor or Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		Size = UDim2.fromOffset(props.width or 900, size > 100 and size * 1.1 or size + 20),
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		TextTransparency = props.transparency or 0,
	}, parent)
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
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(l[2], 0),
		Text = "RHOMULUS", TextColor3 = l[1], FontFace = ANTON, TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1,
	}, logo)
	table.insert(layers, { label = t, kind = l[3], target = l[3] == "shadow" and 0.15 or 0 })
end

-- Pantallas --------------------------------------------------------------
local screens = {}
local current
local function newScreen(name)
	screens[name] = make("CanvasGroup", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Visible = false,
	}, root)
	return screens[name]
end

local builders = {} -- se arman al entrar (así la sala siempre sale limpia)
local joinBox

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
	fade(bg, 0.5, { BackgroundTransparency = isMain and 1 or 0 })
	fade(side, 0.5, { BackgroundTransparency = isMain and 0 or 1 })
	fade(version, 0.3, { TextTransparency = isMain and 0 or 1, TextColor3 = isMain and LIGHT or BLACK })
	fade(cornerR, 0.3, { TextColor3 = isMain and LIGHT or BLACK })
	for _, l in layers do
		if l.kind == "main" then
			fade(l.label, 0.3, { TextTransparency = isMain and 0 or 1 })
		end
	end
	if name == "join" and joinBox then
		task.delay(0.35, function()
			joinBox:CaptureFocus()
		end)
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
local arrow = text(main, "▶", OSW, 38, Vector2.new(52, 520), { width = 40, transparency = 1 })
local items = {
	{ "JUGAR", function()
		if busy then
			return
		end
		busy = true
		setStatus("Conectando con la partida…")
		local r = request:InvokeServer("play")
		busy = false
		if r.error then
			setStatus(r.error)
		end
	end },
	{ "CREAR PARTIDA", function()
		if busy then
			return
		end
		busy = true
		setStatus("Creando la partida…")
		local r = request:InvokeServer("create", "Morro")
		busy = false
		if r.error then
			setStatus(r.error)
		else
			setStatus(nil)
			roomState = r.room
			show("create")
		end
	end },
	{ "UNIRSE CON CÓDIGO", function()
		setStatus(nil)
		show("join")
	end },
}
for i, item in items do
	local y = 448 + 130 * (i - 1)
	text(main, spaced(item[1], 0), ANTON, 108, Vector2.new(120, y + 66), { width = 1000 })
	rule(main, 120, y + 130, 900)
	local b = button(main, 40, y, 980, 130, item[2])
	b.MouseEnter:Connect(function()
		arrow.Position = UDim2.fromOffset(52, y + 72)
		arrow.TextTransparency = 0
	end)
	b.MouseLeave:Connect(function()
		arrow.TextTransparency = 1
	end)
end

-- Código y lista de jugadores (comunes a crear / sala) --------------------
local function codeText(s, code, caption)
	text(s, spaced("CÓDIGO", 3), OSW_BOLD, 36, Vector2.new(120, 342), { width = 500 })
	text(s, spaced(code, 2), ANTON, 350, Vector2.new(120, 515), { width = 900 })
	text(s, spaced(caption, 1), OSW_LIGHT, 30, Vector2.new(120, 681), { width = 700 })
end

local function playerList(s, names, hostIdx, youIdx)
	text(s, spaced("JUGADORES " .. #names .. "/4", 3), OSW_BOLD, 36, Vector2.new(876, 342), { width = 700 })
	for i = 1, 4 do
		local y = 407 + 72 * (i - 1)
		text(s, string.format("%02d", i), OSW_BOLD, 34, Vector2.new(876, y + 2), { width = 60 })
		if names[i] then
			text(s, string.upper(names[i]), ANTON, 62, Vector2.new(935, y), { width = 600 })
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
			text(s, spaced("ESPERANDO…", 2), OSW_LIGHT, 38, Vector2.new(938, y), { width = 600 })
			rule(s, 876, y + 36, 924, true)
		end
	end
end

-- 2) Crear partida (anfitrión) ---------------------------------------------
local create = newScreen("create")
builders.create = function()
	local s = create
	clear(s)
	local st = roomState
	if not st then
		return
	end
	header(s, "CREAR PARTIDA")
	codeText(s, st.code, "COMPÁRTELO CON TU GRUPO")
	playerList(s, st.names, st.hostIndex, nil)
	text(s, spaced("MAPA", 3), OSW_BOLD, 36, Vector2.new(876, 714), { width = 400 })
	local x = 876
	local boxes = {}
	local function paint()
		for j, m in boxes do
			m.box.BackgroundTransparency = (MAPS[j].id == st.map) and 0 or 1
			m.label.TextColor3 = (MAPS[j].id == st.map) and RED or BLACK
		end
	end
	for i, mapInfo in MAPS do
		local name = mapInfo.name
		local w = (i == 1) and 211 or 433
		local box = make("Frame", { BackgroundColor3 = BLACK, Position = UDim2.fromOffset(x, 748),
			Size = UDim2.fromOffset(w, 87), BorderSizePixel = 0 }, s)
		make("UIStroke", { Color = BLACK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
		local label = text(s, name, ANTON, 56, Vector2.new(x + w / 2, 792),
			{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = w })
		button(s, x, 748, w, 87, function()
			st.map = mapInfo.id
			paint()
			task.spawn(function()
				local r = request:InvokeServer("setMap", mapInfo.id)
				if r.room then
					roomState = r.room
				end
			end)
		end)
		table.insert(boxes, { box = box, label = label })
		x += w + 24
	end
	paint()
	rule(s, 120, 857, 1680)
	backButton(s, "main", true)
	smallVersion(s, 1340, 932)
	make("Frame", { BackgroundColor3 = BLACK, BorderSizePixel = 0,
		Position = UDim2.fromOffset(1385, 880), Size = UDim2.fromOffset(415, 100) }, s)
	text(s, spaced(st.started and "EMPEZANDO…" or "EMPEZAR", 2), ANTON, 84, Vector2.new(1592, 932),
		{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 415, color = RED })
	button(s, 1385, 880, 415, 100, function()
		if not st.started then
			task.spawn(function()
				request:InvokeServer("start")
			end)
		end
	end)
end

-- 3) Unirse con código ------------------------------------------------------
local join = newScreen("join")
local joined = newScreen("joined")

builders.join = function()
	local s = join
	clear(s)
	header(s, "UNIRSE CON CÓDIGO")
	local slots = {}
	for i = 1, 4 do
		local x = 475 + 250 * (i - 1)
		outline(s, x, 400, 220, 260, 5)
		slots[i] = text(s, "", ANTON, 280, Vector2.new(x + 110, 535),
			{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 220 })
	end
	local caption = text(s, spaced("INTRODUCE EL CÓDIGO DEL ANFITRIÓN", 3), OSW_BOLD, 36, Vector2.new(960, 720),
		{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 1400 })
	rule(s, 120, 857, 1680)
	backButton(s, "main")
	smallVersion(s, 1400, 932)
	outline(s, 1445, 882, 355, 98, 2)
	local enterLabel = text(s, spaced("ENTRAR", 2), ANTON, 84, Vector2.new(1622, 932),
		{ anchor = Vector2.new(0.5, 0.5), align = Enum.TextXAlignment.Center, width = 355, transparency = 0.5 })

	-- La TextBox invisible recibe lo que se escribe (sirve también en celular)
	joinBox = make("TextBox", {
		BackgroundTransparency = 1, Text = "", TextTransparency = 1, ClearTextOnFocus = false,
		PlaceholderText = "", Position = UDim2.fromOffset(475, 400), Size = UDim2.fromOffset(970, 260), ZIndex = 4,
	}, s)
	joinBox:GetPropertyChangedSignal("Text"):Connect(function()
		local t = string.sub(string.gsub(string.upper(joinBox.Text), "[^A-Z]", ""), 1, 4)
		if t ~= joinBox.Text then
			joinBox.Text = t
			return
		end
		for i = 1, 4 do
			slots[i].Text = string.sub(t, i, i)
		end
		enterLabel.TextTransparency = (#t == 4) and 0 or 0.5
	end)
	button(s, 1445, 882, 355, 98, function()
		if #joinBox.Text == 4 and not busy then
			busy = true
			caption.Text = spaced("BUSCANDO LA SALA…", 3)
			local r = request:InvokeServer("join", joinBox.Text)
			busy = false
			if r.error then
				caption.Text = spaced(string.upper(r.error), 3)
			else
				roomState = r.room
				show("joined")
			end
		end
	end)
end

builders.joined = function()
	local s = joined
	clear(s)
	local st = roomState
	if not st then
		return
	end
	header(s, "PARTIDA " .. st.code)
	codeText(s, st.code, "CONECTADO")
	playerList(s, st.names, st.hostIndex, st.youIndex)
	text(s, spaced("MAPA: " .. mapName(st.map), 3), OSW_BOLD, 44, Vector2.new(876, 728), { width = 900 })
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
	local key = table.concat({ st.code, st.map, table.concat(st.names, ","), st.hostIndex, st.youIndex, tostring(st.started) }, "|")
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

local prompt = text(root, spaced("PRESIONA CUALQUIER TECLA", 4), OSW_BOLD, 38, Vector2.new(120, 947),
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
