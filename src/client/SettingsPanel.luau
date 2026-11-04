-- Ajustes del jugador: sensibilidad de la cámara (ratón y dedo), calidad gráfica y panel de rendimiento. Se abre con la tecla O o con el botón de engranaje del celular
-- (client/TouchControls). Mientras está abierto el jugador tiene el atributo "UiOpen" (libera el ratón, igual que la tienda).
-- Se recuerda mientras dura la sesión: el juego aún no guarda datos entre partidas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Controls = require(script.Parent.Controls)
local Performance = require(script.Parent.Performance)
local Sfx = require(script.Parent.Sfx)
local Paper = require(script.Parent.PaperStyle)

local player = Players.LocalPlayer
local OSWALD = Paper.Head
local GOLD = Paper.Red -- acento: rojo tinta

local SettingsPanel = {}

local setOpen = function(_open) end
local isOpen = false

function SettingsPanel.toggle()
	setOpen(not isOpen)
end

function SettingsPanel.isOpen()
	return isOpen
end

local function label(parent, str, size, position, textSize, color, align, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.FontFace = font or OSWALD
	l.TextSize = textSize
	l.TextColor3 = color
	l.Text = str
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function button(parent, str, size, position)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = Paper.Ink
	b.BorderSizePixel = 0
	b.FontFace = OSWALD
	b.TextSize = 28
	b.TextColor3 = Paper.Hilite
	b.Text = str
	b.Parent = parent
	return b
end

function SettingsPanel.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Settings"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 45
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(360, 340)
	panel.Rotation = -0.4
	panel.Parent = gui
	Paper.paper(panel, 3)
	-- En pantallas muy bajas el panel se achica para que quepa
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function fit()
		local viewport = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(viewport.Y / 380, viewport.X / 400), 0.6, 1)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	label(panel, "SETTINGS", UDim2.new(1, -60, 0, 36), UDim2.fromOffset(16, 6), 26, GOLD)
	local close = button(panel, "X", UDim2.fromOffset(40, 36), UDim2.new(1, -46, 0, 6))
	close.TextSize = 22

	label(panel, "SENSITIVITY", UDim2.new(1, -32, 0, 24), UDim2.fromOffset(16, 56), 18, Paper.Ink)
	local minus = button(panel, "−", UDim2.fromOffset(64, 52), UDim2.fromOffset(16, 86))
	local plus = button(panel, "+", UDim2.fromOffset(64, 52), UDim2.new(1, -80, 0, 86))
	local value = label(panel, "", UDim2.new(1, -176, 0, 52), UDim2.fromOffset(88, 86), 30, Paper.Ink, Enum.TextXAlignment.Center)
	label(
		panel,
		Controls.isTouch() and "How far the camera turns when you drag your finger" or "How far the camera turns with the mouse",
		UDim2.new(1, -32, 0, 40),
		UDim2.fromOffset(16, 148),
		14,
		Paper.Soft,
		nil,
		Paper.Typewriter
	).TextWrapped = true

	local function refresh()
		value.Text = string.format("%.1f×", Controls.getSensitivity())
	end
	refresh()
	Controls.sensitivityChanged:Connect(refresh)

	-- Calidad gráfica: AUTO / ALTA / MEDIA / BAJA
	label(panel, "GRAPHICS QUALITY", UDim2.new(1, -32, 0, 24), UDim2.fromOffset(16, 196), 18, Paper.Ink)
	local qualityPrev = button(panel, "<", UDim2.fromOffset(64, 44), UDim2.fromOffset(16, 222))
	qualityPrev.Name = "QualityPrev"
	local qualityNext = button(panel, ">", UDim2.fromOffset(64, 44), UDim2.new(1, -80, 0, 222))
	qualityNext.Name = "QualityNext"
	local quality = label(panel, "", UDim2.new(1, -176, 0, 44), UDim2.fromOffset(88, 222), 24, Paper.Ink, Enum.TextXAlignment.Center)
	quality.TextYAlignment = Enum.TextYAlignment.Center
	local function refreshQuality()
		quality.Text = Performance.levelName()
	end
	refreshQuality()
	Performance.changed:Connect(refreshQuality)
	qualityPrev.Activated:Connect(function()
		Sfx.play("Click", 0.05)
		Performance.cycleMode(-1)
	end)
	qualityNext.Activated:Connect(function()
		Sfx.play("Click", 0.05)
		Performance.cycleMode(1)
	end)

	-- Panel de rendimiento (FPS, memoria, piezas)
	local perf = button(panel, "", UDim2.new(1, -32, 0, 40), UDim2.fromOffset(16, 284))
	perf.Name = "PerfToggle"
	perf.TextSize = 20
	local function refreshPerf()
		perf.Text = Performance.isOverlayShown() and "PERFORMANCE: SHOWN" or "PERFORMANCE: HIDDEN"
	end
	refreshPerf()
	perf.Activated:Connect(function()
		Sfx.play("Click", 0.05)
		Performance.setOverlay(not Performance.isOverlayShown())
		refreshPerf()
	end)

	local T = Config.Touch
	minus.Activated:Connect(function()
		Sfx.play("Click", 0.05)
		Controls.setSensitivity(Controls.getSensitivity() - T.SensitivityStep)
	end)
	plus.Activated:Connect(function()
		Sfx.play("Click", 0.05)
		Controls.setSensitivity(Controls.getSensitivity() + T.SensitivityStep)
	end)

	setOpen = function(open)
		if open == isOpen then
			return
		end
		if open and player:GetAttribute("UiOpen") then
			return -- otra ventana (tienda o ayuda) ya tiene el ratón
		end
		isOpen = open
		gui.Enabled = open
		player:SetAttribute("UiOpen", open or nil)
	end
	close.Activated:Connect(function()
		Sfx.play("Click", 0.05)
		setOpen(false)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.O then
			SettingsPanel.toggle()
		elseif isOpen and input.KeyCode == Enum.KeyCode.Escape then
			setOpen(false)
		end
	end)
end

return SettingsPanel
