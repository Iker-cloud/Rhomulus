-- Vida como jeringa de sangre: el líquido se vacía hacia la aguja al recibir daño.
-- Animada: baja suave, destella y tiembla al golpe, y late en rojo con poca vida.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UiFit = require(script.Parent.UiFit)
local player = Players.LocalPlayer

local BLOOD = Color3.fromRGB(205, 78, 0)
local LOW_BLOOD = Color3.fromRGB(230, 30, 20)
local GLASS = Color3.fromRGB(205, 195, 180)
local LOW_HEALTH = 0.3

local HealthHud = {}

local function rect(parent, size, position, color)
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

function HealthHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HealthHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local basePosition = UDim2.new(0, 20, 1, -85)
	local root = Instance.new("Frame")
	root.Size = UDim2.fromOffset(340, 70)
	root.Position = basePosition
	root.BackgroundTransparency = 1
	root.Parent = gui
	UiFit.scale(root)

	-- Émbolo
	rect(root, UDim2.fromOffset(8, 44), UDim2.fromOffset(0, 3), GLASS)
	rect(root, UDim2.fromOffset(26, 8), UDim2.fromOffset(8, 21), GLASS)

	-- Cuerpo de la jeringa
	local barrel = Instance.new("Frame")
	barrel.Position = UDim2.fromOffset(34, 8)
	barrel.Size = UDim2.fromOffset(240, 36)
	barrel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	barrel.BorderSizePixel = 0
	barrel.Parent = root
	Instance.new("UICorner", barrel).CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Color = GLASS
	stroke.Thickness = 3
	stroke.Parent = barrel

	-- El líquido va pegado al lado de la aguja (derecha) y se acorta hacia ella
	local inner = Instance.new("Frame")
	inner.Position = UDim2.fromOffset(4, 4)
	inner.Size = UDim2.new(1, -8, 1, -8)
	inner.BackgroundTransparency = 1
	inner.ClipsDescendants = true
	inner.Parent = barrel

	local liquid = Instance.new("Frame")
	liquid.AnchorPoint = Vector2.new(1, 0)
	liquid.Position = UDim2.fromScale(1, 0)
	liquid.Size = UDim2.fromScale(1, 1)
	liquid.BackgroundColor3 = BLOOD
	liquid.BorderSizePixel = 0
	liquid.Parent = inner
	Instance.new("UICorner", liquid).CornerRadius = UDim.new(0, 5)

	local shine = Instance.new("Frame")
	shine.Size = UDim2.new(1, 0, 0.22, 0)
	shine.Position = UDim2.fromScale(0, 0.12)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.82
	shine.BorderSizePixel = 0
	shine.Parent = liquid

	-- Marcas de volumen
	for i = 1, 7 do
		local tick = rect(barrel, UDim2.fromOffset(2, i % 2 == 0 and 10 or 7), UDim2.new(i / 8, -1, 0, 3), GLASS)
		tick.BackgroundTransparency = 0.35
		tick.ZIndex = 3
	end

	-- Cuello y aguja
	rect(root, UDim2.fromOffset(14, 18), UDim2.fromOffset(276, 17), GLASS)
	rect(root, UDim2.fromOffset(48, 3), UDim2.fromOffset(290, 25), GLASS)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(34, 48)
	label.Size = UDim2.fromOffset(240, 18)
	label.Font = Enum.Font.Code
	label.TextSize = 17
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = GLASS
	label.Parent = root

	-- Estado animado
	local target, maxHealth = 100, 100
	local displayed = 100
	local flash, shake = 0, 0 -- 0..1, se apagan solos
	local lastHealth = nil
	local healthConnection = nil

	local function watch(character)
		local humanoid = character:WaitForChild("Humanoid")
		if healthConnection then
			healthConnection:Disconnect()
		end
		maxHealth = humanoid.MaxHealth
		target = humanoid.Health
		displayed = humanoid.Health
		lastHealth = humanoid.Health

		healthConnection = humanoid.HealthChanged:Connect(function(health)
			maxHealth = humanoid.MaxHealth
			target = health
			if lastHealth then
				if health < lastHealth then
					flash = 1
					shake = math.clamp((lastHealth - health) / 30, 0.3, 1)
				elseif health > lastHealth then
					flash = 0.5
				end
			end
			lastHealth = health
		end)
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end

	RunService.Heartbeat:Connect(function(dt)
		local downed = player:GetAttribute("State") == "Downed"
		displayed += (target - displayed) * math.min(1, dt * 8)
		local ratio = math.clamp(displayed / maxHealth, 0, 1)
		liquid.Size = UDim2.fromScale(ratio, 1)

		-- Poca sangre: late en rojo
		local low = target / maxHealth < LOW_HEALTH and target > 0
		local pulse = low and (0.5 + 0.5 * math.sin(os.clock() * 8)) or 0
		liquid.BackgroundColor3 = BLOOD:Lerp(LOW_BLOOD, pulse):Lerp(Color3.new(1, 1, 1), flash * 0.6)

		flash = math.max(0, flash - dt * 3.5)
		shake = math.max(0, shake - dt * 4)
		root.Position = basePosition + UDim2.fromOffset((math.random() - 0.5) * 12 * shake, (math.random() - 0.5) * 12 * shake)

		if downed then
			label.Text = "CAÍDO"
			label.TextColor3 = Color3.fromRGB(255, 90, 70)
		else
			label.Text = `SANGRE {math.floor(displayed + 0.5)}`
			label.TextColor3 = low and LOW_BLOOD or GLASS
		end
	end)
end

return HealthHud
