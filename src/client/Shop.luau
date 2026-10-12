-- Tienda de suministros: se abre al pulsar E en una estación de munición (el servidor manda Remotes.OpenShop). Lista la
-- munición y los objetos de Config.Items con su precio en latas; se compra con el botón (el ratón queda libre mientras
-- está abierta: atributo "UiOpen" del jugador, que lee CameraController). Se cierra con ✕, con Esc, con E otra vez (el prompt) o al alejarse.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Difficulties = require(ReplicatedStorage.Shared.Difficulties)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
local GOLD = Color3.fromRGB(246, 196, 70)
local DARK = Color3.fromRGB(18, 18, 20)
local CLOSE_DISTANCE = 22

local Shop = {}

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

function Shop.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.Parent = player:WaitForChild("PlayerGui")

	local rows = {} -- { id, cost, button, count, max }
	local entries = { { id = "Ammo", name = "MUNICIÓN", cost = Config.WeaponBox.AmmoCost, note = "Recarga la reserva del arma" } }
	for _, id in Config.Items.Order do
		local cfg = Config.Items[id]
		table.insert(entries, { id = id, name = string.upper(cfg.Name), cost = cfg.Cost, max = cfg.Max })
	end

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 70 + #entries * 52)
	panel.BackgroundColor3 = DARK
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Parent = panel

	label(panel, "SUMINISTROS", UDim2.new(1, -60, 0, 34), UDim2.fromOffset(16, 8), 28, GOLD)
	local latas = label(panel, "", UDim2.new(1, -60, 0, 18), UDim2.fromOffset(16, 40), 16, Color3.fromRGB(215, 210, 200))
	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(34, 34)
	close.Position = UDim2.new(1, -44, 0, 8)
	close.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
	close.BorderSizePixel = 0
	close.FontFace = OSWALD
	close.TextSize = 20
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "X"
	close.Parent = panel

	for i, entry in entries do
		local row = Instance.new("Frame")
		row.Position = UDim2.fromOffset(12, 66 + (i - 1) * 52)
		row.Size = UDim2.new(1, -24, 0, 46)
		row.BackgroundColor3 = Color3.fromRGB(34, 34, 38)
		row.BorderSizePixel = 0
		row.Parent = panel
		label(row, entry.name, UDim2.fromOffset(150, 24), UDim2.fromOffset(12, 4), 20, Color3.new(1, 1, 1))
		local count = label(row, entry.note or "", UDim2.fromOffset(160, 16), UDim2.fromOffset(12, 26), 13, Color3.fromRGB(150, 146, 140))
		local cost = label(row, `{entry.cost} LATAS`, UDim2.fromOffset(90, 46), UDim2.fromOffset(176, 0), 18, GOLD, Enum.TextXAlignment.Right)
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromOffset(86, 32)
		button.Position = UDim2.new(1, -96, 0, 7)
		button.BackgroundColor3 = GOLD
		button.BorderSizePixel = 0
		button.FontFace = OSWALD
		button.TextSize = 18
		button.TextColor3 = Color3.fromRGB(16, 16, 16)
		button.Text = "COMPRAR"
		button.Parent = row
		button.Activated:Connect(function()
			Remotes.Buy:FireServer(entry.id)
		end)
		table.insert(rows, { entry = entry, button = button, count = count, cost = cost })
	end

	local stationPosition = nil
	local connection = nil

	local function setOpen(open)
		panel.Visible = open
		player:SetAttribute("UiOpen", open or nil)
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if open then
			connection = RunService.RenderStepped:Connect(function()
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if not root or (root.Position - stationPosition).Magnitude > CLOSE_DISTANCE or player:GetAttribute("State") ~= "Normal" then
					setOpen(false)
					return
				end
				local points = workspace:GetAttribute("Points") or 0
				latas.Text = `Latas del equipo: {points}`
				for _, r in rows do
					local entry = r.entry
					local owned = entry.max and (player:GetAttribute("Item_" .. entry.id) or 0) or nil
					local full = owned ~= nil and owned >= entry.max
					if owned ~= nil then
						r.count.Text = `Llevas {owned} de {entry.max}`
					end
					local price = Difficulties.price(entry.cost, workspace:GetAttribute("Difficulty")) -- el precio base sube o baja con la dificultad
					r.cost.Text = `{price} LATAS`
					local affordable = points >= price
					r.button.Text = full and "LLENO" or "COMPRAR"
					r.button.BackgroundColor3 = (full or not affordable) and Color3.fromRGB(80, 78, 74) or GOLD
					r.cost.TextColor3 = affordable and GOLD or Color3.fromRGB(200, 90, 80)
				end
			end)
		end
	end

	close.Activated:Connect(function()
		setOpen(false)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if panel.Visible and input.KeyCode == Enum.KeyCode.Escape then
			setOpen(false)
		end
	end)
	Remotes.OpenShop.OnClientEvent:Connect(function(position)
		if panel.Visible then
			setOpen(false)
			return
		end
		stationPosition = position
		setOpen(true)
	end)
end

return Shop
