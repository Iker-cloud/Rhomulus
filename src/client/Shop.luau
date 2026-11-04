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

local UiFit = require(script.Parent.UiFit)
local Paper = require(script.Parent.PaperStyle)
local player = Players.LocalPlayer
local OSWALD = Paper.Head
local GOLD = Paper.Red -- acento: rojo tinta
local ROW = Color3.fromRGB(214, 198, 160)
local CLOSE_DISTANCE = 22

local Shop = {}

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

function Shop.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.Parent = player:WaitForChild("PlayerGui")

	local rows = {} -- { id, cost, button, count, max }
	local entries = { { id = "Ammo", name = "AMMO", cost = Config.WeaponBox.AmmoCost, note = "Refills the weapon's reserve" } }
	for _, id in Config.Items.Order do
		local cfg = Config.Items[id]
		table.insert(entries, { id = id, name = string.upper(cfg.Name), cost = cfg.Cost, max = cfg.Max })
	end

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 70 + #entries * 52)
	panel.Rotation = -0.4
	panel.Visible = false
	panel.Parent = gui
	Paper.paper(panel, 3)
	UiFit.fitPanel(panel, 420, 70 + #entries * 52)

	label(panel, "SUPPLIES", UDim2.new(1, -60, 0, 34), UDim2.fromOffset(16, 8), 28, GOLD)
	local latas = label(panel, "", UDim2.new(1, -60, 0, 18), UDim2.fromOffset(16, 40), 14, Paper.Soft, nil, Paper.Typewriter)
	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(34, 34)
	close.Position = UDim2.new(1, -44, 0, 8)
	close.BackgroundColor3 = Paper.Ink
	close.BorderSizePixel = 0
	close.FontFace = OSWALD
	close.TextSize = 20
	close.TextColor3 = Color3.fromRGB(240, 232, 214)
	close.Text = "X"
	close.Parent = panel

	for i, entry in entries do
		local row = Instance.new("Frame")
		row.Position = UDim2.fromOffset(12, 66 + (i - 1) * 52)
		row.Size = UDim2.new(1, -24, 0, 46)
		row.BackgroundColor3 = ROW
		row.BorderSizePixel = 0
		row.Parent = panel
		label(row, entry.name, UDim2.fromOffset(150, 24), UDim2.fromOffset(12, 4), 20, Paper.Ink)
		local count = label(row, entry.note or "", UDim2.fromOffset(160, 16), UDim2.fromOffset(12, 26), 12, Paper.Soft, nil, Paper.Typewriter)
		count.TextScaled = true
		local fitNote = Instance.new("UITextSizeConstraint")
		fitNote.MaxTextSize = 12
		fitNote.Parent = count
		local cost = label(row, `{entry.cost} CANS`, UDim2.fromOffset(90, 46), UDim2.fromOffset(176, 0), 18, GOLD, Enum.TextXAlignment.Right)
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromOffset(86, 32)
		button.Position = UDim2.new(1, -96, 0, 7)
		button.BackgroundColor3 = Paper.Ink
		button.BorderSizePixel = 0
		button.FontFace = OSWALD
		button.TextSize = 18
		button.TextColor3 = Paper.Hilite
		button.Text = "BUY"
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
				latas.Text = `Team cans: {points}`
				for _, r in rows do
					local entry = r.entry
					local owned = entry.max and (player:GetAttribute("Item_" .. entry.id) or 0) or nil
					local full = owned ~= nil and owned >= entry.max
					if owned ~= nil then
						r.count.Text = `You have {owned} of {entry.max}`
					end
					local price = Difficulties.price(entry.cost, workspace:GetAttribute("Difficulty")) -- el precio base sube o baja con la dificultad
					r.cost.Text = `{price} CANS`
					local affordable = points >= price
					r.button.Text = full and "MAX" or "BUY"
					r.button.BackgroundColor3 = (full or not affordable) and Color3.fromRGB(150, 138, 118) or Paper.Ink
					r.button.TextColor3 = (full or not affordable) and Paper.Paper or Paper.Hilite
					r.cost.TextColor3 = affordable and Paper.Ink or Color3.fromRGB(150, 40, 36)
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
