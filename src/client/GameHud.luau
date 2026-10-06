-- Avance de la partida: mensaje de etapa, aviso "Listo" del lobby, cuenta atrás de la extracción y resultados.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local GameHud = {}

local function text(parent, size, color)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = size
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = parent
	return label
end

function GameHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GameHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local banner = text(gui, 22)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 85)
	banner.Size = UDim2.fromOffset(700, 30)

	local timer = text(gui, 30, Color3.fromRGB(255, 210, 90))
	timer.AnchorPoint = Vector2.new(0.5, 0)
	timer.Position = UDim2.new(0.5, 0, 0, 120)
	timer.Size = UDim2.fromOffset(400, 36)

	-- Avisos del equipo (quién compró qué)
	local feed = Instance.new("Frame")
	feed.AnchorPoint = Vector2.new(0, 1)
	feed.Position = UDim2.new(0, 20, 1, -70)
	feed.Size = UDim2.fromOffset(380, 0)
	feed.AutomaticSize = Enum.AutomaticSize.Y
	feed.BackgroundTransparency = 1
	feed.Parent = gui
	local feedLayout = Instance.new("UIListLayout")
	feedLayout.Padding = UDim.new(0, 2)
	feedLayout.Parent = feed

	Remotes.Feed.OnClientEvent:Connect(function(message)
		local line = text(feed, 16)
		line.Size = UDim2.fromOffset(380, 22)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.Text = message
		task.delay(4, function()
			line:Destroy()
		end)
	end)

	-- Resultados
	local resultFrame = Instance.new("Frame")
	resultFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	resultFrame.Position = UDim2.fromScale(0.5, 0.5)
	resultFrame.Size = UDim2.fromOffset(460, 0)
	resultFrame.AutomaticSize = Enum.AutomaticSize.Y
	resultFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	resultFrame.BackgroundTransparency = 0.2
	resultFrame.BorderSizePixel = 0
	resultFrame.Visible = false
	resultFrame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = resultFrame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.Parent = resultFrame

	local function update()
		local stage = workspace:GetAttribute("Stage")
		local message = workspace:GetAttribute("Message") or ""

		if stage == "Lobby" and not player:GetAttribute("Ready") then
			message ..= " [Y]"
		end
		banner.Text = message

		local arrival = workspace:GetAttribute("ExtractionEnd")
		local remaining = arrival and arrival - workspace:GetServerTimeNow() or 0
		timer.Text = (stage == "Extraction" and remaining > 0) and `Rescate en {math.ceil(remaining)}s` or ""

		if stage ~= "Result" then
			resultFrame.Visible = false
		end
	end

	workspace:GetAttributeChangedSignal("Stage"):Connect(update)
	workspace:GetAttributeChangedSignal("Message"):Connect(update)
	player:GetAttributeChangedSignal("Ready"):Connect(update)
	task.spawn(function()
		while true do
			update()
			task.wait(0.25)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Y then
			Remotes.Ready:FireServer()
		end
	end)

	Remotes.Results.OnClientEvent:Connect(function(won, stats)
		for _, child in resultFrame:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end

		local title = text(resultFrame, 36, won and Color3.fromRGB(110, 230, 120) or Color3.fromRGB(240, 80, 80))
		title.Size = UDim2.new(1, 0, 0, 44)
		title.Text = won and "VICTORIA" or "DERROTA"

		local header = text(resultFrame, 16, Color3.fromRGB(200, 200, 200))
		header.Size = UDim2.new(1, 0, 0, 22)
		header.Text = "Jugador — Kills — Revividos — Daño recibido"

		table.sort(stats, function(a, b)
			return a.kills > b.kills
		end)
		for _, entry in stats do
			local row = text(resultFrame, 18)
			row.Size = UDim2.new(1, 0, 0, 24)
			row.Text = `{entry.name} — {entry.kills} — {entry.revives} — {entry.damage}`
		end

		resultFrame.Visible = true
	end)
end

return GameHud
