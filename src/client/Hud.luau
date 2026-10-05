-- Mira, munición y vida propias.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local Hud = {}

local function label(parent, position, size)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = position
	text.Size = size
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.5
	text.TextScaled = true
	text.Parent = parent
	return text
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Mira
	local crosshair = Instance.new("Frame")
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(6, 6)
	crosshair.BackgroundColor3 = Color3.new(1, 1, 1)
	crosshair.BorderSizePixel = 0
	crosshair.Parent = gui
	Instance.new("UICorner", crosshair).CornerRadius = UDim.new(1, 0)

	-- Munición
	local ammoLabel = label(gui, UDim2.new(1, -220, 1, -70), UDim2.fromOffset(200, 50))
	ammoLabel.TextXAlignment = Enum.TextXAlignment.Right

	Remotes.AmmoUpdate.OnClientEvent:Connect(function(ammo, magSize, reloading)
		ammoLabel.Text = reloading and "Recargando..." or `{ammo} / {magSize}`
	end)

	-- Vida
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 20, 1, -50)
	back.Size = UDim2.fromOffset(250, 24)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0
	back.Parent = gui

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
	fill.BorderSizePixel = 0
	fill.Parent = back

	local function watchHumanoid(character)
		local humanoid = character:WaitForChild("Humanoid")
		local function update()
			fill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
		end
		humanoid.HealthChanged:Connect(update)
		update()
	end
	player.CharacterAdded:Connect(watchHumanoid)
	if player.Character then
		task.spawn(watchHumanoid, player.Character)
	end

	Remotes.Sync:FireServer()
end

return Hud
