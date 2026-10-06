-- Avance de la partida: avisos del equipo, cronómetro de la extracción y la tecla Y del lobby.
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

	local timer = text(gui, 30, Color3.fromRGB(255, 210, 90))
	timer.AnchorPoint = Vector2.new(0.5, 0)
	timer.Position = UDim2.new(0.5, 0, 0, 160)
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

	local function update()
		local stage = workspace:GetAttribute("Stage")
		local arrival = workspace:GetAttribute("ExtractionEnd")
		local remaining = arrival and arrival - workspace:GetServerTimeNow() or 0
		timer.Text = (stage == "Extraction" and remaining > 0) and `Rescate en {math.ceil(remaining)}s` or ""
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
end

return GameHud
