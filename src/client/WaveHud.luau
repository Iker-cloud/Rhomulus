-- Marcador del modo Survival: oleada actual y cuántos zombies quedan (o la cuenta atrás de la pausa), y una alerta al empezar cada
-- oleada de jefe. Lee los atributos de Workspace que publica GameState.survival: Wave, WaveTotal, WaveLeft, WaveBoss y WaveBreakEnd.
-- Mismo lenguaje visual que el resto del HUD (placas inclinadas, letra pesada en cursiva, rojo sobre negro).
-- Los textos van en inglés; Lang.watch los traduce solo (pares con {1} en shared/LangEs).
local Players = game:GetService("Players")

local Sfx = require(script.Parent.Sfx)
local Slant = require(script.Parent.Slant)
local UiFit = require(script.Parent.UiFit)

local player = Players.LocalPlayer

local WaveHud = {}

local DARK = Color3.fromRGB(14, 16, 12)
local RED = Color3.fromRGB(200, 38, 38)
local AMBER = Color3.fromRGB(245, 190, 50)
local GREEN = Color3.fromRGB(70, 160, 90)
local CREAM = Color3.fromRGB(245, 245, 235)
local BLACK = Color3.fromRGB(16, 12, 10)

local function label(parent, size, color)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Text = "" -- (sin esto sale "Label", el texto por defecto, hasta que se escriba otra cosa)
	text.FontFace = Slant.FONT
	text.TextSize = size
	text.TextColor3 = color
	text.TextScaled = true
	text.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.MinTextSize = 8
	limit.Parent = text
	return text
end

-- Placa inclinada (paralelogramo) con sombra dura debajo, para que no se pierda sobre el cielo
local function plate(parent, x, y, width, height, slant, color)
	local shadow = Instance.new("Frame")
	shadow.BackgroundTransparency = 1
	shadow.Position = UDim2.fromOffset(x + 3, y + 3)
	shadow.Parent = parent
	Slant.fill(shadow, width, height, slant, Color3.fromRGB(0, 0, 0))
	for _, strip in shadow:GetChildren() do
		strip.BackgroundTransparency = 0.55
	end
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(x, y)
	holder.Parent = parent
	Slant.fill(holder, width, height, slant, color)
	return holder
end

function WaveHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WaveHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Marcador arriba al centro (donde va la etiqueta de dificultad en las demás partidas): etiqueta roja con la oleada + placa oscura
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 12)
	panel.Size = UDim2.fromOffset(420, 58)
	panel.BackgroundTransparency = 1
	panel.Visible = false
	panel.Parent = gui
	UiFit.scale(panel, 0.9)

	plate(panel, 150, 0, 270, 46, 14, DARK)
	local tag = plate(panel, 0, 0, 190, 46, 14, RED)
	local title = label(tag, 26, CREAM)
	title.Position = UDim2.fromOffset(22, 4)
	title.Size = UDim2.fromOffset(150, 38)
	local status = label(panel, 20, CREAM)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Position = UDim2.fromOffset(212, 4)
	status.Size = UDim2.fromOffset(190, 38)

	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(170, 50)
	track.Size = UDim2.fromOffset(240, 4)
	track.BackgroundColor3 = DARK
	track.BackgroundTransparency = 0.25
	track.BorderSizePixel = 0
	track.Parent = panel
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = RED
	fill.BorderSizePixel = 0
	fill.Parent = track

	-- Al empezar una oleada de jefe suena la alerta (el aviso grande en el centro se quitó: tapaba la vista)
	local function showBanner(_wave, boss)
		if boss then
			Sfx.play("AlertTank", 0.5)
		end
	end

	local function paintTag(color)
		for _, strip in tag:GetChildren() do
			strip.BackgroundColor3 = color
		end
	end

	local function hidden()
		local state = player:GetAttribute("State")
		return state == "Downed" or state == "Dead" -- la tarjeta de caído y la del espectador ocupan ese sitio
	end

	local function refresh()
		local stage = workspace:GetAttribute("Stage")
		local active = workspace:GetAttribute("SurvivalMode") and (stage == "Wave" or stage == "WaveBreak") and not hidden()
		panel.Visible = active
		if not active then
			return
		end
		local wave = workspace:GetAttribute("Wave") or 0
		if stage == "Wave" then
			local total = math.max(1, workspace:GetAttribute("WaveTotal") or 1)
			local left = math.clamp(workspace:GetAttribute("WaveLeft") or total, 0, total)
			local boss = workspace:GetAttribute("WaveBoss") == true
			title.Text = `WAVE {wave}`
			title.TextColor3 = boss and BLACK or CREAM
			paintTag(boss and AMBER or RED)
			status.Text = boss and `BOSS WAVE · {left} LEFT` or `{left} LEFT`
			fill.Size = UDim2.fromScale(1 - left / total, 1)
			track.Visible = true
		else
			local remaining = math.max(0, (workspace:GetAttribute("WaveBreakEnd") or 0) - workspace:GetServerTimeNow())
			title.Text = wave == 0 and "GET READY" or `WAVE {wave} CLEARED`
			title.TextColor3 = CREAM
			paintTag(GREEN)
			status.Text = `NEXT WAVE IN {math.ceil(remaining)}`
			track.Visible = false
		end
	end

	local lastWave = 0
	workspace:GetAttributeChangedSignal("Wave"):Connect(function()
		local wave = workspace:GetAttribute("Wave") or 0
		if wave > 0 and wave ~= lastWave and workspace:GetAttribute("SurvivalMode") then
			showBanner(wave, workspace:GetAttribute("WaveBoss") == true)
		end
		lastWave = wave
		refresh()
	end)
	for _, name in { "Stage", "MapId", "SurvivalMode", "WaveLeft", "WaveTotal", "WaveBoss" } do
		workspace:GetAttributeChangedSignal(name):Connect(refresh)
	end
	player:GetAttributeChangedSignal("State"):Connect(refresh)
	task.spawn(function()
		while true do
			if workspace:GetAttribute("Stage") == "WaveBreak" then
				refresh() -- la cuenta atrás de la pausa
			end
			task.wait(0.25)
		end
	end)
	refresh()
end

return WaveHud
