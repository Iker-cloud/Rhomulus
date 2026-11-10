-- Las órdenes llegan como una transmisión de radio: franja de color, canal y quién habla, y el mensaje.
-- Cada orden tiene su color y su remitente (tabla TONES). El servidor manda el texto en Workspace.Message
-- y la clave de la orden en Workspace.Tone. Las teclas sueltas (una letra mayúscula, como "Y") salen como tecla de verdad.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Controls = require(script.Parent.Controls)
local Lang = require(game:GetService("ReplicatedStorage").Shared.Lang)

local UiFit = require(script.Parent.UiFit)
local player = Players.LocalPlayer

-- clave -> { color, remitente }
local TONES = {
	Lobby = { Color3.fromRGB(155, 214, 70), "COMMANDER" },
	Survival = { Color3.fromRGB(245, 190, 50), "COMMANDER" },
	Wave = { Color3.fromRGB(235, 70, 60), "LOOKOUT" },
	Boss = { Color3.fromRGB(255, 60, 120), "LOOKOUT" },
	Waiting = { Color3.fromRGB(120, 190, 120), "COMMANDER" },
	Start = { Color3.fromRGB(70, 215, 200), "COMMANDER" },
	Advance = { Color3.fromRGB(245, 190, 50), "COMMANDER" },
	Stadium = { Color3.fromRGB(245, 190, 50), "COMMANDER" },
	Vote = { Color3.fromRGB(70, 215, 200), "COMMANDER" },
	Safe = { Color3.fromRGB(90, 170, 255), "MEDICAL" },
	Generator = { Color3.fromRGB(255, 140, 50), "TECH" },
	Gas = { Color3.fromRGB(255, 140, 50), "TECH" },
	GasCarry = { Color3.fromRGB(255, 140, 50), "TECH" },
	Crew = { Color3.fromRGB(255, 140, 50), "SECURITY" },
	Checkpoint = { Color3.fromRGB(255, 215, 60), "SECURITY" },
	Warning = { Color3.fromRGB(235, 70, 60), "LOOKOUT" },
	Horde = { Color3.fromRGB(255, 60, 120), "LOOKOUT" },
	Radio = { Color3.fromRGB(170, 125, 255), "OPERATOR" },
	Hold = { Color3.fromRGB(255, 100, 50), "COMMANDER" },
	Van = { Color3.fromRGB(90, 225, 130), "PILOT" },
	Board = { Color3.fromRGB(255, 215, 60), "PILOT" },
	Run = { Color3.fromRGB(255, 75, 75), "PILOT" },
	Victory = { Color3.fromRGB(110, 230, 120), "COMMANDER" },
	Defeat = { Color3.fromRGB(235, 70, 60), "COMMANDER" },
}

local RadioHud = {}

-- Una letra mayúscula completamente sola ("Y") se convierte en tecla resaltada. Se revisa palabra por palabra para
-- no confundirla con la inicial de una palabra con tilde ("Súbanse").
local function withKeys(message, color)
	local hex = color:ToHex()
	return (
		message:gsub("%S+", function(word)
			local lead, key, trail = word:match("^([¡¿%p]*)(%u)([%p]*)$")
			if not key or key == "A" or key == "I" then -- "A" e "I" son palabras en inglés, no teclas
				return word
			end
			return lead .. `<mark color="#{hex}" transparency="0"><font color="#10140f"> {key} </font></mark>` .. trail
		end)
	)
end

function RadioHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RadioHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("CanvasGroup")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Size = UDim2.fromOffset(450, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Color3.fromRGB(14, 16, 12)
	panel.BackgroundTransparency = 0.06
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	UiFit.scale(panel)
	local basePosition = UDim2.new(0.5, 0, 0, 80)
	panel.Position = basePosition

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Transparency = 0.55
	stroke.Parent = panel

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 4, 1, 0)
	accent.BorderSizePixel = 0
	accent.Parent = panel

	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 3)
	layout.Parent = content

	-- Cabecera: punto rojo parpadeante, canal y remitente, barras de señal
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 15)
	header.LayoutOrder = 1
	header.Parent = content

	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(7, 7)
	dot.Position = UDim2.fromOffset(0, 4)
	dot.BackgroundColor3 = Color3.fromRGB(255, 70, 50)
	dot.BorderSizePixel = 0
	dot.Parent = header
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

	local sender = Instance.new("TextLabel")
	sender.BackgroundTransparency = 1
	sender.Position = UDim2.fromOffset(15, 0)
	sender.Size = UDim2.new(1, -60, 1, 0)
	sender.Font = Enum.Font.Code
	sender.TextSize = 12
	sender.TextXAlignment = Enum.TextXAlignment.Left
	sender.Parent = header

	local signal = {}
	for i = 1, 3 do
		local barFrame = Instance.new("Frame")
		barFrame.AnchorPoint = Vector2.new(0, 1)
		barFrame.Size = UDim2.fromOffset(3, 3 + i * 3)
		barFrame.Position = UDim2.new(1, -26 + i * 6, 1, -1)
		barFrame.BorderSizePixel = 0
		barFrame.Parent = header
		signal[i] = barFrame
	end

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.Font = Enum.Font.GothamBold
	body.TextSize = 18
	body.TextColor3 = Color3.fromRGB(245, 245, 235)
	body.TextWrapped = true
	body.RichText = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.LayoutOrder = 2
	body.Parent = content

	local currentTone = TONES.Advance
	local reveal, total = 0, 0

	local function show(message, toneKey)
		if message == "" then
			panel.Visible = false
			return
		end
		local tone = TONES[toneKey] or TONES.Advance
		currentTone = tone
		local color = tone[1]

		accent.BackgroundColor3 = color
		stroke.Color = color
		sender.TextColor3 = color
		sender.Text = `CHANNEL 7 · {tone[2]}`
		for _, barFrame in signal do
			barFrame.BackgroundColor3 = color
		end

		-- se traduce antes de poner las teclas (la etiqueta ya lleva marcas de texto enriquecido)
		local shown = Lang.tr(Controls.touchText(message))
		body.Text = withKeys(shown, color)
		total = utf8.len(shown) or #shown
		reveal = 0 -- el texto aparece letra por letra
		body.MaxVisibleGraphemes = 0

		-- Entra deslizándose desde la izquierda
		panel.Visible = true
		panel.GroupTransparency = 1
		panel.Position = basePosition + UDim2.fromOffset(-40, 0)
		TweenService:Create(panel, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			GroupTransparency = 0,
			Position = basePosition,
		}):Play()
	end

	local lastKey = nil
	local function refresh()
		local message = workspace:GetAttribute("Message") or ""
		local toneKey = workspace:GetAttribute("Tone")
		if workspace:GetAttribute("Stage") == "Result" then
			message = ""
		end
		-- En el lobby, después de presionar Y, la orden cambia a esperar a los demás
		if workspace:GetAttribute("Stage") == "Lobby" and toneKey == "Lobby" and player:GetAttribute("Ready") then
			message, toneKey = "Ready. Waiting for the other players", "Waiting"
		end
		local key = message .. "|" .. tostring(toneKey)
		if key ~= lastKey then
			lastKey = key
			show(message, toneKey)
		end
	end

	-- El servidor cambia varios atributos seguidos: se agrupan para animar una sola vez
	local pending = false
	local function schedule()
		if not pending then
			pending = true
			task.defer(function()
				pending = false
				refresh()
			end)
		end
	end
	workspace:GetAttributeChangedSignal("Message"):Connect(schedule)
	workspace:GetAttributeChangedSignal("Tone"):Connect(schedule)
	workspace:GetAttributeChangedSignal("Stage"):Connect(schedule)
	player:GetAttributeChangedSignal("Ready"):Connect(schedule)
	refresh()

	RunService.Heartbeat:Connect(function(dt)
		-- Escribe el mensaje letra por letra
		if reveal < total + 4 then
			reveal += dt * 80
			body.MaxVisibleGraphemes = reveal >= total + 4 and -1 or math.floor(reveal)
		end
		-- Punto rojo parpadeante y barras de señal que titilan
		local t = os.clock()
		dot.BackgroundTransparency = math.sin(t * 5) > 0 and 0 or 0.6
		for i, barFrame in signal do
			barFrame.BackgroundTransparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(t * 3 + i))
		end
	end)
end

return RadioHud
