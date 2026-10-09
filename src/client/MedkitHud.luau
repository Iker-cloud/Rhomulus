-- Botiquín (cliente): la tecla de Config.Medkit.Key cura al compañero herido al que se mira (a menos de Range) o, si no
-- hay ninguno, a uno mismo. Muestra el botiquín que se lleva (encima de la jeringa) y la barra de la curación en curso.
-- El servidor (server/Medkits) valida todo y pone los atributos Item_Medkit, HealingEnd y HealingTarget.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local M = Config.Medkit
local RED = Color3.fromRGB(226, 66, 54)
local DARK = Color3.fromRGB(14, 13, 13)

local MedkitHud = {}

-- Compañero herido más cercano delante de la cámara, dentro del alcance
local function pickTarget()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local look = workspace.CurrentCamera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit
	local best, bestDistance = nil, M.Range
	for _, other in Players:GetPlayers() do
		local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		local humanoid = otherRoot and other.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth and other:GetAttribute("State") == "Normal" then
			local offset = otherRoot.Position - root.Position
			local distance = offset.Magnitude
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if distance <= bestDistance and flat.Magnitude > 0.1 and flat.Unit:Dot(flatLook) > 0.4 then
				best, bestDistance = other, distance
			end
		end
	end
	return best
end

local function label(parent, text, size, position, font, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = font
	l.TextSize = 14
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

function MedkitHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MedkitHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Botiquín que se lleva: encima de la jeringa de vida
	local badge = Instance.new("Frame")
	badge.Position = UDim2.new(0, 20, 1, -132)
	badge.Size = UDim2.fromOffset(168, 32)
	badge.BackgroundColor3 = DARK
	badge.BackgroundTransparency = 0.15
	badge.BorderSizePixel = 0
	badge.Visible = false
	badge.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = RED
	stroke.Transparency = 0.3
	stroke.Parent = badge
	local cross = Instance.new("Frame")
	cross.Position = UDim2.fromOffset(8, 6)
	cross.Size = UDim2.fromOffset(20, 20)
	cross.BackgroundColor3 = Color3.new(1, 1, 1)
	cross.BorderSizePixel = 0
	cross.Parent = badge
	for _, size in { UDim2.fromOffset(12, 4), UDim2.fromOffset(4, 12) } do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = size
		bar.BackgroundColor3 = RED
		bar.BorderSizePixel = 0
		bar.Parent = cross
	end
	label(badge, `BOTIQUÍN  [{M.KeyLabel}]`, UDim2.fromOffset(130, 32), UDim2.fromOffset(36, 0), Enum.Font.GothamBlack, Color3.new(1, 1, 1))

	-- Barra de curación (debajo de la mira)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0.5, 60)
	panel.Size = UDim2.fromOffset(220, 38)
	panel.BackgroundColor3 = DARK
	panel.BackgroundTransparency = 0.2
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local title = label(panel, "", UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 4), Enum.Font.GothamBold, Color3.new(1, 1, 1))
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 8, 1, -12)
	back.Size = UDim2.new(1, -16, 0, 5)
	back.BackgroundColor3 = Color3.fromRGB(60, 56, 54)
	back.BorderSizePixel = 0
	back.Parent = panel
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = RED
	fill.BorderSizePixel = 0
	fill.Parent = back

	RunService.RenderStepped:Connect(function()
		badge.Visible = false -- el botiquín ahora se ve en la barra del inventario (client/Inventory)
		local endTime = player:GetAttribute("HealingEnd")
		if endTime then
			local left = math.max(0, endTime - workspace:GetServerTimeNow())
			local target = player:GetAttribute("HealingTarget")
			title.Text = (target and target ~= "") and `Curando a {target}…` or "Curándote…"
			fill.Size = UDim2.fromScale(1 - left / M.Time, 1)
			panel.Visible = true
		else
			panel.Visible = false
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= M.Key or (player:GetAttribute("Item_Medkit") or 0) <= 0 then
			return
		end
		Remotes.UseMedkit:FireServer(pickTarget())
	end)
end

return MedkitHud
