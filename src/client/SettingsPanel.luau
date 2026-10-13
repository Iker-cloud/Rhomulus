-- Ajustes del jugador: sensibilidad de la cámara (ratón y dedo). Se abre con la tecla O o con el botón de engranaje del celular
-- (client/TouchControls). Mientras está abierto el jugador tiene el atributo "UiOpen" (libera el ratón, igual que la tienda).
-- Se recuerda mientras dura la sesión: el juego aún no guarda datos entre partidas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Controls = require(script.Parent.Controls)

local player = Players.LocalPlayer
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local GOLD = Color3.fromRGB(246, 196, 70)
local DARK = Color3.fromRGB(18, 18, 20)

local SettingsPanel = {}

local setOpen = function(_open) end
local isOpen = false

function SettingsPanel.toggle()
	setOpen(not isOpen)
end

function SettingsPanel.isOpen()
	return isOpen
end

local function label(parent, str, size, position, textSize, color, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.FontFace = OSWALD
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
	b.BackgroundColor3 = Color3.fromRGB(44, 44, 48)
	b.BorderSizePixel = 0
	b.FontFace = OSWALD
	b.TextSize = 28
	b.TextColor3 = Color3.new(1, 1, 1)
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
	panel.Size = UDim2.fromOffset(360, 200)
	panel.BackgroundColor3 = DARK
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Parent = panel
	-- En pantallas muy bajas el panel se achica para que quepa
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function fit()
		local viewport = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(viewport.Y / 260, viewport.X / 400), 0.6, 1)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	label(panel, "AJUSTES", UDim2.new(1, -60, 0, 36), UDim2.fromOffset(16, 6), 26, GOLD)
	local close = button(panel, "X", UDim2.fromOffset(40, 36), UDim2.new(1, -46, 0, 6))
	close.TextSize = 22

	label(panel, "SENSIBILIDAD", UDim2.new(1, -32, 0, 24), UDim2.fromOffset(16, 56), 18, Color3.fromRGB(215, 210, 200))
	local minus = button(panel, "−", UDim2.fromOffset(64, 52), UDim2.fromOffset(16, 86))
	local plus = button(panel, "+", UDim2.fromOffset(64, 52), UDim2.new(1, -80, 0, 86))
	local value = label(panel, "", UDim2.new(1, -176, 0, 52), UDim2.fromOffset(88, 86), 30, Color3.new(1, 1, 1), Enum.TextXAlignment.Center)
	label(
		panel,
		Controls.isTouch() and "Cuánto gira la cámara al arrastrar el dedo" or "Cuánto gira la cámara con el ratón",
		UDim2.new(1, -32, 0, 40),
		UDim2.fromOffset(16, 148),
		15,
		Color3.fromRGB(150, 146, 140)
	).TextWrapped = true

	local function refresh()
		value.Text = string.format("%.1f×", Controls.getSensitivity())
	end
	refresh()
	Controls.sensitivityChanged:Connect(refresh)

	local T = Config.Touch
	minus.Activated:Connect(function()
		Controls.setSensitivity(Controls.getSensitivity() - T.SensitivityStep)
	end)
	plus.Activated:Connect(function()
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
